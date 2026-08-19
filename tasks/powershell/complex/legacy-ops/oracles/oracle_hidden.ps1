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
. (Ws 'ops\Ops.ps1')

# The whole run happens under a comma-decimal ambient culture on purpose.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

$csv = Ws 'data\stock.csv'

# --- Loading -------------------------------------------------------------
$items = Import-StockItem $csv
Ok ($items -is [object[]]) 'Import-StockItem must return object[]'
Eq 11 (@($items).Count) 'every row is loaded'
Eq '[Sku, Name, Category, Supplier, OnHand, ReorderPoint, UnitCost, Tags]' (Show (@($items[0].PSObject.Properties.Name))) 'item property names and order'
Eq 0.75 $items[0].UnitCost 'a dot is a decimal point, not a group separator'
Eq 12.5 $items[6].UnitCost 'a larger cost is read the same way'
Ok ($items[0].UnitCost -is [double]) 'UnitCost is Double'
Eq $null $items[8].UnitCost 'a blank cost is empty, not zero'
Eq 2 $items[0].OnHand 'OnHand is read'
Eq 10 $items[0].ReorderPoint 'ReorderPoint is read'
Ok ($items[0].Tags -is [string[]]) 'Tags is String[]'
Eq 0 (@($items[0].Tags).Count) 'an item with no tags has an empty tag list'
Eq '[discontinued, clearance]' (Show $items[3].Tags) 'semicolons separate tags'
Eq '[clearance]' (Show $items[5].Tags) 'a single tag is still a list'

# --- Filtering -----------------------------------------------------------
$active = Select-ActiveStock $items
Ok ($active -is [object[]]) 'Select-ActiveStock must return object[]'
Eq 9 (@($active).Count) 'only the discontinued items are dropped'
Eq '[S001, S002, S003, S005, S006, S007, S009, S010, S011]' (Show (@($active | ForEach-Object { $_.Sku }))) 'which items survive'
Ok (-not (@($active | ForEach-Object { $_.Sku }) -contains 'S004')) 'an item tagged discontinued and clearance is still dropped'
Ok (-not (@($active | ForEach-Object { $_.Sku }) -contains 'S008')) 'an item tagged only discontinued is dropped'
Ok ((@($active | ForEach-Object { $_.Sku }) -contains 'S001')) 'an item with no tags at all is kept'

# --- Valuation -----------------------------------------------------------
$categories = Get-CategoryValue $active
Ok ($categories -is [object[]]) 'Get-CategoryValue must return object[]'
Eq 5 (@($categories).Count) 'five categories'
Eq '[Category, Items, Priced, TotalValue, AverageUnitCost]' (Show (@($categories[0].PSObject.Properties.Name))) 'category property names and order'
Eq '[anchors, fasteners, seals, spares, tools]' (Show (@($categories | ForEach-Object { $_.Category }))) 'categories in ordinal order'
Eq '[2, 3, 1, 1, 2]' (Show (@($categories | ForEach-Object { $_.Items }))) 'item counts'
Eq '[2, 3, 0, 0, 1]' (Show (@($categories | ForEach-Object { $_.Priced }))) 'priced counts'
Eq '[150, 11.5, 0, 0, 1250]' (Show (@($categories | ForEach-Object { $_.TotalValue }))) 'category values, zero where nothing is priced'
Eq '[2.75, 0.4167, 0, 0, 12.5]' (Show (@($categories | ForEach-Object { $_.AverageUnitCost }))) 'average unit costs, zero where nothing is priced'
Ok ($categories[2].TotalValue -is [double]) 'an unpriced category still reports a Double total'
Ok ($categories[2].AverageUnitCost -is [double]) 'an unpriced category still reports a Double average'

# --- The report ----------------------------------------------------------
$lines = Get-StockReport $csv
Ok ($lines -is [string[]]) 'Get-StockReport must return String[]'
Eq 6 (@($lines).Count) 'five category lines and a total'
Eq 'anchors items=2 priced=2 value=150.00 avg=2.7500' $lines[0] 'the anchors line'
Eq 'fasteners items=3 priced=3 value=11.50 avg=0.4167' $lines[1] 'the fasteners line'
Eq 'seals items=1 priced=0 value=0.00 avg=0.0000' $lines[2] 'the seals line, with nothing priced'
Eq 'spares items=1 priced=0 value=0.00 avg=0.0000' $lines[3] 'the spares line, with nothing priced'
Eq 'tools items=2 priced=1 value=1250.00 avg=12.5000' $lines[4] 'the tools line'
Eq 'TOTAL value=1411.50' $lines[5] 'the total line'
foreach ($line in @($lines)) {
    Ok (-not $line.Contains(',')) 'the report never uses a comma as a decimal point'
}
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
