#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$SourcePath,
    [Parameter(Mandatory)] [string]$OutputDirectory,
    [Parameter(Mandatory)] [ValidatePattern('^[0-9a-f]{64}$')] [string]$ExpectedSourceSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = Get-Item -LiteralPath $SourcePath
if ($source -isnot [IO.FileInfo] -or $source.LinkType -in @('SymbolicLink', 'Junction')) { throw 'Source must be a workbook file, not a symbolic link.' }
if ((Get-FileHash -LiteralPath $source.FullName).Hash.ToLowerInvariant() -cne $ExpectedSourceSha256) { throw 'Source changed since approval review.' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Output already exists; refusing overwrite.' }
$required = @(
    '[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml', 'xl/styles.xml',
    'xl/theme/theme1.xml', 'xl/sharedStrings.xml', 'xl/worksheets/sheet1.xml',
    'xl/tables/table1.xml', 'xl/worksheets/_rels/sheet1.xml.rels', 'xl/_rels/workbook.xml.rels'
)
$sourceArchive = [IO.Compression.ZipFile]::OpenRead($source.FullName)
function Read-Part([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create($stream, $settings)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
        return ,$document
    } finally { $reader.Dispose(); $stream.Dispose() }
}
function Resolve-Target([string]$RelationshipPart, [string]$Target) {
    $owner = if ($RelationshipPart -ceq '_rels/.rels') { '' }
        else { $RelationshipPart -replace '/_rels/([^/]+)\.rels$', '/$1' }
    ([Uri]::new([Uri]('https://package.invalid/' + $owner), $Target)).AbsolutePath.TrimStart('/')
}
function Get-PartHash([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant() }
    finally { $stream.Dispose() }
}
try {
    $names = @($sourceArchive.Entries.FullName)
    if (@($names | Group-Object | Where-Object Count -GT 1).Count) { throw 'Duplicate package parts.' }
    $removed = @($names | Where-Object { $_ -match '^(customXml/|docProps/|\[trash\]/)' })
    $retained = @($names | Where-Object { $_ -cnotin $removed })
    if (@(Compare-Object $required $retained -CaseSensitive).Count) { throw 'Workbook structure differs from reviewed single-table format.' }
    $sheet = Read-Part $sourceArchive.GetEntry('xl/worksheets/sheet1.xml')
    $table = Read-Part $sourceArchive.GetEntry('xl/tables/table1.xml')
    $headers = @($table.SelectNodes('//*[local-name()="tableColumn"]') | ForEach-Object { $_.GetAttribute('name') })
    if ($table.DocumentElement.GetAttribute('name') -cne 'PropertyBudgetTable' -or
        [string]::Join('|', $headers) -cne 'PropertyCode|PropertyName|BudgetMonth|BudgetRevenue|BudgetOccupancyPct') { throw 'Unexpected budget table contract.' }
    if ($sheet.SelectNodes('//*[local-name()="f"]').Count) { throw 'Formula workbook requires separate review.' }
    $rows = @($sheet.SelectNodes('//*[local-name()="sheetData"]/*[local-name()="row"]') | Where-Object { $_.SelectNodes('./*[local-name()="c"]/*[local-name()="v" or local-name()="is"]').Count })
    if ($rows.Count -lt 2 -or $table.DocumentElement.GetAttribute('ref') -cne "A1:E$($rows.Count)") { throw 'Unexpected table bounds or empty workbook.' }
    $hashes = @{}
    $updated = @{}
    foreach ($name in $retained) {
        $entry = $sourceArchive.GetEntry($name)
        $document = Read-Part $entry
        if ($document.OuterXml -match '(?i)([a-z0-9-]+\.sharepoint\.com|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|AccountKey\s*=|[?&]sig=|[A-Z]:\\)') {
            throw "Private-data marker in retained part: $name"
        }
        if ($name.EndsWith('.rels', [StringComparison]::Ordinal)) {
            foreach ($relationship in @($document.SelectNodes('//*[local-name()="Relationship"]'))) {
                if ($relationship.GetAttribute('TargetMode') -ceq 'External') { throw 'External relationship requires separate review.' }
                $target = Resolve-Target $name $relationship.GetAttribute('Target')
                if ($target -cin $removed) { [void]$relationship.ParentNode.RemoveChild($relationship) }
                elseif ($target -cnotin $retained) { throw "Missing relationship target in $name" }
            }
            $updated[$name] = $document
        } elseif ($name -ceq '[Content_Types].xml') {
            foreach ($override in @($document.SelectNodes('//*[local-name()="Override"]'))) {
                if ($override.GetAttribute('PartName').TrimStart('/') -cin $removed) { [void]$override.ParentNode.RemoveChild($override) }
            }
            foreach ($default in @($document.SelectNodes('//*[local-name()="Default"]'))) {
                if ($default.GetAttribute('Extension') -ceq 'dat') { [void]$default.ParentNode.RemoveChild($default) }
            }
            $updated[$name] = $document
        } else { $hashes[$name] = Get-PartHash $entry }
    }
    [void][IO.Directory]::CreateDirectory($output)
    $asset = Join-Path $output $source.Name
    $fileStream = [IO.File]::Open($asset, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite)
    $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($name in $retained) {
            $destination = $archive.CreateEntry($name).Open()
            try {
                if ($updated.ContainsKey($name)) {
                    $settings = [Xml.XmlWriterSettings]::new()
                    $settings.Encoding = [Text.UTF8Encoding]::new($false)
                    $writer = [Xml.XmlWriter]::Create($destination, $settings)
                    try { $updated[$name].Save($writer) } finally { $writer.Dispose() }
                } else {
                    $inputStream = $sourceArchive.GetEntry($name).Open()
                    try { $inputStream.CopyTo($destination) } finally { $inputStream.Dispose() }
                }
            } finally { $destination.Dispose() }
        }
    } finally { $archive.Dispose(); $fileStream.Dispose() }
    $check = [IO.Compression.ZipFile]::OpenRead($asset)
    try {
        if (@(Compare-Object $retained @($check.Entries.FullName) -CaseSensitive).Count) { throw 'Output package inventory mismatch.' }
        foreach ($name in $retained) {
            $document = Read-Part $check.GetEntry($name)
            if ($hashes.ContainsKey($name) -and (Get-PartHash $check.GetEntry($name)) -cne $hashes[$name]) { throw "Workbook content changed: $name" }
            foreach ($relationship in @($document.SelectNodes('//*[local-name()="Relationship"]'))) {
                if ((Resolve-Target $name $relationship.GetAttribute('Target')) -cnotin $retained) { throw 'Cleaned package has a dangling relationship.' }
            }
        }
    } finally { $check.Dispose() }
    if ((Get-FileHash -LiteralPath $source.FullName).Hash.ToLowerInvariant() -cne $ExpectedSourceSha256) { throw 'Original workbook changed during preparation.' }
    [pscustomobject]@{
        asset = $asset; bytes = (Get-Item -LiteralPath $asset).Length
        sha256 = (Get-FileHash -LiteralPath $asset).Hash.ToLowerInvariant()
        source_sha256 = $ExpectedSourceSha256; rows = $rows.Count - 1
        table = 'PropertyBudgetTable'; removed_parts = $removed
        unchanged_content_parts = @($hashes.Keys | Sort-Object)
    } | ConvertTo-Json -Depth 4
} finally { $sourceArchive.Dispose() }