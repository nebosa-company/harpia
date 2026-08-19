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

# Run every assertion under a comma-decimal ambient culture: correct code
# pins the invariant culture and does not care.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

Eq 1234.56 (ConvertFrom-InvariantNumber '1234.56') 'dot is the decimal point'
Eq 1234.56 (ConvertFrom-InvariantNumber '1,234.56') 'comma is a thousands separator'
Eq -7.5 (ConvertFrom-InvariantNumber '-7.5') 'negative number'
Eq $null (ConvertFrom-InvariantNumber '1.234,56') 'a comma-decimal literal is not invariant'
Ok ((ConvertFrom-InvariantNumber '1234.56') -is [double]) 'numbers come back as Double'

Eq ([datetime]::new(2026, 3, 5)) (ConvertFrom-InvariantDate '2026-03-05') 'yyyy-MM-dd'
Eq ([datetime]::new(2026, 3, 5, 8, 15, 0)) (ConvertFrom-InvariantDate '2026-03-05 08:15:00') 'yyyy-MM-dd HH:mm:ss'
Eq ([datetime]::new(2026, 3, 5)) (ConvertFrom-InvariantDate '05/03/2026') 'dd/MM/yyyy is day first'
Eq ([datetime]::new(2026, 3, 5, 14, 30, 0)) (ConvertFrom-InvariantDate '05/03/2026 14:30') 'dd/MM/yyyy HH:mm'
Eq 'Unspecified' ((ConvertFrom-InvariantDate '2026-03-05').Kind.ToString()) 'DateTimeKind is Unspecified'

Eq '1234.50' (Format-InvariantNumber 1234.5 2) 'rendering uses a dot'
Eq '1234.57' (Format-InvariantNumber 1234.567 2) 'rendering rounds to the requested precision'
Eq '1234.5670' (Format-InvariantNumber 1234.567 4) 'rendering pads to the requested precision'
Ok ((Format-InvariantNumber 1234.5 2) -is [string]) 'the rendering is a string'

$recs = Read-InvariantRecords (Ws 'data\readings.csv')
Ok ($recs -is [object[]]) 'Read-InvariantRecords must return object[]'
Eq 6 (@($recs).Count) 'record count'
Eq '[Id, Taken, Value, Valid]' (Show (@($recs[0].PSObject.Properties.Name))) 'property names and order'

Eq '[R-1, R-2, R-3, R-4, R-5, R-6]' (Show (@($recs | ForEach-Object { $_.Id }))) 'ids in file order'
Eq '[True, True, True, False, False, False]' (Show (@($recs | ForEach-Object { $_.Valid }))) 'validity per row'

Eq ([datetime]::new(2026, 3, 5)) $recs[0].Taken 'R-1 timestamp'
Eq 1234.56 $recs[0].Value 'R-1 value'
Eq ([datetime]::new(2026, 3, 5, 14, 30, 0)) $recs[1].Taken 'R-2 timestamp'
Eq -7.5 $recs[1].Value 'R-2 value'
Eq ([datetime]::new(2026, 3, 5, 8, 15, 0)) $recs[2].Taken 'R-3 timestamp'
Eq 1234.75 $recs[2].Value 'R-3 value with a thousands separator'

Eq $null $recs[3].Taken 'an unparsable date blanks the timestamp'
Eq $null $recs[3].Value 'an unparsable date blanks the value too'
Eq $null $recs[4].Taken 'the 30th of February is not a date'
Eq $null $recs[5].Value 'a comma-decimal value is rejected'
Eq $null $recs[5].Taken 'a rejected value blanks the timestamp too'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
