Feature: Module Configuration
    As a PowerShell Module Author
    I need to be able to store settings
    And override them per-user

    Background:
        Given the configuration module is imported with testing paths:
        | Enterprise                | User                | Machine                |
        | TestDrive:\EnterprisePath | TestDrive:\UserPath | TestDrive:\MachinePath |

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

    @Modules @Import
    Scenario: Loading LocalMachine Overrides
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        And a settings file named Configuration.psd1 in the Machine folder
            """
            @{
              UserName = 'Joel Bennett'
            }
            """
        When I call Import-Configuration 
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Joel Bennett
        And the settings object's Age should be 42

    @Modules @Import
    Scenario: Multi-level Overrides
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1
            """
            @{
              FullName = 'John Smith'
              BirthDay = @{
                Month = 'December'
                Day = 22
              }
            }
            """
        And a settings file named Configuration.psd1 in the Enterprise folder
            """
            @{
              FullName = 'Joel Bennett'
              UserName = 'Jaykul'
              Birthday = @{
                Month = 'May'
              }
            }
            """
        When I call Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's BirthDay should be of type hashtable
        And the settings object's BirthDay.Month should be May
        And the settings object's BirthDay.Day should be 22
        

    @Modules @Import
    Scenario: Object Property Overrides
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1
            """
            @{
              FullName = 'John Smith'
              BirthDay = PSObject @{
                Month = 'December'
                Day = 25
              }
            }
            """
        And a settings file named Configuration.psd1 in the Enterprise folder
            """
            @{
              FullName = 'Joel Bennett'
              UserName = 'Jaykul'
              Birthday = @{
                Month = 'May'
              }
            }
            """
        And a settings file named Configuration.psd1 in the User folder
            """
            @{
              FullName = 'Joel Bennett'
              UserName = 'Jaykul'
              Birthday = PSObject @{
                Day = 22
              }
            }
            """
        When I call Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's BirthDay should be of type PSCustomObject
        And the settings object's BirthDay.Month should be May
        And the settings object's BirthDay.Day should be 22
        
    @Modules @Import
    Scenario: Loading User Overrides
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1
            """
            @{
              UserName = 'John Smith'
              Age = 24
            }
            """
        And a settings file named Configuration.psd1 in the Machine folder
            """
            @{
              UserName = 'Jaykul'
            }
            """
        And a settings file named Configuration.psd1 in the Enterprise folder
            """
            @{
              Age = 42
            }
            """
        And a settings file named Configuration.psd1 in the User folder
            """
            @{
              FullName = 'Joel Bennett'
            }
            """
        When I call Import-Configuration 
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's Age should be 42

    @Modules @Import
    Scenario: Multi-level Overrides
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1 in the Enterprise folder
            """
            @{
              FullName = 'Joel Bennett'
              UserName = 'Jaykul'
              Birthday = @{
                Month = 'May'
                Day = 22
              }
            }
            """
        When I call Import-Configuration
        Then the settings object should be of type hashtable
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett
        And the settings object's BirthDay should be of type hashtable
        And the settings object's BirthDay.Month should be May
        And the settings object's BirthDay.Day should be 22
        


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