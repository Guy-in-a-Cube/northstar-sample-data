import ast
import base64
import contextlib
import hashlib
import io
import json
import re
import unittest
import zlib
from pathlib import Path
from urllib.parse import quote, unquote, urlparse
from uuid import UUID


DIRECT_LAKE_DIR = Path(__file__).resolve().parents[1]
LAB_DIR = DIRECT_LAKE_DIR.parent
WORKSPACE_ID = "00000000-0000-0000-0000-000000000001"
WAREHOUSE_ID = "00000000-0000-0000-0000-000000000002"
MODEL_ID = "00000000-0000-0000-0000-000000000003"


class Response:
    def __init__(self, status_code=200, body=None, headers=None):
        self.status_code = status_code
        self.body = {} if body is None else body
        self.headers = {} if headers is None else headers
        self.text = json.dumps(self.body)

    def json(self):
        return self.body


class Client:
    def __init__(self, responses=(), post_response=None):
        self.responses = list(responses)
        self.post_response = post_response
        self.get_calls = []
        self.post_calls = []

    def get(self, path, **kwargs):
        self.get_calls.append(path)
        if not self.responses:
            raise AssertionError("Unexpected GET")
        return self.responses.pop(0) if len(self.responses) > 1 else self.responses[0]

    def post(self, path, **kwargs):
        self.post_calls.append((path, kwargs))
        if isinstance(self.post_response, Exception):
            raise self.post_response
        if self.post_response is None:
            raise AssertionError("Unexpected POST")
        return self.post_response


class Clock:
    def __init__(self):
        self.now = 0

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        self.now += max(seconds, 0.1)


class Frame:
    def __init__(self, count, marker):
        self.count = count
        self.marker = marker

    def __len__(self):
        return self.count

    def copy(self):
        return Frame(self.count, self.marker)


class DaxClient:
    def __init__(self):
        self.marker = object()
        self.month_count = 2

    def evaluate_dax(self, **kwargs):
        count = self.month_count if "SUMMARIZECOLUMNS" in kwargs["dax_string"] else 1
        return Frame(count, self.marker)


class SetupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        notebook_path = DIRECT_LAKE_DIR / "nb_create_connectivity_direct_lake_model.ipynb"
        cls.notebook = json.loads(notebook_path.read_text(encoding="utf-8"))
        cls.sources = ["".join(cell["source"]) for cell in cls.notebook["cells"] if cell["cell_type"] == "code"]

    def namespace(self):
        namespace = {
            "base64": base64, "hashlib": hashlib, "json": json, "re": re,
            "time": Clock(), "zlib": zlib, "UUID": UUID, "quote": quote,
            "urlparse": urlparse, "operation_timeout_seconds": 3,
            "fabric_client": Client(), "display": lambda value: None,
        }
        helper_tree = ast.parse(self.sources[1])
        functions = ast.Module(body=[node for node in helper_tree.body if isinstance(node, ast.FunctionDef)], type_ignores=[])
        exec(compile(functions, "notebook-helpers", "exec"), namespace)
        self.run_cell(namespace, 2)
        namespace.update({
            "workspace_id": WORKSPACE_ID, "warehouse_id": WAREHOUSE_ID,
            "source_url": f"https://onelake.dfs.fabric.microsoft.com/{WORKSPACE_ID}/{WAREHOUSE_ID}",
            "model_id": MODEL_ID, "model_created": False, "semantic_model_name": "Student",
        })
        namespace["definition"] = namespace["prepare_definition"](namespace["template_files"], WORKSPACE_ID, WAREHOUSE_ID)
        return namespace

    def run_cell(self, namespace, index):
        with contextlib.redirect_stdout(io.StringIO()):
            exec(compile(self.sources[index], f"notebook-code-{index + 1}", "exec"), namespace)

    def test_notebook_format_and_syntax(self):
        self.assertEqual(self.notebook["nbformat"], 4)
        self.assertEqual(len(self.notebook["cells"]), 8)
        identities = []
        for cell in self.notebook["cells"]:
            self.assertRegex(cell["id"], r"^[a-zA-Z0-9_-]{1,64}$")
            self.assertTrue(cell["metadata"]["id"])
            identities.append(cell["id"])
            self.assertEqual(cell["metadata"]["language"], "markdown" if cell["cell_type"] == "markdown" else "python")
            self.assertTrue(all(line.endswith("\n") for line in cell["source"]))
            if cell["cell_type"] == "code":
                self.assertEqual(cell["outputs"], [])
                self.assertIsNone(cell["execution_count"])
                ast.parse("".join(cell["source"]))
        self.assertEqual(len(identities), len(set(identities)))

    def test_portable_binding_does_not_change_template(self):
        namespace = self.namespace()
        definition = namespace["definition"]
        self.assertEqual(len(definition["parts"]), 8)
        decoded = {part["path"]: base64.b64decode(part["payload"]).decode("utf-8") for part in definition["parts"]}
        self.assertEqual(namespace["validate_definition"](decoded, namespace["source_url"]),
                         {"tables": 3, "columns": 12, "measures": 3, "relationships": 2})
        self.assertIn(namespace["source_placeholder"], namespace["template_files"]["definition/expressions.tmdl"])

    def test_checksum_and_uuid_rejections(self):
        namespace = self.namespace()
        namespace["template_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            namespace["load_template"]()
        with self.assertRaisesRegex(ValueError, "badly formed"):
            namespace["prepare_definition"](namespace["template_files"], "not-a-guid", WAREHOUSE_ID)

    def test_definition_rejections(self):
        namespace = self.namespace()
        changes = (
            ("definition/tables/FactStayNight.tmdl", "mode: directLake", "mode: import", "Expected one Direct Lake"),
            ("definition/tables/DimDate.tmdl", "schemaName: dw", "schemaName: dbo", "Wrong Warehouse schema"),
            ("definition/tables/DimDate.tmdl", "sourceColumn: FullDate", "sourceColumn: Date", "must map"),
            ("definition/tables/FactStayNight.tmdl", "DirectLake - Northstar Connectivity", "Wrong Source", "Wrong source expression"),
        )
        for path, original, replacement, message in changes:
            with self.subTest(message=message):
                files = dict(namespace["template_files"])
                self.assertIn(original, files[path])
                files[path] = files[path].replace(original, replacement)
                with self.assertRaisesRegex(ValueError, message):
                    namespace["validate_definition"](files, namespace["source_placeholder"])
        files = dict(namespace["template_files"], unexpected="extra")
        with self.assertRaisesRegex(ValueError, "Unexpected definition parts"):
            namespace["validate_definition"](files, namespace["source_placeholder"])

    def test_unique_names(self):
        namespace = self.namespace()
        item = {"displayName": "Student"}
        self.assertIs(namespace["unique_name"]([item], "student", "model"), item)
        for items, count in (([], 0), ([item, item], 2)):
            with self.subTest(count=count), self.assertRaisesRegex(ValueError, f"found {count}"):
                namespace["unique_name"](items, "Student", "model")

    def test_pagination_and_repeated_token(self):
        namespace = self.namespace()
        client = Client([Response(body={"value": [1], "continuationToken": "a+b"}), Response(body={"value": [2]})])
        namespace["fabric_client"] = client
        self.assertEqual(namespace["list_all"]("/v1/items?type=Warehouse"), [1, 2])
        self.assertEqual(client.get_calls[1], "/v1/items?type=Warehouse&continuationToken=a%2Bb")
        namespace["fabric_client"] = Client([Response(body={"continuationToken": "same"})])
        with self.assertRaisesRegex(RuntimeError, "repeated continuation token"):
            namespace["list_all"]("/v1/items")

    def test_http_and_missing_operation_id(self):
        namespace = self.namespace()
        with self.assertRaisesRegex(RuntimeError, "HTTP 403"):
            namespace["require_success"](Response(403), "Read")
        with self.assertRaisesRegex(RuntimeError, "accepted without a tracking ID"):
            namespace["wait_for_operation"](Response(202), "Create")

    def test_operation_success_failure_and_timeout(self):
        accepted = Response(202, headers={"Location": f"/v1/operations/{MODEL_ID}"})
        namespace = self.namespace()
        namespace["fabric_client"] = Client([
            Response(body={"status": "Running"}, headers={"Retry-After": "1"}),
            Response(body={"status": "Succeeded"}), Response(body={"id": MODEL_ID}),
        ])
        self.assertEqual(namespace["wait_for_operation"](accepted, "Create"), {"id": MODEL_ID})
        namespace = self.namespace()
        namespace["fabric_client"] = Client([Response(body={"status": "Failed"})])
        with self.assertRaisesRegex(RuntimeError, "Failed"):
            namespace["wait_for_operation"](accepted, "Create")
        namespace = self.namespace()
        namespace["fabric_client"] = Client([Response(body={"status": "Running"})])
        with self.assertRaisesRegex(TimeoutError, "remains pending"):
            namespace["wait_for_operation"](accepted, "Create")

    def test_creation_guards_make_no_post(self):
        namespace = self.namespace()
        namespace["model_created"] = True
        with self.assertRaisesRegex(RuntimeError, "already created"):
            self.run_cell(namespace, 4)
        namespace["model_created"] = False
        namespace["list_all"] = lambda path: [{"type": "SemanticModel", "displayName": "Student"}]
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.run_cell(namespace, 4)
        self.assertEqual(namespace["fabric_client"].post_calls, [])

    def test_creation_success_and_ambiguous_failure(self):
        namespace = self.namespace()
        namespace["list_all"] = lambda path: []
        namespace["fabric_client"] = Client(post_response=Response(201, {"id": MODEL_ID}))
        self.run_cell(namespace, 4)
        self.assertTrue(namespace["model_created"])
        self.assertEqual(len(namespace["fabric_client"].post_calls), 1)
        self.assertEqual(namespace["fabric_client"].post_calls[0][0], f"/v1/workspaces/{WORKSPACE_ID}/semanticModels")
        namespace = self.namespace()
        namespace["list_all"] = lambda path: []
        namespace["fabric_client"] = Client(post_response=ConnectionError("unknown request outcome"))
        with self.assertRaisesRegex(RuntimeError, "may already exist"):
            self.run_cell(namespace, 4)
        self.assertEqual(len(namespace["fabric_client"].post_calls), 1)
        self.assertFalse(namespace["model_created"])

    def test_refresh_success(self):
        namespace = self.namespace()
        namespace["model_created"] = True
        namespace["power_bi_client"] = Client([Response(body={"status": "Completed"})],
                                              Response(202, headers={"Location": f"/refreshes/{MODEL_ID}"}))
        self.run_cell(namespace, 5)
        self.assertTrue(namespace["refresh_completed"])
        self.assertEqual(namespace["power_bi_client"].post_calls[0][1]["json"]["retryCount"], 0)

    def test_refresh_timeout_retains_model_and_blocks_resubmission(self):
        namespace = self.namespace()
        namespace["model_created"] = True
        client = Client([Response(body={"status": "InProgress"})],
                        Response(202, headers={"Location": f"/refreshes/{MODEL_ID}"}))
        namespace["power_bi_client"] = client
        with self.assertRaisesRegex(RuntimeError, "NOT been deleted"):
            self.run_cell(namespace, 5)
        self.assertTrue(namespace["model_created"])
        self.assertEqual(namespace["model_id"], MODEL_ID)
        with self.assertRaisesRegex(RuntimeError, "already attempted"):
            self.run_cell(namespace, 5)
        self.assertEqual(len(client.post_calls), 1)

    def test_repeated_queries_preserve_baseline(self):
        namespace = self.namespace()
        namespace["model_created"] = True
        namespace["fabric_client"] = Client(post_response=Response(body={"definition": namespace["definition"]}))
        namespace["fabric"] = DaxClient()
        self.run_cell(namespace, 6)
        baseline_marker = namespace["fabric"].marker
        namespace["fabric"].marker = object()
        self.run_cell(namespace, 6)
        self.assertIs(namespace["baseline_monthly"].marker, baseline_marker)
        self.assertIs(namespace["baseline_totals"].marker, baseline_marker)
        self.assertIsNot(namespace["monthly"].marker, baseline_marker)

    def test_query_failure_retains_model(self):
        namespace = self.namespace()
        namespace["model_created"] = True
        namespace["fabric_client"] = Client(post_response=Response(body={"definition": namespace["definition"]}))
        namespace["fabric"] = DaxClient()
        namespace["fabric"].month_count = 1
        with self.assertRaisesRegex(RuntimeError, "query checks failed"):
            self.run_cell(namespace, 6)
        self.assertTrue(namespace["model_created"])

    def test_no_update_delete_or_untracked_mutation_calls(self):
        for source in self.sources:
            for node in ast.walk(ast.parse(source)):
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                    self.assertNotIn(node.func.attr, {"delete", "patch", "put"})
        self.assertNotIn("/refreshes", self.sources[6])
        self.assertIn("/getDefinition?format=TMDL", self.sources[6])

    def test_sql_keys_are_checked_individually(self):
        balanced_match_counts = (0, 2, 1, 1, 1)
        self.assertEqual(sum(balanced_match_counts), 5)
        self.assertTrue(any(count != 1 for count in balanced_match_counts))
        pattern = (
            r"IF EXISTS\s*\(\s*SELECT saved\.StayNightID\s*"
            r"FROM dbo\.NorthstarConnectivityRestore AS saved\s*"
            r"LEFT JOIN dw\.FactStayNight AS fact ON fact\.StayNightID = saved\.StayNightID\s*"
            r"GROUP BY saved\.StayNightID\s*HAVING COUNT_BIG\(fact\.StayNightID\) <> 1\s*\)"
        )
        scripts = sorted(DIRECT_LAKE_DIR.glob("*.sql"))
        self.assertEqual(len(scripts), 3)
        for script in scripts:
            with self.subTest(script=script.name):
                self.assertRegex(script.read_text(encoding="utf-8"), pattern)

    def test_sql_assigns_saved_values_with_guards(self):
        for filename, target, current in (
            ("002_update_warehouse_demo.sql", "DemoRoomRevenue", "OriginalRoomRevenue"),
            ("003_reset_warehouse_demo.sql", "OriginalRoomRevenue", "DemoRoomRevenue"),
        ):
            text = (DIRECT_LAKE_DIR / filename).read_text(encoding="utf-8")
            with self.subTest(script=filename):
                self.assertEqual(len(re.findall(r"(?m)^\s*UPDATE fact\s*$", text)), 1)
                self.assertIn(f"SET RoomRevenue = saved.{target}", text)
                self.assertIn(f"WHERE fact.RoomRevenue = saved.{current}", text)
                for guard in ("@ConfirmedLabWarehouse VARCHAR(128) = ''", "WarehouseName <> DB_NAME()",
                              "COUNT_BIG(DISTINCT StayNightID)", "SET @ChangedRows = @@ROWCOUNT;",
                              "IF @ChangedRows <> 5", "ROLLBACK TRANSACTION;"):
                    self.assertIn(guard, text)

    def test_document_links(self):
        documents = (DIRECT_LAKE_DIR / "README.md", LAB_DIR / "student-preparation.md",
                     LAB_DIR / "README.md", LAB_DIR / "framing/README.md",
                     LAB_DIR.parents[1] / "README.md")
        for document in documents:
            for target in re.findall(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", document.read_text(encoding="utf-8")):
                if urlparse(target).scheme or target.startswith("#"):
                    continue
                with self.subTest(document=str(document), target=target):
                    self.assertTrue((document.parent / unquote(target.split("#", 1)[0])).exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)