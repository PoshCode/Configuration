#requires -Version "4.0" -Module PackageManagement, Pester
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
    $Script:SourcePath = "src", "source", ${ModuleName} | ForEach-Object { Join-Path $Path $_ -Resolve -ErrorAction Ignore } | Select-Object -First 1
    if(!$SourcePath) {
        Write-Warning "This Build script expects a 'Source' or '$ModuleName' folder to be alongside it."
        throw "Can't find module source folder."
    }

    $Script:ManifestPath = Join-Path $SourcePath "${ModuleName}.psd1" -Resolve -ErrorAction Ignore
    if(!$ManifestPath) {
        Write-Warning "This Build script expects a '${ModuleName}.psd1' in the '$SourcePath' folder."
        throw "Can't find module source files"
    }
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

function clean {
    #.Synopsis
    #   Clean output and old log
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ReleasePath = $Script:ReleasePath,

        # Also clean packages
        [Switch]$Packages
    )

    Trace-Message "OUTPUT Release Path: $ReleasePath"
    if(Test-Path $ReleasePath) {
        Trace-Message "       Clean up old build"
        Trace-Message "DELETE $ReleasePath\"
        Remove-Item $ReleasePath -Recurse -Force
    }
    if(Test-Path $Path\packages) {
        Trace-Message "DELETE $Path\packages"
        # force reinstall by cleaning the old ones
        Remove-Item $Path\packages\ -Recurse -Force
    }
    if(Test-Path $Path\packages\build.log) {
        Trace-Message "DELETE $OutputPath\build.log"
        Remove-Item $OutputPath\build.log -Recurse -Force
    }

}

function update {
    #.Synopsis
    #   Nuget restore and git submodule update
    #.Description
    #   This works like nuget package restore, but using PackageManagement
    #   The benefit of using PackageManagement is that you can support any provider and any source
    #   However, currently only the nuget providers supports a -Destination
    #   So for most cases, you could use nuget restore instead:
    #      nuget restore $(Join-Path $Path packages.config) -PackagesDirectory "$Path\packages" -ExcludeVersion -PackageSaveMode nuspec
    [CmdletBinding()]
    param(
        # Force reinstall
        [switch]$Force=$($Step -contains "Clean"),

        # Remove packages first
        [switch]$Clean
    )
    $ErrorActionPreference = "Stop"
    Set-StrictMode -Version Latest
    Trace-Message "UPDATE $ModuleName in $Path"

    if(Test-Path (Join-Path $Path packages.config)) {
        if(!($Name = Get-PackageSource | Where-Object Location -eq 'https://www.nuget.org/api/v2' | ForEach-Object Name)) {
            Write-Warning "Adding NuGet package source"
            $Name = Register-PackageSource NuGet -Location 'https://www.nuget.org/api/v2' -ForceBootstrap -ProviderName NuGet | Where-Object Name
        }

        if($Force -and (Test-Path $Path\packages)) {
            # force reinstall by cleaning the old ones
            remove-item $Path\packages\ -Recurse -Force
        }
        if(Test-Path $Path\packages\ -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at '$Path\packages\'"
        }
        if(!(Test-Path $Path\packages\ -PathType Container)) {
            $null = New-Item $Path\packages\ -Type Directory -Force
        }

        # Remember, as of now, only nuget actually supports the -Destination flag
        foreach($Package in ([xml](Get-Content .\packages.config)).packages.package) {
            Trace-Message "Installing $($Package.id) v$($Package.version) from $($Package.Source)"
            $null = Install-Package -Name $Package.id -RequiredVersion $Package.version -Source $Package.Source -Destination $Path\packages -Force:$Force -ErrorVariable failure
            if($failure) {
                throw "Failed to install $($package.id), see errors above."
            }
        }
    }

    # we also check for git submodules...
    git submodule update --init --recursive
}

function build {
    [CmdletBinding()]
    param()
    Trace-Message "BUILDING: $ModuleName from $Path"
    # Copy NuGet dependencies
    $PackagesConfig = (Join-Path $Path packages.config)
    if(Test-Path $PackagesConfig) {
        Trace-Message "       Copying Packages"
        foreach($Package in ([xml](Get-Content $PackagesConfig)).packages.package) {
            $LibPath = "$ReleasePath\lib"
            $folder = Join-Path $Path "packages\$($Package.id)*"

            # The git NativeBinaries are special -- we need to copy all the "windows" binaries:
            if($Package.id -eq "LibGit2Sharp.NativeBinaries") {
                $targets = Join-Path $folder 'libgit2\windows'
                $LibPath = Join-Path $LibPath "NativeBinaries"
            } else {
                # Check for each TargetFramework, in order of preference, fall back to using the lib folder
                $targets = ($TargetFramework -replace '^','lib\') + 'lib' | ForEach-Object { Join-Path $folder $_ }
            }

            $PackageSource = Get-Item $targets -ErrorAction SilentlyContinue | Select-Object -First 1 -Expand FullName
            if(!$PackageSource) {
                throw "Could not find a lib folder for $($Package.id) from package. You may need to run Setup.ps1"
            }

            Trace-Message "robocopy $PackageSource $LibPath /E /NP /LOG+:'$OutputPath\build.log' /R:2 /W:15"
            $null = robocopy $PackageSource $LibPath /E /NP /LOG+:"$OutputPath\build.log" /R:2 /W:15
            if($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1 -and $LASTEXITCODE -ne 3) {
                throw "Failed to copy Package $($Package.id) (${LASTEXITCODE}), see build.log for details"
            }
        }
    }

    $RootModule = Get-Module $ManifestPath -ListAvailable | Select-Object -ExpandProperty RootModule
    if (!$RootModule) {
        $RootModule = Get-Module $ManifestPath -ListAvailable | Select-Object -ExpandProperty ModuleToProcess
        if (!$RootModule) {
            $RootModule = "${ModuleName}.psm1"
        }
    }

    $ReleaseModule = Join-Path $ReleasePath ${RootModule}

    ## Copy PowerShell source Files (support for my new Public|Private folders, and the old simple copy way)
    # if the Source folder has "Public" and optionally "Private" in it, then the psm1 must be assembled:
    if(Test-Path (Join-Path $SourcePath Public) -Type Container){
        Trace-Message "       Collating Module Source"
        if(Test-Path $ReleasePath -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at '$ReleasePath'"
        }
        if(!(Test-Path $ReleasePath -PathType Container)) {
            $null = New-Item $ReleasePath -Type Directory -Force
        }

        Trace-Message "       Setting content for $ReleaseModule"

        $FunctionsToExport = Join-Path $SourcePath Public\*.ps1 -Resolve | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }
        Set-Content $ReleaseModule ((
            (Get-Content (Join-Path $SourcePath Private\*.ps1) -Raw) +
            (Get-Content (Join-Path $SourcePath Public\*.ps1) -Raw)) -join "`r`n`r`n`r`n") -Encoding UTF8

        # If there are any folders that aren't Public, Private, Tests, or Specs ...
        $OtherFolders = Get-ChildItem $SourcePath -Directory -Exclude Public, Private, Tests, Specs
        # Then we need to copy everything in them
        Copy-Item $OtherFolders -Recurse -Destination $ReleasePath

        # Finally, we need to copy any files in the Source directory
        Get-ChildItem $SourcePath -File |
            Where-Object Name -ne $RootModule |
            Copy-Item -Destination $ReleasePath

        Update-Manifest $ReleaseManifest -Property FunctionsToExport -Value $FunctionsToExport
    } else {
        # Legacy modules just have "stuff" in the source folder and we need to copy all of it
        Trace-Message "       Copying Module Source"
        Trace-Message "COPY   $SourcePath\"
        $null = robocopy $SourcePath\  $ReleasePath /E /NP /LOG+:"$OutputPath\build.log" /R:2 /W:15
        if($LASTEXITCODE -ne 3 -AND $LASTEXITCODE -ne 1) {
            throw "Failed to copy Module (${LASTEXITCODE}), see build.log for details"
        }
    }

    # Copy the readme file as an about_ help
    $ReadMe = Join-Path $Path Readme.md
    if(Test-Path $ReadMe -PathType Leaf) {
        $LanguagePath = Join-Path $ReleasePath $DefaultLanguage
        if(Test-Path $LanguagePath -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at '$LanguagePath'"
        }
        if(!(Test-Path $LanguagePath -PathType Container)) {
            $null = New-Item $LanguagePath -Type Directory -Force
        }

        $about_module = Join-Path $LanguagePath "about_${ModuleName}.help.txt"
        if(!(Test-Path $about_module)) {
            Trace-Message "Turn readme into about_module"
            Copy-Item -LiteralPath $ReadMe -Destination $about_module
        }
    }

    ## Update the PSD1 Version:
    Trace-Message "       Update Module Version"
    Push-Location $ReleasePath
    try {
        Import-Module $ReleaseModule -Force
        $FileList = Get-ChildItem -Recurse -File | Resolve-Path -Relative
        Update-Metadata -Path $ReleaseManifest -PropertyName 'ModuleVersion' -Value $Version
        Update-Metadata -Path $ReleaseManifest -PropertyName 'FileList' -Value $FileList
        Import-Module $ReleaseManifest -Force
    } finally {
        Pop-Location
    }
    (Get-Module $ReleaseManifest -ListAvailable | Out-String -stream) -join "`n" | Trace-Message
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
    Remove-Module $ModuleName -ErrorAction SilentlyContinue
    Write-Host $(prompt) -NoNewLine
    Write-Host Remove-Module $ModuleName -ErrorAction SilentlyContinue

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

function package {
    [CmdletBinding()]
    param()

    Trace-Message "robocopy '$ReleasePath' '${OutputPath}\${ModuleName}' /MIR /NP "
    $null = robocopy $ReleasePath "${OutputPath}\${ModuleName}" /MIR /NP /LOG+:"$OutputPath\build.log"

    # Obviously this should be Publish-Module, but this works on appveyor
    $zipFile = Join-Path $OutputPath "${ModuleName}-${Version}.zip"
    Add-Type -assemblyname System.IO.Compression.FileSystem
    Remove-Item $zipFile -ErrorAction SilentlyContinue
    Trace-Message "ZIP    $zipFile"
    [System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $OutputPath $ModuleName), $zipFile)

    # You can add other artifacts here
    ls $OutputPath -File
}

function Trace-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Message,

        [switch]$AsWarning,

        [switch]$ResetTimer,

        [switch]$KillTimer,

        [Diagnostics.Stopwatch]$Stopwatch
    )
    begin {
        if($Stopwatch) {
            $Script:TraceTimer = $Stopwatch
            $Script:TraceTimer.Start()
        }
        if(!(Test-Path Variable:Script:TraceTimer)) {
            $Script:TraceTimer = New-Object System.Diagnostics.Stopwatch
            $Script:TraceTimer.Start()
        }
        if($ResetTimer)
        {
            $Script:TraceTimer.Restart()
        }
    }

    process {
        $Script = Split-Path $MyInvocation.ScriptName -Leaf
        $Command = (Get-PSCallStack)[1].Command
        if($Script -ne $Command) {
            $Message = "{0} - at {1} Line {2} ({4}) | {3}" -f $Message, $Script, $MyInvocation.ScriptLineNumber, $TraceTimer.Elapsed, $Command
        } else {
            $Message = "{0} - at {1} Line {2} | {3}" -f $Message, $Script, $MyInvocation.ScriptLineNumber, $TraceTimer.Elapsed
        }

        if($AsWarning) {
            Write-Warning $Message
        } else {
            Write-Verbose $Message
        }
    }

    end {
        if($KillTimer) {
            $Script:TraceTimer.Stop()
            $Script:TraceTimer = $null
        }
    }
}

# First call to Trace-Message, pass in our TraceTimer to make sure we time EVERYTHING.
Trace-Message "BUILDING: $ModuleName in $Path" -Stopwatch $TraceVerboseTimer

Push-Location $Path

init

foreach($s in $step){
    Trace-Message "Invoking Step: $s"
    &$s
}

Pop-Location
Trace-Message "FINISHED: $ModuleName in $Path" -KillTimer