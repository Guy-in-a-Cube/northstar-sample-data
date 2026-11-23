# Fabric Explained

Lab materials for building the Northstar analytics workflow in Microsoft Fabric: ingest operational data, process property events, load a dimensional Warehouse, and orchestrate the refresh.

Sample data is distributed separately through GitHub releases. Start with the [repository download guide](../../README.md) for the operational CSVs, property-budget workbook, and property-event JSON files. This folder contains reusable lab artifacts, not a one-click workspace deployment.

## Available Materials

| Section | Contents |
| --- | --- |
| [Warehouse](warehouse/README.md) | Six ordered SQL scripts creating the `ctl` logging objects, five dimensions, six facts, and their load procedures. |
| [Notebooks](notebooks/README.md) | The Fabric Python property-event notebook, with import instructions, Lakehouse prerequisites, and expected processed/quarantine results. |
| [Pipelines](pipelines/README.md) | Dimension, fact, and standalone refresh definitions, with environment bindings and REST upload instructions. |
| [Power BI](power-bi/README.md) | A combined `sm_northstar` TMDL and Property Health PBIP checkpoint, with reconnection requirements and verification limits. |
| [Data Agent](data-agent/README.md) | NorthStar Performance Analyst instructions, selected model fields, chat questions, and manual setup and answer-review guidance. |

## Suggested Setup Order

1. Download the sample data and prepare a lab workspace on a supported Fabric capacity.
2. Prepare the schema-enabled `lh_northstar` Lakehouse, its operational `landing` tables, event input files, and the `PropertyBudget` source. Follow the source requirements in the Warehouse and notebook guides; these artifacts do not provision or ingest the sources for you.
3. Create a new `wh_northstar` Warehouse and run the six Warehouse scripts in numeric order. Creating the procedures does not execute them or load data.
4. Import the property-event notebook, attach the prepared default Lakehouse, and confirm its Python runtime and output destinations.
5. Configure operational ingestion through a separate Fabric Copy Job, then create and upload the pipeline definitions with your own workspace, item, endpoint, and connection bindings.
6. Review all activities before running the refresh. It processes events, loads dimensions before facts, and records the shared load run in `ctl.LoadRun` and `ctl.LoadRunDetail`.
7. Configure the Power BI checkpoint for your loaded Warehouse, supply property images if needed, and verify the report in your authoring environment.
8. Prepare a working semantic model in Fabric, create the data agent against your own model, paste the supplied instructions, and manually review its answers before publishing or sharing it.

The section guides contain the detailed prerequisites and execution instructions. The refresh pipeline loads Warehouse data; it does not refresh a Power BI semantic model.

## Remaining Materials

These sections are planned but do not yet contain published lab artifacts:

| Section | Planned contents |
| --- | --- |
| `validation/` | Lab-load, transformation, and semantic-model result checks. |
| `guides/` | Lakehouse setup, ingestion mappings, model diagram, and data dictionary. |

## Before You Run

Use a lab environment. Warehouse load procedures modify data, and the event notebook overwrites its processed and quarantine tables. Pipeline bindings must be configured before upload or execution; no schedules, credentials, or permissions are supplied.

Verification differs by artifact: the Warehouse scripts have offline checks, the notebook has been run in a separate Fabric test copy, and configured pipeline imports have been verified by read-back without execution. The Power BI checkpoint passes model-loading, report-structure, and binding checks, and the maintainer reported a successful manual Desktop check; automated rendering verification was blocked. The data-agent instructions and field scope were checked against the reference definition, but its newly authored questions have not been executed. See each section's README for the exact coverage and limitations. The complete workflow has not been validated end to end in a new student workspace.