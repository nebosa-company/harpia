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

[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

$csv = Ws 'data\stock.csv'

# --- The reorder plan ----------------------------------------------------
$plan = Get-StockReorderPlan $csv
Ok ($plan -is [object[]]) 'Get-StockReorderPlan must return object[]'
Eq 5 (@($plan).Count) 'five items are below their reorder point'
Eq '[Supplier, Sku, Name, OnHand, ReorderPoint, OrderQuantity, LineCost]' (Show (@($plan[0].PSObject.Properties.Name))) 'plan property names and order'
Eq '[S001, S010, S011, S003, S009]' (Show (@($plan | ForEach-Object { $_.Sku }))) 'ordered by supplier then sku'
Eq '[Acme, Acme, Acme, Bolt Co, Bolt Co]' (Show (@($plan | ForEach-Object { $_.Supplier }))) 'suppliers grouped together'
Eq '[18, 10, 6, 30, 7]' (Show (@($plan | ForEach-Object { $_.OrderQuantity }))) 'order quantities'
Eq '[13.5, <null>, <null>, 3, <null>]' (Show (@($plan | ForEach-Object { $_.LineCost }))) 'line costs, empty where there is no unit cost'
Ok ($plan[0].OrderQuantity -is [int]) 'OrderQuantity is Int32'
Ok ($plan[0].LineCost -is [double]) 'a known line cost is Double'
Eq 'Bolt' $plan[0].Name 'the item name is carried through'
Eq 2 $plan[0].OnHand 'the stock level is carried through'
Eq 10 $plan[0].ReorderPoint 'the reorder point is carried through'

# An item exactly at its reorder point is not ordered.
$items = Import-StockItem $csv
$active = Select-ActiveStock $items
$direct = Get-ReorderPlan $active
Eq 5 (@($direct).Count) 'Get-ReorderPlan agrees with the entry point'
Ok (-not (@($direct | ForEach-Object { $_.Sku }) -contains 'S006')) 'stock exactly at the reorder point is not ordered'
Ok (-not (@($direct | ForEach-Object { $_.Sku }) -contains 'S002')) 'stock above the reorder point is not ordered'
Ok (-not (@($direct | ForEach-Object { $_.Sku }) -contains 'S008')) 'a discontinued item is never ordered'

# --- Exporting the plan ---------------------------------------------------
$out = Work 'reorder.csv'
$written = Export-ReorderPlan $plan $out
Ok ($written -is [int]) 'Export-ReorderPlan returns an Int32'
Eq 5 $written 'five rows were written'
Ok (Test-Path -LiteralPath $out) 'the export file exists'

$text = Norm (ReadText $out)
$expected = @(
    'Supplier,Sku,Name,OnHand,ReorderPoint,OrderQuantity,LineCost',
    'Acme,S001,Bolt,2,10,18,13.50',
    'Acme,S010,Shim,0,5,10,',
    'Acme,S011,Gasket,0,3,6,',
    'Bolt Co,S003,Washer,0,15,30,3.00',
    'Bolt Co,S009,Bracket,1,4,7,'
) -join "`n"
Eq ($expected + "`n") $text 'the exported CSV, exactly'

$bytes = [System.IO.File]::ReadAllBytes($out)
Ok (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'the export has no byte-order mark'
Ok (-not $text.Contains("`r")) 'the export uses LF line endings'

# --- Empty inputs ---------------------------------------------------------
$emptyCsv = Work 'empty.csv'
WriteLines $emptyCsv @('Sku,Name,Category,Supplier,OnHand,ReorderPoint,UnitCost,Tags')
$emptyItems = Import-StockItem $emptyCsv
Ok ($emptyItems -is [object[]]) 'an empty export loads object[]'
Eq 0 (@($emptyItems).Count) 'an empty export has no items'
$emptyActive = Select-ActiveStock $emptyItems
Ok ($emptyActive -is [object[]]) 'filtering nothing gives object[]'
Eq 0 (@($emptyActive).Count) 'filtering nothing gives nothing'
$emptyCategories = Get-CategoryValue $emptyActive
Ok ($emptyCategories -is [object[]]) 'valuing nothing gives object[]'
Eq 0 (@($emptyCategories).Count) 'valuing nothing gives no categories'
$emptyLines = Get-StockReport $emptyCsv
Ok ($emptyLines -is [string[]]) 'an empty report is String[]'
Eq 1 (@($emptyLines).Count) 'an empty report is just the total line'
Eq 'TOTAL value=0.00' $emptyLines[0] 'the empty total line'
$emptyPlan = Get-ReorderPlan $emptyActive
Ok ($emptyPlan -is [object[]]) 'an empty plan is object[]'
Eq 0 (@($emptyPlan).Count) 'an empty plan has no rows'
$emptyOut = Work 'empty-reorder.csv'
Eq 0 (Export-ReorderPlan $emptyPlan $emptyOut) 'exporting an empty plan writes no rows'
Eq "Supplier,Sku,Name,OnHand,ReorderPoint,OrderQuantity,LineCost`n" (Norm (ReadText $emptyOut)) 'an empty export is just the header'

# --- A one-row export ------------------------------------------------------
$oneCsv = Work 'one.csv'
WriteLines $oneCsv @(
    'Sku,Name,Category,Supplier,OnHand,ReorderPoint,UnitCost,Tags',
    'X1,Solo,solo,Acme,1,4,2.50,clearance'
)
$oneItems = Import-StockItem $oneCsv
Ok ($oneItems -is [object[]]) 'a one-row export loads object[]'
Eq 1 (@($oneItems).Count) 'one item'
Eq 2.5 $oneItems[0].UnitCost 'the one unit cost'
$oneActive = Select-ActiveStock $oneItems
Ok ($oneActive -is [object[]]) 'a one-item filter gives object[]'
Eq 1 (@($oneActive).Count) 'the one item survives'
$oneCategories = Get-CategoryValue $oneActive
Ok ($oneCategories -is [object[]]) 'a one-category valuation gives object[]'
Eq 1 (@($oneCategories).Count) 'one category'
Eq 2.5 $oneCategories[0].TotalValue 'the one category value'
$oneLines = Get-StockReport $oneCsv
Eq 'solo items=1 priced=1 value=2.50 avg=2.5000' $oneLines[0] 'the one category line'
Eq 'TOTAL value=2.50' $oneLines[1] 'the one total line'
$onePlan = Get-ReorderPlan $oneActive
Ok ($onePlan -is [object[]]) 'a one-row plan is object[]'
Eq 1 (@($onePlan).Count) 'one plan row'
Eq 7 $onePlan[0].OrderQuantity 'the one order quantity'
Eq 17.5 $onePlan[0].LineCost 'the one line cost'

# --- Every item discontinued ----------------------------------------------
$allGoneCsv = Work 'gone.csv'
WriteLines $allGoneCsv @(
    'Sku,Name,Category,Supplier,OnHand,ReorderPoint,UnitCost,Tags',
    'Y1,Old,legacy,Acme,1,4,2.50,discontinued',
    'Y2,Older,legacy,Acme,1,4,2.50,clearance;discontinued'
)
$goneItems = Import-StockItem $allGoneCsv
$goneActive = Select-ActiveStock $goneItems
Ok ($goneActive -is [object[]]) 'filtering everything out gives object[]'
Eq 0 (@($goneActive).Count) 'both discontinued items are dropped, whatever else they are tagged'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
