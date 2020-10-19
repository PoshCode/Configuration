function ConvertTo-Metadata {
    #.Synopsis
    #  Serializes objects to PowerShell Data language (PSD1)
    #.Description
    #  Converts objects to a texual representation that is valid in PSD1,
    #  using the built-in registered converters (see Add-MetadataConverter).
    #
    #  NOTE: Any Converters that are passed in are temporarily added as though passed Add-MetadataConverter
    #.Example
    #  $Name = @{ First = "Joel"; Last = "Bennett" }
    #  @{ Name = $Name; Id = 1; } | ConvertTo-Metadata
    #
    #  @{
    #    Id = 1
    #    Name = @{
    #      Last = 'Bennett'
    #      First = 'Joel'
    #    }
    #  }
    #
    #  Convert input objects into a formatted string suitable for storing in a psd1 file.
    #.Example
    #  Get-ChildItem -File | Select-Object FullName, *Utc, Length | ConvertTo-Metadata
    #
    #  Convert complex custom types to dynamic PSObjects using Select-Object.
    #
    #  ConvertTo-Metadata understands PSObjects automatically, so this allows us to proceed
    #  without a custom serializer for File objects, but the serialized data
    #  will not be a FileInfo or a DirectoryInfo, just a custom PSObject
    #.Example
    #  ConvertTo-Metadata ([DateTimeOffset]::Now) -Converters @{
    #     [DateTimeOffset] = { "DateTimeOffset {0} {1}" -f $_.Ticks, $_.Offset }
    #  }
    #
    #  Shows how to temporarily add a MetadataConverter to convert a specific type while serializing the current DateTimeOffset.
    #  Note that this serialization would require a "DateTimeOffset" function to exist in order to deserialize properly.
    #
    #  See also the third example on ConvertFrom-Metadata and Add-MetadataConverter.
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The object to convert to metadata
        [Parameter(ValueFromPipeline = $True)]
        $InputObject,

        # Serialize objects as hashtables
        [switch]$AsHashtable,

        # Additional converters
        [Hashtable]$Converters = @{}
    )
    begin {
        $t = "  "
        $Script:OriginalMetadataSerializers = $Script:MetadataSerializers.Clone()
        $Script:OriginalMetadataDeserializers = $Script:MetadataDeserializers.Clone()
        Add-MetadataConverter $Converters
    }
    end {
        $Script:MetadataSerializers = $Script:OriginalMetadataSerializers.Clone()
        $Script:MetadataDeserializers = $Script:OriginalMetadataDeserializers.Clone()
    }
    process {
        if ($Null -eq $InputObject) {
            '""'
        } elseif ($InputObject -is [IPsMetadataSerializable] -or ($InputObject.ToPsMetadata -as [Func[String]] -and $InputObject.FromPsMetasta -as [Action[String]])) {
            "(FromPsMetadata {0} @'`n{1}`n'@)" -f $InputObject.GetType().FullName, $InputObject.ToMetadata()
        } elseif ( $InputObject -is [Int16] -or
                   $InputObject -is [Int32] -or
                   $InputObject -is [Int64] -or
                   $InputObject -is [Double] -or
                   $InputObject -is [Decimal] -or
                   $InputObject -is [Byte] ) {
            "$InputObject"
        } elseif ($InputObject -is [String]) {
            "'{0}'" -f $InputObject.ToString().Replace("'", "''")
        } elseif ($InputObject -is [Collections.IDictionary]) {
            "@{{`n$t{0}`n}}" -f ($(
                    ForEach ($key in @($InputObject.Keys)) {
                        if ("$key" -match '^([A-Za-z_]\w*|-?\d+\.?\d*)$') {
                            "$key = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        } else {
                            "'$key' = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        }
                    }) -split "`n" -join "`n$t")
        } elseif ($InputObject -is [System.Collections.IEnumerable]) {
            "@($($(ForEach($item in @($InputObject)) { $item | ConvertTo-Metadata -AsHashtable:$AsHashtable}) -join ","))"
        } elseif ($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
            # NOTE: we can't put [ordered] here because we need support for PS v2, but it's ok, because we put it in at parse-time
            $(if ($AsHashtable) {
                    "@{{`n$t{0}`n}}"
                } else {
                    "(PSObject @{{`n$t{0}`n}} -TypeName '$($InputObject.PSTypeNames -join "','")')"
                }) -f ($(
                    ForEach ($key in $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name) {
                        if ("$key" -match '^([A-Za-z_]\w*|-?\d+\.?\d*)$') {
                            "$key = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        } else {
                            "'$key' = " + (ConvertTo-Metadata $InputObject[$key] -AsHashtable:$AsHashtable)
                        }
                    }
                ) -split "`n" -join "`n$t")
        } elseif ($MetadataSerializers.ContainsKey($InputObject.GetType())) {
            $Str = ForEach-Object $MetadataSerializers.($InputObject.GetType()) -InputObject $InputObject

            [bool]$IsCommand = & {
                $ErrorActionPreference = "Stop"
                $Tokens = $Null; $ParseErrors = $Null
                $AST = [System.Management.Automation.Language.Parser]::ParseInput( $Str, [ref]$Tokens, [ref]$ParseErrors)
                $Null -ne $Ast.Find( {$args[0] -is [System.Management.Automation.Language.CommandAst]}, $false)
            }

            if ($IsCommand) { "($Str)" } else { $Str }
        } else {
            Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
            "'{0}'" -f $InputObject.ToString().Replace("'", "`'`'")
        }
    }
}
