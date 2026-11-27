# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {"name": "synapse_pyspark"}
# META }

# MARKDOWN ********************

# # Northstar Direct Lake Framing
# Attach the isolated `lh_northstar_framing_demo` Lakehouse, not a shared source.
# Set the source IDs and choose `prepare`, `append`, or `reset` before running.
# Prepare freezes real rows once. Append holds existing files intact. Reset rewrites
# only the owned demo fact from the frozen baseline; refresh and warm the model again.

# PARAMETERS CELL ********************

stage = "prepare"
source_workspace_id = ""
source_warehouse_id = ""
target_workspace_id = ""

# CELL ********************

import json
from datetime import datetime, timezone
from uuid import UUID

from delta.tables import DeltaTable
from pyspark.sql import functions as F

context = notebookutils.runtime.context
assert stage in {"prepare", "append", "reset"}, "Choose prepare, append, or reset."
for identifier in (source_workspace_id, source_warehouse_id, target_workspace_id):
    UUID(identifier)
assert context["currentWorkspaceId"].lower() == target_workspace_id.lower()
assert context["defaultLakehouseWorkspaceId"].lower() == target_workspace_id.lower()
assert context["defaultLakehouseName"] == "lh_northstar_framing_demo"
assert context["defaultLakehouseId"].lower() != source_warehouse_id.lower()

endpoint = notebookutils.conf.get("trident.onelake.endpoint").replace("https://", "").rstrip("/")
source_root = f"abfss://{source_workspace_id}@{endpoint}/{source_warehouse_id}/Tables/dw"
target_root = f"abfss://{target_workspace_id}@{endpoint}/{context['defaultLakehouseId']}"
demo_root = f"{target_root}/Files/framing-demo"
manifest_path = f"{demo_root}/manifest.json"
fact_path = f"{target_root}/Tables/dbo/factstaynight"
fact_columns = ["StayNightID", "StayDateKey", "PropertyKey", "NightNumber", "RoomsOccupied", "RoomRevenue"]
source_columns = {
    "FactStayNight": fact_columns,
    "DimDate": ["DateKey", "FullDate", "YearMonth"],
    "DimProperty": ["PropertyKey", "PropertyCode", "PropertyName"],
}
spark.conf.set("spark.microsoft.delta.optimizeWrite.enabled", "false")
spark.conf.set("spark.databricks.delta.autoCompact.enabled", "false")


def read_json(path):
    return json.loads(notebookutils.fs.head(path, 1024 * 1024))


def write_json(path, value):
    notebookutils.fs.put(path, json.dumps(value, indent=2, default=str), True)


def fact_state():
    frame = spark.read.format("delta").load(fact_path)
    totals = frame.agg(
        F.count("*").alias("stay_nights"),
        F.sum("RoomsOccupied").alias("rooms_occupied"),
        F.sum("RoomRevenue").alias("room_revenue"),
    ).first().asDict()
    totals["room_revenue"] = str(totals["room_revenue"])
    return {
        "version": int(DeltaTable.forPath(spark, fact_path).history(1).first()["version"]),
        "files": sorted(frame.inputFiles()),
        "totals": totals,
    }


def log_actions(version):
    text = notebookutils.fs.head(f"{fact_path}/_delta_log/{version:020d}.json", 1024 * 1024)
    actions = [json.loads(line) for line in text.splitlines() if line.strip()]
    return {
        "added_files": [action["add"]["path"] for action in actions if "add" in action],
        "removed_files": [action["remove"]["path"] for action in actions if "remove" in action],
    }


def save_table(frame, name, mode):
    frame.coalesce(1).write.format("delta").mode(mode).option(
        "parquet.vorder.enabled", "true"
    ).saveAsTable(f"dbo.{name.lower()}")


def prepare_table(frame, name):
    path = f"{target_root}/Tables/dbo/{name.lower()}"
    if DeltaTable.isDeltaTable(spark, path):
        existing = spark.read.format("delta").load(path).select(*frame.columns)
        assert existing.exceptAll(frame).limit(1).count() == 0
        assert frame.exceptAll(existing).limit(1).count() == 0
    else:
        save_table(frame, name, "errorifexists")


# CELL ********************

if stage == "prepare":
    assert not notebookutils.fs.exists(manifest_path), "Snapshot already exists. Use reset."
    notebookutils.fs.mkdirs(demo_root)
    source_versions = {}
    for name, columns in source_columns.items():
        source_path = f"{source_root}/{name}"
        version = int(DeltaTable.forPath(spark, source_path).history(1).first()["version"])
        snapshot_path = f"{demo_root}/snapshot/{name}"
        if not DeltaTable.isDeltaTable(spark, snapshot_path):
            source = spark.read.format("delta").option("versionAsOf", version).load(source_path)
            source.select(*columns).coalesce(1).write.format("delta").mode("errorifexists").option(
                "userMetadata", json.dumps({"source_version": version})
            ).save(snapshot_path)
        history = DeltaTable.forPath(spark, snapshot_path).history(1).first().asDict()
        source_versions[name] = json.loads(history.get("userMetadata") or "{}").get("source_version")

    frozen = spark.read.format("delta").load(f"{demo_root}/snapshot/FactStayNight")
    latest_date = int(frozen.agg(F.max("StayDateKey")).first()[0])
    frozen_count = frozen.count()
    held_out = frozen.filter(F.col("StayDateKey") == latest_date)
    held_out_count = held_out.count()
    assert 0 < held_out_count < frozen_count, "Need nonempty baseline and held-out batches."
    assert frozen.select("StayNightID").distinct().count() == frozen_count
    assert all(frozen.filter(F.col(column).isNull()).limit(1).count() == 0 for column in fact_columns)
    baseline = frozen.filter(F.col("StayDateKey") < latest_date)
    for name, key, foreign_key in (("DimDate", "DateKey", "StayDateKey"), ("DimProperty", "PropertyKey", "PropertyKey")):
        dimension = spark.read.format("delta").load(f"{demo_root}/snapshot/{name}")
        assert dimension.select(key).distinct().count() == dimension.count()
        assert dimension.filter(F.col(key).isNull()).limit(1).count() == 0
        assert frozen.join(dimension, frozen[foreign_key] == dimension[key], "left_anti").limit(1).count() == 0
        prepare_table(dimension, name)
    prepare_table(baseline, "FactStayNight")
    state = fact_state()
    manifest = {
        "owner": "northstar-connectivity-framing-demo",
        "target_lakehouse_id": context["defaultLakehouseId"],
        "source_versions": source_versions,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "held_out_date_key": latest_date,
        "held_out_rows": held_out_count,
        "snapshot_rows": frozen_count,
        "baseline": state,
    }
    write_json(manifest_path, manifest)
    result = {"stage": stage, "held_out_date_key": latest_date, "held_out_rows": held_out_count, **state}
else:
    manifest = read_json(manifest_path)
    assert manifest["owner"] == "northstar-connectivity-framing-demo"
    assert manifest["target_lakehouse_id"] == context["defaultLakehouseId"]
    frozen = spark.read.format("delta").load(f"{demo_root}/snapshot/FactStayNight")
    latest_date = manifest["held_out_date_key"]
    before = fact_state()
    if stage == "append":
        assert before["totals"] == manifest["baseline"]["totals"], "Fact isn't at baseline. Reset first."
        assert before["files"] == manifest["baseline"]["files"], "Baseline files changed. Reset first."
        assert before["totals"]["stay_nights"] + manifest["held_out_rows"] == manifest["snapshot_rows"]
        save_table(frozen.filter(F.col("StayDateKey") == latest_date), "FactStayNight", "append")
        after = fact_state()
        actions = log_actions(after["version"])
        assert after["version"] == before["version"] + 1
        assert actions["added_files"] and not actions["removed_files"], "Append rewrote existing files."
        assert set(before["files"]) < set(after["files"]), "Original active files weren't retained."
        assert after["totals"]["stay_nights"] == manifest["snapshot_rows"]
        result = {"stage": stage, "before": before, "after": after, **actions}
    else:
        save_table(frozen.filter(F.col("StayDateKey") < latest_date), "FactStayNight", "overwrite")
        after = fact_state()
        assert after["totals"] == manifest["baseline"]["totals"]
        manifest["baseline"] = after
        write_json(manifest_path, manifest)
        result = {"stage": stage, "before": before, "after": after, **log_actions(after["version"])}

result["observed_utc"] = datetime.now(timezone.utc).isoformat()
write_json(f"{demo_root}/{stage}-evidence.json", result)
print(json.dumps(result, indent=2, default=str))
notebookutils.notebook.exit(json.dumps(result, default=str))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
