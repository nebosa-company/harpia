# Layered configuration for the reporting service.

function Test-JsonObjectNode {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [System.Array]) { return $false }
    return ($Value -is [System.Management.Automation.PSCustomObject])
}

function Merge-JsonNode {
    param($Base, $Override)

    if ((Test-JsonObjectNode $Base) -and (Test-JsonObjectNode $Override)) {
        $result = [ordered]@{}
        foreach ($p in $Base.PSObject.Properties) { $result[$p.Name] = $p.Value }
        foreach ($p in $Override.PSObject.Properties) {
            if ($null -eq $p.Value) {
                if ($result.Contains($p.Name)) { $result.Remove($p.Name) }
                continue
            }
            if ($result.Contains($p.Name)) {
                $result[$p.Name] = Merge-JsonNode $result[$p.Name] $p.Value
            }
            else {
                $result[$p.Name] = $p.Value
            }
        }
        return [pscustomobject]$result
    }

    if ($Override -is [System.Array]) { return , $Override }
    return $Override
}

function Merge-JsonConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BasePath,

        [Parameter(Mandatory)]
        [string]$OverridePath
    )

    $base = (Get-Content -LiteralPath $BasePath -Raw) | ConvertFrom-Json
    $over = (Get-Content -LiteralPath $OverridePath -Raw) | ConvertFrom-Json
    return (Merge-JsonNode $base $over)
}

function Save-MergedConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $json = $Config | ConvertTo-Json -Depth 10
    $text = ($json -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $text -NoNewline -Encoding utf8NoBOM
}
