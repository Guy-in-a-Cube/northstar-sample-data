# Direct Lake Incremental Framing

Demonstrate a controlled append, an explicit frame refresh, and column residency before the first post-refresh business query. This is Direct Lake on OneLake: the model reads the isolated Lakehouse directly, not its SQL analytics endpoint, and has no SQL DirectQuery fallback.

This is the presenter-only experiment. Students should use the [owned-Warehouse Direct Lake workflow](../direct-lake/README.md), not deploy or run these recording assets as preparation.

## Recording Environment

Three separate items exist in the `northstar-sample-data` workspace:

| Item | Purpose |
| --- | --- |
| lh_northstar_framing_demo | Frozen real Northstar rows, baseline Delta tables, and file-level evidence |
| nb_northstar_framing_demo | Prepare, append, and reset only the isolated demonstration tables |
| sm_northstar_framing_demo | Three-table Direct Lake on OneLake model with the comparison measures |

The shared Northstar Warehouse and semantic model were not changed. No synthetic data, new business values, schedule, or report modernization is involved. No learner PowerShell is required.

**Status updated 2026-11-27:** the instructor confirmed completion of the append, reset, and final manual model-refresh verification. See the [retained capture](capture-2026-11-25.md) for observations and limits. Before another recording, confirm the isolated model's baseline and that **Keep your Direct Lake data up to date** is off on **sm_northstar_framing_demo** only. Do not change the shared model or run an append as student preparation. This status is instructor-reported, not a fresh automated inspection of the deployed items.

## Artifacts and Setup

- [Notebook source](nb_northstar_framing_demo.py): import into Fabric as a notebook. Attach a schema-enabled Lakehouse named `lh_northstar_framing_demo` as its default Lakehouse. Set `source_workspace_id`, `source_warehouse_id`, and `target_workspace_id` in the parameter cell. These must be actual GUIDs, not names. The portable source defaults to `prepare`; the deployed recording copy is already configured and prepared.
- [Model definition](Northstar%20Connectivity%20Framing.SemanticModel/definition.pbism): portable TMDL template, not a complete report/PBIP project. Its `OneLakeSourceUrl` parameter contains placeholder workspace/Lakehouse IDs. Bind it through your model authoring tool to `https://onelake.dfs.fabric.microsoft.com/<workspace-id>/<lakehouse-id>` before deployment. Never use the shared Warehouse as this target. The actual entities are `dbo.factstaynight`, `dbo.dimdate`, and `dbo.dimproperty`.
- [Totals query](framing-totals.dax): business visibility and warming of the two summed fact columns.
- [Residency query](framing-residency.dax): metadata-only observation of the six user fact columns. Use the same query before and immediately after framing.

The notebook needs read access to the source Warehouse's OneLake tables and write access to the new Lakehouse. The observation workflow needs semantic-model administration/XMLA access and a query client that can run INFO functions. Do not copy credentials into any artifact. Keep configured model exports and raw captures in ignored local storage.

`prepare` freezes projected source data into `Files/framing-demo/snapshot`, copies both dimensions, and withholds all fact rows for the maximum stay-date key. It checks unique keys, non-null fact columns, and dimension coverage. It refuses to replace a completed preparation. An interrupted preparation can resume only when existing target rows exactly match the frozen data.

The three source tables are read separately, not as one atomic cross-table snapshot. The first preparation's upstream Delta version IDs were not retained; its manifest reports null for those source versions. The frozen copies and validated baseline, not a claim about a simultaneous source transaction, anchor this recording.

## Controlled Capture

1. Verify automatic updates are disabled on **sm_northstar_framing_demo**. Close report tabs that could query it and stop other writers or refreshes targeting these isolated items. Do not clear caches or run a full metrics scan during the experiment.
2. Explicitly refresh the model to frame the current baseline. Run [framing-totals.dax](framing-totals.dax), then save [framing-residency.dax](framing-residency.dax) results. This warms `RoomsOccupied` and `RoomRevenue`; do not claim that every fact column is resident. Capture the notebook manifest's baseline Delta version and active file inventory.
3. Run only the configured notebook with `stage = "append"`. It reads the held-out rows from the frozen copy, not the changing Warehouse. Retain `Files/framing-demo/append-evidence.json`. The notebook requires the baseline totals and file inventory to be unchanged, a one-version advance, added files, no removed files, preservation of every original active file, and the expected final row count.
4. Inspect that physical evidence. A successful notebook run or higher row count alone does not demonstrate preservation of the old Parquet files. Do not continue a claimed controlled experiment if compaction, another writer, or an unexpected frame occurred.
5. Explicitly refresh **sm_northstar_framing_demo** and wait for completion. In a query client, a model Full refresh is the framing operation for these Direct Lake partitions. Do not refresh or query the shared model.
6. **Before running any business query**, run the residency query again and retain its results. Compare the baseline resident columns and segment rows with the post-frame observation. Do not promise segment reuse merely because the files survived. Report the actual residency observed; eviction, unexpected refreshes, or background queries can invalidate the capture.
7. Now run the totals query. Compare the result with the notebook's post-append totals and record the changed row count and measures. This proves business visibility after framing, not residency reuse by itself. Query duration is an observation, not a controlled benchmark.

The intended teaching progression is physical files -> framing -> pre-query residency -> business visibility. If residency evidence does not support reuse, retain that outcome and explain the limitation instead of substituting a writer-success message or warmed query for the missing evidence.

## Reset

Set `stage = "reset"` and run the notebook. This overwrites only the owned demo fact table from the frozen baseline; it does not reread or update the shared source, overwrite dimensions, or delete workspace items. Reset intentionally replaces files, so do not treat it as the append demonstration.

Refresh the demo model, rerun the totals query, and capture a fresh pre-append residency result. The notebook updates the manifest's baseline version/file inventory for the next run. Change the deployed parameter back to `append` for recording. Leave automatic updates disabled until controlled captures are finished, then restore the setting on this new model if desired.

## Verification Status

Verified on November 25, 2026:

| Check | Result |
| --- | --- |
| Frozen fact rows | 1,047,520 |
| Held-out stay date / rows | November 28, 2026 / 25; latest date in the data, not a complete-business-day assertion |
| Baseline fact version / files | Version 0 / one active Parquet file |
| Model Stay Nights | 1,047,495 |
| Model Rooms Occupied | 1,317,796 |
| Model Room Revenue | $271,602,367.00 |
| Model validation | Initial frame succeeded; no measure errors; all three saved template partitions are Entity / DirectLake |
| Portable model | Exported and re-imported through the modeling server; placeholder parameter retained |
| Observation queries | Both executed successfully; six fact-column segment rows returned; the two summed columns resident at baseline |
| Notebook | Prepare completed; source and configured copy passed Python syntax validation; connected copy uploaded with Lakehouse binding |

**Still pending:** authenticated confirmation of automatic updates being disabled, the append run, physical append evidence, explicit post-append framing, pre-business-query residency comparison, business-total confirmation, reset/repeat validation, and timed recording rehearsal. Do not present this as a completed incremental-framing capture yet. Report modernization remains deferred.