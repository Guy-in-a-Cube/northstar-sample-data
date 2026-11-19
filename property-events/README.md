# Property Events

Property Events represents events associated with properties. JSON is the distribution format; Azure Blob Storage is the source location used in Fabric Explained.

## Included Files and Evidence

Only this guide is included. No JSON files or folder hierarchy were supplied, so there is no `json/` directory yet. Filenames, event types, record envelopes, fields, row grain, identifiers, timestamps, timezones, event counts, and date coverage are unknown. One file might contain one record, an array, or another structure; no parser settings are prescribed without evidence. See [schema evidence](../schema/README.md).

## General Source Setup

Once the approved JSON files are supplied:

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

The existing event-processing example looks up a `Property` table in a Lakehouse. If operational data was imported only into a Warehouse, the example may need an adjustment or a compatible Lakehouse table. The example code, lookup schema, identifier relationship, and unmatched-property behavior are not supplied, so unchanged compatibility is not promised.

## Limitations and References

JSON validity, encoding, schema, partition layout, event ordering, duplicates, and missing/null handling cannot be verified without the files. Do not assume newline-delimited JSON, a single-object format, or UTC timestamps. Storage access, network restrictions, connection permissions, and costs must be checked in your environment.

Checked 2026-11-19: [Create an Azure Blob Storage shortcut](https://learn.microsoft.com/en-us/fabric/onelake/shortcuts/create-blob-shortcut) and [shortcuts in a Lakehouse](https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-shortcuts). These document the capability and Files-versus-Tables behavior; no upload, shortcut, or end-to-end processing was tested. Return to the [repository guide](../README.md).