# Operational Data

Northstar's core business records include properties and bookings. The intended source system is SQL Server; public CSV exports provide a separate access path without requiring Cube membership.

## Included Files and Evidence

Only this guide is included. No operational CSVs, source DDL, or data dictionary were supplied, so there is no `csv/` directory yet. Actual export filenames, table names, columns, row grain, identifiers, relationships, row counts, and date coverage are not verified. The business subjects above do not establish table names or a booking-to-property join.

See [schema evidence](../schema/README.md) for missing inputs. No SQL table-creation script is supplied because authoritative types and constraints are unavailable.

## General Loading Paths

### SQL Server

Cube members may connect to `NorthStar_public` using instructions supplied privately through The Cube. Members may also choose the public CSV path. Do not post private connection information in issues, screenshots, configuration files, or this repository.

For your own database, obtain approved exports and the verified source schema first. Create destination tables from that schema, then use an appropriate SQL Server CSV import tool. Review type mappings before importing; import-tool guesses are not authoritative schema. No database connection or import is performed by this repository.

Readiness checks: the selected database is accessible with your own authorized connection; expected objects from the supplied schema are visible; imported row counts match the same release's export counts; identifiers, nulls, dates, and representative values survive loading. Compare live database counts only to a matching snapshot, not automatically to an older export.

### Direct Fabric CSV Imports

You can import the exports directly into your own Lakehouse or Warehouse without first creating a SQL Server database. For a Lakehouse, uploading files makes them available in Files; use a supported load or transformation workflow to create queryable tables. For a Warehouse, choose a documented ingestion method, such as a pipeline or Dataflow Gen2. `COPY INTO` requires supported storage, not a local Windows file path.

Readiness checks: the expected tables, not merely uploaded files, are present; table previews and parsed counts match the release inventory; reviewed mappings preserve identifiers, decimal precision, and dates. Choose destination item names appropriate to your project.

## Import Considerations

Encoding, BOM, delimiter, quoting, null conventions, and date formats have not been verified because no CSVs exist here. Do not assume UTF-8, comma separators, ISO dates, or empty-field-as-NULL behavior. Preserve leading zeros and avoid locale-dependent date or numeric conversions. Count parsed CSV records, not physical lines, because quoted values can contain newlines. Determine a safe reload strategy before importing again to avoid duplicates or accidental replacement.

Exports are snapshots. Live operational data can evolve independently; repeatable exercises should use one release consistently.

## Fabric Explained Only

The course's database path uses a Copy Job from SQL Server to Fabric. Check connection permissions, connector support, and gateway/network requirements before configuring it. Use full-load behavior unless verified source metadata and an exercise establish another mode; no watermark or merge key is known here. After a learner runs the job, its run status, per-table row counts, and destination previews are observable checks.

Direct CSV imports skip this database Copy Job step. The event-processing example expects a `Property` table in a Lakehouse. A Warehouse-only import may require changes; neither the example nor its required lookup schema is supplied here.

## Official References

Checked 2026-11-19: [Copy Job connectors](https://learn.microsoft.com/en-us/fabric/data-factory/copy-job-connectors), [create a Copy Job](https://learn.microsoft.com/en-us/fabric/data-factory/create-copy-job), [Lakehouse ingestion options](https://learn.microsoft.com/en-us/fabric/data-engineering/load-data-lakehouse), and [Warehouse ingestion options](https://learn.microsoft.com/en-us/fabric/data-warehouse/ingest-data).

These references verify product capabilities, not this dataset's import settings or a learner's environment. SQL Server version, import-tool settings, connection configuration, and actual schema mappings remain unverified. Return to the [repository guide](../README.md).