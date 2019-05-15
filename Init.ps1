<#
    .SYNOPSIS
        Initialize the DevTools folder with RequiredModules and tools
#>
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

# Do we need to re-add the PSModulePath in each PowerShell step?
if (Test-Path $LocalTools) {
    $LocalTools = Convert-Path $LocalTools
    if (-not (@($Env:PSModulePath.Split([IO.Path]::PathSeparator)) -contains $LocalTools)) {
        Write-Verbose "Adding $($LocalTools) to PSModulePath"
        $Env:PSModulePath = $LocalTools + [IO.Path]::PathSeparator + $Env:PSModulePath
    }
    if (-not (@($Env:Path.Split([IO.Path]::PathSeparator)) -contains $LocalTools)) {
        $Env:Path = $LocalTools + [IO.Path]::PathSeparator + $Env:Path
    }
}

if (!$SemVer -and (Get-Command gitversion -ErrorAction Ignore)) {
    $SemVer = gitversion -showvariable nugetversion
}

if (!$OutputDirectory) {
    $OutputDirectory = Join-Path $PSScriptRoot ./Output/Configuration | Convert-Path
}