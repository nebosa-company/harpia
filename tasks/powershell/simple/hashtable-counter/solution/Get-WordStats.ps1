# Token frequency for the support-ticket corpus.

function Get-TokenCounts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Position = 1)]
        [string]$StopWordPath
    )

    $stop = @{}
    if (-not [string]::IsNullOrWhiteSpace($StopWordPath)) {
        foreach ($line in @(Get-Content -LiteralPath $StopWordPath)) {
            $trimmed = ([string]$line).Trim()
            if ($trimmed.Length -eq 0) { continue }
            if ($trimmed.StartsWith('#')) { continue }
            $stop[$trimmed.ToLowerInvariant()] = $true
        }
    }

    $text = ''
    if (Test-Path -LiteralPath $Path) {
        $raw = Get-Content -LiteralPath $Path -Raw
        if ($null -ne $raw) { $text = [string]$raw }
    }

    $counts = @{}
    foreach ($m in [regex]::Matches($text.ToLowerInvariant(), '[\p{L}\p{Nd}]+')) {
        $token = $m.Value
        if ($stop.ContainsKey($token)) { continue }
        if ($counts.ContainsKey($token)) { $counts[$token] = [int]$counts[$token] + 1 }
        else { $counts[$token] = 1 }
    }

    return $counts
}

function Format-CountReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Counts,

        [Parameter(Position = 1)]
        [ValidateRange(0, 10000)]
        [int]$Top = 10
    )

    $total = 0
    foreach ($key in $Counts.Keys) { $total += [int]$Counts[$key] }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($key in $Counts.Keys) {
        $count = [int]$Counts[$key]
        $share = 0.0
        if ($total -gt 0) {
            $share = [math]::Round(([double]$count / [double]$total), 4, [System.MidpointRounding]::AwayFromZero)
        }
        $rows.Add([pscustomobject]@{
            Token = [string]$key
            Count = [int]$count
            Share = [double]$share
        })
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object {
            '{0:D10}|{1}' -f (2000000000 - [int]$_.Count), [string]$_.Token
        })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }

    $take = [math]::Min($Top, $ordered.Length)
    $result = [object[]]@()
    if ($take -gt 0) { $result = [object[]]$ordered[0..($take - 1)] }
    return , $result
}
