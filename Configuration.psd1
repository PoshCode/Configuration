@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = '.\Configuration.psm1'

# Version number of this module.
ModuleVersion = '0.2'

# ID used to uniquely identify this module
GUID = 'e56e5bec-4d97-4dfd-b138-abbaa14464a6'

# Author of this module
Author = @('Joel Bennett')

# Company or vendor of this module
CompanyName = 'HuddledMasses.org'

# Copyright statement for this module
Copyright = 'Copyright (c) 2014 by Joel Bennett, all rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for storing and reading configuration values'

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all files packaged with this module
# FileList = @()

PrivateData = @{
    # PSData is module packaging and gallery metadata embedded in PrivateData
    # It's for the PoshCode and PowerShellGet modules
    # We had to do this because it's the only place we're allowed to extend the manifest
    # https://connect.microsoft.com/PowerShell/feedback/details/421837
    PSData = @{
        # The primary categorization of this module (from the TechNet Gallery tech tree).
        # Category = ""

        # Keyword tags to help users find this module via navigations and search.
        Tags = @('Development','Configuration','Settings','Storage')

        # The web address of an icon which can be used in galleries to represent this module
        # IconUri = ""

        # The web address of this module's project or support homepage.
        # ProjectUri = ""

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        # LicenseUri = ""

        # Release notes for this particular version of the module
        # ReleaseNotes = False

        # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
        # RequireLicenseAcceptance = ""

        # Indicates this is a pre-release/testing version of the module.
        IsPrerelease = 'True'

    }
}

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
