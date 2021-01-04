const core = require('@actions/core')
const cache = require('@actions/cache')

const path = require('path')
const { execFileSync } = require('child_process')

async function cacheDotNetGlobalTool(tools) {
    const os = (process.env['RUNNER_OS'] || process.env['OS'] || process.env['ImageOS'] || '')
    const home = (process.env['HOME'] || process.env['USERPROFILE'])
    const toolPath = path.join(home, '.dotnet', 'tools')

    function restoreKey(value, index, list) {
        return list.slice(0,index).concat(value).join('-')
    }
    const key = [os, 'dotnet', 'tools'].concat(tools).join('-')
    const restoreKeys = key.split('-').map(restoreKey)

    const exists = await cache.restoreCache([toolPath], key, restoreKeys)
    if (!exists) {
        tools.forEach(tool => {
            execFileSync('dotnet', ['tool', 'install', '--global', tool])
        })
        await cache.saveCache([toolPath], key)
    }
}

async function main() {
    try {
        await cacheDotNetGlobalTool(['GitVersion.Tool'])
        var gitversionOutput = execFileSync('dotnet-gitversion', [
            '-url', process.env['GITHUB_SERVER_URL'] + '/' + process.env['GITHUB_REPOSITORY'] + '.git',
            '-b', process.env['GITHUB_REF'],
            '-c', process.env['GITHUB_SHA'],
            '-output', 'json'])

        try {
            var json = JSON.parse(gitversionOutput)
        } catch (error) {
            console.error("Error parsing JSON %s", error.message)
            throw error;
        }

        core.setOutput('Major', json.Major)
        core.setOutput('Minor', json.Minor)
        core.setOutput('Patch', json.Patch)
        core.setOutput('PreReleaseTag', json.PreReleaseTag)
        core.setOutput('PreReleaseTagWithDash', json.PreReleaseTagWithDash)
        core.setOutput('PreReleaseLabel', json.PreReleaseLabel)
        core.setOutput('PreReleaseNumber', json.PreReleaseNumber)
        core.setOutput('WeightedPreReleaseNumber', json.WeightedPreReleaseNumber)
        core.setOutput('BuildMetaData', json.BuildMetaData)
        core.setOutput('BuildMetaDataPadded', json.BuildMetaDataPadded)
        core.setOutput('FullBuildMetaData', json.FullBuildMetaData)
        core.setOutput('MajorMinorPatch', json.MajorMinorPatch)
        core.setOutput('SemVer', json.SemVer)
        core.setOutput('LegacySemVer', json.LegacySemVer)
        core.setOutput('LegacySemVerPadded', json.LegacySemVerPadded)
        core.setOutput('AssemblySemVer', json.AssemblySemVer)
        core.setOutput('AssemblySemFileVer', json.AssemblySemFileVer)
        core.setOutput('FullSemVer', json.FullSemVer)
        core.setOutput('InformationalVersion', json.InformationalVersion)
        core.setOutput('BranchName', json.BranchName)
        core.setOutput('Sha', json.Sha)
        core.setOutput('ShortSha', json.ShortSha)
        core.setOutput('NuGetVersionV2', json.NuGetVersionV2)
        core.setOutput('NuGetVersion', json.NuGetVersion)
        core.setOutput('NuGetPreReleaseTagV2', json.NuGetPreReleaseTagV2)

    } catch (error) {
        core.setFailed(error.message)
    }
}

main()