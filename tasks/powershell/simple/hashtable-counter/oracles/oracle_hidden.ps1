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

Ok ($counts -is [hashtable]) 'Get-TokenCounts must return a hashtable'
Eq 10 $counts.Count 'distinct token count after stop words'
Eq 4 $counts['dog'] 'dog appears four times'
Eq 4 $counts['fox'] 'fox appears four times, case folded'
Eq 4 $counts['quick'] 'quick appears four times, case folded'
Eq 2 $counts['42'] 'digit runs are tokens'
Eq 1 $counts['7'] 'a one-digit token'
Eq 1 $counts['barks'] 'punctuation does not stick to a token'
Eq 1 $counts['brown'] 'brown appears once'
Eq 1 $counts['jumps'] 'jumps appears once'
Eq 1 $counts['lazy'] 'lazy appears once'
Eq 1 $counts['runs'] 'runs appears once'
Ok (-not $counts.ContainsKey('the')) 'a stop word is dropped'
Ok (-not $counts.ContainsKey('and')) 'a stop word is dropped'
Ok (-not $counts.ContainsKey('over')) 'a stop word is dropped'
Ok (-not $counts.ContainsKey('')) 'no empty token'

$report = Format-CountReport $counts
Ok ($report -is [object[]]) 'Format-CountReport must return object[]'
Eq 10 (@($report).Count) 'the default keeps the top ten'
Eq '[Token, Count, Share]' (Show (@($report[0].PSObject.Properties.Name))) 'property names and order'
Eq '[dog, fox, quick, 42, 7, barks, brown, jumps, lazy, runs]' (Show (@($report | ForEach-Object { $_.Token }))) 'count descending, then token ordinal ascending'
Eq '[4, 4, 4, 2, 1, 1, 1, 1, 1, 1]' (Show (@($report | ForEach-Object { $_.Count }))) 'counts in report order'
Eq 0.2 $report[0].Share 'share of a four-count token'
Eq 0.1 $report[3].Share 'share of a two-count token'
Eq 0.05 $report[4].Share 'share of a one-count token'
Ok ($report[0].Count -is [int]) 'Count is Int32'
Ok ($report[0].Share -is [double]) 'Share is Double'

# Running it twice gives the same order.
$again = Format-CountReport (Get-TokenCounts (Ws 'data\sample.txt') (Ws 'data\stopwords.txt'))
Eq (Show (@($report | ForEach-Object { $_.Token }))) (Show (@($again | ForEach-Object { $_.Token }))) 'the report order is stable across runs'

# Without a stop-word list nothing is dropped.
$all = Get-TokenCounts (Ws 'data\sample.txt')
Eq 13 $all.Count 'distinct token count with no stop words'
Eq 4 $all['the'] 'the appears four times'
Eq 2 $all['and'] 'and appears twice'
Eq 1 $all['over'] 'over appears once'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
