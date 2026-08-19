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

$root = New-Site 'site'
$graphPath = Join-Path $root 'graph.json'

# --- Reading the graph ---------------------------------------------------
$graph = Read-BuildGraph $graphPath
Ok ($graph -is [object[]]) 'Read-BuildGraph must return object[]'
Eq 3 (@($graph).Count) 'three targets'
Eq '[Name, Inputs, Outputs, Command]' (Show (@($graph[0].PSObject.Properties.Name))) 'target property names and order'
Eq '[greet, shout, banner]' (Show (@($graph | ForEach-Object { $_.Name }))) 'targets in declaration order'
Ok ($graph[0].Inputs -is [string[]]) 'Inputs is String[]'
Ok ($graph[0].Outputs -is [string[]]) 'Outputs is String[]'
Eq '[src/hello.txt, src/world.txt]' (Show $graph[0].Inputs) 'the first target inputs'
Eq '[out/greet.txt]' (Show $graph[0].Outputs) 'the first target outputs'
Eq 'concat src/hello.txt src/world.txt > out/greet.txt' $graph[0].Command 'the first target command'

# --- Build order ---------------------------------------------------------
$order = Get-BuildOrder $graph
Ok ($order -is [string[]]) 'Get-BuildOrder must return String[]'
Eq '[greet, shout, banner]' (Show $order) 'dependencies come before their dependents'

# --- First build ---------------------------------------------------------
$first = Invoke-Build $root $graphPath
Ok ($first -is [object[]]) 'Invoke-Build must return object[]'
Eq 3 (@($first).Count) 'one result per target'
Eq '[Name, Status]' (Show (@($first[0].PSObject.Properties.Name))) 'result property names and order'
Eq '[greet, shout, banner]' (Show (@($first | ForEach-Object { $_.Name }))) 'results follow the build order'
Eq '[built, built, built]' (Show (@($first | ForEach-Object { $_.Status }))) 'everything is built the first time'

Eq 'hello world' (ReadText (Join-Path $root 'out\greet.txt')) 'concat produced the greeting'
Eq 'HELLO WORLD' (ReadText (Join-Path $root 'out\shout.txt')) 'upper produced the shout'
Eq '===HELLO WORLD===' (ReadText (Join-Path $root 'out\banner.txt')) 'concat produced the banner'

$cachePath = Join-Path $root '.buildcache.json'
Ok (Test-Path -LiteralPath $cachePath) 'the build wrote a cache'
Ok ($null -ne ((ReadText $cachePath) | ConvertFrom-Json)) 'the cache is valid JSON'

# --- Nothing changed -----------------------------------------------------
$second = Invoke-Build $root $graphPath
Eq '[skipped, skipped, skipped]' (Show (@($second | ForEach-Object { $_.Status }))) 'a second build skips everything'
Eq 'hello world' (ReadText (Join-Path $root 'out\greet.txt')) 'the outputs are untouched'

# --- A source at the root of the chain changes ---------------------------
WriteText (Join-Path $root 'src\hello.txt') 'HI '
$third = Invoke-Build $root $graphPath
Eq '[built, built, built]' (Show (@($third | ForEach-Object { $_.Status }))) 'the whole chain rebuilds'
Eq 'HI world' (ReadText (Join-Path $root 'out\greet.txt')) 'the greeting was rebuilt'
Eq 'HI WORLD' (ReadText (Join-Path $root 'out\shout.txt')) 'the shout was rebuilt'
Eq '===HI WORLD===' (ReadText (Join-Path $root 'out\banner.txt')) 'the banner was rebuilt'

# --- A source only the last target uses changes --------------------------
WriteText (Join-Path $root 'src\border.txt') '***'
$fourth = Invoke-Build $root $graphPath
Eq '[skipped, skipped, built]' (Show (@($fourth | ForEach-Object { $_.Status }))) 'only the affected target rebuilds'
Eq '***HI WORLD***' (ReadText (Join-Path $root 'out\banner.txt')) 'the banner picked up the new border'
Eq 'HI WORLD' (ReadText (Join-Path $root 'out\shout.txt')) 'the untouched output is untouched'

# --- A source is rewritten with the same bytes ---------------------------
WriteText (Join-Path $root 'src\border.txt') '***'
$fifth = Invoke-Build $root $graphPath
Eq '[skipped, skipped, skipped]' (Show (@($fifth | ForEach-Object { $_.Status }))) 'rewriting identical content is not a change'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
