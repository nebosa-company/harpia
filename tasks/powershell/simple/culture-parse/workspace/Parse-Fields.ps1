# Field parsing for the instrument export.
#
# The exports are produced on machines all over the world and always use
# the same wire formats, so parsing here must never depend on whatever
# regional settings the operator happens to have.

function ConvertFrom-InvariantNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    throw 'ConvertFrom-InvariantNumber is not implemented yet.'
}

function ConvertFrom-InvariantDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    throw 'ConvertFrom-InvariantDate is not implemented yet.'
}

function Format-InvariantNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [double]$Value,

        [Parameter(Position = 1)]
        [int]$Decimals = 2
    )

    throw 'Format-InvariantNumber is not implemented yet.'
}

function Read-InvariantRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    throw 'Read-InvariantRecords is not implemented yet.'
}
