#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [guid]$SqlConnectionId,
    [Parameter(Mandatory)]
    [guid]$BlobConnectionId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$')]
    [string]$Container,
    [ValidatePattern('^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*$')]
    [string]$OutputPrefix = 'operational-data/test-runs',
    [string]$OutputPath,
    [switch]$AllTables,
    [object[]]$SchemaMetadata,
    [ValidateRange(0, 10)]
    [int]$RetryCount = 0,
    [ValidateRange(30, 3600)]
    [int]$RetryIntervalSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($SqlConnectionId -eq [guid]::Empty -or $BlobConnectionId -eq [guid]::Empty) {
    throw 'Connection IDs must not be empty.'
}
if ($Container.Contains('--')) { throw 'Container names must not contain consecutive hyphens.' }

$query = @'
SET NOCOUNT ON;
IF EXISTS (
    SELECT 1
    FROM ops.Property AS p
    CROSS APPLY (VALUES
        (p.property_name), (p.region), (p.market),
        (p.property_type), (p.luxury_tier)
    ) AS text_values(value)
    WHERE text_values.value COLLATE Latin1_General_100_BIN2 = N'\N'
      AND DATALENGTH(text_values.value) = 4
)
    THROW 50002, 'Source text conflicts with the reserved CSV NULL marker.', 1;
SELECT
    property_id,
    property_code,
    property_name,
    region,
    market,
    property_type,
    luxury_tier,
    room_count,
    CONVERT(char(10), open_date, 23) AS open_date,
    REPLACE(CONVERT(char(23), created_at_utc, 121), ' ', 'T') AS created_at_utc,
    REPLACE(CONVERT(char(23), updated_at_utc, 121), ' ', 'T') AS updated_at_utc,
    CONVERT(tinyint, is_deleted) AS is_deleted,
    CONVERT(char(36), source_batch_id) AS source_batch_id
FROM ops.Property
ORDER BY property_id;
'@

$exports = @([pscustomobject]@{ Table = 'Property'; Query = $query })
if ($AllTables) {
    $expectedCounts = [ordered]@{ Booking = 23; Channel = 8; Experience = 8; Guest = 13; Property = 13; PropertyDailyInventory = 10; SatisfactionSurvey = 16; StayNight = 14 }
    if (@($SchemaMetadata).Count -ne 105) { throw 'All-table export requires the verified 105-column source metadata.' }
    $exports = @(foreach ($table in $expectedCounts.Keys) {
        $columns = @($SchemaMetadata | Where-Object { $_.table_name -ceq $table } | Sort-Object column_id)
        $keys = @($columns | Where-Object { $_.is_primary_key -eq $true })
        if ($columns.Count -ne $expectedCounts[$table] -or $keys.Count -ne 1) { throw "Unexpected column count or primary key for $table." }
        $selectColumns = [Collections.Generic.List[string]]::new()
        $textColumns = [Collections.Generic.List[string]]::new()
        foreach ($column in $columns) {
            if ($column.column_name -cnotmatch '^[a-z][a-z0-9_]*$') { throw 'Unexpected column identifier.' }
            $name = '[' + $column.column_name + ']'
            $projection = switch ($column.type_name) {
                'date' { "CONVERT(char(10), $name, 23) AS $name" }
                'datetime2' { "REPLACE(CONVERT(char(23), $name, 121), ' ', 'T') AS $name" }
                'bit' { "CONVERT(tinyint, $name) AS $name" }
                'uniqueidentifier' { "CONVERT(char(36), $name) AS $name" }
                'nvarchar' { $textColumns.Add("($name)"); $name }
                { $_ -in @('int', 'bigint', 'decimal') } { $name }
                default { throw "Unsupported export type: $($column.type_name)" }
            }
            $selectColumns.Add($projection)
        }
        $guard = ''
        if ($textColumns.Count) {
            $guard = "IF EXISTS (SELECT 1 FROM [ops].[$table] CROSS APPLY (VALUES $([string]::Join(', ', $textColumns))) AS text_values(value) WHERE value COLLATE Latin1_General_100_BIN2 = N'\N' AND DATALENGTH(value) = 4) THROW 50002, 'Source text conflicts with the reserved CSV NULL marker.', 1;`n"
        }
        [pscustomobject]@{ Table = $table; Query = "SET NOCOUNT ON;`n${guard}SELECT $([string]::Join(', ', $selectColumns)) FROM [ops].[$table] ORDER BY [$($keys[0].column_name)];" }
    })
}

$activities = @(foreach ($export in $exports) {
            [ordered]@{
                name = 'Export' + $export.Table
                type = 'Copy'
                dependsOn = @()
                policy = @{ timeout = '0.00:15:00'; retry = $RetryCount; retryIntervalInSeconds = $RetryIntervalSeconds; secureInput = $false; secureOutput = $false }
                typeProperties = [ordered]@{
                    source = [ordered]@{
                        type = 'AzureSqlSource'
                        sqlReaderQuery = $export.Query
                        queryTimeout = '00:05:00'
                        partitionOption = 'None'
                        isolationLevel = 'ReadCommitted'
                        datasetSettings = [ordered]@{
                            type = 'AzureSqlTable'
                            schema = @()
                            typeProperties = @{ schema = 'ops'; table = $export.Table }
                            externalReferences = @{ connection = $SqlConnectionId.ToString() }
                        }
                    }
                    sink = [ordered]@{
                        type = 'DelimitedTextSink'
                        storeSettings = @{ type = 'AzureBlobStorageWriteSettings' }
                        formatSettings = @{ type = 'DelimitedTextWriteSettings'; quoteAllText = $true; fileExtension = '.csv' }
                        datasetSettings = [ordered]@{
                            type = 'DelimitedText'
                            schema = @()
                            typeProperties = [ordered]@{
                                location = [ordered]@{
                                    type = 'AzureBlobStorageLocation'
                                    container = $Container
                                    folderPath = @{ type = 'Expression'; value = "@concat('$OutputPrefix/', pipeline().RunId)" }
                                    fileName = $export.Table + '.csv'
                                }
                                columnDelimiter = ','
                                rowDelimiter = "`n"
                                encodingName = 'UTF-8 without BOM'
                                escapeChar = '"'
                                quoteChar = '"'
                                firstRowAsHeader = $true
                                nullValue = '\N'
                            }
                            externalReferences = @{ connection = $BlobConnectionId.ToString() }
                        }
                    }
                    enableStaging = $false
                    parallelCopies = 1
                    enableSkipIncompatibleRow = $false
                    translator = @{ type = 'TabularTranslator'; typeConversion = $false }
                }
            }
})

if ($AllTables) {
    $tokens = @{ '@RUN_ID@' = 'pipeline().RunId' }
    $fileQueries = @(foreach ($export in $exports) {
        $table = $export.Table
        $tokens["@ROWS_${table}@"] = "string(activity('Export$table').output.rowsCopied)"
        $tokens["@BYTES_${table}@"] = "string(activity('Export$table').output.dataWritten)"
        "SELECT 'ops.$table' AS [table], '$table.csv' AS name, CAST(@ROWS_${table}@ AS bigint) AS rows, CAST(@BYTES_${table}@ AS bigint) AS bytes"
    })
    $markerSql = "SELECT (SELECT 1 AS contract_version, 'complete' AS status, '@RUN_ID@' AS run_id, REPLACE(CONVERT(char(23), SYSUTCDATETIME(), 121), ' ', 'T') + 'Z' AS completed_at_utc, JSON_QUERY((SELECT [table], name, rows, bytes FROM ($([string]::Join(' UNION ALL ', $fileQueries))) AS inventory FOR JSON PATH)) AS files FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS completion_json;"
    $expressionParts = @(foreach ($part in [regex]::Split($markerSql, '(@[A-Z_]+(?:[A-Za-z]+)?@)')) {
        if ($tokens.ContainsKey($part)) { $tokens[$part] }
        else { "'" + $part.Replace("'", "''") + "'" }
    })
    $marker = ($activities[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable)
    $marker.name = 'WriteCompletionMarker'
    $marker.dependsOn = @($exports | ForEach-Object { @{ activity = 'Export' + $_.Table; dependencyConditions = @('Succeeded') } })
    $marker.typeProperties.source.sqlReaderQuery = @{ type = 'Expression'; value = '@concat(' + [string]::Join(', ', $expressionParts) + ')' }
    $marker.typeProperties.source.datasetSettings.Remove('typeProperties')
    $marker.typeProperties.sink.formatSettings.quoteAllText = $false
    $marker.typeProperties.sink.formatSettings.fileExtension = '.json'
    $markerFormat = $marker.typeProperties.sink.datasetSettings.typeProperties
    $markerFormat.location.fileName = '_SUCCESS.json'
    $markerFormat.columnDelimiter = "`t"
    $markerFormat.quoteChar = ''
    $markerFormat.escapeChar = ''
    $markerFormat.firstRowAsHeader = $false
    $activities += $marker
}

$definition = [ordered]@{
    properties = [ordered]@{
        description = 'Manual full export; no schedule or publication. Completion marker requires all eight CSVs.'
        activities = $activities
    }
}

$json = $definition | ConvertTo-Json -Depth 30
if ($OutputPath) {
    $stream = [IO.File]::Open([IO.Path]::GetFullPath($OutputPath), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
} else {
    $json
}