# Layered configuration for the reporting service.
#
# A base file holds the defaults; one environment file is layered on top
# of it just before the service starts.

function Merge-JsonConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BasePath,

        [Parameter(Mandatory)]
        [string]$OverridePath
    )

    throw 'Merge-JsonConfig is not implemented yet.'
}

function Save-MergedConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [Parameter(Mandatory)]
        [string]$Path
    )

    throw 'Save-MergedConfig is not implemented yet.'
}
