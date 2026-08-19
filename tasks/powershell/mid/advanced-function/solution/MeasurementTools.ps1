# Sensor reading conversion for the cold-store dashboard.

function Import-ReadingFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $inv = [System.Globalization.CultureInfo]::InvariantCulture

    foreach ($row in @(Import-Csv -LiteralPath $Path)) {
        $kelvin = [double]0
        $raw = ([string]$row.Kelvin).Trim()
        [void][double]::TryParse($raw, [System.Globalization.NumberStyles]::Float, $inv, [ref]$kelvin)
        [pscustomobject]@{
            Sensor = [string]$row.Sensor
            Kelvin = [double]$kelvin
        }
    }
}

function Format-Reading {
    [CmdletBinding(DefaultParameterSetName = 'Celsius')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Celsius')]
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Fahrenheit')]
        [double]$Kelvin,

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Celsius')]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Fahrenheit')]
        [string]$Sensor = 'unknown',

        [Parameter(ParameterSetName = 'Celsius')]
        [Parameter(ParameterSetName = 'Fahrenheit')]
        [ValidateRange(0, 6)]
        [int]$Decimals = 2,

        [Parameter(ParameterSetName = 'Celsius')]
        [switch]$Celsius,

        [Parameter(Mandatory, ParameterSetName = 'Fahrenheit')]
        [switch]$Fahrenheit
    )

    begin {
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
    }

    process {
        $celsiusValue = $Kelvin - 273.15
        if ($PSCmdlet.ParameterSetName -eq 'Fahrenheit') {
            $scale = 'F'
            $raw = ($celsiusValue * 9.0 / 5.0) + 32.0
        }
        else {
            $scale = 'C'
            $raw = $celsiusValue
        }

        $value = [math]::Round([double]$raw, $Decimals, [System.MidpointRounding]::AwayFromZero)

        [pscustomobject]@{
            Sensor = [string]$Sensor
            Kelvin = [double]$Kelvin
            Scale  = [string]$scale
            Value  = [double]$value
            Text   = ('{0} {1}' -f $value.ToString('F' + $Decimals, $inv), $scale)
        }
    }
}

function Measure-Reading {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [psobject[]]$Reading
    )

    begin {
        $values = [System.Collections.Generic.List[double]]::new()
        $scales = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($null -eq $Reading) { return }
        foreach ($item in $Reading) {
            if ($null -eq $item) { continue }
            $values.Add([double]$item.Value)
            $scales.Add([string]$item.Scale)
        }
    }

    end {
        $count = $values.Count
        if ($count -eq 0) {
            [pscustomobject]@{
                Count = [int]0
                Scale = $null
                Min   = $null
                Max   = $null
                Mean  = $null
            }
            return
        }

        $distinct = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($s in $scales) { [void]$distinct.Add($s) }
        if ($distinct.Count -eq 1) { $scale = [string]$scales[0] } else { $scale = 'mixed' }

        $min = $values[0]
        $max = $values[0]
        $sum = [double]0
        foreach ($v in $values) {
            if ($v -lt $min) { $min = $v }
            if ($v -gt $max) { $max = $v }
            $sum += $v
        }

        [pscustomobject]@{
            Count = [int]$count
            Scale = [string]$scale
            Min   = [double]$min
            Max   = [double]$max
            Mean  = [double][math]::Round($sum / $count, 4, [System.MidpointRounding]::AwayFromZero)
        }
    }
}
