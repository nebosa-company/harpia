# Minimal incremental build system for the docs pipeline.
#
# A build graph is a JSON document; each target names its inputs, its
# outputs, and one command from a two-verb language. Nothing shells out.

function Read-BuildGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    throw 'Read-BuildGraph is not implemented yet.'
}

function Get-BuildOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Graph,

        [Parameter(Position = 1)]
        [string]$Target
    )

    throw 'Get-BuildOrder is not implemented yet.'
}

function Invoke-Build {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$GraphPath,

        [Parameter(Position = 2)]
        [string]$Target,

        [switch]$Force
    )

    throw 'Invoke-Build is not implemented yet.'
}
