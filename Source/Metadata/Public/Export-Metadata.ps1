function Export-Metadata {
    <#
        .Synopsis
            Creates a metadata file from a simple object
        .Description
            Serves as a wrapper for ConvertTo-Metadata to explicitly support exporting to files

            Note that exportable data is limited by the rules of data sections (see about_Data_Sections) and the available MetadataSerializers (see Add-MetadataConverter)

            The only things inherently importable in PowerShell metadata files are Strings, Booleans, and Numbers ... and Arrays or Hashtables where the values (and keys) are all strings, booleans, or numbers.

            Note: this function and the matching Import-Metadata are extensible, and have included support for PSCustomObject, Guid, Version, etc.
        .Example
            $Configuration | Export-Metadata .\Configuration.psd1

            Export a configuration object (or hashtable) to the default Configuration.psd1 file for a module
            The Configuration module uses Configuration.psd1 as it's default config file.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # Specifies the path to the PSD1 output file.
        [Parameter(Mandatory = $true, Position = 0)]
        $Path,

        # comments to place on the top of the file (to explain settings or whatever for people who might edit it by hand)
        [string[]]$CommentHeader,

        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        [Hashtable]$Converters = @{},

        # If set, output the nuspec file
        [Switch]$Passthru
    )
    begin {
        $data = @()
    }
    process {
        $data += @($InputObject)
    }
    end {
        # Avoid arrays when they're not needed:
        if ($data.Count -eq 1) {
            $data = $data[0]
        }
        Set-Content -Encoding UTF8 -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata -InputObject $data -Converters $Converters -AsHashtable:$AsHashtable)) -Join "`n")
        if ($Passthru) {
            Get-Item $Path
        }
    }
}
