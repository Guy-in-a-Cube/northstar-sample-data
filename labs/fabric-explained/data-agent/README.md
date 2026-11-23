# NorthStar Performance Analyst

Instructions and sample questions for recreating the NorthStar Performance Analyst in Microsoft Fabric. This is a manual setup companion, not an importable DataAgent definition or a deployment script.

The reference agent uses one Power BI semantic model, `sm_northstar`, as its authoritative analytical source. It does not connect directly to the Warehouse or Lakehouse.

## Files

| File | Purpose |
| --- | --- |
| [instructions.md](instructions.md) | Copy-ready agent instructions, preserved from the reference agent. |
| [example-questions.md](example-questions.md) | Newly authored chat prompts and answer-review criteria for the lab. |

## Prerequisites

- A paid Fabric F2 or higher capacity, or Power BI Premium P1 or higher with Fabric enabled. Confirm the required AI tenant settings, including cross-geo processing and storage, with your administrator.
- Permission to create a data-agent item in your lab workspace.
- A working `sm_northstar` semantic model in Fabric, backed by your loaded lab Warehouse. The local [Power BI checkpoint](../power-bi/README.md) is a starting artifact, not a service data source; prepare and validate the model in Fabric before adding it to the agent.
- Read permission on the semantic model. For semantic-model interactions through a data agent, Build permission and membership in the model's workspace are not required. Model authoring has separate permission requirements.

The sample data is synthetic. Review the selected guest-name and email fields before adapting this configuration to real data. Data access runs under the caller's permissions; agent instructions are not a substitute for access controls or model security.

See Microsoft's [Create a Fabric data agent](https://learn.microsoft.com/en-us/fabric/data-science/how-to-create-data-agent) guide for current capacity, tenant, and permission requirements. You do not need to supply an Azure OpenAI key or an access token for the in-product chat experience.

## Create the Agent

1. In your lab workspace, select **New item**, search for **Fabric data agent**, and name the item **NorthStar Performance Analyst**.
2. Add your own `sm_northstar` Power BI semantic model from the catalog. Use your lab model, not the reference workspace's item. Keep this agent scoped to that single semantic-model source.
3. In **Explorer**, select the 11 tables and their fields listed below. Selecting a parent selects its children, so review the resulting field selection rather than assuming every available model field belongs in this agent.
4. Open **Data agent instructions** and paste the entire contents of [instructions.md](instructions.md). The reference definition has no source-specific instructions or user description; no additional source-level text needs to be copied.
5. Try the [example questions](example-questions.md) in chat. Replace the period placeholder with a period present in the relevant facts. Review the generated DAX, filters, and supporting results against the semantic model before accepting an answer.
6. After the questions pass your manual checks, select **Publish** and supply the description below. Publishing creates a shareable version separate from the editable draft. Share only with people who have the required access to the agent and its source model.

Suggested publication description, preserved from the reference definition:

> Analyzes NorthStar business performance across properties, markets, channels, experiences, bookings, occupancy, budgets, guest satisfaction, and operational events. Use it to compare performance, identify notable patterns, and highlight areas that warrant further investigation.

Power BI semantic-model sources do not currently support saved example question/query pairs in the **Example queries** pane. The supplied questions are prompts to run in chat, not training examples to upload there.

## Source Scope

The captured definition selects 11 tables, 36 columns, and 57 measures. The field lists below record that selection by name, without workspace, artifact, or field IDs. Keep the model's explicit measures and business descriptions; do not replace them with agent-written formulas over raw fact columns.

| Table | Selected fields |
| --- | --- |
| `DimProperty` | `PropertyCode`, `PropertyName`, `Region`, `Market`, `PropertyType`, `LuxuryTier`, `RoomCount`, `OpenDate` |
| `DimGuest` | `GuestCode`, `GuestSegment`, `LoyaltyTier`, `AgeGroup`, `HomeRegion`, `GuestName`, `Email` |
| `DimChannel` | `ChannelCode`, `ChannelName`, `ChannelType` |
| `DimExperience` | `ExperienceCode`, `ExperienceName`, `ExperienceType` |
| `DimDate` | `FullDate`, `CalendarYear`, `CalendarQuarter`, `MonthNumber`, `MonthName`, `YearMonth`, `DayOfWeekName`, `IsWeekend`, `Season` |
| `FactBooking` | `Bookings`, `Nights Booked`, `Rooms Booked`, `Cancelled Bookings`, `Cancellation Rate`, `Cancellation Amount`, `Loyalty Bookings`, `Loyalty Booking %`, `Cancellation Rate PY`, `Cancellation Rate YoY Change`, `Bookings by Check-In Date`, `Rooms Booked by Check-In Date`, `Nights Booked by Check-In Date`, `Bookings by Check-Out Date` |
| `FactStayNight` | `Rooms Occupied`, `Room Revenue`, `Experience Revenue`, `Other Revenue`, `Discount Amount`, `Gross Revenue`, `Total Revenue`, `ADR`, `Customers Served`, `Total Revenue PY`, `Total Revenue YoY %`, `Customers Served PY`, `Customers Served YoY %`, `Experience Revenue PY`, `Experience Revenue YoY %` |
| `FactPropertyInventory` | `Room Capacity`, `Rooms Out of Service`, `Rooms Sellable`, `Occupancy %`, `RevPAR`, `Occupancy % PY`, `Occupancy YoY Change` |
| `FactGuestSatisfaction` | `Survey Responses`, `Average Satisfaction Score`, `Average Service Score`, `Average Cleanliness Score`, `Average Value Score`, `Would Recommend`, `Recommendation Rate`, `Survey Responses by Stay Date`, `Average Satisfaction Score by Stay Date` |
| `FactPropertyBudget` | `Budget Revenue`, `Budget Occupancy %`, `Revenue Variance`, `Revenue Variance %`, `Occupancy Variance` |
| `FactPropertyEvent` | `EventTimestamp`, `EventType`, `RoomNumber`, `Severity`, `Description`, `SourceSystem`, `Property Events`, `Affected Properties`, `Out-of-Service Events`, `Rooms Returned to Service Events`, `Maintenance Events`, `Amenity Closure Events`, `High Severity Events` |

The four measures on `DimProperty` and `Satisfaction vs Portfolio` are outside the captured agent selection. Hidden technical keys and raw fact amounts are also outside this scope. If you change the model or its visibility settings, review the agent's selection again; do not assume the original field list updates automatically.

## Review Answers

- Confirm that the answer uses the selected semantic model and its existing measures, with the requested date role, period, and grouping.
- Check currency, percentages, counts, and percentage-point differences against the model's definitions. In particular, `Budget Occupancy %` is the model's average budget occupancy, not an agent-defined weighted calculation.
- Compare returned figures with a report or model query using exactly the same filters. Not every question has an equivalent visual in the supplied Property Health report.
- Distinguish no matching records from a measured zero. Do not accept invented prior-year results or assumptions about missing date coverage.
- Treat operational events and financial patterns as observations occurring together, not proof of causation. Unsupported claims about pricing, demand, guest behavior, or maintenance causes do not pass review.
- Keep each question's scope explicit. Do not accept extra benchmark periods or causal explanations simply because they sound plausible.

## Verification and Export Boundaries

The reference definition was retrieved on November 22, 2026. Its draft and published agent instructions and data-source definitions matched. The copied instructions, publication description, and field lists were checked against that definition; selected fields and question measure names were checked against the distributed model.

The instructions contained no environment bindings, so their wording required no substitutions. This package omits the raw draft/published JSON, source workspace and artifact IDs, field IDs, `.platform`, and deployment metadata instead of distributing a partially bound agent definition. It contains no credentials or returned business records.

The example questions are newly authored, not exported saved questions or verified answers. No student agent was created, no questions were executed, and no numerical or end-to-end answer validation is claimed. The live agent and its semantic model were not changed, queried, or republished during packaging. The manual answer checks above remain part of student setup.