# Credential store for the scheduled jobs.

function Read-CredentialStore {
    param([string]$Path)

    $list = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $raw = Get-Content -LiteralPath $Path -Raw
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $doc = $raw | ConvertFrom-Json
            foreach ($entry in @($doc.entries)) {
                if ($null -eq $entry) { continue }
                $list.Add([pscustomobject]@{
                    name     = [string]$entry.name
                    userName = [string]$entry.userName
                    secret   = [string]$entry.secret
                })
            }
        }
    }

    $arr = [object[]]@($list)
    return , $arr
}

function Write-CredentialStore {
    param([object[]]$Entries, [string]$Path)

    $ordered = [object[]]@($Entries)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.name })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }

    $document = [pscustomobject]@{ entries = $ordered }
    $json = ($document | ConvertTo-Json -Depth 5)
    $text = ($json -replace "`r`n", "`n")

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $text -NoNewline -Encoding utf8NoBOM
}

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

    $existing = Read-CredentialStore -Path $Path
    $kept = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($existing)) {
        if ([string]$entry.name -cne $Name) { $kept.Add($entry) }
    }

    $kept.Add([pscustomobject]@{
        name     = [string]$Name
        userName = [string]$UserName
        secret   = [string](ConvertFrom-SecureString -SecureString $Password)
    })

    Write-CredentialStore -Entries ([object[]]@($kept)) -Path $Path
}

function Get-StoredCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )

    $existing = Read-CredentialStore -Path $Path
    foreach ($entry in @($existing)) {
        if ([string]$entry.name -ceq $Name) {
            $secure = ConvertTo-SecureString -String ([string]$entry.secret)
            return [System.Management.Automation.PSCredential]::new([string]$entry.userName, $secure)
        }
    }
    return $null
}

function Get-StoredCredentialName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $existing = Read-CredentialStore -Path $Path
    $names = [string[]]@(@($existing) | ForEach-Object { [string]$_.name })
    if ($names.Length -gt 1) {
        [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
    }
    return , $names
}

function Remove-StoredCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )

    $existing = Read-CredentialStore -Path $Path
    $kept = [System.Collections.Generic.List[object]]::new()
    $removed = $false
    foreach ($entry in @($existing)) {
        if ([string]$entry.name -ceq $Name) { $removed = $true; continue }
        $kept.Add($entry)
    }

    if ($removed) {
        Write-CredentialStore -Entries ([object[]]@($kept)) -Path $Path
    }
    return [bool]$removed
}
