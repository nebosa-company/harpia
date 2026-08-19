# Minimal incremental build system for the docs pipeline.

function ConvertTo-BuildFullPath {
    param([string]$Root, [string]$Relative)
    return (Join-Path $Root ([string]$Relative -replace '/', '\'))
}

function Get-BuildFileText {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($FullPath)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Set-BuildFileText {
    param([string]$FullPath, [string]$Text)
    $parent = Split-Path -Parent $FullPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($FullPath, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-BuildFileHash {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return $null }
    return [string](Get-FileHash -LiteralPath $FullPath -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Read-BuildGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $document = (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json
    $collected = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($node in @($document.targets)) {
        if ($null -eq $node) { continue }
        $name = [string]$node.name
        if ($seen.Contains($name)) { throw "Duplicate target: $name" }
        [void]$seen.Add($name)
        $collected.Add([pscustomobject]@{
            Name    = $name
            Inputs  = [string[]]@(@($node.inputs) | ForEach-Object { [string]$_ })
            Outputs = [string[]]@(@($node.outputs) | ForEach-Object { [string]$_ })
            Command = [string]$node.command
        })
    }

    $arr = [object[]]@($collected)
    return , $arr
}

function Get-BuildDependencyMap {
    param([object[]]$Graph)

    $producer = @{}
    foreach ($node in @($Graph)) {
        foreach ($output in @($node.Outputs)) { $producer[[string]$output] = [string]$node.Name }
    }

    $map = @{}
    foreach ($node in @($Graph)) {
        $deps = [System.Collections.Generic.List[string]]::new()
        foreach ($needed in @($node.Inputs)) {
            $key = [string]$needed
            if ($producer.ContainsKey($key)) {
                $owner = [string]$producer[$key]
                if ($owner -cne [string]$node.Name -and -not $deps.Contains($owner)) { $deps.Add($owner) }
            }
        }
        $map[[string]$node.Name] = $deps
    }
    return $map
}

function Get-BuildOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Graph,

        [Parameter(Position = 1)]
        [string]$Target
    )

    $all = @($Graph)
    $byName = @{}
    foreach ($node in $all) { $byName[[string]$node.Name] = $node }
    $deps = Get-BuildDependencyMap -Graph ([object[]]$all)

    $wanted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if ([string]::IsNullOrWhiteSpace($Target)) {
        foreach ($node in $all) { [void]$wanted.Add([string]$node.Name) }
    }
    else {
        if (-not $byName.ContainsKey($Target)) { throw "Unknown target: $Target" }
        $pending = [System.Collections.Generic.Stack[string]]::new()
        $pending.Push([string]$Target)
        while ($pending.Count -gt 0) {
            $name = $pending.Pop()
            if ($wanted.Contains($name)) { continue }
            [void]$wanted.Add($name)
            foreach ($dep in @($deps[$name])) { $pending.Push([string]$dep) }
        }
    }

    $remaining = [System.Collections.Generic.List[string]]::new()
    foreach ($node in $all) {
        if ($wanted.Contains([string]$node.Name)) { $remaining.Add([string]$node.Name) }
    }

    $done = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $order = [System.Collections.Generic.List[string]]::new()

    while ($remaining.Count -gt 0) {
        $ready = [System.Collections.Generic.List[string]]::new()
        foreach ($name in $remaining) {
            $blocked = $false
            foreach ($dep in @($deps[$name])) {
                if ($wanted.Contains([string]$dep) -and -not $done.Contains([string]$dep)) { $blocked = $true; break }
            }
            if (-not $blocked) { $ready.Add($name) }
        }
        if ($ready.Count -eq 0) {
            $stuck = [string[]]@($remaining)
            if ($stuck.Length -gt 1) { [System.Array]::Sort($stuck, [System.StringComparer]::Ordinal) }
            throw ("Cycle detected: " + ($stuck -join ', '))
        }
        $readyArray = [string[]]@($ready)
        if ($readyArray.Length -gt 1) { [System.Array]::Sort($readyArray, [System.StringComparer]::Ordinal) }
        $next = $readyArray[0]
        $order.Add($next)
        [void]$done.Add($next)
        [void]$remaining.Remove($next)
    }

    $arr = [string[]]@($order)
    return , $arr
}

function Read-BuildCache {
    param([string]$Root)

    $cache = @{}
    $path = Join-Path $Root '.buildcache.json'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $raw = Get-Content -LiteralPath $path -Raw
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $document = $raw | ConvertFrom-Json
            foreach ($entry in @($document.targets)) {
                if ($null -eq $entry) { continue }
                $inputs = @{}
                foreach ($item in @($entry.inputs)) {
                    if ($null -eq $item) { continue }
                    $inputs[[string]$item.path] = [string]$item.hash
                }
                $cache[[string]$entry.name] = [pscustomobject]@{
                    Command = [string]$entry.command
                    Inputs  = $inputs
                }
            }
        }
    }
    return $cache
}

function Write-BuildCache {
    param([hashtable]$Cache, [string]$Root)

    $names = [string[]]@($Cache.Keys)
    if ($names.Length -gt 1) { [System.Array]::Sort($names, [System.StringComparer]::Ordinal) }

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $names) {
        $entry = $Cache[$name]
        $paths = [string[]]@($entry.Inputs.Keys)
        if ($paths.Length -gt 1) { [System.Array]::Sort($paths, [System.StringComparer]::Ordinal) }
        $inputs = [System.Collections.Generic.List[object]]::new()
        foreach ($path in $paths) {
            $inputs.Add([pscustomobject]@{ path = [string]$path; hash = [string]$entry.Inputs[$path] })
        }
        $entries.Add([pscustomobject]@{
            name    = [string]$name
            command = [string]$entry.Command
            inputs  = [object[]]@($inputs)
        })
    }

    $document = [pscustomobject]@{ targets = [object[]]@($entries) }
    $json = ($document | ConvertTo-Json -Depth 8) -replace "`r`n", "`n"
    Set-BuildFileText -FullPath (Join-Path $Root '.buildcache.json') -Text $json
}

function Invoke-BuildCommand {
    param([string]$Root, [string]$Command)

    $tokens = @(([string]$Command).Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($tokens.Count -lt 4) { throw "Bad command: $Command" }

    $verb = [string]$tokens[0]
    $arrow = [System.Array]::IndexOf([array]$tokens, '>')
    if ($arrow -lt 2 -or $arrow -ne ($tokens.Count - 2)) { throw "Bad command: $Command" }

    $sources = @($tokens[1..($arrow - 1)])
    $destination = [string]$tokens[$tokens.Count - 1]

    $builder = [System.Text.StringBuilder]::new()
    foreach ($relative in $sources) {
        $text = Get-BuildFileText -FullPath (ConvertTo-BuildFullPath -Root $Root -Relative ([string]$relative))
        if ($null -eq $text) { throw "Missing input: $relative" }
        [void]$builder.Append($text)
    }

    $result = $builder.ToString()
    if ($verb -ceq 'upper') {
        if ($sources.Count -ne 1) { throw "Bad command: $Command" }
        $result = $result.ToUpperInvariant()
    }
    elseif ($verb -cne 'concat') {
        throw "Unknown verb: $verb"
    }

    Set-BuildFileText -FullPath (ConvertTo-BuildFullPath -Root $Root -Relative $destination) -Text $result
}

function Invoke-Build {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Root,

        [Parameter(Mandatory, Position = 1)]
        [string]$GraphPath,

        [Parameter(Position = 2)]
        [string]$Target,

        [switch]$Force
    )

    $graph = Read-BuildGraph -Path $GraphPath
    $order = Get-BuildOrder -Graph ([object[]]@($graph)) -Target $Target

    $byName = @{}
    foreach ($node in @($graph)) { $byName[[string]$node.Name] = $node }
    $deps = Get-BuildDependencyMap -Graph ([object[]]@($graph))
    $cache = Read-BuildCache -Root $Root

    $failed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $results = [System.Collections.Generic.List[object]]::new()
    $cacheDirty = $false

    foreach ($name in @($order)) {
        $node = $byName[$name]

        $blocked = $false
        foreach ($dep in @($deps[$name])) {
            if ($failed.Contains([string]$dep)) { $blocked = $true; break }
        }
        if ($blocked) {
            [void]$failed.Add($name)
            $results.Add([pscustomobject]@{ Name = [string]$name; Status = 'failed' })
            continue
        }

        $hashes = @{}
        $missing = $false
        foreach ($relative in @($node.Inputs)) {
            $hash = Get-BuildFileHash -FullPath (ConvertTo-BuildFullPath -Root $Root -Relative ([string]$relative))
            if ($null -eq $hash) { $missing = $true; break }
            $hashes[[string]$relative] = $hash
        }
        if ($missing) {
            [void]$failed.Add($name)
            $results.Add([pscustomobject]@{ Name = [string]$name; Status = 'failed' })
            continue
        }

        $upToDate = $false
        if (-not $Force -and $cache.ContainsKey($name)) {
            $entry = $cache[$name]
            if ([string]$entry.Command -ceq [string]$node.Command -and $entry.Inputs.Count -eq $hashes.Count) {
                $same = $true
                foreach ($key in $hashes.Keys) {
                    if (-not $entry.Inputs.ContainsKey($key)) { $same = $false; break }
                    if ([string]$entry.Inputs[$key] -cne [string]$hashes[$key]) { $same = $false; break }
                }
                if ($same) {
                    foreach ($relative in @($node.Outputs)) {
                        if (-not (Test-Path -LiteralPath (ConvertTo-BuildFullPath -Root $Root -Relative ([string]$relative)) -PathType Leaf)) {
                            $same = $false
                            break
                        }
                    }
                }
                $upToDate = $same
            }
        }

        if ($upToDate) {
            $results.Add([pscustomobject]@{ Name = [string]$name; Status = 'skipped' })
            continue
        }

        try {
            Invoke-BuildCommand -Root $Root -Command ([string]$node.Command)
        }
        catch {
            [void]$failed.Add($name)
            $results.Add([pscustomobject]@{ Name = [string]$name; Status = 'failed' })
            continue
        }

        $cache[$name] = [pscustomobject]@{ Command = [string]$node.Command; Inputs = $hashes }
        $cacheDirty = $true
        $results.Add([pscustomobject]@{ Name = [string]$name; Status = 'built' })
    }

    if ($cacheDirty) { Write-BuildCache -Cache $cache -Root $Root }

    $arr = [object[]]@($results)
    return , $arr
}
