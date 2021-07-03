# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters = @{},
    $EnterpriseData,
    $UserData,
    $MachineData
)

$ConfigurationRoot = Get-Variable PSScriptRoot* -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "PSScriptRoot" } | ForEach-Object { $_.Value }
if (!$ConfigurationRoot) {
    $ConfigurationRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

Import-Module "${ConfigurationRoot}\Metadata.psm1" -Force -Args @($Converters) -Verbose:$false