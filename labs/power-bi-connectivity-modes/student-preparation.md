# Student Preparation and Follow-Along

Complete this preparation before the course. The first five modules use prepared Power BI projects and the existing Northstar data; no PowerShell, data generators, or new Warehouse tables are required. Module 6 uses the [student Direct Lake workflow](direct-lake/README.md): your own Warehouse, one five-row restore checkpoint, and a self-contained setup notebook. Do not run the separate presenter framing notebook as student preparation.

## Before You Start

| Requirement | What You Need |
| --- | --- |
| Computer | Windows with a current Power BI Desktop version that can open Power BI Project (PBIP) files |
| Inspection tool | DAX Studio installed for VertiPaq metrics and Server Timings; connect it to the correct open Desktop instance |
| Course files | Download the repository ZIP and extract it completely, or use an existing checkout. Keep each PBIP file with its Report and SemanticModel folders. Do not open projects directly inside the ZIP. |
| Warehouse | Access to a populated Northstar Warehouse containing dw.FactStayNight, dw.DimDate, and dw.DimProperty |
| Connection details | Your Warehouse SQL endpoint hostname and database name, normally wh_northstar; these are not the Fabric portal URL or workspace ID |
| Authentication | Your Microsoft Entra organizational account with SQL read access to the three Warehouse tables |
| Thin report | Read and Build permission on the full existing sm_northstar semantic model, plus any required data/security access |

Ask your instructor or workspace administrator for the connection details and permissions before the lesson. Access to a semantic model does not automatically grant Warehouse SQL access. A workspace with suitable active Fabric capacity must already be available for the source items; this guide does not provision capacity or grant access.

If you are building your own Northstar environment, complete the [Fabric Explained Warehouse prerequisite](../fabric-explained/warehouse/README.md) and [full semantic-model prerequisite](../fabric-explained/power-bi/README.md) first. Do not repeat ingestion if your instructor has already provided the populated environment.

Make working copies of the complete project folders in a separate folder outside the repository. Keep the supplied templates unchanged. Both Import variants have the same project filename: use their parent folder names to distinguish them. Connected copies contain your environment settings and possibly cached data; do not upload or commit them.

## Projects to Prepare

| Lesson | Starting File |
| --- | --- |
| Existing-model reuse | [Northstar Property Health.pbix](../fabric-explained/power-bi/Northstar%20Property%20Health.pbix) |
| Import and compression baseline | [Import with StayNightID](import/with-staynightid/Northstar%20Connectivity%20Import.pbip) |
| Compression comparison | [Import without StayNightID](import/without-staynightid/Northstar%20Connectivity%20Import.pbip) |
| DirectQuery | [Northstar Connectivity DirectQuery.pbip](directquery/Northstar%20Connectivity%20DirectQuery.pbip) |
| Aggregations and Dual | [Northstar Connectivity Aggregations.pbip](aggregations/Northstar%20Connectivity%20Aggregations.pbip) |
| Direct Lake update/framing | [Student Direct Lake setup and follow-along](direct-lake/README.md), using your own already-loaded Warehouse |

## Connect the Warehouse Projects

Use these steps for each Import variant, DirectQuery, and Aggregations project:

1. Open the PBIP from its working-copy folder in Power BI Desktop.
2. Select Transform data > Edit parameters. Set WarehouseServer to your SQL endpoint hostname and WarehouseDatabase to your database name. The portable template's server is YOUR_WAREHOUSE_SQL_ENDPOINT; that placeholder cannot connect.
3. Apply the changes. When prompted, sign in with your Microsoft Entra/Organizational account. Use Data source settings to manage credentials if necessary; do not enter credentials into queries or model files.
4. Refresh both Import variants. For Aggregations, refresh the imported summary and both Dual dimensions together; the normal Desktop refresh processes these cached tables. Approve its read-only native summary query if prompted after reviewing it with your instructor.
5. For DirectQuery, apply the connection and load the report. It queries the Warehouse for report results; there is no imported full-detail fact snapshot to refresh. Initial connection can still check source metadata.
6. Confirm the property and month selections and the results below. Save your connected working copy and reopen it once before class.

Refresh the Import variants and Aggregations during the same quiet source period. Imported results can differ from current DirectQuery results if the Warehouse changes between refreshes; that is a freshness difference, not automatically a model defect.

## Check the Business Results

Select Downtown Central, property code 201, and March/April 2026. The historical checked results are:

| Month | Stay Nights | Rooms Occupied | Room Revenue |
| --- | --- | --- | --- |
| 2026-03 | 2,468 | 3,102 | 667,006.00 |
| 2026-04 | 2,586 | 3,095 | 664,131.00 |
| Total | 5,054 | 6,197 | 1,331,137.00 |

These values were checked against the course source; they are not guaranteed for a different or subsequently corrected dataset. Compare the same source and filters across models. PropertyCode is the stable business identifier; do not substitute an environment-specific PropertyKey.

Connect DAX Studio to the intended Desktop window and run [monthly-comparison.dax](queries/monthly-comparison.dax) for the same question. For a whole-model comparison, run this query in each Import variant:

```dax
EVALUATE
ROW (
    "Stay Nights", [Stay Nights],
    "Rooms Occupied", [Rooms Occupied],
    "Room Revenue", [Room Revenue]
)
```

The two Import variants must retain the same rows and return the same measures. There is no fixed whole-model total for every student snapshot. Omitting StayNightID removes only an unused model column, not stay-night records.

## Follow Along in Each Module

### 1. Reuse the Existing Model

Open a working copy of the supplied Property Health report and sign in. Use Transform data > Data source settings > Change Source to select your intended workspace and the full existing sm_northstar. If the saved connection is unavailable, dismiss the connection error and select the accessible model.

Confirm that the page loads, the property filter changes results, and the Property Health View and Booking Risk View bookmarks work. Save and reopen the working copy to confirm the connection persists. Do not choose Make changes to this model, which creates a local composite model. Do not use the reduced framing demo model: this report needs the broader full-model contract. The Property Health page is not required to display the same three-measure comparison table as the reduced projects.

### 2. Import

Open the connected with-StayNightID project. In Model view, confirm that FactStayNight, DimDate, and DimProperty are Import. Select the comparison property/months and run the monthly DAX query in DAX Studio with Server Timings enabled. Inspect VertiPaq execution. Querying the imported data does not fetch the latest Warehouse rows; a model refresh updates that copy.

### 3. Compression

Open both refreshed Import variants. Connect DAX Studio to each correct instance and use View Metrics. Record whole-model and FactStayNight sizes. For StayNightID in the baseline, and RoomsOccupied and RoomRevenue in both variants, record cardinality, encoding, data size, dictionary size, and hierarchy size.

Check matching row counts and business measures before comparing storage. Use VertiPaq metrics, not PBIX file size. The measured difference demonstrates the cost of retaining this unused unique ID; different business columns do not independently isolate cardinality, range, ordering, or encoding as a single cause. Export metrics to your personal working folder if requested by the instructor.

### 4. DirectQuery

Open the connected DirectQuery project and confirm all three table modes are DirectQuery. Use the same property/month filters and monthly DAX query. With DAX Studio Server Timings enabled, inspect the source SQL's joins, filters, and aggregates. Performance Analyzer can show the report visual's generated DAX; the supplied monthly query is separately authored, not that exact visual query.

Cached results can prevent a new SQL request for an interaction. Do not use a single duration, or the absence of SQL alone, to declare a universal performance winner. Never clear caches on the shared service model for this exercise.

### 5. Aggregations and Dual

Open the connected, refreshed Aggregations project. Follow the [Aggregations and Dual walkthrough](aggregations/README.md). Inspect its table modes and Manage aggregations mappings. Run the monthly DAX with Server Timings and identify the scan naming AggStayNightDateProperty. Then run [aggregation-detail.dax](queries/aggregation-detail.dax), which groups by NightNumber, and identify the source detail SQL. Reconcile each month's detail results to the monthly totals.

The original measures still reference the detail fact; the engine chooses the summary when it covers the question. Dual dimensions can participate in either path. An uncovered user-defined aggregation is not Direct Lake fallback.

### 6. Direct Lake

Before class, complete the [student Direct Lake preparation](direct-lake/README.md) in a Warehouse you own. This module requires permission to create its five-row restore checkpoint and update RoomRevenue; shared read-only Warehouse access used in earlier modules is not sufficient. Run the setup notebook to create a new comparison model, disable automatic updates on that new model only, and record your baseline.

During the lesson, use the guarded update script, rerun notebook Cell 8 before and after a completed manual model refresh, then use the exact-value reset script and refresh again. Expect only March and whole-model Room Revenue to increase by 50.00, then return to your own baseline. Do not rerun setup, overwrite the checkpoint, change the shared model, or run the presenter's append notebook. Warehouse updates can invalidate segments; this student exercise does not prove append-style residency reuse.

## Ready-for-Class Checklist

- The full-model thin report opens, filters work, both bookmarks work, and its saved connection survives reopening.
- Both Import variants connect and refresh, agree on counts/measures, and can be inspected in DAX Studio.
- DirectQuery connects and returns the comparison results with the expected three DirectQuery table modes.
- Aggregations has refreshed caches and the expected DirectQuery/Dual/Dual/Import modes; both supplied queries execute.
- All connected files and metric exports are in your own working folder, not replacing the portable templates.
- For Module 6, your own Warehouse checkpoint and new Direct Lake model are prepared, automatic updates are off on that model, and baseline results are recorded outside the notebook session.
- You have not run the framing notebook or changed the shared source/model to manufacture a demo result.

## If Something Does Not Work

| Symptom | Check |
| --- | --- |
| PBIP fails to open | Update Desktop, extract the full download, and keep both companion folders beside the PBIP. |
| Placeholder or connection error | Check WarehouseServer and WarehouseDatabase; use the SQL hostname rather than a portal URL. |
| Authentication or access denied | Sign in with the intended organizational account and ask the administrator to check SQL read access or model Read/Build permission as appropriate. |
| Wrong model in DAX Studio | Confirm the Desktop connection and whether it is the with-ID, without-ID, DirectQuery, or Aggregations instance before running the query. |
| Different Import/DirectQuery totals | Compare filters and source versions, then refresh the imported copies during a stable source period. |
| Thin report has missing fields | Reconnect to the full sm_northstar, not the reduced comparison/framing model. Do not convert the report to composite as a workaround. |
| No fresh source-query event | Confirm DirectQuery mode and the correct connection, enable Server Timings, and consider local query caching. Use the provided captures for reference, not as evidence of your own execution. |

See the [query capture notes](queries/README.md) for examples and their interpretation limits, and the [Direct Lake guide](direct-lake/README.md) for its additional permissions, setup, recovery and verification limits. The new student Direct Lake workflow has offline validation; a fresh student-environment pilot is still pending.