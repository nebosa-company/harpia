$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = $inv
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $inv

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

try {
    . (Join-Path $PSScriptRoot 'Invoke-SalesReport.ps1')

    $csv = Join-Path $PSScriptRoot 'data\sales.csv'
    $r = Get-SalesReport -Path $csv

    Ok ($r -is [object[]]) 'Get-SalesReport must return object[]'
    Eq 3 (@($r).Count) 'region count'

    Eq 'South' $r[0].Region 'row 0 region'
    Eq 3 $r[0].Orders 'row 0 orders'
    Eq 10 $r[0].Units 'row 0 units'
    Eq 762.47 $r[0].Revenue 'row 0 revenue'

    Eq 'North' $r[1].Region 'row 1 region'
    Eq 3 $r[1].Orders 'row 1 orders'
    Eq 16 $r[1].Units 'row 1 units'
    Eq 250 $r[1].Revenue 'row 1 revenue'

    Eq 'East' $r[2].Region 'row 2 region'
    Eq 2 $r[2].Orders 'row 2 orders'
    Eq 12 $r[2].Units 'row 2 units'
    Eq 103.75 $r[2].Revenue 'row 2 revenue'

    Ok ($r[0].Orders -is [int]) 'Orders is Int32'
    Ok ($r[0].Units -is [int]) 'Units is Int32'
    Ok ($r[0].Revenue -is [double]) 'Revenue is Double'

    $names = @($r[0].PSObject.Properties.Name)
    Eq '[Region, Orders, Units, Revenue]' (Show $names) 'property names and order'

    $filtered = Get-SalesReport -Path $csv -MinRevenue 200
    Ok ($filtered -is [object[]]) 'filtered result is object[]'
    Eq 2 (@($filtered).Count) 'filtered region count'
    Eq 'South' $filtered[0].Region 'filtered row 0'
    Eq 'North' $filtered[1].Region 'filtered row 1'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
