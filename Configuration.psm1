# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $EnterpriseData = $Env:AppData,
    $UserData       = $Env:LocalAppData,
    $MachineData    = $Env:ProgramData
)

$EnterpriseData = Join-Path $EnterpriseData WindowsPowerShell
$UserData       = Join-Path $UserData   WindowsPowerShell
$MachineData    = Join-Path $MachineData WindowsPowerShell

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
        [Parameter(ParameterSetName = "Scope")]
        [Security.PolicyLevelType]$Scope = "Enterprise",

        # A callstack. You should not ever need to pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The type of storage you're looking for will be automatically detected from the callstack
        [Parameter(ParameterSetName = "ManualOverride")]
        [ValidateSet("Modules", "Scripts")]
        [String]$Type = $(if($CallStack[0].InvocationInfo.MyCommand.Module){"Modules"} else {"Scripts"}),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride")]
        [String]$CompanyName = $(if($CallStack[0].InvocationInfo.MyCommand.Module){$CallStack[0].InvocationInfo.MyCommand.Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"}),

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