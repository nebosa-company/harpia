# Parallel mapper for the batch tools.

function Invoke-ParallelMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 2)]
        [ValidateRange(1, 64)]
        [int]$ThrottleLimit = 4
    )

    $items = [object[]]@($InputObject)
    if ($items.Length -eq 0) {
        $none = [object[]]@()
        return , $none
    }

    $blockText = $ScriptBlock.ToString()

    $work = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $items.Length; $i++) {
        $work.Add([pscustomobject]@{ Index = [int]$i; Value = $items[$i] })
    }

    $raw = $work | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $ErrorActionPreference = 'Stop'
        $block = [scriptblock]::Create($using:blockText)
        $entry = $_

        $success = $true
        $result = $null
        $failure = $null

        try {
            $emitted = [System.Collections.Generic.List[object]]::new()
            $errors = [System.Collections.Generic.List[object]]::new()
            $produced = @($entry.Value) | ForEach-Object $block 2>&1
            foreach ($item in @($produced)) {
                if ($item -is [System.Management.Automation.ErrorRecord]) { $errors.Add($item) }
                else { $emitted.Add($item) }
            }
            if ($errors.Count -gt 0) {
                $success = $false
                $failure = [string]$errors[0].Exception.Message
            }
            elseif ($emitted.Count -eq 1) { $result = $emitted[0] }
            elseif ($emitted.Count -gt 1) { $result = [object[]]@($emitted) }
        }
        catch {
            $success = $false
            $failure = [string]$_.Exception.Message
        }

        [pscustomobject]@{
            Index   = [int]$entry.Index
            Success = [bool]$success
            Result  = $result
            Failure = $failure
        }
    }

    $byIndex = @{}
    foreach ($record in @($raw)) { $byIndex[[int]$record.Index] = $record }

    $out = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $items.Length; $i++) {
        $record = $byIndex[$i]
        $out.Add([pscustomobject]@{
            Index   = [int]$i
            Input   = $items[$i]
            Success = [bool]$record.Success
            Result  = $record.Result
            Error   = $record.Failure
        })
    }

    $arr = [object[]]@($out)
    return , $arr
}
