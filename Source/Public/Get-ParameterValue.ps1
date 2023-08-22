function Get-ParameterValue {
    <#
        .SYNOPSIS
            Get parameter values from PSBoundParameters + DefaultValues and optionally, a configuration file
        .DESCRIPTION
            This function gives command authors an easy way to combine default parameter values and actual arguments.
            It also supports user-specified default parameter values loaded from a configuration file.

            It returns a hashtable (like PSBoundParameters) which combines these parameter defaults with parameter values passed by the caller.
    #>
    [CmdletBinding()]
    param(
        # The base name of a configuration file to read defaults from
        # If specified, the command will read a ".psd1" file with this name
        # Suggested Value: $MyInvocation.MyCommand.Noun
        [string]$FromFile,

        # If your configuration file has defaults for multiple commands, pass
        # the top-level key which contains defaults for this invocation
        [string]$CommandKey,

        # Allows extending the valid variables which are allowed to be referenced in configuration
        # BEWARE: This exposes the value of these variables in the calling context to the configuration file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables
    )

    $CallersInvocation = $PSCmdlet.SessionState.PSVariable.GetValue("MyInvocation")
    $BoundParameters = @{} + $CallersInvocation.BoundParameters
    $AllParameters = $CallersInvocation.MyCommand.Parameters

    if ($FromFile) {
        $FromFile = [IO.Path]::ChangeExtension($FromFile, ".psd1")
    }

    $FileDefaults = if ($FromFile -and (Test-Path $FromFile)) {
        $MetadataOptions = @{
            AllowedVariables = $AllowedVariables
            PSVariable       = $PSCmdlet.SessionState.PSVariable
            ErrorAction      = "SilentlyContinue"
        }
        Write-Debug "Importing $FromFile"
        $FileValues = Import-Metadata $FromFile @MetadataOptions
        if ($CommandKey) {
            $FileValues = $FileValues.$CommandKey
        }
        $FileValues
    } else {
        @{}
    }

    # Don't support getting common parameters from the config file
    $CommonParameters = [System.Management.Automation.Cmdlet]::CommonParameters +
                        [System.Management.Automation.Cmdlet]::OptionalCommonParameters

    # Layer the defaults below config below actual parameter values
    foreach ($parameter in $AllParameters.GetEnumerator().Where({ $_.Key -notin $CommonParameters })) {
        Write-Debug "  Parameter: $($parameter.key)"
        $key = $parameter.Key

        # Support parameter aliases in the config file by changing the alias to the parameter name
        # If the value is not in the file defaults AND was not set by the user ...
        if ($FromFile -and -not $FileDefaults.ContainsKey($key) -and -not $BoundParameters.ContainsKey($key)) {
            # Check if any of the aliases are in the file defaults
            Write-Debug "  Aliases: $($parameter.Value.Aliases -join ', ')"
            foreach ($k in @($parameter.Value.Aliases)) {
                if ($null -ne $k -and $FileDefaults.ContainsKey($k)) {
                    Write-Debug "    ... Update FileDefaults[$key] from $k"
                    $FileDefaults[$key] = $FileDefaults[$k]
                    $null = $FileDefaults.Remove($k)
                    break
                }
            }
        }

        # Bound parameter values > build.psd1 values > default parameters values
        if ($CallersInvocation) {
            # If it's in the file defaults (now) AND it was not already set at a higher precedence
            if ($FromFile -and $FileDefaults.ContainsKey($Parameter) -and -not ($BoundParameters.ContainsKey($Parameter))) {
                Write-Debug "Export $Parameter = $($FileDefaults[$Parameter])"
                $BoundParameters[$Parameter] = $FileDefaults[$Parameter]
                # Set the variable in the _callers_ SessionState as well as our return hashtable
                $PSCmdlet.SessionState.PSVariable.Set($Parameter, $FileDefaults[$Parameter])
            # If it's still NOT in the file defaults and was not already set, check if there's a default value
            } elseif (-not $FileDefaults.ContainsKey($key) -and -not $BoundParameters.ContainsKey($key)) {
                # Reading the current value of the $key variable returns either the bound parameter or the default
                if ($null -ne ($value = $PSCmdlet.SessionState.PSVariable.Get($key).Value)) {
                    Write-Debug "    From Default: $($BoundParameters[$key] -join ', ')"
                    if ($value -ne ($null -as $parameter.Value.ParameterType)) {
                        $BoundParameters[$key] = $value
                    }
                }
            # Otherwise, it was set by the user, or ...
            } elseif ($BoundParameters[$key]) {
                Write-Debug "    From Parameter: $($BoundParameters[$key] -join ', ')"
            # We'll set it from the file
            } elseif ($FileDefaults[$key]) {
                Write-Debug "    From File: $($FileDefaults[$key] -join ', ')"
                $BoundParameters[$key] = $FileDefaults[$key]
            }
        }
    }

    $BoundParameters
}
