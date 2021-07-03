<#
    .SYNOPSIS
        Invoke-Gherkin against a specific version in output
#>
[CmdletBinding()]
param(
    # A specific folder the build is in
    $OutputDirectory = $PSScriptRoot,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer
)
Push-Location $PSScriptRoot -StackName BuildTestStack

if (!$SemVer -and (Get-Command gitversion -ErrorAction Ignore)) {
    $SemVer = gitversion -showvariable nugetversion
}

Write-Host "OutputDirectory: $OutputDirectory"
Write-Host "SemVer: $SemVer"

try {
    if (Test-Path $OutputDirectory) {
        # Get the part of the output path that we need to add to the PSModulePath
        if ($OutputDirectory -match "Configuration$") {
            $OutputDirectory = Split-Path $OutputDirectory
        }
        if (-not (@($Env:PSModulePath.Split([IO.Path]::PathSeparator)) -contains $OutputDirectory)) {
            Write-Verbose "Adding $($OutputDirectory) to PSModulePath"
            $Env:PSModulePath = $OutputDirectory + [IO.Path]::PathSeparator + $Env:PSModulePath
        }
    }

    $Specs = @{ Path = Join-Path $PSScriptRoot Specs }
    # Just to make sure everything is kosher, run tests in a clean session
    $PSModulePath = $Env:PSModulePath
    Invoke-Command {
        # We need to make sure that the PSModulePath has our output at the front
        $Env:PSModulePath = $OutputDirectory + [IO.Path]::PathSeparator +
                            $Env:PSModulePath

        Write-Host "Testing Configuration $SemVer"
        $SemVer = ($SemVer -split "-")[0]

        # We need to make sure we have loaded ONLY the right version of the module
        Get-Module Configuration -All | Remove-Module -ErrorAction SilentlyContinue -Force
        $Specs["CodeCoverage"] = Import-Module Configuration -RequiredVersion $SemVer -PassThru | Select-Object -Expand Path
        Invoke-Gherkin @Specs
    }

} finally {
    Pop-Location -StackName BuildTestStack
}