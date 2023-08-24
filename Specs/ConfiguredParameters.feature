Feature: Configure Command From Working Directory

    There is a command to support loading default parameter values from the working directory

    Background:
        Given the configuration module is imported with testing paths:
            | Enterprise                | User                | Machine                |
            | TestDrive:/EnterprisePath | TestDrive:/UserPath | TestDrive:/MachinePath |

    @Functions @Import
    Scenario: Loading Default Settings
        Given a passthru command 'Test-Verb' with UserName and Age parameters
        And a settings file named Verb.psd1 in the current folder
            """
            @{
            UserName = 'Joel'
            Age = 42
            }
            """
        When I call Test-Verb
        Then the output object's userName should be Joel
        And the output object's Age should be 42

    @Functions @Import
    Scenario: Overriding Default Settings
        Given a passthru command 'Test-Verb' with UserName and Age parameters
        And a settings file named Verb.psd1 in the current folder
            """
            @{
            UserName = 'Joel'
            Age = 42
            }
            """
        When I call Test-Verb Mark
        Then the output object's userName should be Mark
        And the output object's Age should be 42

    @Functions @Import
    Scenario: Overriding Default Settings Works on any Parameter
        Given a passthru command 'Test-Verb' with UserName and Age parameters
        And a settings file named Verb.psd1 in the current folder
            """
            @{
            UserName = 'Joel'
            Age = 42
            }
            """
        When I call Test-Verb -Age 10
        Then the output object's userName should be Joel
        And the output object's Age should be 10

    @Functions @Import
    Scenario: New-User Example
        Given an example New-User command
        And a settings file named User.psd1 in the current folder
            """
            @{
                Domain = 'HuddledMasses.org'
            }
            """
        When I call New-User Joel Bennett
        Then the output object's EMail should be Joel.Bennett@HuddledMasses.org

    @Functions @Import
    Scenario: New-User Example Two (overwriting)
        Given an example New-User command
        And a settings file named User.psd1 in the current folder
            """
            @{
                Permissions = @{
                    Access = "Administrator"
                }
            }
            """
        And a settings file named User.psd1 in the parent folder
            """
            @{
                Department = "Security"
                Permissions = @{
                    Access = "User"
                }
            }
            """
        And a settings file named User.psd1
            """
            @{
                Domain = "HuddledMasses.org"
            }
            """
        When I call New-User Joel Bennett
        Then the output object's EMail should be Joel.Bennett@HuddledMasses.org
        And the output object's Department should be Security
        And the output object's Permissions should be of type [hashtable]
        And the output object's Permissions.Access should be Administrator


    @Functions @Import
    Scenario: New-User Example Three
        Given an example New-User command
        And a settings file named SecurityUser.psd1 in the current folder
            """
            @{
                Domain = 'HuddledMasses.org'
                Permissions = @{
                    Access = "Administrator"
                }
            }
            """
        When I call New-User Joel Bennett -Department Security
        Then the output object's EMail should be Joel.Bennett@HuddledMasses.org
        And the output object's Permissions should be of type [hashtable]
        And the output object's Permissions.Access should be of type [string]
        And the output object's Permissions.Access should be Administrator