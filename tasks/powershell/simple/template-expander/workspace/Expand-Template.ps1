# Placeholder expansion for the notification templates.
#
# Templates live in templates/ and are edited by the support team, so the
# expander has to be forgiving about spacing and unforgiving about
# anything that could quietly produce the wrong text.

function Expand-Template {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Template,

        [Parameter(Mandatory, Position = 1)]
        [hashtable]$Values,

        [switch]$Strict
    )

    throw 'Expand-Template is not implemented yet.'
}

function Expand-TemplateFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$TemplatePath,

        [Parameter(Mandatory, Position = 1)]
        [hashtable]$Values,

        [Parameter(Mandatory, Position = 2)]
        [string]$OutPath,

        [switch]$Strict
    )

    throw 'Expand-TemplateFile is not implemented yet.'
}
