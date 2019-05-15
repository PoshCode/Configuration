[CmdletBinding()]
param(
    # A specific folder to build into
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer,

    # Optionally, a local folder that modules and CLI tools can be installed in
    $LocalTools = "./RequiredModules"
)
Push-Location $PSScriptRoot -StackName BuildWindowsConsoleFont

# The init script sets default values for the parameters and fixes paths
. $PSScriptRoot/Init.ps1

$PSBoundParameters['SemVer'] = $SemVer
$PSBoundParameters['OutputDirectory'] = $OutputDirectory
$null = $PSBoundParameters.Remove('LocalTools')

try {
    ## Build the actual module
    $MetadataInfo = Build-Module -SourcePath .\Source\Metadata `
                        -Target CleanBuild -Passthru `
                        @PSBoundParameters

    $ConfigurationInfo = Build-Module -SourcePath .\Source\Configuration `
                        -Target Build -Passthru `
                        @PSBoundParameters

    # Because this is a double-module, combine the exports of both modules
    Update-Metadata -Path $ConfigurationInfo.Path -PropertyName FunctionsToExport `
                    -Value @(
                        $MetadataInfo.ExportedFunctions.Keys
                        $ConfigurationInfo.ExportedFunctions.Keys
                        # @('*')
                    )

    $ConfigurationInfo

    # Remove the extra metadata file
    Remove-Item $MetadataInfo.Path
} finally {
    Pop-Location -StackName BuildWindowsConsoleFont
}