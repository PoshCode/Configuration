[CmdletBinding()]
param(
    [string]$Path = $pwd,
    [string]$Version = "1.0.0",
    [string]$Destination = "output"
)

& $PSScriptRoot\Install-RequiredModule @{
        "Configuration" = "[1.3.1,2.0)"
        "ModuleBuilder" = "2.*"
    } -TrustRegisteredRepositories

if (![IO.Path]::IsPathFullyQualified($Destination)) {
    $Destination = Join-Path $pwd $Destination
} else {
    $Destination = New-Item $Destination -ItemType Directory -Force | Convert-Path
}

$Modules = @(
    foreach ($BuildManifest in Get-ChildItem -Path $path -Filter build.psd1 -Recurse) {
        Write-Host "Build-Module -SourcePath $BuildManifest -Destination $Destination -SemVer $Version -Verbose -Passthru"
        Build-Module -SourcePath $BuildManifest -Destination $Destination -SemVer $Version -Verbose -Passthru
    }
)

$ModuleInfo = $Modules | Select-Object Name, Path, ModuleBase | ConvertTo-Json -Compress
Write-Host "::set-output name=moduleinfo::$ModuleInfo"

trap {
    $_ | Format-List | Out-Host
    throw
}
