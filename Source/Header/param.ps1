# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters = @{},
    $EnterpriseData,
    $UserData,
    $MachineData
)

Import-Module Metadata -Force -Args @($Converters) -Verbose:$false -Global