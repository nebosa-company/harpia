# Step runner for the maintenance playbooks.

function Invoke-Safely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1)]
        [string]$Name = 'unnamed'
    )

    $outputs = [System.Collections.Generic.List[object]]::new()
    $message = $null
    $type = $null

    try {
        $raw = & $ScriptBlock 2>&1
        if ($null -ne $raw) {
            foreach ($item in @($raw)) {
                if ($item -is [System.Management.Automation.ErrorRecord]) {
                    if ($null -eq $message) {
                        $message = [string]$item.Exception.Message
                        $type = [string]$item.Exception.GetType().FullName
                    }
                }
                else {
                    $outputs.Add($item)
                }
            }
        }
    }
    catch {
        $message = [string]$_.Exception.Message
        $type = [string]$_.Exception.GetType().FullName
    }

    $succeeded = ($null -eq $message)
    if ($succeeded) { $output = [object[]]@($outputs) } else { $output = [object[]]@() }

    return [pscustomobject]@{
        Name         = [string]$Name
        Succeeded    = [bool]$succeeded
        Output       = $output
        ErrorMessage = $message
        ErrorType    = $type
    }
}

function Invoke-AllSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [scriptblock[]]$ScriptBlock,

        [switch]$StopOnError
    )

    $results = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $ScriptBlock.Count; $i++) {
        $result = Invoke-Safely -ScriptBlock $ScriptBlock[$i] -Name ("step-{0}" -f ($i + 1))
        $results.Add($result)
        if ($StopOnError -and -not $result.Succeeded) { break }
    }

    $arr = [object[]]@($results)
    return , $arr
}
