# Generate ScriptAnalyzer.feature
$Path = GetModuleBase

# The name (or path) of a settings file to be used.
[string]$Settings = "PSScriptAnalyzerSettings.psd1"
Write-Verbose "Resolve settings '$Settings'"
if (Test-Path $Settings) {
    $Settings = Resolve-Path $Settings
} else {
    Set-Location $PSScriptRoot\..
    if (Test-Path $Settings) {
        $Settings = Resolve-Path $Settings
    } else {
        foreach ($directory in Get-ChildItem -Directory) {
            $search = Join-Path $directory.FullName $Settings
            if (Test-Path $search) {
                $Settings = Resolve-Path $search
                break
            }
        }
    }
}

$ExcludeRules = @()
$Rules = @(
    if (!(Test-Path $Settings)) {
        Write-Warning "Could not find a 'PSScriptAnalyzerSettings.psd1'"
    } else {
        Write-Verbose "Loading $Settings"
        $Config = Import-LocalizedData -BaseDirectory ([IO.Path]::GetDirectoryName($Settings)) -FileName ([IO.Path]::GetFileName($Settings))
        $ExcludeRules = @($Config.ExcludeRules)
        if ($Config.CustomRulePath -and (Test-Path $Config.CustomRulePath)) {
            $CustomRules = @{
                CustomRulePath = @($Config.CustomRulePath)
                RecurseCustomRulePath = [bool]$Config.RecurseCustomRulePath
            }
            Get-ScriptAnalyzerRule @CustomRules
        }
    }

    Get-ScriptAnalyzerRule
) | Where-Object RuleName -notin $ExcludeRules

Set-Content "$PSScriptRoot\ScriptAnalyzer.feature" @"
@ScriptAnalyzer
Feature: Passes Script Analyzer
    This module should pass Invoke-ScriptAnalyzer with flying colors

    Scenario: ScriptAnalyzer on the compiled module output
        Given the configuration module is imported
        When we run ScriptAnalyzer on '$Path' with '$Settings'
$(  foreach ($Rule in $Rules.RuleName) {"
        Then it passes the ScriptAnalyzer rule $Rule"
    })
"@


When "we run ScriptAnalyzer on '(?<Path>.*)' with '(?<Settings>.*)'" {
    param($Path, $Settings)
    try {
        $script:ScriptAnalyzerResults = Invoke-ScriptAnalyzer @PSBoundParameters
    } catch {
        Write-Warning "Exception running script analyzer on $($_.TargetObject)"
        Write-Warning $($_.Exception.StackTrace)
        throw $_
    }
}

Then "it passes the ScriptAnalyzer rule (?<RuleName>.*)" {
    param($RuleName)
    $rule = $script:ScriptAnalyzerResults.Where({$_.RuleName -eq $RuleName})
    if ($rule) { # ScriptAnalyzer only has results for failed tests
        throw ([Management.Automation.ErrorRecord]::new(
            ([Exception]::new(($rule.ForEach{$_.ScriptName + ":" + $_.Line + " " + $_.Message} -join "`n"))),
            "ScriptAnalyzerViolation",
            "SyntaxError",
            $rule))
    }
}
