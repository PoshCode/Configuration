function Update-Manifest {
    #.Synopsis
    #   Update a PowerShell module manifest
    #.Description
    #   By default Update-Manifest increments the ModuleVersion, but it can set any key in the Module Manifest, its PrivateData, or the PSData in PrivateData. 
    #
    #   NOTE: This cannot currently create new keys, or uncomment keys.
    #.Example
    #   Update-Manifest .\Configuration.psd1
    #
    #   Increments the Build part of the ModuleVersion in the Configuration.psd1 file
    #.Example
    #   Update-Manifest .\Configuration.psd1 -Increment Major
    #
    #   Increments the Major version part of the ModuleVersion in the Configuration.psd1 file
    #.Example
    #   Update-Manifest .\Configuration.psd1 -Value '0.4'
    #
    #   Sets the ModuleVersion in the Configuration.psd1 file to 0.4
    #.Example
    #   Update-Manifest .\Configuration.psd1 -Property ReleaseNotes -Value 'Add the awesome Update-Manifest function!'
    #
    #   Sets the PrivateData.PSData.ReleaseNotes value in the Configuration.psd1 file!
    [CmdletBinding()]
    param(
        # The path to the module manifest file
        [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
        [Alias("PSPath")]
        [string]$Manifest,

        # The property to be set in the manifest. It must already exist in the file (and not be commented out)
        # This searches the Manifest root properties, then the properties PrivateData, then the PSData
        [Parameter(ParameterSetName="Overwrite")]
        [string]$PropertyName = 'ModuleVersion',

        # A new value for the property
        [Parameter(ParameterSetName="Overwrite", Mandatory)]
        $Value,

        # By default Update-Manifest increments ModuleVersion; this controls which part of the version number is incremented
        [Parameter(ParameterSetName="Increment")]
        [ValidateSet("Major","Minor","Build","Revision")]
        [string]$Increment = "Build",

        # When set, and incrementing the ModuleVersion, output the new version number.
        [Parameter(ParameterSetName="Increment")]
        [switch]$Passthru
    )

    $KeyValue = Get-ManifestValue $Manifest -PropertyName $PropertyName -Passthru

    if($PSCmdlet.ParameterSetName -eq "Increment") {
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

    if(Test-Path $Manifest) {
        Set-Content $Manifest $ManifestContent
    } else {
        $ManifestContent
    }
}


function Get-ManifestValue {
    #.Synopsis
    #   Reads a specific value from a module manifest
    #.Description
    #   By default Get-ManifestValue gets the ModuleVersion, but it can read any key in the Module Manifest, including the PrivateData, or the PSData inside the PrivateData.
    #.Example
    #   Get-ManifestValue .\Configuration.psd1
    #   
    #   Returns the module version number (as a string)
    #.Example
    #   Get-ManifestValue .\Configuration.psd1 ReleaseNotes
    #   
    #   Returns the release notes!
    [CmdletBinding()]
    param(
        # The path to the module manifest file
        [Parameter(ValueFromPipelineByPropertyName="True", Position=0)]
        [Alias("PSPath")]
        [string]$Manifest,

        # The property to be read from the manifest. Get-ManifestValue searches the Manifest root properties, then the properties PrivateData, then the PSData
        [Parameter(ParameterSetName="Overwrite", Position=1)]
        [string]$PropertyName = 'ModuleVersion',

        [switch]$Passthru
    )
    $ErrorActionPreference = "Stop"

    if(Test-Path $Manifest) {
        $ManifestContent = Get-Content $Manifest -Raw
    } else { 
        $ManifestContent = $Manifest
    }

    $Tokens = $Null; $ParseErrors = $Null
    $AST = [System.Management.Automation.Language.Parser]::ParseInput( $ManifestContent, $Manifest, [ref]$Tokens, [ref]$ParseErrors )
    $ManifestHash = $AST.Find( {$args[0] -is [System.Management.Automation.Language.HashtableAst]}, $true )
    $KeyValue = $ManifestHash.KeyValuePairs.Where{ $_.Item1.Value -eq $PropertyName }.Item2

    # Recursively search for PropertyName in the PrivateData and PrivateData.PSData
    if(!$KeyValue) {
        $global:PrivateData = $ManifestHash.KeyValuePairs.Where{ $_.Item1.Value -eq 'PrivateData' }.Item2.PipelineElements.Expression
        $KeyValue = $PrivateData.KeyValuePairs.Where{ $_.Item1.Value -eq $PropertyName }.Item2
        if(!$KeyValue) {
            $global:PSData = $PrivateData.KeyValuePairs.Where{ $_.Item1.Value -eq 'PSData' }.Item2.PipelineElements.Expression
            $KeyValue = $PSData.KeyValuePairs.Where{ $(Write-Verbose "'$($_.Item1.Value)' -eq '$PropertyName'"); $_.Item1.Value -eq $PropertyName }.Item2
            if(!$KeyValue) {
                Write-Error "Couldn't find '$PropertyName' in that manifest!"
                return
            }
        }
    }

    if($Passthru) { $KeyValue } else { 
        Write-Verbose "Start $($KeyValue.Extent.StartLineNumber) : $($KeyValue.Extent.StartColumnNumber) (char $($KeyValue.Extent.StartOffset))"
        Write-Verbose "End   $($KeyValue.Extent.EndLineNumber) : $($KeyValue.Extent.EndColumnNumber) (char $($KeyValue.Extent.EndOffset))"
        $KeyValue.SafeGetValue()
    }
}