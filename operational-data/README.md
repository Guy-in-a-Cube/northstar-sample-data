# Operational Data

Northstar's core business records include properties and bookings. The intended source system is SQL Server; public CSV exports provide a separate access path without requiring Cube membership.

## Included Files and Evidence

This guide is accompanied by the [operational table deployment script](../schema/create-ops-tables.sql) and [verified schema reference](../schema/README.md). On 2026-11-20, read-only metadata inspection verified the eight `ops` table definitions, including types, nullability, identity settings, keys, defaults, checks, and indexes. No foreign keys were found; intended business joins remain unconfirmed.

No operational CSVs or business dictionary were supplied, so there is no `csv/` directory yet. Export filenames, business grain, cross-source relationships, exported row counts, and date coverage remain unverified. See [schema evidence](../schema/README.md) for the table inventory and remaining inputs.

## General Loading Paths

### Your Own SQL Database

Cube members may connect to `NorthStar_public` using instructions supplied privately through The Cube. Members may also choose the public CSV path. Do not post private connection information in issues, screenshots, configuration files, or this repository.

For your own database, follow the [deployment instructions](../schema/README.md) to create empty `ops` tables with the supplied script. Its intended targets are SQL Server 2019 or later, Azure SQL Database, and the writable SQL database in Fabric; it is not a Warehouse or SQL analytics endpoint script. Cross-platform deployment has not been tested. The script stops if any target object already exists rather than altering it.

Once approved exports are available, use an appropriate import tool for your destination. Review type mappings and identity-value preservation before importing; import-tool guesses are not authoritative schema. No import or script deployment has been performed against a database.

Readiness checks: the selected database is accessible with your own authorized connection; expected objects from the supplied schema are visible; imported row counts match the same release's export counts; identifiers, nulls, dates, and representative values survive loading. Compare live database counts only to a matching snapshot, not automatically to an older export.

### Direct Fabric CSV Imports

You can import the exports directly into your own Lakehouse or Warehouse without first creating a SQL Server database. For a Lakehouse, uploading files makes them available in Files; use a supported load or transformation workflow to create queryable tables. For a Warehouse, choose a documented ingestion method, such as a pipeline or Dataflow Gen2. `COPY INTO` requires supported storage, not a local Windows file path.

Readiness checks: the expected tables, not merely uploaded files, are present; table previews and parsed counts match the release inventory; reviewed mappings preserve identifiers, decimal precision, and dates. Choose destination item names appropriate to your project.

## Import Considerations

Encoding, BOM, delimiter, quoting, null conventions, and date formats have not been verified because no CSVs exist here. Do not assume UTF-8, comma separators, ISO dates, or empty-field-as-NULL behavior. Preserve leading zeros and avoid locale-dependent date or numeric conversions. Count parsed CSV records, not physical lines, because quoted values can contain newlines. Determine a safe reload strategy before importing again to avoid duplicates or accidental replacement.

Exports are snapshots. Live operational data can evolve independently; repeatable exercises should use one release consistently.

## Fabric Explained Only

The course's database path uses a Copy Job from SQL Server to Fabric. Check connection permissions, connector support, and gateway/network requirements before configuring it. Use full-load behavior unless an exercise establishes another mode; a watermark strategy and Copy Job merge mappings have not been selected or tested. Verified primary keys are documented in the schema reference, but their presence alone does not establish a change-tracking strategy. After a learner runs the job, its run status, per-table row counts, and destination previews are observable checks.

Direct CSV imports skip this database Copy Job step. The event-processing example expects a `Property` table in a Lakehouse. A Warehouse-only import may require changes; neither the example nor its required lookup schema is supplied here.

## Official References

Checked 2026-11-19: [Copy Job connectors](https://learn.microsoft.com/en-us/fabric/data-factory/copy-job-connectors), [create a Copy Job](https://learn.microsoft.com/en-us/fabric/data-factory/create-copy-job), [Lakehouse ingestion options](https://learn.microsoft.com/en-us/fabric/data-engineering/load-data-lakehouse), and [Warehouse ingestion options](https://learn.microsoft.com/en-us/fabric/data-warehouse/ingest-data).

These references verify product capabilities, not this dataset's import settings or a learner's environment. Target deployment, import-tool settings, connection configuration, and export-to-table mappings remain unverified. Return to the [repository guide](../README.md).