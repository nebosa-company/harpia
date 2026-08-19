# Rendering of the category report.

function Format-StockReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Category
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($row in @($Category)) {
        $lines.Add(('{0} items={1} priced={2} value={3:F2} avg={4:F4}' -f
            $row.Category, $row.Items, $row.Priced, $row.TotalValue, $row.AverageUnitCost))
    }

    $total = (@($Category) | Measure-Object -Property TotalValue -Sum).Sum
    $lines.Add(('TOTAL value={0:F2}' -f $total))

    $arr = [string[]]@($lines)
    return , $arr
}
