A module for saving and loading settings and configuration for PowerShell modules (and scripts).

The Configuration module is something I have been meaning to pull out of the PoshCode packaging module for awhile, since it already exists in PoshCode. 

I finally started working on this while I work on writing the Gherkin support for Pester. That support will be merged into Pester after the Pester 3.0 release, but in the meantime, I'm using it to test this module! My [Gherkin branch of Pester](https://github.com/Jaykul/Pester/tree/Gherkin) has the test code for ``Invoke-Gherkin`` and this module is serving as the first trial usage.

In any case, this module is mostly I'm writing the module by porting code from my PoshCode module, but I'm doing so only as I develop the specs (the .feature files) and the Gherkin support to run them! Anything you see here has 100% code coverage in the feature and step files, and is executable by the code in my "Gherkin" branch of Pester.

You can try it by running:

    Invoke-Gherkin -CodeCoverage .\Configuration.psm1