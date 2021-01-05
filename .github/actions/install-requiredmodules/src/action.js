const core  = require('@actions/core')
const cache = require('@actions/cache')
const path  = require('path')
const fs = require('fs');
const { execFileSync } = require('child_process')

async function restore(paths, key) {
    function restoreKey(value, index, list) {
        return list.slice(0,index).concat(value).join('-')
    }

    try {
        const restoreKeys = key.split('-').map(restoreKey)
        return await cache.restoreCache(paths, key, restoreKeys)
    } catch (error) {}
}

async function main() {
    try {
        // try finding the RequiredModules.psd1 where they said it would be
        var requiredModules = [
            core.getInput('requiredModules-path'),
            path.resolve('RequiredModules.psd1'),
            path.resolve('RequiredModules','RequiredModules.psd1')
        ].filter(file => fs.existsSync(file))[0]

        const hash = String(execFileSync('pwsh', ['-noprofile', '-nologo', '-noninteractive', '-command', '$(Get-FileHash "' + requiredModules + '").Hash'])).trim()
        const psModulePath = String(execFileSync('pwsh', ['-noprofile', '-nologo', '-noninteractive', '-command', '$Env:PSModulePath.Split([IO.Path]::PathSeparator).Where({$_.StartsWith((Split-Path $profile.CurrentUserAllHosts))})'])).trim()

        const os = (process.env['RUNNER_OS'] || process.env['OS'] || process.env['ImageOS'] || '')
        var key = [os, 'psmodules', hash.trim()].join('-')
        core.info("Restore: '" + psModulePath + "' from cache: " + key)
        const cacheKey = await restore([psModulePath], key)
        if (cacheKey) {
            core.info("Cache hit: " + cacheKey)
        } else {
            const command = path.resolve(__dirname, 'Install-RequiredModule.ps1')
            core.info("PS> " + command + " -RequiredModulesFile " + requiredModules)
            core.info(execFileSync('pwsh', ['-noprofile', '-nologo', '-noninteractive', '-file', command, '-RequiredModulesFile', requiredModules, '-TrustRegisteredRepositories', '-Scope', 'CurrentUser']))
            const cache = await cache.saveCache([psModulePath], key)
            core.info("New cache [" + cache + "] for: " + psModulePath)
        }
    } catch (error) {
        core.setFailed(error.message)
    }
}

main()