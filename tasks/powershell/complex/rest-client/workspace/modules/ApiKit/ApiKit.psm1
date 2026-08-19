# ApiKit - retrying, paging client for the internal REST services.
#
# The client never talks to a socket itself. It is handed a transport
# script block and calls that, which is what makes it testable and what
# lets the same client sit on top of different plumbing.

function New-ApiClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$BaseUri,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$Transport,

        [Parameter(Position = 2)]
        [int]$MaxRetries = 3,

        [Parameter(Position = 3)]
        [int]$RetryDelayMs = 100
    )

    throw 'New-ApiClient is not implemented yet.'
}

function Invoke-ApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        $Client,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path,

        [Parameter(Position = 2)]
        [string]$Method = 'GET',

        [Parameter(Position = 3)]
        $Body,

        [Parameter(Position = 4)]
        [hashtable]$Headers
    )

    throw 'Invoke-ApiRequest is not implemented yet.'
}

function Get-ApiPagedResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        $Client,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path,

        [Parameter(Position = 2)]
        [int]$MaxPages = 50
    )

    throw 'Get-ApiPagedResult is not implemented yet.'
}

Export-ModuleMember -Function *
