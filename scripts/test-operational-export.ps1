#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Server,
    [Parameter(Mandatory)]
    [string]$Database,
    [Parameter(Mandatory)]
    [string]$Directory,
    [Parameter(Mandatory)]
    [guid]$RunId,
    [Parameter(Mandatory)]
    [object[]]$SchemaMetadata
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module SqlServer
$root = [IO.Path]::GetFullPath($Directory)
$markerText = [IO.File]::ReadAllText((Join-Path $root '_SUCCESS.json'))
$document = [Text.Json.JsonDocument]::Parse($markerText)
try { $markerTimestamp = $document.RootElement.GetProperty('completed_at_utc').GetString() }
finally { $document.Dispose() }
$marker = $markerText | ConvertFrom-Json
$tables = @('Booking', 'Channel', 'Experience', 'Guest', 'Property', 'PropertyDailyInventory', 'SatisfactionSurvey', 'StayNight')
if ($marker.contract_version -ne 1 -or $marker.status -cne 'complete' -or $marker.run_id -cne $RunId.ToString() -or
    $markerTimestamp -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$' -or $marker.files.Count -ne 8) {
    throw 'Invalid completion marker.'
}
$expectedFiles = @('_SUCCESS.json') + @($tables | ForEach-Object { "$_.csv" })
$actualFiles = @(Get-ChildItem -LiteralPath $root -File | ForEach-Object { $_.Name })
if (Compare-Object $expectedFiles $actualFiles) { throw 'Run folder does not contain exactly eight CSVs and one marker.' }
$encoding = [Text.UTF8Encoding]::new($false, $true)
$culture = [Globalization.CultureInfo]::InvariantCulture
if (-not ('NorthstarExportCsvValidator' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

public static class NorthstarExportCsvValidator
{
    public static long[] AppendRows(IDataReader reader, IncrementalHash hash, string[] types, int[] scales)
    {
        var encoding = new UTF8Encoding(false, true);
        var culture = CultureInfo.InvariantCulture;
        var counts = new long[5];
        var fields = new string[types.Length];
        var specialCharacters = new[] { ',', '"', '\r', '\n' };
        while (reader.Read())
        {
            for (int ordinal = 0; ordinal < types.Length; ordinal++)
            {
                if (reader.IsDBNull(ordinal))
                {
                    fields[ordinal] = @"\N";
                    counts[1]++;
                    continue;
                }
                object value = reader.GetValue(ordinal);
                string text;
                switch (types[ordinal])
                {
                    case "int":
                    case "bigint":
                        fields[ordinal] = ((IFormattable)value).ToString(null, culture);
                        continue;
                    case "bit":
                        fields[ordinal] = (bool)value ? "1" : "0";
                        continue;
                    case "decimal":
                        fields[ordinal] = ((decimal)value).ToString("F" + scales[ordinal], culture);
                        counts[2]++;
                        continue;
                    case "date": text = ((DateTime)value).ToString("yyyy-MM-dd", culture); break;
                    case "datetime2": text = ((DateTime)value).ToString("yyyy-MM-ddTHH:mm:ss.fff", culture); break;
                    case "uniqueidentifier": text = ((Guid)value).ToString().ToUpperInvariant(); break;
                    case "nvarchar":
                        text = (string)value;
                        if (text == @"\N") throw new InvalidOperationException("Source contains the reserved NULL marker.");
                        if (text.IndexOfAny(specialCharacters) >= 0) counts[3]++;
                        if (text.Length == 0) counts[4]++;
                        break;
                    default: throw new InvalidOperationException("Unsupported source type: " + types[ordinal]);
                }
                fields[ordinal] = "\"" + text.Replace("\"", "\"\"") + "\"";
            }
            hash.AppendData(encoding.GetBytes(string.Join(",", fields) + "\n"));
            counts[0]++;
        }
        return counts;
    }
}
'@
}
$token = az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv
if ($LASTEXITCODE -ne 0) { throw 'Could not acquire SQL access token.' }
$builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source'] = $Server
$builder['Initial Catalog'] = $Database
$builder['Encrypt'] = $true
$builder['TrustServerCertificate'] = $false
$connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$connection.AccessToken = $token
Remove-Variable token
$results = [Collections.Generic.List[object]]::new()
try {
    $connection.Open()
    foreach ($table in $tables) {
        Write-Verbose "Validating ops.$table against the exported CSV."
        $columns = @($SchemaMetadata | Where-Object { $_.table_name -ceq $table } | Sort-Object column_id)
        $keys = @($columns | Where-Object { $_.is_primary_key -eq $true })
        if ($keys.Count -ne 1 -or @($columns | Where-Object { $_.column_name -cnotmatch '^[a-z][a-z0-9_]*$' }).Count) {
            throw "Invalid source metadata for $table."
        }
        $entries = @($marker.files | Where-Object { $_.name -ceq "$table.csv" -and $_.table -ceq "ops.$table" })
        if ($entries.Count -ne 1) { throw "Marker entry mismatch for $table." }
        $entry = $entries[0]
        $path = Join-Path $root "$table.csv"
        if ((Get-Item -LiteralPath $path).Length -ne $entry.bytes) { throw "Marker byte count mismatch for $table." }
        $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT * FROM [ops].[$table] ORDER BY [$($keys[0].column_name)];"
        $command.CommandTimeout = 300
        $reader = $null
        try {
            $reader = $command.ExecuteReader()
            if ($reader.FieldCount -ne $columns.Count) { throw "Column count mismatch for $table." }
            $names = @(for ($ordinal = 0; $ordinal -lt $reader.FieldCount; $ordinal++) {
                $name = $reader.GetName($ordinal)
                if ($name -cne $columns[$ordinal].column_name) { throw "Column order mismatch for $table." }
                $name
            })
            $hash.AppendData($encoding.GetBytes([string]::Join(',', [string[]]$names) + "`n"))
            $counts = [NorthstarExportCsvValidator]::AppendRows($reader, $hash, [string[]]$columns.type_name, [int[]]$columns.scale)
            $rowCount, $nullCount, $decimalCount, $specialTextCount, $emptyTextCount = $counts
            if ($rowCount -ne $entry.rows) { throw "Marker row count mismatch for $table." }
            $expectedHash = [Convert]::ToHexString($hash.GetHashAndReset())
            $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            if ($expectedHash -cne $actualHash) { throw "CSV differs from independently serialized SQL values for $table." }
            $results.Add([pscustomobject]@{
                Table = $table; Rows = $rowCount; Columns = $columns.Count; Bytes = $entry.bytes
                Nulls = $nullCount; Decimals = $decimalCount; SpecialText = $specialTextCount
                EmptyText = $emptyTextCount; SHA256 = $actualHash; Result = 'PASS'
            })
            Write-Verbose "PASS: ops.$table ($rowCount rows; matching source and CSV SHA256)."
        } finally {
            if ($null -ne $reader) { $reader.Dispose() }
            $command.Dispose()
            $hash.Dispose()
        }
    }
} finally { $connection.Dispose() }
$results