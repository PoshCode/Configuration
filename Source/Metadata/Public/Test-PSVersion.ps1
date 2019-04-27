function Test-PSVersion {
    <#
      .Synopsis
         Test the PowerShell Version
      .Description
         This function exists so I can do things differently on older versions of PowerShell.
         But the reason I test in a function is that I can mock the Version to test the alternative code.
      .Example
         if(Test-PSVersion -ge 3.0) {
            ls | where Length -gt 12mb
         } else {
            ls | Where { $_.Length -gt 12mb }
         }

         This is just a trivial example to show the usage (you wouldn't really bother for a where-object call)
   #>
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Version]$Version = $PSVersionTable.PSVersion,
        [Version]$lt,
        [Version]$le,
        [Version]$gt,
        [Version]$ge,
        [Version]$eq,
        [Version]$ne
    )

    $all = @(
        if ($lt) { $Version -lt $lt }
        if ($gt) { $Version -gt $gt }
        if ($le) { $Version -le $le }
        if ($ge) { $Version -ge $ge }
        if ($eq) { $Version -eq $eq }
        if ($ne) { $Version -ne $ne }
    )

    $all -notcontains $false
}
