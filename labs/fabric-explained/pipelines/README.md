# Fabric Explained Pipelines

These are sanitized Fabric DataPipeline definitions, not native ZIP templates for the pipeline template gallery. Each JSON file is uploaded as the `pipeline-content.json` definition part through the Fabric REST API. Configure the bindings before uploading; the placeholder-bound files are not runnable.

| File | Purpose |
| --- | --- |
| [pl_load_northstar_dimension.json](pl_load_northstar_dimension.json) | Conditionally start a load run, then load the five Warehouse dimensions. |
| [pl_load_northstar_fact.json](pl_load_northstar_fact.json) | Conditionally start a load run, then load the six Warehouse facts. FactStayNight waits for FactBooking. |
| [pl_refresh_northstar.json](pl_refresh_northstar.json) | Generate a shared LoadRunID, start the run, invoke operational ingestion, process property events, load dimensions and facts, and record completion or failure. |

The refresh is standalone with respect to the original external Azure Data Factory pipeline. It still requires the Fabric Copy Job described below. It refreshes Warehouse data; it does not refresh a Power BI semantic model.

## Prerequisites

- A workspace on a supported Fabric capacity, with Contributor access and an identity authorized for `DataPipeline.ReadWrite.All` or `Item.ReadWrite.All`.
- The `wh_northstar` objects from the [Warehouse scripts](../warehouse/README.md), with permission to execute the load and logging procedures.
- A schema-enabled `lh_northstar` with the operational tables in `landing`, using the names and structures expected by the Warehouse procedures.
- The [property-event notebook](../notebooks/README.md), attached to the correct default Lakehouse and supplied with its input files. It writes `processed.PropertyEvent` and `quarantine.PropertyEvent`.
- The `PropertyBudget` source exposing `dbo.[Property Budget]`, as required by the budget loader.
- A separately configured Fabric Copy Job that populates the operational landing tables. Its definition is not included here.
- Fabric connections and permissions for the Copy Job and child-pipeline invocation activities. A connection ID is not the same as a workspace or item ID.

The procedures modify Warehouse data, and the notebook overwrites its two output tables. Inspect the linked scripts and source mappings before running these pipelines against existing data.

## Bindings

Configure local working copies rather than committing your environment's identifiers. Replace every occurrence, including the stored-procedure activity nested inside each child's `Start Load Run` condition.

| Placeholder | Replacement |
| --- | --- |
| `__WAREHOUSE_SQL_ENDPOINT__` | Warehouse SQL server hostname, without a URL scheme. |
| `00000000-0000-0000-0000-000000000001` | Target workspace ID. These definitions assume all referenced items are in that workspace. |
| `00000000-0000-0000-0000-000000000002` | Target Warehouse item ID. |
| `00000000-0000-0000-0000-000000000003` | Imported property-event notebook item ID. |
| `00000000-0000-0000-0000-000000000004` | Dimension pipeline item ID obtained during creation. |
| `00000000-0000-0000-0000-000000000005` | Fact pipeline item ID obtained during creation. |
| `00000000-0000-0000-0000-000000000006` | Operational Copy Job item ID. |
| `00000000-0000-0000-0000-000000000007` | Fabric connection ID for `Load Operational Data`. |
| `00000000-0000-0000-0000-000000000008` | Fabric connection ID for both `Load Dimensions` and `Load Facts`. |

Keep the expected source item names (`wh_northstar`, `lh_northstar`, and `PropertyBudget`) unless you also update the SQL that references them. The UUID-shaped markers above are deliberately non-live placeholders, not usable defaults.

## Upload

The tested route is to create empty pipelines and then upload their configured definitions. Neither operation runs a pipeline or creates a schedule.

1. Create each of the three pipelines using its intended display name. The [Create Data Pipeline API](https://learn.microsoft.com/en-us/rest/api/fabric/datapipeline/items/create-data-pipeline) accepts this request:

   ```http
   POST https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/dataPipelines
   Authorization: Bearer {FabricAccessToken}
   Content-Type: application/json
   ```

   ```json
   {
     "displayName": "pl_load_northstar_dimension"
   }
   ```

2. Record each returned item ID. Substitute the correct display name for the fact and refresh pipelines. If creation returns `202 Accepted`, follow the operation's `Location` and `Retry-After` headers until it succeeds, then retrieve its result to obtain the item ID. Do not resubmit creation to wait for completion.

3. Resolve the Warehouse bindings in both child definitions, and upload those children first. Resolve all remaining bindings in the refresh definition, including the two new child IDs, then upload the refresh.

4. For each configured JSON file, encode its UTF-8 bytes as Base64. For example, from the directory containing your configured copy:

   ```powershell
   $payload = [Convert]::ToBase64String(
       [IO.File]::ReadAllBytes((Resolve-Path './pl_load_northstar_dimension.json').Path)
   )
   $body = @{
       definition = @{
           parts = @(@{
               path = 'pipeline-content.json'
               payload = $payload
               payloadType = 'InlineBase64'
           })
       }
   } | ConvertTo-Json -Depth 6
   ```

5. Submit `$body` as the JSON body of the [Update Item Definition API](https://learn.microsoft.com/en-us/rest/api/fabric/core/items/update-item-definition):

   ```http
   POST https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/items/{itemId}/updateDefinition
   Authorization: Bearer {FabricAccessToken}
   Content-Type: application/json
   ```

   This replaces the item's entire definition. Target only your newly created pipeline. A `200 OK` completes the update; a `202 Accepted` requires operation-state polling using `Location` and `Retry-After`. Do not request an item result or resubmit the update to wait for completion.

6. Open the imported pipelines in Fabric and inspect every activity, connection, notebook attachment, and child-pipeline selection before running. No `.platform`, schedules, credentials, or permissions are supplied by these files. Authentication must use a token for the Fabric API; keep it out of files and source control.

See the [DataPipeline definition reference](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/datapipeline-definition) for the payload structure. Uploading the raw JSON to the template gallery was not tested and is not the import process described here.

## Running And Logging

Run `pl_refresh_northstar` for the full workflow. It creates a fresh GUID in `LoadRunID`, writes one `ctl.LoadRun` header, and passes the same ID to both children with `StartLoadRun = false`. The child loaders write their step details through the existing Warehouse procedures. The parent marks the run complete only after the facts finish.

For a direct dimension or fact run, supply a fresh GUID as the required `LoadRunID` parameter and leave the Boolean `StartLoadRun` parameter at its default `true`. These child pipelines do not complete or fail the header themselves. The caller must invoke `ctl.usp_complete_load_run` or `ctl.usp_fail_load_run` for that same ID afterward; otherwise the header remains `Running`. Set `StartLoadRun = false` only when the caller has already created that header.

On the full refresh failure path, a failed or skipped `Complete Load Run` triggers `Fail Load Run`, followed by an explicit `Fail Refresh` activity. The final failure is still raised if failure logging itself fails. If initialization or Warehouse access fails before a header can be written, use Fabric activity run history; there may be no matching `ctl.LoadRun` record.

Avoid concurrent refreshes or reuse of a LoadRunID. Inspect both `ctl.LoadRun` and `ctl.LoadRunDetail` alongside Fabric monitoring after execution.

## Changes From The Source

- Removed the external ADF nightly-pipeline invocation and made `Set LoadRunID Variable` the entry activity.
- Replaced environment-specific endpoints, workspace/item IDs, and connection IDs with the documented placeholders.
- Added the conditional child start and parent `StartLoadRun = false` arguments to avoid three header inserts for one run ID.
- Replaced the original failure logger's multiple `Failed` dependencies with the failed-or-skipped completion route, and added the explicit final failure activity.

Existing loader procedures, SQL parameters, activity policies, and load dependencies are otherwise retained. The original `Load FactGustSatisfaction` activity-name typo is retained; its stored-procedure reference is unchanged.

## Validation

Validation on November 21, 2026 covered JSON parsing, source-preservation checks, placeholder-only public bindings, dependency references, shared-ID/header settings, booking-before-stay ordering, and an offline simulation of the success route and eight failure scenarios.

All three configured definitions were uploaded into temporary, unscheduled Fabric pipelines and retrieved again. Each saved content definition matched its configured upload exactly. Direct placeholder-bound uploads were rejected; configure the bindings before uploading. The temporary pipelines were deleted afterward.

No pipeline was executed during validation. Import acceptance is not proof that connections, SQL loads, Copy Job ingestion, notebook invocation, or end-to-end logging will succeed in a new environment. The live lab pipelines were not modified.