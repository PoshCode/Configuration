function Import-ParameterConfiguration {
    <#
        .SYNOPSIS
            Loads a metadata file based on the calling command name and combines the values there with the parameter values of the calling function.
        .DESCRIPTION
            This function gives command authors and users an easy way to let the default parameter values of the command be set by a configuration file in the folder you call it from.

            Normally, you have three places to get parameter values from. In priority order, they are:
            - Parameters passed by the caller always win
            - The PowerShell $PSDefaultParameterValues hashtable appears to the function as if the user passed it
            - Default parameter values (defined in the function)

            If you call this command at the top of a function, it overrides (only) the default parameter values with

            - Values from a manifest file in the present working directory ($pwd)
        .Example
            Given that you've written a script like:

            function New-User {
                [CmdletBinding()]
                param(
                    $FirstName,
                    $LastName,
                    $UserName,
                    $Domain,
                    $EMail
                )
                Import-ParameterConfiguration
                # Possibly calculated based on (default) parameter values
                if (-not $UserName) { $UserName = "$FirstName.$LastName" }
                if (-not $EMail)    { $EMail = "$UserName@$Domain" }

                # Lots of work to create the user's AD account and email etc.
                [PSCustomObject]@{
                    PSTypeName = "MagicUser"
                    FirstName = $FirstName
                    LastName = $LastName
                    EMail      = $EMail
                }
            }

            You could create a User.psd1 in a folder with just:

            @{ Domain = "HuddledMasses.org" }

            Now the following command would resolve the `User.psd1`
            And the user would get an appropriate email address automatically:

            PS> New-User Joel Bennett

        .Example
            Following up on our earlier example, imagine that you wanted different configuration files for each department ...

            You could create department specific files in your folder, like Security-User.psd1 with something like

            @{
                Domain = "HuddledMasses.org"
                Permissions = @{
                    # whatever you need
                }
            }

            And then modify your function like ...

            function New-User {
                [CmdletBinding()]
                param(
                    $FirstName,
                    $LastName,
                    $UserName,
                    $Domain,
                    $EMail,
                    $Department,
                    [hashtable]$Permissions
                )
                Import-ParameterConfiguration -FileName "${Department}User.psd1"
                # Possibly calculated based on (default) parameter values
                if (-not $UserName) { $UserName = "$FirstName.$LastName" }
                if (-not $EMail)    { $EMail = "$UserName@$Domain" }

                # Lots of work to create the user's AD account and email etc.
                [PSCustomObject]@{
                    PSTypeName = "MagicUser"
                    FirstName = $FirstName
                    LastName = $LastName
                    EMail      = $EMail
                    # Passthru for testing
                    Permissions = $Permissions
                }
            }

            Now the following command would resolve the `SecurityUser.psd1`
            And the user would get appropriate permissions automatically:

            PS> New-User Joel Bennett -Department Security
    #>
    [CmdletBinding()]
    param(
        # The folder the configuration should be read from. Defaults to the current working directory
        [string]$WorkingDirectory = $pwd,
        # The name of the configuration file.
        # The default value is your command's Noun, with the ".psd1" extention.
        # So if you call this from a command named Build-Module, the noun is "Module" and the config $FileName is "Module.psd1"
        [string]$FileName
    )

    $CallersInvocation = @(Get-PSCallStack)[1].InvocationInfo
    if (-not $PSBoundParameters.ContainsKey("FileName")) {
        $FileName = "$($CallersInvocation.MyCommand.Noun).psd1"
    }

    $FileName = Join-Path $WorkingDirectory $FileName

    if (Test-Path $FileName) {
        Write-Debug "Initializing parameters for $($CallersInvocation.InvocationName) from $(Join-Path $WorkingDirectory $CallersInvocation.MyCommand.Noun).psd1"
        $ConfiguredDefaults = Import-Metadata $FileName -ErrorAction SilentlyContinue

        foreach ($Parameter in $CallersInvocation.MyCommand.Parameters.Keys) {
            # If it's in the defaults AND it was not passed in as a parameter ...
            if ($ConfiguredDefaults.ContainsKey($Parameter) -and -not ($CallersInvocation.BoundParameters -and $CallersInvocation.BoundParameters.ContainsKey($Parameter))) {
                Write-Debug "Export $Parameter = $($ConfiguredDefaults[$Parameter])"
                # This "SessionState" is the _callers_ SessionState, not ours
                $PSCmdlet.SessionState.PSVariable.Set($Parameter, $ConfiguredDefaults[$Parameter])
            }
        }
    }
}