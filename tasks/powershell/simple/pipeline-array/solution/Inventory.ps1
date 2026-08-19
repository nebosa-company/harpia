# Low-stock reporting for the parts room.

function Get-LowStock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Threshold
    )

    $rows = @(Import-Csv -LiteralPath $Path)

    $low = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $rows) {
        $onHand = [int]$row.OnHand
        if ($onHand -ge $Threshold) { continue }
        $reorder = [int]$row.Reorder
        $low.Add([pscustomobject]@{
            Sku     = [string]$row.Sku
            Name    = [string]$row.Name
            OnHand  = [int]$onHand
            Reorder = [int]$reorder
            Missing = [int][math]::Max(0, $reorder - $onHand)
        })
    }

    $sorted = @($low | Sort-Object -Property Sku)
    return , $sorted
}

function Get-LowStockSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Threshold
    )

    $result = Get-LowStock -Path $Path -Threshold $Threshold
    $low = @($result)

    $names = [string[]]@($low | ForEach-Object { [string]$_.Name })

    $total = 0
    foreach ($item in $low) { $total += [int]$item.Missing }

    return [pscustomobject]@{
        Count        = [int]$low.Count
        Names        = $names
        TotalMissing = [int]$total
    }
}
