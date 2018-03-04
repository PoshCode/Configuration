
        BeforeEachFeature {
            Remove-Module 'Configuration' -ErrorAction Ignore -Force
            Import-Module 'C:\Users\Joel\Projects\Modules\Configuration\1.2.1\Configuration.psd1' -Force
        }
        AfterEachFeature {
            Remove-Module 'Configuration' -ErrorAction Ignore -Force
            Import-Module 'C:\Users\Joel\Projects\Modules\Configuration\1.2.1\Configuration.psd1' -Force
        }
        AfterEachScenario {
            if(Test-Path 'C:\Users\Joel\Projects\Modules\Configuration\1.2.1\Configuration.psd1.backup') {
                Remove-Item 'C:\Users\Joel\Projects\Modules\Configuration\1.2.1\Configuration.psd1'
                Rename-Item 'C:\Users\Joel\Projects\Modules\Configuration\1.2.1\Configuration.psd1.backup' 'C:\Users\Joel\Projects\Modules\Configuration\1.2.1\Configuration.psd1'
            }
        }
    
