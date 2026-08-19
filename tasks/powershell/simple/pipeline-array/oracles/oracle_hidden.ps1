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
. (Ws 'Inventory.ps1')

$csv = Ws 'data\inventory.csv'

# Several items below the threshold.
$many = Get-LowStock -Path $csv -Threshold 10
Ok ($many -is [object[]]) 'Get-LowStock must return object[]'
Eq 5 (@($many).Count) 'five items are below 10'
Eq '[S001, S003, S004, S006, S008]' (Show (@($many | ForEach-Object { $_.Sku }))) 'records ordered by Sku'
Eq '[Sku, Name, OnHand, Reorder, Missing]' (Show (@($many[0].PSObject.Properties.Name))) 'property names and order'
Eq '[8, 15, 3, 0, 17]' (Show (@($many | ForEach-Object { $_.Missing }))) 'missing quantities'
Ok ($many[0].OnHand -is [int]) 'OnHand is Int32'
Ok ($many[0].Missing -is [int]) 'Missing is Int32'

$sum = Get-LowStockSummary -Path $csv -Threshold 10
Eq 5 $sum.Count 'summary count for five items'
Ok ($sum.Count -is [int]) 'Count is Int32'
Ok ($sum.Names -is [string[]]) 'Names is String[]'
Eq '[Bolt, Washer, Screw, Rivet, Hinge]' (Show $sum.Names) 'summary names'
Eq 43 $sum.TotalMissing 'summary total missing'
Ok ($sum.TotalMissing -is [int]) 'TotalMissing is Int32'
Eq '[Count, Names, TotalMissing]' (Show (@($sum.PSObject.Properties.Name))) 'summary property names and order'

# Exactly one item below the threshold: still a list, everywhere.
$one = Get-LowStock -Path $csv -Threshold 1
Ok ($one -is [object[]]) 'a single match must still be object[]'
Eq 1 (@($one).Count) 'single-match count'
Eq 'S003' $one[0].Sku 'single-match sku'

$sum1 = Get-LowStockSummary -Path $csv -Threshold 1
Eq 1 $sum1.Count 'single-match summary count'
Ok ($sum1.Names -is [string[]]) 'a single match still gives String[] names'
Eq 1 (@($sum1.Names).Count) 'single-match names length'
Eq 'Washer' $sum1.Names[0] 'indexing a single-match name list gives the whole name'
Eq 15 $sum1.TotalMissing 'single-match total missing'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
