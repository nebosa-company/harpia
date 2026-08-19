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

# A block that succeeds.
$r = Invoke-Safely -ScriptBlock { 'alpha' } -Name 'first'
Eq '[Name, Succeeded, Output, ErrorMessage, ErrorType]' (Show (@($r.PSObject.Properties.Name))) 'property names and order'
Eq 'first' $r.Name 'name is echoed back'
Eq $true $r.Succeeded 'a clean block succeeds'
Ok ($r.Succeeded -is [bool]) 'Succeeded is a Boolean'
Ok ($r.Output -is [object[]]) 'Output is object[]'
Eq '[alpha]' (Show $r.Output) 'single emitted value'
Eq $null $r.ErrorMessage 'no message on success'
Eq $null $r.ErrorType 'no type on success'

# Several emitted values keep their order.
$r = Invoke-Safely { 1; 2; 3 }
Eq 'unnamed' $r.Name 'the default name'
Eq '[1, 2, 3]' (Show $r.Output) 'emitted values in order'
Eq 3 (@($r.Output).Count) 'emitted value count'

# A thrown string.
$r = Invoke-Safely -ScriptBlock { throw 'boom' } -Name 'thrower'
Eq $false $r.Succeeded 'a throwing block fails'
Eq 'boom' $r.ErrorMessage 'the thrown message is reported'
Ok ($r.Output -is [object[]]) 'Output is object[] even on failure'
Eq 0 (@($r.Output).Count) 'Output is empty on failure'
Eq 'thrower' $r.Name 'the name survives a failure'

# A thrown typed exception.
$r = Invoke-Safely { throw [System.InvalidOperationException]::new('bad state') }
Eq $false $r.Succeeded 'a typed throw fails'
Eq 'bad state' $r.ErrorMessage 'the typed message is reported'
Eq 'System.InvalidOperationException' $r.ErrorType 'the exception type is reported'

# A non-terminating error is still a failure.
$r = Invoke-Safely { Write-Error 'soft failure' }
Eq $false $r.Succeeded 'a non-terminating error is a failure'
Ok ($null -ne $r.ErrorMessage) 'a non-terminating error carries a message'
Ok ($r.ErrorMessage -like '*soft failure*') 'the non-terminating message is reported'
Ok (-not [string]::IsNullOrWhiteSpace([string]$r.ErrorType)) 'a non-terminating error carries a type'

# Output that follows a non-terminating error does not make the step green.
$r = Invoke-Safely { Write-Error 'first went wrong'; 'kept going' }
Eq $false $r.Succeeded 'emitting after an error is still a failure'
Eq 0 (@($r.Output).Count) 'no output is reported for a failed step'

# The runner never throws.
$r = Invoke-Safely { throw 'nope' }
Ok ($null -ne $r) 'the runner returns a record instead of throwing'

# Running a list of steps.
$steps = @({ 'a' }, { throw 'stop here' }, { 'c' })
$all = Invoke-AllSafely -ScriptBlock $steps
Ok ($all -is [object[]]) 'Invoke-AllSafely returns object[]'
Eq 3 (@($all).Count) 'every step runs by default'
Eq '[step-1, step-2, step-3]' (Show (@($all | ForEach-Object { $_.Name }))) 'default step names'
Eq '[True, False, True]' (Show (@($all | ForEach-Object { $_.Succeeded }))) 'per-step outcomes'
Eq 'stop here' $all[1].ErrorMessage 'the failing step carries its message'
Eq '[c]' (Show $all[2].Output) 'later steps still run'

$stopped = Invoke-AllSafely -ScriptBlock $steps -StopOnError
Eq 2 (@($stopped).Count) '-StopOnError stops after the first failure'
Eq '[True, False]' (Show (@($stopped | ForEach-Object { $_.Succeeded }))) '-StopOnError outcomes'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
