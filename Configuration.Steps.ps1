$PSModuleAutoLoadingPreference = "None"

Remove-Module Configuration -EA 0
Import-Module .\Configuration.psd1

Given 'the configuration module is imported with testing paths:' {
    param($Table)
    Remove-Module Configuration -EA 0
    Import-Module .\Configuration.psd1 -Args $Table.Enterprise, $Table.User, $Table.Machine -Scope Global
}

When "a script with the name '(.+)'" {
    param($name)
    Set-Content "TestDrive:\${name}.ps1" "Get-StoragePath"
    $Script:ScriptName = $Name
}

When "a module with(?:\s+\w+ name '(?<name>.+?)'|\s+\w+ the company '(?<company>.+?)'|\s+\w+ the author '(?<author>.+?)')+" {
    param($name, $Company = "", $Author = "")

    $ModulePath = "TestDrive:\Modules\$name"
    Remove-Module $name -ErrorAction SilentlyContinue
    Remove-Item $ModulePath -Recurse -ErrorAction SilentlyContinue
    $null = mkdir $ModulePath -Force
    $Env:PSModulePath = $Env:PSModulePath + ";TestDrive:\Modules" -replace "(;TestDrive:\\Modules)+?$", ";TestDrive:\Modules"

    Set-Content $ModulePath\${Name}.psm1 "function GetStoragePath {Get-StoragePath @Args }"

    New-ModuleManifest $ModulePath\${Name}.psd1 -RootModule .\${Name}.psm1 -Description "A Super Test Module" -Company $Company -Author $Author

    # New-ModuleManifest sets things even when we don't want it to:
    if(!$Author) {
        Set-Content $ModulePath\${Name}.psd1 ((Get-Content $ModulePath\${Name}.psd1) -Replace "^(Author.*)$", '#$1')
    }
    if(!$Company) {
        Set-Content $ModulePath\${Name}.psd1 ((Get-Content $ModulePath\${Name}.psd1) -Replace "^(Company.*)$", '#$1')
    }

    Import-Module $ModulePath\${Name}.psd1
}

When "the module's (\w+) path should (\w+) (.+)$" {
    param($Scope, $Comparator, $Path)

    [string[]]$Path = $Path -split "\s*and\s*" | %{ $_.Trim("['`"]") }

    $script:LocalStoragePath = GetStoragePath -Scope $Scope
    foreach($PathAssertion in $Path) {
        $script:LocalStoragePath | Should $Comparator $PathAssertion
    }
}

When "the script's (\w+) path should (\w+) (.+)$" {
    param($Scope, $Comparator, $Path)

    [string[]]$Path = $Path -split "\s*and\s*" | %{ $_.Trim("['`"]") }

    $script:LocalStoragePath = iex "TestDrive:\${ScriptName}.ps1"
    foreach($PathAssertion in $Path) {
        $script:LocalStoragePath | Should $Comparator $PathAssertion
    }
}

When "the module's storage path should end with a version number if one is passed in" {
    GetStoragePath -Version "2.0" | Should Match "\\2.0$"
    GetStoragePath -Version "4.0" | Should Match "\\4.0$"
}


When "a settings hashtable" {
    param($hashtable)
    $script:Settings = iex "[ordered]$hashtable"
}

When "a settings file named (.*)" {
    param($fileName, $hashtable)
    $Script:SettingsFile = $fileName
    Set-Content TestDrive:\$fileName -Value $hashtable
}

Then "the settings object MyPath should match the file's path" {
    $script:Settings.MyPath | Should Be "TestDrive:\${Script:SettingsFile}"
}

When "a settings hashtable with an? (.+) in it" {
    param($type)
    $script:Settings = @{
        UserName = $Env:UserName
    }

    switch($type) {
        "NULL" {
            $Settings.TestCase = $Null
        }
        "Enum" {
            $Settings.TestCase = [Security.PolicyLevelType]::Enterprise
        }
        "String" {
            $Settings.TestCase = "Test"
        }
        "Number" {
            $Settings.OneTestCase = 42
            $Settings.TwoTestCase = 42.9
        }
        "Array"  {
            $Settings.TestCase = "One", "Two", "Three"
        }
        "Boolean"  {
            $Settings.OneTestCase = $True
            $Settings.TwoTestCase = $False
        }
        "DateTime" {
            $Settings.TestCase = Get-Date
        }
        "DateTimeOffset" {
            $Settings.TestCase = [DateTimeOffset](Get-Date)
        }
        "GUID" {
            $Settings.TestCase = [GUID]::NewGuid()
        }
        "PSObject" {
            $Settings.TestCase = New-Object PSObject -Property @{ Name = $Env:UserName }
        }
        "Uri" {
            $Settings.TestCase = [Uri]"http://HuddledMasses.org"
        }
        "Hashtable" {
            $Settings.TestCase = @{ Key = "Value"; ANother = "Value" }
        }
        default {
            throw "missing test type"
        }
    }
}

When "we add a converter for (.*) types" {
    param($Type)
    switch ($Type) {
        "Uri" {
            Add-MetadataConverter @{
                [Uri] = { "Uri '$_' " }
                "Uri" = {
                    param([string]$Value)
                    [Uri]$Value
                }
            }
        }
        default {
            throw "missing converter type"
        }
    }
}



When "we convert the settings to metadata" {
    $script:SettingsMetadata = ConvertTo-Metadata $script:Settings

    $Wide = $Host.UI.RawUI.WindowSize.Width
    Write-Verbose $script:SettingsMetadata
}

When "we convert the metadata to an object" {
    $script:Settings = ConvertFrom-Metadata $script:SettingsMetadata

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "we convert the file to an object" {
    $script:Settings = ConvertFrom-Metadata TestDrive:\${Script:SettingsFile}

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}


When "the string version should (\w+)\s*(.*)?" {
    param($operator, $data)
    # I have to normalize line endings:
    $meta = ($script:SettingsMetadata -replace "\r?\n","`n")
    $data = $data.trim('"''')  -replace "\r?\n","`n"
    # And then actually test it
    $meta | Should $operator $data
}

# This step will create verifiable/counting loggable mocks for Write-Warning, Write-Error, Write-Verbose
When "we expect an? (?<type>warning|error|verbose)" {
    param($type)
    Mock -Module Metadata Write-$type { $true } -Verifiable
}

# this step lets us verify the number of calls to those three mocks
When "the (?<type>warning|error|verbose) is logged(?: (?<exactly>exactly) (\d+) times)?" {
    param($count, $exactly, $type)
    $param = @{}
    if($count) {
        $param.Exactly = $Exactly -eq "Exactly"
        $param.Times = $count
    }
    Assert-MockCalled -Module Metadata -Command Write-$type @param
}

When "we add a converter that's not a scriptblock" {
    Add-MetadataConverter @{
        "Uri" = "
            param([string]$Value)
            [Uri]$Value
        "
    }
}

When "we add a converter with a number as a key" {
    Add-MetadataConverter @{
        42 = {
            param([string]$Value)
            $Value
        }
    }
}

# Then the error is logged exactly 2 times

Then "the settings object should be a (.*)" {
    param([Type]$Type)
    $script:Settings -is $Type | Should Be $true
}


Then "the settings object should have an? (.*) of type (.*)" {
    param([String]$Parameter, [Type]$Type)
    $script:Settings.$Parameter -is $Type | Should Be $true
}

Given "a mock PowerShell version (.*)" {
    param($version)
    $script:PSVersion = [Version]$version
    $script:PSDefaultParameterValues."Test-PSVersion:Version" = $script:PSVersion
}

When "we fake version 2.0 in the Metadata module" {
    &(Get-Module Configuration) {
        &(Get-Module Metadata) {
            $script:PSDefaultParameterValues."Test-PSVersion:Version" = [Version]"2.0"
        }
    }
}

When "we're using PowerShell 4 or higher in the Metadata module" {
    &(Get-Module Configuration) {
        &(Get-Module Metadata) {
            $null = $script:PSDefaultParameterValues.Remove("Test-PSVersion:Version")
            $PSVersionTable.PSVersion -ge ([Version]"4.0") | Should Be $True
        }
    }
}

Given "the actual PowerShell version" {
    $script:PSVersion = $PSVersionTable.PSVersion
    $null = $script:PSDefaultParameterValues.Remove("Test-PSVersion:Version")
}

Then "the Version -(..) (.*)" {
    param($comparator, $version)

    if($version -eq "the version") {
        [Version]$version = $script:PSVersion
    } else {
        [Version]$version = $version
    }

    $test = @{ $comparator = $version }
    Test-PSVersion @test | Should Be $True
}

