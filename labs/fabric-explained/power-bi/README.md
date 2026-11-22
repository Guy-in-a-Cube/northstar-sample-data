# Fabric Explained - Power BI Checkpoint

The Northstar Property Health report and `sm_northstar` semantic model are packaged together as a Power BI Project (PBIP). This is a definition-only checkpoint: no cached model data, credentials, service identities, or refresh schedules are included.

| Artifact | Contents |
| --- | --- |
| [Northstar Property Health.pbip](Northstar%20Property%20Health.pbip) | Project entry point linking the report to its local semantic model. |
| [Report definition](Northstar%20Property%20Health.Report/definition.pbir) | PBIR report with one Property Health page, 24 visual containers, two bookmarks, and its exported base theme. |
| [Semantic model definition](sm_northstar.SemanticModel/definition/model.tmdl) | TMDL for 11 tables, 117 columns, 62 measures, and 22 relationships. |

Keep both artifact folders beside the PBIP file. The report uses a relative `byPath` reference to `sm_northstar.SemanticModel`; it is not connected to the original service model.

## Prerequisites

- A lab Fabric workspace on a supported capacity, with permission to read its Warehouse through OneLake.
- A loaded `wh_northstar` Warehouse using the [Warehouse scripts](../warehouse/README.md). Load dimensions and facts using the [pipeline guide](../pipelines/README.md) or the documented procedure lifecycle.
- A current Power BI Desktop build supporting PBIP, TMDL, PBIR, and Direct Lake on OneLake. Enable applicable preview features if required by your build.
- Access to the model's source tables and appropriate Power BI/Fabric licensing for your chosen authoring and publishing workflow.

All 11 table partitions retain **Direct Lake on OneLake**, using the Warehouse's `dw` tables. This is not an Import snapshot or a DirectQuery model, even though the model-level default mode is Import. Do not convert its partitions just to bypass a connection problem.

## Configure Your Working Copy

Replace the following placeholders before opening or deploying the checkpoint. Use your own working copy and keep environment bindings out of the shared repository.

| Placeholder | Location | Replacement |
| --- | --- | --- |
| `00000000-0000-0000-0000-000000000001` | [expressions.tmdl](sm_northstar.SemanticModel/definition/expressions.tmdl) | Your Fabric workspace ID. |
| `00000000-0000-0000-0000-000000000002` | [expressions.tmdl](sm_northstar.SemanticModel/definition/expressions.tmdl) | Your Warehouse item ID, not its SQL endpoint or semantic-model ID. |
| `__PROPERTY_IMAGE_BASE_URL__` | [DimProperty.tmdl](sm_northstar.SemanticModel/definition/tables/DimProperty.tmdl) | An accessible image folder URL ending in `/`. Replace all three occurrences. |

The shared `DatabaseQuery` expression should resolve to:

```text
https://onelake.dfs.fabric.microsoft.com/{workspaceId}/{warehouseId}
```

Leave the `dw` schema and table mappings unchanged unless you intentionally adapted the Warehouse. The placeholder UUIDs are not working defaults. Replacing them does not grant permissions or authenticate you to Fabric.

## Property Images

Property-image files are **not included in this checkpoint**. The exported report retains its image bindings, and the image measures retain their original filename logic. Image content will not work until you supply the corresponding files and configure their base URL.

- `Property Image URL` uses the numbered filename mapping, such as `01_Alpine_Crest.png`.
- `Property Image URL NS` and `Property Image URL Property` remove spaces from property names, such as `AlpineCrest.png`, and use `NorthStarCollection.png` when no property is selected.

The complete mappings remain in the linked DimProperty TMDL. Supply the filenames used by your selected measure, and make sure Power BI can retrieve the images. An authenticated OneLake URL is not automatically a publicly accessible image URL; test access in your intended report environment. No original image workspace or Lakehouse is referenced by the distributed model.

## Open And Inspect

1. Download the repository's lab files and keep the project folder structure intact. See the [repository download guide](../../../README.md) for the separate source datasets.
2. Prepare and load your Warehouse, then configure the placeholders above.
3. Open `Northstar Property Health.pbip` in a compatible Power BI Desktop build and authenticate to your own Fabric source when prompted.
4. Check that the Property Health page, visuals, slicers, and both bookmarks load correctly. Verify property images separately.
5. Compare the model's table and relationship inventory with the counts above, and verify the results against your loaded Warehouse before using or publishing the report.

There is no embedded data cache, so this checkpoint is not an offline report. Opening it without valid source bindings and permissions is not an end-to-end test. Follow the supported Direct Lake authoring workflow for your Desktop build; if local Direct Lake project editing is unavailable, use Fabric model authoring rather than silently changing the storage mode.

For service deployment, create the semantic model first and then bind a report working copy to the newly created service model. The local `byPath` reference must be replaced with a service `byConnection` reference for that workflow. Deployment, permission assignment, and refresh execution are not performed by these files.

See Microsoft's [PBIP overview](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview), [semantic-model project documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset), and [report project documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report).

## Source Preservation

The checkpoint was exported on November 22, 2026. Existing table, column, relationship, measure, hierarchy, description, and formatting definitions are retained, except for the documented source URL substitutions. Report page, visual, bookmark, and theme payloads are retained byte-for-byte.

Portability changes are limited to:

- Replacing the Warehouse workspace/item IDs and all three property-image base URLs with placeholders.
- Removing the semantic model's original service database ID and excluded-demo bookkeeping reference. Object lineage tags remain; they identify model objects, not live service bindings.
- Replacing the report's service connection with a relative local model reference.
- Adding the PBIP entry point and semantic-model project metadata, and omitting the report's `.platform` service metadata.

No deployment framework, additional source items, or image downloads are included.

## Verification Status

- All 51 checkpoint files match the source exports plus the documented portability changes.
- The sanitized TMDL loads through the modeling engine with 11 tables, 62 measures, and 22 relationships.
- All 11 Direct Lake partitions retain their `dw` table mappings and shared source expression.
- PBIR validation passes with zero errors and zero warnings. All 98 checked report field references resolve to the model, and the project paths resolve locally.
- The distributed files were checked for the original live source bindings, including legacy image locations; none remain.

On November 22, 2026, the maintainer reported that the checkpoint worked during a manual Desktop check. The earlier automated test of a separately configured, ignored copy remained blocked with the Desktop bridge host-not-ready and the window Untitled. No automated screenshot, property-image access, or metric-result assertions are claimed. Verify reconnection, image access, and report results in your own prepared lab environment.

The live semantic model and report were not modified, refreshed, or republished during export and validation.