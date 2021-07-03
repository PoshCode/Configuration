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
    # PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Callstack', Justification = 'This is referenced in ParameterBinder')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Module', Justification = 'This is referenced in ParameterBinder')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DefaultPath', Justification = 'This is referenced in ParameterBinder')]
    [CmdletBinding(DefaultParameterSetName = '__ModuleInfo', SupportsShouldProcess)]
    param(
        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

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

        # DefaultPath is IGNORED.
        # The parameter was here to match Import-Configuration, but it is meaningless in Export-Configuration
        # The only reason I haven't removed it is that I don't want to break any code that might be using it.
        # TODO: If we release a breaking changes Configuration 2.0, remove this parameter
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName = $true)]
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
        if (!$Name) {
            throw "Could not determine the storage name, Export-Configuration should only be called from inside a script or module, or by piping ModuleInfo to it."
        }

        $Parameters = @{
            CompanyName = $CompanyName
            Name        = $Name
        }
        if ($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-ConfigurationPath @Parameters -Scope $Scope

        $ConfigurationPath = Join-Path $MachinePath "Configuration.psd1"

        $InputObject | Export-Metadata $ConfigurationPath -AsHashtable:$AsHashtable
    }
}
