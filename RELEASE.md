# Local Validation and Release Packaging

This repository is not release-ready: all three datasets, authoritative schema information, redistribution confirmation, and license selection are missing. No release has been published. Local ZIP creation is not authorization to redistribute anything.

## Validation

Install PowerShell 7 or later. From the repository root, run:

```powershell
pwsh -NoProfile -File ./scripts/package-release.ps1 -Version 0.0.0-review
```

The [packaging script](scripts/package-release.ps1) validates the explicit [file list](release-files.txt), rejects unsafe paths and symbolic links, checks relative Markdown file links in the selected documents, and parses any selected JSON with the .NET JSON parser. It reports selected CSV/JSON file counts. It does not follow external links, validate Markdown anchor fragments, infer schemas, parse CSVs, or scan for all secrets. JSON checks cover single JSON documents, not JSON Lines; add a separate verified workflow if actual source files require it.

Current result: documentation checks are possible, but there are no CSVs or JSON files to parse, count records in, or inspect for sensitive values. Absence of data is not a successful data-validation result.

## Prepare Approved Assets

1. Obtain the actual source files and provenance. Put operational exports under `operational-data/csv/`, the budget seed in `property-budget/`, and JSON under `property-events/json/`, preserving meaningful subdirectories. Create these data directories only when adding real assets.
2. Update the dataset guides and [schema evidence](schema/README.md) using verified filenames and metadata. Record export timestamps separately from record date coverage. Do not infer source SQL types, constraints, or keys from values alone.
3. Verify CSV encoding/BOM, delimiter, headers, quoting, field counts, null conventions, date formats, and parsed record counts using those established settings. Reconcile exported counts with export evidence. Verify JSON syntax, envelope, record counts, and relationships using supplied definitions. No CSV validation settings can be provided yet; the packaging script is not a substitute for these checks.
4. Review every proposed public file, including filenames and nested JSON, for real personal information, internal identifiers/addresses, private endpoints, connection strings, credentials, tokens, SAS parameters, and third-party notices. Automated checks cannot establish that data is synthetic or redistributable. Do not reproduce any discovered secrets in review reports; remove or replace affected assets through an approved process. Never include Cube-only connection instructions.
5. Ask the owner to confirm redistribution rights for every source and choose a suitable data license, with an explicit decision about documentation and tooling coverage. Add approved terms only after that confirmation. No license terms have been added here.
6. Add each approved file by its exact relative path to the file list. No wildcards or automatic directory inclusion are used. Include approved license files in the list when they exist. This list initially selects only the documentation and packaging tools created locally; it is not evidence of publication approval.

## Build a Local Candidate

```powershell
pwsh -NoProfile -File ./scripts/package-release.ps1 -Version 0.0.0-review -CreateZip
```

The command creates a single local ZIP under `dist/` with a `northstar-sample-data/` top-level directory. It preserves paths, includes only listed files, then checks archive entry names and SHA-256 content hashes against the selected files. Existing packages are never overwritten. The version is caller-supplied; use a review label for local tests, not an asserted public release version. No Git operation or network call is performed by the script.

Git metadata, unrelated files, secrets, and generated packages must never be added to the allowlist. The script blocks common private/generated paths and unapproved file categories, but an innocuously named data or text file can still contain secrets. The ignore rules are convenience guards, not a security review or an eraser for previously tracked files. ZIPs and `dist/` are excluded from version control by the supplied ignore rules.

## Before Public Release

Complete the source, schema, privacy, redistribution, and license checks above. Recheck official product documentation and test the intended learner setup separately when authorized; no live service work is part of this local repository task. SharePoint list column compatibility, tenant feature availability, SQL Server import mappings, network/gateway setup, and the event example's Lakehouse lookup remain unverified.

Use immutable release labels such as `v1.0.0` only after approval. Keep the reviewed file list, export metadata, parsed row counts, and a SHA-256 checksum of the final ZIP with the release record. Never silently replace a release ZIP; issue a new version for data, schema, or documentation changes. Each course should cite the exact version used in its recordings, not a mutable branch archive. Publication and creation of remote download links require separate approval and are not performed here.

Return to the [repository guide](README.md).