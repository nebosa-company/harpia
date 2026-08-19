# Parallel mapper for the batch tools.
#
# The batch tools hand this a list of items and a block to run against
# each one. Items are independent; the report that comes back is not, and
# has to line up with the input list every time.

function Invoke-ParallelMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 2)]
        [int]$ThrottleLimit = 4
    )

    throw 'Invoke-ParallelMap is not implemented yet.'
}
