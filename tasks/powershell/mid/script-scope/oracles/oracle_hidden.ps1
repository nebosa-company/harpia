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
. (Ws 'Collector.ps1')

Reset-Collector
$read = Import-SampleFile (Ws 'data\samples.csv')
Eq 6 $read 'the import reports how many rows it read'

$report = Get-CollectorReport
Ok ($report -is [object[]]) 'Get-CollectorReport must return object[]'
Eq 3 (@($report).Count) 'three sample groups'
Eq '[Name, Count, Sum, Mean]' (Show (@($report[0].PSObject.Properties.Name))) 'report property names and order'
Eq '[alpha, beta, gamma]' (Show (@($report | ForEach-Object { $_.Name }))) 'groups ordered by name'
Eq '[3, 2, 1]' (Show (@($report | ForEach-Object { $_.Count }))) 'per-group counts'
Eq '[7, 6, 10]' (Show (@($report | ForEach-Object { $_.Sum }))) 'per-group sums'
Eq '[2.3333, 3, 10]' (Show (@($report | ForEach-Object { $_.Mean }))) 'per-group means'
Ok ($report[0].Count -is [int]) 'Count is Int32'
Ok ($report[0].Sum -is [double]) 'Sum is Double'
Ok ($report[0].Mean -is [double]) 'Mean is Double'

$total = Get-CollectorTotal
Ok ($total -is [int]) 'the total is Int32'
Eq 6 $total 'every imported sample is counted'

# Adding by hand keeps the total moving.
Add-Sample 'delta' 5
Add-Sample 'alpha' 5
Eq 8 (Get-CollectorTotal) 'hand-added samples are counted too'

$report = Get-CollectorReport
Eq 4 (@($report).Count) 'a new group appears in the report'
Eq '[alpha, beta, delta, gamma]' (Show (@($report | ForEach-Object { $_.Name }))) 'the new group is in order'
$alpha = @($report | Where-Object { $_.Name -eq 'alpha' })[0]
Eq 4 $alpha.Count 'the existing group grew'
Eq 12 $alpha.Sum 'the existing group sum grew'
Eq 3 $alpha.Mean 'the existing group mean moved'

# Importing a second file accumulates on top.
$second = Work 'second.csv'
WriteLines $second @('Name,Value', 'beta,6', 'beta,8')
Eq 2 (Import-SampleFile $second) 'the second import reports its own row count'
Eq 10 (Get-CollectorTotal) 'the total spans both imports'
$report = Get-CollectorReport
$beta = @($report | Where-Object { $_.Name -eq 'beta' })[0]
Eq 4 $beta.Count 'the second import accumulated'
Eq 20 $beta.Sum 'the second import summed'
Eq 5 $beta.Mean 'the second import mean'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
