# Property Events

Property Events represents events associated with properties. JSON is the distribution format; Azure Blob Storage is the source location used in Fabric Explained.

## Download

**[Download Property Events ZIP](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/download/property-events-v1.0.0/property-events.zip)** from [Property Events v1.0.0](https://github.com/Guy-in-a-Cube/northstar-sample-data/releases/tag/property-events-v1.0.0). Repository access is required while the repository is private.

Extract the ZIP to get five original files under `property-events/`. The ZIP contains only event data; verification details are in the release notes. Individual JSON files are also assets on the same release. Upload the extracted event files, not the ZIP or release notes, to your own private Blob container. Source account and container names are not required.

The ZIP is 3,768 bytes with SHA-256 `25ce44d89dc4f971477e031e872715ccb9640ebf75e01fc5a744c13e06638ab9`. All five original file names and byte hashes are preserved. This event version is outside the operational snapshot cleanup selector; event-specific retention automation is not configured.

## Included Files and Evidence

Only this guide is included in regular Git files; event data is distributed through the versioned release above. Read-only inspection of the supplied private source on 2026-11-20 verified five files at the container root, with no nested folders. Each contains nine events, for 45 events and 11,038 bytes in total. ETag-conditioned downloads preserved the source bytes; the source container was not changed. The published ZIP and five individual assets were independently downloaded and hash-verified. See [schema evidence](../schema/README.md).

| Source Filename | Bytes | Events | SHA-256 |
| --- | --- | --- | --- |
| `property_events_20260831_01.json` | 2,206 | 9 | `3924f99aa428060945a0eacb063927f6d1c82f1bd98acfcc298883242b1328a4` |
| `property_events_20260831_02.json` | 2,211 | 9 | `cd0bd625bfe927600cf1452176fa1256c40fbad34fac06dd03d7bf968fa51397` |
| `property_events_20260831_03.json` | 2,204 | 9 | `376f6a3e9b10fc31339591b64f28405f184d5125f663a3a9a139d6897292f38c` |
| `property_events_20260831_04.json` | 2,210 | 9 | `b57a1af68b73eccdb61eb8b62ff3b66c6f5733245a822d257a4792a5b67b0c5d` |
| `property_events_20260831_05.json` | 2,207 | 9 | `22335a3b9c208c38158ccf3df13cfcea5b178cd982350f419d235d566dff8c09` |

## Record Format

Despite their `.json` extension and `application/json` source content type, these are newline-delimited JSON (NDJSON), not JSON arrays or single JSON documents. Each nonempty line is one complete event object. All 45 lines parsed successfully as UTF-8 without a BOM, with LF line endings and a final LF. A reader must parse each line separately rather than treat the entire file as one JSON document.

Every observed record has these eight fields. Types and null counts describe this inspected snapshot, not an enforced schema for future files.

| Field | Observed JSON Type | Notes |
| --- | --- | --- |
| `property_code` | Number | Integer values; join to operational `Property.property_code`, not `property_id`. |
| `event_id` | String | 45 distinct identifiers; no duplicate IDs in this snapshot. |
| `event_time` | String | Mixed timestamp formats; retain the original string until timezone handling is defined. |
| `event_type` | String | Ten exact spellings, including case, space, hyphen, and underscore variations. |
| `room_number` | String or null | Ten nulls; non-null values are strings, not JSON numbers. |
| `severity` | String | `HIGH` (10), `MEDIUM` (15), and `LOW` (20). |
| `description` | String | Free-text event description; requires review before each redistribution. |
| `source_system` | String | Property source labels; unmatched codes use `PMS-UNKNOWN`. |

### Source Variations

- All stored event dates are 2026-08-31. The 43 explicitly UTC timestamps span `2026-08-31T08:00:00Z` through `2026-08-31T20:28:00Z`. Two timestamps, `2026-08-31 09:59:00` and `2026-08-31 15:56:00`, have no timezone; do not silently assume they are UTC or local time.
- Exact event-type values are `ROOM_OOS`, `room-oos`, `Room Out Of Service`, `room oos`, `MAINTENANCE`, `maintenance`, `AMENITY_CLOSED`, `Amenity Closed`, `ROOM_RETURNED_TO_SERVICE`, and `room-returned-to-service`. Preserve these strings in the distributed source; any normalization belongs in a separately defined processing step.
- Against the verified operational Property snapshot, 43 events match the 16 property codes. Two events use code `999`, which has no matching property. Do not replace those codes or silently discard their events. Lookup and unmatched-record handling must be explicit.
- No missing fields or duplicate event IDs were observed. Null room numbers are present; null handling should not replace them with an invented room identifier.

Review of all records and screening for URLs, email addresses, storage keys, SAS signatures, and local-path markers found no such markers. On 2026-11-20, the owner separately confirmed these event records are synthetic and approved publishing the original files under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). This dedication covers Property Events data; maintainer-owned repository code and documentation have a separate CC0 approval under [LICENSE](../LICENSE). Source variations were preserved, not normalized.

## General Source Setup

Use the approved release above:

1. Use one dataset release consistently and retain the original meaningful directory structure. Do not flatten nested folders or rename files without understanding how consumers discover them.
2. Provision your own storage account and container. Upload the files, preserving relative paths under your chosen dataset prefix. Do not upload repository documentation as event data.
3. Keep the container private and authorize only the access needed by your workflow. Never put storage account keys, SAS URLs, credentials, or private connection instructions in repository files or public screenshots.
4. Check that the expected paths can be listed and representative files can be read using the identity intended for access. Compare uploaded file counts and checksums to the release inventory. Validate the JSON envelope and record count separately; file counts are not event counts.

Storage account, container, prefix, and downstream item names are yours to choose. Access checks are instructions for learners, not operations performed by this repository.

## Fabric Explained Only

The course accesses the learner's blob storage through a shortcut in a Lakehouse's **Files** section:

1. Use your own Fabric Lakehouse and an authorized Azure Blob Storage connection.
2. In Files, create a new shortcut, choose Azure Blob Storage, and select the uploaded dataset folder using the current Microsoft workflow.
3. Verify that the expected folder hierarchy is visible and files can actually be read through the shortcut. Seeing only the shortcut name is not sufficient proof of readable data.

A plain shortcut provides access to files. It does not itself transform JSON, flatten nested records, or create processed tables. Separate parsing and processing must use the actual supplied schema. A Files shortcut is not automatically registered as a SQL-queryable table.

The existing event-processing example looks up a `Property` table in a Lakehouse. If operational data was imported only into a Warehouse, the example may need an adjustment or a compatible Lakehouse table. The source's `property_code` relationship is now verified, including two unmatched events; the example code, lookup table types, normalization rules, timezone decisions, and unmatched-property behavior remain unsupplied, so unchanged compatibility is not promised.

## Limitations and References

Line-level JSON validity, encoding, field types, root-level layout, record counts, duplicate IDs, and source variations were checked for the five released files only. Future source files require new verification. File or listing order is not a delivery-order guarantee. Processing rules remain unresolved; redistribution of this snapshot is owner-approved. Storage access, network restrictions, connection permissions, and costs must be checked in your environment.

Checked 2026-11-19: [Create an Azure Blob Storage shortcut](https://learn.microsoft.com/en-us/fabric/onelake/shortcuts/create-blob-shortcut) and [shortcuts in a Lakehouse](https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-shortcuts). These document the capability and Files-versus-Tables behavior; no upload, shortcut, or end-to-end processing was tested. Return to the [repository guide](../README.md).