function Update-Object {
    <#
      .Synopsis
         Recursively updates a hashtable or custom object with new values
      .Description
         Updates the InputObject with data from the update object, updating or adding values.
      .Example
         Update-Object -Input @{
            One = "Un"
            Two = "Dos"
         } -Update @{
            One = "Uno"
            Three = "Tres"
         }

         Updates the InputObject with the values in the UpdateObject,
         will return the following object:

         @{
            One = "Uno"
            Two = "Dos"
            Three = "Tres"
         }
   #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")] # Because PSSCriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The object (or hashtable) with properties (or keys) to overwrite the InputObject
        [AllowNull()]
        [Parameter(Position = 0, Mandatory = $true)]
        $UpdateObject,

        # This base object (or hashtable) will be updated and overwritten by the UpdateObject
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        $InputObject,

        # A list of values which (if found on InputObject) should not be updated from UpdateObject
        [Parameter()]
        [string[]]$ImportantInputProperties
    )
    process {
        # Write-Debug "INPUT OBJECT:"
        # Write-Debug (($InputObject | Out-String -Stream | ForEach-Object TrimEnd) -join "`n")
        # Write-Debug "Update OBJECT:"
        # Write-Debug (($UpdateObject | Out-String -Stream | ForEach-Object TrimEnd) -join "`n")
        if ($Null -eq $InputObject) {
            return
        }

        # $InputObject -is [PSCustomObject] -or
        if ($InputObject -is [System.Collections.IDictionary]) {
            $OutputObject = $InputObject
        } else {
            # Create a PSCustomObject with all the properties
            $OutputObject = [PSObject]$InputObject # | Select-Object * | % { }
        }

        if (!$UpdateObject) {
            $OutputObject
            return
        }

        if ($UpdateObject -is [System.Collections.IDictionary]) {
            $Keys = $UpdateObject.Keys
        } else {
            $Keys = @($UpdateObject |
                    Get-Member -MemberType Properties |
                    Where-Object { $p1 -notcontains $_.Name } |
                    Select-Object -ExpandProperty Name)
        }

        function TestKey {
            [OutputType([bool])]
            [CmdletBinding()]
            param($InputObject, $Key)
            [bool]$(
                if ($InputObject -is [System.Collections.IDictionary]) {
                    $InputObject.ContainsKey($Key)
                } else {
                    Get-Member -InputObject $InputObject -Name $Key
                }
            )
        }

        # # Write-Debug "Keys: $Keys"
        foreach ($key in $Keys) {
            if ($key -notin $ImportantInputProperties -or -not (TestKey -InputObject $InputObject -Key $Key) ) {
                # recurse Dictionaries (hashtables) and PSObjects
                if (($OutputObject.$Key -is [System.Collections.IDictionary] -or $OutputObject.$Key -is [PSObject]) -and
                    ($InputObject.$Key -is [System.Collections.IDictionary] -or $InputObject.$Key -is [PSObject])) {
                    $Value = Update-Object -InputObject $InputObject.$Key -UpdateObject $UpdateObject.$Key
                } else {
                    $Value = $UpdateObject.$Key
                }

                if ($OutputObject -is [System.Collections.IDictionary]) {
                    $OutputObject.$key = $Value
                } else {
                    $OutputObject = Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name $key -Value $Value -PassThru -Force
                }
            }
        }

        $OutputObject
    }
}
