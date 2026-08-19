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

# The work really is spread across workers rather than run in a loop.
$source = ReadText (Ws 'Invoke-ParallelMap.ps1')
$parallelish = ($source -match '(?i)-Parallel\b') -or
               ($source -match '(?i)runspacefactory') -or
               ($source -match '(?i)runspacepool') -or
               ($source -match '(?i)Start-ThreadJob') -or
               ($source -match '(?i)Start-Job')
Ok ($parallelish) 'the mapper runs its items on more than one worker'

# The throttle is validated by the parameter itself.
Ok ($null -ne (Throws { Invoke-ParallelMap @(1) { $_ } 0 })) 'a throttle of zero is refused'
Ok ($null -ne (Throws { Invoke-ParallelMap @(1) { $_ } -1 })) 'a negative throttle is refused'
Ok ($null -ne (Throws { Invoke-ParallelMap @(1) { $_ } 999 })) 'an absurd throttle is refused'
Ok ($null -eq (Throws { Invoke-ParallelMap @(1) { $_ } 1 })) 'a throttle of one is allowed'
Ok ($null -eq (Throws { Invoke-ParallelMap @(1) { $_ } 64 })) 'a throttle of sixty four is allowed'

# An empty batch.
$none = Invoke-ParallelMap @() { $_ }
Ok ($null -ne $none) 'an empty batch must not return null'
Ok ($none -is [object[]]) 'an empty batch returns object[]'
Eq 0 (@($none).Count) 'an empty batch has no records'

# A single item.
$one = Invoke-ParallelMap @('solo') { $_.Length }
Ok ($one -is [object[]]) 'a one-item batch returns object[]'
Eq 1 (@($one).Count) 'one-item count'
Eq 0 $one[0].Index 'one-item index'
Eq 'solo' $one[0].Input 'one-item input'
Eq 4 $one[0].Result 'one-item result'
Eq $true $one[0].Success 'one-item success'

# Every item failing.
$allBad = Invoke-ParallelMap @(1, 2) { throw "no good: $_" }
Eq 2 (@($allBad).Count) 'a batch where everything fails still reports everything'
Eq '[False, False]' (Show (@($allBad | ForEach-Object { $_.Success }))) 'both items failed'
Eq 'no good: 1' $allBad[0].Error 'the first failure message'
Eq 'no good: 2' $allBad[1].Error 'the second failure message'

# A block that writes to the error stream without throwing.
$soft = Invoke-ParallelMap @('a') { Write-Error 'soft trouble' }
Eq $false $soft[0].Success 'writing to the error stream is a failure'
Ok ($soft[0].Error -like '*soft trouble*') 'the soft failure message is reported'

# Throttling below the batch size still covers every item.
$narrow = Invoke-ParallelMap (1..6) { $_ + 1 } 1
Eq 6 (@($narrow).Count) 'a throttle of one still processes everything'
Eq '[2, 3, 4, 5, 6, 7]' (Show (@($narrow | ForEach-Object { $_.Result }))) 'a throttle of one keeps the order'

# Leaving the throttle out works and still covers the whole batch.
$defaulted = Invoke-ParallelMap (1..10) { $_ * $_ }
Eq 10 (@($defaulted).Count) 'the default throttle still processes everything'
Eq '[1, 4, 9, 16, 25, 36, 49, 64, 81, 100]' (Show (@($defaulted | ForEach-Object { $_.Result }))) 'the default throttle keeps the order'

# Items of mixed types keep their own shapes.
$mixedTypes = Invoke-ParallelMap @(1, 'two', 3.5) { "$_" }
Eq 3 (@($mixedTypes).Count) 'mixed item types are all processed'
Eq '[1, two, 3.5]' (Show (@($mixedTypes | ForEach-Object { $_.Result }))) 'mixed item types round trip'
Eq '[True, True, True]' (Show (@($mixedTypes | ForEach-Object { $_.Success }))) 'mixed item types all succeed'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
