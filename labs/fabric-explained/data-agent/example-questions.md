# Example Questions

These are newly authored chat prompts for the [NorthStar Performance Analyst setup](README.md), not saved examples exported from the reference agent. They have been checked against its selected model fields but have not been executed against an agent.

Replace `[MONTH YEAR]` with a calendar month present in the facts used by the question. Use a complete month for monthly budget comparisons. If the sample load contains only part of a month, do not treat a comparison with the full monthly budget as a like-for-like result. The date dimension alone does not establish fact coverage, and different facts may cover different periods.

Run each question independently unless you intentionally request a follow-up. Check the returned filters and generated DAX. The measure names under each question are review anchors, not alternative formulas or fixed expected answers.

## 1. Portfolio Baseline

For [MONTH YEAR], show NorthStar's total revenue, room revenue, rooms occupied, and occupancy percentage across all properties.

**Measure anchors:** `Total Revenue`, `Room Revenue`, `Rooms Occupied`, `Occupancy %`.

**Review:** Use the requested month and portfolio scope. Revenue and occupancy must follow the model's stay and inventory definitions, not bookings or room capacity alone.

## 2. Revenue Against Budget

For [MONTH YEAR], which five properties were furthest below revenue budget? Show actual revenue, budget revenue, revenue variance, and revenue variance percentage for each property. If fewer than five properties were below budget, show only those properties.

**Measure anchors:** `Total Revenue`, `Budget Revenue`, `Revenue Variance`, `Revenue Variance %`.

**Review:** Rank negative variances with the largest shortfall first. Positive variance means above budget; do not relabel it as a shortfall or add properties to fill five rows.

## 3. Occupancy Against Budget

For [MONTH YEAR], compare actual occupancy with budget occupancy by property. Show the difference in percentage points and identify the properties below budget.

**Measure anchors:** `Occupancy %`, `Budget Occupancy %`, `Occupancy Variance`.

**Review:** Preserve the model's budget occupancy calculation. An actual-minus-budget difference is a percentage-point difference, not relative percentage growth.

## 4. Booking Cancellations

Using booking dates in [MONTH YEAR], compare bookings, cancelled bookings, and cancellation rates by channel. Which channel had the highest cancellation rate?

**Measure anchors:** `Bookings`, `Cancelled Bookings`, `Cancellation Rate`.

**Review:** Use booking dates rather than check-in or check-out dates. Include booking counts to give the rate context; do not claim a channel caused cancellations.

## 5. Loyalty Booking Mix

For bookings made in [MONTH YEAR], compare loyalty bookings and the share of bookings identified as loyalty bookings by property. Include total bookings.

**Measure anchors:** `Bookings`, `Loyalty Bookings`, `Loyalty Booking %`.

**Review:** Use the model's loyalty definition, not a guessed rule based on guest names or loyalty tiers. Do not introduce individual guest or email records.

## 6. Satisfaction by Stay Date

Using stay dates in [MONTH YEAR], compare average satisfaction scores by property and include the number of survey responses for each property.

**Measure anchors:** `Average Satisfaction Score by Stay Date`, `Survey Responses by Stay Date`.

**Review:** Use the stay-date measures rather than the default survey-date measures. Scores and response counts must use the same requested date role.

## 7. Experience Revenue

For [MONTH YEAR], rank experiences by realized experience revenue and show the five highest-revenue experiences.

**Measure anchors:** `Experience Revenue`.

**Review:** Use realized stay revenue grouped by experience, not the number of bookings. Do not assume popularity or demand caused the ranking.

## 8. Operational Events

For [MONTH YEAR], show property events, out-of-service events, maintenance events, amenity closure events, and high-severity events by property.

**Measure anchors:** `Property Events`, `Out-of-Service Events`, `Maintenance Events`, `Amenity Closure Events`, `High Severity Events`.

**Review:** Keep event counts distinct from unavailable-room inventory. High severity can overlap other event categories; do not sum these categories as if they were mutually exclusive.

## 9. Events Alongside Performance

For [MONTH YEAR], list properties with recorded operational events alongside their rooms out of service, occupancy percentage, and total revenue. Describe what occurred in the same period without claiming that the events caused the performance results.

**Measure anchors:** `Property Events`, `Rooms Out of Service`, `Occupancy %`, `Total Revenue`.

**Review:** Use the same month and property grouping for every measure. `Rooms Out of Service` aggregates inventory observations; it is not a distinct count of rooms affected by events. A property with events but no matching inventory or stay records must not acquire invented performance results.

## 10. Prior-Year Comparison

For [MONTH YEAR], compare total revenue with the same month one year earlier and show the year-over-year percentage change. If the prior-year period has no supporting data, say that a supported comparison is unavailable rather than inventing values.

**Measure anchors:** `Total Revenue`, `Total Revenue PY`, `Total Revenue YoY %`.

**Review:** Use the model's prior-year and year-over-year measures. Do not silently switch to the previous month or add unrelated baseline periods.