# Token frequency for the support-ticket corpus.
#
# The counts feed a small report that gets pasted into the weekly summary,
# so the same corpus has to produce the same report every single time.

function Get-TokenCounts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Position = 1)]
        [string]$StopWordPath
    )

    throw 'Get-TokenCounts is not implemented yet.'
}

function Format-CountReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Counts,

        [Parameter(Position = 1)]
        [int]$Top = 10
    )

    throw 'Format-CountReport is not implemented yet.'
}
