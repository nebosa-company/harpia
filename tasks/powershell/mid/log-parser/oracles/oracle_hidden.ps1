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
. (Ws 'LogTools.ps1')

[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

$log = Ws 'logs\app.log'
$entries = ConvertFrom-AppLog $log

Ok ($entries -is [object[]]) 'ConvertFrom-AppLog must return object[]'
Eq 7 (@($entries).Count) 'seven parsable lines'
Eq '[LineNumber, Timestamp, Level, Component, Message, DurationMs]' (Show (@($entries[0].PSObject.Properties.Name))) 'entry property names and order'
Eq '[1, 2, 4, 5, 7, 8, 10]' (Show (@($entries | ForEach-Object { $_.LineNumber }))) 'line numbers refer to the source file'
Eq '[ERROR, INFO, WARN, INFO, ERROR, INFO, TRACE]' (Show (@($entries | ForEach-Object { $_.Level }))) 'levels in file order'
Eq '[billing, billing, search, search, search, billing, auth]' (Show (@($entries | ForEach-Object { $_.Component }))) 'components in file order'
Eq '[412, <null>, 1800, 200, <null>, 88, <null>]' (Show (@($entries | ForEach-Object { $_.DurationMs }))) 'durations, absent where not logged'
Eq 'charge failed' $entries[0].Message 'the duration suffix is stripped from the message'
Eq 'retry scheduled' $entries[1].Message 'a message with no duration is intact'
Eq 'index unavailable' $entries[4].Message 'a later message with no duration'

Ok ($entries[0].Timestamp -is [datetime]) 'Timestamp is a DateTime'
Eq 'Utc' $entries[0].Timestamp.Kind.ToString() 'timestamps are UTC'
Eq ([datetime]::new(2026, 3, 5, 8, 14, 22, [System.DateTimeKind]::Utc)) $entries[0].Timestamp 'the first timestamp'
Eq ([datetime]::new(2026, 3, 5, 8, 17, 10, [System.DateTimeKind]::Utc)) $entries[6].Timestamp 'the last timestamp'
Ok ($entries[0].LineNumber -is [int]) 'LineNumber is Int32'
Ok ($entries[0].DurationMs -is [int]) 'a present duration is Int32'

# --- Summary ------------------------------------------------------------
$summary = Get-LogSummary $entries
Ok ($summary -is [object[]]) 'Get-LogSummary must return object[]'
Eq 3 (@($summary).Count) 'three components'
Eq '[Component, Total, Errors, Warnings, MaxDurationMs, AvgDurationMs]' (Show (@($summary[0].PSObject.Properties.Name))) 'summary property names and order'
Eq '[billing, search, auth]' (Show (@($summary | ForEach-Object { $_.Component }))) 'busiest first, ties by component name'
Eq '[3, 3, 1]' (Show (@($summary | ForEach-Object { $_.Total }))) 'per-component totals'
Eq '[1, 1, 0]' (Show (@($summary | ForEach-Object { $_.Errors }))) 'per-component error counts'
Eq '[0, 1, 0]' (Show (@($summary | ForEach-Object { $_.Warnings }))) 'per-component warning counts'
Eq '[412, 1800, <null>]' (Show (@($summary | ForEach-Object { $_.MaxDurationMs }))) 'per-component slowest event'
Eq '[250, 1000, <null>]' (Show (@($summary | ForEach-Object { $_.AvgDurationMs }))) 'per-component average duration'
Ok ($summary[0].Total -is [int]) 'Total is Int32'
Ok ($summary[0].MaxDurationMs -is [int]) 'MaxDurationMs is Int32'
Ok ($summary[0].AvgDurationMs -is [double]) 'AvgDurationMs is Double'

# --- Parse statistics ---------------------------------------------------
$stats = Get-LogParseStats $log
Eq '[Lines, Parsed, Skipped]' (Show (@($stats.PSObject.Properties.Name))) 'stat property names and order'
Eq 10 $stats.Lines 'total lines in the file'
Eq 7 $stats.Parsed 'parsed lines'
Eq 3 $stats.Skipped 'skipped lines'
Ok ($stats.Lines -is [int]) 'Lines is Int32'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
