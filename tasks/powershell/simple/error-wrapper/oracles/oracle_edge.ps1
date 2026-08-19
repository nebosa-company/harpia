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
. (Ws 'Invoke-Safely.ps1')
$ErrorActionPreference = 'Continue'

# A block that emits nothing.
$r = Invoke-Safely { $null = 1 + 1 }
Eq $true $r.Succeeded 'a silent block succeeds'
Ok ($null -ne $r.Output) 'a silent block still has an Output'
Ok ($r.Output -is [object[]]) 'a silent block gives object[]'
Eq 0 (@($r.Output).Count) 'a silent block emits nothing'

# A block emitting exactly one value: still a list.
$r = Invoke-Safely { 42 }
Ok ($r.Output -is [object[]]) 'a one-value block gives object[]'
Eq 1 (@($r.Output).Count) 'a one-value block has one entry'
Eq 42 $r.Output[0] 'indexing the single value'

# A cmdlet failure that is non-terminating by default.
$missing = Join-Path (WorkRoot) 'definitely-not-here.txt'
$r = Invoke-Safely { Get-Item -LiteralPath $missing }
Eq $false $r.Succeeded 'a missing file is a failure'
Ok (-not [string]::IsNullOrWhiteSpace([string]$r.ErrorMessage)) 'the cmdlet error carries a message'

# Division by zero.
$r = Invoke-Safely { 1 / 0 }
Eq $false $r.Succeeded 'division by zero is a failure'
Ok (-not [string]::IsNullOrWhiteSpace([string]$r.ErrorMessage)) 'division by zero carries a message'

# The caller's preferences are left alone.
$ErrorActionPreference = 'SilentlyContinue'
$null = Invoke-Safely { throw 'x' }
Eq 'SilentlyContinue' $ErrorActionPreference 'the caller ErrorActionPreference is untouched'
$ErrorActionPreference = 'Continue'

# The runner works whatever the caller preference happens to be.
$ErrorActionPreference = 'SilentlyContinue'
$r = Invoke-Safely { throw 'still caught' }
Eq $false $r.Succeeded 'failures are caught under SilentlyContinue too'
Eq 'still caught' $r.ErrorMessage 'the message survives SilentlyContinue'
$ErrorActionPreference = 'Continue'

# An empty step list.
$none = Invoke-AllSafely -ScriptBlock @()
Ok ($null -ne $none) 'an empty step list must not give $null'
Ok ($none -is [object[]]) 'an empty step list gives object[]'
Eq 0 (@($none).Count) 'an empty step list runs nothing'

# A single step.
$one = Invoke-AllSafely -ScriptBlock @({ 'solo' })
Ok ($one -is [object[]]) 'a one-step list gives object[]'
Eq 1 (@($one).Count) 'one-step count'
Eq 'step-1' $one[0].Name 'one-step name'
Eq '[solo]' (Show $one[0].Output) 'one-step output'

# -StopOnError with no failures runs everything.
$clean = Invoke-AllSafely -ScriptBlock @({ 1 }, { 2 }, { 3 }) -StopOnError
Eq 3 (@($clean).Count) '-StopOnError runs every step when none fail'
Eq '[True, True, True]' (Show (@($clean | ForEach-Object { $_.Succeeded }))) '-StopOnError clean outcomes'

# -StopOnError when the very first step fails.
$firstBad = Invoke-AllSafely -ScriptBlock @({ throw 'a' }, { 'b' }) -StopOnError
Eq 1 (@($firstBad).Count) '-StopOnError stops immediately on a first-step failure'
Eq 'step-1' $firstBad[0].Name 'the failing first step is reported'

# Steps see values from the scope they were written in.
$captured = 'from the caller'
$r = Invoke-Safely { $captured }
Eq $true $r.Succeeded 'a block reading a caller variable succeeds'
Eq '[from the caller]' (Show $r.Output) 'a block reads the scope it was written in'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
