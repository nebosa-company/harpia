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
$manifestPath = Ws 'modules\TextKit\TextKit.psd1'
Ok (Test-Path -LiteralPath $manifestPath) 'the module manifest exists'

# The manifest itself has to be well formed and explicit.
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
Eq 'TextKit.psm1' $manifest.RootModule 'RootModule points at the script module'
Eq '1.2.0' ([string]$manifest.ModuleVersion) 'ModuleVersion'
Eq '7.0' ([string]$manifest.PowerShellVersion) 'PowerShellVersion'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.GUID)) 'the manifest carries a GUID'
$guid = [guid]::Empty
Ok ([guid]::TryParse([string]$manifest.GUID, [ref]$guid)) 'the GUID parses'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.Author)) 'the manifest names an author'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.Description)) 'the manifest carries a description'

Eq '[ConvertTo-SlugText, Get-TextStats, Split-Sentence]' (Show (@($manifest.FunctionsToExport | Sort-Object))) 'FunctionsToExport lists the three names'
Ok (-not ((@($manifest.FunctionsToExport) -join ',').Contains('*'))) 'FunctionsToExport is not a wildcard'
Eq 0 (@($manifest.CmdletsToExport).Count) 'CmdletsToExport is an explicit empty list'
Eq 0 (@($manifest.VariablesToExport).Count) 'VariablesToExport is an explicit empty list'
Eq '[slug]' (Show (@($manifest.AliasesToExport))) 'AliasesToExport lists the alias'

Ok ($null -ne (Test-ModuleManifest -Path $manifestPath -ErrorAction SilentlyContinue)) 'Test-ModuleManifest accepts the manifest'

Import-Module $manifestPath -Force -ErrorAction Stop
$module = Get-Module TextKit

# The helper stays inside the module.
Ok ($null -eq (Get-Command ConvertTo-CollapsedWhitespace -ErrorAction SilentlyContinue)) 'the whitespace helper is not exported'
$insideModule = & $module { $null -ne (Get-Command ConvertTo-CollapsedWhitespace -ErrorAction SilentlyContinue) }
Ok ($insideModule) 'the whitespace helper still exists inside the module'
$collapsed = & $module { ConvertTo-CollapsedWhitespace "  a   b `t c  " }
Eq 'a b c' $collapsed 'the whitespace helper collapses and trims'

# --- Slug edges ---------------------------------------------------------
Eq '' (ConvertTo-SlugText '') 'an empty string slugs to nothing'
Eq '' (ConvertTo-SlugText '   ') 'whitespace slugs to nothing'
Eq '' (ConvertTo-SlugText '!!!') 'punctuation only slugs to nothing'
Eq 'a' (ConvertTo-SlugText '---a---') 'leading and trailing dashes are trimmed'
Eq 'a-b' (ConvertTo-SlugText 'a---b') 'a dash run collapses'
Eq 'abcdef' (ConvertTo-SlugText 'abcdef' 0) 'a zero limit leaves the slug alone'
Eq 'abc' (ConvertTo-SlugText 'abcdef' 3) 'a hard truncation'
Eq 'a' (ConvertTo-SlugText 'a b c' 2) 'truncation trims the dash it lands on'

# --- Sentence edges -----------------------------------------------------
$empty = Split-Sentence ''
Ok ($null -ne $empty) 'an empty text gives an array, not null'
Ok ($empty -is [System.Array]) 'an empty text gives an array'
Eq 0 (@($empty).Count) 'an empty text has no sentences'

$blank = Split-Sentence '     '
Eq 0 (@($blank).Count) 'whitespace only has no sentences'

$one = Split-Sentence 'Only one.'
Ok ($one -is [System.Array]) 'a single sentence still comes back as an array'
Eq 1 (@($one).Count) 'single sentence count'
Eq 'Only one.' $one[0] 'single sentence text'

$noSpace = Split-Sentence 'Hi.There'
Eq 1 (@($noSpace).Count) 'a stop with no following space does not end a sentence'

$multi = Split-Sentence "First line.`nSecond line."
Eq 2 (@($multi).Count) 'a newline after a stop ends a sentence'
Eq '[First line., Second line.]' (Show (@($multi))) 'sentences across lines'

# --- Stat edges ---------------------------------------------------------
$empty = Get-TextStats ''
Eq 0 $empty.Characters 'an empty text has no characters'
Eq 0 $empty.Words 'an empty text has no words'
Eq 0 $empty.Sentences 'an empty text has no sentences'
Eq 0 $empty.AverageWordLength 'an empty text has a zero average'

$single = Get-TextStats 'Hi'
Eq 2 $single.Characters 'two characters'
Eq 1 $single.Words 'one word'
Eq 1 $single.Sentences 'one sentence'
Eq 2 $single.AverageWordLength 'a one-word average'

$rounded = Get-TextStats 'a bb cccc'
Eq 3 $rounded.Words 'three words'
Eq 2.333 $rounded.AverageWordLength 'the average rounds to three decimals'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
