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
. (Ws 'Install-AppState.ps1')

$spec = Ws 'state\desired.json'
$root = FreshDir (Work 'site1')

# --- Nothing installed yet ---------------------------------------------
$state = Test-AppState $root $spec
Ok ($state -is [object[]]) 'Test-AppState must return object[]'
Eq 4 (@($state).Count) 'one record per spec entry'
Eq '[Path, Ensure, State, InDrift]' (Show (@($state[0].PSObject.Properties.Name))) 'state property names and order'
Eq '[bin/run.cmd, conf/app.ini, conf/legacy.ini, logs/.keep]' (Show (@($state | ForEach-Object { $_.Path }))) 'entries ordered by path'
Eq '[missing, missing, ok, missing]' (Show (@($state | ForEach-Object { $_.State }))) 'states on an empty root'
Eq '[True, True, False, True]' (Show (@($state | ForEach-Object { $_.InDrift }))) 'drift flags on an empty root'
Ok ($state[0].InDrift -is [bool]) 'InDrift is a Boolean'

$report = Get-AppStateReport $root $spec
Eq '[Total, Compliant, Drifted, DriftedPaths]' (Show (@($report.PSObject.Properties.Name))) 'report property names and order'
Eq 4 $report.Total 'report total'
Eq 1 $report.Compliant 'report compliant count'
Eq 3 $report.Drifted 'report drifted count'
Ok ($report.DriftedPaths -is [string[]]) 'DriftedPaths is String[]'
Eq '[bin/run.cmd, conf/app.ini, logs/.keep]' (Show $report.DriftedPaths) 'the drifted paths'

# --- First install ------------------------------------------------------
$applied = Install-AppState $root $spec
Ok ($applied -is [object[]]) 'Install-AppState must return object[]'
Eq 4 (@($applied).Count) 'one action per spec entry'
Eq '[Path, Action]' (Show (@($applied[0].PSObject.Properties.Name))) 'action property names and order'
Eq '[bin/run.cmd, conf/app.ini, conf/legacy.ini, logs/.keep]' (Show (@($applied | ForEach-Object { $_.Path }))) 'actions ordered by path'
Eq '[created, created, none, created]' (Show (@($applied | ForEach-Object { $_.Action }))) 'first install actions'

$ini = Join-Path $root 'conf\app.ini'
Ok (Test-Path -LiteralPath $ini) 'the config file was created'
Eq "[app]`nname=demo`nport=8080`n" (ReadText $ini) 'the config file holds exactly the spec content'
Ok (-not (ReadText $ini).Contains("`r")) 'the config file uses LF line endings'
$bytes = [System.IO.File]::ReadAllBytes($ini)
Ok (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'the config file has no byte-order mark'

$cmd = Join-Path $root 'bin\run.cmd'
Ok (Test-Path -LiteralPath $cmd) 'the launcher was created in a new directory'
Eq "@echo off`necho running`n" (ReadText $cmd) 'the launcher content'

$keep = Join-Path $root 'logs\.keep'
Ok (Test-Path -LiteralPath $keep) 'the empty marker file was created'
Eq '' (ReadText $keep) 'the marker file is empty'

Ok (-not (Test-Path -LiteralPath (Join-Path $root 'conf\legacy.ini'))) 'the absent entry was not created'

# --- Second install is a no-op -----------------------------------------
$again = Install-AppState $root $spec
Eq '[none, none, none, none]' (Show (@($again | ForEach-Object { $_.Action }))) 'a second install changes nothing'

$state = Test-AppState $root $spec
Eq '[ok, ok, ok, ok]' (Show (@($state | ForEach-Object { $_.State }))) 'everything is compliant after installing'
Eq '[False, False, False, False]' (Show (@($state | ForEach-Object { $_.InDrift }))) 'nothing is in drift'

$report = Get-AppStateReport $root $spec
Eq 4 $report.Compliant 'every entry is compliant'
Eq 0 $report.Drifted 'nothing drifted'
Ok ($report.DriftedPaths -is [string[]]) 'DriftedPaths is still String[] when empty'
Eq 0 (@($report.DriftedPaths).Count) 'no drifted paths'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
