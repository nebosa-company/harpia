# Valuation of the stock, grouped by category, and the reorder plan.

function Get-CategoryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Item
    )

    $order = [System.Collections.Generic.List[string]]::new()
    $groups = @{}

    foreach ($entry in @($Item)) {
        $category = [string]$entry.Category
        if (-not $groups.ContainsKey($category)) {
            $groups[$category] = [System.Collections.Generic.List[object]]::new()
            $order.Add($category)
        }
        $groups[$category].Add($entry)
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($category in $order) {
        $group = @($groups[$category])
        $priced = @($group | Where-Object { $null -ne $_.UnitCost })

        $total = [double]0
        $costSum = [double]0
        foreach ($entry in $priced) {
            $total += [double]$entry.OnHand * [double]$entry.UnitCost
            $costSum += [double]$entry.UnitCost
        }

        $average = [double]0
        if ($priced.Count -gt 0) {
            $average = [double]$costSum / [double]$priced.Count
        }

        $rows.Add([pscustomobject]@{
            Category        = [string]$category
            Items           = [int]$group.Count
            Priced          = [int]$priced.Count
            TotalValue      = [double][math]::Round($total, 2, [System.MidpointRounding]::AwayFromZero)
            AverageUnitCost = [double][math]::Round($average, 4, [System.MidpointRounding]::AwayFromZero)
        })
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.Category })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}

function Get-ReorderPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Item
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($Item)) {
        $onHand = [int]$entry.OnHand
        $reorderPoint = [int]$entry.ReorderPoint
        if ($onHand -ge $reorderPoint) { continue }

        $quantity = [int][math]::Max(0, ($reorderPoint * 2) - $onHand)
        $lineCost = $null
        if ($null -ne $entry.UnitCost) {
            $lineCost = [double][math]::Round($quantity * [double]$entry.UnitCost, 2, [System.MidpointRounding]::AwayFromZero)
        }

        $rows.Add([pscustomobject]@{
            Supplier      = [string]$entry.Supplier
            Sku           = [string]$entry.Sku
            Name          = [string]$entry.Name
            OnHand        = [int]$onHand
            ReorderPoint  = [int]$reorderPoint
            OrderQuantity = [int]$quantity
            LineCost      = $lineCost
        })
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { ([string]$_.Supplier) + "`u{0001}" + ([string]$_.Sku) })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}

function Export-ReorderPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Plan,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )

    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('Supplier,Sku,Name,OnHand,ReorderPoint,OrderQuantity,LineCost')

    $written = 0
    foreach ($row in @($Plan)) {
        $cost = ''
        if ($null -ne $row.LineCost) {
            $cost = ([double]$row.LineCost).ToString('F2', $invariant)
        }
        $lines.Add([string]::Format(
            $invariant,
            '{0},{1},{2},{3},{4},{5},{6}',
            [string]$row.Supplier,
            [string]$row.Sku,
            [string]$row.Name,
            [int]$row.OnHand,
            [int]$row.ReorderPoint,
            [int]$row.OrderQuantity,
            $cost))
        $written++
    }

    $text = (($lines -join "`n") + "`n")
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))

    return [int]$written
}
