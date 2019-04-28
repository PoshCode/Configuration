Feature: Manifest Read and Write
    As a PowerShell Module Author
    I want to easily edit my manifest as part of my build script

    Background:
        Given the configuration module is imported with testing paths:
        | Enterprise                | User                | Machine                |
        | TestDrive:/EnterprisePath | TestDrive:/UserPath | TestDrive:/MachinePath |

    @Modules @Import
    Scenario: Read ModuleVersion from a module manifest by default
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'

                # ID used to uniquely identify this module
                GUID = 'e56e5bec-4d97-4dfd-b138-abbaa14464a6'
            }
            """
        When I call Get-Metadata ModuleName.psd1
        Then the result should be 0.4

    Scenario: Read a named value from a module manifest
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'

                Description = 'This is the day'
            }
            """
        When I call Get-Metadata ModuleName.psd1 Description
        Then the result should be This is the day

    Scenario: Read a named value from a module manifest PrivateData
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'

                PrivateData = @{
                    MyVeryOwnKey = "Test Value"
                }
            }
            """
        When I call Get-Metadata ModuleName.psd1 MyVeryOwnKey
        Then the result should be Test Value

    Scenario: Read the release notes from a module manifest PSData
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'

                PrivateData = @{
                    MyVeryOwnKey = "Test Value"
                    PSData = @{
                        ReleaseNotes = "Nothing has changed"
                    }
                }
            }
            """
        When I call Get-Metadata ModuleName.psd1 ReleaseNotes
        Then the result should be Nothing has changed


    Scenario: Attempt to read a non-existent value
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'
            }
            """
        Given we expect an error in the Metadata module
        When I call Get-Metadata ModuleName.psd1 NoSuchThing
        Then the error is logged exactly 1 time


    Scenario: Update the module version by default
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'
            }
            """
        When I call Update-Metadata ModuleName.psd1
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 0.4.1

    Scenario: Update the module major version
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Major
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 1.0

    Scenario: Update the module minor version
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Minor
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 0.5

    Scenario: Update the module minor version when it's 0
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '1.0'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Minor
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 1.1

    Scenario: Update the module build version
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4.1'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Build
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 0.4.2

    Scenario: Update the module build version when it's 0
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Build
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 0.4.1

    Scenario: Update the module revision
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '4.3.2.1'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Revision
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 4.3.2.2

    Scenario: Update the module revision when the build isn't set
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'
            }
            """
        When I call Update-Metadata ModuleName.psd1 -Increment Revision
        And I call Get-Metadata ModuleName.psd1
        Then the result should be 0.4.0.1


    @Regression
    Scenario: Get Arrays from a metadata file
        Given a module with the name 'ModuleName'
        And a module manifest named ModuleName.psd1
            """
            @{
                # Script module or binary module file associated with this manifest.
                ModuleToProcess = './Configuration.psm1'

                # Version number of this module.
                ModuleVersion = '0.4'

                AliasesToExport = @('Get-StoragePath', 'Get-ManifestValue', 'Update-Manifest')
            }
            """
        When I call Get-Metadata ModuleName.psd1 AliasesToExport
        Then the result should be @('Get-StoragePath', 'Get-ManifestValue', 'Update-Manifest')