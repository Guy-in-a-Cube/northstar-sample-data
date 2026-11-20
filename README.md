# Northstar Sample Data

Static sample files for the fictional Northstar property business. Use the version specified by your course; files are not regenerated daily. Future updates will be published manually as new versions.

## Downloads

| Files | Download | Contents |
| --- | --- | --- |
| SQL schema | [create-ops-tables.sql](schema/create-ops-tables.sql) | Eight empty operational tables in the `ops` schema |
| Operational CSVs | [operations-data.zip](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/operational-20261120T170446170Z-d6fa0db4-3b98-4163-940f-36ecaef08b73/operations-data.zip) | Eight CSVs under `operations-data/`; 1,578,294 rows in the November 20, 2026 snapshot |
| Property Budget Excel | [NorthStar_PropertyBudget.xlsx](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/property-budget-v1.0.0/NorthStar_PropertyBudget.xlsx) | 384 monthly budgets for 16 properties, January 2025-December 2026 |
| Property Events JSON | [property-events.zip](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/property-events-v1.0.0/property-events.zip) | Five NDJSON files under `property-events/`; 45 events dated August 31, 2026 |

Individual CSVs and event files are available on their [operational](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/tag/operational-20261120T170446170Z-d6fa0db4-3b98-4163-940f-36ecaef08b73) and [event](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/tag/property-events-v1.0.0) release pages. Data is stored in release assets, not regular Git files. Downloads require repository access while this repository is private.

## Using the Files

- **SQL:** run the entire schema script in an empty destination database. Intended targets are SQL Server 2019+, Azure SQL Database, and the writable SQL database in Fabric, not Fabric Warehouse or read-only SQL endpoints. Existing target tables cause it to stop; the script creates tables, not data. Destination deployment/imports have not been tested. Preserve exported identity values when importing CSVs.
- **CSV:** UTF-8 without BOM, comma-delimited, with headers and quoted text. Unquoted `\N` means NULL; `""` means empty text. Dates use `yyyy-MM-dd`; timestamps use `yyyy-MM-ddTHH:mm:ss.fff`; decimals use a dot and bits use `0`/`1`. All rows/columns, including audit fields and soft-deletes, are included. This is not a database-wide transactional snapshot. Optional [checksums and validation](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/operational-20261120T170446170Z-d6fa0db4-3b98-4163-940f-36ecaef08b73/operations-data-validation.zip) are separate from the data ZIP.
- **Excel:** select `PropertyBudgetTable` and follow Microsoft's [Create a list based on a spreadsheet](https://support.microsoft.com/en-us/office/create-a-list-based-on-a-spreadsheet-380cfeb5-6e14-438e-988a-c2b9bea574fa) instructions in your own SharePoint site. Revenue is USD; occupancy is a fraction (`0.2322` means 23.22%). `PropertyCode` matches operational `Property.property_code`, not `property_id`. SharePoint import has not been tested here.
- **JSON:** parse one JSON object per line, not a single JSON array. Upload the extracted files to your own private Blob container if required by your course. Event-type variations, two timestamps without timezones, and two unmatched property codes (`999`) are preserved; processing rules must handle them explicitly.

## License

The released synthetic data and maintainer-owned code/documentation are dedicated under CC0 1.0, with separate owner approvals. See [LICENSE](LICENSE). Third-party rights, trademarks, and patents are not waived.