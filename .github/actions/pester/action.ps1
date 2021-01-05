[CmdletBinding()]
param(
    # The path to the folder where your tests are.
    # Note: if there are no .Tests.ps1 files and only .feature files, Invoke-Gherkin will run instead of Pester
    [string]$PesterVersion,
    [string]$ModuleUnderTest,
    [string]$ModuleVersion,
    [string]$TestsDirectory = "*[Tt]est*",
    [string[]]$IncludeTag,
    [string[]]$ExcludeTag,
    [string[]]$AdditionalModulePaths = "Modules",
    [string]$CodeCoveragePath,
    [string]$TestRunTitle = "Pester",
    [string]$Show = "All"
)

if ($PesterVersion) {
    & $PSScriptRoot\Install-RequiredModule @{ "Pester" = $PesterVersion } -TrustRegisteredRepositories
    Import-Module Pester -RequiredVersion $PesterVersion
} elseif (Test-Path RequiredModules.psd1) {
    & $PSScriptRoot\Install-RequiredModule -RequiredModulesFile RequiredModules.psd1 -TrustRegisteredRepositories -Import
} elseif (Test-Path RequiredModules\RequiredModules.psd1) {
    & $PSScriptRoot\Install-RequiredModule -RequiredModulesFile RequiredModules\RequiredModules.psd1 -TrustRegisteredRepositories -Import
}

$Options = @{
    Path         = Convert-Path $TestsDirectory
    OutputFormat = "NUnitXml"
    OutputFile   = 'results.xml'
    Show         = $Show
}

if ($CodeCoverage = $CodeCoveragePath) {
    if ($CodeCoverage = Get-ChildItem $CodeCoverage -Recurse -Include *.psm1, *.ps1 | Convert-Path) {
        $Options.CodeCoverage = $CodeCoverage
        $Options.CodeCoverageOutputFile = 'coverage.xml'
    }
}

if ($IncludeTag) {
    Write-Verbose "IncludeTag $($IncludeTag -join ', ')" -Verbose
    $Options.Tag = $IncludeTag
}

if ($ExcludeTag) {
    Write-Verbose "ExcludeTag $($ExcludeTag -join ', ')" -Verbose
    $Options.ExcludeTag = $ExcludeTag
}

if ($AdditionalModulePaths) {
    $Env:PSModulePath = @(
        @($AdditionalModulePaths -split [IO.Path]::PathSeparator | ForEach-Object TrimEnd(':;')) +
        @($Env:PSModulePath -split [IO.Path]::PathSeparator | ForEach-Object TrimEnd(':;'))
    ) -join [IO.Path]::PathSeparator
    Write-Verbose "Current PSModulePath $Env:PSModulePath" -Verbose
}

if ($ModuleUnderTest) {
    Remove-Module $ModuleUnderTest -Force -ErrorAction Ignore
    if ($ModuleVersion) {
        Import-Module $ModuleUnderTest -RequiredVersion $ModuleVersion
    } else {
        Get-Module $ModuleUnderTest -ListAvailable -Ov Modules |
            Sort-Object Version -Descending |
            Select-Object -First 1 |
            Import-Module
    }
}

@($Modules) + @(Get-Module) | Out-String | Write-Verbose -Verbose

Write-Host $([PSCustomObject]$Options | Out-String)
if (!$PSVersionTable.OS) {
    $PSVersionTable.OS = [System.Environment]::OSVersion
}

"PSPlatform=PowerShell $($PSVersionTable['PSVersion', 'OS'] -join ' on ')" |
    Out-File $Env:GITHUB_ENV -Encoding UTF8 -Append

# Use Gherkin when we can't find *.Tests.ps1, but there are *.feature
# Note this requires Pester 4.x (either by PesterVersion or RequiredModules.psd1)
if (!(Get-ChildItem $TestsDirectory -Recurse -Filter *.[Tt]ests.ps1) -and
     (Get-ChildItem $TestsDirectory -Recurse -Filter *.feature)) {
    # there's a bug in Gherkin's code coverage
    $null = $Options.Remove("CodeCoverageOutputFile")
    Invoke-Gherkin @Options
} else {
    Invoke-Pester @Options
}
