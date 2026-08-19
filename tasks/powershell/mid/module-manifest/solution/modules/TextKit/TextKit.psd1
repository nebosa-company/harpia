@{
    RootModule        = 'TextKit.psm1'
    ModuleVersion     = '1.2.0'
    GUID              = 'a7f1c2e4-58d3-4b6a-9c10-2f7e4d8b3a55'
    Author            = 'Docs Tooling'
    CompanyName       = 'Internal'
    Copyright         = 'Internal use only'
    Description       = 'Small text helpers shared by the docs tooling: slugs, sentences, and statistics.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @('ConvertTo-SlugText', 'Split-Sentence', 'Get-TextStats')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('slug')

    PrivateData       = @{
        PSData = @{
            Tags = @('text', 'docs')
        }
    }
}
