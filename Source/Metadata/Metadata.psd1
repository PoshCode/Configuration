@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'Metadata.psm1'

# Version number of this module.
ModuleVersion = '1.3.1'

# ID used to uniquely identify this module
GUID = 'c7505d40-646d-46b5-a440-8a81791c5d23'

# Author of this module
Author = @('Joel Bennett')

# Company or vendor of this module
CompanyName = 'HuddledMasses.org'

# Copyright statement for this module
Copyright = 'Copyright (c) 2014-2018 by Joel Bennett, all rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for PowerShell data serialization'

# We explicitly name the functions we want to be visible, but we export everything with '*'
FunctionsToExport = 'Add-MetadataConverter','ConvertFrom-Metadata','ConvertTo-Metadata',
                    'Export-Metadata','Import-Metadata','Update-Metadata','Udpate-Object'

# Prerelease metadata to make ModuleBuilder happy
PrivateData   = @{ PSData = @{ Prerelease = "" } }

}
