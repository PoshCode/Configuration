function Import-Metadata {
    <#
      .Synopsis
         Creates a data object from the items in a Metadata file (e.g. a .psd1)
      .Description
         Serves as a wrapper for ConvertFrom-Metadata to explicitly support importing from files
      .Example
         $data = Import-Metadata .\Configuration.psd1 -Ordered

         Convert a module manifest into a hashtable of properties for introspection, preserving the order in the file
   #>
    [CmdletBinding()]
    param(
        # The path to the metadata (.psd1) file to import
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath", "Content")]
        [string]$Path,

        # A hashtable of MetadataConverters (same as with Add-MetadataConverter)
        [Hashtable]$Converters = @{},

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered,

        # Allows extending the valid variables which are allowed to be referenced in metadata
        # BEWARE: This exposes the value of these variables in the calling context to the metadata file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables,

        # You should not pass this.
        # The PSVariable parameter is for preserving variable scope within the Metadata commands
        [System.Management.Automation.PSVariableIntrinsics]$PSVariable
    )
    process {
        if (!$PSVariable) {
            $PSVariable = $PSCmdlet.SessionState.PSVariable
        }
        if (Test-Path $Path) {
            # Write-Debug "Importing Metadata file from `$Path: $Path"
            if (!(Test-Path $Path -PathType Leaf)) {
                $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
            }
        }
        if (!(Test-Path $Path)) {
            WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                -Message "Can't find file $Path" `
                -ErrorId "PathNotFound,Metadata\Import-Metadata" `
                -Category "ObjectNotFound"
            return
        }
        try {
            ConvertFrom-Metadata -InputObject $Path -Converters $Converters -Ordered:$Ordered -AllowedVariables $AllowedVariables -PSVariable $PSVariable
        } catch {
            ThrowError $_
        }
    }
}
