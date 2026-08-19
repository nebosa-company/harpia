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
$manifestPath = Ws 'modules\ApiKit\ApiKit.psd1'
Ok (Test-Path -LiteralPath $manifestPath) 'the ApiKit manifest exists'
Import-Module $manifestPath -Force -ErrorAction Stop
$module = Get-Module ApiKit
Ok ($null -ne $module) 'the module imports by manifest path'
Eq '[Get-ApiPagedResult, Invoke-ApiRequest, New-ApiClient]' (Show (@($module.ExportedFunctions.Keys | Sort-Object))) 'exactly three exported functions'

$log = [System.Collections.Generic.List[object]]::new()
function Reply([int]$code, $body, $headers) {
    return [pscustomobject]@{ StatusCode = $code; Headers = $headers; Body = $body }
}

# --- The client record ---------------------------------------------------
$client = New-ApiClient 'https://api.internal/v1/' { param($Request) Reply 200 $null $null }
Eq '[BaseUri, Transport, MaxRetries, RetryDelayMs]' (Show (@($client.PSObject.Properties.Name))) 'client property names and order'
Eq 'https://api.internal/v1' $client.BaseUri 'the base URI loses its trailing slash'
Eq 3 $client.MaxRetries 'the default retry count'
Eq 100 $client.RetryDelayMs 'the default back-off unit'
Ok ($client.Transport -is [scriptblock]) 'the transport is kept as a script block'

# --- A request that works the first time --------------------------------
$log.Clear()
$client = New-ApiClient 'https://api.internal/v1' {
    param($Request)
    $log.Add($Request)
    Reply 200 ([pscustomobject]@{ ok = $true }) $null
}
$result = Invoke-ApiRequest $client '/widgets'
Eq '[Success, StatusCode, Body, Attempts, Delays, Error]' (Show (@($result.PSObject.Properties.Name))) 'result property names and order'
Eq $true $result.Success 'a 200 succeeds'
Eq 200 $result.StatusCode 'the status code is reported'
Eq $true $result.Body.ok 'the body is passed through'
Eq 1 $result.Attempts 'one attempt'
Ok ($result.Delays -is [int[]]) 'Delays is Int32[]'
Eq 0 (@($result.Delays).Count) 'no delays on a first-time success'
Eq $null $result.Error 'no error on success'

Eq 1 $log.Count 'the transport was called once'
Eq 'https://api.internal/v1/widgets' $log[0].Uri 'the URI is the base plus the path'
Eq 'GET' $log[0].Method 'GET is the default method'
Eq 1 $log[0].Attempt 'the first attempt is numbered 1'
Eq '[Method, Uri, Body, Headers, Attempt]' (Show (@($log[0].PSObject.Properties.Name))) 'request property names and order'

# The path may be given without a leading slash.
$log.Clear()
$null = Invoke-ApiRequest $client 'widgets'
Eq 'https://api.internal/v1/widgets' $log[0].Uri 'a path without a leading slash still joins cleanly'

# Method, body and headers reach the transport.
$log.Clear()
$null = Invoke-ApiRequest $client '/widgets' 'POST' ([pscustomobject]@{ name = 'w' }) @{ 'X-Trace' = 'abc' }
Eq 'POST' $log[0].Method 'the method reaches the transport'
Eq 'w' $log[0].Body.name 'the body reaches the transport'
Eq 'abc' $log[0].Headers['X-Trace'] 'the headers reach the transport'

# --- Retry on a server error --------------------------------------------
$log.Clear()
$attempt = 0
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    $log.Add($Request)
    if ($Request.Attempt -lt 3) { return Reply 503 $null $null }
    return Reply 200 ([pscustomobject]@{ ok = 'finally' }) $null
}
$result = Invoke-ApiRequest $client '/flaky'
Eq $true $result.Success 'the request eventually succeeds'
Eq 3 $result.Attempts 'three attempts were needed'
Eq 'finally' $result.Body.ok 'the successful body is returned'
Eq '[100, 200]' (Show $result.Delays) 'the back-off doubles between attempts'
Eq '[1, 2, 3]' (Show (@($log | ForEach-Object { $_.Attempt }))) 'the transport sees the attempt number'
Eq $null $result.Error 'a request that eventually works has no error'

# --- Giving up ------------------------------------------------------------
$log.Clear()
$client = New-ApiClient 'https://api.internal' { param($Request) $log.Add($Request); Reply 500 $null $null }
$result = Invoke-ApiRequest $client '/broken'
Eq $false $result.Success 'a permanently failing request fails'
Eq 500 $result.StatusCode 'the last status code is reported'
Eq 4 $result.Attempts 'the first attempt plus three retries'
Eq '[100, 200, 400]' (Show $result.Delays) 'three back-offs were worked out'
Eq 'HTTP 500' $result.Error 'the error names the status'
Eq 4 $log.Count 'the transport was called four times'

# --- A client error is not retried ---------------------------------------
$log.Clear()
$client = New-ApiClient 'https://api.internal' { param($Request) $log.Add($Request); Reply 404 $null $null }
$result = Invoke-ApiRequest $client '/missing'
Eq $false $result.Success 'a 404 fails'
Eq 404 $result.StatusCode 'the 404 is reported'
Eq 1 $result.Attempts 'a 404 is not retried'
Eq 0 (@($result.Delays).Count) 'a 404 produces no back-off'
Eq 'HTTP 404' $result.Error 'the 404 error message'
Eq 1 $log.Count 'the transport was called once'

# --- A transport that throws is retried ----------------------------------
$log.Clear()
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    $log.Add($Request)
    if ($Request.Attempt -eq 1) { throw 'socket closed' }
    return Reply 200 ([pscustomobject]@{ ok = 'recovered' }) $null
}
$result = Invoke-ApiRequest $client '/flappy'
Eq $true $result.Success 'a thrown transport is retried'
Eq 2 $result.Attempts 'two attempts'
Eq 'recovered' $result.Body.ok 'the recovered body'

# --- Pagination -----------------------------------------------------------
$pages = @{
    '/widgets'        = [pscustomobject]@{ items = @('w1', 'w2'); next = '/widgets?page=2' }
    '/widgets?page=2' = [pscustomobject]@{ items = @('w3', 'w4'); next = '/widgets?page=3' }
    '/widgets?page=3' = [pscustomobject]@{ items = @('w5') }
}
$log.Clear()
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    $log.Add($Request)
    $key = $Request.Uri.Substring('https://api.internal'.Length)
    return Reply 200 $pages[$key] $null
}
$items = Get-ApiPagedResult $client '/widgets'
Ok ($items -is [object[]]) 'Get-ApiPagedResult must return object[]'
Eq '[w1, w2, w3, w4, w5]' (Show $items) 'every page contributes its items, in order'
Eq 3 $log.Count 'three pages were fetched'
Eq '[https://api.internal/widgets, https://api.internal/widgets?page=2, https://api.internal/widgets?page=3]' (Show (@($log | ForEach-Object { $_.Uri }))) 'the next link is followed'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
