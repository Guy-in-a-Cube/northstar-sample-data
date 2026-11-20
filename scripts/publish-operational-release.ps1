#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PlanPath,
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository,
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$Commit,
    [Parameter(Mandatory)]
    [string[]]$ProtectedTags,
    [ValidateRange(1, 365)]
    [int]$KeepSnapshots = 7,
    [switch]$Publish,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
$pattern = '^operational-\d{8}T\d{9}Z-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
if ($plan.tag -cnotmatch $pattern -or $plan.files.Count -ne 10) { throw 'Invalid operational release plan.' }
$names = @($plan.files | ForEach-Object { [IO.Path]::GetFileName($_) })
$expectedNames = @('Booking.csv', 'Channel.csv', 'Experience.csv', 'Guest.csv', 'Property.csv',
    'PropertyDailyInventory.csv', 'SatisfactionSurvey.csv', 'StayNight.csv', 'operations-data.zip', 'operations-data-validation.zip')
if (@(Compare-Object $expectedNames $names -CaseSensitive).Count -ne 0) { throw 'Release plan asset names mismatch.' }
$localAssets = @{}
foreach ($path in $plan.files) {
    $file = Get-Item -LiteralPath $path
    if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ge 2GB) {
        throw 'Invalid local release asset.'
    }
    $localAssets[$file.Name] = [pscustomobject]@{ size = $file.Length; digest = 'sha256:' + (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() }
}
$validationPath = @($plan.files | Where-Object { [IO.Path]::GetFileName($_) -ceq 'operations-data-validation.zip' })[0]
$localManifest = Get-Content -Raw -LiteralPath (Join-Path ([IO.Path]::GetDirectoryName($validationPath)) 'release-manifest.json') | ConvertFrom-Json
if ($localManifest.run_id -cne $plan.run_id -or $localManifest.files.Count -ne 8) { throw 'Local manifest identity mismatch.' }
$selectRetention = Join-Path $PSScriptRoot 'select-operational-release-retention.ps1'

function Get-Releases {
    $lines = @(gh api "repos/$Repository/releases" --paginate --jq '.[]')
    if ($LASTEXITCODE -ne 0) { throw 'Could not read releases; no mutation permitted.' }
    foreach ($line in $lines) { $line | ConvertFrom-Json }
}

function Assert-Assets {
    param([object]$Release, [switch]$Existing)
    if ($Release.assets.Count -ne 10 -or @(Compare-Object $expectedNames @($Release.assets.name) -CaseSensitive).Count -ne 0) {
        throw 'Release inventory mismatch.'
    }
    foreach ($name in $expectedNames) {
        $assets = @($Release.assets | Where-Object name -CEQ $name)
        if ($assets.Count -ne 1) { throw 'Duplicate release asset.' }
        if (-not $Existing -or $name.EndsWith('.csv', [StringComparison]::Ordinal)) {
            if ($assets[0].size -ne $localAssets[$name].size -or $assets[0].digest -cne $localAssets[$name].digest) {
                throw "Release asset integrity mismatch: $name"
            }
        }
    }
    if ($Existing) {
        $cache = Join-Path ([IO.Path]::GetTempPath()) "northstar-existing-$([guid]::NewGuid())"
        try {
            $asset = @($Release.assets | Where-Object name -CEQ 'operations-data-validation.zip')[0]
            if ($asset.size -gt 1MB) { throw 'Existing validation bundle is unexpectedly large.' }
            gh release download $Release.tag_name --repo $Repository --pattern operations-data-validation.zip --dir $cache | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Could not verify the existing published bundle.' }
            $zipPath = Join-Path $cache 'operations-data-validation.zip'
            if ((Get-FileHash -LiteralPath $zipPath).Hash.ToLowerInvariant() -cne ($asset.digest -replace '^sha256:', '')) {
                throw 'Existing validation bundle digest mismatch.'
            }
            $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
            try {
                $entries = @($archive.Entries | Where-Object FullName -CEQ 'validation/release-manifest.json')
                $validationNames = @('validation/_SUCCESS.json', 'validation/release-manifest.json', 'validation/SHA256SUMS.txt')
                if ($archive.Entries.Count -ne 3 -or $entries.Count -ne 1 -or $entries[0].Length -gt 1MB -or
                    @(Compare-Object $validationNames @($archive.Entries.FullName) -CaseSensitive).Count -ne 0) {
                    throw 'Existing validation archive contents mismatch.'
                }
                $stream = $entries[0].Open()
                $reader = [IO.StreamReader]::new($stream, [Text.UTF8Encoding]::new($false, $true))
                try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
                finally { $reader.Dispose(); $stream.Dispose() }
            } finally { $archive.Dispose() }
            $dataAsset = @($Release.assets | Where-Object name -CEQ 'operations-data.zip')[0]
            if ($manifest.run_id -cne $plan.run_id -or $manifest.files.Count -ne 8 -or
                $dataAsset.size -ne $manifest.data_archive.bytes -or $dataAsset.digest -cne ('sha256:' + $manifest.data_archive.sha256)) {
                throw 'Existing published snapshot bundle mismatch.'
            }
            foreach ($name in $expectedNames | Where-Object { $_.EndsWith('.csv', [StringComparison]::Ordinal) }) {
                $entries = @($manifest.files | Where-Object name -CEQ $name)
                $localEntries = @($localManifest.files | Where-Object name -CEQ $name)
                if ($entries.Count -ne 1 -or $entries[0].bytes -ne $localAssets[$name].size -or
                    ('sha256:' + $entries[0].sha256) -cne $localAssets[$name].digest -or $entries[0].archive_path -cne "operations-data/$name" -or
                    $localEntries.Count -ne 1 -or $entries[0].rows -ne $localEntries[0].rows -or $entries[0].table -cne $localEntries[0].table) {
                    throw 'Existing manifest CSV mismatch.'
                }
            }
        } finally { if (Test-Path -LiteralPath $cache) { [IO.Directory]::Delete($cache, $true) } }
    }
}

$releases = @(Get-Releases)
$null = & $selectRetention -Releases $releases -ProtectedTags $ProtectedTags -KeepSnapshots $KeepSnapshots
$matches = @($releases | Where-Object tag_name -CEQ $plan.tag)
if ($matches.Count -gt 1) { throw 'Duplicate release tag.' }
if ($matches.Count -eq 1) {
    if (-not $Publish -or $matches[0].draft -or $matches[0].prerelease) {
        throw 'Release or incomplete draft already exists; refusing replacement or automatic repair.'
    }
    Assert-Assets -Release $matches[0] -Existing
    $status = 'AlreadyPublished'
    $release = $matches[0]
} else {
    $refs = @(gh api "repos/$Repository/git/matching-refs/tags/$($plan.tag)" | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Could not verify tag availability.' }
    if (@($refs | Where-Object { $_.ref -ceq "refs/tags/$($plan.tag)" }).Count -ne 0) { throw 'Git tag already exists.' }
    if (-not $Apply) {
        [pscustomobject]@{ status = 'Preview'; tag = $plan.tag; publish = [bool]$Publish; delete = @(); url = $null }
        return
    }
    gh release create $plan.tag @($plan.files) --repo $Repository --target $Commit --title $plan.title --notes-file $plan.notes --draft --latest=false | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Draft creation failed; no publication or cleanup is permitted.' }
    $matches = @(Get-Releases | Where-Object tag_name -CEQ $plan.tag)
    if ($matches.Count -ne 1 -or -not $matches[0].draft) { throw 'New draft read-back failed.' }
    $release = $matches[0]
    Assert-Assets -Release $release
    $status = 'DraftCreated'
    if ($Publish) {
        $body = $release.body.Replace('Manual draft of the Northstar operational data snapshot', 'Northstar operational data snapshot').Replace(' Download links become available when this draft is published; draft reviewers can use the asset list.', '').Replace('before preparing this draft', 'before preparing this release')
        @{ draft = $false; make_latest = 'false'; body = $body } | ConvertTo-Json -Compress |
            gh api --method PATCH "repos/$Repository/releases/$($release.id)" --input - --silent
        if ($LASTEXITCODE -ne 0) { throw 'Publication failed; no cleanup is permitted.' }
        $release = gh api "repos/$Repository/releases/$($release.id)" | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or $release.draft -or $release.tag_name -cne $plan.tag) { throw 'Publication read-back failed.' }
        Assert-Assets -Release $release
        $status = 'Published'
    }
}

$deleted = @()
if ($Publish) {
    $selection = & $selectRetention -Releases @(Get-Releases) -ProtectedTags $ProtectedTags -KeepSnapshots $KeepSnapshots
    if (@($selection.delete | Where-Object tag_name -CEQ $plan.tag).Count -ne 0) {
        throw 'Processed snapshot is outside the rolling window; protect it before cleanup.'
    }
    if ($selection.delete.Count -gt 10) { throw 'Retention backlog exceeds ten releases; review required before cleanup.' }
    if (-not $Apply) { $deleted = @($selection.delete | ForEach-Object { $_.tag_name }) }
    if ($Apply) {
        foreach ($candidate in $selection.delete) {
            $current = gh api "repos/$Repository/releases/$($candidate.id)" | ConvertFrom-Json
            if ($LASTEXITCODE -ne 0 -or $current.draft -or $current.prerelease -or
                $current.tag_name -cne $candidate.tag_name -or $ProtectedTags -ccontains $current.tag_name -or $current.tag_name -ceq $plan.tag) {
                throw 'Retention target changed; refusing deletion.'
            }
            gh api --method DELETE "repos/$Repository/releases/$($candidate.id)" --silent
            if ($LASTEXITCODE -ne 0) { throw 'Operational release cleanup failed.' }
            $deleted += $candidate.tag_name
        }
        $remaining = @(Get-Releases)
        if (@($remaining | Where-Object { $deleted -ccontains $_.tag_name }).Count -ne 0) { throw 'Cleanup read-back failed.' }
    }
}
[pscustomobject]@{ status = $status; tag = $plan.tag; delete = $deleted; url = $release.html_url }