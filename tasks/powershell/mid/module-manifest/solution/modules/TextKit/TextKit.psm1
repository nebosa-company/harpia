# TextKit - small text helpers shared by the docs tooling.

function ConvertTo-CollapsedWhitespace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) { return '' }
    return ([regex]::Replace($Text, '\s+', ' ')).Trim()
}

function ConvertTo-SlugText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Position = 1)]
        [int]$MaxLength = 0
    )

    if ($null -eq $Text) { return '' }

    $collapsed = ConvertTo-CollapsedWhitespace $Text
    $lowered = $collapsed.ToLowerInvariant()
    $slug = [regex]::Replace($lowered, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')

    if ($MaxLength -gt 0 -and $slug.Length -gt $MaxLength) {
        $slug = $slug.Substring(0, $MaxLength).Trim('-')
    }

    return $slug
}

function Split-Sentence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    $out = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrEmpty($Text)) {
        foreach ($piece in [regex]::Split($Text, '(?<=[.!?])(?=\s)')) {
            $trimmed = ConvertTo-CollapsedWhitespace $piece
            if ($trimmed.Length -gt 0) { $out.Add($trimmed) }
        }
    }

    $arr = [string[]]@($out)
    return , $arr
}

function Get-TextStats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    $words = [regex]::Matches($Text, '[\p{L}\p{Nd}]+')
    $wordCount = $words.Count

    $letters = 0
    foreach ($w in $words) { $letters += $w.Value.Length }

    $average = [double]0
    if ($wordCount -gt 0) {
        $average = [math]::Round([double]$letters / [double]$wordCount, 3, [System.MidpointRounding]::AwayFromZero)
    }

    $sentences = Split-Sentence $Text

    return [pscustomobject]@{
        Characters        = [int]$Text.Length
        Words             = [int]$wordCount
        Sentences         = [int]@($sentences).Count
        AverageWordLength = [double]$average
    }
}

New-Alias -Name slug -Value ConvertTo-SlugText -Force

Export-ModuleMember -Function @('ConvertTo-SlugText', 'Split-Sentence', 'Get-TextStats') -Alias @('slug')
