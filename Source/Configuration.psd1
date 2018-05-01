@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = '.\Configuration.psm1'

# Version number of this module.
ModuleVersion = '1.3.0'

# ID used to uniquely identify this module
GUID = 'e56e5bec-4d97-4dfd-b138-abbaa14464a6'

# Author of this module
Author = @('Joel Bennett')

# Company or vendor of this module
CompanyName = 'HuddledMasses.org'

# HelpInfo URI of this module
# HelpInfoURI = ''

# Copyright statement for this module
Copyright = 'Copyright (c) 2014-2017 by Joel Bennett, all rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for storing and reading configuration values, with full PS Data serialization, automatic configuration for modules and scripts, etc.'

# We explicitly name the functions we want to be visible, but we export everything with '*'
FunctionsToExport = 'Import-Configuration','Export-Configuration','Get-StoragePath','Add-MetadataConverter',
                    'ConvertFrom-Metadata','ConvertTo-Metadata','Export-Metadata','Import-Metadata',
                    'Update-Manifest','Get-ManifestValue','*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all files packaged with this module
FileList = @('.\Configuration.psd1','.\Configuration.psm1','.\Metadata.psm1','.\en-US\about_Configuration.help.txt')

PrivateData = @{
    # Allows overriding the default paths where Configuration stores it's configuration
    # Within those folders, the module assumes a "powershell" folder and creates per-module configuration folders
    PathOverride = @{
        # Where the user's personal configuration settings go.
        # Highest presedence, overrides all other settings.
        # Defaults to $Env:LocalAppData on Windows
        # Defaults to $Env:XDG_CONFIG_HOME elsewhere ($HOME/.config/)
        UserData       = ""
        # On some systems there are "roaming" user configuration stored in the user's profile. Overrides machine configuration
        # Defaults to $Env:AppData on Windows
        # Defaults to $Env:XDG_CONFIG_DIRS elsewhere (or $HOME/.local/share/)
        EnterpriseData = ""
        # Machine specific configuration. Overrides defaults, but is overriden by both user roaming and user local settings
        # Defaults to $Env:ProgramData on Windows
        # Defaults to /etc/xdg elsewhere
        MachineData    = ""
    }
    # PSData is module packaging and gallery metadata embedded in PrivateData
    # It's for the PoshCode and PowerShellGet modules
    # We had to do this because it's the only place we're allowed to extend the manifest
    # https://connect.microsoft.com/PowerShell/feedback/details/421837
    PSData = @{
        # Keyword tags to help users find this module via navigations and search.
        Tags = @('Development','Configuration','Settings','Storage')

        # The web address of this module's project or support homepage.
        ProjectUri = "https://github.com/PoshCode/Configuration"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri = "http://opensource.org/licenses/MIT"

        # Release notes for this particular version of the module
        ReleaseNotes = '
        v2.0.0: Bump version to hide 1.2 and justify the change to the save paths.
                Rename Get-StoragePath to Get-ConfigurationPath (old name is aliased)
        v1.2.0: Add Support for Linux and MacOS
                Stop using `mkdir -Force` because it does not work on Linux
                Add default paths for posix systems based on XDG standards
                Add logic for overriding the default paths in the Manifest
                Fix a bug in PSObject serialization (from v1.1.1)
                Fix bug with special property names (like PSObject) caused by dot notation
                Fix tests so they run cross-platform
                ACCIDENTALLY changed default save paths:
                   Using "powershell" instead of WindowsPowerShell (even in WindowsPowerShell)
        v1.1.0: Added support for ScriptBlocks and SwitchParameters
                Added support for serializing objects as hashtables
        '

        # Indicates this is a pre-release/testing version of the module.
        IsPrerelease = 'False'
    }
}

}


