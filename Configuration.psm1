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

Import-Module "${ConfigurationRoot}\Metadata.psm1" -Force -Args @($Converters)

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
    [CmdletBinding(DefaultParameterSetName = '__ModuleInfo')]
    param(
        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Security.PolicyLevelType]$Scope = "Enterprise",

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module = $(
            $mi = ($CallStack)[0].InvocationInfo.MyCommand.Module
            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object Name -eq $mi.Name | Where-Object ExportedCommands | Select-Object -First 1) {
                   return $mi2
                }
            }
            return $mi
        ),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName = $(
            if($Module){
                $Name = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $Module.Author
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
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name = $(if($Module) { $Module.Name }),

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 }),


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

    process {
        if(!$Name) {
            throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
        }
        $CompanyName = $CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"

        Write-Verbose "Storage Root: $PathRoot"
        $PathRoot = Join-Path $PathRoot $Type

        if($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        Write-Verbose "Storage Path: $PathRoot"

        # Note: avoid using Convert-Path because drives aliases like "TestData:" get converted to a C:\ file system location
        $null = mkdir $PathRoot -Force
        (Resolve-Path $PathRoot).Path
    }
}

function Export-Configuration {
    #.Synopsis
    #   Exports a configuration object to a specified path.
    #.Description
    #   Exports the configuration object to a file, by default, in the Roaming AppData location
    #
    #   NOTE: this exports the FULL configuration to this file, which will override both defaults and local machine configuration when Import-Configuration is used.
    #.Example
    #   @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now } | Export-Configuration
    #
    #   This example shows how to use Export-Configuration in your module to cache some data.
    #
    #.Example
    #   Get-Module Configuration | Export-Configuration @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now }
    #
    #   This example shows how to use Export-Configuration to export data for use in a specific module.
    #
    [CmdletBinding(DefaultParameterSetName='__ModuleInfo',SupportsShouldProcess)]
    param(
        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        $InputObject,

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module = $(
            $mi = ($CallStack)[0].InvocationInfo.MyCommand.Module
            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object Name -eq $mi.Name | Where-Object ExportedCommands | Select-Object -First 1) {
                   return $mi2
                }
            }
            return $mi
        ),


        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName = $(
            if($Module){
                $Name = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $Module.Author
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
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name = $(if($Module) { $Module.Name }),

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 }),

        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Parameter(ParameterSetName = "ManualOverride")]
        [Security.PolicyLevelType]$Scope = "Enterprise",

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )
    process {
        if(!$Name) {
            throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
        }

        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-StoragePath @Parameters -Scope $Scope

        $ConfigurationPath = Join-Path $MachinePath "Configuration.psd1"

        $InputObject | Export-Metadata $ConfigurationPath
    }
}

function Import-Configuration {
    #.Synopsis
    #   Import the full, layered configuration for the module.
    #.Description
    #   Imports the DefaultPath Configuration file, and then imports the Machine, Roaming (enterprise), and local config files, if they exist.
    #   Each configuration file is layered on top of the one before (so only needs to set values which are different)
    #.Example
    #   $Configuration = Import-Configuration
    #
    #   This example shows how to use Import-Configuration in your module to load the cached data
    #
    #.Example
    #   $Configuration = Get-Module Configuration | Import-Configuration
    #
    #   This example shows how to use Import-Configuration in your module to load data cached for another module
    #
    [CmdletBinding(DefaultParameterSetName = '__CallStack')]
    param(
        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module = $(
            $mi = ($CallStack)[0].InvocationInfo.MyCommand.Module
            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object Name -eq $mi.Name | Where-Object ExportedCommands | Select-Object -First 1) {
                   return $mi2
                }
            }
            return $mi
        ),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName = $(
            if($Module){
                $Name = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $Module.Author
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
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name = $(if($Module) { $Module.Name }),

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 }),

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *never* calculated, if you use version numbers, you must manage them on your own
        [Version]$Version,

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered
    )
    begin {
        Write-Verbose "Module Name $Name"
    }
    process {
        if(!$Name) {
            throw "Could not determine the configuration name. When you are not calling Import-Configuration from a module, you must specify the -Author and -Name parameter"
        }        

        if(Test-Path $DefaultPath -Type Container) {
            $DefaultPath = Join-Path $DefaultPath Configuration.psd1
        }

        Write-Verbose "PSBoundParameters $($PSBoundParameters | Out-String)"
        $Configuration = if(Test-Path $DefaultPath) {
                             Import-Metadata $DefaultPath -ErrorAction Ignore -Ordered:$Ordered
                         } else { @{} }
        Write-Verbose "Module ($DefaultPath)`n$($Configuration | Out-String)"

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
                    Import-Metadata $MachinePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        Write-Verbose "Machine ($MachinePath)`n$($Machine | Out-String)"


        $EnterprisePath = Get-StoragePath @Parameters -Scope Enterprise
        $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
        $Enterprise = if(Test-Path $EnterprisePath) {
                    Import-Metadata $EnterprisePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        Write-Verbose "Enterprise ($EnterprisePath)`n$($Enterprise | Out-String)"

        $LocalUserPath = Get-StoragePath @Parameters -Scope User
        $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
        $LocalUser = if(Test-Path $LocalUserPath) {
                    Import-Metadata $LocalUserPath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        Write-Verbose "LocalUser ($LocalUserPath)`n$($LocalUser | Out-String)"

        $Configuration | Update-Object $Machine |
                         Update-Object $Enterprise |
                         Update-Object $LocalUser
    }
}