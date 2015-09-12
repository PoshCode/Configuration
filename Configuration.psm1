# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters     = @{},
    $EnterpriseData = $Env:AppData,
    $UserData       = $Env:LocalAppData,
    $MachineData    = $Env:ProgramData
)

$EnterpriseData = Join-Path $EnterpriseData WindowsPowerShell
$UserData       = Join-Path $UserData   WindowsPowerShell
$MachineData    = Join-Path $MachineData WindowsPowerShell

$ConfigurationRoot = Get-Variable PSScriptRoot* -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "PSScriptRoot" } | ForEach-Object { $_.Value }
if(!$ConfigurationRoot) {
    $ConfigurationRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

Import-Module "${ConfigurationRoot}\Metadata.psm1" -Args @($Converters)

function Get-StoragePath {
    #.Synopsis
    #   Gets an application storage path outside the module storage folder
    #.Description
    #   Gets an AppData (or roaming profile) or ProgramData path for settings storage
    #
    #   As a general rule, there are three scopes which result in three different root folders
    #       User:       $Env:LocalAppData
    #       Machine:    $Env:ProgramData
    #       Enterprise: $Env:AppData (which is the "roaming" folder of AppData)
    #
    #   WARNINGs:
    #       1.  This command is only meant to be used in modules, to find a place where they can serialize data for storage. It can be used in scripts, but doing so is more risky.
    #       2.  Since there are multiple module paths, it's possible for more than one module to exist with the same name, so you should exercise care
    #
    #   If it doesn't already exist, the folder is created before the path is returned, so you can always trust this folder to exist.
    #   The folder that is returned survives module uninstall/reinstall/upgrade, and this is the lowest level API for the Configuration module, expecting the module author to export data there using other Import/Export cmdlets.
    #.Example
    #   $CacheFile = Join-Path (Get-StoragePath) Data.clixml
    #   $Data | Export-CliXML -Path $CacheFile
    #
    #   This example shows how to use Get-StoragePath with Export-CliXML to cache some data from inside a module.
    #
    [CmdletBinding(DefaultParameterSetName = 'NoParameters')]
    param(
        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Security.PolicyLevelType]$Scope = "Enterprise",

        # A callstack. You should not ever need to pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride")]
        [String]$CompanyName = $(
            if($CallStack[0].InvocationInfo.MyCommand.Module){
                $Name = $CallStack[0].InvocationInfo.MyCommand.Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $CallStack[0].InvocationInfo.MyCommand.Module.Author
                    if($Name -eq "Unknown" -or -not $Name) {
                        $Name = "AnonymousModules"
                    }
                }
                $Name
            } else {
                "AnonymousScripts"
            }
        ),

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride")]
        [String]$Name = $(
            if($Module = $CallStack[0].InvocationInfo.MyCommand.Module) {
                $Module.Name
            } else {
                if(!($BaseName = [IO.Path]::GetFileNameWithoutExtension(($CallStack[0].InvocationInfo.MyCommand.Name -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_")))) {
                    throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
                }
                return $BaseName
            }
        ),

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )
    begin {
        $PathRoot = $(switch ($Scope) {
            "Enterprise" { $EnterpriseData }
            "User"       { $UserData }
            "Machine"    { $MachineData }
            # This should be "Process" scope, but what does that mean?
            # "AppDomain"  { $MachineData }
            default { $EnterpriseData }
        })
    }

    end {
        $PathRoot = Join-Path $PathRoot $Type

        if($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        # Note: avoid using Convert-Path because drives aliases like "TestData:" get converted to a C:\ file system location
        $null = mkdir $PathRoot -Force
        (Resolve-Path $PathRoot).Path
    }
}


function Import-Configuration {
    [CmdletBinding(DefaultParameterSetName = '__CallStack')]
    param(
        # A callstack. You should not ever need to pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride")]
        [String]$CompanyName = $(
            if($CallStack[0].InvocationInfo.MyCommand.Module){
                $Name = $CallStack[0].InvocationInfo.MyCommand.Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $CallStack[0].InvocationInfo.MyCommand.Module.Author
                    if($Name -eq "Unknown" -or -not $Name) {
                        $Name = "AnonymousModules"
                    }
                }
                $Name
            } else {
                "AnonymousScripts"
            }
        ),

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true)]
        [String]$Name = $(
            if($Module = $CallStack[0].InvocationInfo.MyCommand.Module) {
                $Module.Name
            } else {
                if(!($BaseName = [IO.Path]::GetFileNameWithoutExtension(($CallStack[0].InvocationInfo.MyCommand.Name -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_")))) {
                    throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
                }
                return $BaseName
            }
        ),

        # The full path to the module (in case there are dupes)
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride")]
        [String]$ModulePath = $(
            if($Module = $CallStack[0].InvocationInfo.MyCommand.Module) {
                $Module.Path
            } else {
                if(!($BaseName = [IO.Path]::GetFileNameWithoutExtension(($CallStack[0].InvocationInfo.MyCommand.Name -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_")))) {
                    throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
                }
                return $BaseName
            }
        ),
        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )

    $ModulePath = Split-Path $ModulePath -Parent
    $ModulePath = Join-Path $ModulePath Configuration.psd1
    $Local = if(Test-Path $ModulePath) {
                Import-Metadata $ModulePath -ErrorAction Ignore
            } else { @{} }

    $Parameters = @{
        CompanyName = $CompanyName
        Name = $Name
    }
    if($Version) {
        $Parameters.Version = $Version
    }

    $MachinePath = Get-StoragePath @Parameters -Scope Machine
    $MachinePath = Join-Path $MachinePath Configuration.psd1
    $Machine = if(Test-Path $MachinePath) {
                Import-Metadata $MachinePath -ErrorAction Ignore
            } else { @{} }

    $EnterprisePath = Get-StoragePath @Parameters -Scope Enterprise
    $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
    $Enterprise = if(Test-Path $EnterprisePath) {
                Import-Metadata $EnterprisePath -ErrorAction Ignore
            } else { @{} }

    $LocalUserPath = Get-StoragePath @Parameters -Scope User
    $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
    $User = if(Test-Path $LocalUserPath) {
                Import-Metadata $LocalUserPath -ErrorAction Ignore
            } else { @{} }

    $Local | Update-Object $Machine | 
             Update-Object $Enterprise | 
             Update-Object $User
}