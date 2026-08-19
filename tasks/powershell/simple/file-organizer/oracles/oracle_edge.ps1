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
. (Ws 'Move-ByExtension.ps1')

function Snap([string]$root) {
    $items = @(Get-ChildItem -LiteralPath $root -Recurse -Force | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\')
        if ($_.PSIsContainer) { "D:$rel" } else { "F:$rel=" + (ReadText $_.FullName) }
    })
    return ((@($items) | Sort-Object -CaseSensitive) -join '|')
}

Ok ((Get-Command Invoke-FileOrganizer).Parameters.ContainsKey('WhatIf')) 'the function must support -WhatIf'
Ok ((Get-Command Invoke-FileOrganizer).Parameters.ContainsKey('Confirm')) 'the function must support -Confirm'

# -WhatIf must leave the tree byte-for-byte identical.
$root = FreshDir (Work 'tree2')
WriteText (Join-Path $root 'a.txt') 'alpha'
WriteText (Join-Path $root 'b.log') 'bravo'
$before = Snap $root
$plan = Invoke-FileOrganizer -Root $root -WhatIf
$after = Snap $root
Eq $before $after '-WhatIf must not change anything on disk'
Ok ($plan -is [object[]]) '-WhatIf still returns object[]'
Eq 2 (@($plan).Count) '-WhatIf plan length'
Eq '[planned, planned]' (Show (@($plan | ForEach-Object { $_.Status }))) '-WhatIf status'
Eq '[False, False]' (Show (@($plan | ForEach-Object { $_.Moved }))) '-WhatIf Moved flags'
Eq 'txt\a.txt' $plan[0].Destination '-WhatIf still reports the destination'

# One loose file: still an array.
$single = FreshDir (Work 'tree3')
WriteText (Join-Path $single 'only.md') 'solo'
$s = Invoke-FileOrganizer -Root $single
Ok ($s -is [object[]]) 'a one-file root must still return object[]'
Eq 1 (@($s).Count) 'one-file count'
Eq 'md' $s[0].Bucket 'one-file bucket'

# No loose files at all: an empty array, never $null.
$bare = FreshDir (Work 'tree4')
New-Item -ItemType Directory -Path (Join-Path $bare 'only-a-dir') | Out-Null
$b = Invoke-FileOrganizer -Root $bare
Ok ($null -ne $b) 'an empty root must not return null'
Ok ($b -is [object[]]) 'an empty root must return object[]'
Eq 0 (@($b).Count) 'empty root count'

# A name whose only dot is the first character has no extension.
$dotted = FreshDir (Work 'tree5')
WriteText (Join-Path $dotted '.env') 'SECRET='
WriteText (Join-Path $dotted 'x.tar.gz') 'blob'
$d = Invoke-FileOrganizer -Root $dotted
Eq '[.env, x.tar.gz]' (Show (@($d | ForEach-Object { $_.Name }))) 'dotfiles are candidates too'
Eq 'other' $d[0].Bucket 'a leading-dot name goes to other'
Eq 'gz' $d[1].Bucket 'only the last extension segment names the bucket'
Ok (Test-Path -LiteralPath (Join-Path $dotted 'other\.env')) 'dotfile filed under other'

# An occupied destination is a conflict, not an overwrite and not a crash.
$clash = FreshDir (Work 'tree6')
WriteText (Join-Path $clash 'dup.txt') 'new'
WriteText (Join-Path $clash 'txt\dup.txt') 'old'
$c = Invoke-FileOrganizer -Root $clash
Eq 1 (@($c).Count) 'conflict plan length'
Eq 'conflict' $c[0].Status 'occupied destination reports conflict'
Eq $false $c[0].Moved 'conflicting file is not moved'
Eq 'old' (ReadText (Join-Path $clash 'txt\dup.txt')) 'the existing file is not overwritten'
Eq 'new' (ReadText (Join-Path $clash 'dup.txt')) 'the loose file stays put'

# An existing bucket directory is reused without complaint.
$reuse = FreshDir (Work 'tree7')
New-Item -ItemType Directory -Path (Join-Path $reuse 'txt') | Out-Null
WriteText (Join-Path $reuse 'later.txt') 'ok'
$u = Invoke-FileOrganizer -Root $reuse
Eq 'moved' $u[0].Status 'existing bucket directory is reused'
Ok (Test-Path -LiteralPath (Join-Path $reuse 'txt\later.txt')) 'file landed in the existing bucket'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
