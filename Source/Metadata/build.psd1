@{
    SourceDirectories = @("Header", "Private", "Public", "Footer")
    Prefix = "Header\param.ps1"
    Postfix = "Footer\initialize.ps1"
    OutputDirectory = "..\..\"
    VersionedOutputDirectory = $true
}