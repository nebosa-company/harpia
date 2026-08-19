# Field parsing for the instrument export.

$script:InvariantDateFormats = @(
    'yyyy-MM-dd',
    'yyyy-MM-dd HH:mm:ss',
    'dd/MM/yyyy',
    'dd/MM/yyyy HH:mm'
)

function ConvertFrom-InvariantNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) { return $null }
    $trimmed = $Text.Trim()
    if ($trimmed.Length -eq 0) { return $null }

    $styles = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
    $parsed = [double]0
    if ([double]::TryParse($trimmed, $styles, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        return [double]$parsed
    }
    return $null
}

function ConvertFrom-InvariantDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) { return $null }
    $trimmed = $Text.Trim()
    if ($trimmed.Length -eq 0) { return $null }

    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $trimmed,
        [string[]]$script:InvariantDateFormats,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed)
    if ($ok) { return $parsed }
    return $null
}

function Format-InvariantNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [double]$Value,

        [Parameter(Position = 1)]
        [ValidateRange(0, 9)]
        [int]$Decimals = 2
    )

    return $Value.ToString('F' + $Decimals, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Read-InvariantRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $rows = @(Import-Csv -LiteralPath $Path)
    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($row in $rows) {
        $taken = ConvertFrom-InvariantDate ([string]$row.Taken)
        $value = ConvertFrom-InvariantNumber ([string]$row.Value)
        $valid = ($null -ne $taken) -and ($null -ne $value)

        $out.Add([pscustomobject]@{
            Id    = [string]$row.Id
            Taken = $(if ($valid) { $taken } else { $null })
            Value = $(if ($valid) { $value } else { $null })
            Valid = [bool]$valid
        })
    }

    $arr = @($out)
    return , $arr
}
