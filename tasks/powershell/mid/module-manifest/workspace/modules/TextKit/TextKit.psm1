# TextKit - small text helpers shared by the docs tooling.

function ConvertTo-CollapsedWhitespace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    throw 'ConvertTo-CollapsedWhitespace is not implemented yet.'
}

function ConvertTo-SlugText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Position = 1)]
        [int]$MaxLength = 0
    )

    throw 'ConvertTo-SlugText is not implemented yet.'
}

function Split-Sentence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    throw 'Split-Sentence is not implemented yet.'
}

function Get-TextStats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    throw 'Get-TextStats is not implemented yet.'
}

Export-ModuleMember -Function *
