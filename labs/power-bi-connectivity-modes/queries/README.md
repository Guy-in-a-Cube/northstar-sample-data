# Connectivity Query Captures

Captured on 2026-11-25 against the connected Northstar Connectivity DirectQuery and with-StayNightID Import Desktop models. Each model had three Ready partitions in its respective mode. No model definitions, source data, cache settings, or report layout were changed for these captures.

- [Controlled DAX query](monthly-comparison.dax): reproduces the comparison table's business grouping and filters. This is deliberately authored DAX, not the exact visual-generated query from Performance Analyzer.
- [Captured DirectQuery SQL](monthly-comparison-directquery.sql): the DirectQueryBegin/End TextData from the second execution, with whitespace and keyword casing normalized for reading. Aliases, projections, joins, predicates, aggregates, and the engine-generated row limit are preserved.
- [Captured Import xmSQL](monthly-comparison-import.xmsql): the top-level VertiPaqScan begin event's TextData, preserving engine names and IDs. This is an internal storage-engine description, not T-SQL to run against the Warehouse. IDs can differ in other model instances.

## Observed Results

| Property | Month | Stay Nights | Rooms Occupied | Room Revenue |
| --- | --- | --- | --- | --- |
| Downtown Central | 2026-03 | 2,468 | 3,102 | 667,006.00 |
| Downtown Central | 2026-04 | 2,586 | 3,095 | 664,131.00 |

Both executions returned these two rows, matching the previously checked baseline. The first call took 1,413 ms client-side. The second took 231 ms client-side; its trace reported QueryEnd duration 229 ms and DirectQueryEnd duration 222 ms. These are individual observations, not a benchmark, FE/SE calculation, or evidence that DirectQuery is faster/slower than Import. Caches were not cleared; Warehouse cache and capacity conditions were not controlled.

The subsequent Import execution used the identical DAX and returned the same two rows and all six measure values. Its client-side duration was 9 ms; QueryEnd reported 7 ms and the top-level VertiPaqScan reported 3 ms. These runs were not a matched-source-snapshot or cold/warm performance experiment: displayed results agree for the selected months, but the complete Import snapshot was not compared with the current Warehouse. Do not turn these individual durations into a general speedup claim.

## What the Trace Establishes

The retained second trace contains one QueryBegin, one DirectQueryBegin, one DirectQueryEnd, and one QueryEnd, correlated by the same activity/request identifiers, with no discarded events. One SQL request computed all three measures grouped by month/property. The joins, property filter, month filter, COUNT_BIG, and SUM aggregates were pushed to SQL. The outer SQL does not request StayNightID as a result field even though it remains in the source projection.

TOP (1000001) is an engine-generated result guard, not a business Top N rule. LEFT OUTER JOIN reflects the generated query; no Assume Referential Integrity change was made. Source SQL text does not establish a physical execution plan or exact columns read from storage.

Raw trace output is retained only in the repository's ignored dist directory, outside the learner project. The first trace was stopped before fetching; its event text was not retained and is not used as SQL evidence. The second trace was fetched and exported before stopping. No trace remains running from this capture.

## Import Engine Comparison

The Import trace contains six events: QueryBegin/End, a top-level VertiPaqScan begin/end pair, and a nested VertiPaqScanInternal begin/end pair. All share the query's request identifier; the storage-engine events have their own activity identifier. No DirectQueryBegin/End, cache-match, or error events appeared, and no events were discarded. A successful VertiPaq scan plus verified Import modes provides positive engine-path evidence, not just an absence of SQL.

The top-level scan and nested internal scan overlap and each reports 3 ms; do not add them as two independent 3 ms requests. The internal representation used DC_KIND="DENSE" and INB, while the retained top-level representation used DC_KIND="AUTO" and IN. Both represent internal VertiPaq work, not SQL requests to the Warehouse. This says nothing about the SQL used during the earlier Import refresh.

The reusable comparison is now the same DAX and business results, with DirectQuery source SQL on one side and Import's internal xmSQL on the other. Both raw traces are retained in ignored local storage; both traces were exported before stopping.

## Aggregations and Dual

The separate Aggregations Desktop model was loaded and its imported summary and Dual dimensions refreshed on 2026-11-25. The detail fact remained DirectQuery. It used the same three detail-table measures; no measure was redirected explicitly to the summary.

- [Monthly DAX](monthly-comparison.dax) returned the same two monthly rows above. The retained [aggregation xmSQL](monthly-comparison-aggregation.xmsql) is the top-level VertiPaqScan begin event, after newline normalization. It names AggStayNightDateProperty and sums RoomRevenue, StayNights, and RoomsOccupied through the cached Dual dimensions. This is positive evidence of an aggregation hit, not merely an absence of SQL. The trace contained QueryBegin/End and overlapping top-level/internal VertiPaq scan pairs, without DirectQuery, cache-match, or error events. Aggregate Table Rewrite Query was not subscribed.
- [Uncovered-detail DAX](aggregation-detail.dax) adds FactStayNight.NightNumber to the same question. The summary does not contain this attribute. The retained [generated detail SQL](aggregation-detail-directquery.sql) preserves the captured aliases/projections/joins/predicates/aggregates/row guard, with whitespace and keyword casing normalized. It groups by NightNumber/month/property at the source, including both Dual dimension joins. The trace contained QueryBegin/End and one DirectQueryBegin/End pair, with no summary scans or errors.

All ten detail rows and thirty measure values matched the separate DirectQuery baseline, and each month's five detail rows summed to the corresponding monthly result. Whole-model measures also agreed between the refreshed summary-backed model and DirectQuery: 1,047,520 stay nights, 1,317,828 occupied rooms, and 271,609,086.00 room revenue. The imported summary contained 22,719 rows. These totals reflect source growth since the earlier 1,047,284-row research snapshot; they do not prove an immutable source snapshot across all tests.

For completeness, the covered execution took 7 ms client-side (QueryEnd 6 ms; top-level/internal scan durations 1 ms each, overlapping). The uncovered execution took 2,249 ms client-side (QueryEnd 2,246 ms; DirectQueryEnd 216 ms). Do not attribute the entire elapsed difference to Warehouse SQL or turn these two different-grain queries into a controlled speedup comparison. No caches were cleared and source/capacity conditions were not controlled.

Both session-scoped traces were fetched and exported before stopping, with zero discarded events. Raw traces remain in ignored dist storage; reusable captures contain no endpoint or credentials. The [demo walkthrough](../aggregations/README.md) provides the connection, mappings, sequence, and reset.

## Next Check

To inspect the exact report visual query, separately record that visual in Performance Analyzer and capture its execution; do not relabel these controlled queries as visual captures. Preserve the same business filters and distinguish SQL source queries from Import's internal storage-engine queries. Any timing benchmark needs a separately recorded cache/source protocol and repeated runs.