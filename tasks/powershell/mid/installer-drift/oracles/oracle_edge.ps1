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

function Snap([string]$root) {
    $items = @(Get-ChildItem -LiteralPath $root -Recurse -Force | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\')
        if ($_.PSIsContainer) { "D:$rel" } else { "F:$rel=" + (ReadText $_.FullName) }
    })
    return ((@($items) | Sort-Object -CaseSensitive) -join '|')
}

$spec = Ws 'state\desired.json'

Ok ((Get-Command Install-AppState).Parameters.ContainsKey('WhatIf')) 'the installer supports -WhatIf'

# --- -WhatIf plans without touching anything ----------------------------
$dry = FreshDir (Work 'dry')
$before = Snap $dry
$plan = Install-AppState $dry $spec -WhatIf
$after = Snap $dry
Eq $before $after '-WhatIf must not write anything'
Ok ($plan -is [object[]]) '-WhatIf still returns object[]'
Eq '[created, created, none, created]' (Show (@($plan | ForEach-Object { $_.Action }))) '-WhatIf reports what it would do'

# --- Drift after a real install -----------------------------------------
$root = FreshDir (Work 'site2')
$null = Install-AppState $root $spec

# Someone edited a file.
WriteText (Join-Path $root 'conf\app.ini') "[app]`nname=tampered`n"
$state = Test-AppState $root $spec
$ini = @($state | Where-Object { $_.Path -eq 'conf/app.ini' })[0]
Eq 'different' $ini.State 'an edited file reads as different'
Eq $true $ini.InDrift 'an edited file is in drift'
$fix = Install-AppState $root $spec
$fixIni = @($fix | Where-Object { $_.Path -eq 'conf/app.ini' })[0]
Eq 'updated' $fixIni.Action 'an edited file is updated'
Eq "[app]`nname=demo`nport=8080`n" (ReadText (Join-Path $root 'conf\app.ini')) 'the file is back to spec'

# Someone deleted a file.
Remove-Item -LiteralPath (Join-Path $root 'bin\run.cmd') -Force
$state = Test-AppState $root $spec
$cmdState = @($state | Where-Object { $_.Path -eq 'bin/run.cmd' })[0]
Eq 'missing' $cmdState.State 'a deleted file reads as missing'
$fix = Install-AppState $root $spec
$fixCmd = @($fix | Where-Object { $_.Path -eq 'bin/run.cmd' })[0]
Eq 'created' $fixCmd.Action 'a deleted file is created again'

# Someone put back a file that must not be there.
WriteText (Join-Path $root 'conf\legacy.ini') 'old settings'
$state = Test-AppState $root $spec
$legacy = @($state | Where-Object { $_.Path -eq 'conf/legacy.ini' })[0]
Eq 'present' $legacy.State 'a forbidden file reads as present'
Eq $true $legacy.InDrift 'a forbidden file is in drift'
$fix = Install-AppState $root $spec
$fixLegacy = @($fix | Where-Object { $_.Path -eq 'conf/legacy.ini' })[0]
Eq 'removed' $fixLegacy.Action 'a forbidden file is removed'
Ok (-not (Test-Path -LiteralPath (Join-Path $root 'conf\legacy.ini'))) 'the forbidden file is gone'

$state = Test-AppState $root $spec
Eq '[ok, ok, ok, ok]' (Show (@($state | ForEach-Object { $_.State }))) 'the site is back in line'

# --- Windows line endings are not drift ---------------------------------
[System.IO.File]::WriteAllText((Join-Path $root 'conf\app.ini'), "[app]`r`nname=demo`r`nport=8080`r`n", [System.Text.UTF8Encoding]::new($false))
$state = Test-AppState $root $spec
$ini = @($state | Where-Object { $_.Path -eq 'conf/app.ini' })[0]
Eq 'ok' $ini.State 'CRLF line endings are not drift'
$noop = Install-AppState $root $spec
Eq '[none, none, none, none]' (Show (@($noop | ForEach-Object { $_.Action }))) 'CRLF does not trigger a rewrite'

# --- A one-entry spec ---------------------------------------------------
$oneSpec = Work 'one.json'
WriteText $oneSpec '{ "files": [ { "path": "only/here.txt", "ensure": "present", "content": "solo\n" } ] }'
$oneRoot = FreshDir (Work 'oneroot')
$oneState = Test-AppState $oneRoot $oneSpec
Ok ($oneState -is [object[]]) 'a one-entry spec still gives object[]'
Eq 1 (@($oneState).Count) 'one-entry state count'
$oneApplied = Install-AppState $oneRoot $oneSpec
Ok ($oneApplied -is [object[]]) 'a one-entry install still gives object[]'
Eq 1 (@($oneApplied).Count) 'one-entry action count'
Eq 'created' $oneApplied[0].Action 'the one entry was created'
Eq "solo`n" (ReadText (Join-Path $oneRoot 'only\here.txt')) 'the one entry content'
$oneReport = Get-AppStateReport $oneRoot $oneSpec
Eq 1 $oneReport.Total 'one-entry report total'
Eq 0 $oneReport.Drifted 'one-entry report drift'

# --- An empty spec ------------------------------------------------------
$noneSpec = Work 'none.json'
WriteText $noneSpec '{ "files": [] }'
$noneRoot = FreshDir (Work 'noneroot')
$noneState = Test-AppState $noneRoot $noneSpec
Ok ($null -ne $noneState) 'an empty spec must not return null'
Ok ($noneState -is [object[]]) 'an empty spec gives object[]'
Eq 0 (@($noneState).Count) 'an empty spec has no entries'
$noneApplied = Install-AppState $noneRoot $noneSpec
Ok ($noneApplied -is [object[]]) 'an empty install gives object[]'
Eq 0 (@($noneApplied).Count) 'an empty install does nothing'
$noneReport = Get-AppStateReport $noneRoot $noneSpec
Eq 0 $noneReport.Total 'an empty report totals zero'
Eq 0 $noneReport.Compliant 'an empty report has nothing compliant'
Eq 0 $noneReport.Drifted 'an empty report has nothing drifted'
Eq 0 (@($noneReport.DriftedPaths).Count) 'an empty report has no drifted paths'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
