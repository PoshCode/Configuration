@StoragePath
Feature: Automatically Calculate Local Storage Paths on Linux
    In order for module settings to survive upgrades
    A PowerShell Module Author
    Needs a place outside their module to save settings
    For developer guidelines, see: http://msdn.microsoft.com/en-us/library/windows/apps/hh465094.aspx
    We create a module-specific storage location inside the operating-system specified data paths:
    By default, we store in the $Env:AppData user roaming path that Windows synchronizes (C:/Users/USERNAME/AppData/Roaming)
    But we  support using the $Env:ProgramData machine-local path instead (C:/ProgramData)
    As well as the machine-specific $Env:LocalAppData user data path (C:/Users/USERNAME/AppData/Local)

    @Modules @Linux
    Scenario Outline: On Linux the default configuration paths are different
        Given the configuration module is imported on Linux:
        Given a module with the name '<modulename>' with the author 'Jaykul'
        Then the module's <scope> path should match '^<rootpattern>' and '/Jaykul/<modulename>$'
        And the module's <scope> path should exist already

        Examples:
            | scope      | modulename      | rootpattern    |
            | Enterprise | SuperTestModule | ~/.local/share |
            | Machine    | SuperTestModule | /etc/xdg       |
            | User       | SuperTestModule | ~/.config      |

    @Modules
    Scenario Outline: Modules storage paths work at load time on Linux
        Given the configuration module is imported on Linux:
        Given a module with the name 'SimpleTest' by the author 'Joel Bennett'
        Then the module's user path at load time should match '^~/.config' and '/Joel Bennett/SimpleTest$'
        And the module's user path should exist already

    @Modules @Linux
    Scenario Outline: There should be a way to store settings at the Machine and User scope on Linux too
        Given the configuration module is imported with testing paths on Linux:
        | Enterprise                | User                | Machine                |
        | TestDrive:/EnterprisePath | TestDrive:/UserPath | TestDrive:/MachinePath |
        Given a module with the name '<modulename>' with the author ''
        Then the module's <scope> path should match '^<rootpattern>' and '/AnonymousModules/<modulename>$'
        And the module's <scope> path should exist already

        Examples:
            | scope      | modulename      | rootpattern               |
            | Enterprise | SuperTestModule | TestDrive:/EnterprisePath |
            | Machine    | SuperTestModule | TestDrive:/MachinePath    |
            | User       | SuperTestModule | TestDrive:/UserPath       |
