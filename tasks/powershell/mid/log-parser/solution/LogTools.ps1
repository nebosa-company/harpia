# Application log tooling for the on-call rota.

$script:LogLinePattern = [regex]'^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) \[(?<lvl>TRACE|DEBUG|INFO|WARN|ERROR)\] (?<comp>\S+) - (?<msg>.*)$'
$script:LogDurationPattern = [regex]'^(?<body>.*?)\s*\(dur=(?<ms>\d+)ms\)$'

function Get-AppLogLine {
    param([string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $text) { $text = '' }
    $text = ($text -replace "`r`n", "`n")
    if ($text.EndsWith("`n")) { $text = $text.Substring(0, $text.Length - 1) }
    if ($text.Length -eq 0) { return , ([string[]]@()) }
    return , ([string[]]$text.Split("`n"))
}

function ConvertFrom-AppLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal

    $lines = Get-AppLogLine -Path $Path
    $out = [System.Collections.Generic.List[object]]::new()
    $number = 0

    foreach ($line in @($lines)) {
        $number++
        $match = $script:LogLinePattern.Match([string]$line)
        if (-not $match.Success) { continue }

        $stamp = [datetime]::MinValue
        $ok = [datetime]::TryParseExact($match.Groups['ts'].Value, 'yyyy-MM-ddTHH:mm:ssZ', $inv, $styles, [ref]$stamp)
        if (-not $ok) { continue }

        $message = $match.Groups['msg'].Value
        $duration = $null
        $durMatch = $script:LogDurationPattern.Match($message)
        if ($durMatch.Success) {
            $duration = [int]$durMatch.Groups['ms'].Value
            $message = $durMatch.Groups['body'].Value
        }

        $out.Add([pscustomobject]@{
            LineNumber = [int]$number
            Timestamp  = $stamp
            Level      = [string]$match.Groups['lvl'].Value
            Component  = [string]$match.Groups['comp'].Value
            Message    = [string]$message.Trim()
            DurationMs = $duration
        })
    }

    $arr = [object[]]@($out)
    return , $arr
}

function Get-LogSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Entry
    )

    $order = [System.Collections.Generic.List[string]]::new()
    $groups = @{}

    foreach ($item in @($Entry)) {
        if ($null -eq $item) { continue }
        $component = [string]$item.Component
        if (-not $groups.ContainsKey($component)) {
            $groups[$component] = [pscustomobject]@{
                Component = $component
                Total     = 0
                Errors    = 0
                Warnings  = 0
                Durations = [System.Collections.Generic.List[int]]::new()
            }
            $order.Add($component)
        }
        $bucket = $groups[$component]
        $bucket.Total = $bucket.Total + 1
        if ([string]$item.Level -ceq 'ERROR') { $bucket.Errors = $bucket.Errors + 1 }
        if ([string]$item.Level -ceq 'WARN') { $bucket.Warnings = $bucket.Warnings + 1 }
        if ($null -ne $item.DurationMs) { $bucket.Durations.Add([int]$item.DurationMs) }
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($component in $order) {
        $bucket = $groups[$component]
        $max = $null
        $avg = $null
        if ($bucket.Durations.Count -gt 0) {
            $sum = 0
            $max = [int]$bucket.Durations[0]
            foreach ($d in $bucket.Durations) {
                $sum += [int]$d
                if ([int]$d -gt $max) { $max = [int]$d }
            }
            $avg = [double][math]::Round([double]$sum / [double]$bucket.Durations.Count, 2, [System.MidpointRounding]::AwayFromZero)
        }
        $rows.Add([pscustomobject]@{
            Component     = [string]$component
            Total         = [int]$bucket.Total
            Errors        = [int]$bucket.Errors
            Warnings      = [int]$bucket.Warnings
            MaxDurationMs = $max
            AvgDurationMs = $avg
        })
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { '{0:D10}|{1}' -f (2000000000 - [int]$_.Total), [string]$_.Component })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}

function Get-LogParseStats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $lines = Get-AppLogLine -Path $Path
    $total = @($lines).Count
    $entries = ConvertFrom-AppLog -Path $Path
    $parsed = @($entries).Count

    return [pscustomobject]@{
        Lines   = [int]$total
        Parsed  = [int]$parsed
        Skipped = [int]($total - $parsed)
    }
}
