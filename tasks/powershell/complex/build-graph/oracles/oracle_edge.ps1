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
. (Ws 'MiniBuild.ps1')

function New-Site([string]$name) {
    $root = FreshDir (Work $name)
    WriteText (Join-Path $root 'src\hello.txt') 'hello '
    WriteText (Join-Path $root 'src\world.txt') 'world'
    WriteText (Join-Path $root 'src\border.txt') '==='
    Copy-Item -LiteralPath (Ws 'build\graph.json') -Destination (Join-Path $root 'graph.json') -Force
    return $root
}

# --- -Force ignores the cache -------------------------------------------
$root = New-Site 'force'
$graphPath = Join-Path $root 'graph.json'
$null = Invoke-Build $root $graphPath
$forced = Invoke-Build $root $graphPath -Force
Eq '[built, built, built]' (Show (@($forced | ForEach-Object { $_.Status }))) '-Force rebuilds everything'
Eq '===HELLO WORLD===' (ReadText (Join-Path $root 'out\banner.txt')) '-Force produces the same output'
$after = Invoke-Build $root $graphPath
Eq '[skipped, skipped, skipped]' (Show (@($after | ForEach-Object { $_.Status }))) 'the cache is still good after a forced build'

# --- Building one target builds only its subgraph -----------------------
$root = New-Site 'subgraph'
$graphPath = Join-Path $root 'graph.json'
$partial = Invoke-Build $root $graphPath 'shout'
Eq '[greet, shout]' (Show (@($partial | ForEach-Object { $_.Name }))) 'only the target and its dependencies run'
Eq '[built, built]' (Show (@($partial | ForEach-Object { $_.Status }))) 'the subgraph was built'
Ok (Test-Path -LiteralPath (Join-Path $root 'out\shout.txt')) 'the requested output exists'
Ok (-not (Test-Path -LiteralPath (Join-Path $root 'out\banner.txt'))) 'the unrelated output was not produced'

$graph = Read-BuildGraph $graphPath
Eq '[greet]' (Show (Get-BuildOrder $graph 'greet')) 'a leaf target orders alone'
Eq '[greet, shout, banner]' (Show (Get-BuildOrder $graph 'banner')) 'the last target pulls in everything'

# --- A deleted output forces just that target ---------------------------
$root = New-Site 'deleted'
$graphPath = Join-Path $root 'graph.json'
$null = Invoke-Build $root $graphPath
Remove-Item -LiteralPath (Join-Path $root 'out\shout.txt') -Force
$repaired = Invoke-Build $root $graphPath
Eq '[skipped, built, skipped]' (Show (@($repaired | ForEach-Object { $_.Status }))) 'a missing output rebuilds only its target'
Eq 'HELLO WORLD' (ReadText (Join-Path $root 'out\shout.txt')) 'the missing output came back'

# --- A missing source fails the target and everything downstream --------
$root = New-Site 'broken'
$graphPath = Join-Path $root 'graph.json'
Remove-Item -LiteralPath (Join-Path $root 'src\world.txt') -Force
$broken = Invoke-Build $root $graphPath
Eq '[failed, failed, failed]' (Show (@($broken | ForEach-Object { $_.Status }))) 'a missing source fails the chain'
Ok (-not (Test-Path -LiteralPath (Join-Path $root 'out\greet.txt'))) 'nothing was produced from the broken target'

# The build recovers once the source is back.
WriteText (Join-Path $root 'src\world.txt') 'world'
$recovered = Invoke-Build $root $graphPath
Eq '[built, built, built]' (Show (@($recovered | ForEach-Object { $_.Status }))) 'the build recovers'

# --- Bad graphs ----------------------------------------------------------
$dup = Work 'dup.json'
WriteText $dup '{ "targets": [ { "name": "dup", "inputs": [], "outputs": ["a"], "command": "concat x > a" }, { "name": "dup", "inputs": [], "outputs": ["b"], "command": "concat x > b" } ] }'
$dupError = Throws { Read-BuildGraph $dup }
Ok ($null -ne $dupError) 'a duplicate target name is rejected'
Eq 'Duplicate target: dup' $dupError.Exception.Message 'the duplicate message names the target'

$cycle = Work 'cycle.json'
WriteText $cycle '{ "targets": [ { "name": "a", "inputs": ["out/b.txt"], "outputs": ["out/a.txt"], "command": "upper out/b.txt > out/a.txt" }, { "name": "b", "inputs": ["out/a.txt"], "outputs": ["out/b.txt"], "command": "upper out/a.txt > out/b.txt" } ] }'
$cycleGraph = Read-BuildGraph $cycle
$cycleError = Throws { Get-BuildOrder $cycleGraph }
Ok ($null -ne $cycleError) 'a cycle is rejected'
Eq 'Cycle detected: a, b' $cycleError.Exception.Message 'the cycle message names the targets, sorted'

$unknownError = Throws { Get-BuildOrder $cycleGraph 'nope' }
Ok ($null -ne $unknownError) 'an unknown target is rejected'
Eq 'Unknown target: nope' $unknownError.Exception.Message 'the unknown-target message names it'

# --- An empty graph ------------------------------------------------------
$emptyGraphPath = Work 'empty.json'
WriteText $emptyGraphPath '{ "targets": [] }'
$emptyGraph = Read-BuildGraph $emptyGraphPath
Ok ($null -ne $emptyGraph) 'an empty graph is an array, not null'
Ok ($emptyGraph -is [object[]]) 'an empty graph is object[]'
Eq 0 (@($emptyGraph).Count) 'an empty graph has no targets'
$emptyOrder = Get-BuildOrder $emptyGraph
Ok ($emptyOrder -is [string[]]) 'an empty order is String[]'
Eq 0 (@($emptyOrder).Count) 'an empty order is empty'
$emptyRoot = FreshDir (Work 'emptyroot')
$emptyBuild = Invoke-Build $emptyRoot $emptyGraphPath
Ok ($emptyBuild -is [object[]]) 'an empty build returns object[]'
Eq 0 (@($emptyBuild).Count) 'an empty build does nothing'

# --- Independent targets order by name ----------------------------------
$flat = Work 'flat.json'
WriteText $flat '{ "targets": [ { "name": "zulu", "inputs": ["s.txt"], "outputs": ["z.txt"], "command": "upper s.txt > z.txt" }, { "name": "Alpha", "inputs": ["s.txt"], "outputs": ["A.txt"], "command": "upper s.txt > A.txt" }, { "name": "9nine", "inputs": ["s.txt"], "outputs": ["9.txt"], "command": "upper s.txt > 9.txt" } ] }'
$flatGraph = Read-BuildGraph $flat
Eq '[9nine, Alpha, zulu]' (Show (Get-BuildOrder $flatGraph)) 'independent targets order by name, ordinally'

$flatRoot = FreshDir (Work 'flatroot')
WriteText (Join-Path $flatRoot 's.txt') 'quiet'
$flatBuild = Invoke-Build $flatRoot $flat
Eq '[9nine, Alpha, zulu]' (Show (@($flatBuild | ForEach-Object { $_.Name }))) 'the build follows that order'
Eq 'QUIET' (ReadText (Join-Path $flatRoot 'A.txt')) 'an independent target produced its output'

# --- A one-target graph --------------------------------------------------
$solo = Work 'solo.json'
WriteText $solo '{ "targets": [ { "name": "only", "inputs": ["s.txt"], "outputs": ["o.txt"], "command": "upper s.txt > o.txt" } ] }'
$soloGraph = Read-BuildGraph $solo
Ok ($soloGraph -is [object[]]) 'a one-target graph is object[]'
Eq 1 (@($soloGraph).Count) 'one target'
$soloOrder = Get-BuildOrder $soloGraph
Ok ($soloOrder -is [string[]]) 'a one-target order is String[]'
Eq '[only]' (Show $soloOrder) 'the single target'
$soloRoot = FreshDir (Work 'soloroot')
WriteText (Join-Path $soloRoot 's.txt') 'x'
$soloBuild = Invoke-Build $soloRoot $solo
Ok ($soloBuild -is [object[]]) 'a one-target build is object[]'
Eq '[built]' (Show (@($soloBuild | ForEach-Object { $_.Status }))) 'the single target was built'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
