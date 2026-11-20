# Property Budget

Property Budget represents planned property budgets. The maintainer's Excel workbook is the authoritative distribution source. Each learner creates their own SharePoint list from a versioned workbook as their working copy. The maintainer's demo list is not the distribution source.

## Included Files and Evidence

Only this guide is included in the repository; no budget workbook has been copied or published. Read-only inspection of the supplied workbook on 2026-11-20 verified one sheet, an Excel table named `PropertyBudgetTable`, five columns, and 384 data rows: 16 properties for each of 24 months, January 2025 through December 2026. All months start on the first day, with no duplicate property/month pairs. No formulas, macros, or external workbook links were found.

All 16 property codes and names match the verified operational snapshot. `PropertyCode` maps to operational `Property.property_code`, not `property_id` or a SharePoint-generated item ID. Operational inventory in that snapshot spans January 2023 through November 2026; the workbook has no 2023-2024 budgets. Historical backfill is a separate decision, not an implied requirement.

The existing SharePoint list could not be inspected because access required sign-in. Its column definitions and equality with the workbook are unverified. On 2026-11-20, the owner confirmed all revenue amounts are USD and approved 3% annual revenue growth with unchanged prior-year occupancy for future extensions. These are owner-approved business assumptions, not deductions from workbook formatting. Budget redistribution approval and budget licensing remain unresolved. Operational data's CC0 dedication does not automatically cover this workbook.

## Workbook Contract

The row grain is one planned budget per property per calendar month. The logical key is `PropertyCode` + `BudgetMonth`; names are descriptive, not identifiers. Keep the existing five columns and Excel table name for compatible releases.

| Column | Published Value Contract | Suggested SharePoint Type (Not Tested Here) |
| --- | --- | --- |
| `PropertyCode` | Stable code matching the paired operational export; preserve its complete text representation, including any future leading zeros | Single line of text |
| `PropertyName` | Nonempty descriptive property name | Single line of text |
| `BudgetMonth` | Real Excel date on the first day of the month, displayed as `yyyy-mm-dd` | Date and time, date-only display |
| `BudgetRevenue` | Nonnegative planned monthly revenue in USD, rounded to two decimal places | Number with two decimal places; consumers should verify any optional USD currency display |
| `BudgetOccupancyPct` | Decimal fraction from 0 through 1; retain source precision, not just displayed precision | Number storing the decimal fraction |

All five fields are required for published seed rows. For example, a stored occupancy of `0.2322` means 23.22%, even when Excel's display rounds it to 23.2%. Import must not turn it into `23.22` or `0.002322`. Dates must remain the intended calendar month in SharePoint; date-only display alone does not establish timezone behavior.

## Excel Maintenance

This defines maintenance behavior, not authorization to generate or publish new records:

1. Maintain Excel as the single authoritative source. Do not independently maintain the demo SharePoint list and then merge competing edits. New releases are generated from reviewed Excel revisions, not from consumer lists.
2. Review extensions monthly. The proposed planning horizon is December of the year following an explicitly selected reporting month in the paired operational snapshot. Confirm that reporting month rather than inferring it from export timestamps, audit dates, or future reservations. Daily operational exports alone do not create source records or trigger daily budget recalculation.
3. Append only missing, approved property/month pairs, in month then property-code order. Extend `PropertyBudgetTable` to include new rows. Existing rows and published snapshots are not automatically rewritten; approved corrections require a new release and a correction note.
4. For an existing property, use the same calendar month in the prior approved budget year as the seasonal baseline. New USD revenue is prior-year budget revenue multiplied by `1.03`, rounded to two decimal places using decimal arithmetic and midpoint rounding away from zero. This is 3% annual growth, not monthly growth; later years compound from the prior approved year's rounded values. Preserve the prior-year occupancy fraction unchanged; it must remain between 0 and 1. Existing workbook amounts remain unchanged. Do not substitute actual revenue or occupancy for historical plans. Approval of these assumptions does not itself generate rows or authorize publication.
5. New properties, missing prior-year baselines, inactive-property eligibility, and historical backfills require separately approved values and period coverage. Do not invent a baseline, silently copy another property's budget, or infer eligibility solely from a soft-delete flag.
6. Before release, validate required values, key uniqueness, complete approved month/property coverage, date and numeric contracts, Excel table bounds, and property-code membership in the paired operational snapshot. Review workbook metadata and all content for privacy and redistribution, not just visible cell values.

## Budget Releases

Publish the reviewed Excel workbook as a versioned budget release asset. A matching CSV may be offered separately after its encoding, date, null, and precision conventions are defined; it is not the primary consumer setup route. No release or budget download link exists yet.

Record the budget version, workbook SHA-256, table name, row count, month coverage, currency, generation assumptions, and paired operational snapshot tag in separate release metadata. Keep verification metadata separate from the learner's workbook. Do not depend on a maintainer's local course folder for cloud automation.

Keep budget publication separate from the current eight-table operational workflow until a combined release contract is explicitly approved. Protect course-pinned budget releases, including their paired operational snapshots, and never silently replace their assets. A budget-specific rolling retention policy remains to be selected; operational cleanup must not delete budget releases.

## Create Your SharePoint List

Consumer setup uses Microsoft's documentation rather than a repository-authored click-by-click walkthrough. This guide stops at creating the list; downstream Fabric setup is taught in the course. No maintainer-run Excel-to-SharePoint import test is planned. Once an approved workbook is available:

1. Download the exact budget workbook version and paired operational snapshot specified by the course. Confirm the workbook table and row count against that release's metadata; 384 is the inspected baseline, not a permanent expected count.
2. Follow [Create a list based on a spreadsheet](https://support.microsoft.com/en-us/office/create-a-list-based-on-a-spreadsheet-380cfeb5-6e14-438e-988a-c2b9bea574fa), Microsoft's official Support article. Use the Excel route in your own authorized SharePoint site and select `PropertyBudgetTable`.
3. Review inferred column types and imported values against the workbook contract above. Preserve property codes independently of generated item IDs, month dates, revenue precision, and occupancy fractions. Confirm row count and property/month coverage; these consumer checks are not a claim that this repository tested the import.

Microsoft documents a maximum of 5,000 table rows for this list-creation route. It also notes that uploading a workbook from your device saves the original file in the site's Site Assets library; consider access to that file before uploading. A future workbook beyond the documented import limit would need another documented setup route.

Excel seeds the list; it is not a live Excel-to-list synchronization. Learner edits do not update the maintainer's workbook. The default update/reset route is a new list from a newer pinned workbook. Keep the previous list until the replacement is verified. Never blindly append a full workbook into an existing list. An advanced in-place update would need a separately tested upsert keyed by property/month and a policy for preserving learner edits; it is not supplied here.

## Import Considerations and References

The workbook evidence and intended contracts above do not certify SharePoint import compatibility. Optional CSV conventions, exact SharePoint types/internal names, timezone handling, the reporting month/planning horizon, and new-property baselines remain to be confirmed. USD and the existing-property 3% annual growth/unchanged occupancy rule are owner-approved. Avoid locale-dependent conversions; currency is established by that confirmation, not a dollar-sign display format alone.

Checked 2026-11-20: [Create a list based on a spreadsheet (Microsoft Support)](https://support.microsoft.com/en-us/office/create-a-list-based-on-a-spreadsheet-380cfeb5-6e14-438e-988a-c2b9bea574fa). Microsoft's Excel-to-list instructions are on Microsoft Support, not Microsoft Learn. This reference establishes documented product behavior, not a tested import of this dataset. Return to the [repository guide](../README.md).