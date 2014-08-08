$PSModuleAutoLoadingPreference = "None"

Given 'the configuration module is imported with testing paths:' {
    param($Table)
    Remove-Module Configuration -EA 0
    Import-Module .\Configuration.psm1 -Args $Table.Enterprise, $Table.User, $Table.Machine -Scope Global
}

When "a script with the name '(.+)'" {
    param($name)
    Set-Content "TestDrive:\${name}.ps1" "Get-StoragePath"
    $Script:ScriptName = $Name
}

When "a module with the name '(.+?)'(?: by the company '(.+)')?" {
    param($name, $Company = "")

    $ModulePath = "TestDrive:\Modules\$name"
    Remove-Module $name -ErrorAction SilentlyContinue
    Remove-Item $ModulePath -Recurse -ErrorAction SilentlyContinue
    $null = mkdir $ModulePath -Force
    $Env:PSModulePath = $Env:PSModulePath + ";TestDrive:\Modules" -replace "(;TestDrive:\\Modules)+?$", ";TestDrive:\Modules"

    Set-Content $ModulePath\${Name}.psm1 "function GetStoragePath {Get-StoragePath @Args }"

    New-ModuleManifest $ModulePath\${Name}.psd1 -RootModule .\${Name}.psm1 -Description "A Super Test Module" -Company $Company

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
