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
. (Ws 'Get-WordStats.ps1')

$counts = Get-TokenCounts (Ws 'data\sample.txt') (Ws 'data\stopwords.txt')

# -Top slices the ordered table but shares stay relative to the whole corpus.
$top3 = Format-CountReport $counts 3
Ok ($top3 -is [object[]]) 'a sliced report is object[]'
Eq 3 (@($top3).Count) 'top three length'
Eq '[dog, fox, quick]' (Show (@($top3 | ForEach-Object { $_.Token }))) 'top three tokens'
Eq 0.2 $top3[0].Share 'shares are relative to the whole corpus, not the slice'

# -Top 1 still returns a list.
$top1 = Format-CountReport $counts 1
Ok ($top1 -is [object[]]) 'a one-row report is still object[]'
Eq 1 (@($top1).Count) 'one-row length'
Eq 'dog' $top1[0].Token 'one-row token'

# -Top 0 returns an empty list.
$top0 = Format-CountReport $counts 0
Ok ($null -ne $top0) 'a zero-row report must not be $null'
Ok ($top0 -is [object[]]) 'a zero-row report is object[]'
Eq 0 (@($top0).Count) 'zero-row length'

# -Top larger than the table returns everything.
$big = Format-CountReport $counts 99
Eq 10 (@($big).Count) 'asking for more rows than exist returns them all'

# A negative -Top is rejected by the parameter itself.
Ok ($null -ne (Throws { Format-CountReport $counts -1 })) 'a negative -Top is rejected'

# An empty corpus.
$emptyFile = Work 'empty.txt'
WriteText $emptyFile ''
$none = Get-TokenCounts $emptyFile
Ok ($none -is [hashtable]) 'an empty corpus still gives a hashtable'
Eq 0 $none.Count 'an empty corpus has no tokens'
$emptyReport = Format-CountReport $none
Ok ($emptyReport -is [object[]]) 'an empty corpus report is object[]'
Eq 0 (@($emptyReport).Count) 'an empty corpus report has no rows'

# A corpus of one token.
$soloFile = Work 'solo.txt'
WriteText $soloFile 'Solo'
$solo = Get-TokenCounts $soloFile
Eq 1 $solo.Count 'one distinct token'
Eq 1 $solo['solo'] 'the token is lower cased'
$soloReport = Format-CountReport $solo
Ok ($soloReport -is [object[]]) 'a one-token report is object[]'
Eq 1 (@($soloReport).Count) 'one-token report length'
Eq 1 $soloReport[0].Share 'a single token owns the whole corpus'

# Separators: apostrophes, underscores and hyphens all split.
$splitFile = Work 'split.txt'
WriteText $splitFile "don't a_b well-known"
$split = Get-TokenCounts $splitFile
Eq 6 $split.Count 'apostrophes, underscores and hyphens are separators'
Eq 1 $split['don'] 'apostrophe splits'
Eq 1 $split['t'] 'a one-letter fragment is a token'
Eq 1 $split['a'] 'underscore splits'
Eq 1 $split['well'] 'hyphen splits'
Eq 1 $split['known'] 'hyphen splits on both sides'

# A stop-word list with comments and blank lines, and mixed case entries.
$stopFile = Work 'stops.txt'
WriteLines $stopFile @('# header', '', 'ALPHA', '  beta  ', '')
$textFile = Work 'text.txt'
WriteText $textFile 'alpha Alpha BETA beta gamma'
$filtered = Get-TokenCounts $textFile $stopFile
Eq 1 $filtered.Count 'stop words are matched case insensitively'
Eq 1 $filtered['gamma'] 'the surviving token'

# Shares round to four decimals.
$thirds = @{ a = 1; b = 1; c = 1 }
$r = Format-CountReport $thirds
Eq '[a, b, c]' (Show (@($r | ForEach-Object { $_.Token }))) 'an all-tie table sorts by token ordinal'
Eq 0.3333 $r[0].Share 'shares round to four decimals'

# Ordinal ordering puts digits before letters on a tie.
$mixed = @{ 'zulu' = 2; '9nine' = 2; 'Alpha' = 2 }
$m = Format-CountReport $mixed
Eq '[9nine, Alpha, zulu]' (Show (@($m | ForEach-Object { $_.Token }))) 'ties break on ordinal, not culture, ordering'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
