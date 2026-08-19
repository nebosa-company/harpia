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
. (Ws 'Parse-Fields.ps1')

[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

Eq $null (ConvertFrom-InvariantNumber '') 'empty string is not a number'
Eq $null (ConvertFrom-InvariantNumber '   ') 'whitespace is not a number'
Eq $null (ConvertFrom-InvariantNumber 'abc') 'letters are not a number'
Eq $null (ConvertFrom-InvariantNumber '12 34') 'an embedded space is not a number'
Eq 42 (ConvertFrom-InvariantNumber '  42  ') 'surrounding whitespace is trimmed'
Eq 1000 (ConvertFrom-InvariantNumber '1e3') 'exponent notation'
Eq 5 (ConvertFrom-InvariantNumber '+5') 'leading plus sign'
Eq 0.5 (ConvertFrom-InvariantNumber '0.5') 'sub-unit value'
Eq 0 (ConvertFrom-InvariantNumber '0') 'zero is a number, not a blank'

Eq $null (ConvertFrom-InvariantDate '') 'empty string is not a date'
Eq $null (ConvertFrom-InvariantDate '   ') 'whitespace is not a date'
Eq $null (ConvertFrom-InvariantDate '2026-02-30') 'the 30th of February does not exist'
Eq $null (ConvertFrom-InvariantDate '2026-13-01') 'month 13 does not exist'
Eq $null (ConvertFrom-InvariantDate '3/5/2026') 'day and month must be zero padded'
Eq $null (ConvertFrom-InvariantDate '05.03.2026') 'dotted dates are not in the accepted set'
Eq $null (ConvertFrom-InvariantDate 'March 5, 2026') 'long dates are not in the accepted set'
Eq $null (ConvertFrom-InvariantDate '2026-02-29') '2026 is not a leap year'
Eq ([datetime]::new(2024, 2, 29)) (ConvertFrom-InvariantDate '2024-02-29') '2024 is a leap year'
Eq ([datetime]::new(2026, 12, 31, 23, 59, 59)) (ConvertFrom-InvariantDate '2026-12-31 23:59:59') 'end of year'
Eq ([datetime]::new(2026, 3, 5)) (ConvertFrom-InvariantDate '  2026-03-05  ') 'surrounding whitespace is trimmed'

Eq '0' (Format-InvariantNumber 0 0) 'zero decimals'
Eq '-3.5' (Format-InvariantNumber -3.456 1) 'negative value, one decimal'
Eq '0.00' (Format-InvariantNumber 0.0 2) 'zero renders padded'
Eq '1234.50' (Format-InvariantNumber 1234.5) 'two decimals is the default'
Ok ($null -ne (Throws { Format-InvariantNumber 1 12 })) 'more than nine decimals is rejected'
Ok ($null -ne (Throws { Format-InvariantNumber 1 -1 })) 'a negative precision is rejected'

$one = Work 'one.csv'
WriteLines $one @('Id,Taken,Value', 'R-9,2026-04-01,3.25')
$r = Read-InvariantRecords $one
Ok ($r -is [object[]]) 'a one-row export must still be object[]'
Eq 1 (@($r).Count) 'one-row count'
Eq 3.25 $r[0].Value 'one-row value'

$none = Work 'none.csv'
WriteLines $none @('Id,Taken,Value')
$e = Read-InvariantRecords $none
Ok ($null -ne $e) 'a header-only export must not return null'
Ok ($e -is [object[]]) 'a header-only export must return object[]'
Eq 0 (@($e).Count) 'header-only count'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
