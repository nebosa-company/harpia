# Sample collector for the calibration bench.
#
# The bench script resets the collector, feeds it samples from one or
# more runs, and prints a report at the end.

$script:Samples = @{}
$script:Total = 0

function Reset-Collector {
    [CmdletBinding()]
    param()

    $Samples = @{}
    $Total = 0
}

function Add-Sample {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [double]$Value
    )

    if (-not $Samples.ContainsKey($Name)) {
        $Samples[$Name] = [System.Collections.Generic.List[double]]::new()
    }
    $Samples[$Name].Add([double]$Value)

    $Total = $Total + 1
}

function Import-SampleFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $rows = @(Import-Csv -LiteralPath $Path)
    $read = 0
    foreach ($row in $rows) {
        Add-Sample -Name ([string]$row.Name) -Value ([double]$row.Value)
        $read++
    }
    return [int]$read
}

function Get-CollectorTotal {
    [CmdletBinding()]
    param()

    return [int]$Total
}

function Get-CollectorReport {
    [CmdletBinding()]
    param()

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $Samples.Keys) {
        $values = $Samples[$name]
        $sum = [double]0
        foreach ($v in $values) { $sum += [double]$v }
        $count = [int]$values.Count
        $mean = [double]0
        if ($count -gt 0) {
            $mean = [math]::Round($sum / $count, 4, [System.MidpointRounding]::AwayFromZero)
        }
        $rows.Add([pscustomobject]@{
            Name  = [string]$name
            Count = [int]$count
            Sum   = [double]$sum
            Mean  = [double]$mean
        })
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.Name })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}
