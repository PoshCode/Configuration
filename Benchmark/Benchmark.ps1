[CmdletBinding()]
param([int]$Count = 10)
$dataPath = Join-Path $PSScriptRoot "../Benchmark/Data/Configuration.psd1"

foreach ($Version in Get-Module Configuration -ListAvailable | Sort-Object Version) {
    Remove-Module Configuration -Force
    Import-Module $Version.Path -Force
    $Configuration = Get-Module Configuration
    Write-Host "${fg:white}$($Configuration.Name) v$($Configuration.Version)$(if(($pre=$Configuration.PrivateData.PSData.PreRelease)) {"-$pre"})"

    $ToTime = [System.Collections.Generic.List[timespan]]::new()
    $FromTime = [System.Collections.Generic.List[timespan]]::new()

    $Timer = [System.Diagnostics.Stopwatch]::new()
    for ($i=0;$i -lt $Count; $i++) {
        $Timer.Restart()
        $inputObject = ConvertFrom-Metadata -InputObject (Get-Content -Raw $dataPath)
        $FromTime.Add($Timer.Elapsed)
        $outputObject = ConvertTo-Metadata -InputObject $inputObject
        $ToTime.Add($Timer.Elapsed)
    }
    $From = $FromTime | Measure-Object TotalMilliseconds -Sum -Average -Maximum -Minimum
    $To = $ToTime | Measure-Object TotalMilliseconds -Sum -Average -Maximum -Minimum

    Write-Host "  ${fg:grey}ConvertTo-Metadata completed in ${fg:Cyan}$($To.Average) milliseconds${fg:grey} on average. Max $($To.Maximum) to $($To.Minimum) minimum."
    Write-Host "  ${fg:grey}ConvertFrom-Metadata completed in ${fg:Cyan}$($From.Average) milliseconds${fg:grey} on average. Max $($From.Maximum) to $($From.Minimum) minimum."
}