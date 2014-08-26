param(
   # Because of the way
   $Converters = @{}
)

$ModuleManifestExtension = ".psd1"

function Add-MetadataConverter {
   [CmdletBinding()]
   param([hashtable]$Converters)

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

function Test-PSVersion {
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


function ConvertFrom-Metadata {
   [CmdletBinding()]
   param(
      [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
      [Alias("PSPath")]
      $InputObject,

      [Hashtable]$Converters = @{},
      $ScriptRoot = '$PSScriptRoot'
   )
   begin {
      $Script:OriginalMetadataConverters = $Script:MetadataConverters.Clone()
      Add-MetadataConverter $Converters
      [string[]]$ValidCommands = @("PSObject", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", "Join-Path") +  @($MetadataConverters.Keys.GetEnumerator())
      [string[]]$ValidVariables = "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot","PSCulture","PSUICulture","True","False","Null"
   }
   end {
      $Script:MetadataConverters = $Script:OriginalMetadataConverters.Clone()
   }
   process {
      $EAP, $ErrorActionPreference = $EAP, "Stop"
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
         $InputObject = "$InputObject" -replace "# SIG # Begin signature block(?s:.*)"
         $AST = [System.Management.Automation.Language.Parser]::ParseInput($InputObject, [ref]$Tokens, [ref]$ParseErrors)
      }

      if($ParseErrors -ne $null) {
         $ParseException = New-Object System.Management.Automation.ParseException (,[System.Management.Automation.Language.ParseError[]]$ParseErrors)
         $PSCmdlet.ThrowTerminatingError((New-Object System.Management.Automation.ErrorRecord $ParseException, "Metadata Error", "ParserError", $InputObject))
      }

      $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -Expand NestedTokens

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
        Write-Error "$Script"
      }

      $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

      try {
         $Script.InvokeReturnAsIs(@())
      }
      finally {
         $ErrorActionPreference = $EAP
         $ExecutionContext.SessionState.LanguageMode = $Mode
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


$MetadataConverters = @{}

if($Converters -isnot [Collections.IDictionary]) {
   foreach($param in $Converters) {
      if($param -is [Collections.IDictionary]) {
         Add-MetadataConverter $param
      }
   }
} else {
   Add-MetadataConverter $Converters
}

Add-MetadataConverter @{
   [bool]    = { if($_) { '$True' } else { '$False' } }

   [Version] = { "'$_'" }

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
