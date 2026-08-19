# Declarative file-state enforcer for the site build-out.
#
# One policy document describes the directories, files, JSON settings and
# individual lines a site must have. Applying it is all-or-nothing.

function Get-StatePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$PolicyPath
    )

    throw 'Get-StatePlan is not implemented yet.'
}

function Get-StateDrift {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$PolicyPath
    )

    throw 'Get-StateDrift is not implemented yet.'
}

function Invoke-StatePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$PolicyPath
    )

    throw 'Invoke-StatePlan is not implemented yet.'
}
