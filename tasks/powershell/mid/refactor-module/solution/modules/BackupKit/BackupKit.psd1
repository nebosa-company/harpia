@{
    RootModule        = 'BackupKit.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd3b41e97-6c25-4a8f-9f02-71e5c8a4b6d1'
    Author            = 'Platform Tools'
    CompanyName       = 'Internal'
    Copyright         = 'Internal use only'
    Description       = 'Plan, copy, and verify file backups.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @('New-BackupPlan', 'Invoke-BackupPlan', 'Get-BackupManifest')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
