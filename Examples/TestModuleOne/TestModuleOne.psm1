# If your default configuration has some blank settings, you can do something like this:
# Assume I have a mandatory credential:
function ImportConfiguration {
    $Configuration = Import-Configuration
    if(!$Configuration.Credential.Password.Length) {
        Write-Warning "Thanks for using the Acme Industries Module, please run Set-AimConfiguration to configure."
        throw "Module not configured. Run Set-AimConfiguration"
    }
    $Configuration
}

function Set-AimConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]$Address,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if ($_.Password.Length -eq 0) {
                throw "Credential must include a password."
            }
            $true
        })]
        [PSCredential]$Credential
    )
    end {
        $PSBoundParameters | Export-Configuration
    }
}

# Test for it **during** module import:
try {
    $null = ImportConfiguration
} catch {
    # Hide the error on import, just warn them
    Write-Host "You must configure module to avoid this warning on first run. Use Set-AimConfiguration" -ForegroundColor Black -BackgroundColor Yellow
}