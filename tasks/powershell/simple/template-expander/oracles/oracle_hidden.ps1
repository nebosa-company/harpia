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

# Everything runs under a comma-decimal ambient culture on purpose.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

Eq 'Hello Ada.' (Expand-Template 'Hello {{name}}.' @{ name = 'Ada' }) 'a plain placeholder'
Eq 'Hello Ada.' (Expand-Template 'Hello {{ name }}.' @{ name = 'Ada' }) 'spaces inside the braces'
Eq 'Hello Ada.' (Expand-Template 'Hello {{   name   }}.' @{ name = 'Ada' }) 'more spaces inside the braces'
Eq 'Ada and Ada' (Expand-Template '{{name}} and {{ name }}' @{ name = 'Ada' }) 'a repeated placeholder'
Eq 'AdaGrace' (Expand-Template '{{a}}{{b}}' @{ a = 'Ada'; b = 'Grace' }) 'adjacent placeholders'
Eq 'Hello Ada.' (Expand-Template 'Hello {{NAME}}.' @{ name = 'Ada' }) 'keys match case insensitively'
Eq 'Hello Ada.' (Expand-Template 'Hello {{name}}.' @{ NaMe = 'Ada' }) 'table keys match case insensitively too'

Ok ((Expand-Template 'x' @{}) -is [string]) 'the result is a string'
Eq 'no placeholders here' (Expand-Template 'no placeholders here' @{ a = 1 }) 'a template with nothing to expand'
Eq '' (Expand-Template '' @{ a = 1 }) 'an empty template'

# Value rendering is invariant.
Eq 'n=1234.5' (Expand-Template 'n={{n}}' @{ n = [double]1234.5 }) 'doubles render with a dot'
Eq 'n=42' (Expand-Template 'n={{n}}' @{ n = 42 }) 'integers render plainly'
Eq 'f=true|g=false' (Expand-Template 'f={{f}}|g={{g}}' @{ f = $true; g = $false }) 'booleans render lower case'
Eq 'd=2026-03-05' (Expand-Template 'd={{d}}' @{ d = [datetime]::new(2026, 3, 5, 14, 30, 0) }) 'dates render as yyyy-MM-dd'
Eq 'v=' (Expand-Template 'v={{v}}' @{ v = $null }) 'a null value renders as nothing'
Eq 'l=a, b, c' (Expand-Template 'l={{l}}' @{ l = @('a', 'b', 'c') }) 'a list renders comma separated'

# A substituted value is never scanned again.
Eq 'Hello {{admin}}!' (Expand-Template 'Hello {{name}}!' @{ name = '{{admin}}'; admin = 'root' }) 'values are not re-expanded'

# A whole template from disk.
$values = @{
    customer  = 'Ada Lovelace'
    account   = 'AC-0042'
    opened    = [datetime]::new(2026, 1, 17)
    balance   = [double]1250.75
    paperless = $true
}
$out = Work 'welcome.out.txt'
$text = Expand-TemplateFile (Ws 'templates\welcome.txt') $values $out
Ok ($text -is [string]) 'Expand-TemplateFile returns the expanded text'
Ok ($text.Contains('Hello Ada Lovelace,')) 'the greeting expanded'
Ok ($text.Contains('Your account AC-0042 was opened on 2026-01-17.')) 'the account line expanded'
Ok ($text.Contains('Balance: 1250.75')) 'the balance rendered invariantly'
Ok ($text.Contains('Paperless: true')) 'the flag rendered lower case'
Ok ($text.Contains('quote AC-0042.')) 'the repeated placeholder expanded'
Ok (-not $text.Contains('{{')) 'no placeholder is left behind'

Ok (Test-Path -LiteralPath $out) 'Expand-TemplateFile writes the output file'
Eq (Norm $text) (Norm (ReadText $out)) 'the file holds what was returned'
$bytes = [System.IO.File]::ReadAllBytes($out)
Ok (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'the output file has no byte-order mark'
Ok (-not (ReadText $out).Contains("`r")) 'the output file uses LF line endings'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
