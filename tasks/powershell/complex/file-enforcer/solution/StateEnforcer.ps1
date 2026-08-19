# Declarative file-state enforcer for the site build-out.

function Resolve-StatePath {
    param([string]$Root, [string]$Relative)
    return (Join-Path $Root ([string]$Relative -replace '/', '\'))
}

function Read-StateText {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($FullPath)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return ($text -replace "`r`n", "`n")
}

function Write-StateText {
    param([string]$FullPath, [string]$Text)
    $parent = Split-Path -Parent $FullPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($FullPath, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Read-StatePolicy {
    param([string]$PolicyPath)
    $document = (Get-Content -LiteralPath $PolicyPath -Raw) | ConvertFrom-Json
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($resource in @($document.resources)) {
        if ($null -ne $resource) { $list.Add($resource) }
    }
    $arr = [object[]]@($list)
    return , $arr
}

function Split-StateLine {
    param([string]$Text)
    if ($null -eq $Text) { return , ([string[]]@()) }
    $normalized = $Text
    if ($normalized.EndsWith("`n")) { $normalized = $normalized.Substring(0, $normalized.Length - 1) }
    if ($normalized.Length -eq 0) { return , ([string[]]@()) }
    return , ([string[]]$normalized.Split("`n"))
}

function Join-StateLine {
    param([string[]]$Lines)
    if ($null -eq $Lines -or $Lines.Length -eq 0) { return '' }
    return (($Lines -join "`n") + "`n")
}

function Set-JsonNodeValue {
    param($Node, [string[]]$Segments, $Value)

    $key = [string]$Segments[0]
    if ($Segments.Length -eq 1) {
        if (@($Node.PSObject.Properties.Name) -contains $key) { $Node.$key = $Value }
        else { $Node | Add-Member -NotePropertyName $key -NotePropertyValue $Value }
        return
    }

    $child = $null
    if (@($Node.PSObject.Properties.Name) -contains $key) { $child = $Node.$key }
    if ($null -eq $child -or -not ($child -is [System.Management.Automation.PSCustomObject])) {
        $child = [pscustomobject]@{}
        if (@($Node.PSObject.Properties.Name) -contains $key) { $Node.$key = $child }
        else { $Node | Add-Member -NotePropertyName $key -NotePropertyValue $child }
    }
    Set-JsonNodeValue -Node $child -Segments ([string[]]$Segments[1..($Segments.Length - 1)]) -Value $Value
}

function Remove-JsonNodeValue {
    param($Node, [string[]]$Segments)

    $key = [string]$Segments[0]
    if (-not (@($Node.PSObject.Properties.Name) -contains $key)) { return }
    if ($Segments.Length -eq 1) {
        $Node.PSObject.Properties.Remove($key)
        return
    }
    $child = $Node.$key
    if ($child -is [System.Management.Automation.PSCustomObject]) {
        Remove-JsonNodeValue -Node $child -Segments ([string[]]$Segments[1..($Segments.Length - 1)])
    }
}

function Get-StateDesiredJson {
    param([string]$Current, $Resource)

    if ([string]::IsNullOrWhiteSpace($Current)) { $document = [pscustomobject]@{} }
    else { $document = $Current | ConvertFrom-Json }
    if ($null -eq $document) { $document = [pscustomobject]@{} }

    if ($null -ne $Resource.set) {
        foreach ($property in @($Resource.set.PSObject.Properties)) {
            $segments = [string[]]([string]$property.Name).Split('.')
            Set-JsonNodeValue -Node $document -Segments $segments -Value $property.Value
        }
    }
    foreach ($dotted in @($Resource.remove)) {
        if ($null -eq $dotted) { continue }
        $segments = [string[]]([string]$dotted).Split('.')
        Remove-JsonNodeValue -Node $document -Segments $segments
    }

    $json = ($document | ConvertTo-Json -Depth 12) -replace "`r`n", "`n"
    return ($json.TrimEnd("`n") + "`n")
}

function Get-StateResourceStatus {
    param([string]$Root, $Resource)

    $type = [string]$Resource.type
    $full = Resolve-StatePath -Root $Root -Relative ([string]$Resource.path)

    if ($type -ceq 'directory') {
        $exists = Test-Path -LiteralPath $full -PathType Container
        if ([string]$Resource.ensure -ceq 'absent') {
            if ($exists) { return [pscustomobject]@{ Action = 'delete'; Reason = 'present' } }
            return [pscustomobject]@{ Action = 'none'; Reason = 'ok' }
        }
        if (-not $exists) { return [pscustomobject]@{ Action = 'create'; Reason = 'missing' } }
        return [pscustomobject]@{ Action = 'none'; Reason = 'ok' }
    }

    if ($type -ceq 'file') {
        $current = Read-StateText -FullPath $full
        if ([string]$Resource.ensure -ceq 'absent') {
            if ($null -ne $current) { return [pscustomobject]@{ Action = 'delete'; Reason = 'present' } }
            return [pscustomobject]@{ Action = 'none'; Reason = 'ok' }
        }
        $desired = ([string]$Resource.content) -replace "`r`n", "`n"
        if ($null -eq $current) { return [pscustomobject]@{ Action = 'create'; Reason = 'missing' } }
        if ($current -cne $desired) { return [pscustomobject]@{ Action = 'update'; Reason = 'content' } }
        return [pscustomobject]@{ Action = 'none'; Reason = 'ok' }
    }

    if ($type -ceq 'json-patch') {
        $current = Read-StateText -FullPath $full
        $desired = Get-StateDesiredJson -Current ([string]$current) -Resource $Resource
        if ($null -eq $current) { return [pscustomobject]@{ Action = 'create'; Reason = 'missing' } }
        if ($current -cne $desired) { return [pscustomobject]@{ Action = 'update'; Reason = 'content' } }
        return [pscustomobject]@{ Action = 'none'; Reason = 'ok' }
    }

    if ($type -ceq 'line') {
        $current = Read-StateText -FullPath $full
        $wanted = [string]$Resource.line
        if ([string]$Resource.ensure -ceq 'absent') {
            if ($null -eq $current) { return [pscustomobject]@{ Action = 'none'; Reason = 'ok' } }
            $lines = Split-StateLine -Text $current
            $kept = [string[]]@(@($lines) | Where-Object { $_ -cne $wanted })
            if ((Join-StateLine -Lines $kept) -cne $current) { return [pscustomobject]@{ Action = 'update'; Reason = 'content' } }
            return [pscustomobject]@{ Action = 'none'; Reason = 'ok' }
        }
        if ($null -eq $current) { return [pscustomobject]@{ Action = 'create'; Reason = 'missing' } }
        $lines = Split-StateLine -Text $current
        $occurrences = @(@($lines) | Where-Object { $_ -ceq $wanted }).Count
        if ($occurrences -eq 1) { return [pscustomobject]@{ Action = 'none'; Reason = 'ok' } }
        return [pscustomobject]@{ Action = 'update'; Reason = 'content' }
    }

    throw "Unknown resource type: $type"
}

function Set-StateResource {
    param([string]$Root, $Resource)

    $type = [string]$Resource.type
    $full = Resolve-StatePath -Root $Root -Relative ([string]$Resource.path)

    if ($type -ceq 'directory') {
        if ([string]$Resource.ensure -ceq 'absent') {
            if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
        }
        elseif (-not (Test-Path -LiteralPath $full -PathType Container)) {
            New-Item -ItemType Directory -Path $full -Force | Out-Null
        }
        return
    }

    if ($type -ceq 'file') {
        if ([string]$Resource.ensure -ceq 'absent') {
            if (Test-Path -LiteralPath $full -PathType Leaf) { Remove-Item -LiteralPath $full -Force }
            return
        }
        Write-StateText -FullPath $full -Text (([string]$Resource.content) -replace "`r`n", "`n")
        return
    }

    if ($type -ceq 'json-patch') {
        $current = Read-StateText -FullPath $full
        $desired = Get-StateDesiredJson -Current ([string]$current) -Resource $Resource
        Write-StateText -FullPath $full -Text $desired
        return
    }

    if ($type -ceq 'line') {
        $current = Read-StateText -FullPath $full
        $wanted = [string]$Resource.line
        if ([string]$Resource.ensure -ceq 'absent') {
            if ($null -eq $current) { return }
            $lines = Split-StateLine -Text $current
            $kept = [string[]]@(@($lines) | Where-Object { $_ -cne $wanted })
            Write-StateText -FullPath $full -Text (Join-StateLine -Lines $kept)
            return
        }
        $lines = Split-StateLine -Text ([string]$current)
        $occurrences = @(@($lines) | Where-Object { $_ -ceq $wanted }).Count
        if ($null -ne $current -and $occurrences -eq 1) { return }
        $kept = [System.Collections.Generic.List[string]]::new()
        foreach ($line in @($lines)) { if ($line -cne $wanted) { $kept.Add([string]$line) } }
        $kept.Add($wanted)
        Write-StateText -FullPath $full -Text (Join-StateLine -Lines ([string[]]@($kept)))
        return
    }

    throw "Unknown resource type: $type"
}

function Get-StatePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$PolicyPath
    )

    $policy = Read-StatePolicy -PolicyPath $PolicyPath
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($resource in @($policy)) {
        $status = Get-StateResourceStatus -Root $Root -Resource $resource
        $rows.Add([pscustomobject]@{
            Id     = [string]$resource.id
            Type   = [string]$resource.type
            Action = [string]$status.Action
            Reason = [string]$status.Reason
        })
    }
    $arr = [object[]]@($rows)
    return , $arr
}

function Get-StateDrift {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$PolicyPath
    )

    $plan = Get-StatePlan -Root $Root -PolicyPath $PolicyPath
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($plan)) {
        $action = [string]$entry.Action
        if ($action -ceq 'create' -or $action -ceq 'delete') { $severity = 'major' }
        elseif ($action -ceq 'update') { $severity = 'minor' }
        else { $severity = 'none' }
        $rows.Add([pscustomobject]@{
            Id       = [string]$entry.Id
            Severity = [string]$severity
            Detail   = [string]$entry.Reason
        })
    }
    $arr = [object[]]@($rows)
    return , $arr
}

function Get-StateTreeSnapshot {
    param([string]$Root)

    $existed = Test-Path -LiteralPath $Root -PathType Container
    $entries = [System.Collections.Generic.List[object]]::new()
    if ($existed) {
        $base = (Resolve-Path -LiteralPath $Root).ProviderPath
        foreach ($item in @(Get-ChildItem -LiteralPath $base -Recurse -Force)) {
            $relative = $item.FullName.Substring($base.Length).TrimStart('\')
            if ($item.PSIsContainer) {
                $entries.Add([pscustomobject]@{ Relative = $relative; IsDirectory = $true; Bytes = $null })
            }
            else {
                $entries.Add([pscustomobject]@{ Relative = $relative; IsDirectory = $false; Bytes = [System.IO.File]::ReadAllBytes($item.FullName) })
            }
        }
    }
    return [pscustomobject]@{ RootExisted = [bool]$existed; Entries = [object[]]@($entries) }
}

function Restore-StateTreeSnapshot {
    param($Snapshot, [string]$Root)

    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    if (-not $Snapshot.RootExisted) { return }

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    foreach ($entry in @($Snapshot.Entries)) {
        $full = Join-Path $Root ([string]$entry.Relative)
        if ($entry.IsDirectory) {
            if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
        }
        else {
            $parent = Split-Path -Parent $full
            if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            [System.IO.File]::WriteAllBytes($full, $entry.Bytes)
        }
    }
}

function Invoke-StatePlan {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$PolicyPath
    )

    $policy = Read-StatePolicy -PolicyPath $PolicyPath
    $applied = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    if (-not $PSCmdlet.ShouldProcess($Root, 'Apply state policy')) {
        foreach ($resource in @($policy)) {
            $status = Get-StateResourceStatus -Root $Root -Resource $resource
            if ([string]$status.Action -ceq 'none') { $skipped.Add([string]$resource.id) }
            else { $applied.Add([string]$resource.id) }
        }
        return [pscustomobject]@{
            Succeeded  = $true
            Applied    = [string[]]@($applied)
            Skipped    = [string[]]@($skipped)
            RolledBack = $false
            FailedId   = $null
            Error      = $null
        }
    }

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }
    $snapshot = Get-StateTreeSnapshot -Root $Root

    foreach ($resource in @($policy)) {
        try {
            $status = Get-StateResourceStatus -Root $Root -Resource $resource
            if ([string]$status.Action -ceq 'none') {
                $skipped.Add([string]$resource.id)
                continue
            }
            Set-StateResource -Root $Root -Resource $resource
            $applied.Add([string]$resource.id)
        }
        catch {
            Restore-StateTreeSnapshot -Snapshot $snapshot -Root $Root
            return [pscustomobject]@{
                Succeeded  = $false
                Applied    = [string[]]@()
                Skipped    = [string[]]@()
                RolledBack = $true
                FailedId   = [string]$resource.id
                Error      = [string]$_.Exception.Message
            }
        }
    }

    return [pscustomobject]@{
        Succeeded  = $true
        Applied    = [string[]]@($applied)
        Skipped    = [string[]]@($skipped)
        RolledBack = $false
        FailedId   = $null
        Error      = $null
    }
}
