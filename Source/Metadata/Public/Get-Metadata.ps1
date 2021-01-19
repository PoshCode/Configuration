function Get-Metadata {
    #.Synopsis
    #   Reads a specific value from a PowerShell metadata file (e.g. a module manifest)
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
    [Alias("Get-ManifestValue")]
    [CmdletBinding()]
    param(
        # The path to the module manifest file
        [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
        [Alias("PSPath")]
        [ValidateScript( { if ([IO.Path]::GetExtension($_) -ne ".psd1") {
                    throw "Path must point to a .psd1 file"
                } $true })]
        [string]$Path,

        # The property (or dotted property path) to be read from the manifest.
        # Get-Metadata searches the Manifest root properties, and also the nested hashtable properties.
        [Parameter(ParameterSetName = "Overwrite", Position = 1)]
        [string]$PropertyName = 'ModuleVersion',

        [switch]$Passthru
    )
    process {
        $ErrorActionPreference = "Stop"

        if (!(Test-Path $Path)) {
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
        if ($KeyValue.Count -eq 0) {
            WriteError -ExceptionType System.Management.Automation.ItemNotFoundException `
                -Message "Can't find '$PropertyName' in $Path" `
                -ErrorId "PropertyNotFound,Metadata\Get-Metadata" `
                -Category "ObjectNotFound"
            return
        }
        if ($KeyValue.Count -gt 1) {
            $SingleKey = @($KeyValue | Where-Object { $_.HashKeyPath -eq $PropertyName })

            if ($SingleKey.Count -gt 1) {
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

        if ($Passthru) {
            $KeyValue
        } else {
            # # Write-Debug "Start $($KeyValue.Extent.StartLineNumber) : $($KeyValue.Extent.StartColumnNumber) (char $($KeyValue.Extent.StartOffset))"
            # # Write-Debug "End   $($KeyValue.Extent.EndLineNumber) : $($KeyValue.Extent.EndColumnNumber) (char $($KeyValue.Extent.EndOffset))"

            # In PowerShell 5+ we can just use:
            if ($KeyValue.SafeGetValue) {
                $KeyValue.SafeGetValue()
            } else {
                # Otherwise, this workd for simple values:
                $Expression = $KeyValue.GetPureExpression()
                if ($Expression.Value) {
                    $Expression.Value
                } else {
                    # For complex (arrays, hashtables) we parse it ourselves
                    ConvertFrom-Metadata $KeyValue
                }
            }
        }
    }
}
