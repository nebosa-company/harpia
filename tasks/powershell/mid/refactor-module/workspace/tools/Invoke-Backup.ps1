# Backup helper. Everything lives in this one file: plan, copy, verify.
# Dot-source it and call the functions.

function New-BackupPlan {
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
