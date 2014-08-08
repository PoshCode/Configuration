@StoragePath
Feature: Local Storage Paths
    In order for module settings to survive upgrades
    A PowerShell Module Author
    Needs a place outside their module to save settings
    By default, it should be the "RoamingData" path used by enterprises

    Background:
        Given the configuration module is imported with testing paths:
        | Enterprise                | User                | Machine                |
        | TestDrive:\EnterprisePath | TestDrive:\UserPath | TestDrive:\MachinePath |

    @Scripts
    Scenario: Scripts get automatic storage paths
        Given a script with the name 'SuperTestScript'
        Then the script's Enterprise path should match '^TestDrive:\\EnterprisePath\\' and '\\Scripts\\SuperTestScript$'
        And the script's Enterprise path should exist already

    @Modules 
    Scenario Outline: Modules get automatic storage paths
        Given a module with the name '<modulename>'
        Then the module's Enterprise path should match '^TestDrive:\\EnterprisePath\\' and '\\Modules\\<modulename>$'
        And the module's Enterprise path should exist already

        Examples: A few different module names
            | modulename        |
            | SuperTestModule   |
            | AnotherTestModule |
            | ThirdModuleName   |

    @Modules
    Scenario Outline: There should be a way to store settings at the Machine and User scope too
        Given a module with the name '<modulename>'
        Then the module's <scope> path should match '^<root>' and '\\Modules\\<modulename>$'
        And the module's <scope> path should exist already

        Examples:
            | scope      | modulename      | root                         |
            | Enterprise | SuperTestModule | TestDrive:\\\\EnterprisePath |
            | Machine    | SuperTestModule | TestDrive:\\\\MachinePath    |
            | User       | SuperTestModule | TestDrive:\\\\UserPath       |
            | AppDomain  | SuperTestModule | TestDrive:\\\\EnterprisePath |

    @Modules
    Scenario Outline: To allow us to upgrade, settings should be versionable
        Given a module with the name 'SuperTestModule'
        Then the module's Enterprise path should match '^TestDrive:\\EnterprisePath\\' and '\\Modules\\SuperTestModule$'
        But the module's storage path should end with a version number if one is passed in

    @Modules
    Scenario Outline: To support differentiation, settings should support a company name
        Given a module with the name 'SuperTestModule' by the company 'PoshCode'
        Then the module's Enterprise path should match '^TestDrive:\\EnterprisePath\\' and '\\Modules\\PoshCode\\SuperTestModule$'
        But the module's storage path should end with a version number if one is passed in

