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

# Asking for both scales at once is refused.
Ok ($null -ne (Throws { Format-Reading -Kelvin 300 -Celsius -Fahrenheit })) 'both scales at once is refused'

# The precision is validated by the parameter itself.
Ok ($null -ne (Throws { Format-Reading -Kelvin 300 -Decimals 9 })) 'more than six decimals is refused'
Ok ($null -ne (Throws { Format-Reading -Kelvin 300 -Decimals -1 })) 'a negative precision is refused'
Ok ($null -eq (Throws { Format-Reading -Kelvin 300 -Decimals 0 })) 'zero decimals is allowed'
Eq '27 C' (Format-Reading -Kelvin 300.15 -Decimals 0).Text 'zero-decimal text'
Eq '26.850000 C' (Format-Reading -Kelvin 300 -Decimals 6).Text 'six-decimal text'

# Bare numbers may be piped straight in.
$plain = @(300.15, 273.15 | Format-Reading -Celsius)
Eq 2 $plain.Count 'bare numbers pipe in one at a time'
Eq '[unknown, unknown]' (Show (@($plain | ForEach-Object { $_.Sensor }))) 'bare numbers get the default sensor'
Eq '[27, 0]' (Show (@($plain | ForEach-Object { $_.Value }))) 'bare number conversion'

# One piped reading still produces one row.
$single = @([pscustomobject]@{ Sensor = 'solo'; Kelvin = 273.15 } | Format-Reading -Celsius)
Eq 1 $single.Count 'a single piped reading gives one row'
Eq 'solo' $single[0].Sensor 'a single piped sensor name'
Eq 0 $single[0].Value 'a single piped value'

# Sub-zero readings.
$cold = Format-Reading -Kelvin 200 -Celsius
Eq -73.15 $cold.Value 'a sub-zero celsius value'
Eq '-73.15 C' $cold.Text 'a sub-zero celsius text'
$coldF = Format-Reading -Kelvin 200 -Fahrenheit
Eq -99.67 $coldF.Value 'a sub-zero fahrenheit value'

# An empty pipeline converts nothing.
$nothing = @(@() | Format-Reading -Celsius)
Eq 0 $nothing.Count 'an empty pipeline converts nothing'

# The summariser always produces exactly one row.
$emptySummary = @() | Measure-Reading
Eq 1 (@($emptySummary).Count) 'the summariser emits one row for an empty pipeline'
Eq 0 $emptySummary.Count 'an empty summary counts zero'
Ok ($emptySummary.Count -is [int]) 'an empty summary Count is Int32'
Eq $null $emptySummary.Min 'an empty summary has no minimum'
Eq $null $emptySummary.Max 'an empty summary has no maximum'
Eq $null $emptySummary.Mean 'an empty summary has no mean'
Eq $null $emptySummary.Scale 'an empty summary has no scale'

$oneSummary = Format-Reading -Kelvin 300.15 -Celsius | Measure-Reading
Eq 1 (@($oneSummary).Count) 'the summariser emits one row for a single reading'
Eq 1 $oneSummary.Count 'a one-reading summary counts one'
Eq 27 $oneSummary.Min 'a one-reading minimum'
Eq 27 $oneSummary.Max 'a one-reading maximum'
Eq 27 $oneSummary.Mean 'a one-reading mean'
Eq 'C' $oneSummary.Scale 'a one-reading scale'

# Mixed scales are reported as such.
$mixedInput = @(
    (Format-Reading -Kelvin 300.15 -Celsius),
    (Format-Reading -Kelvin 300.15 -Fahrenheit)
)
$mixed = $mixedInput | Measure-Reading
Eq 2 $mixed.Count 'a mixed summary counts both'
Eq 'mixed' $mixed.Scale 'a mixed summary says so'
Eq 27 $mixed.Min 'a mixed summary minimum'
Eq 80.6 $mixed.Max 'a mixed summary maximum'
Eq 53.8 $mixed.Mean 'a mixed summary mean'

# The summariser also takes its input as an argument.
$byArg = Measure-Reading -Reading $mixedInput
Eq 2 $byArg.Count 'the summariser accepts an argument as well as a pipeline'
Eq 'mixed' $byArg.Scale 'the argument form reports the same scale'

# Importing a one-row export.
$oneRow = Work 'one.csv'
WriteLines $oneRow @('Sensor,Kelvin', 'solo,290.15')
$imported = @(Import-ReadingFile $oneRow)
Eq 1 $imported.Count 'a one-row export imports one reading'
Eq 290.15 $imported[0].Kelvin 'a one-row kelvin value'

# Importing a header-only export.
$noRow = Work 'none.csv'
WriteLines $noRow @('Sensor,Kelvin')
Eq 0 (@(Import-ReadingFile $noRow)).Count 'a header-only export imports nothing'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
