# Fabric Explained: Property Event Notebook

[nb_process_property_events.ipynb](nb_process_property_events.ipynb) is the Python
notebook from the Fabric Explained lab. It standardizes event types and timestamps,
validates property codes against `landing.Property`, and writes processed and
quarantined Delta tables.

## Prerequisites

- A Fabric workspace on an active capacity, with permission to run notebooks and
  write to its Lakehouse.
- A **schema-enabled Lakehouse**, attached as the notebook's default Lakehouse.
- The five extracted JSON files from the
  [property-events-v1.0.0 release](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/tag/property-events-v1.0.0)
  in `Files/property-events`. Upload the files themselves, not the ZIP. A shortcut
  to equivalent files also works; an Azure Blob Storage connection is not required.
- A Delta table at `Tables/landing/Property`, with `property_code` as an integer
  and `property_name` as text. Use the released operational `Property.csv` to load
  this table; the [repository download guide](../../../README.md) links to the
  operational data release. A CSV in Files is not a substitute for the Delta table.
- The `processed` and `quarantine` Lakehouse schemas.

The notebook uses the Fabric **Python** experience and **Python 3.12** kernel,
not PySpark. Its pandas, DuckDB, and delta-rs libraries are provided by that runtime;
no custom Environment or package-install cell is required.
Local editors may flag Fabric-only imports such as `notebookutils`; execute the
notebook in Fabric, not a local Jupyter kernel.

## Upload And Run

1. Download the notebook file and import it into your Fabric workspace using
   **Import notebook**.
2. Confirm that the notebook language is **Python** and its kernel is **Python 3.12**.
3. Add your prepared Lakehouse and set it as the default. The distributed notebook
   deliberately contains no attachment to the original workspace or Lakehouse.
4. Restart the notebook session after changing the default Lakehouse, then run all
   cells in order.

Output destinations are resolved from your default Lakehouse at runtime:

- `processed.PropertyEvent`
- `quarantine.PropertyEvent`

**Both tables are overwritten on every run.** Use a lab Lakehouse, not a production
Lakehouse. The writes are separate operations, not a transaction across both tables.
The notebook does not create source tables, download data, or provision schemas.

## Expected Results

With the released sample files and Property data: **45 loaded, 43 processed,
2 quarantined**. The two quarantined events have the unknown property code `999`.

Unzoned timestamps are treated as UTC. Unparseable timestamps become null; the
quarantine rule checks property codes, not timestamp validity. Original event-type
variants are normalized without changing the lab's validation logic.

## Verification

The notebook passes the official Jupyter notebook-format validation and Python
syntax checks. Saved outputs and execution details have been cleared.

On November 21, 2026, a separately uploaded copy completed successfully in Fabric
using Python 3.12. Only its output table names were changed to unique temporary names;
an additional test cell verified 45 inputs, 43 processed rows, 2 quarantined rows,
Delta read-back columns, preserved null room numbers, parsed timestamps, and repeat
overwrite without duplicate rows. The original notebook and its output tables were
not modified during verification.