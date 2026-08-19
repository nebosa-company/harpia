# Stock loading and filtering.

function Import-StockItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $rows = @(Import-Csv -LiteralPath $Path)
    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($row in $rows) {
        $tags = [string[]]@(([string]$row.Tags).Split(';') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.Length -gt 0 })

        $cost = $null
        $raw = ([string]$row.UnitCost).Trim()
        if ($raw.Length -gt 0) {
            $parsed = [double]0
            $ok = [double]::TryParse(
                $raw,
                [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$parsed)
            if ($ok) { $cost = [double]$parsed }
        }

        $items.Add([pscustomobject]@{
            Sku          = [string]$row.Sku
            Name         = [string]$row.Name
            Category     = [string]$row.Category
            Supplier     = [string]$row.Supplier
            OnHand       = [int]$row.OnHand
            ReorderPoint = [int]$row.ReorderPoint
            UnitCost     = $cost
            Tags         = $tags
        })
    }

    $arr = [object[]]@($items)
    return , $arr
}

function Select-ActiveStock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Item
    )

    $active = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($Item)) {
        $discontinued = $false
        foreach ($tag in @($entry.Tags)) {
            if ([string]$tag -ceq 'discontinued') { $discontinued = $true; break }
        }
        if (-not $discontinued) { $active.Add($entry) }
    }

    $arr = [object[]]@($active)
    return , $arr
}
