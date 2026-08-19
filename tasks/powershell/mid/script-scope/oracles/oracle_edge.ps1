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
. (Ws 'Collector.ps1')

# A fresh collector is empty.
Reset-Collector
$empty = Get-CollectorReport
Ok ($null -ne $empty) 'an empty collector reports an array, not null'
Ok ($empty -is [object[]]) 'an empty collector reports object[]'
Eq 0 (@($empty).Count) 'an empty collector has no groups'
Eq 0 (Get-CollectorTotal) 'an empty collector has a zero total'

# One sample still reports as an array.
Add-Sample 'solo' 4.5
$one = Get-CollectorReport
Ok ($one -is [object[]]) 'a one-group report is object[]'
Eq 1 (@($one).Count) 'one group'
Eq 'solo' $one[0].Name 'the group name'
Eq 1 $one[0].Count 'the group count'
Eq 4.5 $one[0].Sum 'the group sum'
Eq 4.5 $one[0].Mean 'the group mean'
Eq 1 (Get-CollectorTotal) 'one sample counted'

# The reset really resets.
Reset-Collector
$after = Get-CollectorReport
Ok ($after -is [object[]]) 'the report after a reset is object[]'
Eq 0 (@($after).Count) 'the reset cleared every group'
Eq 0 (Get-CollectorTotal) 'the reset cleared the total'

# A second session starts from scratch.
Add-Sample 'fresh' 1
Add-Sample 'fresh' 3
Eq 2 (Get-CollectorTotal) 'the second session counts only its own samples'
$session = Get-CollectorReport
Eq 1 (@($session).Count) 'the second session has only its own group'
Eq 'fresh' $session[0].Name 'no group survived the reset'
Eq 2 $session[0].Count 'no sample survived the reset'
Eq 4 $session[0].Sum 'the second session sum'
Eq 2 $session[0].Mean 'the second session mean'

# Reset again, then import a header-only file.
Reset-Collector
$noRows = Work 'none.csv'
WriteLines $noRows @('Name,Value')
Eq 0 (Import-SampleFile $noRows) 'a header-only file reads no rows'
Eq 0 (Get-CollectorTotal) 'a header-only file adds nothing to the total'
$noGroups = Get-CollectorReport
Eq 0 (@($noGroups).Count) 'a header-only file adds no groups'

# Means round to four decimals.
Reset-Collector
Add-Sample 'thirds' 1
Add-Sample 'thirds' 1
Add-Sample 'thirds' 2
$thirds = Get-CollectorReport
Eq 1.3333 $thirds[0].Mean 'the mean rounds to four decimals'
Eq 3 (Get-CollectorTotal) 'three samples counted'

# Group names are ordered ordinally, not by culture.
Reset-Collector
Add-Sample 'zulu' 1
Add-Sample '9nine' 1
Add-Sample 'Alpha' 1
$ordinal = Get-CollectorReport
Eq '[9nine, Alpha, zulu]' (Show (@($ordinal | ForEach-Object { $_.Name }))) 'ordinal ordering of group names'
Eq 3 (Get-CollectorTotal) 'three differently named samples counted'

# Negative values are ordinary samples.
Reset-Collector
Add-Sample 'signed' -2
Add-Sample 'signed' 4
$signed = Get-CollectorReport
Eq 2 $signed[0].Count 'negative samples are counted'
Eq 2 $signed[0].Sum 'negative samples are summed'
Eq 1 $signed[0].Mean 'negative samples average'
Eq 2 (Get-CollectorTotal) 'the total counts negative samples'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
