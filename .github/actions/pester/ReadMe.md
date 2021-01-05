# An opinionated Pester tests action

Runs Invoke-Pester or Invoke-Gherkin depending on whether there are .tests.ps1 or .feature files, and generates `results.xml` and optionally code `coverage.xml` files.

## Inputs:

### testsDirectory:
    - The path to the folder where your tests are
    - required: false
    - default: "*[Tt]est*"
### pesterVersion:
    -  If you need a specific version of Pester (default is what's on your PSModulePath)
    - required: false
### includeTag:
    - If you want to only run some of your tests, a comma-separated list of tags
    - required: false
### excludeTag:
    - If you want to skip some of your tests, a comma-separated list of tags
    - required: false
### additionalModulePaths:
    - A string which will be appended to the PSModulePath
    - required: false
### codeCoverageDirectory:
    - The path to a module or scripts under test
    - required: false
### testRunTitle:
    - If you want to override the default "Pester" test run name
    - required: false

## Usage

For basic usage: use two jobs, one for build and one for .\Test.ps1

At the end of the **build** job, use `actions/upload-artifact` to publish:

1. The Module with the name "Modules"
2. A Tests or Specs folder with the name "PesterTests"
3. RequiredModules.psd1 (if you have one)

```yaml
  - name: Upload Build Output
    uses: actions/upload-artifact@v2
    with:
      name: Modules
      path: ${{github.workspace}}/output
  - name: Upload Tests
    uses: actions/upload-artifact@v2
    with:
      name: PesterTests
      path: ${{github.workspace}}/Specs
  - name: Upload RequiredModules.psd1
    uses: actions/upload-artifact@v2
    with:
      name: RequiredModules
      path: ${{github.workspace}}/RequiredModules.psd1
```

Then add a **test** job, and use `actions/download-artifact` to download all of the packages, before calling this Pester action:

```yaml
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [windows-latest, ubuntu-16.04, ubuntu-18.04, windows-2016, macos-latest]
    needs: build
    steps:
      - name: Download Build Output
        uses: actions/download-artifact@v2
      - name: Test Module
        uses: PoshCode/Actions/Pester@v1
```