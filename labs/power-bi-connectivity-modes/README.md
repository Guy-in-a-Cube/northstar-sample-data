# Power BI Connectivity Modes

## Students Start Here

Use the [student preparation and follow-along guide](student-preparation.md) for prerequisites, working copies, connection steps, result checks, and all six course modules. Complete setup before the lessons. Module 6 has a [student Direct Lake workflow](direct-lake/README.md) against your own loaded Warehouse; do not run the separate presenter framing notebook as student preparation.

## Purpose and Status

Build one reusable Northstar demo kit for three formats:

- Six-module course: approximately eight minutes per module.
- Sixty-minute session: 50 minutes of content plus 10 minutes of Q&A, emphasizing compression, Import/DirectQuery, and Direct Lake incremental framing.
- Ten-minute Guy in a Cube video: selected comparisons and tradeoffs, not three setup tutorials or another dedicated Direct Lake walkthrough.

Status updated 2026-11-27: the instructor confirmed completion of the presenter framing reset/manual-refresh verification, the demo rehearsals, the Import compression checks, and the thin-report reconnection checks. The prepared projects and query captures support guided follow-along with prerequisites. The student guide now includes a separate Direct Lake setup notebook and guarded Warehouse update/reset exercise. The new student workflow has offline validation only; a fresh student-environment pilot is pending. Instructor-reported completion is not an independent setup study or a controlled timing benchmark. No numerical compression results are published without a retained metric capture.

The source research and pilot observations below are dated evidence, not a new list of student readiness blockers. Portable Git versions use placeholder bindings; keep your configured Desktop copies and caches local. Earlier generators and supplemental compression samples were retired. Report modernization remains deferred.

## Guiding Approach

**Warehouse first; supplemental data only for a demonstrated gap.** Research the existing tables and model before deciding which artifacts to build. Do not assume compression needs a separate model or dataset.

The learner experience is: open a prepared report/model, connect or reconnect through the supported Power BI interface, authenticate, verify a familiar result, and inspect the behavior. Learners do not run PowerShell scripts, generate sample files, or deploy an additional business schema.

For controlled student Direct Lake framing, the self-contained notebook creates a new three-table model against the student's own Warehouse. One five-row control checkpoint supports a reversible update; it is not a new business schema. Keep shared data/models and the presenter append experiment separate.

Reuse the loaded `wh_northstar` and the existing Direct Lake `sm_northstar`. The Import comparison model should also support compression inspection if its real columns meet the teaching objectives. Add a separate asset only when research and measurements show why it is necessary.

Start from Fabric Explained's loaded Warehouse and working-model checkpoint; do not repeat its ingestion, event processing, budget, or agent setup. Existing guidance:

- [Fabric Explained Warehouse](../fabric-explained/warehouse/README.md)
- [Fabric Explained Power BI](../fabric-explained/power-bi/README.md)

## What We Already Know

Read-only inspection of Northstar Analytics - Dev on 2026-11-24 established:

| Observation | Result |
| --- | --- |
| FactStayNight | 1,047,284 rows; RoomRevenue belongs here, not in FactBooking |
| FactBooking | 380,694 rows |
| DimProperty | 16 properties |
| Existing semantic model | Eleven Direct Lake on OneLake partitions bound to Warehouse dw tables |
| FactStayNight.RoomsOccupied | Three distinct values, ranging from 1 to 3 |
| FactStayNight.RoomRevenue | 404 distinct values, ranging from 137 to 936 |
| FactStayNight.StayNightID | 1,047,284 distinct values |
| Date/property aggregation | 22,702 groups, approximately 46 times fewer rows than stay-night detail |
| Scoped integrity checks | No duplicate date/property keys, duplicate booking/night pairs, or missing stay-date/property references observed |

Candidate comparison question: how much room revenue did Downtown Central generate in March and April 2026? Use `DimProperty.PropertyCode = 201`, not an environment-specific generated key.

| Period | Stay Nights | Rooms Occupied | Room Revenue |
| --- | --- | --- | --- |
| March 2026 | 2,468 | 3,102 | 667,006.00 |
| April 2026 | 2,586 | 3,095 | 664,131.00 |

SQL and model queries agreed on these results. Whole-fact room revenue was 271,545,702.00 and total revenue was 296,786,833.00. Room Revenue sums stay-night room revenue; Total Revenue adds experience/other revenue and subtracts discounts. Keep the definitions distinct.

These are dated observations, not fixed totals for every learner snapshot. Stay dates extend through 2026-11-27, including future dates relative to inspection; October has only 23 active stay dates. Prefer a checked historical period. Activity on every date is not proof of complete source data.

At the initial research stage, scoped Direct Lake storage metadata was inspected before processed Import measurements. The instructor subsequently confirmed completion of the Import compression checks. No controlled mode-comparison benchmark is claimed. Cardinality and row reduction identify candidates; they do not prove an Import encoding, storage ranking, aggregation hit, or speedup.

## Research Findings and Proposed Contract

The additional SELECT and model-metadata checks used existing sources only. No shared source, model, report, refresh, security, or capacity setting was changed.

| Objective | Existing Source / Observation | Decision and Remaining Evidence |
| --- | --- | --- |
| Practical compression | FactStayNight: RoomsOccupied has 3 values, NightNumber 5, RoomRevenue 404, and StayNightID is unique across 1,047,284 rows | Real-column Import checks completed per instructor confirmation; the student guide records the measurement workflow. No supplemental data justified and no unretained numerical storage claim published. |
| Types and repetition | SQL revenue is decimal(18,2); the existing model uses floating-point Number. SourceUpdatedAt has 1,502 values, not one per row | Specify numeric types explicitly. Do not assume every timestamp is high-cardinality or use unlike business columns to isolate one encoding cause. |
| Import / DirectQuery | FactStayNight with DimDate and DimProperty answers the same checked revenue question | Prepare matching full-detail projections, measures, filters, and layouts. Observe actual query paths; timings alone are insufficient. |
| Aggregations / Dual | Initial stay-date/property grouping reduced 1,047,284 detail rows to 22,702 groups | Separate model verified in Desktop: named Import summary scan for the covered query and source SQL for uncovered NightNumber detail; current totals recorded in its walkthrough. |
| Direct Lake reuse | Existing sm_northstar uses Direct Lake on OneLake; the supplied thin report already references it | Reuse without rebinding the model's source. A report connection change is not a storage-mode change or SQL fallback demonstration. |
| Incremental framing | The isolated append preserved the original file; pre-business-query residency and changed totals were observed | Presenter experiment/reset verification complete. The separate student Warehouse update/framing workflow is packaged with offline checks; it makes no append-residency claim and never targets shared data. |

All thirteen declared FactStayNight columns reported encoding code 1 in the current Direct Lake storage metadata. RoomsOccupied and RoomRevenue had resident segments; StayNightID and NightNumber did not. The latter's small reported bytes are not evidence of excellent compression. Segment metadata represented 1,048,221 rows, while SQL and DAX both still returned 1,047,284 logical rows and 271,545,702.00 room revenue. Do not substitute physical segment counts for logical business counts or treat current residency as a complete Import storage measurement. These reads can warm caches and are not a pre-query framing baseline.

Initial comparison contract, approved and exercised in the local Import pilot:

- FactStayNight: StayNightID, StayDateKey, PropertyKey, NightNumber, RoomsOccupied, RoomRevenue; preserve every stay-night row and the existing grain.
- DimDate: DateKey, Date (mapped from the Warehouse's FullDate), YearMonth. DimProperty: PropertyKey, PropertyCode, PropertyName; preserve dimension rows and native keys.
- Active, single-direction relationships from each dimension key to the matching fact key. Use identical integer keys and explicitly matching revenue types across the comparison pair; retain Number initially to align with the existing model, with two-decimal display formatting.
- Measures: Stay Nights = COUNTROWS(FactStayNight), Rooms Occupied = SUM(FactStayNight[RoomsOccupied]), Room Revenue = SUM(FactStayNight[RoomRevenue]). Reconcile currency to cents; formatting does not change the underlying numeric type.
- One small, identical comparison page showing monthly room revenue, rooms occupied, and stay nights, with property/month filters. The supplied Property Health page depends on the broader existing model and is not the report template for this reduced projection.

Minimum reusable artifacts: the existing thin report/model for trusted-model and Direct Lake reuse, plus one prepared Import model/report and its matching DirectQuery counterpart. Compression uses the Import artifact. The separate Aggregations/Dual project extends that contract; controlled framing remains a later, separately verified addition.

## Connection Pilot Status

Static inspection of the supplied [Northstar Property Health report](../fabric-explained/power-bi/Northstar%20Property%20Health.pbix) verified its live service connection to sm_northstar in Northstar Analytics - Dev, no embedded DataModel, one Property Health page with 23 visual definition files, and the Property Health View and Booking Risk View bookmarks. The original report's SHA256 remained unchanged. Desktop was not running; no report was opened or reconnected during this inspection.

The documented thin-report learner workflow is:

1. Open a working copy in Power BI Desktop and sign in with an account that can read the model and has Build permission.
2. Use Transform data > Data source settings > Change Source to select the learner's workspace and existing sm_northstar. If the saved reference is unavailable, dismiss the error and reconnect.
3. Check the page, property filter, and both bookmarks. For the comparison question, validate PropertyCode 201 in March/April 2026 against the current source snapshot rather than assuming this report already displays that exact question.
4. Save the connected working copy without overwriting the supplied original. Publishing is optional and not part of the pilot.

The Import pilot is a different operation: open the prepared Import artifact, change its Warehouse server/database through Data source settings, authenticate with Microsoft Entra ID, refresh, and verify the same business results. It needs Warehouse SQL read access, not merely Build permission on sm_northstar. DirectQuery should reuse that SQL reconnection pattern without an Import refresh. Neither operation changes the existing Direct Lake model's OneLake binding.

The local [Import pilot with StayNightID](import/with-staynightid/Northstar%20Connectivity%20Import.pbip) was created without Fabric publication and moved intact into its own folder. It has three Import partitions, twelve declared data columns, two relationships, and three measures. Desktop adds three internal row-number columns; do not mistake its total of fifteen columns for additional business fields. Warehouse projection checks passed after correcting the calendar source mapping to FullDate; the exported model was successfully re-imported offline.

The matching [Import copy without StayNightID](import/without-staynightid/Northstar%20Connectivity%20Import.pbip) omits only that unused fact column from the model and its Power Query projection/type step. It has eleven declared data columns and preserves all source rows, measures, relationships, and report content. Both folders contain a project named Northstar Connectivity Import.pbip. Configure and refresh each against the same Warehouse snapshot before comparing values and VertiPaq storage. The instructor confirmed completion of these checks on 2026-11-27. Keep connected working copies separate from the supplied templates.

Open the project in Desktop. Use Transform data > Edit parameters to set WarehouseServer to the learner's Warehouse SQL hostname and WarehouseDatabase to its database name (default wh_northstar). The saved endpoint is deliberately YOUR_WAREHOUSE_SQL_ENDPOINT. Apply the changes, use Microsoft Entra/Organizational account authentication when prompted, and refresh. This parameter workflow configures all three partitions together without scripts or raw model edits; Data source settings manages credentials and permissions. Select Downtown Central and March/April 2026, then reconcile the table with the checked baseline above. Save only the learner's connected working copy.

Import pilot verification on 2026-11-24:

- PBIR validation: zero errors and warnings. Power BI Desktop 2.159.1231.0 opened the local project successfully.
- Assisted learner workflow: the user confirmed parameter configuration, authentication, and successful refresh through Desktop, then selected Downtown Central and March/April 2026. This was one assisted test, not an independent learner study or verification of every reconnect scenario.
- Loaded modes: all three M partitions remained Import and reported Ready after refresh. The database-level state still reported Unprocessed; partition states and visible values, not that single label, establish the observed result.
- Rendering and values: fresh screenshot review showed the title, selectors, two monthly bars, and populated detail table. All six monthly values above matched a separate SELECT against the Warehouse. The month dropdown was open in the capture; its overlay was an interaction state, not a layout overlap. The scaffold's blue chart styling rendered; the authored green per-measure override did not, so do not claim that color override was verified.
- Distribution boundary: a fresh offline load of the saved model confirmed WarehouseServer still equals YOUR_WAREHOUSE_SQL_ENDPOINT. No live endpoint or credentials were exported from the connected Desktop test. Local caches/working copies are ignored only under this pilot. The reviewed temporary screenshot was removed from its external validation directory; Desktop was left open.

The DAX query tool was unavailable during the initial pilot, so its screenshot validation did not independently establish full-table totals. Later query-path captures and the instructor's 2026-11-27 confirmation of the Import/compression and thin-report checks supplement that initial test. No fresh-student usability study or controlled performance benchmark is claimed. Each student should complete the preparation guide against their own source before class.

## DirectQuery Comparison

Open the prepared [Northstar Connectivity DirectQuery project](directquery/Northstar%20Connectivity%20DirectQuery.pbip). It matches the Import project with StayNightID: the same full-detail SQL projections, twelve data columns, two single-direction relationships, three measures, and identical comparison page. All three M partitions and the model default are DirectQuery; neither dimension is Import or Dual. No aggregation table, incremental refresh policy, or shared-model change is included.

The DirectQuery M queries deliberately stop at Table.SelectColumns, using the native Warehouse column types. The copied Import Table.TransformColumnTypes steps prevented loading in the assisted Desktop test; removing those steps from all three queries resolved it. That fix is now saved in the prepared project. Model data types and SQL provider mappings remain explicit, including the Date-to-FullDate mapping and Number revenue type used by the Import baseline.

1. In Desktop, use Transform data > Edit parameters to set WarehouseServer and WarehouseDatabase to the same Warehouse used by the Import comparison. The saved endpoint remains YOUR_WAREHOUSE_SQL_ENDPOINT and the database defaults to wh_northstar.
2. Apply the parameters and authenticate with Microsoft Entra/Organizational account when prompted. The account needs Warehouse SQL read access. Initial application can check source schema; it does not import the full fact table.
3. In Model view, select each table and confirm Storage mode is DirectQuery. Select Downtown Central and March/April 2026 on the report page, then compare all three measures with the checked baseline above and the Import project against the same source snapshot.
4. Use Performance Analyzer to record a visual refresh and filter changes. Inspect the generated DAX and capture its DirectQuery SQL with DAX Studio Server Timings before claiming an observed source query path. Record cache and source conditions before comparing timings; DirectQuery does not guarantee a new SQL request for every interaction.

Verification on 2026-11-24:

- Saved definition: the corrected model passed offline export/re-import. All three partitions remained DirectQuery without type-conversion steps, with twelve data columns, two relationships, three matching measures, SQL provider metadata, and placeholder parameters. Both Import projects and the copied report content were preserved.
- Report and Desktop: PBIR validation passed with zero errors or warnings. Desktop opened the project; the user connected it and confirmed matching values after removing the type steps. Read-only inspection then confirmed all three live partitions were Ready and DirectQuery, with M expressions exactly matching the corrected saved template.
- Rendering and values: fresh screenshot review showed Downtown Central's March/April bars and detail rows. All six monthly values matched the checked baseline above; totals were 5,054 stay nights, 6,197 occupied rooms, and 1,331,137.00 room revenue. Selection handles and the subtitle placeholder belonged to Desktop's selected-visual editing chrome, not report data or a layout defect.
- Boundary: the saved template still uses YOUR_WAREHOUSE_SQL_ENDPOINT; the connected Desktop model's private settings were not exported. The reviewed temporary screenshot was removed and Desktop was left open. SQL query-path/performance evidence and full-table automated model-value checks remain pending; matching displayed values and DirectQuery metadata do not replace those checks.

The project is local only; no publication or source writes were performed. Desktop caches and working PBIX/ABF files are ignored under this folder, just as for Import.

Query capture on 2026-11-25: a [controlled DAX query and its generated SQL](queries/README.md) returned the two expected monthly rows. A session-scoped trace confirmed one DirectQuery SQL request containing both joins, property/month filters, and all three aggregates. This is not Desktop's exact visual-generated DAX, an Import trace, or a controlled performance benchmark. The raw trace was exported to ignored local storage before stopping; the reusable query files contain no private endpoint or credentials.

The matching Import capture subsequently ran the identical DAX against the Ready, with-StayNightID Import model. Both monthly rows and all six measure values agreed with DirectQuery. Its trace positively identified a VertiPaq scan and nested internal scan, with no DirectQuery events or discarded events. The captured xmSQL and interpretation are included in the query evidence above. No caches were cleared or definitions changed; the individual durations are observations, not a controlled benchmark or proof of a fully identical source snapshot.

## Aggregations and Dual

The separate [Aggregations/Dual demo](aggregations/README.md) includes a prepared project, connection/refresh steps, mappings, an approximately eight-minute demo sequence, and reset guidance. It retains DirectQuery stay-night detail, uses Dual date/property dimensions, and adds a hidden Import summary at stay-date/property grain. The existing measures and comparison page are unchanged; report modernization is deferred.

The unchanged monthly query returned the expected values and positively scanned the imported summary. The supplied NightNumber query generated detail SQL with both dimension joins, returned ten rows matching the separate DirectQuery baseline, and rolled up to the monthly totals. Offline export/re-import verified the modes, mappings, and relationships; Desktop processing left all four partitions Ready. Whole-model measures also matched the current DirectQuery source. See the demo's verification status and retained query captures for evidence, newer source totals, and remaining rehearsal checks.

## Direct Lake Framing

The [isolated framing demo](framing/README.md) now has its own Lakehouse, configured notebook, and Direct Lake on OneLake semantic model in the separately approved `northstar-sample-data` workspace. It uses frozen real Northstar rows with a 25-row latest-date holdout, leaving the shared Warehouse and model unchanged. A portable model template, notebook source, totals query, and residency query are included.

The presenter capture added one file and removed none, preserved the original file, observed the original summed-column segments resident immediately after framing and before business queries, and confirmed the 25-row increase. Reset restored the Lakehouse baseline. The automated final XMLA refresh stalled; the instructor completed a manual UI refresh on 2026-11-27 and verified 1,047,495 stay nights, 1,317,796 occupied rooms, and 271,602,367.00 room revenue. Automatic updates remain off for controlled captures. This closes the presenter reset; it does not establish an easy independent student deployment.

The [student Direct Lake guide](direct-lake/README.md) instead creates a new small model directly against each student's own Warehouse, captures five original revenues, applies a guarded total increase of 50.00, and restores exact originals. Students observe results around manual UI refreshes. An UPDATE may replace files/invalidate resident segments; this is data visibility/framing, not append-style file preservation. New student assets have offline validation only and leave live shared/presenter assets untouched.

## Build Sequence

### 1. Research Existing Tables

Map each teaching objective to candidate Warehouse columns and tables. Read-only profiling should check types, row counts, cardinality, numeric ranges, nulls, repetition, grain, date coverage, and relevant keys. Extend the existing stay-night findings only where another table offers a better teaching example.

Inspect relevant model definitions and relationships. Determine whether actual encoding/storage evidence can be obtained from the existing model, or requires processing the planned Import comparison model. Direct Lake measurements do not automatically predict Import behavior; data queries and metrics scans can warm caches.

For compression, start with RoomsOccupied, RoomRevenue, and StayNightID. Different business columns can demonstrate practical storage tradeoffs but do not isolate range, cardinality, or ordering independently. If a specific lesson cannot be shown reliably, record the gap before proposing a small supplemental example. Do not change encoding hints to manufacture a result.

Outcome: a short source/objective mapping and minimum artifact proposal in this README. Research comes before provisioning.

### 2. Agree on the Minimum Demo Contract

Choose the fact/dimension projections from the research, preserving exact key types, business grain, and a consistent revenue measure. Likely starting point: FactStayNight, DimDate, and DimProperty, adding compression candidates only when useful.

Use identical business measures, relationships, report layouts, filters, and recorded source baselines for Import/DirectQuery comparisons. Keep full detail available rather than silently compare different dataset sizes. Recheck expected results against each learner/source snapshot.

Decide the supported artifact format and reconnection workflow through a small pilot. Do not assume a live report connection, SQL source change, and Direct Lake source rebinding are the same operation. Confirm prerequisite permissions and exact new owned targets before authoring or processing.

### 3. Validate One Learner Experience

Begin with a prepared thin report reconnecting to the existing `sm_northstar`. Verify the actual binding, filters, and expected result; distinguish report connectivity from underlying model storage.

Then validate the prepared Import project's Warehouse reconnection, authentication, and refresh. Confirm that a learner can complete the steps without scripts or editing raw model definitions. Use this pattern for the matching DirectQuery artifact; do not multiply untested setup patterns.

### 4. Build Independent Demos Concurrently

After the shared contract and pilot are checked, use nonoverlapping ownership. One integration owner maintains this README and shared decisions; each builder owns only its new artifacts. No builder changes shared Northstar items.

| Workstream | Reuse and Learner Action | Dependency / Check |
| --- | --- | --- |
| Trusted-model reuse | Open/reconnect a prepared thin report to sm_northstar | Supported binding and consistent business result |
| Import/DirectQuery | Open matching prepared models/reports; change Warehouse connection and authenticate; refresh Import | Same source contract, measures, filters, results; actual query-path evidence |
| Compression | Inspect real columns in the prepared Import model where suitable | Processed Import model and observed storage components; fallback only for an identified teaching gap |
| Aggregations/Dual | Reconnect a prepared same-source model with mappings already configured; refresh its imported tables | Shared source/type/grain contract; supported Dual setup, actual aggregation rewrite and uncovered detail query |
| Direct Lake and architecture | Leverage the existing workspace model for supported connectivity, binding, and architecture inspection | Confirm OneLake versus SQL architecture and identity/security boundaries; do not convert the shared model |
| Incremental framing | Presenter uses a separately approved isolated experiment or verified capture when controlled changes are required | Confirm source/writer behavior, physical changes, framing, pre-query residency, results, and safe reset |

Compression can reuse the Import build rather than run as an independent model project. Aggregations can proceed from the agreed contract without waiting for the final Import report. Architecture research can proceed independently. Parallelism does not bypass those dependencies or authorize concurrent writes to shared models.

Keep learner artifacts minimal. Controlled source appends/replacements and detailed instrumentation are presenter preparation, not a required script-driven learner deployment.

### 5. Verify and Adapt for Three Formats

For each demo, record starting state, a few deliberate actions, observed results, and a simple reset. Verify saved modes/bindings, matching values, and the actual claimed execution path. Fewer rows or absence of SQL alone does not prove an aggregation hit.

For framing, inspect source physical changes -> frame completion -> residency before querying -> business results. Writer success alone does not prove existing files were preserved. Do not insert warming queries or full metrics scans before residency observations.

Reuse the same artifacts across formats. The course explains the workflow; the session uses prepared comparisons with longer primary demos; the video selects concise verified evidence. Final timings follow measured rehearsals including navigation, interactions, waits, and contingency. No universal faster/fresher/better ranking.

## Boundaries and Next Action

Preserve `wh_northstar`, `sm_northstar`, Fabric Explained assets, unrelated user changes, and both reference courses under `C:/github/course-builder/courses/`. Student documentation and a local Git commit do not authorize new live changes, refreshes, traces, deployment, access/capacity/settings changes, or service-item deletion.

The existing OneLake model has no SQL DirectQuery fallback. Any demonstrated SQL-based Direct Lake fallback needs separate verified architecture-specific evidence; otherwise explain the distinction without claiming an observed fallback.

Confirm exact targets and operations before execution. Keep private IDs and raw captures outside learner artifacts, never store credentials, and add files only when an agreed demo needs them. Import incremental refresh and hybrid tables remain outside scope. Committing, pushing and opening a PR for student assets does not authorize executing their live Warehouse/model operations.

**Next action:** distribute the [student preparation guide](student-preparation.md) and prepared projects, and pilot the new [student Direct Lake workflow](direct-lake/README.md) in an owned student environment. The instructor confirmed the prior preparation checks and rehearsals are complete; that does not validate the new Warehouse update/reset path. Exact visual-generated query capture and controlled timing benchmarks remain separate evidence tasks. Report modernization remains deferred. No supplemental dataset is proposed.