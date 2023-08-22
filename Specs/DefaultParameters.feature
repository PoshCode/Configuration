Feature: Get PSBoundParameters plus default values plus a config file

    There is a command to support merging PSBoundParameters with parmeter default values
    That command supports overwriting the default values with values from a config file

    Background:
        Given the configuration module is imported

    @Functions @ParameterValue
    Scenario: Loading Default Settings
        Given a passthru command 'Test-Verb' with UserName and Age=42 parameters that calls Get-ParameterValue
        When I call Test-Verb Joel
        Then the output object's UserName should be Joel
        And the output object's Age should be 42

    @Functions @ParameterValue
    Scenario: Loading Default Settings
        Given a passthru command 'Test-Verb' with UserName and Age=12 parameters that calls Get-ParameterValue
        When I call Test-Verb Joel
        Then the output object's UserName should be Joel
        And the output object's Age should be 12

    @Functions @ParameterValue
    Scenario: Overriding Default Settings
        Given a passthru command 'Test-Verb' with UserName='Sarah' and Age=12 parameters that calls Get-ParameterValue
        When I call Test-Verb Joel 24
        Then the output object's UserName should be Joel
        And the output object's Age should be 24

    @Functions @ParameterValue
    Scenario: Configuration file
        Given a passthru command 'Test-Verb' with UserName='Sarah' and Age=12 parameters that calls Get-ParameterValue with a file config
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

    @Functions @ParameterValue
    Scenario: Configuration file with aliases
        Given a passthru command 'Test-Verb' with UserName='Sarah' and Age=12 parameters that calls Get-ParameterValue with a file config
        And a settings file named Verb.psd1 in the current folder
            """
            @{
            UserName = 'Joel'
            Age = 42
            Alias = 'Supports Aliases'
            }
            """
        When I call Test-Verb -Age 10
        Then the output object's userName should be Joel
        And the output object's Age should be 10
        And the output object's ExtraParameter should be Supports Aliases
