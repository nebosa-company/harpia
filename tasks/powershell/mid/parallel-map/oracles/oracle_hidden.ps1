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
. (Ws 'Invoke-ParallelMap.ps1')

# A straightforward map over eight items.
$items = 1..8
$r = Invoke-ParallelMap $items { $_ * 10 }
Ok ($r -is [object[]]) 'Invoke-ParallelMap must return object[]'
Eq 8 (@($r).Count) 'one record per item'
Eq '[Index, Input, Success, Result, Error]' (Show (@($r[0].PSObject.Properties.Name))) 'property names and order'
Eq '[0, 1, 2, 3, 4, 5, 6, 7]' (Show (@($r | ForEach-Object { $_.Index }))) 'indexes are input order'
Eq '[1, 2, 3, 4, 5, 6, 7, 8]' (Show (@($r | ForEach-Object { $_.Input }))) 'inputs are echoed in order'
Eq '[10, 20, 30, 40, 50, 60, 70, 80]' (Show (@($r | ForEach-Object { $_.Result }))) 'results line up with the inputs'
Eq '[True, True, True, True, True, True, True, True]' (Show (@($r | ForEach-Object { $_.Success }))) 'every item succeeded'
Eq '[<null>, <null>, <null>, <null>, <null>, <null>, <null>, <null>]' (Show (@($r | ForEach-Object { $_.Error }))) 'no errors'
Ok ($r[0].Index -is [int]) 'Index is Int32'
Ok ($r[0].Success -is [bool]) 'Success is a Boolean'

# One bad item does not take the batch down.
$mixed = Invoke-ParallelMap @(1, 2, 3, 4) { if ($_ -eq 3) { throw 'item three is bad' } ; $_ + 100 }
Eq 4 (@($mixed).Count) 'every item is still reported'
Eq '[True, True, False, True]' (Show (@($mixed | ForEach-Object { $_.Success }))) 'only the bad item failed'
Eq '[101, 102, <null>, 104]' (Show (@($mixed | ForEach-Object { $_.Result }))) 'the failed item has no result'
Eq 'item three is bad' $mixed[2].Error 'the failure message is reported'
Eq $null $mixed[0].Error 'a successful item has no error'
Eq 3 $mixed[2].Input 'the failed item echoes its input'

# Strings and objects pass through unharmed, and order is preserved even
# when the work finishes out of order.
$words = @('delta', 'alpha', 'charlie', 'bravo', 'echo', 'foxtrot')
$upper = Invoke-ParallelMap $words { $_.ToUpperInvariant() } 3
Eq '[delta, alpha, charlie, bravo, echo, foxtrot]' (Show (@($upper | ForEach-Object { $_.Input }))) 'input order is preserved'
Eq '[DELTA, ALPHA, CHARLIE, BRAVO, ECHO, FOXTROT]' (Show (@($upper | ForEach-Object { $_.Result }))) 'results stay aligned with their inputs'
Eq '[0, 1, 2, 3, 4, 5]' (Show (@($upper | ForEach-Object { $_.Index }))) 'indexes stay in order'

# A block that emits several values collects them all.
$multi = Invoke-ParallelMap @('x') { $_; $_; 'extra' }
Eq 1 (@($multi).Count) 'one record for one item'
Ok ($multi[0].Result -is [object[]]) 'several emitted values come back as an array'
Eq '[x, x, extra]' (Show $multi[0].Result) 'every emitted value is kept, in order'

# A block that emits nothing.
$silent = Invoke-ParallelMap @('x') { $null = 1 }
Eq $true $silent[0].Success 'a silent block still succeeds'
Eq $null $silent[0].Result 'a silent block has no result'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
