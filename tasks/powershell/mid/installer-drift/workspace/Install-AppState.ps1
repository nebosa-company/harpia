# Desired-state installer for the on-prem agent.
#
# One JSON document describes the files the agent needs. Running the
# installer twice in a row must be indistinguishable from running it once.

function Test-AppState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$SpecPath
    )

    throw 'Test-AppState is not implemented yet.'
}

function Install-AppState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$SpecPath
    )

    throw 'Install-AppState is not implemented yet.'
}

function Get-AppStateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$SpecPath
    )

    throw 'Get-AppStateReport is not implemented yet.'
}
