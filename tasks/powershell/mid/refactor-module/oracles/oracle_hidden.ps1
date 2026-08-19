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
$manifestPath = Ws 'modules\BackupKit\BackupKit.psd1'
Ok (Test-Path -LiteralPath $manifestPath) 'the BackupKit manifest exists'

Import-Module $manifestPath -Force -ErrorAction Stop
$module = Get-Module BackupKit
Ok ($null -ne $module) 'the module imports by manifest path'
Eq '[Get-BackupManifest, Invoke-BackupPlan, New-BackupPlan]' (Show (@($module.ExportedFunctions.Keys | Sort-Object))) 'exactly the three helpers are exported'
Eq 0 (@($module.ExportedVariables.Keys).Count) 'no variables are exported'

# --- Behaviour is unchanged ---------------------------------------------
$root = FreshDir (Work 'tree')
$source = Join-Path $root 'source'
$backup = Join-Path $root 'backup'
WriteText (Join-Path $source 'a.txt') 'alpha'
WriteText (Join-Path $source 'b.log') 'bravo'
WriteText (Join-Path $source 'nested\c.txt') 'charlie'
WriteText (Join-Path $source 'nested\deep\d.txt') 'delta'

$plan = New-BackupPlan $source $backup
Ok ($plan -is [object[]]) 'the plan is object[]'
Eq 4 (@($plan).Count) 'plan length'
Eq '[RelativePath, Source, Destination, Length]' (Show (@($plan[0].PSObject.Properties.Name))) 'plan property names and order'
Eq '[a.txt, b.log, nested/c.txt, nested/deep/d.txt]' (Show (@($plan | ForEach-Object { $_.RelativePath }))) 'relative paths use forward slashes and ordinal order'
Eq 5 $plan[0].Length 'planned file length'
Ok ($plan[0].Length -is [long]) 'Length is Int64'
Ok ([string]::Equals([string]$plan[2].Destination, (Join-Path $backup 'nested\c.txt'), [System.StringComparison]::OrdinalIgnoreCase)) 'destination path'
Ok ([string]::Equals([string]$plan[0].Source, (Join-Path $source 'a.txt'), [System.StringComparison]::OrdinalIgnoreCase)) 'source path'

$filtered = New-BackupPlan $source $backup @('*.txt')
Eq 3 (@($filtered).Count) 'the include filter keeps only matching names'
Eq '[a.txt, nested/c.txt, nested/deep/d.txt]' (Show (@($filtered | ForEach-Object { $_.RelativePath }))) 'filtered relative paths'

$copied = Invoke-BackupPlan $plan
Eq 4 $copied 'every planned file was copied'
Ok ($copied -is [int]) 'the copy count is Int32'
Ok (Test-Path -LiteralPath (Join-Path $backup 'nested\deep\d.txt')) 'the deepest file was copied'
Eq 'delta' (ReadText (Join-Path $backup 'nested\deep\d.txt')) 'the deepest file content'

$sourceManifest = Get-BackupManifest $source
$backupManifest = Get-BackupManifest $backup
Ok ($sourceManifest -is [object[]]) 'the manifest is object[]'
Eq '[RelativePath, Sha256]' (Show (@($sourceManifest[0].PSObject.Properties.Name))) 'manifest property names and order'
Eq 4 (@($sourceManifest).Count) 'manifest length'
Eq '[a.txt, b.log, nested/c.txt, nested/deep/d.txt]' (Show (@($sourceManifest | ForEach-Object { $_.RelativePath }))) 'manifest ordering'
Ok ($sourceManifest[0].Sha256 -cmatch '^[0-9A-F]{64}$') 'hashes are uppercase hex'
Eq (Show (@($sourceManifest | ForEach-Object { "$($_.RelativePath)=$($_.Sha256)" }))) (Show (@($backupManifest | ForEach-Object { "$($_.RelativePath)=$($_.Sha256)" }))) 'the backup matches the source'

# Copying again over an existing backup still works.
Eq 4 (Invoke-BackupPlan $plan) 'a second copy overwrites without complaint'

# --- The old entry point still works ------------------------------------
$shim = ReadText (Ws 'tools\Invoke-Backup.ps1')
Ok ($shim -match '(?i)Import-Module') 'the old script now imports the module'
Ok (-not ($shim -match '(?im)^\s*function\s+New-BackupPlan\b')) 'the old script no longer defines New-BackupPlan'
Ok (-not ($shim -match '(?im)^\s*function\s+Invoke-BackupPlan\b')) 'the old script no longer defines Invoke-BackupPlan'
Ok (-not ($shim -match '(?im)^\s*function\s+Get-BackupManifest\b')) 'the old script no longer defines Get-BackupManifest'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
