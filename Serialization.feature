@Serialization
Feature: Serialize Hashtables or Custom Objects
    To allow users to configure module preferences without editing their profiles
    A PowerShell Module Author
    Needs to serialize a preferences object in a user-editable format we call metadata

    Scenario: Serialize a hashtable to string
        Given a settings hashtable
            """
            @{ UserName = "Joel"; BackgroundColor = "Black"}
            """
        When we convert the settings to metadata
        Then the string version should be
            """
            @{
              UserName = 'Joel'
              BackgroundColor = 'Black'
            }
            """

    Scenario: Should serialize core types:
        Given a settings hashtable with a String in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = ([''"])[^\1]+\1'

        Given a settings hashtable with a Boolean in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = \`$(True|False)'

        Given a settings hashtable with a NULL in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = ""'

        Given a settings hashtable with a Number in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = \d+'

        Given a settings hashtable with an Array in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = ([^,]*,)+[^,]*'


    Scenario Outline: Should support a few additional types
        Given a settings hashtable with a <type> in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = <type> "

        Examples:
            | type           |
            | DateTime       |
            | DateTimeOffset |
            | GUID           |
            | PSObject       |

    Scenario: Unsupported types should be serialized as strings
        Given a settings hashtable with an Enum in it
        Then we expect a warning
        When we convert the settings to metadata
        And the warning is called
        
        
