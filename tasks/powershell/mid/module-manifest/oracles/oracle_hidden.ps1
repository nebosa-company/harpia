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

Import-Module $manifestPath -Force -ErrorAction Stop
$module = Get-Module TextKit
Ok ($null -ne $module) 'the module imports by manifest path'
Eq '1.2.0' $module.Version.ToString() 'the module version'

$exported = @($module.ExportedFunctions.Keys | Sort-Object)
Eq '[ConvertTo-SlugText, Get-TextStats, Split-Sentence]' (Show $exported) 'exactly three exported functions'
Eq '[slug]' (Show (@($module.ExportedAliases.Keys))) 'the slug alias is exported'
Eq 0 (@($module.ExportedCmdlets.Keys).Count) 'no cmdlets are exported'
Eq 0 (@($module.ExportedVariables.Keys).Count) 'no variables are exported'

# --- ConvertTo-SlugText -------------------------------------------------
Eq 'hello-world' (ConvertTo-SlugText 'Hello, World!') 'a plain slug'
Eq 'hello-world' (ConvertTo-SlugText '  Hello,   World!  ') 'surrounding and inner whitespace collapse'
Eq 'c-net-8' (ConvertTo-SlugText 'C# & .NET 8') 'punctuation runs become one dash'
Eq 'allcaps' (ConvertTo-SlugText 'ALLCAPS') 'case is folded'
Eq 'release-1-2-0' (ConvertTo-SlugText 'Release 1.2.0') 'digits survive'
Eq 'hello' (ConvertTo-SlugText 'Hello, World!' 5) 'a length limit truncates'
Eq 'hello' (ConvertTo-SlugText 'Hello, World!' 6) 'truncation never leaves a trailing dash'
Eq 'hello-world' (ConvertTo-SlugText 'Hello, World!' 0) 'a zero limit means no limit'
Eq 'hello-world' (ConvertTo-SlugText 'Hello, World!' 99) 'a limit past the end changes nothing'
Ok ((ConvertTo-SlugText 'x') -is [string]) 'the slug is a string'

# The alias reaches the same function.
Eq 'hello-world' (slug 'Hello, World!') 'the alias works'

# --- Split-Sentence -----------------------------------------------------
$s = Split-Sentence 'One. Two! Three?'
Ok ($s -is [System.Array]) 'Split-Sentence returns an array'
Eq 3 (@($s).Count) 'three sentences'
Eq '[One., Two!, Three?]' (Show (@($s))) 'sentences keep their punctuation'

$s = Split-Sentence 'A...  B.'
Eq '[A..., B.]' (Show (@($s))) 'a run of stops ends one sentence'

$s = Split-Sentence 'Hello world'
Eq 1 (@($s).Count) 'text with no terminator is one sentence'
Eq 'Hello world' $s[0] 'the unterminated sentence is intact'

# --- Get-TextStats ------------------------------------------------------
$stats = Get-TextStats 'Hello, world! How are you?'
Eq '[Characters, Words, Sentences, AverageWordLength]' (Show (@($stats.PSObject.Properties.Name))) 'stat property names and order'
Eq 26 $stats.Characters 'character count'
Eq 5 $stats.Words 'word count'
Eq 2 $stats.Sentences 'sentence count'
Eq 3.8 $stats.AverageWordLength 'average word length'
Ok ($stats.Characters -is [int]) 'Characters is Int32'
Ok ($stats.Words -is [int]) 'Words is Int32'
Ok ($stats.Sentences -is [int]) 'Sentences is Int32'
Ok ($stats.AverageWordLength -is [double]) 'AverageWordLength is Double'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
