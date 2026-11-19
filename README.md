# Northstar Sample Data

Northstar is a sample property business used across training courses. This repository brings together operational records, planned property budgets, and property events without tying the data to a single course or platform.

**Current status: documentation and local packaging tools only. No source data files were supplied.** There are no downloadable datasets or published releases yet. See the [schema evidence and missing assets](schema/README.md).

## Sources

| Dataset | Business Purpose | Source System | Download Format |
| --- | --- | --- | --- |
| [Operational Data](operational-data/README.md) | Core business records, including properties and bookings | SQL Server | CSV exports; not yet supplied |
| [Property Budget](property-budget/README.md) | Planned property budgets | SharePoint list | Seed CSV; not yet supplied |
| [Property Events](property-events/README.md) | Events associated with properties | Azure Blob Storage | JSON files; not yet supplied |

GitHub distributes the sample files. It is not the SQL Server, SharePoint, or blob storage source system used in course exercises. You provision your own sources from public exports, or use the member database option for operational data.

**Membership is not required to download or use the public sample files.** That access policy does not supply missing files or grant a license: redistribution rights and license terms are still pending confirmation before public release.

## Start Here: Cube Members

1. For the SQL Server path, use the private connection instructions provided through The Cube to connect to `NorthStar_public`. No private server addresses, authentication details, or connection instructions belong in this repository.
2. Alternatively, use the public operational CSV exports once supplied. Members can choose either path.
3. Use your own SharePoint list for Property Budget and your own storage for Property Events. See each dataset guide for its setup and readiness checks.

## Start Here: Public Exports

1. Use the immutable dataset release referenced by your course when one is available. Download its combined ZIP, or the individual files from that same version. No release or download URL exists yet.
2. Follow [Operational Data](operational-data/README.md) to load CSVs into your own SQL Server database, or import them directly into a Fabric Lakehouse or Warehouse.
3. Follow [Property Budget](property-budget/README.md) to seed your own SharePoint list from its CSV.
4. Follow [Property Events](property-events/README.md) to upload the JSON files to your own blob storage, preserving their directory structure.

These paths are blocked until the source files and verified import conventions are supplied. Choose your own database, storage, and Fabric item names unless an exercise explicitly requires otherwise.

## Fabric Explained Example

This example describes one course's topology, not a requirement for using the dataset:

| Dataset | Example Path |
| --- | --- |
| Operational Data | SQL Server to Fabric using a Copy Job |
| Property Budget | The learner's SharePoint list mirrored into Fabric; the seed CSV itself is not mirrored |
| Property Events | Azure Blob Storage accessed through a shortcut in Lakehouse Files; separate processing is needed to produce tables |

Direct operational CSV imports into Fabric skip the database Copy Job step. They do not reproduce the database connectivity exercise.

The existing event-processing example looks up a `Property` table in a Lakehouse. Warehouse-only operational imports may require an adjustment to that example or a compatible Lakehouse table. The example code and schema were not supplied, so compatibility is not verified. Do not assume a Warehouse-only path works unchanged.

## Versions, Snapshots, and Licensing

Use immutable, versioned releases so recordings and learners can use the same files. A suggested first approved version is `v1.0.0`; this is a naming recommendation, not an existing release. Courses should record the dataset version separately from the course version. Use a new version for any file or schema change rather than replacing an existing release asset.

CSV exports are snapshots. The live database may change independently, so live counts and values can differ from a recorded course or public export. Export dates, date coverage, row counts, CSV conventions, and schema details are currently unknown; no export date should be inferred from this documentation's date.

No data or code license has been selected, and no license grant or publication approval is implied. Before public release, the owner must confirm redistribution rights for all assets and choose appropriate license terms for data, documentation, and tooling. See [local validation and release packaging](RELEASE.md).

Product setup references were checked against Microsoft documentation on 2026-11-19. Tenant availability, permissions, networking, costs, and end-to-end imports were not tested. See the dataset guides for official references and remaining setup gaps.