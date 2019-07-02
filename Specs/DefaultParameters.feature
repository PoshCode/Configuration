Feature: Configure Command From Working Directory

    There is a command to support loading default parameter values from the working directory

    Background:
        Given a passthru command 'Test-Verb' with UserName and Age parameters

    @Functions @Import
    Scenario: Loading Default Settings
        Given a local file named Verb.psd1
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
        Given a local file named Verb.psd1
            """
            @{
            UserName = 'Joel'
            Age = 42
            }
            """
        When I call Test-Verb Mark
        Then the output object's userName should be Mark
        And the output object's Age should be 42

        When I call Test-Verb -Age 10
        Then the output object's userName should be Joel
        And the output object's Age should be 10

    @Functions @Import
    Scenario: Parameter Values
        Given an example New-User command
        And a local file named User.psd1
            """
            @{
                Domain = 'HuddledMasses.org'
            }
            """
        When I call New-User Joel Bennett
        Then the output object's EMail should be Joel.Bennett@HuddledMasses.org

    @Functions @Import
    Scenario: Parameter Values
        Given an example New-User command
        And a local file named SecurityUser.psd1
            """
            @{
                Domain = 'HuddledMasses.org'
                Permissions = @{
                    Azure = "Admin1"
                }
            }
            """
        When I call New-User Joel Bennett -Department Security
        Then the output object's EMail should be Joel.Bennett@HuddledMasses.org
        And the output object's Permissions should be of type [hashtable]
        And the output object's Permissions.Azure should be of type [string]
        And the output object's Permissions.Azure should be Admin1