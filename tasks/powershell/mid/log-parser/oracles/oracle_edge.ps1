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

# An empty log.
$emptyLog = Work 'empty.log'
WriteText $emptyLog ''
$empty = ConvertFrom-AppLog $emptyLog
Ok ($null -ne $empty) 'an empty log must not give null'
Ok ($empty -is [object[]]) 'an empty log gives object[]'
Eq 0 (@($empty).Count) 'an empty log has no entries'
$emptyStats = Get-LogParseStats $emptyLog
Eq 0 $emptyStats.Lines 'an empty log has no lines'
Eq 0 $emptyStats.Parsed 'an empty log parses nothing'
Eq 0 $emptyStats.Skipped 'an empty log skips nothing'
$emptySummary = Get-LogSummary $empty
Ok ($emptySummary -is [object[]]) 'an empty summary is object[]'
Eq 0 (@($emptySummary).Count) 'an empty summary has no rows'

# A one-line log.
$oneLog = Work 'one.log'
WriteLines $oneLog @('2026-04-01T00:00:00Z [INFO] solo - started (dur=0ms)')
$one = ConvertFrom-AppLog $oneLog
Ok ($one -is [object[]]) 'a one-line log gives object[]'
Eq 1 (@($one).Count) 'one entry'
Eq 0 $one[0].DurationMs 'a zero duration is zero, not absent'
Ok ($one[0].DurationMs -is [int]) 'a zero duration is Int32'
Eq 'started' $one[0].Message 'the message with the suffix removed'
$oneSummary = Get-LogSummary $one
Ok ($oneSummary -is [object[]]) 'a one-row summary is object[]'
Eq 1 (@($oneSummary).Count) 'one summary row'
Eq 0 $oneSummary[0].MaxDurationMs 'a zero duration is still the maximum'
Eq 0 $oneSummary[0].AvgDurationMs 'a zero duration averages to zero'

# Junk lines of every kind are skipped, never guessed at.
$junkLog = Work 'junk.log'
WriteLines $junkLog @(
    'not a log line at all',
    '2026-04-01T00:00:00Z [FATAL] svc - unknown level',
    '2026-04-01T00:00:00Z [info] svc - lower case level',
    '2026-04-01T00:00:00Z INFO svc - missing brackets',
    '2026-04-01T00:00:00Z [INFO] svc missing the dash',
    '2026-04-01 00:00:00 [INFO] svc - wrong timestamp shape',
    '2026-04-01T00:00:00Z [INFO] svc - good line'
)
$junk = ConvertFrom-AppLog $junkLog
Eq 1 (@($junk).Count) 'only the good line survives'
Eq 7 $junk[0].LineNumber 'the surviving line keeps its line number'
$junkStats = Get-LogParseStats $junkLog
Eq 7 $junkStats.Lines 'junk lines are still counted as lines'
Eq 1 $junkStats.Parsed 'one line parsed'
Eq 6 $junkStats.Skipped 'six lines skipped'

# A component with no durations at all.
$mixedLog = Work 'mixed.log'
WriteLines $mixedLog @(
    '2026-04-01T00:00:01Z [WARN] alpha - one',
    '2026-04-01T00:00:02Z [WARN] alpha - two',
    '2026-04-01T00:00:03Z [ERROR] beta - three (dur=5ms)',
    '2026-04-01T00:00:04Z [ERROR] beta - four (dur=6ms)',
    '2026-04-01T00:00:05Z [DEBUG] beta - five (dur=10ms)'
)
$mixed = ConvertFrom-AppLog $mixedLog
$mixedSummary = Get-LogSummary $mixed
Eq '[beta, alpha]' (Show (@($mixedSummary | ForEach-Object { $_.Component }))) 'the busier component comes first'
$alpha = @($mixedSummary | Where-Object { $_.Component -eq 'alpha' })[0]
Eq 2 $alpha.Total 'alpha total'
Eq 0 $alpha.Errors 'alpha errors'
Eq 2 $alpha.Warnings 'alpha warnings'
Eq $null $alpha.MaxDurationMs 'no durations means no maximum'
Eq $null $alpha.AvgDurationMs 'no durations means no average'
$beta = @($mixedSummary | Where-Object { $_.Component -eq 'beta' })[0]
Eq 10 $beta.MaxDurationMs 'beta maximum'
Eq 7 $beta.AvgDurationMs 'beta average'
Eq 2 $beta.Errors 'beta errors'
Eq 0 $beta.Warnings 'beta warnings'

# Averages round to two decimals.
$roundLog = Work 'round.log'
WriteLines $roundLog @(
    '2026-04-01T00:00:01Z [INFO] r - a (dur=1ms)',
    '2026-04-01T00:00:02Z [INFO] r - b (dur=1ms)',
    '2026-04-01T00:00:03Z [INFO] r - c (dur=2ms)'
)
$round = ConvertFrom-AppLog $roundLog
$roundSummary = Get-LogSummary $round
Eq 1.33 $roundSummary[0].AvgDurationMs 'the average rounds to two decimals'

# Ties on total break on component name, ordinally.
$tieLog = Work 'tie.log'
WriteLines $tieLog @(
    '2026-04-01T00:00:01Z [INFO] zulu - a',
    '2026-04-01T00:00:02Z [INFO] Alpha - b',
    '2026-04-01T00:00:03Z [INFO] 9nine - c'
)
$tie = ConvertFrom-AppLog $tieLog
$tieSummary = Get-LogSummary $tie
Eq '[9nine, Alpha, zulu]' (Show (@($tieSummary | ForEach-Object { $_.Component }))) 'ties break ordinally on component'

# Summarising an explicitly empty list.
$noneSummary = Get-LogSummary @()
Ok ($noneSummary -is [object[]]) 'summarising nothing gives object[]'
Eq 0 (@($noneSummary).Count) 'summarising nothing gives no rows'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
