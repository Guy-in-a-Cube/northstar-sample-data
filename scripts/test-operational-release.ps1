#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$prepare = Join-Path $PSScriptRoot 'prepare-operational-release.ps1'
$root = Join-Path (Join-Path $PSScriptRoot '..') "dist/release-validator-tests-$([guid]::NewGuid())"
$fixture = Join-Path $root 'fixture'
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$encoding = [Text.UTF8Encoding]::new($false, $true)
$sourceText = [IO.File]::ReadAllText((Join-Path $SourceDirectory '_SUCCESS.json'), $encoding)
$document = [Text.Json.JsonDocument]::Parse($sourceText)
try { $timestamp = $document.RootElement.GetProperty('completed_at_utc').GetString() }
finally { $document.Dispose() }
$baseline = $sourceText | ConvertFrom-Json
$baseline.completed_at_utc = $timestamp
$headers = @{}
foreach ($entry in $baseline.files) {
    $reader = [IO.StreamReader]::new((Join-Path $SourceDirectory $entry.name), $encoding)
    try { $headers[$entry.name] = $reader.ReadLine() + "`n" }
    finally { $reader.Dispose() }
    $entry.rows = 0
    $entry.bytes = $encoding.GetByteCount($headers[$entry.name])
}
$baselineJson = $baseline | ConvertTo-Json -Depth 5
$caseNumber = 0

function Reset-Fixture {
    Get-ChildItem -LiteralPath $fixture -File | Remove-Item
    foreach ($entry in $headers.GetEnumerator()) {
        [IO.File]::WriteAllText((Join-Path $fixture $entry.Key), $entry.Value, $encoding)
    }
    [IO.File]::WriteAllText((Join-Path $fixture '_SUCCESS.json'), $baselineJson, $encoding)
}

function Write-Marker {
    param([object]$Value)
    if ($Value.completed_at_utc -is [DateTime]) { $Value.completed_at_utc = $timestamp }
    [IO.File]::WriteAllText((Join-Path $fixture '_SUCCESS.json'), ($Value | ConvertTo-Json -Depth 5), $encoding)
}

function Assert-Rejected {
    param([string]$Name, [scriptblock]$Change, [string]$ExpectedError)
    Reset-Fixture
    & $Change
    $script:caseNumber++
    $output = Join-Path $root "rejected-$script:caseNumber"
    $rejected = $false
    try { & $prepare -Directory $fixture -OutputDirectory $output | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch $ExpectedError) { throw }
        $rejected = $true
    }
    if (-not $rejected -or (Test-Path -LiteralPath $output)) { throw "Invalid fixture accepted: $Name" }
    Write-Output "PASS: rejects $Name without preparing release assets."
}

try {
    Reset-Fixture
    $validOutput = Join-Path $root 'valid'
    $plan = (& $prepare -Directory $fixture -OutputDirectory $validOutput) -join "`n" | ConvertFrom-Json
    if ($plan.files.Count -ne 10) { throw 'Valid fixture did not produce exactly 10 planned assets.' }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $validOutput 'release-manifest.json') | ConvertFrom-Json
    if (@($manifest.files).Count -ne 8 -or @($manifest.files | Where-Object rows -NE 0).Count -ne 0) {
        throw 'Header-only fixture validation failed.'
    }
    foreach ($entry in $manifest.files) {
        if ($entry.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $fixture $entry.name)).Hash.ToLowerInvariant()) {
            throw 'Generated checksum mismatch.'
        }
    }
    $archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $validOutput 'operations-data.zip'))
    try {
        $expectedPaths = @($baseline.files | ForEach-Object { "operations-data/$($_.name)" })
        if ($archive.Entries.Count -ne 8 -or @(Compare-Object $expectedPaths @($archive.Entries.FullName) -CaseSensitive).Count -ne 0) {
            throw 'Data ZIP must contain only eight CSVs in operations-data/.'
        }
        foreach ($entry in $archive.Entries) {
            $entryStream = $entry.Open()
            $hash = [Security.Cryptography.SHA256]::Create()
            try { $actual = [BitConverter]::ToString($hash.ComputeHash($entryStream)).Replace('-', '').ToLowerInvariant() }
            finally { $hash.Dispose(); $entryStream.Dispose() }
            $expected = @($manifest.files | Where-Object { $_.archive_path -ceq $entry.FullName })[0]
            if ($actual -cne $expected.sha256) { throw 'CSV content changed inside data ZIP.' }
        }
    } finally { $archive.Dispose() }
    $archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $validOutput 'operations-data-validation.zip'))
    try {
        $expectedPaths = @('validation/_SUCCESS.json', 'validation/release-manifest.json', 'validation/SHA256SUMS.txt')
        if ($archive.Entries.Count -ne 3 -or @(Compare-Object $expectedPaths @($archive.Entries.FullName) -CaseSensitive).Count -ne 0) {
            throw 'Validation ZIP must contain only the three separate verification files.'
        }
    } finally { $archive.Dispose() }
    if ($manifest.data_archive.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $validOutput 'operations-data.zip')).Hash.ToLowerInvariant()) {
        throw 'Data ZIP checksum mismatch.'
    }
    Write-Output 'PASS: ten assets, data-only operations-data/ ZIP, separate validation bundle, and unchanged CSV hashes.'

    Assert-Rejected 'missing completion marker' {
        Remove-Item -LiteralPath (Join-Path $fixture '_SUCCESS.json')
    } 'exactly eight CSVs'
    Assert-Rejected 'missing CSV' {
        Remove-Item -LiteralPath (Join-Path $fixture 'Property.csv')
    } 'exactly eight CSVs'
    Assert-Rejected 'extra file' {
        [IO.File]::WriteAllText((Join-Path $fixture 'extra.csv'), '', $encoding)
    } 'exactly eight CSVs'
    Assert-Rejected 'incomplete marker' {
        $value = $baselineJson | ConvertFrom-Json
        $value.status = 'failed'
        Write-Marker $value
    } 'incomplete'
    Assert-Rejected 'duplicate inventory' {
        $value = $baselineJson | ConvertFrom-Json
        $value.files[7] = $value.files[0]
        Write-Marker $value
    } 'Invalid inventory entry'
    Assert-Rejected 'unsafe inventory name' {
        $value = $baselineJson | ConvertFrom-Json
        $value.files[0].name = '../../Booking.csv'
        Write-Marker $value
    } 'Invalid inventory entry'
    Assert-Rejected 'incorrect byte size' {
        $value = $baselineJson | ConvertFrom-Json
        $value.files[0].bytes++
        Write-Marker $value
    } 'Byte size mismatch'
    Assert-Rejected 'incorrect parsed row count' {
        $value = $baselineJson | ConvertFrom-Json
        $value.files[0].rows++
        Write-Marker $value
    } 'Row count mismatch'
    Assert-Rejected 'invalid UTF-8' {
        $path = Join-Path $fixture 'Booking.csv'
        $bytes = [IO.File]::ReadAllBytes($path)
        $bytes[0] = 255
        [IO.File]::WriteAllBytes($path, $bytes)
    } 'Unable to translate bytes'

    $multiline = Join-Path $root 'isolated-csv-parser-fixture.csv'
    $text = @'
test_key,test_text
1,"comma, ""quote""
second line"
2,""
3,\N
'@
    [IO.File]::WriteAllText($multiline, $text + "`n", $encoding)
    if ([NorthstarReleaseCsvValidator]::CountRows($multiline, 2, 'test_key') -ne 3) {
        throw 'Embedded newline CSV record-count test failed.'
    }
    Write-Output 'PASS: isolated CSV parser fixture handles embedded newlines, commas, doubled quotes, empty text, and NULL marker.'
    $accepted = $false
    try { & $prepare -Directory $fixture -OutputDirectory $validOutput | Out-Null; $accepted = $true }
    catch { if ($_.Exception.Message -notmatch 'overwrite') { throw } }
    if ($accepted) { throw 'Existing release candidate was overwritten.' }
    Write-Output 'PASS: refuses to overwrite an existing candidate.'
    foreach ($offset in -1, 1) {
        Reset-Fixture
        $value = $baselineJson | ConvertFrom-Json
        $value.completed_at_utc = [DateTimeOffset]::UtcNow.AddDays($offset).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
        Write-Marker $value
        $accepted = $false
        try {
            & $prepare -Directory $fixture -OutputDirectory (Join-Path $root "freshness-$offset") -RequireCurrentDay | Out-Null
            $accepted = $true
        } catch { if ($_.Exception.Message -notmatch 'stale or future') { throw } }
        if ($accepted) { throw 'Scheduled publishing accepted a stale or future export.' }
    }
    Reset-Fixture
    $value = $baselineJson | ConvertFrom-Json
    $value.completed_at_utc = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
    Write-Marker $value
    & $prepare -Directory $fixture -OutputDirectory (Join-Path $root 'freshness-today') -RequireCurrentDay | Out-Null
    Write-Output 'PASS: scheduled publishing accepts current-day completion and rejects stale/future exports.'
    $selectRetention = Join-Path $PSScriptRoot 'select-operational-release-retention.ps1'
    $releaseFixture = @(foreach ($number in 1..10) {
        [pscustomobject]@{
            id = $number
            tag_name = 'operational-202611' + $number.ToString('00') + 'T120000000Z-' + $baseline.run_id
            draft = $false
            prerelease = $false
        }
    })
    $protected = @($releaseFixture[0].tag_name)
    $excluded = @(
        [pscustomobject]@{ id = 11; tag_name = 'budget-v1'; draft = $false; prerelease = $false }
        [pscustomobject]@{ id = 12; tag_name = 'operational-20261111T120000000Z-' + $baseline.run_id; draft = $true; prerelease = $false }
        [pscustomobject]@{ id = 13; tag_name = 'operational-20261112T120000000Z-' + $baseline.run_id; draft = $false; prerelease = $true }
    )
    $selection = & $selectRetention -Releases ($releaseFixture + $excluded) -ProtectedTags $protected
    if ($selection.keep.Count -ne 8 -or $selection.delete.Count -ne 2 -or
        @(Compare-Object @(2, 3) @($selection.delete.id)).Count -ne 0 -or
        $selection.delete.tag_name -ccontains $protected[0]) {
        throw 'Retention must preserve seven unprotected snapshots plus the course baseline.'
    }
    $selection = & $selectRetention -Releases @($releaseFixture[0]) -ProtectedTags $protected
    if ($selection.delete.Count -ne 0) { throw 'Small inventories must not be pruned.' }
    $selection = & $selectRetention -Releases $releaseFixture -ProtectedTags @($releaseFixture.tag_name)
    if ($selection.delete.Count -ne 0) { throw 'Protected releases must never be pruned.' }
    Write-Output 'PASS: retention preserves course baselines and newest seven snapshots; excludes drafts, prereleases, and other datasets.'
    Reset-Fixture
    $publisher = Join-Path $PSScriptRoot 'publish-operational-release.ps1'
    $planPath = Join-Path $root 'publisher-plan.json'
    [IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json -Depth 5), $encoding)
    $assets = @($plan.files | ForEach-Object {
        $file = Get-Item -LiteralPath $_
        [pscustomobject]@{ name = $file.Name; size = $file.Length; digest = 'sha256:' + (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() }
    })
    $published = [pscustomobject]@{
        id = 20; tag_name = $plan.tag; draft = $false; prerelease = $false
        assets = $assets; body = ''; html_url = 'https://example.invalid/release'
    }
    $oldGh = Get-Item Function:gh -ErrorAction SilentlyContinue
    $oldExitCode = Get-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $global:northstarMockReleases = @($releaseFixture[0..8]) + @($published)
    $global:northstarMockCalls = @()
    $global:northstarMockValidationZip = Join-Path $validOutput 'operations-data-validation.zip'
    $global:northstarMockMode = ''
    $global:northstarMockAssetTemplate = $assets | ConvertTo-Json -Depth 5 -Compress
    function global:gh {
        $arguments = @($args)
        $global:northstarMockCalls += ($arguments -join ' ')
        $global:LASTEXITCODE = 0
        if ($arguments[0] -eq 'release' -and $arguments[1] -eq 'create') {
            $created = [pscustomobject]@{
                id = 20; tag_name = $arguments[2]; draft = $true; prerelease = $false
                assets = @($global:northstarMockAssetTemplate | ConvertFrom-Json); body = ''; html_url = 'https://example.invalid/release'
            }
            if ($global:northstarMockMode -ceq 'CorruptDraft') { $created.assets[0].digest = 'sha256:' + ('0' * 64) }
            $global:northstarMockReleases += $created
            'https://example.invalid/release'
            return
        }
        if ($arguments[0] -eq 'release' -and $arguments[1] -eq 'download') {
            $destination = $arguments[[Array]::IndexOf($arguments, '--dir') + 1]
            [IO.Directory]::CreateDirectory($destination) | Out-Null
            Copy-Item -LiteralPath $global:northstarMockValidationZip -Destination (Join-Path $destination 'operations-data-validation.zip')
            return
        }
        $endpoint = @($arguments | Where-Object { $_ -like 'repos/test/repo/*' })[0]
        if ($endpoint -eq 'repos/test/repo/releases') {
            foreach ($release in $global:northstarMockReleases) { $release | ConvertTo-Json -Depth 10 -Compress }
            return
        }
        if ($endpoint -like 'repos/test/repo/git/matching-refs/*') { '[]'; return }
        if ($endpoint -match '^repos/test/repo/releases/([0-9]+)$') {
            $identity = [long]$Matches[1]
            if ($arguments -contains 'PATCH') {
                if ($global:northstarMockMode -ceq 'PublicationFails') { $global:LASTEXITCODE = 1; return }
                @($global:northstarMockReleases | Where-Object id -EQ $identity)[0].draft = $false
                return
            }
            if ($arguments -contains 'DELETE') {
                $global:northstarMockReleases = @($global:northstarMockReleases | Where-Object id -NE $identity)
                return
            }
            @($global:northstarMockReleases | Where-Object id -EQ $identity)[0] | ConvertTo-Json -Depth 10 -Compress
            return
        }
        throw 'Unexpected simulated GitHub command.'
    }
    try {
        $parameters = @{ PlanPath = $planPath; Repository = 'test/repo'; Commit = ('a' * 40); ProtectedTags = $protected; Publish = $true }
        $result = & $publisher @parameters
        if ($result.status -cne 'AlreadyPublished' -or $result.delete.Count -ne 2 -or @($global:northstarMockCalls | Where-Object { $_ -match 'DELETE|PATCH|release create' }).Count -ne 0) {
            throw 'Preview or duplicate handling performed a mutation.'
        }
        $global:northstarMockCalls = @()
        $result = & $publisher @parameters -Apply
        if ($result.status -cne 'AlreadyPublished' -or $result.delete.Count -ne 2 -or
            $global:northstarMockReleases.Count -ne 8 -or
            @($global:northstarMockCalls | Where-Object { $_ -match 'PATCH|release create' }).Count -ne 0) {
            throw 'Duplicate skip must prune to exactly seven rolling snapshots plus baseline without republishing.'
        }
        $published.draft = $true
        $global:northstarMockReleases = @($published)
        $global:northstarMockCalls = @()
        $accepted = $false
        try { & $publisher @parameters -Apply | Out-Null; $accepted = $true }
        catch { if ($_.Exception.Message -notmatch 'incomplete draft') { throw } }
        if ($accepted -or @($global:northstarMockCalls | Where-Object { $_ -match 'DELETE|PATCH|release create' }).Count -ne 0) {
            throw 'Incomplete draft triggered mutation.'
        }
        $published.draft = $false
        $published.assets[0].digest = 'sha256:' + ('0' * 64)
        $global:northstarMockCalls = @()
        $accepted = $false
        try { & $publisher @parameters -Apply | Out-Null; $accepted = $true }
        catch { if ($_.Exception.Message -notmatch 'integrity mismatch') { throw } }
        if ($accepted -or @($global:northstarMockCalls | Where-Object { $_ -match 'DELETE|PATCH|release create' }).Count -ne 0) {
            throw 'Corrupt published snapshot triggered mutation.'
        }
        $global:northstarMockReleases = @()
        $global:northstarMockCalls = @()
        $result = & $publisher @parameters
        if ($result.status -cne 'Preview' -or @($global:northstarMockCalls | Where-Object { $_ -match 'DELETE|PATCH|release create' }).Count -ne 0) {
            throw 'New release preview performed a mutation.'
        }
        $global:northstarMockReleases = @($releaseFixture[0..8])
        $global:northstarMockCalls = @()
        $result = & $publisher @parameters -Apply
        if ($result.status -cne 'Published' -or $result.delete.Count -ne 2 -or
            @($global:northstarMockReleases | Where-Object id -EQ 20)[0].draft -or $global:northstarMockReleases.Count -ne 8) {
            throw 'New release publish-then-prune sequence failed.'
        }
        foreach ($failure in 'CorruptDraft', 'PublicationFails') {
            $global:northstarMockMode = $failure
            $global:northstarMockReleases = @($releaseFixture[0..8])
            $global:northstarMockCalls = @()
            $accepted = $false
            try { & $publisher @parameters -Apply | Out-Null; $accepted = $true }
            catch {
                if ($_.Exception.Message -notmatch 'integrity mismatch|Publication failed') { throw }
            }
            if ($accepted -or @($global:northstarMockCalls | Where-Object { $_ -match 'DELETE' }).Count -ne 0 -or
                -not @($global:northstarMockReleases | Where-Object id -EQ 20)[0].draft) {
                throw 'Upload/publication failure deleted releases or published a partial draft.'
            }
        }
        Write-Output 'PASS: simulated publisher previews safely, verifies duplicates, prunes only eligible releases, and rejects incomplete/corrupt snapshots.'
        Write-Output 'PASS: simulated create/verify/publish/cleanup succeeds; upload or publication failure leaves an unpublished draft and never prunes.'
    } finally {
        if ($oldGh) { Set-Item Function:global:gh -Value $oldGh.ScriptBlock }
        else { Remove-Item Function:global:gh }
        Remove-Variable northstarMockReleases,northstarMockCalls,northstarMockValidationZip,northstarMockMode,northstarMockAssetTemplate -Scope Global
        if ($oldExitCode) { $global:LASTEXITCODE = $oldExitCode.Value }
        else { Remove-Variable LASTEXITCODE -Scope Global }
    }
    Write-Output 'All tests passed. Fixtures are not Northstar source snapshots; no cloud or GitHub operations were performed.'
} finally {
    [IO.Directory]::Delete($root, $true)
}