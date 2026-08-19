@{
    RootModule        = 'ApiKit.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'f04b8c31-9d2a-4e77-8b56-31c0a9f2e7d4'
    Author            = 'Platform Tools'
    CompanyName       = 'Internal'
    Copyright         = 'Internal use only'
    Description       = 'Retrying, paging client for the internal REST services.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @('New-ApiClient', 'Invoke-ApiRequest', 'Get-ApiPagedResult')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
