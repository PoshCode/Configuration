@Version
Feature: A Mockable PowerShell Version test
    To allow testing for the version of PowerShell while mocking the version
    A PowerShell Module Author
    Needs a way to test the current version that can be mocked

    @Changes
    Scenario: Test the current PowerShell version
        Given the actual PowerShell version
        Then the Version -eq the Version
        And the Version -lt 10.0
        And the Version -le 10.0
        And the Version -gt 1.0
        And the Version -ge 1.0
        And the Version -ge the Version
        And the Version -le the Version
        And the Version -ne 1.0
        And the Version -ne 10.0

    Scenario: Test an old PowerShell version
        Given a mock PowerShell version 2.0
        Then the Version -eq 2.0
        And the Version -lt 10.0
        And the Version -le 10.0
        And the Version -gt 1.0
        And the Version -ge 1.0
        And the Version -ge 2.0
        And the Version -le 2.0
        And the Version -ne 1.0
        And the Version -ne 10.0
