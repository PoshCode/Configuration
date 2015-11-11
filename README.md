A module for saving and loading settings and configuration for PowerShell modules (and scripts).




A little history:
=================

The Configuration module is something I first wrote as part of the PoshCode packaging module and have been meaning to pull out for awhile. 

I finally started working on this while I work on writing the Gherkin support for Pester. That support will be merged into Pester after the Pester 3.0 release, but in the meantime, I'm using it to test this module! My [LanguageDecoupling branch of Pester](https://github.com/Jaykul/Pester/tree/LanguageDecoupling) has the test code for ``Invoke-Gherkin`` and this module is serving as the first trial usage.

In any case, this module is mostly code ported from my PoshCode module as I develop the specs (the .feature files) and the Gherkin support to run them! Anything you see here has better than 98% code coverage in the feature and step files, and is executable by the code in my "Gherkin" branch of Pester.

For the tests to work, you need to make sure that the module isn't already loaded, because the tests import it with the file paths mocked. You can unload the module like this:

    Remove-Module Configuration -ErrorAction SilentlyContinue

And verify the tests with this command, assuming you get my Pester fork:

    Invoke-Gherkin -CodeCoverage *.psm1
