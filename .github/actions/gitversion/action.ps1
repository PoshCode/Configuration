[CmdletBinding()]
param(
    [string]$repository,
    [string]$ref,
    [string]$sha
)

Write-Host "::group::{dotnet tool install}"
dotnet tool install --global GitVersion.Tool # --version 5.6.0
Write-Host "::endgroup::"

$ofs = "`n"
[string]$gitversion = dotnet-gitversion -url "https://github.com/$repository.git" -b $ref -c $sha
Write-Verbose $gitversion -Verbose

(ConvertFrom-Json -InputObject $gitversion -AsHashtable).GetEnumerator().ForEach{
    "::set-output name=$($_.Key)::$($_.Value)"
}
