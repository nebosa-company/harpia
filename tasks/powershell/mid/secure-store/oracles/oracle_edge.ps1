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

# A store that does not exist yet.
$missing = Work 'no-such-store.json'
if (Test-Path -LiteralPath $missing) { Remove-Item -LiteralPath $missing -Force }
$names = Get-StoredCredentialName $missing
Ok ($null -ne $names) 'a missing store gives an array, not null'
Ok ($names -is [string[]]) 'a missing store gives String[]'
Eq 0 (@($names).Count) 'a missing store has no names'
Eq $null (Get-StoredCredential 'anything' $missing) 'a missing store resolves nothing'
Eq $false (Remove-StoredCredential 'anything' $missing) 'removing from a missing store reports false'

# One entry: the name list is still a list.
$store = Work 'store2.json'
if (Test-Path -LiteralPath $store) { Remove-Item -LiteralPath $store -Force }
Save-StoredCredential 'only' 'svc_only' (Secure 'One-Entry-1') $store
$names = Get-StoredCredentialName $store
Ok ($names -is [string[]]) 'a one-entry store gives String[]'
Eq 1 (@($names).Count) 'one name'
Eq 'only' $names[0] 'indexing the single name gives the whole name'

# An unknown name.
Eq $null (Get-StoredCredential 'missing' $store) 'an unknown name resolves to null'

# Names are matched exactly, case included.
Eq $null (Get-StoredCredential 'ONLY' $store) 'names are matched case sensitively'

# Emptying the store leaves a readable file.
Eq $true (Remove-StoredCredential 'only' $store) 'the last entry is removed'
Ok (Test-Path -LiteralPath $store) 'the store file survives being emptied'
$emptyNames = Get-StoredCredentialName $store
Ok ($emptyNames -is [string[]]) 'an emptied store gives String[]'
Eq 0 (@($emptyNames).Count) 'an emptied store has no names'
Ok ($null -ne ((ReadText $store) | ConvertFrom-Json)) 'an emptied store is still valid JSON'

# Awkward passwords survive the round trip.
$awkward = 'p a s s"word''s \ / {} [] : , 42 end'
Save-StoredCredential 'awkward' 'svc_awkward' (Secure $awkward) $store
Eq $awkward (Plain (Get-StoredCredential 'awkward' $store)) 'an awkward password round trips exactly'
Ok (-not (ReadText $store).Contains('p a s s')) 'the awkward password is not in the clear'

# A long password.
$long = ('x' * 200) + '-end'
Save-StoredCredential 'long' 'svc_long' (Secure $long) $store
Eq $long (Plain (Get-StoredCredential 'long' $store)) 'a long password round trips exactly'

# Names sort ordinally.
Save-StoredCredential 'zulu' 'svc_z' (Secure 'z') $store
Save-StoredCredential 'Alpha' 'svc_a' (Secure 'a') $store
Save-StoredCredential '9nine' 'svc_9' (Secure '9') $store
$names = Get-StoredCredentialName $store
Eq '[9nine, Alpha, awkward, long, zulu]' (Show $names) 'names sort ordinally'

# Every entry still resolves after all that editing.
Eq 'z' (Plain (Get-StoredCredential 'zulu' $store)) 'zulu still resolves'
Eq 'a' (Plain (Get-StoredCredential 'Alpha' $store)) 'Alpha still resolves'
Eq '9' (Plain (Get-StoredCredential '9nine' $store)) '9nine still resolves'
Eq $awkward (Plain (Get-StoredCredential 'awkward' $store)) 'the awkward entry still resolves'

# The protected form is not the plaintext and is not empty.
$doc = (ReadText $store) | ConvertFrom-Json
$entries = @($doc.entries)
Eq 5 $entries.Count 'the file holds five entries'
foreach ($entry in $entries) {
    $secret = [string]$entry.secret
    Ok ($secret.Length -gt 0) 'every entry carries a protected secret'
    Ok ($secret -cne 'z' -and $secret -cne 'a' -and $secret -cne '9') 'no protected secret is the plaintext'
}
}
catch {
    Write-Host ("FAIL unhandled: {0}" -f $_.Exception.Message)
    Write-Host ($_.ScriptStackTrace)
    exit 1
}

Done
