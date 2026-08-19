# Step runner for the maintenance playbooks.
#
# Playbook steps are ordinary script blocks. The runner has to survive
# every one of them so the operator gets a complete report instead of a
# stack trace halfway down the list.

function Invoke-Safely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1)]
        [string]$Name = 'unnamed'
    )

    throw 'Invoke-Safely is not implemented yet.'
}

function Invoke-AllSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [scriptblock[]]$ScriptBlock,

        [switch]$StopOnError
    )

    throw 'Invoke-AllSafely is not implemented yet.'
}
