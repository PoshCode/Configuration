Feature: Module Configuration
    As a PowerShell Module Author
    I need to be able to store settings
    And override them per-user

    Background:
        Given the configuration module is imported with testing paths:
        | Enterprise                | User                | Machine                |
        | TestDrive:/EnterprisePath | TestDrive:/UserPath | TestDrive:/MachinePath |

    @Modules @Import
    Scenario: Loading Default Settings
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When I call Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object should have a UserName of type String
        And the settings object should have an Age of type Int32


    @Modules @EndUsers
    Scenario: End users should be able to read the configuration data for a module
        Given a module with the name 'SuperTestModule' by the company 'PoshCode' and the author 'Jaykul'
        And a settings file named Configuration.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When the ModuleInfo is piped to Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object should have a UserName of type String
        And the settings object should have an Age of type Int32

    @Modules @Import @EndUsers
    Scenario: End users should be able to work with configuration data outside the module
        Given a module with the name 'SuperTestModule'
        And a settings file named Configuration.psd1 in the Enterprise folder
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When the ModuleInfo is piped to Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object should have a UserName of type String
        And the settings object should have an Age of type Int32

    @Modules @Import
    Scenario: SxS Versions
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1 in the Enterprise folder
            """
            @{
              FullName = 'John Smith'
              BirthDay = @{
                Month = 'December'
                Day = 22
              }
            }
            """
        And a settings file named Configuration.psd1 in the Enterprise folder for version 2.0
            """
            @{
              FullName = 'Joel Bennett'
              UserName = 'Jaykul'
              Birthday = @{
                Month = 'May'
              }
            }
            """
        When I call Import-Configuration with a version
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's BirthDay should be of type hashtable
        And the settings object's BirthDay.Month should be May
        And the settings object's BirthDay.Day should be null

    @Modules @Export
    Scenario: Exporting creates the expected files
        Given a module with the name 'MyModule1' and the author 'Bob'
        And a settings file named Configuration.psd1
            """
            @{
              FullName = 'John Smith'
              UserName = 'Jaykul'
              BirthDay = @{
                Month = 'December'
                Day = 22
              }
            }
            """
        When I call Export-Configuration with
            """
            @{
              FullName = 'Joel Bennett'
              Birthday = @{
                Month = 'May'
              }
            }
            """
        Then a settings file named Configuration.psd1 should exist in the Enterprise folder
        When I call Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's BirthDay should be of type hashtable
        And the settings object's BirthDay.Month should be May
        And the settings object's BirthDay.Day should be 22


    @Modules @Export
    Scenario: Exporting supports versions
        Given a module with the name 'MyModule1' and the author 'Bob'
        And a settings file named Configuration.psd1
            """
            @{
              FullName = 'John Smith'
              UserName = 'Jaykul'
              BirthDay = @{
                Month = 'December'
                Day = 22
              }
            }
            """
        When I call Export-Configuration with a version
            """
            @{
              FullName = 'Joel Bennett'
              Birthday = @{
                Month = 'May'
              }
            }
            """
        Then a settings file named Configuration.psd1 should exist in the Enterprise folder for version 2.0

        When I call Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object's FullName should be John Smith
        And the settings object's BirthDay.Month should be December

        When I call Import-Configuration with a version
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's BirthDay should be of type hashtable
        And the settings object's BirthDay.Month should be May
        And the settings object's BirthDay.Day should be 22

    # @WIP
    # Scenario: Migrate settings only once
    #     Given MyModule has a new version
    #     And I have some settings from an old version
    #     When I load the settings in the new module
    #     Then the settings from the old version should be copied
    #     And MyModule should be able to migrate them
    #     But they should save only to the new version