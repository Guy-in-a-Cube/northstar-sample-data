# Fabric Explained

Lab materials for building the Northstar analytics workflow in Microsoft Fabric: ingest operational data, process property events, load a dimensional Warehouse, and orchestrate the refresh.

Sample data is distributed separately through GitHub releases. Start with the [repository download guide](../../README.md) for the operational CSVs, property-budget workbook, and property-event JSON files. This folder contains reusable lab artifacts, not a one-click workspace deployment.

## Available Materials

| Section | Contents |
| --- | --- |
| [Copy Job Ingestion](guides/copy-job-ingestion.md) | Operational SQL-source setup, eight SQL-to-Lakehouse mappings, incremental/upsert settings, and connection and verification requirements. |
| [Warehouse](warehouse/README.md) | Six ordered SQL scripts creating the `ctl` logging objects, five dimensions, six facts, and their load procedures. |
| [Notebooks](notebooks/README.md) | The Fabric Python property-event notebook, with import instructions, Lakehouse prerequisites, and expected processed/quarantine results. |
| [Pipelines](pipelines/README.md) | Dimension, fact, and standalone refresh definitions, with environment bindings and REST upload instructions. |
| [Power BI](power-bi/README.md) | A self-contained semantic-model creation notebook and Property Health report binary, with manual setup and reconnection instructions. |
| [Data Agent](data-agent/README.md) | NorthStar Performance Analyst instructions, selected model fields, chat questions, and manual setup and answer-review guidance. |

## Suggested Setup Order

1. Download the sample data and prepare a lab workspace on a supported Fabric capacity.
2. Prepare your operational SQL source: create the eight `ops` tables and import the released CSVs with their original IDs and audit values. Follow the [Copy Job ingestion guide](guides/copy-job-ingestion.md); the Copy Job reads SQL tables, not the release files directly.
3. Prepare the schema-enabled `lh_northstar` Lakehouse. **Before bringing any data into the Lakehouse, create the `landing`, `processed`, and `quarantine` schemas.** Then configure `cj_northstar_ops` and complete its initial load into the eight `landing` tables. Confirm SQL-endpoint visibility. Prepare the event input files and the separate `PropertyBudget` source as described in the Warehouse and notebook guides. These artifacts do not provision or ingest the sources for you.
4. Create a new `wh_northstar` Warehouse and run the six Warehouse scripts in numeric order. Creating the procedures does not execute them or load data.
5. Import the property-event notebook, attach the prepared default Lakehouse, and confirm its Python runtime and output destinations.
6. Create and upload the pipeline definitions with your own workspace, item, endpoint, and connection bindings, including the existing Copy Job item and its Fabric invocation connection. That connection is separate from the job's SQL-source connection.
7. Review all activities before running the refresh. It invokes the Copy Job, processes events, loads dimensions before facts, and records the shared load run in `ctl.LoadRun` and `ctl.LoadRunDetail`.
8. Import the Power BI model-creation notebook, set its inputs, and run it against your loaded Warehouse. Open the supplied report binary in Power BI Desktop, connect it to the newly created model, and verify the report results. No property-image setup is required.
9. Create the data agent against the semantic model created in step 8, paste the supplied instructions, and manually review its answers before publishing or sharing it.

The section guides contain the detailed prerequisites and execution instructions. The refresh pipeline loads Warehouse data; it does not refresh a Power BI semantic model.

## Remaining Materials

Additional lab materials remain planned:

| Section | Planned contents |
| --- | --- |
| `validation/` | Lab-load, transformation, and semantic-model result checks. |
| `guides/` | Further Lakehouse setup, budget/event ingestion guidance, model diagram, and data dictionary. |

## Before You Run

Use a lab environment. Warehouse load procedures modify data, and the event notebook overwrites its processed and quarantine tables. Pipeline bindings must be configured before upload or execution; no schedules, credentials, or permissions are supplied.

Verification differs by artifact: the Copy Job mappings and settings were checked against its reference definition and the operational schema, but student copy execution has not been validated. The Warehouse scripts have offline checks, the property-event notebook has been run in a separate Fabric test copy, and configured pipeline imports have been verified by read-back without execution. The maintainer confirmed that the image-free Power BI notebook created and validated a new semantic model and that the report could be opened and connected to it. The data-agent instructions and field scope were checked against the reference definition, but its newly authored questions have not been executed. See each section's guide for the exact coverage and limitations. The complete workflow has not been validated end to end in a new student workspace.