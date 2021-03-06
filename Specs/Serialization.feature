Feature: Serialize Hashtables or Custom Objects
    To allow users to configure module preferences without editing their profiles
    A PowerShell Module Author
    Needs to serialize a preferences object in a user-editable format we call metadata

    Background:
        Given the configuration module is imported with testing paths:
        | Enterprise                | User                | Machine                |
        | TestDrive:/EnterprisePath | TestDrive:/UserPath | TestDrive:/MachinePath |

    @Serialization
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

    @Serialization @ConsoleColor
    Scenario: Serialize a ConsoleColor to string
        Given a settings hashtable
            """
            @{ UserName = "Joel"; BackgroundColor = [ConsoleColor]::Black }
            """
        When we convert the settings to metadata
        Then the string version should be
            """
            @{
              UserName = 'Joel'
              BackgroundColor = (ConsoleColor Black)
            }
            """

    @Serialization
    Scenario: Should be able to serialize core types:
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

    @Serialization
    Scenario: Should be able to serialize a array
        Given a settings hashtable with an Array in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = ([^,]*,)+[^,]*'

    @Serialization
    Scenario: Should be able to serialize nested hashtables
        Given a settings hashtable with a hashtable in it
        When we convert the settings to metadata
        Then the string version should match 'TestCase = @{'


    @Serialization @SecureString @PSCredential @CRYPT32
    Scenario Outline: Should be able to serialize PSCredential
        Given a settings hashtable with a PSCredential in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = \(?PSCredential"

    @Serialization @SecureString @CRYPT32
    Scenario Outline: Should be able to serialize SecureStrings
        Given a settings hashtable with a SecureString in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = \(?ConvertTo-SecureString [a-z0-9]+"


    @Serialization @CRYPT32
    Scenario Outline: Should support a few additional types
        Given a settings hashtable with a <type> in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = \(?<type> "

        Examples:
            | type           |
            | DateTime       |
            | DateTimeOffset |
            | GUID           |
            | PSObject       |
            | PSCredential   |
            | ConsoleColor   |

    @Serialization
    Scenario: PSCustomObject preserves PSTypeNames
        Given a settings object
            """
            @{
                PSTypeName = 'Whatever.User'
                FirstName = 'Joel'
                LastName = 'Bennett'
                UserName = 'Jaykul'
                Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        When we export to a settings file named Configuration.psd1
        And we import the file to an object
        Then the settings object should have Whatever.User in the PSTypeNames

    @Serialization @Enum
    Scenario: Unsupported types should be serialized as strings
        Given a settings hashtable with an Enum in it
        Then we expect a warning in the Metadata module
        When we convert the settings to metadata
        And the warning is logged

    @Serialization @Error @Converter
    Scenario: Invalid converters should write non-terminating errors
        Given we expect an error in the Metadata module
        When we add a converter that's not a scriptblock
        And we add a converter with a number as a key
        Then the error is logged exactly 2 times

    @Serialization @Uri @Converter
    Scenario: Developers should be able to add support for other types
        Given a settings hashtable with a Uri in it
        When we add a converter for Uri types
        And we convert the settings to metadata
        Then the string version should match "TestCase = \(?Uri '.*'"


    @Serialization @File
    Scenario: Developers should be able to export straight to file
        Given a settings hashtable
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When we export to a settings file named Configuration.psd1
        Then the settings file should contain
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """

    @Deserialization @Uri @Converter
    Scenario: I should be able to import serialized data
        Given a settings hashtable
            """
            @{
              UserName = 'Joel'
              Age = 42
              LastUpdated = (Get-Date).Date
              Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        Then the settings object's Homepage should be of type Uri
        And we add a converter for Uri types
        And we convert the settings to metadata
        When we convert the metadata to an object
        Then the settings object should be of type hashtable
        Then the settings object's UserName should be of type String
        Then the settings object's Age should be of type Int32
        Then the settings object's LastUpdated should be of type DateTime
        Then the settings object's Homepage should be of type Uri

    @DeSerialization @SecureString @PSCredential @CRYPT32
    Scenario Outline: I should be able to import serialized credentials and secure strings
        Given a settings hashtable
            """
            @{
              Credential = [PSCredential]::new("UserName",(ConvertTo-SecureString Password -AsPlainText -Force))
              Password = ConvertTo-SecureString Password -AsPlainText -Force
            }
            """
        When we convert the settings to metadata
        Then the string version should match "Credential = \(?PSCredential"
        And the string version should match "Password = \(?ConvertTo-SecureString [\"a-z0-9]*"
        When we convert the metadata to an object
        Then the settings object should be of type hashtable
        Then the settings object's Credential should be of type PSCredential
        Then the settings object's Password should be of type SecureString

    @Serialization @SecureString @CRYPT32
    Scenario Outline: Should be able to serialize SecureStrings
        Given a settings hashtable with a SecureString in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = \(?ConvertTo-SecureString [a-z0-9]+"

    @Deserialization @Uri @Converter
    Scenario: I should be able to import serialized data even in PowerShell 2
        Given a settings hashtable
            """
            @{
              UserName = New-Object PSObject -Property @{ FirstName = 'Joel'; LastName = 'Bennett' }
              Age = [Version]4.2
              LastUpdated = [DateTimeOffset](Get-Date).Date
              GUID = [GUID]::NewGuid()
              Color = [ConsoleColor]::Red
            }
            """
        And we fake version 2.0 in the Metadata module
        And we add a converter for Uri types
        And we convert the settings to metadata
        When we convert the metadata to an object
        Then the settings object should be of type hashtable
        And the settings object's UserName should be of type PSObject
        And the settings object's Age should be of type String
        And the settings object's LastUpdated should be of type DateTimeOffset
        And the settings object's GUID should be of type GUID
        And the settings object's Color should be of type ConsoleColor

    @Deserialization @Uri @Converter
    Scenario: I should be able to add converters at import time
        Given the configuration module is imported with a URL converter
        And a settings hashtable
            """
            @{
              UserName = 'Joel'
              Age = 42
              Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        Then the settings object's Homepage should be of type Uri
        And we convert the settings to metadata
        Then the string version should match
            """
              Homepage = \(?Uri 'http://HuddledMasses.org/'
            """
        When we convert the metadata to an object
        Then the settings object should be of type hashtable
        And the settings object's UserName should be of type String
        And the settings object's Age should be of type Int32
        And the settings object's Homepage should be of type Uri


    @Deserialization @File
    Scenario: I should be able to import serialized data from files even in PowerShell 2
        Given a module with the name 'TestModule1'
        Given a settings file named Configuration.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        And we fake version 2.0 in the Metadata module
        When we import the file to an object
        Then the settings object should be of type hashtable
        And the settings object's UserName should be of type String
        And the settings object's Age should be of type Int32


    @Deserialization @File
    Scenario: I should be able to import serialized data regardless of file extension
        Given a module with the name 'TestModule1'
        Given a settings file named Settings.data
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When we import the file to an object
        Then the settings object should be of type hashtable
        Then the settings object's UserName should be of type String
        Then the settings object's Age should be of type Int32

    @Deserialization @File
    Scenario: Imported metadata files should be able to use PSScriptRoot
        Given a module with the name 'TestModule1'
        Given a settings file named Configuration.psd1
            """
            @{
              MyPath = Join-Path $PSScriptRoot "Configuration.psd1"
            }
            """
        And we're using PowerShell 4 or higher in the Metadata module
        When we import the file to an object
        Then the settings object should be of type hashtable
        And the settings object's MyPath should be of type String
        And the settings object MyPath should match the file's path


    @Deserialization @File
    Scenario: Bad data should generate useful errors
        Given a module with the name 'TestModule1'
        Given a settings file named Configuration.psd1
            """
            @{ UserName = }
            """
        Then trying to import the file to an object should throw
            """
            Missing statement after '=' in hash literal.
            """

    @Deserialization @File
    Scenario: Disallowed commands should generate useful errors
        Given a module with the name 'TestModule1'
        Given a settings file named Configuration.psd1
            """
            @{
                UserName = New-Object PSObject -Property @{ First = "Joel" }
            }
            """
        Then trying to import the file to an object should throw
            """
            The command 'New-Object' is not allowed in restricted language mode or a Data section.
            """

    @Serialization @Deserialization @File
    Scenario: Handling the default module manifest
        Given a module with the name 'TestModule1'
        Given a settings file named ModuleName/ModuleName.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
            }
            """
        When we import the folder path
        Then the settings object should be of type hashtable
        Then the settings object's UserName should be of type String
        Then the settings object's Age should be of type Int32

    @Serialization @Deserialization @File
    Scenario: Errors when you import missing files
        Given the settings file does not exist
        And we expect an error in the metadata module
        When we import the file to an object
        Then the error is logged


    @UpdateObject
    Scenario: Update A Hashtable
       Given a settings hashtable
            """
            @{
              UserName = 'Joel'
              Age = 41
              Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        When we update the settings with
            """
            @{
              Age = 42
            }
            """
        Then the settings object's UserName should be Joel
         And the settings object's Age should be 42

    @UpdateObject
    Scenario: Update an Object
       Given a settings object
            """
            @{
               PSTypeName = 'User'
               FirstName = 'Joel'
               LastName = 'Bennett'
               UserName = 'Jaykul'
               Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        When we update the settings with
            """
            @{
              Age = 42
            }
            """
        Then the settings object should have User in the PSTypeNames
         And the settings object's UserName should be Jaykul
         And the settings object's Age should be 42

    @UpdateObject
    Scenario: Try to Update An Object With Nothing
        Given a settings hashtable
            """
            @{
              UserName = 'Joel'
              Age = 41
              Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        When we update the settings with
            """
            """
        Then the settings object's UserName should be Joel
        And the settings object's Age should be 41

    @UpdateObject
    Scenario: Update a hashtable with important properties
       Given a settings object
            """
            @{
               PSTypeName = 'User'
               FirstName = 'Joel'
               LastName = 'Bennett'
               UserName = 'Jaykul'
               Age = 12
               Homepage = [Uri]"http://HuddledMasses.org"
            }
            """
        When we say UserName is important and update with
            """
            @{
                UserName = 'JBennett'
                Age = 42
            }
            """
        Then the settings object's UserName should be Jaykul
        And the settings object's Age should be 42
        And the settings object should have User in the PSTypeNames


    @Serialization @Deserialization @File
    Scenario: I should be able to import a manifest in order
        Given a module with the name 'TestModule1'
        Given a settings file named Configuration.psd1
            """
            @{
              UserName = 'Joel'
              Age = 42
              FullName = 'Joel Bennett'
            }
            """
        When we import the file with ordered
        Then the settings object should be of type Collections.Specialized.OrderedDictionary
        And the settings object's UserName should be of type String
        And the settings object's Age should be of type Int32
        And Key 0 is UserName
        And Key 1 is Age
        And Key 2 is FullName


    @Serialization @Deserialization @File
    Scenario: The ordered hashtable should recurse
        Given a module with the name 'TestModule1'
        Given a settings file named Configuration.psd1
            """
            @{
              Age = 42
              FullName = @{
                FirstName = 'Joel'
                LastName = 'Bennett'
              }
            }
            """
        When we import the file with ordered
        Then the settings object should be of type Collections.Specialized.OrderedDictionary
        And the settings object's FullName should be of type Collections.Specialized.OrderedDictionary

    @Regression @Serialization
    Scenario: Arrays of custom types
        Given the configuration module is imported with a URL converter
        And a settings hashtable
            """
            @{
              UserName = 'Joel'
              Domains = [Uri]"http://HuddledMasses.org", [Uri]"http://PoshCode.org", [Uri]"http://JoelBennett.net"
            }
            """
        When we convert the settings to metadata
        Then the string version should match "Domains = @\(\(?\s*Uri"
        And the string version should match "Uri 'http://huddledmasses.org/'"
        And the string version should match "Uri 'http://poshcode.org'"

    @Serialization @ScriptBlock
    Scenario Outline: Should be able to serialize ScriptBlocks
        Given a settings hashtable with a ScriptBlock in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = \(?ScriptBlock '"

    @Serialization
    Scenario Outline: Should serialize Switch statements as booleans
        Given a settings hashtable with a SwitchParameter in it
        When we convert the settings to metadata
        Then the string version should match "TestCase = \`$True"

    @Serialization
    Scenario: Has an IPsMetadataSerializable Interface
        Given the configuration module exports IPsMetadataSerializable
        And a TestClass that implements IPsMetadataSerializable
        And a settings file named Configuration.psd1
            """
            FromPsMetadata TestClass "
                @{
                    Values = @{
                        User = 'Jaykul'
                    }
                    Name = 'Joel'
                }
            "
            """
        When we import the file to an object
        Then the settings object should be of type TestClass
        And the settings object's User should be Jaykul
        And the settings object's Name should be Joel
        And the settings object's Keys should be User

    @Serialization
    Scenario: Allows specifying a list of allowed variables
        Given a settings file named Configuration.psd1
            """
            @{
                UserName = "${Env:UserName}"
                Age = 42
                FullName = $FullName
            }
            """
        And we define FullName = Joel Bennett
        And we define Env:UserName = Jaykul
        When we import the file allowing variables FullName, Env:UserName
        And the settings object's UserName should be Jaykul
        And the settings object's FullName should be Joel Bennett

