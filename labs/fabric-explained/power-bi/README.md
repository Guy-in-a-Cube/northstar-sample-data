# Fabric Explained - Power BI

Create the Northstar semantic model in Fabric with the supplied notebook, then connect the supplied report to that model in Power BI Desktop. These are the two setup assets; no separate model export or project folders are required.

## Files

| Artifact | Purpose |
| --- | --- |
| [nb_create_northstar_semantic_model.ipynb](nb_create_northstar_semantic_model.ipynb) | Self-contained notebook that creates a new model, performs its initial refresh, reads back its definition, and runs DAX checks. |
| [Northstar Property Health.pbix](Northstar%20Property%20Health.pbix) | Live-connected report with the Property Health page and two navigation bookmarks. Connect it to your own newly created model. |

The embedded model contains 11 tables, 106 declared columns, 59 measures, 22 relationships, and the supplied business descriptions and AI instructions. All 11 table partitions use **Direct Lake on OneLake** against the Warehouse's `dw` tables. Property-image measures and the report's property-image visual have been removed; no image files or image hosting are needed.

## Prerequisites

- A Fabric workspace on a supported capacity, with Contributor access to create the model and permission to read the Warehouse through OneLake.
- A loaded `wh_northstar` Warehouse. Follow the [Warehouse guide](../warehouse/README.md) and [pipeline guide](../pipelines/README.md) before creating the model.
- A Fabric notebook session with Semantic Link available. The notebook uses the built-in `notebookutils` and `sempy.fabric` libraries; no separate model file or Lakehouse attachment is required.
- A current Power BI Desktop build, signed in to the account that can access your lab semantic model. Build permission is required to connect and author the report; appropriate Power BI/Fabric licensing is also required.

See the [repository download guide](../../../README.md) for lab files and the separately released source datasets.

## Create the Semantic Model

1. In your lab workspace, import [nb_create_northstar_semantic_model.ipynb](nb_create_northstar_semantic_model.ipynb) as a Fabric notebook.
2. Edit the inputs in Cell 2. Leave `workspace_name` blank to use the notebook's workspace, or enter the target workspace's name. Set `warehouse_name` to your loaded Warehouse.
3. Choose an unused `semantic_model_name`. For the course, use `sm_northstar` if that name is available. The supplied test default is `sm_northstar_test`; if you keep it or choose another name, use that actual name when connecting the report and creating the data agent.
4. Select **Run all**. The notebook checks the workspace, Warehouse, and name before creating anything. It binds the embedded model to your selected Warehouse, creates it, and waits for its initial refresh.
5. Confirm the saved-definition checks pass and the final output shows row counts for all 11 tables, Bookings, Customers Served, and Total Revenue. The output also includes the model ID and a link to the new model.

The notebook creates a new model; it does not update or overwrite an existing model. To repeat the setup, choose another unused name. If creation succeeds but refresh or validation fails, the model remains in the workspace for inspection. Review the underlying error and data permissions before retrying; do not rerun creation assuming the model was removed.

## Connect the Report

1. Open [Northstar Property Health.pbix](Northstar%20Property%20Health.pbix) in Power BI Desktop and sign in with your lab account.
2. Replace its saved reference-model connection with your own model. Use **Transform data > Data source settings > Change Source**, select your lab workspace and the model created by the notebook, and confirm the change. If Desktop initially reports that the saved source is unavailable, dismiss that message and change the source.
3. Confirm the Property Health page loads. Test the property slicer and both bookmarks, **Property Health View** and **Booking Risk View**, and compare the report results with your loaded Warehouse using the same filters.
4. Save your connected working copy. If publishing the report, select your intended lab workspace and verify the published report is connected to your lab model.

The report is live-connected and contains no embedded data model. Its saved connection identifies a reference service model; that binding is not a usable learner default and does not grant access. Always reconnect it to your own model. No source credentials, refresh schedules, or permission assignments are supplied.

The notebook does not publish the report or configure ongoing semantic-model refreshes. The [Warehouse refresh pipeline](../pipelines/README.md) loads Warehouse data only; it does not refresh the Power BI semantic model. After later Warehouse loads, refresh the semantic model in Fabric as needed.

## Troubleshooting

- **Model name already exists:** choose a new name in Cell 2. Existing models are never replaced.
- **Warehouse not found or capacity check fails:** check the workspace and Warehouse names, capacity assignment, and your access.
- **Refresh or query fails:** inspect the retained model and the notebook's error. Check OneLake data access and semantic-model/query permissions; do not convert Direct Lake partitions to bypass an access problem.
- **Desktop cannot open the saved source:** reconnect the report to your lab model as described above, and confirm your account has Build permission.
- **Report results differ:** confirm the report uses the intended model, the Warehouse is loaded, the model is refreshed, and the compared filters match.

## Verification Status

On November 23, 2026, the maintainer confirmed that the image-free notebook created and validated a new model successfully, and that the report could be opened and connected to that model.

Offline checks verified the embedded checksum, source-model fidelity, model inventory, Direct Lake settings, AI instructions, connection rebinding, and notebook syntax. The report has no active property-image visual or external property-image references, and its inspected field bindings resolve. Two bookmarks retained empty state for the deleted image visual during inspection; no image URLs or measure bindings remained in that state.

These checks do not certify every metric or a complete fresh-workspace lab run. Verify your own report results and bookmark behavior before publishing or sharing.