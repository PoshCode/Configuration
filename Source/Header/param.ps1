# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters = @{},
    $EnterpriseData,
    $UserData,
    $MachineData
)

if ($Converters.Keys) {
    Add-MetadataConverter $Converters
}
