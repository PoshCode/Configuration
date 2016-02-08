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

   Write-Verbose "Version $Version"

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
            Write-Verbose "Adding function $_"
            Set-Content "function:script:$_" $Converters.$_
            continue
         }

         {$_ -is [Type]}
         {
            Write-Verbose "Adding serializer for $($_.FullName)"
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
      if($InputObject -eq $Null) {
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
      elseif($InputObject -is [String])  {
         # Write-verbose "String"
         "'$InputObject'"
      }
      elseif($InputObject -is [DateTime])  {
         # Write-verbose "DateTime"
         "DateTime '{0}'" -f $InputObject.ToString('o')
      }
      elseif($InputObject -is [DateTimeOffset])  {
         # Write-verbose "DateTime"
         "DateTimeOffset '{0}'" -f $InputObject.ToString('o')
      }
      elseif($InputObject -is [System.Collections.IDictionary]) {
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
         "@($($(ForEach($item in @($InputObject)) { ConvertTo-Metadata $item }) -join ','))"
      }
      elseif($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
         # Write-verbose "PSCustomObject"
         # NOTE: we can't put [ordered] here because we need support for PS v2, but it's ok, because we put it in at parse-time
         "PSObject @{{`n$t{0}`n}}" -f ($(
            ForEach($key in $InputObject | Get-Member -Type Properties | Select -Expand Name) {
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
         # Write-verbose "Using type converter for $($InputObject.GetType())"
         % $MetadataConverters.($InputObject.GetType()) -InputObject $InputObject
      }
      else {
         # Write-verbose "Unknown!"
         # $MetadataConverters.Keys | %{ Write-Verbose "We have converters for: $($_.Name)" }
         Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
         "'{0}'" -f $InputObject.ToString()
      }
   }
}

function ConvertFrom-Metadata {
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
      [string[]]$ValidCommands = @("PSObject", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", "ConvertTo-SecureString", "Join-Path") +  @($MetadataConverters.Keys.GetEnumerator())
      [string[]]$ValidVariables = "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot","PSCulture","PSUICulture","True","False","Null"
   }
   end {
      $Script:MetadataConverters = $Script:OriginalMetadataConverters.Clone()
   }
   process {
      $ErrorActionPreference = "Stop"
      $Tokens = $Null; $ParseErrors = $Null

      if(Test-PSVersion -lt "3.0") {
         Write-Verbose "$InputObject"
         if(!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
            $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
            Set-Content -Path $Path $InputObject
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

      if($ParseErrors -ne $null) {
         ThrowError -Exception (New-Object System.Management.Automation.ParseException (,[System.Management.Automation.Language.ParseError[]]$ParseErrors)) -ErrorId "Metadata Error" -Category "ParserError" -TargetObject $InputObject
      }

      # Get the variables or subexpressions from strings which have them ("StringExpandable" vs "String") ...
      $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -Expand NestedTokens

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
            $Hashtables = $Hashtables | % { 
                                            New-Object PSObject -Property @{Type="([ordered]";Position=$_.Extent.StartOffset}
                                            New-Object PSObject -Property @{Type=")";Position=$_.Extent.EndOffset}
                                          } | Sort Position -Descending
            foreach($point in $Hashtables) {
               $ScriptContent = $ScriptContent.Insert($point.Position, $point.Type)
            }
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
            $Script = $AST.GetScriptBlock()
         }
      }

      # Write-Debug $ScriptContent

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
      $ModuleInfo = $null
      if(Test-Path $Path) {
         Write-Verbose "Importing Metadata file from `$Path: $Path"
         if(!(Test-Path $Path -PathType Leaf)) {
            $Path = Join-Path $Path ((Split-Path $Path -Leaf) + $ModuleManifestExtension)
         }
      }
      if(!(Test-Path $Path)) {
         WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                     -Message "Can't find settings file $Path" `
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
         Converts simple objects to psd1 data files
         Note that exportable data is limited by the rules of data sections (see about_Data_Sections) and the available MetadataConverters (see Add-MetadataConverter)

         The only things inherently importable in PowerShell metadata files are Strings, Booleans, and Numbers ... and Arrays or Hashtables where the values (and keys) are all strings, booleans, or numbers.

         Note: this function and the matching Import-Metadata are extensible, and have included support for PSCustomObject, Guid, Version, etc.
   #>
   [CmdletBinding()]
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
        Set-Content -Path $Path -Value ((@($CommentHeader) + @(ConvertTo-Metadata -InputObject $data -Converters $Converters)) -Join "`n")
        if($Passthru) {
            Get-Item $Path
        }
    }
}


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
   param([string]$UserName, [string]$Password)
   New-Object PSCredential $UserName, (ConvertTo-SecureString $Password)
}


$MetadataConverters = @{}

if($Converters -is [Collections.IDictionary]) {
   Add-MetadataConverter $Converters
}

# The OriginalMetadataConverters
Add-MetadataConverter @{
   [bool]    = { if($_) { '$True' } else { '$False' } }

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
}

$Script:OriginalMetadataConverters = $MetadataConverters.Clone()

function Optimize-Object {
   <#
      .Synopsis
         Remove duplicate data from an object
      .Description
         Removes values from the delta object that are in the base object
   #>
}

function Update-Object {
    <#
        .Synopsis
            Update a custom object (or hashtable) with new values
        .Description
            Updates the InputObject with data from the update object.
        .Example
            Update-Object -Input @{
                One = "Un"
                Two = "Dos"
            } -Update @{
                One = "Uno"
                Three = "Tres"
            }

            Updates the InputObject with the values in the UpdateObject
            will return the following object:
            @{
                One = "Uno"
                Two = "Dos"
                Three = "Tres"
            }
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Position=0, Mandatory=$true)]
        $UpdateObject,

        [Parameter(ValueFromPipeline=$true, Mandatory = $true)]
        $InputObject
    )
    process {
        Write-Verbose "INPUT OBJECT:"
        Write-Verbose (($InputObject | out-string -stream | % TrimEnd) -join "`n")
        Write-Verbose "Update OBJECT:"
        Write-Verbose (($UpdateObject | out-string -stream | % TrimEnd) -join "`n")
        if($InputObject -eq $null) { return }

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
          $Keys = @($UpdateObject | gm -type Properties | Where { $p1 -notcontains $_.Name } | select -expand Name)
       }

       # Write-Debug "Keys: $Keys"
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
             $OutputObject = Add-Member -in $OutputObject -type NoteProperty -name $key -value $Value -Passthru -Force
          }
       }

       $Keys = $OutputObject.Keys
       #Write-Debug "Keys: $Keys"

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