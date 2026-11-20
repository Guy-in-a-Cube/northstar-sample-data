# Local Validation and Release Packaging

The full three-dataset package is not release-ready: budget workbook publication, event sources/schema, business definitions, and remaining redistribution/license decisions are pending. The budget workbook has been inspected and its Excel-authoritative maintenance contract is documented in the budget guide. Consumer Excel-to-SharePoint setup links to Microsoft documentation; no maintainer-run import test is planned. The owner has approved the eight operational tables as synthetic and redistributable under CC0 1.0; operational exports have been validated privately. Code and documentation licensing remains unselected. Operational table metadata has been inspected and a [table deployment script](schema/create-ops-tables.sql) is available. Local ZIP creation is not authorization to redistribute anything.

## Validation

Install PowerShell 7 or later. From the repository root, run:

```powershell
pwsh -NoProfile -File ./scripts/package-release.ps1 -Version 0.0.0-review
```

The [packaging script](scripts/package-release.ps1) validates the explicit [file list](release-files.txt), rejects unsafe paths and symbolic links, checks relative Markdown file links in the selected documents, and parses any selected JSON with the .NET JSON parser. It reports selected CSV/JSON file counts. It does not follow external links, validate Markdown anchor fragments, infer schemas, parse CSVs, or scan for all secrets. JSON checks cover single JSON documents, not JSON Lines; add a separate verified workflow if actual source files require it.

Current result: the local documentation package contains no CSV or JSON data assets. Private operational export validation is a separate check; absence of data from the ZIP is not a successful data-validation result.

SQL script validation is separate from the packager. The operational script was checked with Microsoft's offline SQL Server 2019 syntax parser and compared with inspected source metadata. The packager does not repeat SQL syntax or schema comparisons. Authorized tests against the intended database platforms are still required to verify deployment, rollback, and existing-object rejection; no deployment has been run.

## Prepare Approved Assets

1. Obtain the actual source files and provenance. Put operational exports under `operational-data/csv/`, the budget seed in `property-budget/`, and JSON under `property-events/json/`, preserving meaningful subdirectories. Create these data directories only when adding real assets.
2. Update the dataset guides and [schema evidence](schema/README.md) using verified filenames and metadata. Record export timestamps separately from record date coverage. Do not infer source SQL types, constraints, or keys from values alone.
3. Verify CSV encoding/BOM, delimiter, headers, quoting, field counts, null conventions, date formats, and parsed record counts using those established settings. Reconcile exported counts with export evidence. Verify JSON syntax, envelope, record counts, and relationships using supplied definitions. Operational CSV settings are recorded in the [operational guide](operational-data/README.md). Validate budget Excel table bounds, dates, stored percentages, keys, and coverage against the [budget contract](property-budget/README.md); optional budget CSV and event settings remain pending. The packaging script is not a substitute for these checks.
4. Review every proposed public file, including filenames and nested JSON, for real personal information, internal identifiers/addresses, private endpoints, connection strings, credentials, tokens, SAS parameters, and third-party notices. Automated checks cannot establish that data is synthetic or redistributable. Do not reproduce any discovered secrets in review reports; remove or replace affected assets through an approved process. Never include Cube-only connection instructions.
5. Ask the owner to confirm redistribution rights for every source and choose a suitable data license, with an explicit decision about documentation and tooling coverage. Operational data is approved under CC0 1.0 only; complete the remaining budget/event and code/documentation decisions separately. Do not broaden the operational data dedication to repository code or documentation.
6. Add each approved file by its exact relative path to the file list. No wildcards or automatic directory inclusion are used. Include approved license files in the list when they exist. The current list selects learner documentation, the operational deployment script, and packaging tools; it is not evidence of publication approval.

## Build a Local Candidate

```powershell
pwsh -NoProfile -File ./scripts/package-release.ps1 -Version 0.0.0-review -CreateZip
```

The command creates a single local ZIP under `dist/` with a `northstar-sample-data/` top-level directory. It preserves paths, includes only listed files, then checks archive entry names and SHA-256 content hashes against the selected files. Existing packages are never overwritten. The version is caller-supplied; use a review label for local tests, not an asserted public release version. No Git operation or network call is performed by the script.

Git metadata, unrelated files, secrets, and generated packages must never be added to the allowlist. The script blocks common private/generated paths and unapproved file categories, but an innocuously named data or text file can still contain secrets. The ignore rules are convenience guards, not a security review or an eraser for previously tracked files. ZIPs and `dist/` are excluded from version control by the supplied ignore rules.

## Operational Releases

The **Operational Data Releases** workflow is active for daily publication at 13:20 UTC, after the Fabric export starts at 12:00 UTC. Activation was approved and the workflow pushed to `main` on 2026-11-20; the first scheduled end-to-end run remains to be verified. GitHub scheduled execution can be delayed and is not a completion dependency on Fabric. A scheduled attempt rejects stale/future completion markers and fails rather than publishing yesterday's data when today's export is incomplete.

Manual runs default to drafts. Leave the optional `run_id` blank to select the newest completion timestamp, or supply a specific completed Fabric run ID. Enable the manual `publish` input only when publication is intended. The workflow uses `main` and the `sample-data-publish` environment, nonsecret Azure settings, exact OIDC trust, and container-scoped Storage Blob Data Reader access. GitHub `contents: write` permits release operations; it does not grant Azure write access.

The workflow downloads only from `operational-data/runs/`, rejects folders without a valid `_SUCCESS.json`, and requires exactly eight CSVs plus the marker. Downloads use Entra authentication, chunk integrity checks, and matching ETags; a final blob inventory/ETag check detects changes during download. No storage keys, SAS tokens, SQL queries, or blob writes are used.

Before creating a draft, preparation checks the marker inventory, file byte sizes, strict UTF-8 without BOM, header column counts and primary-key column, CSV field counts, and parsed record counts. Parsing supports quoted commas and embedded newlines. These checks do not revalidate every SQL type/date/null representation or compare current values against the database. Original CSV bytes remain unchanged.

The draft contains ten explicit assets: eight individual CSVs, a primary `operations-data.zip`, and an optional `operations-data-validation.zip`. The data ZIP contains only the eight CSVs under `operations-data/`. The validation ZIP contains `_SUCCESS.json`, `release-manifest.json`, and `SHA256SUMS.txt` under a separate `validation/` folder. Extract both beside each other to verify CSV hashes using the paths in the checksum file. GitHub's individual asset list is flat; the folder structure is provided by the ZIP downloads, not by moving CSVs into regular Git files.

Release notes lead with the data download and link to validation separately. Those download links become available after publication; draft reviewers can use the asset list. ZIP entry names and uncompressed content hashes are checked before upload. SHA-256 hashes are compared with GitHub's uploaded asset digests and sizes. They establish asset integrity, not independent source correctness. The operational data dedication is CC0 1.0; repository code and documentation licensing is not selected by this workflow. Repository and Azure source paths retain their existing `operational-data` naming; `operations-data/` is the consumer ZIP folder.

Tags include the completion timestamp and full Fabric run ID. Draft uploads are verified before publication. A repeat publication attempt skips an already-published snapshot only after checking its CSV digests, sizes, and stored validation manifest against the prepared snapshot. Existing incomplete drafts and unmatched Git tags are refused, not overwritten or automatically repaired. Failures before verified publication never trigger cleanup; partial drafts remain unpublished for separate review. No mutable latest-release alias is maintained.

Publication retention keeps the newest seven unprotected operational snapshots plus all course-protected releases. The first release linked in the repository guide is explicitly protected in the workflow's `PROTECTED_OPERATIONAL_TAGS` JSON array. Add a snapshot there before using its link permanently in a course. Cleanup excludes drafts, prereleases, other datasets, and protected tags; it checks each deletion target again before deleting its release and assets. Git tags remain. Cleanup runs only after publication or a verified already-published result, and stops for review if more than ten deletions are proposed or the active snapshot would fall outside the rolling window. Azure's seven-day blob lifecycle is separate and does not remove GitHub assets.

The publisher defaults to preview; GitHub execution explicitly supplies `-Apply`. Local tests use a simulated GitHub API to verify publication ordering, duplicate handling, protected retention, and failure behavior without changing real releases. End-to-end scheduled execution remains to be verified after approved activation. GitHub Actions failures use repository/account notification settings; Fabric pipeline failure email does not cover this separate job.

Local preparation and focused validator tests can be run without GitHub mutation:

```powershell
pwsh -NoProfile -File ./scripts/prepare-operational-release.ps1 -Directory $exportDirectory -OutputDirectory ./dist/operational-draft-review
pwsh -NoProfile -File ./scripts/test-operational-release.ps1 -SourceDirectory $exportDirectory
```

The export directory must already contain the actual eight CSVs and marker. Preparation refuses existing output directories. Tests use temporary header-derived and isolated parser fixtures, not substitute Northstar source snapshots; no cloud or GitHub operations are performed by the test script.

## Before Public Release

**Required step: repository protection (pending).** Configure and verify these controls before the owner makes the repository public; this checklist does not apply them:

1. Protect `main` with an enforced GitHub ruleset requiring pull requests and code-owner approval. Block force pushes and branch deletion, limit bypass permissions, and confirm the repository plan supports enforcement.
2. Add CODEOWNERS coverage for workflows, publishing/validation scripts, and the ownership file itself. Assign authorized maintainers and verify a valid approval path for maintainer-authored changes; authors cannot approve their own pull requests.
3. Review collaborator, team, app, and automation access; retain only necessary write permissions. Preserve the main-only publishing environment and Azure OIDC trust, and keep release publication off pull-request triggers.
4. Verify the effective rules, ownership coverage, and bypass list. Public visitors can read and fork the repository, but cannot edit its workflows without write access. Authorized owners can still change these controls; do not describe the workflow as immutable.

Complete the source, schema, privacy, redistribution, and license checks above. Recheck official product documentation and test the intended learner setup separately when authorized; no live service work is part of this local repository task. SharePoint list column compatibility, tenant feature availability, SQL Server import mappings, network/gateway setup, and the event example's Lakehouse lookup remain unverified.

Use immutable release labels such as `v1.0.0` only after approval. Keep the reviewed file list, export metadata, parsed row counts, and a SHA-256 checksum of the final ZIP with the release record. Never silently replace a release ZIP; issue a new version for data, schema, or documentation changes. Each course should cite the exact version used in its recordings, not a mutable branch archive. Publication and creation of remote download links require separate approval and are not performed here.

Return to the [repository guide](README.md).