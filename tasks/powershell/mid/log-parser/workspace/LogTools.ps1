# Application log tooling for the on-call rota.
#
# The log ships one event per line. Anything else in the file — banners,
# stack-trace continuations, half-written lines from a crash — is noise.

function ConvertFrom-AppLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    throw 'ConvertFrom-AppLog is not implemented yet.'
}

function Get-LogSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Entry
    )

    throw 'Get-LogSummary is not implemented yet.'
}

function Get-LogParseStats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    throw 'Get-LogParseStats is not implemented yet.'
}
