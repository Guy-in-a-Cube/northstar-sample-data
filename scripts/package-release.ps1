#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*)?$')]
    [string]$Version,
    [switch]$CreateZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$paths = @([IO.File]::ReadAllLines((Join-Path $root 'release-files.txt')) |
    Where-Object { $_.Trim().Length -gt 0 -and -not $_.StartsWith('#') })
if ($paths.Count -eq 0) { throw 'The release file list is empty.' }
$selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$hashes = @{}

foreach ($relative in $paths) {
    if ($relative -ne $relative.Trim() -or $relative -match '\\|:|^/|(^|/)\.{1,2}(/|$)' -or
        $relative -match '(^|/)(\.[^/]+|dist|node_modules|secrets?|private)(/|$)' -or
        $relative -notmatch '^(README\.md|RELEASE\.md|release-files\.txt|LICENSE(?:\.[A-Za-z0-9]+)?|NOTICE(?:\.txt)?|scripts/package-release\.ps1|schema/.+\.(md|sql|json)|operational-data/(README\.md|csv/.+\.csv)|property-budget/(README\.md|[^/]+\.csv)|property-events/(README\.md|json/.+\.json))$') {
        throw "Disallowed release path: $relative"
    }
    if (-not $selected.Add($relative)) { throw "Duplicate release path: $relative" }
    $fullPath = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $fullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes the repository: $relative"
    }
    $item = Get-Item -LiteralPath $fullPath -Force
    if ($item.PSIsContainer) { throw "Expected a file: $relative" }
    while ($null -ne $item) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked paths are not allowed: $relative" }
        if ($item.FullName -eq $root) { break }
        if ($item -is [IO.DirectoryInfo]) { $item = $item.Parent }
        else { $item = $item.Directory }
    }
    $hashes[$relative] = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    if ($relative.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
        $stream = [IO.File]::OpenRead($fullPath)
        try {
            $document = [Text.Json.JsonDocument]::Parse($stream)
            $document.Dispose()
        } finally { $stream.Dispose() }
    }
}

foreach ($relative in $paths | Where-Object { $_ -like '*.md' }) {
    $fullPath = Join-Path $root $relative
    $text = [IO.File]::ReadAllText($fullPath)
    foreach ($match in [regex]::Matches($text, '\[[^\]]*\]\(([^\s)]+)\)')) {
        $target = $match.Groups[1].Value
        if ($target -match '^[A-Za-z][A-Za-z0-9+.-]*:|^#') { continue }
        $target = [uri]::UnescapeDataString(($target -split '[#?]', 2)[0])
        $resolved = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($fullPath)) $target))
        if (-not $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Documentation link escapes the repository in $relative"
        }
        $linked = [IO.Path]::GetRelativePath($root, $resolved).Replace('\', '/')
        if (-not $selected.Contains($linked)) { throw "Link target is missing from package: $relative -> $target" }
    }
}

$csvCount = @($paths | Where-Object { $_ -like '*.csv' }).Count
$jsonCount = @($paths | Where-Object { $_ -like '*.json' }).Count
Write-Output "Validated $($paths.Count) selected paths and relative Markdown file links; JSON documents: $jsonCount."
Write-Output "CSV files selected: $csvCount. CSV parsing and record counts require separately verified source settings."
if ($csvCount -eq 0 -and $jsonCount -eq 0) { Write-Warning 'No data assets supplied; data validation is unavailable.' }
if (-not $CreateZip) { return }

$outputDirectory = Join-Path $root 'dist'
if (Test-Path -LiteralPath $outputDirectory) {
    $directoryItem = Get-Item -LiteralPath $outputDirectory -Force
    if (-not $directoryItem.PSIsContainer -or ($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The output directory must be a regular local directory.'
    }
} else { [IO.Directory]::CreateDirectory($outputDirectory) | Out-Null }
$zipPath = Join-Path $outputDirectory "northstar-sample-data-$Version.zip"
$zipStream = [IO.File]::Open($zipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new($zipStream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($relative in $paths) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $root $relative), "northstar-sample-data/$relative") | Out-Null
        }
    } finally { $archive.Dispose() }
    $zipStream.Position = 0
    $archive = [IO.Compression.ZipArchive]::new($zipStream, [IO.Compression.ZipArchiveMode]::Read, $true)
    try {
        if ($archive.Entries.Count -ne $paths.Count) { throw 'Archive entry count mismatch.' }
        foreach ($entry in $archive.Entries) {
            if (-not $entry.FullName.StartsWith('northstar-sample-data/', [StringComparison]::Ordinal)) { throw 'Unexpected archive root.' }
            $relative = $entry.FullName.Substring('northstar-sample-data/'.Length)
            if (-not $selected.Contains($relative)) { throw 'Unexpected archive entry.' }
            $entryStream = $entry.Open()
            $sha256 = [Security.Cryptography.SHA256]::Create()
            try { $actual = [BitConverter]::ToString($sha256.ComputeHash($entryStream)).Replace('-', '') }
            finally { $sha256.Dispose(); $entryStream.Dispose() }
            if ($actual -ne $hashes[$relative]) { throw "Archive content mismatch: $relative" }
        }
    } finally { $archive.Dispose() }
} catch {
    $zipStream.Dispose()
    [IO.File]::Delete($zipPath)
    throw
} finally { $zipStream.Dispose() }
Write-Output "Created and verified local candidate: $zipPath"
Write-Output "SHA256: $((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash)"
Write-Warning 'Local packaging is not redistribution or publication approval.'