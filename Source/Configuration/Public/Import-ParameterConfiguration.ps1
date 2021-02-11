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
        .EXAMPLE
            Given that you've written a script like:

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
                Import-ParameterConfiguration -Recurse
                # Possibly calculated based on (default) parameter values
                if (-not $UserName) { $UserName = "$FirstName.$LastName" }
                if (-not $EMail)    { $EMail = "$UserName@$Domain" }

                # Lots of work to create the user's AD account, email, set permissions etc.

                # Output an object:
                [PSCustomObject]@{
                    PSTypeName  = "MagicUser"
                    FirstName   = $FirstName
                    LastName    = $LastName
                    EMail       = $EMail
                    Department  = $Department
                    Permissions = $Permissions
                }
            }

            You could create a User.psd1 in a folder with just:

            @{ Domain = "HuddledMasses.org" }

            Now the following command would resolve the `User.psd1`
            And the user would get an appropriate email address automatically:

            PS> New-User Joel Bennett

            FirstName   : Joel
            LastName    : Bennett
            EMail       : Joel.Bennett@HuddledMasses.org

        .EXAMPLE
            Import-ParameterConfiguration works recursively (up through parent folders)

            That means it reads config files in the same way git reads .gitignore,
            with settings in the higher level files (up to the root?) being
            overridden by those in lower level files down to the WorkingDirectory

            Following the previous example to a ridiculous conclusion,
            we could automate creating users by creating a tree like:

            C:\HuddledMasses\Security\Admins\ with a User.psd1 in each folder:

            # C:\HuddledMasses\User.psd1:
            @{
                Domain = "HuddledMasses.org"
            }

            # C:\HuddledMasses\Security\User.psd1:
            @{
                Department = "Security"
                Permissions = @{
                    Access = "User"
                }
            }

            # C:\HuddledMasses\Security\Admins\User.psd1
            @{
                Permissions = @{
                    Access = "Administrator"
                }
            }

            And then switch to the Admins directory and run:

            PS> New-User Joel Bennett

            FirstName   : Joel
            LastName    : Bennett
            EMail       : Joel.Bennett@HuddledMasses.org
            Department  : Security
            Permissions : { Access = Administrator }

        .EXAMPLE
            Following up on our earlier example, let's look at a way to use imagine that -FileName parameter.
            If you wanted to use a different configuration files than your Noun, you can pass the file name in.

            You could even use one of your parameters to generate the file name. If we modify the function like ...

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

            Now you could create a `SecurityUser.psd1`

            @{
                Domain = "HuddledMasses.org"
                Permissions = @{
                    Access = "Administrator"
                }
            }

            And run:

            PS> New-User Joel Bennett -Department Security
    #>
    [CmdletBinding()]
    param(
        # The folder the configuration should be read from. Defaults to the current working directory
        [string]$WorkingDirectory = $pwd,
        # The name of the configuration file.
        # The default value is your command's Noun, with the ".psd1" extention.
        # So if you call this from a command named Build-Module, the noun is "Module" and the config $FileName is "Module.psd1"
        [string]$FileName,

        # If set, considers configuration files in the parent, and it's parent recursively
        [switch]$Recurse,

        # Allows extending the valid variables which are allowed to be referenced in configuration
        # BEWARE: This exposes the value of these variables in the calling context to the configuration file
        # You are reponsible to only allow variables which you know are safe to share
        [String[]]$AllowedVariables
    )

    $CallersInvocation = $PSCmdlet.SessionState.PSVariable.GetValue("MyInvocation")
    $BoundParameters = @{} + $CallersInvocation.BoundParameters
    $AllParameters = $CallersInvocation.MyCommand.Parameters.Keys
    if (-not $PSBoundParameters.ContainsKey("FileName")) {
        $FileName = "$($CallersInvocation.MyCommand.Noun).psd1"
    }

    $MetadataOptions = @{
        AllowedVariables = $AllowedVariables
        PSVariable       = $PSCmdlet.SessionState.PSVariable
        ErrorAction      = "SilentlyContinue"
    }

    do {
        $FilePath = Join-Path $WorkingDirectory $FileName

        Write-Debug "Initializing parameters for $($CallersInvocation.InvocationName) from $(Join-Path $WorkingDirectory $FileName)"
        if (Test-Path $FilePath) {
            $ConfiguredDefaults = Import-Metadata $FilePath @MetadataOptions

            foreach ($Parameter in $AllParameters) {
                # If it's in the defaults AND it was not already set at a higher precedence
                if ($ConfiguredDefaults.ContainsKey($Parameter) -and -not ($BoundParameters.ContainsKey($Parameter))) {
                    Write-Debug "Export $Parameter = $($ConfiguredDefaults[$Parameter])"
                    $BoundParameters.Add($Parameter, $ConfiguredDefaults[$Parameter])
                    # This "SessionState" is the _callers_ SessionState, not ours
                    $PSCmdlet.SessionState.PSVariable.Set($Parameter, $ConfiguredDefaults[$Parameter])
                }
            }
        }
        Write-Debug "Recurse:$Recurse -and $($BoundParameters.Count) of $($AllParameters.Count) Parameters and $WorkingDirectory"
    } while ($Recurse -and ($AllParameters.Count -gt $BoundParameters.Count) -and ($WorkingDirectory = Split-Path $WorkingDirectory))
}