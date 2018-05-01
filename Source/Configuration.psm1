# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters     = @{},
    $EnterpriseData,
    $UserData,
    $MachineData
)

$ConfigurationRoot = Get-Variable PSScriptRoot* -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "PSScriptRoot" } | ForEach-Object { $_.Value }
if(!$ConfigurationRoot) {
    $ConfigurationRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

function InitializeStoragePaths {
    [CmdletBinding()]
    param(
        $EnterpriseData,
        $UserData,
        $MachineData
    )

    $PathOverrides = $MyInvocation.MyCommand.Module.PrivateData.PathOverride

    # Where the user's personal configuration settings go.
    # Highest presedence, overrides all other settings.
    if ([string]::IsNullOrWhiteSpace($UserData)) {
        if (!($UserData = $PathOverrides.UserData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to $Env:XDG_CONFIG_HOME on Linux or MacOS ($HOME/.config/)
                if (!($UserData = $Env:XDG_CONFIG_HOME)) {
                    $UserData = Join-Path $HOME .config/
                }
            } else {
                # Defaults to $Env:LocalAppData on Windows
                if (!($UserData = $Env:LocalAppData)) {
                    $UserData = [Environment]::GetFolderPath("LocalApplicationData")
                }
            }
        }
    }

    # On some systems there are "roaming" user configuration stored in the user's profile. Overrides machine configuration
    if ([string]::IsNullOrWhiteSpace($EnterpriseData)) {
        if (!($EnterpriseData = $PathOverrides.EnterpriseData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to the first value in $Env:XDG_CONFIG_DIRS on Linux or MacOS (or $HOME/.local/share/)
                if (!($EnterpriseData = @($Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator))[0] )) {
                    $EnterpriseData = Join-Path $HOME .local/share/
                }
            } else {
                # Defaults to $Env:AppData on Windows
                if (!($EnterpriseData = $Env:AppData)) {
                    $EnterpriseData = [Environment]::GetFolderPath("ApplicationData")
                }
            }
        }
    }

    # Machine specific configuration. Overrides defaults, but is overriden by both user roaming and user local settings
    if ([string]::IsNullOrWhiteSpace($MachineData)) {
        if (!($MachineData = $PathOverrides.MachineData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to /etc/xdg elsewhere
                $XdgConfigDirs = $Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator) | Where-Object { $_ -and (Test-Path $_) }
                if (!($MachineData = if ($XdgConfigDirs.Count -gt 1) {
                            $XdgConfigDirs[1]
                        })) {
                    $MachineData = "/etc/xdg/"
                }
            } else {
                # Defaults to $Env:ProgramData on Windows
                if (!($MachineData = $Env:ProgramAppData)) {
                    $MachineData = [Environment]::GetFolderPath("CommonApplicationData")
                }
            }
        }
    }

    Join-Path $EnterpriseData powershell
    Join-Path $UserData powershell
    Join-Path $MachineData powershell
}

$EnterpriseData, $UserData, $MachineData = InitializeStoragePaths $EnterpriseData $UserData $MachineData

Import-Module "${ConfigurationRoot}\Metadata.psm1" -Force -Args @($Converters) -Verbose:$false

function ParameterBinder {
    if(!$Module) {
        [System.Management.Automation.PSModuleInfo]$Module = . {
            $Command = ($CallStack)[0].InvocationInfo.MyCommand
            $mi = if($Command.ScriptBlock -and $Command.ScriptBlock.Module) {
                $Command.ScriptBlock.Module
            } else {
                $Command.Module
            }

            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object { ($_.Name -eq $mi.Name) -and $_.ExportedCommands } | Select-Object -First 1) {
                   $mi = $mi2
                }
            }
            $mi
        }
    }

    if(!$CompanyName) {
        [String]$CompanyName = . {
            if($Module){
                $CName = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($CName -eq "Unknown" -or -not $CName) {
                    $CName = $Module.Author
                    if($CName -eq "Unknown" -or -not $CName) {
                        $CName = "AnonymousModules"
                    }
                }
                $CName
            } else {
                "AnonymousScripts"
            }
        }
    }

    if(!$Name) {
        [String]$Name = $(if($Module) { $Module.Name } <# else { ($CallStack)[0].InvocationInfo.MyCommand.Name } #>)
    }

    if(!$DefaultPath -and $Module) {
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 })
    }
}

function Get-ConfigurationPath {
    #.Synopsis
    #   Gets an storage path for configuration files and data
    #.Description
    #   Gets an AppData (or roaming profile) or ProgramData path for configuration and data storage. The folder returned is guaranteed to exist (which means calling this function actually creates folders).
    #
    #   Get-ConfigurationPath is designed to be called from inside a module function WITHOUT any parameters.
    #
    #   If you need to call Get-ConfigurationPath from outside a module, you should pipe the ModuleInfo to it, like:
    #   Get-Module Powerline | Get-ConfigurationPath
    #
    #   As a general rule, there are three scopes which result in three different root folders
    #       User:       $Env:LocalAppData
    #       Machine:    $Env:ProgramData
    #       Enterprise: $Env:AppData (which is the "roaming" folder of AppData)
    #
    #.NOTES
    #   1.  This command is primarily meant to be used in modules, to find a place where they can serialize data for storage.
    #   2.  It's techincally possible for more than one module to exist with the same name.
    #       The command uses the Author or Company as a distinguishing name.
    #
    #.Example
    #   $CacheFile = Join-Path (Get-ConfigurationPath) Data.clixml
    #   $Data | Export-CliXML -Path $CacheFile
    #
    #   This example shows how to use Get-ConfigurationPath with Export-CliXML to cache data as clixml from inside a module.
    [Alias("Get-StoragePath")]
    [CmdletBinding(DefaultParameterSetName = '__ModuleInfo')]
    param(
        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [ValidateSet("User", "Machine", "Enterprise")]
        [string]$Scope = "Enterprise",

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version,

        # By default, Get-ConfigurationPath creates the folder if it doesn't already exist
        # This switch allows overriding that behavior: if set, does not create missing paths
        [Switch]$SkipCreatingFolder
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
        if(Test-Path $PathRoot) {
            $PathRoot = Resolve-Path $PathRoot
        } elseif(!$SkipCreatingFolder) {
            Write-Warning "The $Scope path $PathRoot cannot be found"
        }
    }

    process {
        . ParameterBinder

        if(!$Name) {
            Write-Error "Empty Name ($Name) in $($PSCmdlet.ParameterSetName): $($PSBoundParameters | Format-List | Out-String)"
            throw "Could not determine the storage name, Get-ConfigurationPath should only be called from inside a script or module."
        }
        $CompanyName = $CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
        if($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        if(Test-Path $PathRoot -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at $PathRoot"
        }

        if(!$SkipCreatingFolder -and !(Test-Path $PathRoot -PathType Container)) {
            $null = New-Item $PathRoot -Type Directory -Force
        }

        # Note: this used to call Resolve-Path
        $PathRoot
    }
}

function Export-Configuration {
    <#
        .Synopsis
            Exports a configuration object to a specified path.
        .Description
            Exports the configuration object to a file, by default, in the Roaming AppData location

            NOTE: this exports the FULL configuration to this file, which will override both defaults and local machine configuration when Import-Configuration is used.
        .Example
            @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now } | Export-Configuration

            This example shows how to use Export-Configuration in your module to cache some data.

        .Example
            Get-Module Configuration | Export-Configuration @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now }

            This example shows how to use Export-Configuration to export data for use in a specific module.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(DefaultParameterSetName='__ModuleInfo',SupportsShouldProcess)]
    param(
        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,


        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath,

        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Parameter(ParameterSetName = "ManualOverride")]
        [ValidateSet("User", "Machine", "Enterprise")]
        [string]$Scope = "Enterprise",

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )
    process {
        . ParameterBinder
        if(!$Name) {
            throw "Could not determine the storage name, Export-Configuration should only be called from inside a script or module, or by piping ModuleInfo to it."
        }

        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope $Scope

        $ConfigurationPath = Join-Path $MachinePath "Configuration.psd1"

        $InputObject | Export-Metadata $ConfigurationPath -AsHashtable:$AsHashtable
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
        [System.Management.Automation.PSModuleInfo]$Module,

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name,

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath,

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *never* calculated, if you use version numbers, you must manage them on your own
        [Version]$Version,

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered
    )
    begin {
        # Write-Debug "Import-Configuration for module $Name"
    }
    process {
        . ParameterBinder

        if(!$Name) {
            throw "Could not determine the configuration name. When you are not calling Import-Configuration from a module, you must specify the -Author and -Name parameter"
        }

        if($DefaultPath -and (Test-Path $DefaultPath -Type Container)) {
            $DefaultPath = Join-Path $DefaultPath Configuration.psd1
        }

        $Configuration = if($DefaultPath -and (Test-Path $DefaultPath)) {
                             Import-Metadata $DefaultPath -ErrorAction Ignore -Ordered:$Ordered
                         } else { @{} }
        # Write-Debug "Module Configuration: ($DefaultPath)`n$($Configuration | Out-String)"


        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope Machine -SkipCreatingFolder
        $MachinePath = Join-Path $MachinePath Configuration.psd1
        $Machine = if(Test-Path $MachinePath) {
                    Import-Metadata $MachinePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        # Write-Debug "Machine Configuration: ($MachinePath)`n$($Machine | Out-String)"


        $EnterprisePath = Get-ConfigurationPath @Parameters -Scope Enterprise -SkipCreatingFolder
        $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
        $Enterprise = if(Test-Path $EnterprisePath) {
                    Import-Metadata $EnterprisePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        # Write-Debug "Enterprise Configuration: ($EnterprisePath)`n$($Enterprise | Out-String)"

        $LocalUserPath = Get-ConfigurationPath @Parameters -Scope User -SkipCreatingFolder
        $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
        $LocalUser = if(Test-Path $LocalUserPath) {
                    Import-Metadata $LocalUserPath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        # Write-Debug "LocalUser Configuration: ($LocalUserPath)`n$($LocalUser | Out-String)"

        $Configuration | Update-Object $Machine |
                         Update-Object $Enterprise |
                         Update-Object $LocalUser
    }
}
