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

function New-Fixture([string]$Name, [string[]]$Lines) {
    $dir = Join-Path $PSScriptRoot '.oracle-work'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $p = Join-Path $dir $Name
    Set-Content -LiteralPath $p -Value ($Lines -join "`n") -Encoding utf8NoBOM
    return $p
}

try {
    . (Join-Path $PSScriptRoot 'Invoke-SalesReport.ps1')

    # A single region must still come back as an array, not a bare record.
    $one = New-Fixture 'one.csv' @(
        'Region,Product,Units,UnitPrice,OrderDate',
        'West,Alpha,3,33.333,2026-02-01'
    )
    $r = Get-SalesReport -Path $one
    Ok ($r -is [object[]]) 'single-group result must still be object[]'
    Eq 1 (@($r).Count) 'single-group count'
    Eq 'West' $r[0].Region 'single-group region'
    Eq 100 $r[0].Revenue 'single-group revenue is rounded to 2 decimals'

    # Header-only file: an empty array, never $null.
    $empty = New-Fixture 'empty.csv' @('Region,Product,Units,UnitPrice,OrderDate')
    $e = Get-SalesReport -Path $empty
    Ok ($null -ne $e) 'empty input must not return null'
    Ok ($e -is [object[]]) 'empty input must return object[]'
    Eq 0 (@($e).Count) 'empty input count'

    # Blank numeric cells count as zero but the row is still an order.
    $blanks = New-Fixture 'blanks.csv' @(
        'Region,Product,Units,UnitPrice,OrderDate',
        'West,Alpha,,12.50,2026-02-01',
        'West,Beta,2,10.00,2026-02-02',
        'West,Gamma,4,,2026-02-03'
    )
    $b = Get-SalesReport -Path $blanks
    Eq 1 (@($b).Count) 'blank-cell group count'
    Eq 3 $b[0].Orders 'blank cells still count as orders'
    Eq 6 $b[0].Units 'blank units count as zero'
    Eq 20 $b[0].Revenue 'blank prices count as zero'

    # Surrounding whitespace in numeric cells is tolerated.
    $pad = New-Fixture 'padded.csv' @(
        'Region,Product,Units,UnitPrice,OrderDate',
        'West,Alpha, 4 , 2.50 ,2026-02-01'
    )
    $p = Get-SalesReport -Path $pad
    Eq 4 $p[0].Units 'padded units'
    Eq 10 $p[0].Revenue 'padded price'

    # A filter that excludes everything yields an empty array.
    $none = Get-SalesReport -Path $one -MinRevenue 1000
    Ok ($none -is [object[]]) 'over-filtered result must be object[]'
    Eq 0 (@($none).Count) 'over-filtered count'

    # MinRevenue is inclusive at the boundary.
    $edge = Get-SalesReport -Path $one -MinRevenue 100
    Eq 1 (@($edge).Count) 'MinRevenue is inclusive'

    # Ties on revenue fall back to region name, ascending.
    $ties = New-Fixture 'ties.csv' @(
        'Region,Product,Units,UnitPrice,OrderDate',
        'Zulu,Alpha,1,50.00,2026-02-01',
        'Alpha,Alpha,1,50.00,2026-02-02',
        'Mike,Alpha,1,50.00,2026-02-03'
    )
    $t = Get-SalesReport -Path $ties
    Eq '[Alpha, Mike, Zulu]' (Show (@($t | ForEach-Object { $_.Region }))) 'ties break on region ascending'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
