# Inbox tidier for the ops drop folder.

function Invoke-FileOrganizer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $rootPath = (Resolve-Path -LiteralPath $Root).ProviderPath
    $files = @(Get-ChildItem -LiteralPath $rootPath -File -Force)

    $names = [string[]]@($files | ForEach-Object { $_.Name })
    if ($names.Length -gt 1) { [System.Array]::Sort($names, [System.StringComparer]::Ordinal) }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($name in $names) {
        $dot = $name.LastIndexOf('.')
        $bucket = 'other'
        if ($dot -gt 0 -and $dot -lt ($name.Length - 1)) {
            $bucket = $name.Substring($dot + 1).ToLowerInvariant()
        }

        $source = Join-Path $rootPath $name
        $bucketDir = Join-Path $rootPath $bucket
        $destination = Join-Path $bucketDir $name
        $relative = Join-Path $bucket $name

        $status = 'moved'
        $moved = $true

        if (Test-Path -LiteralPath $destination) {
            $status = 'conflict'
            $moved = $false
        }
        elseif ($PSCmdlet.ShouldProcess($source, "Move into $bucket")) {
            if (-not (Test-Path -LiteralPath $bucketDir)) {
                New-Item -ItemType Directory -Path $bucketDir -Force | Out-Null
            }
            Move-Item -LiteralPath $source -Destination $destination
        }
        else {
            $status = 'planned'
            $moved = $false
        }

        $results.Add([pscustomobject]@{
            Name        = [string]$name
            Bucket      = [string]$bucket
            Destination = [string]$relative
            Moved       = [bool]$moved
            Status      = [string]$status
        })
    }

    $out = @($results)
    return , $out
}
