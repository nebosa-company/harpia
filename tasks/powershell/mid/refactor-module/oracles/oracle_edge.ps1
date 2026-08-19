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

# --- The manifest is explicit -------------------------------------------
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
Eq 'BackupKit.psm1' $manifest.RootModule 'RootModule points at the script module'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.ModuleVersion)) 'the manifest carries a version'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.GUID)) 'the manifest carries a GUID'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.Description)) 'the manifest carries a description'
Eq '[Get-BackupManifest, Invoke-BackupPlan, New-BackupPlan]' (Show (@($manifest.FunctionsToExport | Sort-Object))) 'FunctionsToExport names the three helpers'
Ok (-not ((@($manifest.FunctionsToExport) -join ',').Contains('*'))) 'FunctionsToExport is not a wildcard'
Ok ($null -ne (Test-ModuleManifest -Path $manifestPath -ErrorAction SilentlyContinue)) 'Test-ModuleManifest accepts the manifest'

# --- Dot-sourcing the old path still provides the commands --------------
. (Ws 'tools\Invoke-Backup.ps1')
foreach ($name in @('New-BackupPlan', 'Invoke-BackupPlan', 'Get-BackupManifest')) {
    Ok ($null -ne (Get-Command $name -ErrorAction SilentlyContinue)) "dot-sourcing the old script still provides $name"
}

# --- Every public command is documented ---------------------------------
foreach ($name in @('New-BackupPlan', 'Invoke-BackupPlan', 'Get-BackupManifest')) {
    $help = Get-Help $name -Full
    $synopsis = ([string]($help.Synopsis | Out-String)).Trim()
    $description = ([string]($help.Description | Out-String)).Trim()
    Ok ($synopsis.Length -gt 0) "$name has a synopsis"
    Ok (-not $synopsis.StartsWith($name)) "$name has a written synopsis rather than its own syntax"
    Ok ($description.Length -gt 0) "$name has a description"

    $examples = @($help.Examples.Example)
    Ok ($examples.Count -ge 1) "$name has at least one example"

    $declared = @((Get-Command $name).Parameters.Keys | Where-Object {
        $_ -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ProgressAction',
                    'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer',
                    'PipelineVariable', 'WhatIf', 'Confirm')
    })
    foreach ($parameterName in $declared) {
        $documented = @($help.parameters.parameter | Where-Object { $_.Name -eq $parameterName })
        Ok ($documented.Count -ge 1) "$name documents its $parameterName parameter"
        if ($documented.Count -ge 1) {
            $text = ([string]($documented[0].Description | Out-String)).Trim()
            Ok ($text.Length -gt 0) "$name has help text for $parameterName"
        }
    }
}

# --- Behavioural corners ------------------------------------------------
$root = FreshDir (Work 'edge')
$source = Join-Path $root 'source'
$backup = Join-Path $root 'backup'

# A source that does not exist yet.
$missingPlan = New-BackupPlan (Join-Path $root 'nope') $backup
Ok ($null -ne $missingPlan) 'a missing source gives an array, not null'
Ok ($missingPlan -is [object[]]) 'a missing source gives object[]'
Eq 0 (@($missingPlan).Count) 'a missing source plans nothing'
$missingManifest = Get-BackupManifest (Join-Path $root 'nope')
Ok ($missingManifest -is [object[]]) 'a missing root gives an empty manifest'
Eq 0 (@($missingManifest).Count) 'a missing root manifests nothing'

# An empty source directory.
New-Item -ItemType Directory -Path $source -Force | Out-Null
$emptyPlan = New-BackupPlan $source $backup
Ok ($emptyPlan -is [object[]]) 'an empty source gives object[]'
Eq 0 (@($emptyPlan).Count) 'an empty source plans nothing'
Eq 0 (Invoke-BackupPlan $emptyPlan) 'copying an empty plan copies nothing'
Eq 0 (Invoke-BackupPlan @()) 'copying an explicitly empty plan copies nothing'

# A single file.
WriteText (Join-Path $source 'only.txt') 'solo'
$onePlan = New-BackupPlan $source $backup
Ok ($onePlan -is [object[]]) 'a one-file plan is object[]'
Eq 1 (@($onePlan).Count) 'one-file plan length'
Eq 'only.txt' $onePlan[0].RelativePath 'one-file relative path'
Eq 1 (Invoke-BackupPlan $onePlan) 'one file copied'
$oneManifest = Get-BackupManifest $backup
Ok ($oneManifest -is [object[]]) 'a one-file manifest is object[]'
Eq 1 (@($oneManifest).Count) 'one-file manifest length'

# A filter that matches nothing.
$noMatch = New-BackupPlan $source $backup @('*.zip')
Ok ($noMatch -is [object[]]) 'a filter matching nothing gives object[]'
Eq 0 (@($noMatch).Count) 'a filter matching nothing plans nothing'

# Several patterns are OR-ed together.
WriteText (Join-Path $source 'notes.md') 'notes'
WriteText (Join-Path $source 'data.csv') 'csv'
$several = New-BackupPlan $source $backup @('*.md', '*.csv')
Eq '[data.csv, notes.md]' (Show (@($several | ForEach-Object { $_.RelativePath }))) 'several patterns are combined'

# Changed content changes the hash.
$before = (Get-BackupManifest $source)[0].Sha256
WriteText (Join-Path $source 'data.csv') 'csv changed'
$after = (Get-BackupManifest $source)[0].Sha256
Ok ($before -cne $after) 'a content change changes the hash'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
