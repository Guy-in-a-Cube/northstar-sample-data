# Student Direct Lake: Update, Frame, Restore

Use your own already-loaded Northstar Warehouse to observe data visibility in a new, small Direct Lake on OneLake model. No Lakehouse copy, sample-data generator, PowerShell, separate TMDL upload, or report redesign is needed. The model has FactStayNight, DimDate and DimProperty, with the same three comparison measures as the other lessons.

This is the student workflow for Module 6. The [presenter append/residency experiment](../framing/README.md) is separate and is not student preparation.

## Prerequisites and Boundaries

- A populated Northstar Warehouse **you own**, in your own Fabric workspace with suitable active capacity. Do not use the instructor's shared Warehouse, a production Warehouse, or a Lakehouse SQL analytics endpoint.
- Access to create and query a semantic model, run a Fabric notebook with Semantic Link available, and read the three Warehouse tables through OneLake. Contributor access and appropriate source data access are required; SQL access alone does not establish OneLake access.
- Warehouse permissions to create one small table in dbo, insert/read its checkpoint rows, and update RoomRevenue in dw.FactStayNight. No permissions or capacity are granted by this kit.
- A quiet source period: no ingestion, reloads or other writers during preparation, update and reset. Other models against your Warehouse may see the temporary change.

Every SQL script starts with an empty `@ConfirmedLabWarehouse`. In Fabric, check the workspace breadcrumb and Warehouse item to confirm it is your own isolated lab source. Run `SELECT DB_NAME() AS CurrentWarehouse;`, then enter that exact name in the script. A name match is a deliberate human confirmation, **not proof of ownership**: two workspaces can contain Warehouses with the same name.

Keep your configured notebook, SQL working copies and outputs private. Do not commit environment settings or results. The existing full sm_northstar and shared source are not setup targets. Do not reconnect the Property Health report to this reduced model.

## Prepare Before Class

1. Open [001_prepare_warehouse_demo.sql](001_prepare_warehouse_demo.sql) in the Fabric SQL query editor for your own Warehouse. Confirm ownership and set the name as described above. Run the complete script, not selected fragments.
2. Confirm `SavedRows = 5` and `ExpectedMarchRevenueIncrease = 50.00`. Preparation captures the five lowest distinct StayNightID values for property code 201 in March 2026. It creates dbo.NorthstarConnectivityRestore and saves exact original revenues; it does **not** update dw.FactStayNight. Keep this checkpoint. Preparation intentionally refuses to replace an existing one.
3. Import [nb_create_connectivity_direct_lake_model.ipynb](nb_create_connectivity_direct_lake_model.ipynb) into your Fabric workspace as a notebook. No Lakehouse attachment is needed. In Cell 2, set the Warehouse name and an unused semantic model name; a blank workspace name uses the notebook's workspace. Select Run all.
4. Confirm the final PASS, model link, March/April results and whole-model totals. The notebook creates a new model, performs its initial refresh, reads its saved definition back, and queries it. It never replaces an existing model or changes Warehouse rows. If creation/refresh fails, inspect the retained model and the reported operation before another attempt.
5. On **this new model only**, open Fabric semantic-model settings, turn **Keep your Direct Lake data up to date** off, and apply the change. Confirm it remains off. Do not change the full or shared model's setting.
6. Rerun Cell 8 only and record the monthly and whole-model baseline results. The notebook retains the first successful baseline in the current session and does not overwrite it on later Cell 8 runs. Also record it outside the session because restarting the kernel loses that in-memory baseline.

The SQL checkpoint is persistent; the notebook's baseline is not. Do not run the update before recording baseline results. If preparation already exists from a prior rehearsal, verify/reset it with the reset script instead of rerunning preparation or recreating the checkpoint.

## Follow Along

1. With automatic updates still off, run [002_update_warehouse_demo.sql](002_update_warehouse_demo.sql) in the **same owned Warehouse**, after setting its confirmation name. Expect `ChangedRows = 5` and `RevenueAboveSavedBaseline = 50.00`. Each selected row receives its saved original RoomRevenue plus 10.00. Keys, dates, rooms occupied and all other fact columns are left unchanged.
2. Rerun notebook Cell 8 only, before requesting a model refresh. Compare the current results with your recorded baseline. This is the old-frame observation; do not rerun notebook setup or its initial-refresh cell. If values have already advanced, check the setting, model selection and intervening refreshes before claiming an old/new-frame result.
3. In Fabric, request a manual refresh of the **new comparison model**. Wait for that newly requested refresh to complete and check its start time, not merely an older Completed history entry.
4. Rerun Cell 8. March Room Revenue and whole-model Room Revenue should each be **50.00 above your baseline**. March/April Stay Nights and Rooms Occupied are unchanged; April Room Revenue is unchanged. Use your recorded snapshot, not another student's historical totals.
5. Run [003_reset_warehouse_demo.sql](003_reset_warehouse_demo.sql), again confirming the same owned Warehouse. Expect `ChangedRows = 5` and `RevenueAboveSavedBaseline = 0.00`. Reset assigns the exact saved original values, not current revenue minus 10.00.
6. Manually refresh the same model again, wait for the new refresh to complete, and rerun Cell 8. All monthly and whole-model measures must match your recorded baseline to cents. Keep the checkpoint for the next rehearsal.

| Stage | Warehouse Revenue Above Saved Baseline | Model Result |
| --- | --- | --- |
| Prepared baseline | 0.00 | Record your initial monthly and whole-model values |
| Updated, before model refresh | 50.00 | Observe the previously framed values; investigate unexpected advancement |
| Updated, after completed model refresh | 50.00 | March and whole-model Room Revenue are baseline plus 50.00 |
| Reset, after completed model refresh | 0.00 | All comparison measures match the recorded baseline |

Repeating update after it is already applied changes zero rows and leaves the increase at 50.00. Repeating reset at baseline changes zero rows and leaves the difference at zero. The scripts require exactly one source row per saved ID, so missing and duplicate keys cannot cancel out in a total count. They reject mixed/unexpected revenues, invalid checkpoints, or changed selected date/property/night/rooms values. They are not a concurrency lock or a substitute for a quiet source period. Do not edit the checkpoint to bypass a rejection.

Cell 8 queries through Semantic Link. Alternatively, use DAX Studio against the new service model's XMLA endpoint, with the required model permissions, and run [monthly-comparison.dax](../queries/monthly-comparison.dax). Compare revenue to cents. No new report is required.

## What This Shows

A Direct Lake refresh frames the source data; it does not import a full fact snapshot. This model reads the Warehouse's dw tables through OneLake, not a SQL endpoint, and has no SQL DirectQuery fallback.

A Warehouse UPDATE can replace affected data files and invalidate resident column segments. This exercise does **not** demonstrate preservation of original files/segments after an append, or establish a performance benchmark. Those claims belong to the separately captured presenter experiment.

## Recovery

| Symptom | Next Step |
| --- | --- |
| Warehouse-name guard stops execution | Check ownership, workspace breadcrumb and current database before entering its name. Never remove the guard. |
| Preparation says checkpoint exists | Keep it. Use reset to verify/restore originals; do not overwrite or drop it. |
| A script rejects selected rows or checkpoint values | Stop other writers and inspect the saved/current rows with your instructor. Do not force an update or arithmetic reset. |
| Model name already exists or creation outcome is unclear | Inspect the workspace and operation first. The notebook never overwrites/deletes a model and disables request retries. |
| Initial refresh failed or timed out | The new model remains. Check its cloud connection/SSO, source access and refresh history. A timeout does not cancel the accepted request. Complete a manual refresh if needed, then run Cell 8 in the same notebook session. Do not resubmit a pending refresh. |
| After-refresh result is still old | Confirm the latest refresh finished, the correct model/source is selected, and the Warehouse change is available on OneLake. Do not rerun UPDATE to increase the amount again. |
| Query/model refresh fails after UPDATE | Use the guarded SQL reset in the same owned Warehouse regardless of model availability, then resolve the model issue and refresh it. Keep the checkpoint intact. |
| Notebook session restarted | Use the baseline you recorded outside the session and the persistent SQL checkpoint. Do not replace baseline evidence with post-update values. |

## Verification Status

Packaged 2026-11-27. Offline checks cover SQL syntax/scoped-write guards, native model metadata, notebook JSON/Python syntax, embedded checksum and binding, and mocked setup failure paths. No student Warehouse UPDATE/reset, live model creation, or live notebook run was performed for this packaging task. A fresh student-environment pilot remains necessary before claiming end-to-end readiness or observed old/new-frame behavior.

Maintainers can run the standard-library [offline setup tests](validation/test_setup.py) with `python labs/power-bi-connectivity-modes/direct-lake/validation/test_setup.py`. This is not a student setup step and makes no Fabric calls.