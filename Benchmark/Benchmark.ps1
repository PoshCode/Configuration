$dataPath = Join-Path $PSScriptRoot "../Benchmark/Data/Configuration.psd1"

Write-Warning "The following Export-ModuleMember error can be ignored."
Get-ChildItem -Recurse -Filter *.ps1 -Path (Join-Path $PSScriptRoot "../Source/Metadata/") | ForEach-Object { . $_ }

$inputObject = Get-Content -Raw $dataPath | ConvertFrom-Metadata

$timingConvertTo = Measure-Command {
  ConvertTo-Metadata -InputObject $inputObject
}

Write-Host "ConvertTo-Metadata completed in $($timingConvertTo.Milliseconds) milliseconds."
