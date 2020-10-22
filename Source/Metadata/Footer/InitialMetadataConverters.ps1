$MetadataSerializers = @{}
$MetadataDeserializers = @{}

if ($Converters -is [Collections.IDictionary]) {
    Add-MetadataConverter $Converters
}
function PSCredentialMetadataConverter {
    <#
    .Synopsis
        Creates a new PSCredential with the specified properties
    .Description
        This is just a wrapper for the PSObject constructor with -Property $Value
        It exists purely for the sake of psd1 serialization
    .Parameter Value
        The hashtable of properties to add to the created objects
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "EncodedPassword")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPasswordParams", "")]
    param(
        # The UserName for this credential
        [string]$UserName,
        # The Password for this credential, encoded via ConvertFrom-SecureString
        [string]$EncodedPassword
    )
    New-Object PSCredential $UserName, (ConvertTo-SecureString $EncodedPassword)
}

# The OriginalMetadataSerializers
Add-MetadataConverter @{
    [bool]           = { if ($_) { '$True' } else { '$False' } }
    [Version]        = { "'$_'" }
    [PSCredential]   = { 'PSCredential "{0}" "{1}"' -f $_.UserName, (ConvertFrom-SecureString $_.Password) }
    [SecureString]   = { "ConvertTo-SecureString {0}" -f (ConvertFrom-SecureString $_) }
    [Guid]           = { "Guid '$_'" }
    [DateTime]       = { "DateTime '{0}'" -f $InputObject.ToString('o') }
    [DateTimeOffset] = { "DateTimeOffset '{0}'" -f $InputObject.ToString('o') }
    [ConsoleColor]   = { "ConsoleColor {0}" -f $InputObject.ToString() }

    [System.Management.Automation.SwitchParameter] = { if ($_) { '$True' } else { '$False' } }
    # Escape single-quotes by doubling them:
    [System.Management.Automation.ScriptBlock] = { "(ScriptBlock '{0}')" -f ("$_" -replace "'", "''") }
    # This GUID is here instead of as a function
    # just to make sure the tests can validate the converter hashtables
    "Guid"           = { [Guid]$Args[0] }
    "DateTime"       = { [DateTime]$Args[0] }
    "DateTimeOffset" = { [DateTimeOffset]$Args[0] }
    "ConsoleColor"   = { [ConsoleColor]$Args[0] }
    "ScriptBlock"    = { [scriptblock]::Create($Args[0]) }
    "PSCredential"   = (Get-Command PSCredentialMetadataConverter).ScriptBlock
    "FromPsMetadata" = {
        $TypeName, $Args = $Args
        $Output = ([Type]$TypeName)::new()
        $Output.FromPsMetadata($Args)
        $Output
    }
    "PSObject"       = { param([hashtable]$Properties, [string[]]$TypeName)
        $Result = New-Object System.Management.Automation.PSObject -Property $Properties
        $TypeName += @($Result.PSTypeNames)
        $Result.PSTypeNames.Clear()
        foreach ($Name in $TypeName) {
            $Result.PSTypeNames.Add($Name)
        }
        $Result }

}

$Script:OriginalMetadataSerializers = $script:MetadataSerializers.Clone()
$Script:OriginalMetadataDeserializers = $script:MetadataDeserializers.Clone()

Export-ModuleMember -Function *-* -Alias *