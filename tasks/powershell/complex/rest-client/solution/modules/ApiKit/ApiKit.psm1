# ApiKit - retrying, paging client for the internal REST services.

$script:ApiRetryableStatus = @(429, 500, 502, 503, 504)

function New-ApiClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$BaseUri,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$Transport,

        [Parameter(Position = 2)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 3,

        [Parameter(Position = 3)]
        [ValidateRange(0, 60000)]
        [int]$RetryDelayMs = 100
    )

    return [pscustomobject]@{
        BaseUri      = [string]$BaseUri.TrimEnd('/')
        Transport    = $Transport
        MaxRetries   = [int]$MaxRetries
        RetryDelayMs = [int]$RetryDelayMs
    }
}

function Get-ApiRetryAfterMs {
    param($Headers)

    if ($null -eq $Headers) { return $null }

    $value = $null
    if ($Headers -is [System.Collections.IDictionary]) {
        foreach ($key in @($Headers.Keys)) {
            if ([string]::Equals([string]$key, 'Retry-After', [System.StringComparison]::OrdinalIgnoreCase)) {
                $value = [string]$Headers[$key]
                break
            }
        }
    }
    else {
        foreach ($property in @($Headers.PSObject.Properties)) {
            if ([string]::Equals([string]$property.Name, 'Retry-After', [System.StringComparison]::OrdinalIgnoreCase)) {
                $value = [string]$property.Value
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($value)) { return $null }

    $seconds = 0
    $ok = [int]::TryParse(
        $value.Trim(),
        [System.Globalization.NumberStyles]::Integer,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$seconds)
    if (-not $ok -or $seconds -lt 0) { return $null }
    return [int]($seconds * 1000)
}

function Invoke-ApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        $Client,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path,

        [Parameter(Position = 2)]
        [string]$Method = 'GET',

        [Parameter(Position = 3)]
        $Body,

        [Parameter(Position = 4)]
        [hashtable]$Headers
    )

    $uri = ([string]$Client.BaseUri) + '/' + ([string]$Path).TrimStart('/')
    $sent = $Headers
    if ($null -eq $sent) { $sent = @{} }

    $maxAttempts = [int]$Client.MaxRetries + 1
    $delays = [System.Collections.Generic.List[int]]::new()

    $attempt = 0
    $status = 0
    $responseBody = $null
    $failure = $null

    while ($attempt -lt $maxAttempts) {
        $attempt++

        $request = [pscustomobject]@{
            Method  = [string]$Method
            Uri     = [string]$uri
            Body    = $Body
            Headers = $sent
            Attempt = [int]$attempt
        }

        $retryAfterMs = $null
        $threw = $false
        try {
            $response = & $Client.Transport $request
            $status = [int]$response.StatusCode
            $responseBody = $response.Body
            $retryAfterMs = Get-ApiRetryAfterMs -Headers $response.Headers
        }
        catch {
            $threw = $true
            $status = 0
            $responseBody = $null
            $failure = [string]$_.Exception.Message
        }

        if (-not $threw) {
            if ($status -ge 200 -and $status -le 299) {
                return [pscustomobject]@{
                    Success    = $true
                    StatusCode = [int]$status
                    Body       = $responseBody
                    Attempts   = [int]$attempt
                    Delays     = [int[]]@($delays)
                    Error      = $null
                }
            }
            $failure = "HTTP $status"
            if ($script:ApiRetryableStatus -notcontains $status) { break }
        }

        if ($attempt -ge $maxAttempts) { break }

        if ($null -ne $retryAfterMs) {
            $delays.Add([int]$retryAfterMs)
        }
        else {
            $delays.Add([int]([int]$Client.RetryDelayMs * [math]::Pow(2, $attempt - 1)))
        }
    }

    return [pscustomobject]@{
        Success    = $false
        StatusCode = [int]$status
        Body       = $responseBody
        Attempts   = [int]$attempt
        Delays     = [int[]]@($delays)
        Error      = $failure
    }
}

function Get-ApiPagedResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        $Client,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path,

        [Parameter(Position = 2)]
        [ValidateRange(1, 1000)]
        [int]$MaxPages = 50
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $next = [string]$Path
    $pages = 0

    while (-not [string]::IsNullOrWhiteSpace($next)) {
        if ($pages -ge $MaxPages) { throw 'Page limit exceeded' }
        $pages++

        $result = Invoke-ApiRequest -Client $Client -Path $next
        if (-not $result.Success) { throw ("Request failed: " + [string]$result.StatusCode) }

        if ($null -ne $result.Body -and $null -ne $result.Body.items) {
            foreach ($item in @($result.Body.items)) { $items.Add($item) }
        }

        $next = ''
        if ($null -ne $result.Body) {
            $candidate = $result.Body.next
            if ($null -ne $candidate) { $next = [string]$candidate }
        }
    }

    $arr = [object[]]@($items)
    return , $arr
}

Export-ModuleMember -Function @('New-ApiClient', 'Invoke-ApiRequest', 'Get-ApiPagedResult')
