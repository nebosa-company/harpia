# Entry point. Dot-source this file and call Get-StockReport.

. (Join-Path $PSScriptRoot 'Inventory.ps1')
. (Join-Path $PSScriptRoot 'Pricing.ps1')
. (Join-Path $PSScriptRoot 'Report.ps1')

function Get-StockReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $items = Import-StockItem -Path $Path
    $active = Select-ActiveStock -Item ([object[]]@($items))
    $categories = Get-CategoryValue -Item ([object[]]@($active))
    $lines = Format-StockReport -Category ([object[]]@($categories))
    return , ([string[]]@($lines))
}
