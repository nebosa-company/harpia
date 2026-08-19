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

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
Eq 'ApiKit.psm1' $manifest.RootModule 'RootModule points at the script module'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.GUID)) 'the manifest carries a GUID'
Ok (-not [string]::IsNullOrWhiteSpace([string]$manifest.Description)) 'the manifest carries a description'
Eq '[Get-ApiPagedResult, Invoke-ApiRequest, New-ApiClient]' (Show (@($manifest.FunctionsToExport | Sort-Object))) 'FunctionsToExport names the three commands'
Ok (-not ((@($manifest.FunctionsToExport) -join ',').Contains('*'))) 'FunctionsToExport is not a wildcard'
Ok ($null -ne (Test-ModuleManifest -Path $manifestPath -ErrorAction SilentlyContinue)) 'Test-ModuleManifest accepts the manifest'

Import-Module $manifestPath -Force -ErrorAction Stop

$log = [System.Collections.Generic.List[object]]::new()
function Reply([int]$code, $body, $headers) {
    return [pscustomobject]@{ StatusCode = $code; Headers = $headers; Body = $body }
}

# --- Parameter validation -------------------------------------------------
Ok ($null -ne (Throws { New-ApiClient 'https://x' { param($r) } -1 })) 'a negative retry count is refused'
Ok ($null -ne (Throws { New-ApiClient 'https://x' { param($r) } 99 })) 'an absurd retry count is refused'
Ok ($null -eq (Throws { New-ApiClient 'https://x' { param($r) } 0 })) 'zero retries is allowed'

# --- No retries at all ----------------------------------------------------
$log.Clear()
$client = New-ApiClient 'https://api.internal' { param($Request) $log.Add($Request); Reply 500 $null $null } 0
$result = Invoke-ApiRequest $client '/x'
Eq 1 $result.Attempts 'zero retries means one attempt'
Eq 1 $log.Count 'the transport was called once'
Ok ($result.Delays -is [int[]]) 'Delays is still Int32[]'
Eq 0 (@($result.Delays).Count) 'no back-off was worked out'

# --- Which statuses are retried -------------------------------------------
foreach ($code in @(429, 500, 502, 503, 504)) {
    $log.Clear()
    $client = New-ApiClient 'https://api.internal' { param($Request) $log.Add($Request); Reply $code $null $null } 1
    $result = Invoke-ApiRequest $client '/x'
    Eq 2 $result.Attempts "status $code is retried"
}
foreach ($code in @(400, 401, 403, 404, 409, 422)) {
    $log.Clear()
    $client = New-ApiClient 'https://api.internal' { param($Request) $log.Add($Request); Reply $code $null $null } 3
    $result = Invoke-ApiRequest $client '/x'
    Eq 1 $result.Attempts "status $code is not retried"
    Eq "HTTP $code" $result.Error "status $code error message"
}

# --- 2xx other than 200 still succeeds ------------------------------------
$client = New-ApiClient 'https://api.internal' { param($Request) Reply 204 $null $null }
$result = Invoke-ApiRequest $client '/x'
Eq $true $result.Success 'a 204 succeeds'
Eq 204 $result.StatusCode 'the 204 is reported'

# --- Retry-After ----------------------------------------------------------
$client = New-ApiClient 'https://api.internal' { param($Request) Reply 503 $null @{ 'Retry-After' = '2' } } 2
$result = Invoke-ApiRequest $client '/x'
Eq '[2000, 2000]' (Show $result.Delays) 'Retry-After seconds become milliseconds'

$client = New-ApiClient 'https://api.internal' { param($Request) Reply 503 $null @{ 'retry-after' = '3' } } 1
$result = Invoke-ApiRequest $client '/x'
Eq '[3000]' (Show $result.Delays) 'the Retry-After header is matched case insensitively'

$client = New-ApiClient 'https://api.internal' { param($Request) Reply 503 $null @{ 'Retry-After' = 'Wed, 21 Oct 2026 07:28:00 GMT' } } 2
$result = Invoke-ApiRequest $client '/x'
Eq '[100, 200]' (Show $result.Delays) 'an unparsable Retry-After falls back to the doubling back-off'

$client = New-ApiClient 'https://api.internal' { param($Request) Reply 503 $null @{ 'Retry-After' = '0' } } 1
$result = Invoke-ApiRequest $client '/x'
Eq '[0]' (Show $result.Delays) 'a Retry-After of zero is honoured as zero'

# --- A different back-off unit --------------------------------------------
$client = New-ApiClient 'https://api.internal' { param($Request) Reply 503 $null $null } 3 50
$result = Invoke-ApiRequest $client '/x'
Eq '[50, 100, 200]' (Show $result.Delays) 'the back-off unit is respected'

# --- A transport that always throws ---------------------------------------
$log.Clear()
$client = New-ApiClient 'https://api.internal' { param($Request) $log.Add($Request); throw 'socket closed' } 2
$result = Invoke-ApiRequest $client '/x'
Eq $false $result.Success 'a transport that always throws fails'
Eq 3 $result.Attempts 'every attempt was made'
Eq 0 $result.StatusCode 'there is no status code to report'
Eq $null $result.Body 'there is no body to report'
Eq 'socket closed' $result.Error 'the transport message is reported'
Eq 3 $log.Count 'the transport was called three times'

# --- Pagination corners ---------------------------------------------------
$single = @{ '/only' = [pscustomobject]@{ items = @('one') } }
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    Reply 200 $single[$Request.Uri.Substring('https://api.internal'.Length)] $null
}
$items = Get-ApiPagedResult $client '/only'
Ok ($items -is [object[]]) 'a one-page result is object[]'
Eq 1 (@($items).Count) 'one item'
Eq 'one' $items[0] 'the single item'

$blank = @{ '/none' = [pscustomobject]@{ items = @() } }
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    Reply 200 $blank[$Request.Uri.Substring('https://api.internal'.Length)] $null
}
$items = Get-ApiPagedResult $client '/none'
Ok ($null -ne $items) 'an empty page gives an array, not null'
Ok ($items -is [object[]]) 'an empty page gives object[]'
Eq 0 (@($items).Count) 'an empty page contributes nothing'

# A next link that loops for ever is stopped by the page limit.
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    Reply 200 ([pscustomobject]@{ items = @('x'); next = '/loop' }) $null
}
$loopError = Throws { Get-ApiPagedResult $client '/loop' 4 }
Ok ($null -ne $loopError) 'an endless next chain is stopped'
Eq 'Page limit exceeded' $loopError.Exception.Message 'the page-limit message'
Ok ($null -ne (Throws { Get-ApiPagedResult $client '/loop' })) 'the default page limit stops it too'
Ok ($null -ne (Throws { Get-ApiPagedResult $client '/loop' 0 })) 'a page limit of zero is refused'

# Exactly at the limit is fine.
$three = @{
    '/p1' = [pscustomobject]@{ items = @('a'); next = '/p2' }
    '/p2' = [pscustomobject]@{ items = @('b'); next = '/p3' }
    '/p3' = [pscustomobject]@{ items = @('c') }
}
$client = New-ApiClient 'https://api.internal' {
    param($Request)
    Reply 200 $three[$Request.Uri.Substring('https://api.internal'.Length)] $null
}
Eq '[a, b, c]' (Show (Get-ApiPagedResult $client '/p1' 3)) 'a chain exactly at the limit is allowed'
Ok ($null -ne (Throws { Get-ApiPagedResult $client '/p1' 2 })) 'a chain one page over the limit is refused'

# A page that fails stops the walk.
$client = New-ApiClient 'https://api.internal' { param($Request) Reply 500 $null $null } 0
$failError = Throws { Get-ApiPagedResult $client '/x' }
Ok ($null -ne $failError) 'a failing page stops the walk'
Eq 'Request failed: 500' $failError.Exception.Message 'the failing-page message names the status'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
