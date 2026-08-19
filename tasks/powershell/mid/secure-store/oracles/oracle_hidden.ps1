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
. (Ws 'CredentialStore.ps1')

function Secure([string]$plain) { return (ConvertTo-SecureString -String $plain -AsPlainText -Force) }
function Plain($credential) { return [System.Net.NetworkCredential]::new('', $credential.Password).Password }

$store = Work 'store1.json'
if (Test-Path -LiteralPath $store) { Remove-Item -LiteralPath $store -Force }

$secretText = 'Correct-Horse-42'
Save-StoredCredential 'reports' 'svc_reports' (Secure $secretText) $store

Ok (Test-Path -LiteralPath $store) 'the store file is created'

$text = ReadText $store
Ok (-not $text.Contains($secretText)) 'the password never reaches the file in the clear'
Ok (-not $text.Contains('Correct')) 'no fragment of the password reaches the file'
$parsed = $text | ConvertFrom-Json
Ok ($null -ne $parsed) 'the store file is valid JSON'
$bytes = [System.IO.File]::ReadAllBytes($store)
Ok (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'the store file has no byte-order mark'

$credential = Get-StoredCredential 'reports' $store
Ok ($credential -is [pscredential]) 'the stored entry comes back as a PSCredential'
Eq 'svc_reports' $credential.UserName 'the user name round trips'
Eq $secretText (Plain $credential) 'the password round trips'
Ok ($credential.Password -is [securestring]) 'the password comes back as a SecureString'

# A second entry does not disturb the first.
Save-StoredCredential 'archive' 'svc_archive' (Secure 'Second-Secret-7') $store
$names = Get-StoredCredentialName $store
Ok ($names -is [string[]]) 'Get-StoredCredentialName returns String[]'
Eq '[archive, reports]' (Show $names) 'names come back sorted'
Eq $secretText (Plain (Get-StoredCredential 'reports' $store)) 'the first password still round trips'
Eq 'Second-Secret-7' (Plain (Get-StoredCredential 'archive' $store)) 'the second password round trips'
Eq 'svc_archive' (Get-StoredCredential 'archive' $store).UserName 'the second user name'

# Saving the same name again replaces it in place.
Save-StoredCredential 'reports' 'svc_reports_v2' (Secure 'Rotated-Secret-9') $store
$names = Get-StoredCredentialName $store
Eq 2 (@($names).Count) 'saving an existing name does not add a second entry'
Eq '[archive, reports]' (Show $names) 'the names are unchanged'
$rotated = Get-StoredCredential 'reports' $store
Eq 'svc_reports_v2' $rotated.UserName 'the user name was updated'
Eq 'Rotated-Secret-9' (Plain $rotated) 'the password was updated'
Eq 'Second-Secret-7' (Plain (Get-StoredCredential 'archive' $store)) 'the other entry is untouched'

$text = ReadText $store
Ok (-not $text.Contains('Rotated-Secret-9')) 'the rotated password is not in the clear either'
Ok (-not $text.Contains('Second-Secret-7')) 'the other password is not in the clear either'

# Removing an entry.
$removed = Remove-StoredCredential 'archive' $store
Ok ($removed -is [bool]) 'Remove-StoredCredential returns a Boolean'
Eq $true $removed 'removing an existing entry reports true'
Eq '[reports]' (Show (Get-StoredCredentialName $store)) 'the entry is gone'
Eq $null (Get-StoredCredential 'archive' $store) 'the removed entry no longer resolves'
Eq $false (Remove-StoredCredential 'archive' $store) 'removing it again reports false'
Eq 'Rotated-Secret-9' (Plain (Get-StoredCredential 'reports' $store)) 'the surviving entry still works'
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
