#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName = 'Local')]
    [string]$Directory,
    [Parameter(Mandatory, ParameterSetName = 'Azure')]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string]$StorageAccount,
    [Parameter(Mandatory, ParameterSetName = 'Azure')]
    [ValidatePattern('^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$')]
    [string]$Container,
    [Parameter(ParameterSetName = 'Azure')]
    [ValidatePattern('^(?:[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})?$')]
    [string]$RunId,
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [switch]$RequireCurrentDay,
    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputPath) { throw 'Refusing to overwrite a release candidate.' }
$tables = [ordered]@{
    Booking = @(23, 'booking_id')
    Channel = @(8, 'channel_id')
    Experience = @(8, 'experience_id')
    Guest = @(13, 'guest_id')
    Property = @(13, 'property_id')
    PropertyDailyInventory = @(10, 'property_inventory_id')
    SatisfactionSurvey = @(16, 'survey_id')
    StayNight = @(14, 'stay_night_id')
}

function Read-ExportMarker {
    param([string]$Path)
    $text = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false, $true))
    $document = [Text.Json.JsonDocument]::Parse($text)
    try { $timestamp = $document.RootElement.GetProperty('completed_at_utc').GetString() }
    finally { $document.Dispose() }
    $value = ConvertFrom-Json -InputObject $text
    $value.completed_at_utc = $timestamp
    if ($value.contract_version -ne 1 -or $value.status -cne 'complete' -or
        $value.run_id -cnotmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') {
        throw 'Unsupported, incomplete, or invalid completion marker.'
    }
    $parsedTimestamp = [DateTimeOffset]::MinValue
    if ($timestamp -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$' -or
        -not [DateTimeOffset]::TryParseExact($timestamp, "yyyy-MM-dd'T'HH:mm:ss.fff'Z'",
            [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsedTimestamp)) {
        throw 'Invalid completion timestamp.'
    }
    return $value
}

if ($PSCmdlet.ParameterSetName -eq 'Azure') {
    foreach ($variable in 'AZURE_STORAGE_KEY', 'AZURE_STORAGE_SAS_TOKEN', 'AZURE_STORAGE_CONNECTION_STRING') {
        if ([Environment]::GetEnvironmentVariable($variable)) { throw "Remove $variable; only Entra login is supported." }
    }
    $storageArguments = @('--account-name', $StorageAccount, '--container-name', $Container, '--auth-mode', 'login', '--only-show-errors')
    $blobs = @(az storage blob list @storageArguments --prefix 'operational-data/runs/' --num-results '*' --output json | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Could not list operational export blobs.' }
    $markerBlobs = @($blobs | Where-Object {
        $_.name -cmatch '^operational-data/runs/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/_SUCCESS\.json$' -and
        (-not $RunId -or $_.name -ceq "operational-data/runs/$RunId/_SUCCESS.json")
    })
    if ($markerBlobs.Count -eq 0) { throw 'No completed export matching the request was found.' }
    $cachePath = "$outputPath-markers"
    $downloadPath = "$outputPath-export"
    if ((Test-Path -LiteralPath $cachePath) -or (Test-Path -LiteralPath $downloadPath)) {
        throw 'Refusing to overwrite previously downloaded export files.'
    }
    [IO.Directory]::CreateDirectory($cachePath) | Out-Null
    $candidates = foreach ($blob in $markerBlobs) {
        if ($blob.properties.contentLength -gt 65536) { throw 'Completion marker is unexpectedly large.' }
        $blobRunId = ($blob.name -split '/')[2]
        $cachedMarker = Join-Path $cachePath "$blobRunId.json"
        az storage blob download @storageArguments --name $blob.name --file $cachedMarker --if-match $blob.properties.etag --validate-content --no-progress --output none
        if ($LASTEXITCODE -ne 0) { throw 'Could not download an unchanged completion marker.' }
        $value = Read-ExportMarker -Path $cachedMarker
        if ($value.run_id -cne $blobRunId) { throw 'Marker run ID does not match its blob folder.' }
        [pscustomobject]@{ Marker = $value; Blob = $blob; Path = $cachedMarker }
    }
    $selected = $candidates | Sort-Object { $_.Marker.completed_at_utc }, { $_.Marker.run_id } -Descending | Select-Object -First 1
    $prefix = "operational-data/runs/$($selected.Marker.run_id)/"
    $runBlobs = @($blobs | Where-Object { $_.name.StartsWith($prefix, [StringComparison]::Ordinal) })
    $runNames = @($tables.Keys | ForEach-Object { "$prefix$_.csv" }) + "$prefix`_SUCCESS.json"
    if ($runBlobs.Count -ne $runNames.Count -or @($runBlobs | Where-Object { $runNames -cnotcontains $_.name }).Count -ne 0) {
        throw 'Selected blob folder must contain exactly eight CSVs and one marker.'
    }
    [IO.Directory]::CreateDirectory($downloadPath) | Out-Null
    foreach ($blob in $runBlobs) {
        $name = $blob.name.Substring($prefix.Length)
        az storage blob download @storageArguments --name $blob.name --file (Join-Path $downloadPath $name) --if-match $blob.properties.etag --validate-content --no-progress --output none
        if ($LASTEXITCODE -ne 0) { throw "Could not download unchanged export file: $name" }
    }
    $after = @(az storage blob list @storageArguments --prefix $prefix --num-results '*' --output json | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0 -or $after.Count -ne $runBlobs.Count) { throw 'Export inventory changed during download.' }
    foreach ($blob in $runBlobs) {
        $matches = @($after | Where-Object { $_.name -ceq $blob.name })
        if ($matches.Count -ne 1 -or $matches[0].properties.etag -cne $blob.properties.etag) {
            throw 'An export file changed during download.'
        }
    }
    $Directory = $downloadPath
}

$directoryPath = [IO.Path]::GetFullPath($Directory)
$directoryItem = Get-Item -LiteralPath $directoryPath -Force
if (-not $directoryItem.PSIsContainer -or ($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Export directory must be a regular local directory.'
}
$expectedNames = @($tables.Keys | ForEach-Object { "$_.csv" }) + '_SUCCESS.json'
$items = @(Get-ChildItem -LiteralPath $directoryPath -Force)
if ($items.Count -ne $expectedNames.Count) { throw 'Export must contain exactly eight CSVs and _SUCCESS.json.' }
foreach ($item in $items) {
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $expectedNames -cnotcontains $item.Name) { throw "Unexpected export path: $($item.Name)" }
}
$markerPath = Join-Path $directoryPath '_SUCCESS.json'
$marker = Read-ExportMarker -Path $markerPath
$completed = [DateTimeOffset]::Parse($marker.completed_at_utc, [Globalization.CultureInfo]::InvariantCulture)
if ($RequireCurrentDay) {
    $now = [DateTimeOffset]::UtcNow
    if ($completed.UtcDateTime.Date -ne $now.UtcDateTime.Date -or $completed -gt $now) {
        throw 'Scheduled publishing requires a completed export from today (UTC), not a stale or future marker.'
    }
}
if (@($marker.files).Count -ne $tables.Count) { throw 'Marker must contain exactly eight inventory entries.' }
foreach ($table in $tables.Keys) {
    $entries = @($marker.files | Where-Object { $_.name -ceq "$table.csv" })
    if ($entries.Count -ne 1 -or $entries[0].table -cne "ops.$table") { throw "Invalid inventory entry: $table" }
    foreach ($field in 'rows', 'bytes') {
        $value = $entries[0].$field
        if (($value -isnot [long] -and $value -isnot [int]) -or $value -lt 0) { throw "Invalid $field for $table" }
    }
    if ((Get-Item -LiteralPath (Join-Path $directoryPath "$table.csv")).Length -ne $entries[0].bytes) {
        throw "Byte size mismatch: $table"
    }
}

if (-not ('NorthstarReleaseCsvValidator' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using Microsoft.VisualBasic.FileIO;

public static class NorthstarReleaseCsvValidator
{
    public static long CountRows(string path, int columnCount, string primaryKey)
    {
        using (FileStream stream = File.OpenRead(path))
        {
            if (stream.ReadByte() == 0xEF && stream.ReadByte() == 0xBB && stream.ReadByte() == 0xBF)
                throw new InvalidDataException("UTF-8 BOM is not allowed: " + path);
        }
        using (FileStream stream = File.OpenRead(path))
        using (TextFieldParser parser = new TextFieldParser(stream, new UTF8Encoding(false, true), false, true))
        {
            parser.TextFieldType = FieldType.Delimited;
            parser.SetDelimiters(",");
            parser.HasFieldsEnclosedInQuotes = true;
            parser.TrimWhiteSpace = false;
            string[] header = parser.ReadFields();
            if (header == null || header.Length != columnCount || header[0] != primaryKey)
                throw new InvalidDataException("Unexpected CSV header: " + path);
            HashSet<string> columns = new HashSet<string>(StringComparer.Ordinal);
            foreach (string column in header)
                if (String.IsNullOrWhiteSpace(column) || !columns.Add(column))
                    throw new InvalidDataException("Invalid or duplicate header: " + path);
            long rows = 0;
            while (!parser.EndOfData)
            {
                string[] fields = parser.ReadFields();
                if (fields == null || fields.Length != columnCount)
                    throw new InvalidDataException("Unexpected field count: " + path);
                rows++;
            }
            return rows;
        }
    }
}
'@
}

$inventory = foreach ($table in $tables.Keys) {
    $filePath = Join-Path $directoryPath "$table.csv"
    $entry = @($marker.files | Where-Object { $_.name -ceq "$table.csv" })[0]
    Write-Verbose "Validating $table"
    $rows = [NorthstarReleaseCsvValidator]::CountRows($filePath, $tables[$table][0], $tables[$table][1])
    if ($rows -ne $entry.rows) { throw "Row count mismatch: $table" }
    [ordered]@{
        table = $entry.table
        name = $entry.name
        archive_path = "operations-data/$($entry.name)"
        rows = $rows
        bytes = $entry.bytes
        sha256 = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$manifest = [ordered]@{
    contract_version = 1
    run_id = $marker.run_id
    completed_at_utc = $marker.completed_at_utc
    data_license = 'CC0-1.0'
    data_license_url = 'https://creativecommons.org/publicdomain/zero/1.0/'
    files = @($inventory)
    completion_marker_sha256 = (Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$tag = "operational-$($completed.ToString('yyyyMMddTHHmmssfffZ'))-$($marker.run_id)"
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$encoding = [Text.UTF8Encoding]::new($false)

function New-VerifiedArchive {
    param([string]$Path, [object[]]$Entries)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($entry in $Entries) {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $entry.source, $entry.name) | Out-Null
            }
        } finally { $archive.Dispose() }
        $stream.Position = 0
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read, $true)
        try {
            if ($archive.Entries.Count -ne $Entries.Count) { throw 'Archive entry count mismatch.' }
            foreach ($entry in $archive.Entries) {
                $expected = @($Entries | Where-Object { $_.name -ceq $entry.FullName })
                if ($expected.Count -ne 1) { throw 'Unexpected archive path.' }
                $entryStream = $entry.Open()
                $hash = [Security.Cryptography.SHA256]::Create()
                try { $actual = [BitConverter]::ToString($hash.ComputeHash($entryStream)).Replace('-', '').ToLowerInvariant() }
                finally { $hash.Dispose(); $entryStream.Dispose() }
                if ($actual -cne $expected[0].sha256) { throw "Archive content mismatch: $($entry.FullName)" }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
}

$dataArchive = Join-Path $outputPath 'operations-data.zip'
$dataEntries = @($inventory | ForEach-Object {
    [pscustomobject]@{ source = Join-Path $directoryPath $_.name; name = $_.archive_path; sha256 = $_.sha256 }
})
New-VerifiedArchive -Path $dataArchive -Entries $dataEntries
$manifest['data_archive'] = [ordered]@{
    name = 'operations-data.zip'
    bytes = (Get-Item -LiteralPath $dataArchive).Length
    sha256 = (Get-FileHash -LiteralPath $dataArchive -Algorithm SHA256).Hash.ToLowerInvariant()
}
$manifestPath = Join-Path $outputPath 'release-manifest.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6) + "`n", $encoding)
$checksums = @($inventory | ForEach-Object { "$($_.sha256)  $($_.archive_path)" })
$checksums += "$($manifest.completion_marker_sha256)  validation/_SUCCESS.json"
$checksums += "$((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant())  validation/release-manifest.json"
$checksums += "$($manifest.data_archive.sha256)  operations-data.zip"
[IO.File]::WriteAllText((Join-Path $outputPath 'SHA256SUMS.txt'), ($checksums -join "`n") + "`n", $encoding)
$validationArchive = Join-Path $outputPath 'operations-data-validation.zip'
$validationEntries = @(
    [pscustomobject]@{ source = $markerPath; name = 'validation/_SUCCESS.json'; sha256 = $manifest.completion_marker_sha256 }
    [pscustomobject]@{ source = $manifestPath; name = 'validation/release-manifest.json'; sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    [pscustomobject]@{ source = Join-Path $outputPath 'SHA256SUMS.txt'; name = 'validation/SHA256SUMS.txt'; sha256 = (Get-FileHash -LiteralPath (Join-Path $outputPath 'SHA256SUMS.txt') -Algorithm SHA256).Hash.ToLowerInvariant() }
)
New-VerifiedArchive -Path $validationArchive -Entries $validationEntries
$downloads = if ($Repository) { "https://github.com/$Repository/releases/download/$tag" } else { '.' }
$notes = @"
[Download CSVs]($downloads/operations-data.zip)

The data ZIP contains only the eight CSVs under operations-data/. Individual CSV downloads are also available.

[Validation bundle]($downloads/operations-data-validation.zip)

The optional validation ZIP contains the completion marker, manifest, and checksums under validation/. Extract it beside operations-data/ to check CSV hashes. Download links become available when this draft is published; draft reviewers can use the asset list.

Manual draft of the Northstar operational data snapshot completed at $($marker.completed_at_utc).

Run: $($marker.run_id)

Eight full-table CSVs, including audit columns and soft-deleted rows. This is not a database-wide transactional snapshot.

Operational data assets are dedicated under CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . This does not select a license for repository code or documentation.

File inventory, row counts, byte sizes, UTF-8 decoding, and CSV structure were validated before preparing this draft. SHA256SUMS.txt records downloaded asset hashes; these are not an independent comparison against the SQL source. Data ZIP entry paths and content hashes were verified without changing the CSV bytes.
"@
[IO.File]::WriteAllText((Join-Path $outputPath 'release-notes.md'), $notes + "`n", $encoding)
[ordered]@{
    tag = $tag
    title = "Northstar operational data - $($marker.completed_at_utc)"
    run_id = $marker.run_id
    files = @($inventory | ForEach-Object { Join-Path $directoryPath $_.name }) + @($dataArchive, $validationArchive)
    notes = Join-Path $outputPath 'release-notes.md'
} | ConvertTo-Json -Depth 4