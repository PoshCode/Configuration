#requires -Version "4.0" -Module Configuration, PackageManagement, Pester
[CmdletBinding()]
param(
    # The step(s) to run. Defaults to "Clean", "Update", "Build", "Test", "Package"
    # You may also "Publish"
    # It's also acceptable to skip the "Clean" and particularly "Update" steps
    [ValidateSet("Clean", "Update", "Build", "Test", "Package", "Publish")]
    [string[]]$Step = @("Clean", "Update", "Build", "Test"),

    # The path to the module to build. Defaults to the folder this script is in.
    [Alias("PSPath")]
    [string]$Path = $PSScriptRoot,

    # The name of the module to build.
    # Default is hardcoded to "Configuration" because AppVeyor forces checkout to lowercase path name
    [string]$ModuleName = "Configuration",

    # The target framework for .net (for packages), with fallback versions
    # The default supports PS3:  "net40","net35","net20","net45"
    # To only support PS4, use:  "net45","net40","net35","net20"
    # To support PS2, you use:   "net35","net20"
    [string[]]$TargetFramework = @("net40","net35","net20","net45"),

    # The revision number (pulled from the environment in AppVeyor)
    [Nullable[int]]$RevisionNumber = ${Env:APPVEYOR_BUILD_NUMBER},

    [ValidateNotNullOrEmpty()]
    [String]$CodeCovToken = ${ENV:CODECOV_TOKEN},

    # The default language is your current UICulture
    [Globalization.CultureInfo]$DefaultLanguage = $((Get-Culture).Name)
)
$Script:TraceVerboseTimer = New-Object System.Diagnostics.Stopwatch
$Script:TraceVerboseTimer.Start()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function init {
    #.Synopsis
    #   The init step always has to run.
    #   Calculate your paths and so-on here.
    [CmdletBinding()]
    param()

    # Calculate Paths
    # The output path is just a temporary output and logging location
    $Script:OutputPath = Join-Path $Path output

    if(Test-Path $OutputPath -PathType Leaf) {
        throw "Cannot create folder for Configuration because there's a file in the way at '$OutputPath'"
    }
    if(!(Test-Path $OutputPath -PathType Container)) {
        $null = New-Item $OutputPath -Type Directory -Force
    }

    # We expect the source for the module in a subdirectory called one of three things:
    $Script:SourcePath = "src\${ModuleName}", "source\${ModuleName}", "src", "source", ${ModuleName} |
                         ForEach-Object { Join-Path $Path $_ -Resolve -ErrorAction Ignore } |
                         Select-Object -First 1
    if(!$SourcePath) {
        Write-Warning "This Build script expects a 'Source' or '$ModuleName' (or 'Source\$ModuleName') folder to be alongside it."
        throw "Can't find module source folder."
    }
    Write-Verbose "SourcePath: $SourcePath"

    $Script:ManifestPath = Join-Path $SourcePath "${ModuleName}.psd1" -Resolve -ErrorAction Ignore
    if(!$ManifestPath) {
        Write-Warning "This Build script expects a '${ModuleName}.psd1' in the '$SourcePath' folder."
        throw "Can't find module source files"
    }
    Write-Verbose "ManifestPath: $ManifestPath"

    $Script:TestPath = "Tests", "Specs" | ForEach-Object { Join-Path $Path $_ -Resolve -ErrorAction Ignore } | Select-Object -First 1
    if(!$TestPath) {
        Write-Warning "This Build script expects a 'Tests' or 'Specs' folder to contain tests."
    }

    # Calculate Version here, because we need it for the release path
    [Version]$Script:Version = Get-Module $ManifestPath -ListAvailable | Select-Object -ExpandProperty Version

    # If the RevisionNumber is specified as ZERO, this is a release build ...
    # If the RevisionNumber is not specified, this is a dev box build
    # If the RevisionNumber is specified, we assume this is a CI build
    if($Script:RevisionNumber -ge 0) {
        # For CI builds we don't increment the build number
        $Script:Build = if($Version.Build -le 0) { 0 } else { $Version.Build }
    } else {
        # For dev builds, assume we're working on the NEXT release
        $Script:Build = if($Version.Build -le 0) { 1 } else { $Version.Build + 1}
    }

    if([string]::IsNullOrEmpty($RevisionNumber) -or $RevisionNumber -eq 0) {
        $Script:Version = New-Object Version $Version.Major, $Version.Minor, $Build
    } else {
        $Script:Version = New-Object Version $Version.Major, $Version.Minor, $Build, $RevisionNumber
    }

    # The release path is where the final module goes
    $Script:ReleasePath = Join-Path $Path $Version
    $Script:ReleaseManifest = Join-Path $ReleasePath "${ModuleName}.psd1"
}


function test {
    [CmdletBinding()]
    param(
        [Switch]$Quiet,

        [Switch]$ShowWip,

        [int]$FailLimit=${Env:ACCEPTABLE_FAILURE},

        [ValidateNotNullOrEmpty()]
        [String]$JobID = ${Env:APPVEYOR_JOB_ID}
    )

    if(!$TestPath) {
        Write-Warning "No tests folder found. Invoking Pester in root: $Path"
        $TestPath = $Path
    }

    Trace-Message "TESTING: $ModuleName with $TestPath"

    Trace-Message "TESTING $ModuleName v$Version" -Verbose:(!$Quiet)
    Write-Host $(prompt) -NoNewLine
    Write-Host Remove-Module $ModuleName -ErrorAction SilentlyContinue
    Remove-Module $ModuleName -ErrorAction SilentlyContinue

    $Options = @{
        OutputFormat = "NUnitXml"
        OutputFile = (Join-Path $OutputPath TestResults.xml)
    }
    if($Quiet) { $Options.Quiet = $Quiet }
    if(!$ShowWip){ $Options.ExcludeTag = @("wip") }

    Set-Content "$TestPath\VersionSpecific.Steps.ps1" "
        BeforeEachFeature {
            Remove-Module 'Configuration' -ErrorAction Ignore -Force
            Import-Module '$ReleasePath\${ModuleName}.psd1' -Force
        }
        AfterEachFeature {
            Remove-Module 'Configuration' -ErrorAction Ignore -Force
            Import-Module '$ReleasePath\${ModuleName}.psd1' -Force
        }
        AfterEachScenario {
            if(Test-Path '$ReleasePath\${ModuleName}.psd1.backup') {
                Remove-Item '$ReleasePath\${ModuleName}.psd1'
                Rename-Item '$ReleasePath\${ModuleName}.psd1.backup' '$ReleasePath\${ModuleName}.psd1'
            }
        }
    "

    # Show the commands they would have to run to get these results:
    Write-Host $(prompt) -NoNewLine
    Write-Host Import-Module $ReleasePath\${ModuleName}.psd1 -Force
    Write-Host $(prompt) -NoNewLine

    # TODO: Update dependency to Pester 4.0 and use just Invoke-Pester
    if(Get-Command Invoke-Gherkin -ErrorAction SilentlyContinue) {
        Write-Host Invoke-Gherkin -Path $TestPath -CodeCoverage "$ReleasePath\*.psm1" -PassThru @Options
        $TestResults = Invoke-Gherkin -Path $TestPath -CodeCoverage "$ReleasePath\*.psm1" -PassThru @Options
    }

    # Write-Host Invoke-Pester -Path $TestPath -CodeCoverage "$ReleasePath\*.psm1" -PassThru @Options
    # $TestResults = Invoke-Pester -Path $TestPath -CodeCoverage "$ReleasePath\*.psm1" -PassThru @Options

    Remove-Module $ModuleName -ErrorAction SilentlyContinue

    $script:failedTestsCount = 0
    $script:passedTestsCount = 0
    foreach($result in $TestResults)
    {
        if($result -and $result.CodeCoverage.NumberOfCommandsAnalyzed -gt 0)
        {
            $script:failedTestsCount += $result.FailedCount
            $script:passedTestsCount += $result.PassedCount
            $CodeCoverageTitle = 'Code Coverage {0:F1}%'  -f (100 * ($result.CodeCoverage.NumberOfCommandsExecuted / $result.CodeCoverage.NumberOfCommandsAnalyzed))

            # TODO: this file mapping does not account for the new Public|Private module source (and I don't know how to make it do so)
            # Map file paths, e.g.: \1.0 back to \src
            for($i=0; $i -lt $TestResults.CodeCoverage.HitCommands.Count; $i++) {
                $TestResults.CodeCoverage.HitCommands[$i].File = $TestResults.CodeCoverage.HitCommands[$i].File.Replace($ReleasePath, $SourcePath)
            }
            for($i=0; $i -lt $TestResults.CodeCoverage.MissedCommands.Count; $i++) {
                $TestResults.CodeCoverage.MissedCommands[$i].File = $TestResults.CodeCoverage.MissedCommands[$i].File.Replace($ReleasePath, $SourcePath)
            }

            if($result.CodeCoverage.MissedCommands.Count -gt 0) {
                $result.CodeCoverage.MissedCommands |
                    ConvertTo-Html -Title $CodeCoverageTitle |
                    Out-File (Join-Path $OutputPath "CodeCoverage-${Version}.html")
            }
            if(${CodeCovToken})
            {
                # TODO: https://github.com/PoshCode/PSGit/blob/dev/test/Send-CodeCov.ps1
                Trace-Message "Sending CI Code-Coverage Results" -Verbose:(!$Quiet)
                $response = &"$TestPath\Send-CodeCov" -CodeCoverage $result.CodeCoverage -RepositoryRoot $Path -OutputPath $OutputPath -Token ${CodeCovToken}
                Trace-Message $response.message -Verbose:(!$Quiet)
            }
        }
    }

    # If we're on AppVeyor ....
    if(Get-Command Add-AppveyorCompilationMessage -ErrorAction SilentlyContinue) {
        Add-AppveyorCompilationMessage -Message ("{0} of {1} tests passed" -f @($TestResults.PassedScenarios).Count, (@($TestResults.PassedScenarios).Count + @($TestResults.FailedScenarios).Count)) -Category $(if(@($TestResults.FailedScenarios).Count -gt 0) { "Warning" } else { "Information"})
        Add-AppveyorCompilationMessage -Message ("{0:P} of code covered by tests" -f ($TestResults.CodeCoverage.NumberOfCommandsExecuted / $TestResults.CodeCoverage.NumberOfCommandsAnalyzed)) -Category $(if($TestResults.CodeCoverage.NumberOfCommandsExecuted -lt $TestResults.CodeCoverage.NumberOfCommandsAnalyzed) { "Warning" } else { "Information"})
    }

    if(${JobID}) {
        if(Test-Path $Options.OutputFile) {
            Trace-Message "Sending Test Results to AppVeyor backend" -Verbose:(!$Quiet)
            $wc = New-Object 'System.Net.WebClient'
            if($response = $wc.UploadFile("https://ci.appveyor.com/api/testresults/nunit/${JobID}", $Options.OutputFile)) {
                if($text = [System.Text.Encoding]::ASCII.GetString($response)) {
                    Trace-Message $text -Verbose:(!$Quiet)
                } else {
                    Trace-Message "No text in response from AppVeyor" -Verbose:(!$Quiet)
                }
            } else {
                Trace-Message "No response when calling UploadFile to AppVeyor" -Verbose:(!$Quiet)
            }
        } else {
            Write-Warning "Couldn't find Test Output: $($Options.OutputFile)"
        }
    }

    if($FailedTestsCount -gt $FailLimit) {
        $exception = New-Object AggregateException "Failed Scenarios:`n`t`t'$($TestResults.FailedScenarios.Name -join "'`n`t`t'")'"
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "FailedScenarios", "LimitsExceeded", $TestResults
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}


init

# Build Metadata and remove it's psd1 file
$MetadataInfo = Build-Module -Target CleanBuild $Path\Source\Metadata -ModuleVersion $Version `
                             -OutputDirectory "$Path\$($Version.ToString(3))" `
                             -Verbose:($VerbosePreference -eq "Continue") `
                             -Passthru

# Build Configuration
$ConfigurationInfo = Build-Module -Target Build $Path\Source\Configuration `
                                  -OutputDirectory "$Path\$($Version.ToString(3))" `
                                  -ModuleVersion $Version `
                                  -Verbose:($VerbosePreference -eq "Continue") `
                                  -Passthru

# combine the exports of both modules
Update-Metadata -Path $ConfigurationInfo.Path -PropertyName FunctionsToExport -Value @($MetadataInfo.ExportedFunctions.Keys + $ConfigurationInfo.ExportedFunctions.Keys + @('*'))

test