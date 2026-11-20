#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]]$Releases,
    [Parameter(Mandatory)]
    [string[]]$ProtectedTags,
    [ValidateRange(1, 365)]
    [int]$KeepSnapshots = 7
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$pattern = '^operational-\d{8}T\d{9}Z-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($tag in $ProtectedTags) {
    if ($tag -cnotmatch $pattern -or -not $seen.Add($tag)) { throw 'Invalid or duplicate protected operational tag.' }
}
$eligible = @($Releases | Where-Object {
    -not $_.draft -and -not $_.prerelease -and $_.tag_name -cmatch $pattern
})
$releaseIds = [Collections.Generic.HashSet[long]]::new()
$releaseTags = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($release in $eligible) {
    if ($release.id -le 0 -or -not $releaseIds.Add([long]$release.id) -or -not $releaseTags.Add($release.tag_name)) {
        throw 'Invalid or duplicate operational release identity.'
    }
}
$rolling = @($eligible | Where-Object { $ProtectedTags -cnotcontains $_.tag_name } | Sort-Object tag_name -Descending)
$delete = @($rolling | Select-Object -Skip $KeepSnapshots)
[pscustomobject]@{
    keep = @($eligible | Where-Object { $ProtectedTags -ccontains $_.tag_name }) + @($rolling | Select-Object -First $KeepSnapshots)
    delete = $delete
}