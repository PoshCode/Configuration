function InitializeStoragePaths {
    [CmdletBinding()]
    param(
        $EnterpriseData,
        $UserData,
        $MachineData
    )

    $PathOverrides = $MyInvocation.MyCommand.Module.PrivateData.PathOverride

    # Where the user's personal configuration settings go.
    # Highest presedence, overrides all other settings.
    if ([string]::IsNullOrWhiteSpace($UserData)) {
        if (!($UserData = $PathOverrides.UserData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to $Env:XDG_CONFIG_HOME on Linux or MacOS ($HOME/.config/)
                if (!($UserData = $Env:XDG_CONFIG_HOME)) {
                    $UserData = Join-Path $HOME .config/
                }
            } else {
                # Defaults to $Env:LocalAppData on Windows
                if (!($UserData = $Env:LocalAppData)) {
                    $UserData = [Environment]::GetFolderPath("LocalApplicationData")
                }
            }
        }
    }

    # On some systems there are "roaming" user configuration stored in the user's profile. Overrides machine configuration
    if ([string]::IsNullOrWhiteSpace($EnterpriseData)) {
        if (!($EnterpriseData = $PathOverrides.EnterpriseData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to the first value in $Env:XDG_CONFIG_DIRS on Linux or MacOS (or $HOME/.local/share/)
                if (!($EnterpriseData = @($Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator))[0] )) {
                    $EnterpriseData = Join-Path $HOME .local/share/
                }
            } else {
                # Defaults to $Env:AppData on Windows
                if (!($EnterpriseData = $Env:AppData)) {
                    $EnterpriseData = [Environment]::GetFolderPath("ApplicationData")
                }
            }
        }
    }

    # Machine specific configuration. Overrides defaults, but is overriden by both user roaming and user local settings
    if ([string]::IsNullOrWhiteSpace($MachineData)) {
        if (!($MachineData = $PathOverrides.MachineData)) {
            if ($IsLinux -or $IsMacOs) {
                # Defaults to /etc/xdg elsewhere
                $XdgConfigDirs = $Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator) | Where-Object { $_ -and (Test-Path $_) }
                if (!($MachineData = if ($XdgConfigDirs.Count -gt 1) {
                            $XdgConfigDirs[1]
                        })) {
                    $MachineData = "/etc/xdg/"
                }
            } else {
                # Defaults to $Env:ProgramData on Windows
                if (!($MachineData = $Env:ProgramAppData)) {
                    $MachineData = [Environment]::GetFolderPath("CommonApplicationData")
                }
            }
        }
    }

    Join-Path $EnterpriseData powershell
    Join-Path $UserData powershell
    Join-Path $MachineData powershell
}

$EnterpriseData, $UserData, $MachineData = InitializeStoragePaths -EnterpriseData $EnterpriseData -UserData $UserData -MachineData $MachineData