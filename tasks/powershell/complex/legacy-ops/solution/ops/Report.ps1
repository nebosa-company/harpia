# Rendering of the category report.

function Format-StockReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Category
    )

    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $lines = [System.Collections.Generic.List[string]]::new()
    $total = [double]0

    foreach ($row in @($Category)) {
        $value = [double]0
        if ($null -ne $row.TotalValue) { $value = [double]$row.TotalValue }
        $average = [double]0
        if ($null -ne $row.AverageUnitCost) { $average = [double]$row.AverageUnitCost }
        $total += $value

        $lines.Add([string]::Format(
            $invariant,
            '{0} items={1} priced={2} value={3:F2} avg={4:F4}',
            [string]$row.Category,
            [int]$row.Items,
            [int]$row.Priced,
            $value,
            $average))
    }

    $lines.Add([string]::Format($invariant, 'TOTAL value={0:F2}', $total))

    $arr = [string[]]@($lines)
    return , $arr
}
