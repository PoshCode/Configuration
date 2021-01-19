function Add-MetadataConverter {
    <#
      .Synopsis
         Add a converter functions for serialization and deserialization to metadata
      .Description
         Add-MetadataConverter allows you to map:
         * a type to a scriptblock which can serialize that type to metadata (psd1)
         * define a name and scriptblock as a function which will be whitelisted in metadata (for ConvertFrom-Metadata and Import-Metadata)

         The idea is to give you a way to extend the serialization capabilities if you really need to.
      .Example
         Add-MetadataCOnverter @{ [bool] = { if($_) { '$True' } else { '$False' } } }

         Shows a simple example of mapping bool to a scriptblock that serializes it in a way that's inherently parseable by PowerShell.  This exact converter is already built-in to the Metadata module, so you don't need to add it.

      .Example
         Add-MetadataConverter @{
            [Uri] = { "Uri '$_' " }
            "Uri" = {
               param([string]$Value)
               [Uri]$Value
            }
         }

         Shows how to map a function for serializing Uri objects as strings with a Uri function that just casts them. Normally you wouldn't need to do that for Uri, since they output strings natively, and it's perfectly logical to store Uris as strings and only cast them when you really need to.

      .Example
         Add-MetadataConverter @{
            [DateTimeOffset] = { "DateTimeOffset {0} {1}" -f $_.Ticks, $_.Offset }
            "DateTimeOffset" = {param($ticks,$offset) [DateTimeOffset]::new( $ticks, $offset )}
         }

         Shows how to change the DateTimeOffset serialization.

         By default, DateTimeOffset values are (de)serialized using the 'o' RoundTrips formatting
         e.g.: [DateTimeOffset]::Now.ToString('o')

   #>
    [CmdletBinding()]
    param(
        # A hashtable of types to serializer scriptblocks, or function names to scriptblock definitions
        [Parameter(Mandatory = $True)]
        [hashtable]$Converters
    )

    if ($Converters.Count) {
        switch ($Converters.Keys.GetEnumerator()) {
            {$Converters[$_] -isnot [ScriptBlock]} {
                WriteError -ExceptionType System.ArgumentExceptionn `
                    -Message "Ignoring $_ converter, the value must be ScriptBlock!" `
                    -ErrorId "NotAScriptBlock,Metadata\Add-MetadataConverter" `
                    -Category "InvalidArgument"
                continue
            }

            {$_ -is [String]} {
                # Write-Debug "Storing deserialization function: $_"
                Set-Content "function:script:$_" $Converters[$_]
                # We need to store the function in MetadataDeserializers
                $script:MetadataDeserializers[$_] = $Converters[$_]
                continue
            }

            {$_ -is [Type]} {
                # Write-Debug "Adding serializer for $($_.FullName)"
                $script:MetadataSerializers[$_] = $Converters[$_]
                continue
            }
            default {
                WriteError -ExceptionType System.ArgumentExceptionn `
                    -Message "Unsupported key type in Converters: $_ is $($_.GetType())" `
                    -ErrorId "InvalidKeyType,Metadata\Add-MetadataConverter" `
                    -Category "InvalidArgument"
            }
        }
    }
}
