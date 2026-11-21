# Fabric Explained - Warehouse Scripts

User-defined table and stored-procedure definitions extracted from `wh_northstar` for the Fabric Explained lab. This folder contains no sample data, `demo` schema objects, system objects, users, roles, grants, ownership settings, or other security configuration.

## Before You Run

- Use a new, writable Fabric Warehouse. These scripts are not for a Lakehouse SQL analytics endpoint or the operational source database.
- The `ctl` and `dw` schemas and listed objects must not already exist. These are creation scripts, not rerunnable migrations; they do not drop or replace existing objects.
- Run complete files, including their `GO` batches, in the global numeric order below. The numbering applies across folders, not independently within each schema.
- Table scripts include their exported primary, unique, and foreign-key constraints. Fabric Warehouse declares these keys `NOT ENFORCED`; they do not validate or enforce data integrity.
- The scripts create objects only. Creating a stored procedure does not execute it or load data.

## Script Order

| Order | Script | Contents |
| --- | --- | --- |
| 001 | [Create ctl and dw schemas](001_create_schemas.sql) | Two schemas |
| 002 | [Create ctl tables](ctl/tables/002_create_ctl_tables.sql) | Two load-logging tables and their constraints |
| 003 | [Create dw dimension tables](dw/tables/003_create_dw_dimension_tables.sql) | Five dimensions and their constraints |
| 004 | [Create dw fact tables](dw/tables/004_create_dw_fact_tables.sql) | Six facts and their constraints |
| 005 | [Create ctl stored procedures](ctl/stored-procedures/005_create_ctl_stored_procedures.sql) | Four start, log, complete, and fail procedures |
| 006 | [Create dw stored procedures](dw/stored-procedures/006_create_dw_stored_procedures.sql) | Eleven dimension and fact load procedures |

Run the six files in order from 001 through 006. Object definitions within each file retain their dependency order and `GO` batch separators. The order creates schemas before tables, dimensions before facts, referenced tables before foreign keys, and logging procedures before the load procedures that call them.

## External Sources

The procedure definitions retain the lab's existing three-part source names. Prepare compatible sources in the same Fabric workspace before creating or executing the load procedures, or adapt their source references to your own item names:

| Source | Required objects |
| --- | --- |
| `lh_northstar.landing` | `Booking`, `Channel`, `Experience`, `Guest`, `Property`, `PropertyDailyInventory`, `SatisfactionSurvey`, `StayNight` |
| `lh_northstar.processed` | `PropertyEvent` |
| `PropertyBudget.dbo` | `[Property Budget]` |

The existing operational CSVs, budget workbook, and raw event JSON are inputs to separate ingestion and processing steps. Running these Warehouse scripts alone does not create the source items or load those files.

## Loading Data

For a load run, use one `LoadRunID`, start the run with `ctl.usp_start_load_run`, execute the dimension loads before the fact loads, and complete or fail the run with the corresponding `ctl` procedure. Load `FactBooking` before `FactStayNight`, because the stay-night loader reads booking facts. The dimension and fact load procedures call `ctl.usp_log_load_step` themselves.

Actual load execution and pipeline orchestration are separate from the numbered object-creation scripts. No procedure-execution script is included here.

## Verification Status

The 13 table and 15 stored-procedure definitions retain the original Warehouse SQL and batch order; formatting changes are limited to blank lines between batches and newline normalization. Offline parsing of the consolidated SQL, source-preservation, object-count, local dependency-order, and exclusion checks passed. The original schema-creation file is unchanged and contains only bare `CREATE SCHEMA` statements, without ownership or permission clauses. These scripts have not been deployed or executed in a student Warehouse.