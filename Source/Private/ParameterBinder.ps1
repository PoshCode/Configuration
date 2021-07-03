function ParameterBinder {
    if (!$Module) {
        [System.Management.Automation.PSModuleInfo]$Module = . {
            $Command = ($CallStack)[0].InvocationInfo.MyCommand
            $mi = if ($Command.ScriptBlock -and $Command.ScriptBlock.Module) {
                $Command.ScriptBlock.Module
            } else {
                $Command.Module
            }

            if ($mi -and $mi.ExportedCommands.Count -eq 0) {
                if ($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object { ($_.Name -eq $mi.Name) -and $_.ExportedCommands } | Select-Object -First 1) {
                    $mi = $mi2
                }
            }
            $mi
        }
    }

    if (!$CompanyName) {
        [String]$CompanyName = . {
            if ($Module) {
                $CName = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]", "_"
                if ($CName -eq "Unknown" -or -not $CName) {
                    $CName = $Module.Author
                    if ($CName -eq "Unknown" -or -not $CName) {
                        $CName = "AnonymousModules"
                    }
                }
                $CName
            } else {
                "AnonymousScripts"
            }
        }
    }

    if (!$Name) {
        [String]$Name = $(if ($Module) {
                $Module.Name
            } <# else { ($CallStack)[0].InvocationInfo.MyCommand.Name } #>)
    }

    if (!$DefaultPath -and $Module) {
        [String]$DefaultPath = $(if ($Module) {
                Join-Path $Module.ModuleBase Configuration.psd1
            })
    }
}
