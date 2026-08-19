# Sales rollup used by the weekly regional review.
#
# The CSV columns are Region,Product,Units,UnitPrice,OrderDate.
# Nothing else in the repository depends on this file yet.

function Get-SalesReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [double]$MinRevenue = 0
    )

    throw 'Get-SalesReport is not implemented yet.'
}
