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
. (Ws 'StateEnforcer.ps1')

function Snap([string]$root) {
    if (-not (Test-Path -LiteralPath $root)) { return '<absent>' }
    $base = (Resolve-Path -LiteralPath $root).ProviderPath
    $items = @(Get-ChildItem -LiteralPath $base -Recurse -Force | ForEach-Object {
        $rel = $_.FullName.Substring($base.Length).TrimStart('\')
        if ($_.PSIsContainer) { "D:$rel" } else { "F:$rel=" + (Norm (ReadText $_.FullName)) }
    })
    return ((@($items) | Sort-Object -CaseSensitive) -join '|')
}

$policy = Ws 'policy\site.json'

Ok ((Get-Command Invoke-StatePlan).Parameters.ContainsKey('WhatIf')) 'the enforcer supports -WhatIf'

# --- -WhatIf plans without touching anything ----------------------------
$dry = FreshDir (Work 'dry')
WriteText (Join-Path $dry 'existing.txt') 'untouched'
$before = Snap $dry
$planned = Invoke-StatePlan $dry $policy -WhatIf
Eq $before (Snap $dry) '-WhatIf must not write anything'
Eq $true $planned.Succeeded '-WhatIf reports success'
Eq $false $planned.RolledBack '-WhatIf rolls nothing back'
Eq '[conf-dir, app-settings, allow-office, banner]' (Show $planned.Applied) '-WhatIf reports what it would apply'
Eq '[deny-loopback, scratch]' (Show $planned.Skipped) '-WhatIf reports what it would skip'

# --- Drift after a real apply -------------------------------------------
$root = FreshDir (Work 'site')
$null = Invoke-StatePlan $root $policy

Remove-Item -LiteralPath (Join-Path $root 'conf\banner.txt') -Force
$drift = Get-StateDrift $root $policy
$banner = @($drift | Where-Object { $_.Id -eq 'banner' })[0]
Eq 'major' $banner.Severity 'a deleted file is major drift'
Eq 'missing' $banner.Detail 'a deleted file reads as missing'

$null = Invoke-StatePlan $root $policy
WriteText (Join-Path $root 'conf\banner.txt') "tampered`n"
$drift = Get-StateDrift $root $policy
$banner = @($drift | Where-Object { $_.Id -eq 'banner' })[0]
Eq 'minor' $banner.Severity 'an edited file is minor drift'
Eq 'content' $banner.Detail 'an edited file reads as content drift'

WriteText (Join-Path $root 'conf\allow.txt') "10.0.0.7`n127.0.0.1`n"
$drift = Get-StateDrift $root $policy
$deny = @($drift | Where-Object { $_.Id -eq 'deny-loopback' })[0]
Eq 'minor' $deny.Severity 'a forbidden line is minor drift'
Eq 'content' $deny.Detail 'a forbidden line reads as content drift'

New-Item -ItemType Directory -Path (Join-Path $root 'tmp\deep') -Force | Out-Null
WriteText (Join-Path $root 'tmp\deep\junk.txt') 'junk'
$drift = Get-StateDrift $root $policy
$scratch = @($drift | Where-Object { $_.Id -eq 'scratch' })[0]
Eq 'major' $scratch.Severity 'a directory that must not exist is major drift'
Eq 'present' $scratch.Detail 'it reads as present'

$fix = Invoke-StatePlan $root $policy
Eq $true $fix.Succeeded 'the repair run succeeded'
Eq '[deny-loopback, banner, scratch]' (Show $fix.Applied) 'only the drifted resources were touched'
Ok (-not (Test-Path -LiteralPath (Join-Path $root 'tmp'))) 'the scratch directory and its contents are gone'
Eq "Site build-out`n" (Norm (ReadText (Join-Path $root 'conf\banner.txt'))) 'the banner was restored'
Eq "10.0.0.7`n" (Norm (ReadText (Join-Path $root 'conf\allow.txt'))) 'the forbidden line was removed'
$after = Get-StateDrift $root $policy
Eq '[none, none, none, none, none, none]' (Show (@($after | ForEach-Object { $_.Severity }))) 'the site is back in line'

# --- Duplicated lines collapse ------------------------------------------
WriteText (Join-Path $root 'conf\allow.txt') "10.0.0.7`nother`n10.0.0.7`n"
$plan = Get-StatePlan $root $policy
$office = @($plan | Where-Object { $_.Id -eq 'allow-office' })[0]
Eq 'update' $office.Action 'a duplicated line needs fixing'
$null = Invoke-StatePlan $root $policy
Eq "other`n10.0.0.7`n" (Norm (ReadText (Join-Path $root 'conf\allow.txt'))) 'the line appears exactly once, at the end'

# --- The JSON resource only owns the keys it names ----------------------
$mixedRoot = FreshDir (Work 'mixed')
New-Item -ItemType Directory -Path (Join-Path $mixedRoot 'conf') -Force | Out-Null
WriteText (Join-Path $mixedRoot 'conf\app.json') '{ "name": "old", "other": "keep", "legacy": true }'
$result = Invoke-StatePlan $mixedRoot $policy
Eq $true $result.Succeeded 'the mixed-owner run succeeded'
$settings = (ReadText (Join-Path $mixedRoot 'conf\app.json')) | ConvertFrom-Json
Eq 'site' $settings.name 'the named key was set'
Eq 'keep' $settings.other 'a key the policy does not name is left alone'
Ok (-not (@($settings.PSObject.Properties.Name) -contains 'legacy')) 'the removed key went away'
Eq 8080 $settings.server.port 'the nested key was created'
$stable = ReadText (Join-Path $mixedRoot 'conf\app.json')
$null = Invoke-StatePlan $mixedRoot $policy
Eq $stable (ReadText (Join-Path $mixedRoot 'conf\app.json')) 'a second run leaves the JSON byte for byte identical'

# --- A failing resource rolls the whole run back ------------------------
$badPolicy = Work 'bad.json'
WriteText $badPolicy '{ "resources": [ { "id": "wipe", "type": "directory", "path": "old", "ensure": "absent" }, { "id": "write", "type": "file", "path": "new/a.txt", "ensure": "present", "content": "written\n" }, { "id": "boom", "type": "gremlin", "path": "x", "ensure": "present" } ] }'

$txRoot = FreshDir (Work 'tx')
WriteText (Join-Path $txRoot 'keep.txt') 'original'
WriteText (Join-Path $txRoot 'old\inside.txt') 'must survive the rollback'
$before = Snap $txRoot

$failed = Invoke-StatePlan $txRoot $badPolicy
Eq $false $failed.Succeeded 'a run with a bad resource fails'
Eq $true $failed.RolledBack 'the run was rolled back'
Eq 'boom' $failed.FailedId 'the failing resource is named'
Eq 'Unknown resource type: gremlin' $failed.Error 'the failure message names the type'
Ok ($failed.Applied -is [string[]]) 'Applied is still String[] after a rollback'
Eq 0 (@($failed.Applied).Count) 'a rolled-back run applied nothing'
Eq $before (Snap $txRoot) 'the tree is exactly as it was before the run'
Ok (-not (Test-Path -LiteralPath (Join-Path $txRoot 'new'))) 'the file written before the failure is gone'
Eq 'must survive the rollback' (Norm (ReadText (Join-Path $txRoot 'old\inside.txt'))) 'the deleted directory came back with its contents'
Eq 'original' (Norm (ReadText (Join-Path $txRoot 'keep.txt'))) 'untouched files are untouched'

Ok ($null -ne (Throws { Get-StatePlan $txRoot $badPolicy })) 'planning a bad policy is an error too'

# --- An empty policy ------------------------------------------------------
$emptyPolicy = Work 'empty.json'
WriteText $emptyPolicy '{ "resources": [] }'
$emptyRoot = FreshDir (Work 'emptyroot')
$emptyPlan = Get-StatePlan $emptyRoot $emptyPolicy
Ok ($null -ne $emptyPlan) 'an empty policy plans an array, not null'
Ok ($emptyPlan -is [object[]]) 'an empty policy plans object[]'
Eq 0 (@($emptyPlan).Count) 'an empty policy plans nothing'
$emptyDrift = Get-StateDrift $emptyRoot $emptyPolicy
Ok ($emptyDrift -is [object[]]) 'an empty policy drifts object[]'
Eq 0 (@($emptyDrift).Count) 'an empty policy has no drift rows'
$emptyResult = Invoke-StatePlan $emptyRoot $emptyPolicy
Eq $true $emptyResult.Succeeded 'an empty policy succeeds'
Eq 0 (@($emptyResult.Applied).Count) 'an empty policy applies nothing'
Eq 0 (@($emptyResult.Skipped).Count) 'an empty policy skips nothing'

# --- A one-resource policy ------------------------------------------------
$onePolicy = Work 'one.json'
WriteText $onePolicy '{ "resources": [ { "id": "solo", "type": "file", "path": "solo.txt", "ensure": "present", "content": "solo\n" } ] }'
$oneRoot = FreshDir (Work 'oneroot')
$onePlan = Get-StatePlan $oneRoot $onePolicy
Ok ($onePlan -is [object[]]) 'a one-resource plan is object[]'
Eq 1 (@($onePlan).Count) 'one plan row'
$oneResult = Invoke-StatePlan $oneRoot $onePolicy
Ok ($oneResult.Applied -is [string[]]) 'a one-resource Applied is String[]'
Eq '[solo]' (Show $oneResult.Applied) 'the single resource was applied'
Eq "solo`n" (Norm (ReadText (Join-Path $oneRoot 'solo.txt'))) 'the single file was written'

# --- Absent file resources ------------------------------------------------
$absentPolicy = Work 'absent.json'
WriteText $absentPolicy '{ "resources": [ { "id": "gone", "type": "file", "path": "gone.txt", "ensure": "absent" } ] }'
$absentRoot = FreshDir (Work 'absentroot')
$plan = Get-StatePlan $absentRoot $absentPolicy
Eq 'none' $plan[0].Action 'a file that is already absent needs nothing'
WriteText (Join-Path $absentRoot 'gone.txt') 'delete me'
$plan = Get-StatePlan $absentRoot $absentPolicy
Eq 'delete' $plan[0].Action 'a file that must not exist is deleted'
Eq 'present' $plan[0].Reason 'and reads as present'
$null = Invoke-StatePlan $absentRoot $absentPolicy
Ok (-not (Test-Path -LiteralPath (Join-Path $absentRoot 'gone.txt'))) 'the file was deleted'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
