# Inbox tidier for the ops drop folder.
#
# Loose files land in a single directory and have to be filed into
# per-extension subfolders before the nightly sweep picks them up.

function Invoke-FileOrganizer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    throw 'Invoke-FileOrganizer is not implemented yet.'
}
