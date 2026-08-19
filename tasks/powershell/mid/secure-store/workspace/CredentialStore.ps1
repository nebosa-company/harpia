# Credential store for the scheduled jobs.
#
# The jobs run as one service account and need a handful of service
# passwords. Nothing readable ever goes to disk.

function Save-StoredCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory, Position = 2)]
        [securestring]$Password,

        [Parameter(Mandatory, Position = 3)]
        [string]$Path
    )

    throw 'Save-StoredCredential is not implemented yet.'
}

function Get-StoredCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )

    throw 'Get-StoredCredential is not implemented yet.'
}

function Get-StoredCredentialName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    throw 'Get-StoredCredentialName is not implemented yet.'
}

function Remove-StoredCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )

    throw 'Remove-StoredCredential is not implemented yet.'
}
