# Aggregations and Dual

## Starting Point

Open [Northstar Connectivity Aggregations.pbip](Northstar%20Connectivity%20Aggregations.pbip) in Power BI Desktop. Reuse the loaded Northstar Warehouse from Fabric Explained, with SQL read access and Microsoft Entra/Organizational account authentication. No new Warehouse objects, data generation, or learner scripts are needed. The comparison page is unchanged from the DirectQuery project; visual modernization is deferred.

Use Transform data > Edit parameters to set WarehouseServer to your Warehouse SQL hostname and WarehouseDatabase to its database name (default wh_northstar). Apply the changes and authenticate. The prepared endpoint is YOUR_WAREHOUSE_SQL_ENDPOINT. The native summary query may require approval; it is a read-only SELECT with GROUP BY. Refresh the imported summary and both Dual dimensions before recording. Save only your connected working copy.

## Model Contract

| Table | Storage Mode | Grain / Role |
| --- | --- | --- |
| FactStayNight | DirectQuery | Every original stay-night row, including StayNightID and NightNumber |
| DimDate | Dual | One row per source date key |
| DimProperty | Dual | One row per source property key |
| AggStayNightDateProperty | Import, hidden | One row per StayDateKey and PropertyKey |

Both facts have active many-to-one, single-direction relationships to the same dimension keys. Dual lets the dimensions participate in the cached summary path or the same-source DirectQuery detail path. It does not import the full detail fact.

The summary's Manage aggregations mappings are:

| Summary Column | Summarization | Detail Table | Detail Column |
| --- | --- | --- | --- |
| StayDateKey | GroupBy | FactStayNight | StayDateKey |
| PropertyKey | GroupBy | FactStayNight | PropertyKey |
| StayNights | Count table rows | FactStayNight | Not applicable |
| RoomsOccupied | Sum | FactStayNight | RoomsOccupied |
| RoomRevenue | Sum | FactStayNight | RoomRevenue |

Key and sum mappings use matching model types: Int64 for keys/occupied rooms and Number for revenue. The SQL summary uses COUNT_BIG, a bigint occupied-room sum, and a float revenue result. Count table rows maps the whole detail table, not a count of nonblank StayNightID values. The model still exposes the same three measures against FactStayNight; none explicitly references the summary. Aggregation selection belongs to the engine.

The inspected source had 1,047,284 detail rows and 22,702 summary groups, approximately 46 times fewer rows. Recheck your own snapshot. Row reduction is not proof of a hit, memory savings, or a particular speedup.

## Demo Sequence

1. In Model view, inspect the four storage modes, the two pairs of relationships, and the hidden summary's Manage aggregations mappings. Keep the existing measures visible: COUNTROWS(FactStayNight), SUM(RoomsOccupied), and SUM(RoomRevenue).
2. Select Downtown Central and March/April 2026 on the existing comparison page. The historical baseline is March: 2,468 stay nights, 3,102 occupied rooms, 667,006.00 revenue; April: 2,586, 3,095, 664,131.00. Validate against your source snapshot before using those numbers.
3. Connect DAX Studio to this Desktop instance and enable Server Timings. Run [monthly-comparison.dax](../queries/monthly-comparison.dax). It requests the same measures at a grain the summary covers. Look for an aggregation rewrite event when available and a VertiPaq scan naming AggStayNightDateProperty. No SQL alone is insufficient proof: a previous query might be cached. Clear the query cache in DAX Studio before each demonstration query if needed, and retain the actual scan/rewrite evidence.
4. Run [aggregation-detail.dax](../queries/aggregation-detail.dax) with Server Timings. It adds NightNumber to the same property/month question. The summary deliberately lacks that attribute, so this grouping cannot be answered from it. Verify a DirectQuery event and SQL grouping by NightNumber over dw.FactStayNight; the related dimensions can participate in that source query through Dual. This is a user-defined aggregation miss, not Direct Lake fallback.
5. Add each month's detail rows and reconcile all three measures to the monthly query. For an independent check, run the same detail query against the separate DirectQuery baseline. Use the same source snapshot; do not infer consistency merely from the modes or mappings.
6. Return to the monthly query to close: one set of measures, cached summary when covered, source detail when not covered. Explain the tradeoff: the summary and Dual dimension caches consume memory and need refresh; detail queries still depend on source performance and access.

For an approximately eight-minute course segment, allow two minutes for the model/mappings, two for the summary path, two for the uncovered detail path, and two for reconciliation and freshness. These are rehearsal allocations, not measured recording times. The shorter video can show the same two traces without repeating setup.

## Freshness and Reset

Refresh the summary and Dual dimensions together before the run, preferably while the source is stable. DirectQuery detail can see changes that the imported summary has not yet captured. Ordinary report refresh or rerunning a DAX query does not refresh imported data. Do not edit the shared Warehouse to manufacture this discrepancy.

For a repeat, restore the property/month selections and clear only the local query cache when demonstrating fresh engine requests. For a clean connection rehearsal, reopen an untouched copy of the prepared project, set the parameters, authenticate, and refresh. Do not overwrite the portable template with a private endpoint or commit Desktop caches. No publication is part of this demo.

## Verification Status

Built on 2026-11-25. Native TMDL export/re-import confirmed four partitions (DirectQuery, Dual, Dual, Import), four active single-direction relationships, the five aggregation mappings, matching key/sum model types, three unchanged detail-table measures, a hidden summary, and a placeholder endpoint. The ten copied report content/resource files matched the existing DirectQuery report byte-for-byte.

PBIR validation reported zero errors and one warning: the remote visualContainer 2.14.0 schema could not be fetched for the two copied slicers, so their schema validation was skipped. Desktop opened the project successfully. The new live instance was configured through the modeling API and its summary and Dual dimensions were refreshed; all four partitions reported Ready. This validates model processing, not a separately completed learner parameter/authentication UI rehearsal. The saved template remains portable; private live settings were not exported.

Runtime checks on 2026-11-25 established both paths:

- The unchanged monthly DAX returned the two expected rows. Its trace positively identified the [summary-table VertiPaq scan](../queries/monthly-comparison-aggregation.xmsql), including SUM(StayNights) for the original COUNTROWS measure, with no DirectQuery/cache-match/error events. A separate Aggregate Table Rewrite Query event was not subscribed; the named summary scan supplies the positive evidence.
- The NightNumber query returned ten rows identical to the separate DirectQuery baseline. Its trace identified one [detail SQL request](../queries/aggregation-detail-directquery.sql), grouping by NightNumber/month/property with both dimension joins. No summary scan appeared. Each month's five rows added back to all three monthly totals.
- Whole-model measures agreed between this refreshed summary-backed model and the separate DirectQuery baseline: 1,047,520 stay nights, 1,317,828 occupied rooms, and 271,609,086.00 room revenue. The summary contained 22,719 rows. The source had grown since the earlier research snapshot; this is a newer observation, not a discrepancy in the historical monthly result or proof that the source remained frozen throughout testing.
- The two session-scoped traces were fetched/exported to ignored local storage before stopping; both reported zero discarded events. No caches were cleared and no repeated performance protocol was used. Query-path evidence is verified; do not calculate a universal speedup from the individual durations.

Screenshot review of the loaded comparison page showed the property/month selections, two monthly bars, and populated detail table without report errors or overlapping visuals. All six displayed monthly values matched the query results; totals were 5,054 stay nights, 6,197 occupied rooms, and 1,331,137.00 revenue. The page was captured without reloading or saving the live model. The temporary external screenshot directory was removed after review, and Desktop was left open.

See the [query capture notes](../queries/README.md) for trace interpretation and limits. On 2026-11-27 the instructor confirmed completion of the recording rehearsals and remaining preparation checks. Students should follow the [preparation guide](../student-preparation.md) before class; this confirmation does not replace their own connection test or establish an independent fresh-student usability study. Save a separate connected working copy rather than overwrite the portable template.

References: [Microsoft user-defined aggregations guidance](https://learn.microsoft.com/en-us/power-bi/transform-model/aggregations-advanced) and [Dual storage mode](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-storage-mode).