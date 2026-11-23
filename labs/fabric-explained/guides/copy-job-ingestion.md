# Operational Ingestion With a Copy Job

Use a Fabric Copy Job named `cj_northstar_ops` to populate the eight operational tables in `lh_northstar.landing` from your own SQL source. This guide supplies manual setup instructions and mappings, not an importable Copy Job definition, database-import script, or scheduled deployment.

The lab's operational path is:

```text
Released operational CSVs -> SQL ops tables -> cj_northstar_ops
                         -> lh_northstar.landing -> notebook and Warehouse loaders
```

The reference Copy Job reads Azure SQL tables. It does not read the release ZIP or CSVs directly. The budget workbook and event JSON follow separate paths; they are not inputs to this Copy Job.

## Prepare the Source and Lakehouse

1. Download the operational CSV release specified by your course from the [repository download guide](../../../README.md). Extract the eight CSVs; the ZIP itself is not a data source.
2. In a new operational Azure SQL database, run [create-ops-tables.sql](../../../schema/create-ops-tables.sql) to create the eight empty `ops` tables. This is the operational source schema, not the Warehouse schema. The script does not import CSV data and stops if the target tables already exist.
3. Import each CSV into its same-named `ops` table using a SQL loading tool appropriate to your environment. Follow the download guide's UTF-8, headers, quoting, NULL, date, timestamp, decimal, and Boolean conventions. Preserve exported identity values and supplied audit timestamps; do not regenerate IDs or replace `updated_at_utc` with the import time. Confirm all eight source tables are populated before configuring the Copy Job. No CSV-to-SQL importer is supplied here.
4. Create a schema-enabled `lh_northstar` Lakehouse in your lab workspace and prepare the `landing`, `processed`, and `quarantine` schemas. Use a new lab destination: full-load operations can replace existing landing data.
5. Create your Fabric Azure SQL source connection with access to the populated operational database, and obtain permission to write to the destination Lakehouse. Store authentication in Fabric connections, not in repository files. If using another SQL source connector, review its supported incremental settings rather than assuming the Azure SQL configuration transfers unchanged.

## Configure the Copy Job

1. Create a **Copy job** item named `cj_northstar_ops` in your lab workspace.
2. Select your Azure SQL connection and operational database. Select the eight `ops` tables listed below, with all their columns. Do not point the job at `dw`, the Lakehouse SQL endpoint, or a ZIP download URL.
3. Select your own `lh_northstar` Lakehouse as the destination, using its `Tables` area and the `landing` schema. Map each table to the same table name; do not flatten the schema into a name such as `landing_Booking`.
4. Configure the per-table source read and destination write settings using the captured settings and key mappings below. Keep each source column mapped to its same-named destination column. Inspect the inferred types before running; selecting tables alone does not prove correct typing.
5. Review the full-load replacement warning, then run an initial load into your lab destination. Use Copy Job monitoring to confirm completion and inspect all eight landing tables. Confirm their visibility through the Lakehouse SQL analytics endpoint before running Warehouse loaders.
6. Configure the refresh pipeline to invoke this existing job using your own item and connection bindings. Do not add an independent schedule for this lab; the refresh pipeline orchestrates its execution.

The initial materialization must finish before the notebook needs `landing.Property` or the Warehouse loaders read the operational tables. An imported pipeline definition or a CSV placed in Lakehouse Files does not satisfy this prerequisite.

## Table and Key Mappings

| Source Table | Destination Table | Destination Upsert Key | Incremental Column |
| --- | --- | --- | --- |
| `ops.Booking` | `lh_northstar.landing.Booking` | `booking_id` | `updated_at_utc` |
| `ops.Channel` | `lh_northstar.landing.Channel` | `channel_id` | `updated_at_utc` |
| `ops.Experience` | `lh_northstar.landing.Experience` | `experience_id` | `updated_at_utc` |
| `ops.Guest` | `lh_northstar.landing.Guest` | `guest_id` | `updated_at_utc` |
| `ops.Property` | `lh_northstar.landing.Property` | `property_id` | `updated_at_utc` |
| `ops.PropertyDailyInventory` | `lh_northstar.landing.PropertyDailyInventory` | `property_inventory_id` | `updated_at_utc` |
| `ops.SatisfactionSurvey` | `lh_northstar.landing.SatisfactionSurvey` | `survey_id` | `updated_at_utc` |
| `ops.StayNight` | `lh_northstar.landing.StayNight` | `stay_night_id` | `updated_at_utc` |

These are source row IDs, not Warehouse surrogate keys or business codes. Preserve business-code columns too: Warehouse joins use values such as `property_code`, `guest_code`, and `channel_code`. `property_code` is not interchangeable with `property_id`.

## Column Contract

Every source column maps to the same destination column name; no renaming, projection, or row filter is specified by this guide. The [operational schema](../../../schema/create-ops-tables.sql) is the complete per-table column and source-type reference. Keep all columns, including IDs, business codes, audit fields, `source_batch_id`, and `is_deleted`, even when a particular Warehouse loader does not consume them.

| Source SQL Type or Property | Required Destination Contract |
| --- | --- |
| `int`, `bigint` | Preserve integer values without narrowing or converting IDs to floating point. Numeric date keys remain integers. |
| `decimal(18,2)` | Preserve revenue and amount values with their decimal precision and scale. |
| `decimal(5,2)` | Preserve survey scores with their decimal precision and scale. |
| `bit` | Preserve Boolean meaning, including false and true soft-delete flags; do not turn values into text. |
| `date` | Preserve calendar dates without introducing a timezone shift. |
| `datetime2(3)` | Preserve millisecond precision. Audit and incremental values are UTC; verify their actual Delta and SQL-endpoint representation rather than silently applying local time. |
| `nvarchar(...)` | Preserve text, Unicode characters, NULL, and empty strings as distinct values. |
| `uniqueidentifier` | Preserve the supplied GUID value and NULL in `source_batch_id`; a textual representation must retain the full value. |
| `IDENTITY` source columns | Copy their exported values. Destination Delta tables do not need to generate new identities. |

The reference job uses `TabularTranslator` without explicit column mappings. Therefore this contract is something to inspect and verify against the inferred destination, not a claim that every connector conversion has been tested. The captured conversion settings allow data truncation and do not treat Booleans as numbers. Do not accept truncated text or changed numeric precision as a valid lab result; correct your mapping or conversion settings before proceeding.

## Captured Load Settings and Limits

The reference definition retrieved on November 23, 2026 contains these settings:

| Setting | Captured Value |
| --- | --- |
| Source / destination types | `AzureSqlTable` / `LakehouseTable` |
| Top-level `jobMode` | `CDC` |
| Per-table source `readMethod` | `SnapshotPlusIncremental` |
| Per-table incremental column | `updated_at_utc`, SQL `datetime2` |
| Destination `writeBehavior` | `Upsert` |
| `fullLoadBehavior` | `Truncate` |
| Partitioning / staging | `None` / disabled |
| Destination change data feed | Disabled |
| Job timeout / retry | 12 hours / 0 retries |

The top-level `CDC` discriminator alone is not an instruction to enable SQL CDC or proof of physical-delete propagation. Match the per-table incremental-column settings and confirm how your connector exposes them in Fabric. The table settings, not a label alone, define the reference mapping recorded here.

Full-load behavior applies to a full snapshot or reload, not to every incremental execution. Treat resets or full reloads as potentially destructive to the landing tables and review them before running. Stable source IDs and upserts are intended to avoid appending duplicates, but repeat-run correctness still needs to be tested in your own job.

Released files are static snapshots. Running the job later does not generate new business data. If you intentionally change source rows in a lab, keep their IDs stable and advance `updated_at_utc`; watermark-based copying cannot discover a changed row whose incremental value does not advance. Review equal-timestamp boundary handling in your connector rather than assuming an untested rule.

Do not filter `is_deleted` rows out of the Copy Job. A soft-delete flag change must be available downstream, with an updated incremental timestamp. Do not assume a physically removed source row will be propagated by a watermark-based configuration.

The existing Warehouse loaders are not a complete incremental-delete solution. For example, the booking loader filters `is_deleted = 0` and upserts active rows; a later soft delete does not automatically remove a previously loaded `dw.FactBooking` row. This guide preserves those procedures for the static-snapshot lab. Demonstrating incremental deletions would require a separately reviewed Warehouse policy and implementation.

## Pipeline Bindings

| Binding | Purpose |
| --- | --- |
| Copy Job SQL-source connection | Authenticates access to your operational SQL database. Configure it inside the Copy Job. |
| Destination workspace and Lakehouse | Directs the Copy Job to your own `lh_northstar` item and `landing` tables. |
| Copy Job item ID | Identifies the created job for the pipeline's `Load Operational Data` activity. |
| Pipeline Fabric connection | Authorizes invocation of the Fabric job. This is separate from its SQL-source connection. |

Follow the [pipeline binding instructions](../pipelines/README.md#bindings). The placeholder ending in `0006` identifies the Copy Job item; the one ending in `0007` identifies the pipeline's Fabric invocation connection, not the job's SQL-source connection. The pipeline already contains `InvokeCopyJob`; no additional Copy activity or external ADF invocation is needed.

## Checks Before Continuing

- Confirm the initial Copy Job run completed and all eight `landing` Delta tables exist with the expected schema, row IDs, columns, NULL values, dates, and numeric precision.
- Compare source and landing row counts for the selected static snapshot, including soft-deleted rows. Warehouse counts can differ because its loaders filter and transform the data.
- Test an unchanged repeat run for duplicate keys and row-count stability. If testing updates, confirm a changed source row with an advanced timestamp updates the corresponding landing row rather than appending another copy.
- During a pipeline test, confirm that success of `Load Operational Data` means the Copy Job completed before `Process Property Events` begins, not merely that a job request was accepted. Import validation did not exercise this behavior.
- Inspect Copy Job monitoring separately from `ctl.LoadRunDetail`: the latter is written by the Warehouse load procedures, not a source of per-table Copy Job copy counts.
- Only then proceed with the [Warehouse](../warehouse/README.md), [notebook](../notebooks/README.md), and [pipeline](../pipelines/README.md) setup and execution instructions.

## Verification Boundaries

Table pairs, upsert keys, incremental columns, and captured settings were inspected from the existing Copy Job definition and checked against the repository's operational schema and loader references. The complete inferred destination types, initial/repeat copying, reset behavior, physical deletes, and pipeline invocation completion have not been runtime-validated for a student environment.

No Copy Job or pipeline was created, executed, changed, or scheduled to produce this guide. No source database or Warehouse was modified. Live database names, workspace/item IDs, connection IDs, and credentials are not distributed here. Property budgets and event-file processing remain separate prerequisites.