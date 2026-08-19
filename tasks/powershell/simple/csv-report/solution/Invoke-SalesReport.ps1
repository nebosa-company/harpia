# Sales rollup used by the weekly regional review.

function Get-SalesReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [double]$MinRevenue = 0
    )

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $rows = @(Import-Csv -Path $Path)

    $order = [System.Collections.Generic.List[string]]::new()
    $acc = @{}

    foreach ($row in $rows) {
        $region = [string]$row.Region
        if (-not $acc.ContainsKey($region)) {
            $acc[$region] = [pscustomobject]@{
                Region  = $region
                Orders  = 0
                Units   = 0
                Revenue = [double]0
            }
            $order.Add($region)
        }

        $units = 0
        $rawUnits = [string]$row.Units
        if (-not [string]::IsNullOrWhiteSpace($rawUnits)) {
            $tmpUnits = 0
            if ([int]::TryParse($rawUnits.Trim(), [System.Globalization.NumberStyles]::Integer, $inv, [ref]$tmpUnits)) {
                $units = $tmpUnits
            }
        }

        $price = [double]0
        $rawPrice = [string]$row.UnitPrice
        if (-not [string]::IsNullOrWhiteSpace($rawPrice)) {
            $tmpPrice = [double]0
            if ([double]::TryParse($rawPrice.Trim(), [System.Globalization.NumberStyles]::Float, $inv, [ref]$tmpPrice)) {
                $price = $tmpPrice
            }
        }

        $entry = $acc[$region]
        $entry.Orders = $entry.Orders + 1
        $entry.Units = $entry.Units + $units
        $entry.Revenue = $entry.Revenue + ($units * $price)
    }

    $built = [System.Collections.Generic.List[object]]::new()
    foreach ($region in $order) {
        $entry = $acc[$region]
        $revenue = [math]::Round([double]$entry.Revenue, 2, [System.MidpointRounding]::AwayFromZero)
        if ($revenue -lt $MinRevenue) { continue }
        $built.Add([pscustomobject]@{
            Region  = [string]$entry.Region
            Orders  = [int]$entry.Orders
            Units   = [int]$entry.Units
            Revenue = [double]$revenue
        })
    }

    $sorted = @($built | Sort-Object -Property `
        @{ Expression = { $_.Revenue }; Descending = $true }, `
        @{ Expression = { $_.Region }; Descending = $false })

    return , $sorted
}
