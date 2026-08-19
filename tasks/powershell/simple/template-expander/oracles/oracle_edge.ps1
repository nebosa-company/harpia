$ErrorActionPreference = 'Stop'
$INV = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = $INV
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $INV

$fails = [System.Collections.Generic.List[string]]::new()
function Fail([string]$m) { $fails.Add($m) }
function Show($v) {
    $c = [System.Globalization.CultureInfo]::InvariantCulture
    if ($null -eq $v) { return '<null>' }
    if ($v -is [string]) { return $v }
    if ($v -is [bool]) { if ($v) { return 'True' } else { return 'False' } }
    if ($v -is [double] -or $v -is [single] -or $v -is [decimal]) { return ([double]$v).ToString('G15', $c) }
    if ($v -is [datetime]) { return $v.ToString('yyyy-MM-ddTHH:mm:ss.fffffff', $c) + '|' + $v.Kind }
    if ($v -is [System.Collections.IDictionary]) {
        $parts = @()
        foreach ($k in @($v.Keys | Sort-Object -CaseSensitive)) { $parts += ("{0}={1}" -f $k, (Show $v[$k])) }
        return '{' + ($parts -join '; ') + '}'
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $parts = @()
        foreach ($e in $v) { $parts += (Show $e) }
        return '[' + ($parts -join ', ') + ']'
    }
    return [string]$v
}
function Eq($expected, $actual, [string]$label) {
    $e = Show $expected
    $a = Show $actual
    if ($e -cne $a) { Fail ("{0}: expected <{1}> but got <{2}>" -f $label, $e, $a) }
}
function Ok([bool]$cond, [string]$label) { if (-not $cond) { Fail $label } }
function Done {
    if ($fails.Count -gt 0) {
        foreach ($f in $fails) { Write-Host "FAIL $f" }
        Write-Error ("{0} assertion(s) failed" -f $fails.Count) -ErrorAction Continue
        exit 1
    }
    Write-Host 'PASS'
    exit 0
}
function WorkRoot {
    $dir = Join-Path $PSScriptRoot '.oracle-work'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}
function Work([string]$name) { return (Join-Path (WorkRoot) $name) }
function FreshDir([string]$path) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}
function WriteText([string]$path, [string]$text) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}
function WriteLines([string]$path, [string[]]$lines) { WriteText $path (($lines -join "`n") + "`n") }
function ReadText([string]$path) { return [System.IO.File]::ReadAllText($path) }
function Norm([string]$text) { return ($text -replace "`r`n", "`n") }
function Throws([scriptblock]$sb) {
    try { & $sb | Out-Null; return $null } catch { return $_ }
}
function Ws([string]$rel) { return (Join-Path $PSScriptRoot $rel) }

try {
. (Ws 'Expand-Template.ps1')

[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

# A missing key is left exactly as written.
Eq 'Hi {{who}}!' (Expand-Template 'Hi {{who}}!' @{ other = 1 }) 'a missing key is left verbatim'
Eq 'Hi {{  who  }}!' (Expand-Template 'Hi {{  who  }}!' @{ other = 1 }) 'a missing key keeps its inner spacing'
Eq 'Ada then {{who}}' (Expand-Template '{{name}} then {{who}}' @{ name = 'Ada' }) 'known and unknown keys mix'

# Strict mode refuses to guess.
$err = Throws { Expand-Template 'Hi {{who}}!' @{ other = 1 } -Strict }
Ok ($null -ne $err) 'strict mode throws on a missing key'
Eq 'Missing template key: who' $err.Exception.Message 'the strict message names the key'

$err2 = Throws { Expand-Template 'Hi {{  who  }}!' @{} -Strict }
Eq 'Missing template key: who' $err2.Exception.Message 'the strict message trims the key'

Ok ($null -eq (Throws { Expand-Template 'Hi {{name}}!' @{ name = 'Ada' } -Strict })) 'strict mode is quiet when every key is present'

# Things that are not placeholders are left alone, strict or not.
Eq '{single}' (Expand-Template '{single}' @{ single = 'x' }) 'single braces are not placeholders'
Eq '{{ 9bad }}' (Expand-Template '{{ 9bad }}' @{}) 'a key cannot start with a digit'
Eq '{{ bad-key }}' (Expand-Template '{{ bad-key }}' @{}) 'a key cannot contain a hyphen'
Eq '{{}}' (Expand-Template '{{}}' @{}) 'an empty placeholder is not a placeholder'
Ok ($null -eq (Throws { Expand-Template '{{ 9bad }}' @{} -Strict })) 'strict mode ignores text that is not a placeholder'
Eq 'under_score ok' (Expand-Template '{{under_score}} ok' @{ under_score = 'under_score' }) 'underscores are allowed in keys'
Eq 'x' (Expand-Template '{{_lead}}' @{ _lead = 'x' }) 'a key may start with an underscore'

# Placeholders at the very start and very end of the template.
Eq 'A middle B' (Expand-Template '{{a}} middle {{b}}' @{ a = 'A'; b = 'B' }) 'placeholders at both ends'

# Multi-line templates keep their newlines.
$multi = "line1 {{a}}`nline2 {{b}}`n"
Eq "line1 A`nline2 B`n" (Expand-Template $multi @{ a = 'A'; b = 'B' }) 'newlines survive expansion'

# An empty string value really empties the slot.
Eq 'x=|' (Expand-Template 'x={{x}}|' @{ x = '' }) 'an empty value expands to nothing'

# Zero and false are values, not blanks.
Eq 'n=0' (Expand-Template 'n={{n}}' @{ n = 0 }) 'zero renders as zero'
Eq 'b=false' (Expand-Template 'b={{b}}' @{ b = $false }) 'false renders as false'

# Expand-TemplateFile creates missing directories and honours -Strict.
$tpl = Work 'edge.tpl'
WriteText $tpl "hello {{who}}`n"
$deep = Work 'a\b\edge.out'
$text = Expand-TemplateFile $tpl @{ who = 'world' } $deep
Eq "hello world`n" (Norm $text) 'the file expander returns the expanded text'
Ok (Test-Path -LiteralPath $deep) 'the file expander creates missing directories'
Eq "hello world`n" (Norm (ReadText $deep)) 'the file expander writes the expanded text'

$strictErr = Throws { Expand-TemplateFile $tpl @{} (Work 'never.out') -Strict }
Ok ($null -ne $strictErr) 'the file expander honours -Strict'
Eq 'Missing template key: who' $strictErr.Exception.Message 'the file expander reports the missing key'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
