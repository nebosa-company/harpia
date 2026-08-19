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

# Nothing below the threshold.
$none = Get-LowStock -Path $csv -Threshold 0
Ok ($null -ne $none) 'no matches must not give $null'
Ok ($none -is [object[]]) 'no matches must still give object[]'
Eq 0 (@($none).Count) 'no-match count'

$sum0 = Get-LowStockSummary -Path $csv -Threshold 0
Eq 0 $sum0.Count 'no-match summary count'
Ok ($sum0.Count -is [int]) 'no-match Count is Int32'
Ok ($null -ne $sum0.Names) 'no-match Names must not be $null'
Ok ($sum0.Names -is [string[]]) 'no-match Names is String[]'
Eq 0 (@($sum0.Names).Count) 'no-match Names length'
Ok ($null -ne $sum0.TotalMissing) 'no-match TotalMissing must not be $null'
Eq 0 $sum0.TotalMissing 'no-match TotalMissing is zero'
Ok ($sum0.TotalMissing -is [int]) 'no-match TotalMissing is Int32'

# Everything below the threshold, including items already above reorder.
$all = Get-LowStock -Path $csv -Threshold 1000
Eq 8 (@($all).Count) 'every item is below 1000'
$nut = @($all | Where-Object { $_.Sku -eq 'S002' })[0]
Eq 0 $nut.Missing 'stock above the reorder point is never a negative shortfall'
$sumAll = Get-LowStockSummary -Path $csv -Threshold 1000
Eq 8 $sumAll.Count 'all-items summary count'
Eq 43 $sumAll.TotalMissing 'items above their reorder point add nothing'
Eq 8 (@($sumAll.Names).Count) 'all-items names length'

# A one-row export.
$oneRow = Work 'one.csv'
WriteLines $oneRow @('Sku,Name,OnHand,Reorder', 'S100,Solo,1,4')
$o = Get-LowStock -Path $oneRow -Threshold 10
Ok ($o -is [object[]]) 'a one-row export must still give object[]'
Eq 1 (@($o).Count) 'one-row count'
Eq 3 $o[0].Missing 'one-row shortfall'
$so = Get-LowStockSummary -Path $oneRow -Threshold 10
Ok ($so.Names -is [string[]]) 'one-row Names is String[]'
Eq '[Solo]' (Show $so.Names) 'one-row names'
Eq 3 $so.TotalMissing 'one-row total missing'

# A header-only export.
$empty = Work 'empty.csv'
WriteLines $empty @('Sku,Name,OnHand,Reorder')
$e = Get-LowStock -Path $empty -Threshold 10
Ok ($e -is [object[]]) 'a header-only export must still give object[]'
Eq 0 (@($e).Count) 'header-only count'
$se = Get-LowStockSummary -Path $empty -Threshold 10
Eq 0 $se.Count 'header-only summary count'
Eq 0 $se.TotalMissing 'header-only total missing'
Eq 0 (@($se.Names).Count) 'header-only names length'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
