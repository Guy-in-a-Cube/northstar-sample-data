# Schema Evidence

No source data, SQL DDL, data dictionary, or export metadata was supplied for this repository. This directory records the evidence gaps; it does not define an authoritative Northstar schema.

| Dataset | Files available | Verified schema, grain, and identifiers | Verified relationships and coverage |
| --- | --- | --- | --- |
| Operational Data | None | Not available | Not available |
| Property Budget | None | Not available | Not available |
| Property Events | None | Not available | Not available |

## Before Adding Data

For each approved export, record its actual relative path, business purpose, provenance, export timestamp (including timezone), and coverage when known. Export timestamps and the dates represented in records are different facts.

For CSV files, verify encoding (including BOM presence), delimiter, quoting, headers, null representation, date formats, parsed data-row count excluding the header, and any embedded newlines. An empty field alone does not establish whether the source value was NULL or an empty string. Preserve identifiers as text until authoritative metadata establishes their types and formatting.

For JSON files, document the actual envelope, record grain, field paths, timestamp formats and timezones, missing-versus-null behavior, and meaningful directory layout. Do not equate file counts with event counts.

Record keys, constraints, SQL types, relationships, and business definitions only when supported by source DDL or a confirmed data dictionary. Values that happen to be unique in a snapshot are not proof of a primary key. Do not generate a SQL Server table-creation script from CSV type guesses.

## Evidence Still Needed

- Approved operational CSV exports, including the supplied filenames for property and booking records.
- The Property Budget seed CSV and its SharePoint list column definitions.
- The original Property Events JSON files with their directory structure preserved.
- SQL DDL or a data dictionary, including the property identifier used across sources.
- Export dates, source date coverage, row counts, and documented CSV conventions.
- The event-processing example's expected Lakehouse Property table schema and lookup behavior.

No data parsing, exported row counts, or source-schema assertions can be verified until those assets are supplied.