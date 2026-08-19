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

$policy = Ws 'policy\site.json'
$root = FreshDir (Work 'site')

# --- The plan for an empty site -----------------------------------------
$plan = Get-StatePlan $root $policy
Ok ($plan -is [object[]]) 'Get-StatePlan must return object[]'
Eq 6 (@($plan).Count) 'one row per resource'
Eq '[Id, Type, Action, Reason]' (Show (@($plan[0].PSObject.Properties.Name))) 'plan property names and order'
Eq '[conf-dir, app-settings, allow-office, deny-loopback, banner, scratch]' (Show (@($plan | ForEach-Object { $_.Id }))) 'rows follow policy order'
Eq '[directory, json-patch, line, line, file, directory]' (Show (@($plan | ForEach-Object { $_.Type }))) 'resource types'
Eq '[create, create, create, none, create, none]' (Show (@($plan | ForEach-Object { $_.Action }))) 'actions on an empty site'
Eq '[missing, missing, missing, ok, missing, ok]' (Show (@($plan | ForEach-Object { $_.Reason }))) 'reasons on an empty site'

$drift = Get-StateDrift $root $policy
Ok ($drift -is [object[]]) 'Get-StateDrift must return object[]'
Eq '[Id, Severity, Detail]' (Show (@($drift[0].PSObject.Properties.Name))) 'drift property names and order'
Eq '[major, major, major, none, major, none]' (Show (@($drift | ForEach-Object { $_.Severity }))) 'severities on an empty site'
Eq '[missing, missing, missing, ok, missing, ok]' (Show (@($drift | ForEach-Object { $_.Detail }))) 'drift details'

# --- Applying it ---------------------------------------------------------
$result = Invoke-StatePlan $root $policy
Eq '[Succeeded, Applied, Skipped, RolledBack, FailedId, Error]' (Show (@($result.PSObject.Properties.Name))) 'result property names and order'
Eq $true $result.Succeeded 'the run succeeded'
Eq $false $result.RolledBack 'nothing was rolled back'
Eq $null $result.FailedId 'no resource failed'
Eq $null $result.Error 'no error'
Ok ($result.Applied -is [string[]]) 'Applied is String[]'
Ok ($result.Skipped -is [string[]]) 'Skipped is String[]'
Eq '[conf-dir, app-settings, allow-office, banner]' (Show $result.Applied) 'the resources that were applied'
Eq '[deny-loopback, scratch]' (Show $result.Skipped) 'the resources that were already in line'

Ok (Test-Path -LiteralPath (Join-Path $root 'conf') -PathType Container) 'the directory was created'
Ok (-not (Test-Path -LiteralPath (Join-Path $root 'tmp'))) 'the absent directory was not created'
Eq "10.0.0.7`n" (Norm (ReadText (Join-Path $root 'conf\allow.txt'))) 'the allow list holds the one line'
Eq "Site build-out`n" (Norm (ReadText (Join-Path $root 'conf\banner.txt'))) 'the banner file content'

$settings = (ReadText (Join-Path $root 'conf\app.json')) | ConvertFrom-Json
Eq 'site' $settings.name 'the patched name'
Eq 8080 $settings.server.port 'the dotted key created a nested object'
Eq $false $settings.debug 'a false value is written, not skipped'
Ok (-not (@($settings.PSObject.Properties.Name) -contains 'legacy')) 'the removed key is absent'

# --- Running it again changes nothing ------------------------------------
$before = ReadText (Join-Path $root 'conf\app.json')
$plan = Get-StatePlan $root $policy
Eq '[none, none, none, none, none, none]' (Show (@($plan | ForEach-Object { $_.Action }))) 'the site is in line'
Eq '[ok, ok, ok, ok, ok, ok]' (Show (@($plan | ForEach-Object { $_.Reason }))) 'nothing to report'

$drift = Get-StateDrift $root $policy
Eq '[none, none, none, none, none, none]' (Show (@($drift | ForEach-Object { $_.Severity }))) 'no drift'

$again = Invoke-StatePlan $root $policy
Eq $true $again.Succeeded 'the second run succeeded'
Eq 0 (@($again.Applied).Count) 'the second run applied nothing'
Eq 6 (@($again.Skipped).Count) 'the second run skipped everything'
Eq $before (ReadText (Join-Path $root 'conf\app.json')) 'the patched file is byte for byte unchanged'
Eq "10.0.0.7`n" (Norm (ReadText (Join-Path $root 'conf\allow.txt'))) 'the allow list is unchanged'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
