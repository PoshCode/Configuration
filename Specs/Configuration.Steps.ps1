$PSModuleAutoLoadingPreference = "None"

BeforeEachFeature {
    Remove-Module Configuration -ErrorAction Ignore -Force
}
AfterEachFeature {
    Remove-Module Configuration -ErrorAction Ignore -Force
    Import-Module Configuration
}

Given 'the configuration module is imported with testing paths:' {
    param($Table)
    $ModuleBase = (Get-Module Configuration -ListAvailable | Sort Version -Descending)[0].ModuleBase
    Remove-Module Configuration -ErrorAction Ignore -Force
    Import-Module $ModuleBase\Configuration.psd1 -Args @($null, $Table.Enterprise, $Table.User, $Table.Machine) -Scope Global
}

Given 'the configuration module is imported with a URL converter' {
    param($Table)
    $ModuleBase = "."
    $ModuleBase = (Get-Module Configuration).ModuleBase
    Remove-Module Configuration -ErrorAction Ignore -Force
    Import-Module $ModuleBase\Configuration.psd1 -Args @{
                [Uri] = { "Uri '$_' " }
                "Uri" = {
                    param([string]$Value)
                    [Uri]$Value
                }
            } -Scope Global
}

Given 'the manifest module is imported' {
    param($Table)
    $ModuleBase = (Get-Module Configuration).ModuleBase
    Remove-Module Configuration, Manifest
    Import-Module $ModuleBase\Manifest.psm1 -Scope Global
}

Given "a module with(?:\s+\w+ name '(?<name>.+?)'|\s+\w+ the company '(?<company>.+?)'|\s+\w+ the author '(?<author>.+?)')+" {
    param($name, $Company = "", $Author = "")

    $ModulePath = "TestDrive:\Modules\$name"
    Remove-Module $name -ErrorAction Ignore
    Remove-Item $ModulePath -Recurse -ErrorAction Ignore
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

    $LocalStoragePath = GetStoragePath -Scope $Scope
    foreach($PathAssertion in $Path) {
        $LocalStoragePath | Should $Comparator $PathAssertion
    }
}

Given "a script with the name '(.+)' that calls Get-StoragePath with no parameters" {
    param($name)
    Set-Content "TestDrive:\${name}.ps1" "Get-StoragePath"
    $ScriptName = $Name
}
Given "a script with the name '(?<File>.+)' that calls Get-StoragePath (?:-Name (?<Name>\w*) ?|-Author (?<Author>\w*) ?){2}" {
    param($File, $Name, $Author)
    Set-Content "TestDrive:\${File}.ps1" "Get-StoragePath -Name $Name -Author $Author"
    $ScriptName = $File
}

Then "the script should throw an exception$" {
    { $LocalStoragePath = iex "TestDrive:\${ScriptName}.ps1" } | Should throw
}


Then "the script's (\w+) path should (\w+) (.+)$" {
    param($Scope, $Comparator, $Path)

    [string[]]$Path = $Path -split "\s*and\s*" | %{ $_.Trim("['`"]") }

    $LocalStoragePath = iex "TestDrive:\${ScriptName}.ps1"
    foreach($PathAssertion in $Path) {
        $LocalStoragePath | Should $Comparator $PathAssertion
    }
}

When "the module's storage path should end with a version number if one is passed in" {
    GetStoragePath -Version "2.0" | Should Match "\\2.0$"
    GetStoragePath -Version "4.0" | Should Match "\\4.0$"
}


When "a settings hashtable" {
    param($hashtable)
    $Settings = iex "[ordered]$hashtable"
}

When "we update the settings with" {
    param($hashtable)
    $Update = if($hashtable) {
        iex $hashtable
    } else {
        $null
    }

    $Settings = $Settings | Update-Object $Update
}

When "a (?:settings file|module manifest) named (\S+)(?:(?: in the (?<Scope>\S+) folder)|(?: for version (?<Version>[0-9.]+)))*" {
    param($fileName, $hashtable, $Scope = $null, $Version = $null)

    if($Scope -and $Version) {
        $folder = GetStoragePath -Scope $Scope -Version $Version
    } elseif($Scope) {
        $folder = GetStoragePath -Scope $Scope
    } elseif($Version) {
        $folder = GetStoragePath -Version $Version
    } elseif(Test-Path "$ModulePath") {
        $folder = $ModulePath
    } else {
        $folder = "TestDrive:\"
    }
    $SettingsFile = Join-Path $folder $fileName

    $Parent = Split-Path $SettingsFile
    if(!(Test-Path $Parent)) {
        $null = mkdir $Parent -Force -EA 0
    }
    Set-Content $SettingsFile -Value $hashtable
}

Then "the settings object MyPath should match the file's path" {
    $Settings.MyPath | Should Be ${SettingsFile}
}

When "a settings hashtable with an? (.+) in it" {
    param($type)
    $Settings = @{
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
        "ConsoleColor" {
            $Settings.TestCase = [ConsoleColor]::Red
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
    $SettingsMetadata = ConvertTo-Metadata $Settings

    # Write-Debug $SettingsMetadata
    $Wide = $Host.UI.RawUI.WindowSize.Width
    Write-Verbose $SettingsMetadata
}

When "we export to a settings file named (.*)" {
    param($fileName)
    if(!$ModulePath -or !(Test-Path $ModulePath)) {
        $ModulePath = "TestDrive:\"
    }
    $SettingsFile = Join-Path $ModulePath $fileName
    $File = $Settings | Export-Metadata ${SettingsFile} -Passthru
    $File.FullName | Should Be (Convert-Path $SettingsFile)
}


When "we convert the metadata to an object" {
    $Settings = ConvertFrom-Metadata $SettingsMetadata

    Write-Verbose (($Settings | Out-String -Stream | % TrimEnd) -join "`n")
}


When "we import the file to an object" {
    $Settings = Import-Metadata ${SettingsFile}

    Write-Verbose (($Settings | Out-String -Stream | % TrimEnd) -join "`n")
}


When "we import the file with ordered" {
    $Settings = Import-Metadata ${SettingsFile} -Ordered

    Write-Verbose (($Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "we import the folder path" {
    $Settings = Import-Metadata (Split-Path ${SettingsFile})

    Write-Verbose (($Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "trying to import the file to an object should throw(.*)" {
    param([string]$Message)
    { $Settings = Import-Metadata ${SettingsFile} } | Should Throw $Message.trim()
}

When "the string version should (\w+)\s*(.*)?" {
    param($operator, $data)
    # Normalize line endings, because the module does:
    $meta = ($SettingsMetadata -replace "\r?\n","`n")
    $data = $data.trim('"''')  -replace "\r?\n","`n"
    # And then actually test it
    $meta | Should $operator $data
}

When "the settings file should (\w+)\s*(.*)?" {
    param($operator, $data)
    # Normalize line endings, because the module does:
    $data = [regex]::escape(($data -replace "\r?\n","`n")) -replace '\\n','\r?\n'
    if($operator -eq "Contain"){ $operator = "ContainMultiline"}
    ${SettingsFile} | Should $operator $data
}

Given "the settings file does not exist" {
    #
    if(!$ModulePath -or !(Test-Path $ModulePath)) {
        $ModulePath = "TestDrive:\"
    }
    if(!${SettingsFile}) {
        $SettingsFile = Join-Path $ModulePath "NoSuchFile.psd1"
    }
    if(Test-Path $SettingsFile) {
        Remove-Item $SettingsFile
    }
}


# This step will create verifiable/counting loggable mocks for Write-Warning, Write-Error, Write-Verbose
When "we expect an? (?<type>warning|error|verbose) in the (?<module>.*) module" {
    param($type, $module)
    $ErrorModule = $module

    Mock -Module $ErrorModule Write-$type { $true } -Verifiable
    # The Metadata module hides itself a little bit
    if($Type -eq "Error" -and ($ErrorModule -eq "Metadata")) {
        Mock -Module $ErrorModule WriteError { Write-Error "Error" -TargetObject $Args }
    }
}

# this step lets us verify the number of calls to those three mocks
When "the (?<type>warning|error|verbose) is logged(?: (?<exactly>exactly) (\d+) times?)?" {
    param($count, $exactly, $type)
    $param = @{}
    if($count) {
        $param.Exactly = $Exactly -eq "Exactly"
        $param.Times = $count
    }

    Assert-MockCalled -Module $ErrorModule -Command Write-$type @param
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
    $Settings | Should BeOfType $Type
}


Then "the settings object should have an? (.*) of type (.*)" {
    param([String]$Parameter, [Type]$Type)
    $Settings.$Parameter | Should BeOfType $Type
}

Then "the settings object's (.*) should (be of type|be) (.*)" {
    param([String]$Parameter, [String]$operator, $Expected)
    $Value = $Settings

    # Write-Debug ($Settings | Out-String)

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

Then "Key (\d+) is (\w+)" {
    param([int]$index, [string]$name)
    $Settings.Keys | Select -Index $index | Should Be $Name
}

Given "a mock PowerShell version (.*)" {
    param($version)
    $PSVersion = [Version]$version
    $PSDefaultParameterValues."Test-PSVersion:Version" = $PSVersion
}

When "we fake version 2.0 in the Metadata module" {
    &(Get-Module Configuration) {
        &(Get-Module Metadata) {
            $PSDefaultParameterValues."Test-PSVersion:Version" = [Version]"2.0"
        }
    }
}

When "we're using PowerShell 4 or higher in the Metadata module" {
    &(Get-Module Configuration) {
        &(Get-Module Metadata) {
            $null = $PSDefaultParameterValues.Remove("Test-PSVersion:Version")
            $PSVersionTable.PSVersion -ge ([Version]"4.0") | Should Be $True
        }
    }
}

Given "the actual PowerShell version" {
    $PSVersion = $PSVersionTable.PSVersion
    $null = $PSDefaultParameterValues.Remove("Test-PSVersion:Version")
}

Then "the Version -(..) (.*)" {
    param($comparator, $version)

    if($version -eq "the version") {
        [Version]$version = $PSVersion
    } else {
        [Version]$version = $version
    }

    $test = @{ $comparator = $version }
    Test-PSVersion @test | Should Be $True
}

When "I call Import-Configuration" {
    $Settings = ImportConfiguration

    Write-Verbose (($Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "I call Import-Configuration with a Version" {
    $Settings = ImportConfigVersion

    Write-Verbose (($Settings | Out-String -Stream | % TrimEnd) -join "`n")
}

When "I call Export-Configuration with" {
    param($configuration)
    iex "$configuration" | ExportConfiguration
}

When "I call Export-Configuration with a Version" {
    param($configuration)
    iex "$configuration" | ExportConfigVersion
}

When "I call Get-Metadata (\S+)(?: (\S+))?" {
    param($path, $name)
    Push-Location $ModulePath
    try {
        if($name) {
            $Result = Get-Metadata $path $name
        } else {
            $Result = Get-Metadata $path
        }
    } finally {
        Pop-Location
    }
}

When "I call Update-Metadata (\S+)(?: (\S+))?" {
    param($path, $name)
    Push-Location $ModulePath
    try {
        if($name) {
            $Result = Update-Metadata $path $name
        } else {
            $Result = Update-Metadata $path
        }
    } finally {
        Pop-Location
    }
}

When "I call Update-Metadata (\S+) -Increment (\S+)" {
    param($path, $name)
    Push-Location $ModulePath
    try {
        $Result = Update-Metadata $path -Increment $name
    } finally {
        Pop-Location
    }
}


Then "the result should be (.*)" {
    param($value)
    $Result | Should Be $value
}


Then "a settings file named (\S+) should exist(?:(?: in the (?<Scope>\S+) folder)|(?: for version (?<Version>[0-9.]+)))*" {
    param($fileName, $hashtable, $Scope = $null, $Version = $null)

    if($Scope -and $Version) {
        $folder = GetStoragePath -Scope $Scope -Version $Version
    } elseif($Scope) {
        $folder = GetStoragePath -Scope $Scope
    } elseif($Version) {
        $folder = GetStoragePath -Version $Version
    } elseif(Test-Path "${ModulePath}") {
        $folder = $ModulePath
    } else {
        $folder = "TestDrive:\"
    }
    $SettingsFile = Join-Path $folder $fileName
    $SettingsFile | Should Exist
}
