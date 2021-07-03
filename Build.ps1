#requires -Module @{ModuleName = "ModuleBuilder"; ModuleVersion = "2.0.0"}, Configuration
[CmdletBinding()]
param(
    # A specific folder to build into
    $OutputDirectory,

    # The version of the output module
    [Alias("ModuleVersion")]
    [string]$SemVer
)
Push-Location $PSScriptRoot -StackName BuildTestStack

if (-not $Semver -and (Get-Command gitversion -ErrorAction Ignore)) {
    if ($semver = gitversion -showvariable SemVer) {
        $null = $PSBoundParameters.Add("SemVer", $SemVer)
    }
}

try {
    Build-Module @PSBoundParameters -Target CleanBuild
} finally {
    Pop-Location -StackName BuildTestStack
}