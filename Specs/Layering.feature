Feature: Multiple settings files should layer
    As a module author, I want to distribute a default config with my module so that by default it has settings
    As a machine administrator, I want to save corporate defaults so that users start with the right configuration
    As a user I want to save my own preferences because those other guys are frequently wrong
    And our custom settings shouldn't be overwritten on upgrade

    Background:
        Given the configuration module is imported with testing paths:
        | Enterprise                | User                | Machine                |
        | TestDrive:/EnterprisePath | TestDrive:/UserPath | TestDrive:/MachinePath |


    @Modules @Import @Layering
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

    @Modules @Import @Layering
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

    @Modules @Import @Layering
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

    @Modules @Import @Layering
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

    @Modules @Import @Layering
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

    @Layering @WIP
    Scenario: Save shouldn't overwrite default settings
        Given a module with the name 'MyModule1'
        And a settings file named Configuration.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When I call Export-Configuration with
            """
            @{
              UserName = 'Joel Bennett'
            }
            """
        # The settings file should not be changed:
        Then the settings file should contain
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """

