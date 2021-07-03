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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Callstack', Justification = 'This is referenced in ParameterBinder')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Module', Justification = 'This is referenced in ParameterBinder')]
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DefaultPath', Justification = 'This is referenced in ParameterBinder')]
    [CmdletBinding(DefaultParameterSetName = '__CallStack')]
    param(
        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Management.Automation.PSModuleInfo]$Module,

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Author")]
        [String]$CompanyName,

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Name,

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName = $true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath,

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *never* calculated, if you use version numbers, you must manage them on your own
        [Version]$Version,

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered,

        # Allows extending the valid variables which are allowed to be referenced in configuration
        # BEWARE: This exposes the value of these variables in the calling context to the configuration file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables
    )
    begin {
        # Write-Debug "Import-Configuration for module $Name"
    }
    process {
        . ParameterBinder

        if (!$Name) {
            throw "Could not determine the configuration name. When you are not calling Import-Configuration from a module, you must specify the -Author and -Name parameter"
        }

        $MetadataOptions = @{
            AllowedVariables = $AllowedVariables
            PSVariable       = $PSCmdlet.SessionState.PSVariable
            Ordered          = $Ordered
            ErrorAction      = "Ignore"
        }

        if ($DefaultPath -and (Test-Path $DefaultPath -Type Container)) {
            $DefaultPath = Join-Path $DefaultPath Configuration.psd1
        }

        $Configuration = if ($DefaultPath -and (Test-Path $DefaultPath)) {
            Import-Metadata $DefaultPath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "Module Configuration: ($DefaultPath)`n$($Configuration | Out-String)"


        $Parameters = @{
            CompanyName = $CompanyName
            Name        = $Name
        }
        if ($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope Machine -SkipCreatingFolder
        $MachinePath = Join-Path $MachinePath Configuration.psd1
        $Machine = if (Test-Path $MachinePath) {
            Import-Metadata $MachinePath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "Machine Configuration: ($MachinePath)`n$($Machine | Out-String)"


        $EnterprisePath = Get-ConfigurationPath @Parameters -Scope Enterprise -SkipCreatingFolder
        $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
        $Enterprise = if (Test-Path $EnterprisePath) {
            Import-Metadata $EnterprisePath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "Enterprise Configuration: ($EnterprisePath)`n$($Enterprise | Out-String)"

        $LocalUserPath = Get-ConfigurationPath @Parameters -Scope User -SkipCreatingFolder
        $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
        $LocalUser = if (Test-Path $LocalUserPath) {
            Import-Metadata $LocalUserPath @MetadataOptions
        } else {
            @{}
        }
        # Write-Debug "LocalUser Configuration: ($LocalUserPath)`n$($LocalUser | Out-String)"

        $Configuration | Update-Object $Machine |
            Update-Object $Enterprise |
            Update-Object $LocalUser
    }
}
