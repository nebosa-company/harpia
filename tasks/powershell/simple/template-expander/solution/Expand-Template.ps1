# Placeholder expansion for the notification templates.

function Format-TemplateValue {
    param($Value)

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($null -eq $Value) { return '' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [datetime]) { return $Value.ToString('yyyy-MM-dd', $inv) }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        return [string]::Format($inv, '{0}', $Value)
    }
    if ($Value -is [System.Array]) {
        $parts = @()
        foreach ($item in $Value) { $parts += (Format-TemplateValue $item) }
        return ($parts -join ', ')
    }
    return [string]$Value
}

function Expand-Template {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Template,

        [Parameter(Mandatory, Position = 1)]
        [hashtable]$Values,

        [switch]$Strict
    )

    $pattern = [regex]'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}'
    $builder = [System.Text.StringBuilder]::new()
    $position = 0

    foreach ($match in $pattern.Matches($Template)) {
        [void]$builder.Append($Template.Substring($position, $match.Index - $position))

        $key = $match.Groups[1].Value
        $found = $false
        $value = $null
        foreach ($candidate in $Values.Keys) {
            if ([string]::Equals([string]$candidate, $key, [System.StringComparison]::OrdinalIgnoreCase)) {
                $found = $true
                $value = $Values[$candidate]
                break
            }
        }

        if ($found) {
            [void]$builder.Append((Format-TemplateValue $value))
        }
        elseif ($Strict) {
            throw "Missing template key: $key"
        }
        else {
            [void]$builder.Append($match.Value)
        }

        $position = $match.Index + $match.Length
    }

    [void]$builder.Append($Template.Substring($position))
    return $builder.ToString()
}

function Expand-TemplateFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$TemplatePath,

        [Parameter(Mandatory, Position = 1)]
        [hashtable]$Values,

        [Parameter(Mandatory, Position = 2)]
        [string]$OutPath,

        [switch]$Strict
    )

    $raw = Get-Content -LiteralPath $TemplatePath -Raw
    if ($null -eq $raw) { $raw = '' }

    $expanded = Expand-Template -Template ([string]$raw) -Values $Values -Strict:$Strict
    $normalized = ($expanded -replace "`r`n", "`n")

    $parent = Split-Path -Parent $OutPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $OutPath -Value $normalized -NoNewline -Encoding utf8NoBOM

    return $normalized
}
