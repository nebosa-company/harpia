$ErrorActionPreference = 'Stop'
$INV = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = $INV
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $INV

$fails = [System.Collections.Generic.List[string]]::new()
function Fail([string]$m) { $fails.Add($m) }
function Show($v) {
    $c = [System.Globalization.CultureInfo]::InvariantCulture
    if ($null -eq $v) { return '<null>' }
    if ($v -is [string]) { return $v }
    if ($v -is [bool]) { if ($v) { return 'True' } else { return 'False' } }
    if ($v -is [double] -or $v -is [single] -or $v -is [decimal]) { return ([double]$v).ToString('G15', $c) }
    if ($v -is [datetime]) { return $v.ToString('yyyy-MM-ddTHH:mm:ss.fffffff', $c) + '|' + $v.Kind }
    if ($v -is [System.Collections.IDictionary]) {
        $parts = @()
        foreach ($k in @($v.Keys | Sort-Object -CaseSensitive)) { $parts += ("{0}={1}" -f $k, (Show $v[$k])) }
        return '{' + ($parts -join '; ') + '}'
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $parts = @()
        foreach ($e in $v) { $parts += (Show $e) }
        return '[' + ($parts -join ', ') + ']'
    }
    return [string]$v
}
function Eq($expected, $actual, [string]$label) {
    $e = Show $expected
    $a = Show $actual
    if ($e -cne $a) { Fail ("{0}: expected <{1}> but got <{2}>" -f $label, $e, $a) }
}
function Ok([bool]$cond, [string]$label) { if (-not $cond) { Fail $label } }
function Done {
    if ($fails.Count -gt 0) {
        foreach ($f in $fails) { Write-Host "FAIL $f" }
        Write-Error ("{0} assertion(s) failed" -f $fails.Count) -ErrorAction Continue
        exit 1
    }
    Write-Host 'PASS'
    exit 0
}
function WorkRoot {
    $dir = Join-Path $PSScriptRoot '.oracle-work'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}
function Work([string]$name) { return (Join-Path (WorkRoot) $name) }
function FreshDir([string]$path) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}
function WriteText([string]$path, [string]$text) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}
function WriteLines([string]$path, [string[]]$lines) { WriteText $path (($lines -join "`n") + "`n") }
function ReadText([string]$path) { return [System.IO.File]::ReadAllText($path) }
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Throws([scriptblock]$sb) {
    try { & $sb | Out-Null; return $null } catch { return $_ }
}
function Ws([string]$rel) { return (Join-Path $PSScriptRoot $rel) }

try {
. (Ws 'MeasurementTools.ps1')

$csv = Ws 'data\readings.csv'

# --- Import-ReadingFile -------------------------------------------------
$rows = @(Import-ReadingFile $csv)
Eq 3 $rows.Count 'three readings in the export'
Eq '[Sensor, Kelvin]' (Show (@($rows[0].PSObject.Properties.Name))) 'reading property names and order'
Eq 'bay-1' $rows[0].Sensor 'first sensor'
Eq 300.15 $rows[0].Kelvin 'first kelvin value'
Ok ($rows[0].Kelvin -is [double]) 'Kelvin is Double'

# --- Format-Reading shape ----------------------------------------------
$cmd = Get-Command Format-Reading
Ok ($cmd.CmdletBinding) 'Format-Reading is an advanced function'
Eq 'Celsius' $cmd.DefaultParameterSet 'the default parameter set'
Eq '[Celsius, Fahrenheit]' (Show (@($cmd.ParameterSets | ForEach-Object { $_.Name } | Sort-Object))) 'parameter set names'

$kelvinAttrs = @($cmd.Parameters['Kelvin'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
Ok (@($kelvinAttrs | Where-Object { $_.ValueFromPipeline }).Count -gt 0) 'Kelvin takes pipeline input'
Ok (@($kelvinAttrs | Where-Object { $_.ValueFromPipelineByPropertyName }).Count -gt 0) 'Kelvin binds by property name'
Ok (@($kelvinAttrs | Where-Object { $_.Mandatory }).Count -gt 0) 'Kelvin is mandatory'

$sensorAttrs = @($cmd.Parameters['Sensor'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
Ok (@($sensorAttrs | Where-Object { $_.ValueFromPipelineByPropertyName }).Count -gt 0) 'Sensor binds by property name'

$mcmd = Get-Command Measure-Reading
Ok ($mcmd.CmdletBinding) 'Measure-Reading is an advanced function'
$readingAttrs = @($mcmd.Parameters['Reading'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
Ok (@($readingAttrs | Where-Object { $_.ValueFromPipeline }).Count -gt 0) 'Reading takes pipeline input'

# --- Format-Reading behaviour ------------------------------------------
$c = Format-Reading -Kelvin 300.15
Eq '[Sensor, Kelvin, Scale, Value, Text]' (Show (@($c.PSObject.Properties.Name))) 'output property names and order'
Eq 'unknown' $c.Sensor 'the default sensor name'
Eq 300.15 $c.Kelvin 'the kelvin value is echoed'
Eq 'C' $c.Scale 'celsius is the default scale'
Eq 27 $c.Value 'celsius value'
Ok ($c.Value -is [double]) 'Value is Double'
Eq '27.00 C' $c.Text 'celsius text'

$f = Format-Reading -Kelvin 300.15 -Fahrenheit
Eq 'F' $f.Scale 'fahrenheit scale'
Eq 80.6 $f.Value 'fahrenheit value'
Eq '80.60 F' $f.Text 'fahrenheit text'

$e = Format-Reading -Kelvin 310.00 -Celsius -Decimals 3 -Sensor 'bay-3'
Eq 'bay-3' $e.Sensor 'an explicit sensor name'
Eq 36.85 $e.Value 'three-decimal celsius value'
Eq '36.850 C' $e.Text 'three-decimal text'

# --- The whole pipeline -------------------------------------------------
$converted = @(Import-ReadingFile $csv | Format-Reading -Celsius)
Eq 3 $converted.Count 'every reading is converted, one at a time'
Eq '[bay-1, bay-2, bay-3]' (Show (@($converted | ForEach-Object { $_.Sensor }))) 'sensor names bind by property name'
Eq '[27, 0, 36.85]' (Show (@($converted | ForEach-Object { $_.Value }))) 'converted values'
Eq '[27.00 C, 0.00 C, 36.85 C]' (Show (@($converted | ForEach-Object { $_.Text }))) 'converted text'

$fahrenheit = @(Import-ReadingFile $csv | Format-Reading -Fahrenheit)
Eq '[80.6, 32, 98.33]' (Show (@($fahrenheit | ForEach-Object { $_.Value }))) 'fahrenheit values through the pipeline'

# --- Measure-Reading ----------------------------------------------------
$summary = Import-ReadingFile $csv | Format-Reading -Celsius | Measure-Reading
Eq 1 (@($summary).Count) 'the summariser emits exactly one row'
Eq '[Count, Scale, Min, Max, Mean]' (Show (@($summary.PSObject.Properties.Name))) 'summary property names and order'
Eq 3 $summary.Count 'summary count'
Ok ($summary.Count -is [int]) 'summary Count is Int32'
Eq 'C' $summary.Scale 'summary scale'
Eq 0 $summary.Min 'summary minimum'
Eq 36.85 $summary.Max 'summary maximum'
Eq 21.2833 $summary.Mean 'summary mean, rounded to four decimals'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
