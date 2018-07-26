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
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
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
                "Enterprise" {
                    $EnterpriseData
                }
                "User" {
                    $UserData
                }
                "Machine" {
                    $MachineData
                }
                # This should be "Process" scope, but what does that mean?
                # "AppDomain"  { $MachineData }
                default {
                    $EnterpriseData
                }
            })
        if (Test-Path $PathRoot) {
            $PathRoot = Resolve-Path $PathRoot
        } elseif (!$SkipCreatingFolder) {
            Write-Warning "The $Scope path $PathRoot cannot be found"
        }
    }

    process {
        . ParameterBinder

        if (!$Name) {
            Write-Error "Empty Name ($Name) in $($PSCmdlet.ParameterSetName): $($PSBoundParameters | Format-List | Out-String)"
            throw "Could not determine the storage name, Get-ConfigurationPath should only be called from inside a script or module."
        }
        $CompanyName = $CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]", "_"
        if ($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if ($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        if (Test-Path $PathRoot -PathType Leaf) {
            throw "Cannot create folder for Configuration because there's a file in the way at $PathRoot"
        }

        if (!$SkipCreatingFolder -and !(Test-Path $PathRoot -PathType Container)) {
            $null = New-Item $PathRoot -Type Directory -Force
        }

        # Note: this used to call Resolve-Path
        $PathRoot
    }
}
