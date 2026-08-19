# Valuation of the stock, grouped by category.

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
        $values = @($priced | ForEach-Object { [double]$_.OnHand * [double]$_.UnitCost })

        $total = ($values | Measure-Object -Sum).Sum
        $average = ($priced | Measure-Object -Property UnitCost -Average).Average

        $rows.Add([pscustomobject]@{
            Category        = [string]$category
            Items           = [int]$group.Count
            Priced          = [int]$priced.Count
            TotalValue      = $total
            AverageUnitCost = $average
        })
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.Category })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}
