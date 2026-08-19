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
. (Ws 'Merge-Config.ps1')

function Merged([string]$baseJson, [string]$overJson) {
    $b = Work 'edge-base.json'
    $o = Work 'edge-over.json'
    WriteText $b $baseJson
    WriteText $o $overJson
    return (Merge-JsonConfig -BasePath $b -OverridePath $o)
}

# An empty override changes nothing at all.
$m = Merged '{"a":1,"b":{"c":2},"d":[1,2]}' '{}'
Eq '[a, b, d]' (Show (@($m.PSObject.Properties.Name))) 'empty override keeps every key'
Eq 1 $m.a 'empty override keeps scalars'
Eq 2 $m.b.c 'empty override keeps nested values'
Eq '[1, 2]' (Show (@($m.d))) 'empty override keeps lists'

# Falsy overrides are real values.
$m = Merged '{"flag":true,"count":7,"label":"x"}' '{"flag":false,"count":0,"label":""}'
Eq $false $m.flag 'false overrides true'
Eq 0 $m.count 'zero overrides seven'
Eq '' $m.label 'the empty string overrides a value'

# A null removes a nested key, and only that key.
$m = Merged '{"s":{"keep":1,"drop":2}}' '{"s":{"drop":null}}'
Eq '[keep]' (Show (@($m.s.PSObject.Properties.Name))) 'null removes a nested key'
Eq 1 $m.s.keep 'its siblings survive'

# A null for a key the base does not have is simply absent.
$m = Merged '{"a":1}' '{"b":null}'
Eq '[a]' (Show (@($m.PSObject.Properties.Name))) 'a null for an unknown key adds nothing'

# Shape changes replace outright.
$m = Merged '{"x":{"deep":1}}' '{"x":"flat"}'
Eq 'flat' $m.x 'an object is replaced by a scalar'
$m = Merged '{"x":"flat"}' '{"x":{"deep":1}}'
Eq 1 $m.x.deep 'a scalar is replaced by an object'
$m = Merged '{"x":{"deep":1}}' '{"x":[1,2,3]}'
Ok ($m.x -is [System.Array]) 'an object is replaced by a list'
Eq '[1, 2, 3]' (Show (@($m.x))) 'the replacing list is intact'

# A single-element list stays a list.
$m = Merged '{"tags":["a","b","c"]}' '{"tags":["only"]}'
Ok ($m.tags -is [System.Array]) 'a one-element list is still a list'
Eq 1 (@($m.tags).Count) 'one-element list length'

# An empty list replaces a populated one.
$m = Merged '{"tags":["a","b"]}' '{"tags":[]}'
Ok ($m.tags -is [System.Array]) 'an empty list is still a list'
Eq 0 (@($m.tags).Count) 'an empty list clears the base list'

# Override-only keys keep their own order and land after the base keys.
$m = Merged '{"b":1,"a":2}' '{"z":3,"y":4}'
Eq '[b, a, z, y]' (Show (@($m.PSObject.Properties.Name))) 'base order first, then override order'

# Deeply nested merge, three levels down.
$m = Merged '{"a":{"b":{"c":{"d":1,"e":2}}}}' '{"a":{"b":{"c":{"e":9,"f":10}}}}'
Eq 1 $m.a.b.c.d 'three levels down, base survives'
Eq 9 $m.a.b.c.e 'three levels down, override applies'
Eq 10 $m.a.b.c.f 'three levels down, new key added'

# Saving creates missing directories and stays parseable.
$deep = Work 'a\b\c\out.json'
Save-MergedConfig -Config $m -Path $deep
Ok (Test-Path -LiteralPath $deep) 'Save-MergedConfig creates missing directories'
$back = (ReadText $deep) | ConvertFrom-Json
Eq 10 $back.a.b.c.f 'deeply nested values survive the save'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
