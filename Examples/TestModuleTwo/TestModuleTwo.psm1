# If your default configuration has valid defaults, but you still want them to review it,
# Provide a public Get-Configuration and test the path(s):
Write-Verbose "No Settings"
function TestStoragePath {
    $Path = Get-StoragePath
    Test-Path (Join-Path $Path "Configuration.psd1")
}

function Set-AimConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Address
    )
    process {
        $PSBoundParameters | Export-Configuration
    }
}

function Get-AimConfiguration {
    Import-Configuration
}

if (!(TestStoragePath -Verbose)) {
    Write-Warning "Not Configured"
    Write-Host @"
Welcome first-time users:
You should review and approve the configuration of this module by running:
    `$Configuration = Get-AimConfiguration
    `$Configuration

And then review the settings. When you're satisfied, approve them by:

    Set-AimConfiguration @Configuration
"@ -ForegroundColor Black -BackgroundColor Yellow
}