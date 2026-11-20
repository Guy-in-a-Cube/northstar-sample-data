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
    if ($plan.files.Count -ne 11) { throw 'Valid fixture did not produce exactly 11 planned assets.' }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $validOutput 'release-manifest.json') | ConvertFrom-Json
    if (@($manifest.files).Count -ne 8 -or @($manifest.files | Where-Object rows -NE 0).Count -ne 0) {
        throw 'Header-only fixture validation failed.'
    }
    foreach ($entry in $manifest.files) {
        if ($entry.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $fixture $entry.name)).Hash.ToLowerInvariant()) {
            throw 'Generated checksum mismatch.'
        }
    }
    Write-Output 'PASS: header-only test fixture produces 11 explicit assets and correct CSV hashes.'

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
    Write-Output 'All tests passed. Fixtures are not Northstar source snapshots; no cloud or GitHub operations were performed.'
} finally {
    [IO.Directory]::Delete($root, $true)
}