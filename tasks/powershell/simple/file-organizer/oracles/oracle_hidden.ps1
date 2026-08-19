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
. (Ws 'Move-ByExtension.ps1')

$root = FreshDir (Work 'tree1')
WriteText (Join-Path $root 'a.TXT') 'alpha'
WriteText (Join-Path $root 'b.txt') 'bravo'
WriteText (Join-Path $root 'c.log') 'charlie'
WriteText (Join-Path $root 'd.csv') 'delta'
WriteText (Join-Path $root 'notes') 'echo'
WriteText (Join-Path $root 'sub\e.txt') 'foxtrot'

$r = Invoke-FileOrganizer -Root $root

Ok ($r -is [object[]]) 'Invoke-FileOrganizer must return object[]'
Eq 5 (@($r).Count) 'one record per loose file'
Eq '[a.TXT, b.txt, c.log, d.csv, notes]' (Show (@($r | ForEach-Object { $_.Name }))) 'names in ordinal order'
Eq '[txt, txt, log, csv, other]' (Show (@($r | ForEach-Object { $_.Bucket }))) 'bucket per file'
Eq '[Name, Bucket, Destination, Moved, Status]' (Show (@($r[0].PSObject.Properties.Name))) 'property names and order'
Eq 'txt\a.TXT' $r[0].Destination 'destination is relative to the root'
Eq $true $r[0].Moved 'Moved is true after a real move'
Ok ($r[0].Moved -is [bool]) 'Moved is a Boolean'
Eq 'moved' $r[0].Status 'Status after a real move'
Eq '[moved, moved, moved, moved, moved]' (Show (@($r | ForEach-Object { $_.Status }))) 'every file moved'

Ok (Test-Path -LiteralPath (Join-Path $root 'txt\a.TXT')) 'a.TXT filed under txt'
Ok (Test-Path -LiteralPath (Join-Path $root 'txt\b.txt')) 'b.txt filed under txt'
Ok (Test-Path -LiteralPath (Join-Path $root 'log\c.log')) 'c.log filed under log'
Ok (Test-Path -LiteralPath (Join-Path $root 'csv\d.csv')) 'd.csv filed under csv'
Ok (Test-Path -LiteralPath (Join-Path $root 'other\notes')) 'extensionless file filed under other'
Eq 'alpha' (ReadText (Join-Path $root 'txt\a.TXT')) 'content survives the move'

Eq 0 (@(Get-ChildItem -LiteralPath $root -File -Force).Count) 'no loose files remain'
Ok (Test-Path -LiteralPath (Join-Path $root 'sub\e.txt')) 'files inside subdirectories are left alone'
Ok (Test-Path -LiteralPath (Join-Path $root 'sub')) 'subdirectories survive'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
