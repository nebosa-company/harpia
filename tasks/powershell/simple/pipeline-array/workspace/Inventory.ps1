# Low-stock reporting for the parts room.
#
# Reads the nightly inventory export and tells the buyer what is running
# out and by how much.

function Get-LowStock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Threshold
    )

    $rows = Import-Csv -LiteralPath $Path

    $low = $rows |
        Where-Object { [int]$_.OnHand -lt $Threshold } |
        ForEach-Object {
            [pscustomobject]@{
                Sku     = [string]$_.Sku
                Name    = [string]$_.Name
                OnHand  = [int]$_.OnHand
                Reorder = [int]$_.Reorder
                Missing = [int][math]::Max(0, [int]$_.Reorder - [int]$_.OnHand)
            }
        } |
        Sort-Object -Property Sku

    return $low
}

function Get-LowStockSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Threshold
    )

    $low = Get-LowStock -Path $Path -Threshold $Threshold

    return [pscustomobject]@{
        Count        = $low.Count
        Names        = $low.Name
        TotalMissing = ($low | Measure-Object -Property Missing -Sum).Sum
    }
}
