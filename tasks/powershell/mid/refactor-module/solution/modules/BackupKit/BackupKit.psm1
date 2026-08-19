# BackupKit - plan, copy, and verify file backups.

function New-BackupPlan {
    <#
    .SYNOPSIS
        Builds the list of files a backup would copy.

    .DESCRIPTION
        Walks SourceRoot recursively, keeps the files whose name matches at
        least one of the Include patterns, and returns one record per file
        describing where it lives and where it belongs under
        DestinationRoot. Nothing is copied. The result is always an array,
        ordered by RelativePath using ordinal comparison.

    .PARAMETER SourceRoot
        The directory to walk. A path that does not exist yields an empty
        plan rather than an error.

    .PARAMETER DestinationRoot
        The directory the files would be copied into. It does not have to
        exist yet.

    .PARAMETER Include
        Wildcard patterns matched against each file's name. A file is kept
        when it matches any of them. Defaults to every file.

    .EXAMPLE
        $plan = New-BackupPlan C:\site C:\vault
        Plans a backup of everything under C:\site.

    .EXAMPLE
        $plan = New-BackupPlan C:\site C:\vault @('*.txt', '*.ini')
        Plans a backup of the text and configuration files only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$SourceRoot,

        [Parameter(Mandatory, Position = 1)]
        [string]$DestinationRoot,

        [Parameter(Position = 2)]
        [string[]]$Include = @('*')
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $SourceRoot) {
        $root = (Resolve-Path -LiteralPath $SourceRoot).ProviderPath
        foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)) {
            $keep = $false
            foreach ($pattern in @($Include)) {
                if ($file.Name -like $pattern) { $keep = $true; break }
            }
            if (-not $keep) { continue }

            $relative = $file.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/')
            $rows.Add([pscustomobject]@{
                RelativePath = [string]$relative
                Source       = [string]$file.FullName
                Destination  = [string](Join-Path $DestinationRoot ($relative -replace '/', '\'))
                Length       = [long]$file.Length
            })
        }
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.RelativePath })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}

function Invoke-BackupPlan {
    <#
    .SYNOPSIS
        Copies the files a plan describes.

    .DESCRIPTION
        Copies every entry of a plan produced by New-BackupPlan to its
        Destination, creating missing directories and overwriting whatever
        is already there, and returns how many files were copied.

    .PARAMETER Plan
        The records returned by New-BackupPlan. An empty plan copies
        nothing and returns 0.

    .EXAMPLE
        $copied = Invoke-BackupPlan (New-BackupPlan C:\site C:\vault)
        Copies everything under C:\site into C:\vault.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Plan
    )

    $copied = 0
    foreach ($entry in @($Plan)) {
        $parent = Split-Path -Parent ([string]$entry.Destination)
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath ([string]$entry.Source) -Destination ([string]$entry.Destination) -Force
        $copied++
    }
    return [int]$copied
}

function Get-BackupManifest {
    <#
    .SYNOPSIS
        Lists every file under a directory with its SHA-256 hash.

    .DESCRIPTION
        Walks Root recursively and returns one record per file with its
        path relative to Root and the uppercase hexadecimal SHA-256 of its
        contents. Two manifests compare equal exactly when the two trees
        hold the same files with the same contents. The result is always an
        array, ordered by RelativePath using ordinal comparison.

    .PARAMETER Root
        The directory to walk. A path that does not exist yields an empty
        manifest rather than an error.

    .EXAMPLE
        $manifest = Get-BackupManifest C:\vault
        Lists the vault's contents with their hashes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $Root) {
        $full = (Resolve-Path -LiteralPath $Root).ProviderPath
        foreach ($file in @(Get-ChildItem -LiteralPath $full -File -Recurse -Force)) {
            $relative = $file.FullName.Substring($full.Length).TrimStart('\').Replace('\', '/')
            $rows.Add([pscustomobject]@{
                RelativePath = [string]$relative
                Sha256       = [string](Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
            })
        }
    }

    $ordered = [object[]]@($rows)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.RelativePath })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}

Export-ModuleMember -Function @('New-BackupPlan', 'Invoke-BackupPlan', 'Get-BackupManifest')
