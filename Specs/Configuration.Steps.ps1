$PSModuleAutoLoadingPreference = "None"

Remove-Module Configuration -EA 0
Import-Module .\Configuration.psd1

Given 'the configuration module is imported with testing paths:' {
    param($Table)
    Remove-Module Configuration -EA 0
    Import-Module .\Configuration.psd1 -Args @($null, $Table.Enterprise, $Table.User, $Table.Machine) -Scope Global
}

Given 'the configuration module is imported with a URL converter' {
    param($Table)
    Remove-Module Configuration -EA 0
    Import-Module .\Configuration.psd1 -Args @{
                [Uri] = { "Uri '$_' " }
                "Uri" = {
                    param([string]$Value)
                    [Uri]$Value
                }
            } -Scope Global
}

Given "a module with(?:\s+\w+ name '(?<name>.+?)'|\s+\w+ the company '(?<company>.+?)'|\s+\w+ the author '(?<author>.+?)')+" {
    param($name, $Company = "", $Author = "")

    $Script:ModulePath = "TestDrive:\Modules\$name"
    Remove-Module $name -ErrorAction SilentlyContinue
    Remove-Item $ModulePath -Recurse -ErrorAction SilentlyContinue
    $null = mkdir $ModulePath -Force
    $Env:PSModulePath = $Env:PSModulePath + ";TestDrive:\Modules" -replace "(;TestDrive:\\Modules)+?$", ";TestDrive:\Modules"

    Set-Content $ModulePath\${Name}.psm1 "
    function GetStoragePath { Get-StoragePath @Args }
    function ImportConfiguration { Import-Configuration }
    function ImportConfigVersion { Import-Configuration -Version 2.0 }
    filter ExportConfiguration { `$_ | Export-Configuration }
    filter ExportConfigVersion { `$_ | Export-Configuration -Version 2.0 }
    "

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

Given "a script with the name '(.+)' that calls Get-StoragePath with no parameters" {
    param($name)
    Set-Content "TestDrive:\${name}.ps1" "Get-StoragePath"
    $Script:ScriptName = $Name
}
Given "a script with the name '(?<File>.+)' that calls Get-StoragePath (?:-Name (?<Name>\w*) ?|-Author (?<Author>\w*) ?){2}" {
    param($File, $Name, $Author)
    Set-Content "TestDrive:\${File}.ps1" "Get-StoragePath -Name $Name -Author $Author"
    $Script:ScriptName = $File
}

Then "the script should throw an exception$" {
    { $script:LocalStoragePath = iex "TestDrive:\${ScriptName}.ps1" } | Should throw
}


Then "the script's (\w+) path should (\w+) (.+)$" {
    param($Scope, $Comparator, $Path)

    [string[]]$Path = $Path -split "\s*and\s*" | %{ $_.Trim("['`"]") }

    $script:LocalStoragePath = iex "TestDrive:\${Script:ScriptName}.ps1"
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

When "we update the settings with" {
    param($hashtable)
    $Update = if($hashtable) {
        iex $hashtable
    } else {
        $null
    }

    $script:Settings = $script:Settings | Update-Object $Update
}

When "a settings file named (\S+)(?:(?: in the (?<Scope>\S+) folder)|(?: for version (?<Version>[0-9.]+)))*" {
    param($fileName, $hashtable, $Scope = $null, $Version = $null)

    if($Scope -and $Version) {
        $folder = GetStoragePath -Scope $Scope -Version $Version
    } elseif($Scope) {
        $folder = GetStoragePath -Scope $Scope
    } elseif($Version) {
        $folder = GetStoragePath -Version $Version
    } elseif(Test-Path "${Script:ModulePath}") {
        $folder = $Script:ModulePath
    } else {
        $folder = "TestDrive:\"
    }
    $Script:SettingsFile = Join-Path $folder $fileName

    $Parent = Split-Path $Script:SettingsFile
    if(!(Test-Path $Parent)) {
        $null = mkdir $Parent -Force -EA 0
    }
    Set-Content $Script:SettingsFile -Value $hashtable
}

Then "the settings object MyPath should match the file's path" {
    $script:Settings.MyPath | Should Be ${Script:SettingsFile}
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
        "PSCredential" {
            $Settings.TestCase = New-Object PSCredential @("UserName", (ConvertTo-SecureString -AsPlainText -Force -String "Password"))
        }
        "SecureString" {
            $Settings.TestCase = ConvertTo-SecureString -AsPlainText -Force -String "Password"
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

When "we export to a settings file named (.*)" {
    param($fileName)
    if(!$Script:ModulePath -or !(Test-Path $Script:ModulePath)) {
        $Script:ModulePath = "TestDrive:\"
    }
    $Script:SettingsFile = Join-Path $Script:ModulePath $fileName
    $File = $script:Settings | Export-Metadata ${Script:SettingsFile} -Passthru
    $File.FullName | Should Be (Convert-Path $SettingsFile)
}


When "we convert the metadata to an object" {
    $script:Settings = ConvertFrom-Metadata $script:SettingsMetadata

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}


When "we import the file to an object" {
    $script:Settings = Import-Metadata ${Script:SettingsFile}

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "we import the folder path" {
    $script:Settings = Import-Metadata (Split-Path ${Script:SettingsFile})

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "trying to import the file to an object should throw(.*)" {
    param([string]$Message)
    { $script:Settings = Import-Metadata ${Script:SettingsFile} } | Should Throw $Message.trim()
}

When "the string version should (\w+)\s*(.*)?" {
    param($operator, $data)
    # I have to normalize line endings:
    $meta = ($script:SettingsMetadata -replace "\r?\n","`n")
    $data = $data.trim('"''')  -replace "\r?\n","`n"
    # And then actually test it
    $meta | Should $operator $data
}

When "the settings file should (\w+)\s*(.*)?" {
    param($operator, $data)
                    # I have to normalize line endings:
    $data = [regex]::escape(($data -replace "\r?\n","`n"))
    if($operator -eq "Contain"){ $operator = "ContainMultiline"}
    Get-Item ${Script:SettingsFile} | Should $operator $data
}
# This step will create verifiable/counting loggable mocks for Write-Warning, Write-Error, Write-Verbose
When "we expect an? (?<type>warning|error|verbose)" {
    param($type)
    Mock -Module Metadata Write-$type { $true } -Verifiable
    if($Type -eq "Error") {
        Mock -Module Metadata WriteError { Write-Error "Error" -TargetObject $Args } -Verifiable
        Mock -Module Metadata ThrowError { Write-Error "Error" -TargetObject $Args } -Verifiable
    }
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

Then "the settings object should be of type (.*)" {
    param([Type]$Type)
    $script:Settings | Should BeOfType $Type
}


Then "the settings object should have an? (.*) of type (.*)" {
    param([String]$Parameter, [Type]$Type)
    $script:Settings.$Parameter | Should BeOfType $Type
}

Then "the settings object's (.*) should (be of type|be) (.*)" {
    param([String]$Parameter, [String]$operator, $Expected)
    $Value = $script:Settings

    Write-Debug ($Settings | Out-String)

    foreach($property in $Parameter.Split(".")) {
        $value = $value.$property
    }

    $operator = $operator -replace " "

    if($Operator -eq "be" -and $Expected -eq "null") {
        $value | Should BeNullOrEmpty
    } else {
        $value | Should $operator $Expected
    }
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

When "I call Import-Configuration" {
    $script:Settings = ImportConfiguration

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "I call Import-Configuration with a Version" {
    $script:Settings = ImportConfigVersion

    Write-Verbose (($script:Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "I call Export-Configuration with" {
    param($configuration)
    iex "$configuration" | ExportConfiguration
}

When "I call Export-Configuration with a Version" {
    param($configuration)
    iex "$configuration" | ExportConfigVersion
}

Then "a settings file named (\S+) should exist(?:(?: in the (?<Scope>\S+) folder)|(?: for version (?<Version>[0-9.]+)))*" {
    param($fileName, $hashtable, $Scope = $null, $Version = $null)

    if($Scope -and $Version) {
        $folder = GetStoragePath -Scope $Scope -Version $Version
    } elseif($Scope) {
        $folder = GetStoragePath -Scope $Scope
    } elseif($Version) {
        $folder = GetStoragePath -Version $Version
    } elseif(Test-Path "${Script:ModulePath}") {
        $folder = $Script:ModulePath
    } else {
        $folder = "TestDrive:\"
    }
    $Script:SettingsFile = Join-Path $folder $fileName
    $Script:SettingsFile | Should Exist
}
