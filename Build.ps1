#requires -Module ModuleBuilder, Configuration
[CmdletBinding()]
param(
    # A specific folder to build into
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer
)
Push-Location $PSScriptRoot -StackName BuildTestStack

if (!$SemVer -and (Get-Command gitversion -ErrorAction Ignore)) {
    $PSBoundParameters['SemVer'] = gitversion -showvariable nugetversion
}
if (!$PSBoundParameters.ContainsKey("OutputDirectory")) {
    $PSBoundParameters["OutputDirectory"] = $PSScriptRoot
}

try {
    ## Build the actual module
    $MetadataInfo = Build-Module -SourcePath .\Source\Metadata `
                        -Target CleanBuild -Passthru `
                        @PSBoundParameters

    $ConfigurationInfo = Build-Module -SourcePath .\Source\Configuration `
                        -Target Build -Passthru `
                        @PSBoundParameters

    # Copy and then remove the extra output
    Copy-Item -Path (Join-Path $MetadataInfo.ModuleBase Metadata.psm1) -Destination $ConfigurationInfo.ModuleBase
    Remove-Item $MetadataInfo.ModuleBase -Recurse

    # Because this is a double-module, combine the exports of both modules
    # Put the ExportedFunctions of both in the manifest
    Update-Metadata -Path $ConfigurationInfo.Path -PropertyName FunctionsToExport `
                    -Value @(
                        @(
                            $MetadataInfo.ExportedFunctions.Keys
                            $ConfigurationInfo.ExportedFunctions.Keys
                        ) | Select-Object -Unique
                        # @('*')
                    )

    # Put the ExportedAliases of both in the manifest
    Update-Metadata -Path $ConfigurationInfo.Path -PropertyName AliasesToExport `
                    -Value @(
                        @(
                            $MetadataInfo.ExportedAliases.Keys
                            $ConfigurationInfo.ExportedAliases.Keys
                        ) | Select-Object -Unique
                        # @('*')
                    )

    $ConfigurationInfo

} finally {
    Pop-Location -StackName BuildTestStack
}