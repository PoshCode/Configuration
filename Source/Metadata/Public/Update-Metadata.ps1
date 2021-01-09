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
    [Alias("Update-Manifest")]
    # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The path to the module manifest file -- must be a .psd1 file
        # As an easter egg, you can pass the CONTENT of a psd1 file instead, and the modified data will pass through
        [Parameter(ValueFromPipelineByPropertyName = "True", Position = 0)]
        [Alias("PSPath")]
        [ValidateScript( { if ([IO.Path]::GetExtension($_) -ne ".psd1") {
                    throw "Path must point to a .psd1 file"
                } $true })]
        [string]$Path,

        # The property to be set in the manifest. It must already exist in the file (and not be commented out)
        # This searches the Manifest root properties, then the properties PrivateData, then the PSData
        [Parameter(ParameterSetName = "Overwrite")]
        [string]$PropertyName = 'ModuleVersion',

        # A new value for the property
        [Parameter(ParameterSetName = "Overwrite", Mandatory)]
        $Value,

        # By default Update-Metadata increments ModuleVersion; this controls which part of the version number is incremented
        [Parameter(ParameterSetName = "IncrementVersion")]
        [ValidateSet("Major", "Minor", "Build", "Revision")]
        [string]$Increment = "Build",

        # When set, and incrementing the ModuleVersion, output the new version number.
        [Parameter(ParameterSetName = "IncrementVersion")]
        [switch]$Passthru
    )
    process {
        $KeyValue = Get-Metadata $Path -PropertyName $PropertyName -Passthru

        if ($PSCmdlet.ParameterSetName -eq "IncrementVersion") {
            $Version = [Version]$KeyValue.GetPureExpression().Value # SafeGetValue()

            $Version = switch ($Increment) {
                "Major" {
                    [Version]::new($Version.Major + 1, 0)
                }
                "Minor" {
                    $Minor = if ($Version.Minor -le 0) {
                        1
                    } else {
                        $Version.Minor + 1
                    }
                    [Version]::new($Version.Major, $Minor)
                }
                "Build" {
                    $Build = if ($Version.Build -le 0) {
                        1
                    } else {
                        $Version.Build + 1
                    }
                    [Version]::new($Version.Major, $Version.Minor, $Build)
                }
                "Revision" {
                    $Build = if ($Version.Build -le 0) {
                        0
                    } else {
                        $Version.Build
                    }
                    $Revision = if ($Version.Revision -le 0) {
                        1
                    } else {
                        $Version.Revision + 1
                    }
                    [Version]::new($Version.Major, $Version.Minor, $Build, $Revision)
                }
            }

            $Value = $Version

            if ($Passthru) {
                $Value
            }
        }

        $Value = ConvertTo-Metadata $Value

        $Extent = $KeyValue.Extent
        while ($KeyValue.parent) {
            $KeyValue = $KeyValue.parent
        }

        $ManifestContent = $KeyValue.Extent.Text.Remove(
            $Extent.StartOffset,
            ($Extent.EndOffset - $Extent.StartOffset)
        ).Insert($Extent.StartOffset, $Value).Trim()

        if (Test-Path $Path) {
            Set-Content -Encoding UTF8 -Path $Path -Value $ManifestContent
        } else {
            $ManifestContent
        }
    }
}