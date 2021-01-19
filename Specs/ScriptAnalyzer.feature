@ScriptAnalyzer
Feature: Passes Script Analyzer
    This module should pass Invoke-ScriptAnalyzer with flying colors

    Scenario: ScriptAnalyzer on the compiled module output
        Given the configuration module is imported
        When we run ScriptAnalyzer on 'Configuration' with 'PSScriptAnalyzerSettings.psd1'

        Then it passes the ScriptAnalyzer rule PSAlignAssignmentStatement
        Then it passes the ScriptAnalyzer rule PSAvoidUsingCmdletAliases
        Then it passes the ScriptAnalyzer rule PSAvoidAssignmentToAutomaticVariable
        Then it passes the ScriptAnalyzer rule PSAvoidDefaultValueSwitchParameter
        Then it passes the ScriptAnalyzer rule PSAvoidDefaultValueForMandatoryParameter
        Then it passes the ScriptAnalyzer rule PSAvoidUsingEmptyCatchBlock
        Then it passes the ScriptAnalyzer rule PSAvoidGlobalAliases
        Then it passes the ScriptAnalyzer rule PSAvoidGlobalFunctions
        Then it passes the ScriptAnalyzer rule PSAvoidGlobalVars
        Then it passes the ScriptAnalyzer rule PSAvoidInvokingEmptyMembers
        Then it passes the ScriptAnalyzer rule PSAvoidLongLines
        Then it passes the ScriptAnalyzer rule PSAvoidNullOrEmptyHelpMessageAttribute
        Then it passes the ScriptAnalyzer rule PSAvoidOverwritingBuiltInCmdlets
        Then it passes the ScriptAnalyzer rule PSAvoidUsingPositionalParameters
        Then it passes the ScriptAnalyzer rule PSReservedCmdletChar
        Then it passes the ScriptAnalyzer rule PSReservedParams
        Then it passes the ScriptAnalyzer rule PSAvoidShouldContinueWithoutForce
        Then it passes the ScriptAnalyzer rule PSAvoidTrailingWhitespace
        Then it passes the ScriptAnalyzer rule PSAvoidUsingUsernameAndPasswordParams
        Then it passes the ScriptAnalyzer rule PSAvoidUsingComputerNameHardcoded
        Then it passes the ScriptAnalyzer rule PSAvoidUsingConvertToSecureStringWithPlainText
        Then it passes the ScriptAnalyzer rule PSAvoidUsingDoubleQuotesForConstantString
        Then it passes the ScriptAnalyzer rule PSAvoidUsingInvokeExpression
        Then it passes the ScriptAnalyzer rule PSAvoidUsingPlainTextForPassword
        Then it passes the ScriptAnalyzer rule PSAvoidUsingWMICmdlet
        Then it passes the ScriptAnalyzer rule PSAvoidUsingWriteHost
        Then it passes the ScriptAnalyzer rule PSUseCompatibleCommands
        Then it passes the ScriptAnalyzer rule PSUseCompatibleSyntax
        Then it passes the ScriptAnalyzer rule PSUseCompatibleTypes
        Then it passes the ScriptAnalyzer rule PSMisleadingBacktick
        Then it passes the ScriptAnalyzer rule PSMissingModuleManifestField
        Then it passes the ScriptAnalyzer rule PSPlaceCloseBrace
        Then it passes the ScriptAnalyzer rule PSPlaceOpenBrace
        Then it passes the ScriptAnalyzer rule PSPossibleIncorrectComparisonWithNull
        Then it passes the ScriptAnalyzer rule PSPossibleIncorrectUsageOfRedirectionOperator
        Then it passes the ScriptAnalyzer rule PSProvideCommentHelp
        Then it passes the ScriptAnalyzer rule PSReviewUnusedParameter
        Then it passes the ScriptAnalyzer rule PSUseApprovedVerbs
        Then it passes the ScriptAnalyzer rule PSUseBOMForUnicodeEncodedFile
        Then it passes the ScriptAnalyzer rule PSUseCmdletCorrectly
        Then it passes the ScriptAnalyzer rule PSUseCompatibleCmdlets
        Then it passes the ScriptAnalyzer rule PSUseConsistentIndentation
        Then it passes the ScriptAnalyzer rule PSUseConsistentWhitespace
        Then it passes the ScriptAnalyzer rule PSUseCorrectCasing
        Then it passes the ScriptAnalyzer rule PSUseDeclaredVarsMoreThanAssignments
        Then it passes the ScriptAnalyzer rule PSUseLiteralInitializerForHashtable
        Then it passes the ScriptAnalyzer rule PSUseOutputTypeCorrectly
        Then it passes the ScriptAnalyzer rule PSUseProcessBlockForPipelineCommand
        Then it passes the ScriptAnalyzer rule PSUsePSCredentialType
        Then it passes the ScriptAnalyzer rule PSShouldProcess
        Then it passes the ScriptAnalyzer rule PSUseShouldProcessForStateChangingFunctions
        Then it passes the ScriptAnalyzer rule PSUseSupportsShouldProcess
        Then it passes the ScriptAnalyzer rule PSUseToExportFieldsInManifest
        Then it passes the ScriptAnalyzer rule PSUseUsingScopeModifierInNewRunspaces
        Then it passes the ScriptAnalyzer rule PSUseUTF8EncodingForHelpFile
        Then it passes the ScriptAnalyzer rule PSDSCDscExamplesPresent
        Then it passes the ScriptAnalyzer rule PSDSCDscTestsPresent
        Then it passes the ScriptAnalyzer rule PSDSCReturnCorrectTypesForDSCFunctions
        Then it passes the ScriptAnalyzer rule PSDSCUseIdenticalMandatoryParametersForDSC
        Then it passes the ScriptAnalyzer rule PSDSCUseIdenticalParametersForDSC
        Then it passes the ScriptAnalyzer rule PSDSCStandardDSCFunctionsInResource
        Then it passes the ScriptAnalyzer rule PSDSCUseVerboseMessageInDSCResource
