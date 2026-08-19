# Visible regression tests for the backup helper.
# Run with:  pwsh -NoProfile -File tests\backup.tests.ps1
# Exits 0 when everything passes, 1 otherwise.

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\tools\Invoke-Backup.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Equal($expected, $actual, [string]$label) {
    $e = if ($null -eq $expected) { '<null>' } else { [string]$expected }
    $a = if ($null -eq $actual) { '<null>' } else { [string]$actual }
    if ($e -cne $a) { $failures.Add("$label : expected <$e> got <$a>") }
}
function Assert-True([bool]$condition, [string]$label) {
    if (-not $condition) { $failures.Add($label) }
}

$work = Join-Path $PSScriptRoot '.work'
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

$source = Join-Path $work 'source'
$backup = Join-Path $work 'backup'
New-Item -ItemType Directory -Path (Join-Path $source 'nested') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $source 'a.txt') -Value 'alpha' -NoNewline -Encoding utf8NoBOM
Set-Content -LiteralPath (Join-Path $source 'b.log') -Value 'bravo' -NoNewline -Encoding utf8NoBOM
Set-Content -LiteralPath (Join-Path $source 'nested\c.txt') -Value 'charlie' -NoNewline -Encoding utf8NoBOM

$plan = New-BackupPlan $source $backup
Assert-True ($plan -is [object[]]) 'the plan is an array'
Assert-Equal 3 (@($plan).Count) 'plan length'
Assert-Equal 'a.txt' $plan[0].RelativePath 'first planned file'
Assert-Equal 'b.log' $plan[1].RelativePath 'second planned file'
Assert-Equal 'nested/c.txt' $plan[2].RelativePath 'third planned file'
Assert-Equal 5 $plan[0].Length 'planned file length'

$filtered = New-BackupPlan $source $backup @('*.txt')
Assert-Equal 2 (@($filtered).Count) 'filtered plan length'
Assert-Equal 'a.txt' $filtered[0].RelativePath 'first filtered file'

$copied = Invoke-BackupPlan $plan
Assert-Equal 3 $copied 'files copied'
Assert-True (Test-Path -LiteralPath (Join-Path $backup 'nested\c.txt')) 'nested file copied'
Assert-Equal 'charlie' (Get-Content -LiteralPath (Join-Path $backup 'nested\c.txt') -Raw) 'nested file content'

$sourceManifest = Get-BackupManifest $source
$backupManifest = Get-BackupManifest $backup
Assert-Equal 3 (@($sourceManifest).Count) 'source manifest length'
Assert-Equal (@($sourceManifest | ForEach-Object { "$($_.RelativePath)=$($_.Sha256)" }) -join '|') `
             (@($backupManifest | ForEach-Object { "$($_.RelativePath)=$($_.Sha256)" }) -join '|') `
             'the backup matches the source'
Assert-True ($sourceManifest[0].Sha256 -cmatch '^[0-9A-F]{64}$') 'hashes are uppercase hex'

Remove-Item -LiteralPath $work -Recurse -Force

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "FAIL $f" }
    exit 1
}
Write-Host 'PASS'
exit 0
