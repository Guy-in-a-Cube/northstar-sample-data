# Schema Evidence

The eight operational tables in `ops` were inspected directly in the source database on **2026-11-20**, using read-only system-catalog queries with database definition visibility. The definitions below are grounded in that metadata, not inferred from CSV values. No business records were read.

The [table deployment script](create-ops-tables.sql) recreates the inspected table structure. No data exports, business dictionary, or export metadata have been supplied. This reference covers the inspected snapshot, not a promise that the live schema will remain unchanged.

| Dataset | Files available | Verified schema, grain, and identifiers | Verified relationships and coverage |
| --- | --- | --- | --- |
| Operational Data | Table deployment script; no CSVs | Columns, SQL types, nullability, identity settings, keys, defaults, checks, and indexes verified from metadata | No foreign keys; business joins and source date coverage not verified |
| Property Budget | Versioned workbook release; see budget guide | Five columns; 384 rows at property/calendar-month grain; logical key is property code + month, not an enforced database key | All 16 codes/names match the operational Property snapshot; January 2025-December 2026; SharePoint types unverified |
| Property Events | Versioned release: five original NDJSON files; see event guide | Eight observed fields; one event object per line; 45 distinct event IDs, not an enforced key | `property_code` matches operational Property for 43 events; two use unmatched code 999. Stored dates are 2026-08-31; two timestamps omit timezone. |

## Operational Tables

All eight tables are in `ops`, with **105 columns total**. Each primary key is clustered and single-column.

| Table | Columns | Primary key | Identity | Additional uniqueness |
| --- | ---: | --- | --- | --- |
| `Booking` | 23 | `booking_id` (`bigint`) | No | None |
| `Channel` | 8 | `channel_id` (`int`) | `(1,1)` | `channel_code` |
| `Experience` | 8 | `experience_id` (`int`) | `(1,1)` | `experience_code` |
| `Guest` | 13 | `guest_id` (`int`) | `(1,1)` | `guest_code` |
| `Property` | 13 | `property_id` (`int`) | `(1,1)` | `property_code` |
| `PropertyDailyInventory` | 10 | `property_inventory_id` (`bigint`) | `(1,1)` | `(property_code, inventory_date)` |
| `SatisfactionSurvey` | 16 | `survey_id` (`bigint`) | No | None |
| `StayNight` | 14 | `stay_night_id` (`bigint`) | `(1,1)` | `(booking_id, stay_date)` |

The unique constraints restrict duplicate combinations; they do not, by themselves, prove every table's business grain. No foreign keys exist between these tables or linking them to other tables. Matching `_code` columns and `booking_id` are not proof of an enforced relationship. Confirm business joins and cross-source identifiers separately.

### Types, Defaults, and Checks

The script preserves the inspected column order, names, lengths, precision, scale, and nullability. Types used are `int`, `bigint`, `nvarchar`, `decimal`, `bit`, `date`, `datetime2(3)`, and `uniqueidentifier`.

All tables contain `created_at_utc`, `updated_at_utc`, `is_deleted`, and nullable `source_batch_id`. There are 18 defaults: `sysutcdatetime()` for every creation timestamp, zero for every deletion flag, and `sysutcdatetime()` for update timestamps on `PropertyDailyInventory` and `StayNight`. There are no table triggers; update timestamps are **not automatically maintained when rows change**. An insert default is not an update mechanism.

Seven enabled, trusted checks are recreated: five enforce nonnegative daily-inventory quantities, out-of-service rooms not exceeding capacity, and `rooms_sellable = room_capacity - rooms_out_of_service`; two require positive stay-night numbers and occupied-room quantities.

The two additional nonunique nonclustered indexes cover `updated_at_utc` on `Booking` and `SatisfactionSurvey`. Together with the eight primary keys and six unique constraints, there are 16 indexes.

No computed columns, user-defined column types, temporal/ledger tables, memory-optimized tables, external or graph tables, specialized encrypted/sparse/FILESTREAM columns, partition compression, or row-level security predicates were found. No table-expression dependencies outside `ops` were found.

## Deploy the Tables

Intended targets are **SQL Server 2019 or later**, **Azure SQL Database**, and the writable **SQL database in Microsoft Fabric**. SQL Server 2019 is a conservative script target, not a claim that earlier versions cannot support these tables. Fabric Warehouse and read-only SQL analytics endpoints are not targets.

1. Provision or choose your own database. Prefer an empty database. The script does not create one and contains no hard-coded server or database name.
2. In VS Code with the MSSQL extension, connect to that destination database and open [create-ops-tables.sql](create-ops-tables.sql). For Fabric, use the SQL database's writable connection, not its SQL analytics endpoint.
3. Verify the selected server and database before running. Your database user needs metadata visibility for existing objects, permission to create tables in `ops`, and permission to create the schema if absent. Creating a new schema owned by `dbo` also requires the corresponding schema-ownership permission.
4. Execute the **entire file**, not a selected table block, outside an existing transaction. The script creates `ops` if missing, then the eight empty tables, constraints, and indexes in one transaction. It does not add users, roles, permissions, foreign keys, or data, and does not run `DROP`, `ALTER`, or database-setting changes.
5. On success, the final query lists the eight tables. Check their columns and constraints in your database explorer. Data loading is a separate step; no CSV exports or loading script are available yet.

If any of the eight target object names already exists, the script stops rather than silently accepting a possibly different definition. It is a create-only script, not a migration or schema-difference tool; rerunning after successful deployment intentionally fails. Other failures are reported, with rollback for runtime errors handled by the transaction. The script does not modify an existing `ops` schema's owner. Run against a database where you have the required visibility and permissions, without concurrent schema changes.

The source database and all character columns use `SQL_Latin1_General_CP1_CI_AS`. The script explicitly preserves that collation on character columns without changing the destination database collation. The source compatibility level is 170; the script does not force it on the destination.

Primary-key and default-constraint names are normalized to stable `PK_ops_*` and `DF_ops_*` names. These names are intentional deployment conventions, not a claim of byte-for-byte source DDL. Existing verified unique/check constraint names and additional index names are retained. Physical tuning options, storage layout, database configuration, and security configuration are outside this table-only script.

### Import and Privacy Considerations

Six tables use identity-generated keys. To retain exported key values, a later import workflow must deliberately preserve them, for example with controlled `IDENTITY_INSERT` or an import tool's equivalent setting. Otherwise, newly generated IDs may differ. `booking_id` and `survey_id` are not identities and must be supplied when loading their tables.

`Guest` contains `guest_name`, `email`, and `guest_external_id`. Their values have not been inspected. Review any proposed exports for personal information and redistribution rights before public release; these column names do not establish that values are synthetic.

### Verification Status

The source metadata and the deployment script are separate evidence: source inspection verifies definitions, while offline syntax and metadata comparisons can check the authored script. Deployment, rollback, rerun behavior, and data loading have **not** been executed against any destination database. Cross-platform support still requires authorized deployment tests before claiming certification.

Microsoft's [Fabric SQL database limitations and feature comparison](https://learn.microsoft.com/en-us/fabric/database/sql/limitations), checked 2026-11-20, indicates no apparent blocker for these conventional table features. Learners still need an accessible database, correct endpoint, and appropriate permissions.

## Before Adding Data

For each approved export, record its actual relative path, business purpose, provenance, export timestamp (including timezone), and coverage when known. Export timestamps and the dates represented in records are different facts.

For CSV files, verify encoding (including BOM presence), delimiter, quoting, headers, null representation, date formats, parsed data-row count excluding the header, and any embedded newlines. An empty field alone does not establish whether the source value was NULL or an empty string. Preserve identifiers as text until authoritative metadata establishes their types and formatting.

For the budget Excel workbook, follow the [workbook and maintenance contract](../property-budget/README.md). Check the named table's bounds, real date values, stored occupancy fractions, numeric precision, property/month uniqueness, and approved coverage. Excel display formats are not proof of currency semantics or SharePoint column types.

For JSON files, document the actual envelope, record grain, field paths, timestamp formats and timezones, missing-versus-null behavior, and meaningful directory layout. Do not equate file counts with event counts.

Record keys, constraints, SQL types, relationships, and business definitions only when supported by authoritative source metadata, source DDL, or a confirmed data dictionary. Values that happen to be unique in a snapshot are not proof of a primary key. Do not generate table definitions from CSV type guesses.

## Evidence Still Needed

- Approved operational CSV exports, including the supplied filenames for property and booking records.
- Property Budget planning horizon/new-property baselines. The first workbook is released under the owner's synthetic-data/CC0 approval; USD, 3% annual revenue growth, and unchanged prior-year occupancy are owner-approved, but no new rows have been generated. Consumer SharePoint setup uses Microsoft documentation, with no maintainer-run import test; actual list column definitions remain unverified. An optional CSV would need its own verified conventions.
- Property Events processing rules. The first snapshot is released under the owner's separate synthetic-data/CC0 approval. The five original root-level files, NDJSON format, eight fields, 45 records, and source checksums are verified in the [event guide](../property-events/README.md); normalization, unzoned timestamps, and unmatched-property handling need explicit decisions.
- A confirmed business dictionary, including table grain, intended joins, and the property identifier used across sources. Operational SQL definitions have been inspected; business meanings remain a separate evidence gap.
- Export dates, source date coverage, row counts, and documented CSV conventions.
- The event-processing example's expected Lakehouse Property table schema and lookup behavior.

Operational source-schema facts are verified from the metadata inspection; export verification is tracked in the operational guide. Budget workbook columns, snapshot grain, property-code matches, row count, and month coverage are verified separately from its untested SharePoint types and proposed planning horizon. Event NDJSON structure, observed field types, counts, dates, and property-code matches are verified for the released files, not guaranteed for future events. Business definitions, full operational source date coverage, and event processing rules still need evidence. All three datasets have separate owner-approved CC0 data dedications; maintainer-owned repository code and documentation have a separate CC0 approval under [LICENSE](../LICENSE). Return to the [repository guide](../README.md).