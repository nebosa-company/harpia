# Sensor reading conversion for the cold-store dashboard.
#
# Readings arrive in kelvin from the loggers and are shown in whichever
# scale the site prefers. The dashboard pipes readings straight through
# these commands, so they have to behave like real cmdlets.

function Import-ReadingFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    throw 'Import-ReadingFile is not implemented yet.'
}

function Format-Reading {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [double]$Kelvin
    )

    throw 'Format-Reading is not implemented yet.'
}

function Measure-Reading {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        $Reading
    )

    throw 'Measure-Reading is not implemented yet.'
}
