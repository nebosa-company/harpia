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

$m = Merge-JsonConfig -BasePath (Ws 'config\base.json') -OverridePath (Ws 'config\prod.json')

Ok ($m -is [System.Management.Automation.PSCustomObject]) 'the merge result is a PSCustomObject'
Eq '[name, retries, verbose, server, tags, region]' (Show (@($m.PSObject.Properties.Name))) 'top-level key order'

Eq 'reporting' $m.name 'base-only key survives'
Eq 0 $m.retries 'a zero in the override really overrides'
Eq $false $m.verbose 'a false in the override really overrides'
Eq 'eu-west' $m.region 'an override-only key is added'
Ok (-not (@($m.PSObject.Properties.Name) -contains 'legacyMode')) 'a null in the override removes the key'

Eq '[host, port, tls]' (Show (@($m.server.PSObject.Properties.Name))) 'nested key order'
Eq 'reports.internal' $m.server.host 'nested scalar override'
Eq 8080 $m.server.port 'nested base-only key survives'
Eq '[enabled, ca]' (Show (@($m.server.tls.PSObject.Properties.Name))) 'doubly nested key order'
Eq $true $m.server.tls.enabled 'doubly nested override'
Eq 'dev.pem' $m.server.tls.ca 'doubly nested base-only key survives'

Ok ($m.tags -is [System.Array]) 'a merged list is still a list'
Eq '[prod]' (Show (@($m.tags))) 'lists are replaced, not concatenated'

# The base file must not have been mutated in place.
$again = Merge-JsonConfig -BasePath (Ws 'config\base.json') -OverridePath (Ws 'config\base.json')
Eq 3 $again.retries 'merging base over base leaves the base values'
Eq '[a, b]' (Show (@($again.tags))) 'the base list is untouched by the earlier merge'

# Round-trip through disk.
$out = Work 'merged.json'
Save-MergedConfig -Config $m -Path $out
Ok (Test-Path -LiteralPath $out) 'Save-MergedConfig writes the file'
$bytes = [System.IO.File]::ReadAllBytes($out)
Ok (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'the saved file has no byte-order mark'
$text = ReadText $out
Ok (-not $text.Contains("`r")) 'the saved file uses LF line endings'
Ok ($text.EndsWith("`n")) 'the saved file ends with a newline'
Ok (-not $text.EndsWith("`n`n")) 'the saved file ends with exactly one newline'

$reloaded = $text | ConvertFrom-Json
Eq 'reports.internal' $reloaded.server.host 'the saved file round-trips'
Eq $false $reloaded.verbose 'false survives the round-trip'
Eq 0 $reloaded.retries 'zero survives the round-trip'
Eq '[prod]' (Show (@($reloaded.tags))) 'the list survives the round-trip'
Ok (-not (@($reloaded.PSObject.Properties.Name) -contains 'legacyMode')) 'the removed key stays removed'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
