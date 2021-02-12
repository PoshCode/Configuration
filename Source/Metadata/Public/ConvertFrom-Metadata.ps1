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
        # The metadata text (or a path to a metadata file)
        [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
        [Alias("PSPath")]
        $InputObject,

        # A hashtable of MetadataConverters (same as with Add-MetadataConverter)
        [Hashtable]$Converters = @{},

        # The PSScriptRoot which the metadata should be evaluated from.
        # You do not normally need to pass this, and it has no effect unless
        # you're referencing $ScriptRoot in your metadata
        $ScriptRoot = "$PSScriptRoot",

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered,

        # Allows extending the valid variables which are allowed to be referenced in metadata
        # BEWARE: This exposes the value of these variables in your context to the caller
        # You ware reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables,

        # You should not pass this.
        # The PSVariable parameter is for preserving variable scope within the Metadata commands
        [System.Management.Automation.PSVariableIntrinsics]$PSVariable
    )
    begin {
        $OriginalMetadataSerializers = $Script:MetadataSerializers.Clone()
        $OriginalMetadataDeserializers = $Script:MetadataDeserializers.Clone()
        Add-MetadataConverter $Converters
        [string[]]$ValidCommands = @(
            "ConvertFrom-StringData", "Join-Path", "Split-Path", "ConvertTo-SecureString"
        ) + @($MetadataDeserializers.Keys)
        [string[]]$ValidVariables = $AllowedVariables + @(
            "PSScriptRoot", "ScriptRoot", "PoshCodeModuleRoot", "PSCulture", "PSUICulture", "True", "False", "Null")

        if (!$PSVariable) {
            $PSVariable = $PSCmdlet.SessionState.PSVariable
        }
    }
    end {
        $Script:MetadataSerializers = $OriginalMetadataSerializers.Clone()
        $Script:MetadataDeserializers = $OriginalMetadataDeserializers.Clone()
    }
    process {
        $ErrorActionPreference = "Stop"
        $Tokens = $Null; $ParseErrors = $Null

        if (Test-PSVersion -lt "3.0") {
            # Write-Debug "ConvertFrom-Metadata: Using Import-LocalizedData to support PowerShell $($PSVersionTable.PSVersion)"
            # Write-Debug "ConvertFrom-Metadata: $InputObject"
            if (!(Test-Path $InputObject -ErrorAction SilentlyContinue)) {
                $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
                Set-Content -Encoding UTF8 -Path $Path $InputObject
                $InputObject = $Path
            } elseif (!"$InputObject".EndsWith($ModuleManifestExtension)) {
                $Path = [IO.path]::ChangeExtension([IO.Path]::GetTempFileName(), $ModuleManifestExtension)
                Copy-Item "$InputObject" "$Path"
                $InputObject = $Path
            }
            $Result = $null
            Import-LocalizedData -BindingVariable Result -BaseDirectory (Split-Path $InputObject) -FileName (Split-Path $InputObject -Leaf) -SupportedCommand $ValidCommands
            return $Result
        }

        if (Test-Path $InputObject -ErrorAction SilentlyContinue) {
            # Write-Debug "ConvertFrom-Metadata: Using ParseInput to support PowerShell $($PSVersionTable.PSVersion)"
            # ParseFile on PS5 (and older) doesn't handle utf8 encoding properly (treats it as ASCII)
            # Sometimes, that causes an avoidable error. So I'm avoiding it, if I can:
            $Path = Convert-Path $InputObject
            if (!$PSBoundParameters.ContainsKey('ScriptRoot')) {
                $ScriptRoot = Split-Path $Path
            }
            $Content = (Get-Content -Path $InputObject -Encoding UTF8)
            # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
            $Content = $Content -join "`n" -replace "# SIG # Begin signature block(?s:.*)"
            try {
                # But older versions of PowerShell, this will throw a MethodException because the overload is missing
                $AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, $Path, [ref]$Tokens, [ref]$ParseErrors)
            } catch [System.Management.Automation.MethodException] {
                # Write-Debug "ConvertFrom-Metadata: Using ParseFile as a backup for PowerShell $($PSVersionTable.PSVersion)"
                $AST = [System.Management.Automation.Language.Parser]::ParseFile( $Path, [ref]$Tokens, [ref]$ParseErrors)

                # If we got parse errors on older versions of PowerShell, test to see if the error is just encoding
                if ($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
                    $StillErrors = $null
                    $AST = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$StillErrors)
                    # If we didn't get errors, clear the errors
                    # Otherwise, we want to use the original errors with the path in them
                    if ($null -eq $StillErrors -or $StillErrors.Count -eq 0) {
                        $ParseErrors = $StillErrors
                    }
                }
            }
        } else {
            # Write-Debug "ConvertFrom-Metadata: Using ParseInput with loose metadata: $InputObject"
            if (!$PSBoundParameters.ContainsKey('ScriptRoot')) {
                $ScriptRoot = $PoshCodeModuleRoot
            }

            $OFS = "`n"
            # Remove SIGnature blocks, PowerShell doesn't parse them in .psd1 and chokes on them here.
            $InputObject = "$InputObject" -replace "# SIG # Begin signature block(?s:.*)"
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($InputObject, [ref]$Tokens, [ref]$ParseErrors)
        }

        if ($null -ne $ParseErrors -and $ParseErrors.Count -gt 0) {
            ThrowError -Exception (New-Object System.Management.Automation.ParseException (, [System.Management.Automation.Language.ParseError[]]$ParseErrors)) -ErrorId "Metadata Error" -Category "ParserError" -TargetObject $InputObject
        }

        # Get the variables or subexpressions from strings which have them ("StringExpandable" vs "String") ...
        $Tokens += $Tokens | Where-Object { "StringExpandable" -eq $_.Kind } | Select-Object -ExpandProperty NestedTokens

        # Write-Debug "ConvertFrom-Metadata: Searching $($Tokens.Count) variables for: $($ValidVariables -join ', '))"
        # Work around PowerShell rules about magic variables
        # Change all the "ValidVariables" to use names like __ModuleBuilder__OriginalName__
        # Later, we'll try to make sure these are all set!
        if (($UsedVariables = $Tokens | Where-Object { ("Variable" -eq $_.Kind) -and ($_.Name -in $ValidVariables) })) {
            # Write-Debug "ConvertFrom-Metadata: Replacing $($UsedVariables.Name -join ', ')"
            if (($scriptroots = @( $UsedVariables | ForEach-Object { $_.Extent | Add-Member NoteProperty Name $_.Name -PassThru } ))) {
                $ScriptContent = $Ast.ToString()
                # Write-Debug "ConvertFrom-Metadata: Replacing $($UsedVariables.Count) variables in metadata: $ScriptContent"
                for ($r = $scriptroots.count - 1; $r -ge 0; $r--) {
                    $VariableExtent = $scriptroots[$r]
                    $VariableName = if ($VariableExtent.Name -eq "PSScriptRoot") {
                        '${__ModuleBuilder__ScriptRoot__}'
                    } else {
                        '${__ModuleBuilder__' + $VariableExtent.Name + '__}'
                    }
                    $ScriptContent = $ScriptContent.Remove($VariableExtent.StartOffset, ($VariableExtent.EndOffset - $VariableExtent.StartOffset)
                                                  ).Insert($VariableExtent.StartOffset, $VariableName)
                }
            }
        }

        # Write-Debug "ConvertFrom-Metadata: Replaced $($UsedVariables.Name -join ' and ') in metadata: $ScriptContent"
        $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)

        $Script = $AST.GetScriptBlock()
        try {
            [string[]]$PrivateVariables = $ValidVariables -replace "^.*$", '__ModuleBuilder__$0__'
            # Write-Debug "ConvertFrom-Metadata: Validating metadata: $Script against $PrivateVariables"
            $Script.CheckRestrictedLanguage( $ValidCommands, $PrivateVariables, $true )
        } catch {
            ThrowError -Exception $_.Exception.InnerException -ErrorId "Metadata Error" -Category "InvalidData" -TargetObject $Script
        }

        # Set the __ModuleBuilder__ValidVariables__ in our scope but not for constant variables:
        $ReplacementVariables = $ValidVariables | Where-Object { $_ -notin "PSCulture", "PSUICulture", "True", "False", "Null" }
        foreach ($name in $ReplacementVariables) {
            if (!($Value = $PSVariable.GetValue($Name))) {
                $Value = "`${$Name}"
            }
            # Write-Debug "ConvertFrom-Metadata: Setting __ModuleBuilder__${Name}__ = $Value"
            Set-Variable "__ModuleBuilder__${Name}__" $Value
        }

        if ($Ordered -and (Test-PSVersion -gt "3.0")) {
            # Write-Debug "ConvertFrom-Metadata: Supporting [Ordered] on PowerShell $($PSVersionTable.PSVersion)"
            # Make all the hashtables ordered, so that the output objects make more sense to humans...
            if ($Tokens | Where-Object { "AtCurly" -eq $_.Kind }) {
                $ScriptContent = $AST.ToString()
                $Hashtables = $AST.FindAll( {$args[0] -is [System.Management.Automation.Language.HashtableAst] -and ("ordered" -ne $args[0].Parent.Type.TypeName)}, $Recurse)
                $Hashtables = $Hashtables | ForEach-Object {
                    New-Object PSObject -Property @{Type = "([ordered]"; Position = $_.Extent.StartOffset}
                    New-Object PSObject -Property @{Type = ")"; Position = $_.Extent.EndOffset}
                } | Sort-Object Position -Descending
                foreach ($point in $Hashtables) {
                    $ScriptContent = $ScriptContent.Insert($point.Position, $point.Type)
                }

                $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$Tokens, [ref]$ParseErrors)
                $Script = $AST.GetScriptBlock()
            }
        }
        # Write-Debug "ConvertFrom-Metadata: Metadata: $Script"
        # Write-Debug "ConvertFrom-Metadata: Switching to RestrictedLanguage mode"
        $Mode, $ExecutionContext.SessionState.LanguageMode = $ExecutionContext.SessionState.LanguageMode, "RestrictedLanguage"

        try {
            $Script.InvokeReturnAsIs(@())
        } finally {
            $ExecutionContext.SessionState.LanguageMode = $Mode
            # Write-Debug "ConvertFrom-Metadata: Switching to $Mode mode"
        }
    }
}
