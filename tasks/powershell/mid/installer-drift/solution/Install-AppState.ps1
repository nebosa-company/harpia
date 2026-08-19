# Desired-state installer for the on-prem agent.

function Get-AppStateSpec {
    param([string]$SpecPath)

    $doc = (Get-Content -LiteralPath $SpecPath -Raw) | ConvertFrom-Json
    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($file in @($doc.files)) {
        $content = ''
        if ($null -ne $file.content) { $content = [string]$file.content }
        $entries.Add([pscustomobject]@{
            Path    = [string]$file.path
            Ensure  = [string]$file.ensure
            Content = ($content -replace "`r`n", "`n")
        })
    }

    $ordered = [object[]]@($entries)
    if ($ordered.Length -gt 1) {
        $keys = [string[]]@($ordered | ForEach-Object { [string]$_.Path })
        [System.Array]::Sort([array]$keys, [array]$ordered, [System.Collections.IComparer][System.StringComparer]::Ordinal)
    }
    return , $ordered
}

function Resolve-AppStatePath {
    param([string]$Root, [string]$RelativePath)
    return (Join-Path $Root ($RelativePath -replace '/', '\'))
}

function Get-AppStateFileText {
    param([string]$FullPath)

    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return $null }
    $raw = Get-Content -LiteralPath $FullPath -Raw
    if ($null -eq $raw) { $raw = '' }
    return ([string]$raw -replace "`r`n", "`n")
}

function Test-AppState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$SpecPath
    )

    $spec = Get-AppStateSpec -SpecPath $SpecPath
    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in @($spec)) {
        $full = Resolve-AppStatePath -Root $Root -RelativePath $entry.Path
        $actual = Get-AppStateFileText -FullPath $full

        if ($entry.Ensure -eq 'absent') {
            if ($null -eq $actual) { $state = 'ok' } else { $state = 'present' }
        }
        elseif ($null -eq $actual) { $state = 'missing' }
        elseif ($actual -cne $entry.Content) { $state = 'different' }
        else { $state = 'ok' }

        $out.Add([pscustomobject]@{
            Path    = [string]$entry.Path
            Ensure  = [string]$entry.Ensure
            State   = [string]$state
            InDrift = [bool]($state -ne 'ok')
        })
    }

    $arr = [object[]]@($out)
    return , $arr
}

function Install-AppState {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$SpecPath
    )

    $spec = Get-AppStateSpec -SpecPath $SpecPath
    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in @($spec)) {
        $full = Resolve-AppStatePath -Root $Root -RelativePath $entry.Path
        $actual = Get-AppStateFileText -FullPath $full
        $action = 'none'

        if ($entry.Ensure -eq 'absent') {
            if ($null -ne $actual) {
                $action = 'removed'
                if ($PSCmdlet.ShouldProcess($full, 'Remove')) {
                    Remove-Item -LiteralPath $full -Force
                }
            }
        }
        else {
            if ($null -eq $actual) { $action = 'created' }
            elseif ($actual -cne $entry.Content) { $action = 'updated' }

            if ($action -ne 'none' -and $PSCmdlet.ShouldProcess($full, $action)) {
                $parent = Split-Path -Parent $full
                if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Set-Content -LiteralPath $full -Value $entry.Content -NoNewline -Encoding utf8NoBOM
            }
        }

        $out.Add([pscustomobject]@{
            Path   = [string]$entry.Path
            Action = [string]$action
        })
    }

    $arr = [object[]]@($out)
    return , $arr
}

function Get-AppStateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$SpecPath
    )

    $states = Test-AppState -Root $Root -SpecPath $SpecPath
    $all = @($states)

    $drifted = @($all | Where-Object { $_.InDrift })
    $paths = [string[]]@($drifted | ForEach-Object { [string]$_.Path })

    return [pscustomobject]@{
        Total        = [int]$all.Count
        Compliant    = [int]($all.Count - $drifted.Count)
        Drifted      = [int]$drifted.Count
        DriftedPaths = $paths
    }
}
