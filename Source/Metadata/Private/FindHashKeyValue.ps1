function FindHashKeyValue {
    [CmdletBinding()]
    param(
        $SearchPath,
        $Ast,
        [string[]]
        $CurrentPath = @()
    )
    # Write-Debug "FindHashKeyValue: $SearchPath -eq $($CurrentPath -Join '.')"
    if ($SearchPath -eq ($CurrentPath -Join '.') -or $SearchPath -eq $CurrentPath[-1]) {
        return $Ast |
            Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force |
            Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
    }

    if ($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst] ) {
        $KeyValue = $Ast.PipelineElements.Expression
        foreach ($KV in $KeyValue.KeyValuePairs) {
            $result = FindHashKeyValue $SearchPath -Ast $KV.Item2 -CurrentPath ($CurrentPath + $KV.Item1.Value)
            if ($null -ne $result) {
                $result
            }
        }
    }
}
