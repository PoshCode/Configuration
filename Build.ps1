[CmdletBinding()]
param(
    # A specific folder to build into
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer
)
Push-Location $PSScriptRoot -StackName BuildWindowsConsoleFont

# Do we need to re-add the PSModulePath in each PowerShell step?
if (Test-Path .\RequiredModules) {
    $LocalModules = Convert-Path .\RequiredModules
    if (-not (@($Env:PSModulePath.Split([IO.Path]::PathSeparator)) -contains $LocalModules)) {
        Write-Verbose "Adding $($LocalModules) to PSModulePath"
        $Env:PSModulePath = $LocalModules + [IO.Path]::PathSeparator + $Env:PSModulePath
    }
}

if (!$SemVer -and (Get-Command gitversion -ErrorAction Ignore)) {
    $PSBoundParameters['SemVer'] = gitversion -showvariable nugetversion
}
if (!$OutputDirectory) {
    $PSBoundParameters['OutputDirectory'] = Join-Path $PSScriptRoot .\Output\Configuration
}

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