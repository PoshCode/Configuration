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
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath", "Content")]
        [string]$Path,

        [Hashtable]$Converters = @{},

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered
    )
    process {
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
            ConvertFrom-Metadata -InputObject $Path -Converters $Converters -Ordered:$Ordered
        } catch {
            ThrowError $_
        }
    }
}
