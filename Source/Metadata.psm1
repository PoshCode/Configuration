param(
   $Converters = @{}
)

$ModuleManifestExtension = ".psd1"

function Test-PSVersion {
   <#
      .Synopsis
         Test the PowerShell Version
      .Description
         This function exists so I can do things differently on older versions of PowerShell.
         But the reason I test in a function is that I can mock the Version to test the alternative code.
      .Example
         if(Test-PSVersion -ge 3.0) {
            ls | where Length -gt 12mb
         } else {
            ls | Where { $_.Length -gt 12mb }
         }

         This is just a trivial example to show the usage (you wouldn't really bother for a where-object call)
   #>
   [OutputType([bool])]
   [CmdletBinding()]
   param(
      [Version]$Version = $PSVersionTable.PSVersion,
      [Version]$lt,
      [Version]$le,
      [Version]$gt,
      [Version]$ge,
      [Version]$eq,
      [Version]$ne
   )

   $all = @(
      if($lt) { $Version -lt $lt }
      if($gt) { $Version -gt $gt }
      if($le) { $Version -le $le }
      if($ge) { $Version -ge $ge }
      if($eq) { $Version -eq $eq }
      if($ne) { $Version -ne $ne }
   )

   $all -notcontains $false
}

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

   if($Converters.Count) {
      switch ($Converters.Keys.GetEnumerator()) {
         {$Converters.$_ -isnot [ScriptBlock]} {
            Write-Error "Ignoring $_ converter, value must be ScriptBlock"
            continue
         }

         {$_ -is [String]}
         {
            # Write-Debug "Storing deserialization function: $_"
            Set-Content "function:script:$_" $Converters.$_
            # We need to store the given function name in MetadataConverters too
            $MetadataConverters.$_ = $Converters.$_
            continue
         }

         {$_ -is [Type]}
         {
            # Write-Debug "Adding serializer for $($_.FullName)"
            $MetadataConverters.$_ = $Converters.$_
            continue
         }
         default {
            Write-Error "Unsupported key type in Converters: $_ is $($_.GetType())"
         }
      }
   }
}

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
      [Parameter(ValueFromPipeline = $True)]
      $InputObject,

      [Hashtable]$Converters = @{}
   )
   begin {
      $t = "  "
      $Script:OriginalMetadataConverters = $Script:MetadataConverters.Clone()
      Add-MetadataConverter $Converters
   }
   end {
      $Script:MetadataConverters = $Script:OriginalMetadataConverters.Clone()
   }
   process {
      # Write-verbose ("Type {0}" -f $InputObject.GetType().FullName)
      if($Null -eq $InputObject) {
        # Write-verbose "Null"
        '""'
      } elseif( $InputObject -is [Int16] -or
                $InputObject -is [Int32] -or
                $InputObject -is [Int64] -or
                $InputObject -is [Double] -or
                $InputObject -is [Decimal] -or
                $InputObject -is [Byte] )
      {
         # Write-verbose "Numbers"
         "$InputObject"
      }
      elseif($InputObject -is [String]) {
         "'{0}'" -f $InputObject.ToString().Replace("'","''")
      }
      elseif($InputObject -is [Collections.IDictionary]) {
         # Write-verbose "Dictionary"
         #Write-verbose "Dictionary:`n $($InputObject|ft|out-string -width 110)"
         "@{{`n$t{0}`n}}" -f ($(
         ForEach($key in @($InputObject.Keys)) {
            if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
               "$key = " + (ConvertTo-Metadata $InputObject.($key))
            }
            else {
               "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
            }
         }) -split "`n" -join "`n$t")
      }
      elseif($InputObject -is [System.Collections.IEnumerable]) {
        # Write-verbose "Enumerable"
        "@($($(ForEach($item in @($InputObject)) { ConvertTo-Metadata $item }) -join ","))"
     }
     elseif($InputObject -is [System.Management.Automation.ScriptBlock]) {
         "(ScriptBlock '$InputObject')"
     }
     elseif($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
         # Write-verbose "PSCustomObject"
         # NOTE: we can't put [ordered] here because we need support for PS v2, but it's ok, because we put it in at parse-time
         "(PSObject @{{`n$t{0}`n}})" -f ($(
            ForEach($key in $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name) {
               if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
                  "$key = " + (ConvertTo-Metadata $InputObject.($key))
               }
               else {
                  "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
               }
            }
         ) -split "`n" -join "`n$t")
      }
      elseif($MetadataConverters.ContainsKey($InputObject.GetType())) {
         $Str = ForEach-Object $MetadataConverters.($InputObject.GetType()) -InputObject $InputObject

         [bool]$IsCommand = & {
            $ErrorActionPreference = "Stop"
            $Tokens = $Null; $ParseErrors = $Null
            $AST = [System.Management.Automation.Language.Parser]::ParseInput( $Str, [ref]$Tokens, [ref]$ParseErrors)
            $Null -ne $Ast.Find({$args[0] -is [System.Management.Automation.Language.CommandAst]}, $false)
         }

         if($IsCommand) { "($Str)" } else { $Str }
      }
      else {
         # Write-verbose "Unknown!"
         # $MetadataConverters.Keys | %{ Write-Verbose "We have converters for: $($_.Name)" }
         Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
         "'{0}'" -f $InputObject.ToString().Replace("'","`'`'")
      }
   }
}

function ConvertFrom-Metadata {
    <#
    .Synopsis
        Deserializes objects from PowerShell Data language (PSD1)
    .Description
        Converts psd1 notation to actual objects, and supports passing in additional converters
        in addition to using the built-in registered converters (see Add-MetadataConverter).

        NOTE: Any Converters that are passed in are temporarily added as though passed Add-MetadataConverter
    .Example
        ConvertFrom-Metadata 'PSObject @{ Name = PSObject @{ First = "Joel"; Last = "Bennett" }; Id = 1; }'

        Id Name
        -- ----
        1 @{Last=Bennett; First=Joel}

        Convert the example string into a real PSObject using the built-in object serializer.
    .Example
        $data = ConvertFrom-Metadata .\Configuration.psd1 -Ordered

        Convert a module manifest into a hashtable of properties for introspection, preserving the order in the file
    .Example
        ConvertFrom-Metadata ("DateTimeOffset 635968680686066846 -05:00:00") -Converters @{
        "DateTimeOffset" = {
            param($ticks,$offset)
            [DateTimeOffset]::new( $ticks, $offset )
        }
        }

        Shows how to temporarily add a "ValidCommand" called "DateTimeOffset" to support extra data types in the metadata.

        See also the third example on ConvertTo-Metadata and Add-MetadataConverter
    #>
   [CmdletBinding()]
   param(
      [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
      [Alias("PSPath")]
      $InputObject,

      [Hashtable]$Converters = @{},

      $ScriptRoot = '$PSScriptRoot',

      # If set (and PowerShell version 4 or later) preserve the file order of configuration
      # This results in the output being an OrderedDictionary instead of Hashtable
      [Switch]$Ordered
   )
   begin {
      $Script:OriginalMetadataConverters = $Script:MetadataConverters.Clone()
      Add-MetadataConverter $Converters
      [string[]]$ValidCommands = @(
            "PSObject", "ConvertFrom-StringData", "Join-Path", "Split-Path", "ConvertTo-SecureString",
         "Guid", "bool", "SecureString", "Version", "DateTime", "DateTimeOffset", "PSCredential", "ConsoleColor", "ScriptBlock"
         ) + @($MetadataConverters.Keys.GetEnumerator() | Where-Object { $_ -isnot [Type] })
      [string[]]$ValidVariables = "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot","PSCulture","PSUICulture","True","False","Null"
   }
   end {
      $Script:MetadataConverters = $Script:OriginalMetadataConverters.Clone()
   }
   process {
      $ErrorActionPreference = "Stop"
      $Tokens = $Null; $ParseErrors = $Null

      if(Test-PSVersion -lt "3.0") {
         # Write-Debug "$InputObject"
         if(!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Set-Content -Encoding UTF8 -Path $Path $InputObject
            $InputObject = $Path
         } elseif(!"$InputObject".EndsWith($ModuleManifestExtension)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Copy-Item "$InputObject" "$Path"
            $InputObject = $Path
         }
         $Result = $null
         Import-LocalizedData -BindingVariable Result -BaseDirectory (Split-Path $InputObject) -FileName (Split-Path $InputObject -Leaf) -SupportedCommand $ValidCommands
         return $Result
      }

      if(Test-Path $InputObject -ErrorAction SilentlyContinue) {
         $AST = [System.Management.Automation.Language.Parser]::ParseFile( (Convert-Path $InputObject), [ref]$Tokens, [ref]$ParseErrors)
         $ScriptRoot = Split-Path $InputObject
      } else {
         $ScriptRoot = $PoshCodeModuleRoot
         $OFS = "`n"
         # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
         $InputObject = "$InputObject" -replace "# SIG # Begin signature block(?s:.*)"
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($InputObject, [ref]$Tokens, [ref]$ParseErrors)
      }

      if($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
         ThrowError -Exception (New-Object System.Management.Automation.ParseException (,[System.Management.Automation.Language.ParseError[]]$ParseErrors)) -ErrorId "Metadata Error" -Category "ParserError" -TargetObject $InputObject
      }

      # Get the variables or subexpressions from strings which have them ("StringExpandable" vs "String") ...
      $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -ExpandProperty NestedTokens

      # Work around PowerShell rules about magic variables
      # Replace "PSScriptRoot" magic variables with the non-reserved "ScriptRoot"
      if($scriptroots = @($Tokens | Where-Object { ("Variable" -eq $_.Kind) -and ($_.Name -eq "PSScriptRoot") } | ForEach-Object { $_.Extent } )) {
         $ScriptContent = $Ast.ToString()
         for($r = $scriptroots.count - 1; $r -ge 0; $r--) {
            $ScriptContent = $ScriptContent.Remove($scriptroots[$r].StartOffset, ($scriptroots[$r].EndOffset - $scriptroots[$r].StartOffset)).Insert($scriptroots[$r].StartOffset,'$ScriptRoot')
         }
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
      }

      $Script = $AST.GetScriptBlock()
      try {
         $Script.CheckRestrictedLanguage( $ValidCommands, $ValidVariables, $true )
      }
      catch {
         ThrowError -Exception $_.Exception.InnerException -ErrorId "Metadata Error" -Category "InvalidData" -TargetObject $Script
      }

      if($Ordered -and (Test-PSVersion -gt "3.0")) {
         # Make all the hashtables ordered, so that the output objects make more sense to humans...
         if($Tokens | Where-Object { "AtCurly" -eq $_.Kind }) {
            $ScriptContent = $AST.ToString()
            $Hashtables = $AST.FindAll({$args[0] -is [System.Management.Automation.Language.HashtableAst] -and ("ordered" -ne $args[0].Parent.Type.TypeName)}, $Recurse)
            $Hashtables = $Hashtables | ForEach-Object {
                                            New-Object PSObject -Property @{Type="([ordered]";Position=$_.Extent.StartOffset}
                                            New-Object PSObject -Property @{Type=")";Position=$_.Extent.EndOffset}
                                          } | Sort-Object Position -Descending
            foreach($point in $Hashtables) {
               $ScriptContent = $ScriptContent.Insert($point.Position, $point.Type)
            }
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
            $Script = $AST.GetScriptBlock()
         }
      }

      $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

      try {
         $Script.InvokeReturnAsIs(@())
      }
      finally {
         $ExecutionContext.SessionState.LanguageMode = $Mode
      }
   }
}

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
      [Parameter(ValueFromPipeline=$true, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias("PSPath","Content")]
      [string]$Path,

      [Hashtable]$Converters = @{},

       # If set (and PowerShell version 4 or later) preserve the file order of configuration
       # This results in the output being an OrderedDictionary instead of Hashtable
      [Switch]$Ordered
   )
   process {
      if(Test-Path $Path) {
         # Write-Debug "Importing Metadata file from `$Path: $Path"
         if(!(Test-Path $Path -PathType Leaf)) {
            $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
         }
      }
      if(!(Test-Path $Path)) {
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

function Export-Metadata {
    <#
        .Synopsis
            Creates a metadata file from a simple object
        .Description
            Serves as a wrapper for ConvertTo-Metadata to explicitly support exporting to files

            Note that exportable data is limited by the rules of data sections (see about_Data_Sections) and the available MetadataConverters (see Add-MetadataConverter)

            The only things inherently importable in PowerShell metadata files are Strings, Booleans, and Numbers ... and Arrays or Hashtables where the values (and keys) are all strings, booleans, or numbers.

            Note: this function and the matching Import-Metadata are extensible, and have included support for PSCustomObject, Guid, Version, etc.
        .Example
            $Configuration | Export-Metadata .\Configuration.psd1

            Export a configuration object (or hashtable) to the default Configuration.psd1 file for a module
            The Configuration module uses Configuration.psd1 as it's default config file.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # Specifies the path to the PSD1 output file.
        [Parameter(Mandatory=$true, Position=0)]
        $Path,

        # comments to place on the top of the file (to explain settings or whatever for people who might edit it by hand)
        [string[]]$CommentHeader,

        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,

        [Hashtable]$Converters = @{},

        # If set, output the nuspec file
        [Switch]$Passthru
    )
    begin { $data = @() }
    process { $data += @($InputObject) }
    end {
        # Avoid arrays when they're not needed:
        if($data.Count -eq 1) { $data = $data[0] }
        Set-Content -Encoding UTF8 -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata -InputObject $data -Converters $Converters)) -Join "`n")
        if($Passthru) {
            Get-Item $Path
        }
    }
}

function Update-Metadata {
    <#
        .Synopsis
           Update a single value in a PowerShell metadata file
        .Description
           By default Update-Metadata increments "ModuleVersion"
           because my primary use of it is during builds,
           but you can pass the PropertyName and Value for any key in a module Manifest, its PrivateData, or the PSData in PrivateData.

           NOTE: This will not currently create new keys, or uncomment keys.
        .Example
           Update-Metadata .\Configuration.psd1

           Increments the Build part of the ModuleVersion in the Configuration.psd1 file
        .Example
           Update-Metadata .\Configuration.psd1 -Increment Major

           Increments the Major version part of the ModuleVersion in the Configuration.psd1 file
        .Example
           Update-Metadata .\Configuration.psd1 -Value '0.4'

           Sets the ModuleVersion in the Configuration.psd1 file to 0.4
        .Example
           Update-Metadata .\Configuration.psd1 -Property ReleaseNotes -Value 'Add the awesome Update-Metadata function!'

           Sets the PrivateData.PSData.ReleaseNotes value in the Configuration.psd1 file!
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The path to the module manifest file -- must be a .psd1 file
        # As an easter egg, you can pass the CONTENT of a psd1 file instead, and the modified data will pass through
        [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
        [Alias("PSPath")]
        [ValidateScript({ if([IO.Path]::GetExtension($_) -ne ".psd1") { throw "Path must point to a .psd1 file" } $true })]
        [string]$Path,

        # The property to be set in the manifest. It must already exist in the file (and not be commented out)
        # This searches the Manifest root properties, then the properties PrivateData, then the PSData
        [Parameter(ParameterSetName="Overwrite")]
        [string]$PropertyName = 'ModuleVersion',

        # A new value for the property
        [Parameter(ParameterSetName="Overwrite", Mandatory)]
        $Value,

        # By default Update-Metadata increments ModuleVersion; this controls which part of the version number is incremented
        [Parameter(ParameterSetName="IncrementVersion")]
        [ValidateSet("Major","Minor","Build","Revision")]
        [string]$Increment = "Build",

        # When set, and incrementing the ModuleVersion, output the new version number.
        [Parameter(ParameterSetName="IncrementVersion")]
        [switch]$Passthru
    )

    $KeyValue = Get-Metadata $Path -PropertyName $PropertyName -Passthru

    if($PSCmdlet.ParameterSetName -eq "IncrementVersion") {
        $Version = [Version]$KeyValue.SafeGetValue()

        $Version = switch($Increment) {
            "Major" {
                [Version]::new($Version.Major + 1, 0)
            }
            "Minor" {
                $Minor = if($Version.Minor -le 0) { 1 } else { $Version.Minor + 1 }
                [Version]::new($Version.Major, $Minor)
            }
            "Build" {
                $Build = if($Version.Build -le 0) { 1 } else { $Version.Build + 1 }
                [Version]::new($Version.Major, $Version.Minor, $Build)
            }
            "Revision" {
                $Build = if($Version.Build -le 0) { 0 } else { $Version.Build }
                $Revision = if($Version.Revision -le 0) { 1 } else { $Version.Revision + 1 }
                [Version]::new($Version.Major, $Version.Minor, $Build, $Revision)
            }
        }

        $Value = $Version

        if($Passthru) { $Value }
    }

    $Value = ConvertTo-Metadata $Value

    $Extent = $KeyValue.Extent
    while($KeyValue.parent) { $KeyValue = $KeyValue.parent }

    $ManifestContent = $KeyValue.Extent.Text.Remove(
                                               $Extent.StartOffset,
                                               ($Extent.EndOffset - $Extent.StartOffset)
                                           ).Insert($Extent.StartOffset, $Value)

    if(Test-Path $Path) {
        Set-Content -Encoding UTF8 -Path $Path -Value $ManifestContent -NoNewline
    } else {
        $ManifestContent
    }
}

function FindHashKeyValue {
    [CmdletBinding()]
    param(
        $SearchPath,
        $Ast,
        [string[]]
        $CurrentPath = @()
    )
    # Write-Debug "FindHashKeyValue: $SearchPath -eq $($CurrentPath -Join '.')"
    if($SearchPath -eq ($CurrentPath -Join '.') -or $SearchPath -eq $CurrentPath[-1]) {
        return $Ast |
            Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force |
            Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
    }

    if($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst] ) {
        $KeyValue = $Ast.PipelineElements.Expression
        foreach($KV in $KeyValue.KeyValuePairs) {
            $result = FindHashKeyValue $SearchPath -Ast $KV.Item2 -CurrentPath ($CurrentPath + $KV.Item1.Value)
            if($null -ne $result) {
                $result
            }
        }
    }
}

function Get-Metadata {
    #.Synopsis
    #   Reads a specific value from a PowerShell metdata file (e.g. a module manifest)
    #.Description
    #   By default Get-Metadata gets the ModuleVersion, but it can read any key in the metadata file
    #.Example
    #   Get-Metadata .\Configuration.psd1
    #
    #   Returns the module version number (as a string)
    #.Example
    #   Get-Metadata .\Configuration.psd1 ReleaseNotes
    #
    #   Returns the release notes!
    [CmdletBinding()]
    param(
        # The path to the module manifest file
        [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
        [Alias("PSPath")]
        [ValidateScript({ if([IO.Path]::GetExtension($_) -ne ".psd1") { throw "Path must point to a .psd1 file" } $true })]
        [string]$Path,

        # The property (or dotted property path) to be read from the manifest.
        # Get-Metadata searches the Manifest root properties, and also the nested hashtable properties.
        [Parameter(ParameterSetName="Overwrite", Position=1)]
        [string]$PropertyName = 'ModuleVersion',

        [switch]$Passthru
    )
    $ErrorActionPreference = "Stop"

    if(!(Test-Path $Path)) {
        WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                  -Message "Can't find file $Path" `
                  -ErrorId "PathNotFound,Metadata\Import-Metadata" `
                  -Category "ObjectNotFound"
        return
    }
    $Path = Convert-Path $Path

    $Tokens = $Null; $ParseErrors = $Null
    $AST = [System.Management.Automation.Language.Parser]::ParseFile( $Path, [ref]$Tokens, [ref]$ParseErrors )

    $KeyValue = $Ast.EndBlock.Statements
    $KeyValue = @(FindHashKeyValue $PropertyName $KeyValue)
    if($KeyValue.Count -eq 0) {
        WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                   -Message "Can't find '$PropertyName' in $Path" `
                   -ErrorId "PropertyNotFound,Metadata\Get-Metadata" `
                   -Category "ObjectNotFound"
        return
    }
    if($KeyValue.Count -gt 1) {
        $SingleKey = @($KeyValue | Where-Object { $_.HashKeyPath -eq $PropertyName })

        if($SingleKey.Count -gt 1) {
            WriteError -ExceptionType System.Reflection.AmbiguousMatchException `
                       -Message ("Found more than one '$PropertyName' in $Path. Please specify a dotted path instead. Matching paths include: '{0}'" -f ($KeyValue.HashKeyPath -join "', '")) `
                       -ErrorId "AmbiguousMatch,Metadata\Get-Metadata" `
                       -Category "InvalidArgument"
            return
        } else {
            $KeyValue = $SingleKey
        }
    }
    $KeyValue = $KeyValue[0]

    if($Passthru) { $KeyValue } else {
        # # Write-Debug "Start $($KeyValue.Extent.StartLineNumber) : $($KeyValue.Extent.StartColumnNumber) (char $($KeyValue.Extent.StartOffset))"
        # # Write-Debug "End   $($KeyValue.Extent.EndLineNumber) : $($KeyValue.Extent.EndColumnNumber) (char $($KeyValue.Extent.EndOffset))"
        $KeyValue.SafeGetValue()
    }
}

Set-Alias Update-Manifest Update-Metadata
Set-Alias Get-ManifestValue Get-Metadata

# These functions are simple helpers for use in data sections (see about_data_sections) and .psd1 files (see ConvertFrom-Metadata)
function PSObject {
   <#
      .Synopsis
         Creates a new PSCustomObject with the specified properties
      .Description
         This is just a wrapper for the PSObject constructor with -Property $Value
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The hashtable of properties to add to the created objects
   #>
   param([hashtable]$Value)
   New-Object System.Management.Automation.PSObject -Property $Value
}

function DateTime {
   <#
      .Synopsis
         Creates a DateTime with the specified value
      .Description
         This is basically just a type cast to DateTime, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The DateTime value, preferably from .Format('o'), the .Net round-trip format
   #>
   param([string]$Value)
   [DateTime]$Value
}

function DateTimeOffset {
   <#
      .Synopsis
         Creates a DateTimeOffset with the specified value
      .Description
         This is basically just a type cast to DateTimeOffset, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The DateTimeOffset value, preferably from .Format('o'), the .Net round-trip format
   #>
   param([string]$Value)
   [DateTimeOffset]$Value
}

function PSCredential {
   <#
      .Synopsis
         Creates a new PSCredential with the specified properties
      .Description
         This is just a wrapper for the PSObject constructor with -Property $Value
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The hashtable of properties to add to the created objects
   #>
   [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword","EncodedPassword")]
   [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPasswordParams","")]
   param(
      # The UserName for this credential
      [string]$UserName,
      # The Password for this credential, encoded via ConvertFrom-SecureString
      [string]$EncodedPassword
   )
   New-Object PSCredential $UserName, (ConvertTo-SecureString $EncodedPassword)
}

function ConsoleColor {
   <#
      .Synopsis
         Creates a ConsoleColor with the specified value
      .Description
         This is basically just a type cast to ConsoleColor, the string needs to be castable.
         It exists purely for the sake of psd1 serialization
      .Parameter Value
         The ConsoleColor value, preferably from .ToString()
   #>
   param([string]$Value)
   [ConsoleColor]$Value
}

function ScriptBlock {
    <#
       .Synopsis
          Creates a ScriptBlock from a string
       .Description
          Just calls [ScriptBlock]::Create with the passed-in value
       .Parameter Value
          The ScriptBlock as a string
    #>
    param([string]$Value)
    [scriptblock]::Create($Value)
 }


$MetadataConverters = @{}

if($Converters -is [Collections.IDictionary]) {
   Add-MetadataConverter $Converters
}

# The OriginalMetadataConverters
Add-MetadataConverter @{
   [bool]    = { if($_) { '$True' } else { '$False' } }

   [System.Management.Automation.SwitchParameter] = { if($_) { '$True' } else { '$False' } }

   [Version] = { "'$_'" }

   [PSCredential] = { 'PSCredential "{0}" "{1}"' -f $_.UserName, (ConvertFrom-SecureString $_.Password) }

   [SecureString] = { "ConvertTo-SecureString {0}" -f (ConvertFrom-SecureString $_) }

   # This GUID is here instead of as a function
   # just to make sure the tests can validate the converter hashtables
   Guid = {
      <#
         .Synopsis
            Creates a GUID with the specified value
         .Description
            This is basically just a type cast to GUID.
            It exists purely for the sake of psd1 serialization
         .Parameter Value
            The GUID value.
      #>
      param([string]$Value)
      [Guid]$Value
   }
   [Guid] = { "Guid '$_'" }

   [DateTime] = { "DateTime '{0}'" -f $InputObject.ToString('o') }

   [DateTimeOffset] = { "DateTimeOffset '{0}'" -f $InputObject.ToString('o') }

   [ConsoleColor] = { "ConsoleColor {0}" -f $InputObject.ToString() }
}

$Script:OriginalMetadataConverters = $MetadataConverters.Clone()

function Update-Object {
   <#
      .Synopsis
         Recursively updates a hashtable or custom object with new values
      .Description
         Updates the InputObject with data from the update object, updating or adding values.
      .Example
         Update-Object -Input @{
            One = "Un"
            Two = "Dos"
         } -Update @{
            One = "Uno"
            Three = "Tres"
         }

         Updates the InputObject with the values in the UpdateObject,
         will return the following object:

         @{
            One = "Uno"
            Two = "Dos"
            Three = "Tres"
         }
   #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess","")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
   param(
      [AllowNull()]
      [Parameter(Position=0, Mandatory=$true)]
      $UpdateObject,

      [Parameter(ValueFromPipeline=$true, Mandatory = $true)]
      $InputObject
   )
   process {
      # Write-Debug "INPUT OBJECT:"
      # Write-Debug (($InputObject | Out-String -Stream | ForEach-Object TrimEnd) -join "`n")
      # Write-Debug "Update OBJECT:"
      # Write-Debug (($UpdateObject | Out-String -Stream | ForEach-Object TrimEnd) -join "`n")
      if($Null -eq $InputObject) { return }

      if($InputObject -is [System.Collections.IDictionary]) {
         $OutputObject = $InputObject
      } else {
         # Create a PSCustomObject with all the properties
         $OutputObject = $InputObject | Select-Object *
      }

      if(!$UpdateObject) {
         Write-Output $OutputObject
         return
      }

      if($UpdateObject -is [System.Collections.IDictionary]) {
         $Keys = $UpdateObject.Keys
      } else {
         $Keys = @($UpdateObject | Get-Member -MemberType Properties | Where-Object { $p1 -notcontains $_.Name } | Select-Object -ExpandProperty Name)
      }

      # # Write-Debug "Keys: $Keys"
      ForEach($key in $Keys) {
         if(($OutputObject.$Key -is [System.Collections.IDictionary] -or $OutputObject.$Key -is [PSObject]) -and
            ($InputObject.$Key -is  [System.Collections.IDictionary] -or $InputObject.$Key -is [PSObject])) {
            $Value = Update-Object -InputObject $InputObject.$Key -UpdateObject $UpdateObject.$Key
         } else {
            $Value = $UpdateObject.$Key
         }

         if($OutputObject -is [System.Collections.IDictionary]) {
            $OutputObject.$key = $Value
         } else {
            $OutputObject = Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name $key -Value $Value -PassThru -Force
         }
      }

      $Keys = $OutputObject.Keys
      ## Write-Debug "Keys: $Keys"

      Write-Output $OutputObject
   }
}

# Utility to throw an errorrecord
function ThrowError {
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet = $((Get-Variable -Scope 1 PSCmdlet).Value),

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName="NewException")]
        [ValidateNotNullOrEmpty()]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName="NewException", Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionType="System.Management.Automation.RuntimeException",

        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=3)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $TargetObject,

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=10)]
        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=10)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=11)]
        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=11)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory = $true, ParameterSetName="Rethrow", Position=1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    process {
        if(!$ErrorRecord) {
            if($PSCmdlet.ParameterSetName -eq "NewException") {
                if($Exception) {
                    $Exception = New-Object $ExceptionType $Message, $Exception
                } else {
                    $Exception = New-Object $ExceptionType $Message
                }
            }
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $Category, $TargetObject
        }
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }
}

# Utility to throw an errorrecord
function WriteError {
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $Cmdlet = $((Get-Variable -Scope 1 PSCmdlet).Value),

        [Parameter(Mandatory = $true, ParameterSetName="ExistingException", Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName="NewException")]
        [ValidateNotNullOrEmpty()]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName="NewException", Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionType="System.Management.Automation.RuntimeException",

        [Parameter(Mandatory = $true, ParameterSetName="NewException", Position=3)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $TargetObject,

        [Parameter(Mandatory = $true, Position=10)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true, Position=11)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory = $true, ParameterSetName="Rethrow", Position=1)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    process {
        if(!$ErrorRecord) {
            if($PSCmdlet.ParameterSetName -eq "NewException") {
                if($Exception) {
                    $Exception = New-Object $ExceptionType $Message, $Exception
                } else {
                    $Exception = New-Object $ExceptionType $Message
                }
            }
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $Category, $TargetObject
        }
        $Cmdlet.WriteError($errorRecord)
    }
}

Export-ModuleMember -Function *-*, PSObject, DateTime, DateTimeOffset, PSCredential, ConsoleColor -Alias *
