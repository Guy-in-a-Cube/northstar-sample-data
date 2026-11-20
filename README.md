# Northstar Sample Data

Northstar is a sample property business used across training courses. This repository brings together operational records, planned property budgets, and property events without tying the data to a single course or platform.

**Current status: the first Operational Data, Property Budget, and Property Events versions are released.** This repository is currently private, so download links require repository access until the owner makes it public. See the [verified schema and deployment instructions](schema/README.md).

## Download Operational Data

**[Download Operational Data](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/operational-20261120T170446170Z-d6fa0db4-3b98-4163-940f-36ecaef08b73/operations-data.zip)**

Extract the ZIP to get eight CSVs under `operations-data/`. It contains no verification files. The optional [validation bundle](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/operational-20261120T170446170Z-d6fa0db4-3b98-4163-940f-36ecaef08b73/operations-data-validation.zip) contains the completion marker, manifest, and checksums separately.

This link points to the protected first snapshot, not a changing latest release. Courses should use the exact snapshot referenced in their recordings. No data files need to be moved into a GitHub repository folder.

## Download Property Budget

[Download the Property Budget Excel workbook](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/property-budget-v1.0.0/NorthStar_PropertyBudget.xlsx). This version contains 384 monthly budget rows for 16 properties, January 2025-December 2026. Follow the [budget guide](property-budget/README.md) and its Microsoft documentation link to create your own SharePoint list. Mirroring is taught in the course, not in that guide.

## Download Property Events

**[Download Property Events ZIP](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/property-events-v1.0.0/property-events.zip)**

Release and individual files: [Property Events v1.0.0](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/tag/property-events-v1.0.0). Setup and data format: [Property Events README](property-events/README.md).

Extract the ZIP to get five original NDJSON files under `property-events/`, containing 45 events dated August 31, 2026. It contains no verification files. Follow the linked guide to upload the files to your own private Blob container and access them through a Lakehouse Files shortcut. Original event-type variations, two timestamps without timezones, and two unmatched-property events are preserved.

## Sources

| Dataset | Business Purpose | Source System | Download Format |
| --- | --- | --- | --- |
| [Operational Data](operational-data/README.md) | Core business records, including properties and bookings | SQL Server | Eight CSVs; data ZIP and individual release assets |
| [Property Budget](property-budget/README.md) | Planned property budgets | Maintainer's Excel; learner's SharePoint list | Versioned Excel workbook release asset |
| [Property Events](property-events/README.md) | Events associated with properties | Azure Blob Storage | Five original NDJSON files; data ZIP and individual release assets |

GitHub distributes the sample files. It is not the SQL Server, SharePoint, or blob storage source system used in course exercises. You provision your own sources from public exports, or use the member database option for operational data.

**Membership will not be required to download the public sample files once the repository is public.** Operational, Property Budget, and Property Events data have separate owner approvals for redistribution under CC0 1.0. The owner has also approved CC0 1.0 for the repository's code and documentation; public access is not enabled yet.

## Start Here: Cube Members

1. For the SQL Server path, use the private connection instructions provided through The Cube to connect to `NorthStar_public`. No private server addresses, authentication details, or connection instructions belong in this repository.
2. Alternatively, use the operational CSV download above. Members can choose either path; repository access is currently required.
3. Use your own SharePoint list for Property Budget and your own storage for Property Events. See each dataset guide for its setup and readiness checks.

## Start Here: Public Exports

1. Use the immutable dataset release referenced by your course. Download its data ZIP, or the individual CSVs from that same version. The operational link above is the first released snapshot.
2. Follow [Operational Data](operational-data/README.md) to load CSVs into your own SQL Server database, or import them directly into a Fabric Lakehouse or Warehouse.
3. Follow [Property Budget](property-budget/README.md) to create your own SharePoint list from a versioned Excel workbook. Excel remains the maintainer's authoritative source; your list is your working copy.
4. Follow [Property Events](property-events/README.md) to upload the released JSON files to your own blob storage, preserving their directory structure.

Event processing rules remain pending; the event guide records the released 45-event NDJSON source and its preserved variations. The budget guide links to Microsoft's Excel-to-SharePoint instructions; no maintainer-run import test is planned. You can prepare empty operational tables using the [SQL database deployment script and instructions](schema/README.md). Platform-specific SQL deployment/import tests are still required. Choose your own database, storage, and Fabric item names unless an exercise explicitly requires otherwise.

## Fabric Explained Example

This example describes one course's topology, not a requirement for using the dataset:

| Dataset | Example Path |
| --- | --- |
| Operational Data | SQL Server to Fabric using a Copy Job |
| Property Budget | The learner's SharePoint list mirrored into Fabric; the Excel seed itself is not mirrored |
| Property Events | Azure Blob Storage accessed through a shortcut in Lakehouse Files; separate processing is needed to produce tables |

Direct operational CSV imports into Fabric skip the database Copy Job step. They do not reproduce the database connectivity exercise.

The existing event-processing example looks up a `Property` table in a Lakehouse. Warehouse-only operational imports may require an adjustment to that example or a compatible Lakehouse table. The example code and schema were not supplied, so compatibility is not verified. Do not assume a Warehouse-only path works unchanged.

## Versions, Snapshots, and Licensing

Use immutable, versioned releases so recordings and learners can use the same files. Operational tags contain the export completion timestamp and full run ID. Courses should record the dataset tag separately from the course version. Course-pinned releases are protected from rolling cleanup; do not use an unprotected nightly snapshot as a permanent course download. Use a new version for any file or schema change rather than replacing an existing release asset.

CSV exports are snapshots. The live database may change independently, so live counts and values can differ from a recorded course or export. Operational table definitions were verified from source metadata on 2026-11-20. The protected export completed at 2026-11-20T17:04:46.170Z and contains 1,578,294 rows across eight tables. CSV conventions are in the operational guide. The budget guide records the verified property/month grain and January 2025-December 2026 workbook coverage. The event guide records observed fields and stored dates separately from unresolved timezone and processing rules. Full operational record date coverage and SharePoint types remain unconfirmed; do not infer record date coverage from the export timestamp.

Operational, Property Budget, and Property Events data assets have separate owner-approved [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) dedications. On 2026-11-20, the owner also approved CC0 1.0 for maintainer-owned repository code and documentation; see [LICENSE](LICENSE) for the full terms. This does not waive third-party rights, trademarks, or patents. Before making the repository public, complete the remaining privacy and repository-protection checks. See [validation and release operations](RELEASE.md).

Product setup references were checked against Microsoft documentation on 2026-11-19. Tenant availability, permissions, networking, costs, and end-to-end imports were not tested. See the dataset guides for official references and remaining setup gaps.