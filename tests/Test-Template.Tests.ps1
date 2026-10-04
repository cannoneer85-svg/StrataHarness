#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Seam C: Test-Template.ps1 version checks (VERSION <=> CHANGELOG.md).
# Every test runs Test-Template.ps1 copied into a minimal fixture repo in $TestDrive,
# because the script resolves the repository root relative to its own location.

BeforeAll {
    $script:ScriptsDir = Join-Path $PSScriptRoot '..' '.agents' 'scripts'

    function New-FixtureRepo {
        param([string]$Version, [string]$Changelog)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $fixtureScripts = Join-Path $root '.agents' 'scripts'
        New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.agents' 'skills') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:ScriptsDir 'Test-Template.ps1') -Destination $fixtureScripts
        Copy-Item -LiteralPath (Join-Path $script:ScriptsDir 'SemVer.ps1') -Destination $fixtureScripts
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n"
        Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Value "# Agent rules`n"
        if ($PSBoundParameters.ContainsKey('Version')) {
            Set-Content -LiteralPath (Join-Path $root 'VERSION') -Value $Version
        }
        if ($PSBoundParameters.ContainsKey('Changelog')) {
            Set-Content -LiteralPath (Join-Path $root 'CHANGELOG.md') -Value $Changelog
        }
        return $root
    }

    function Invoke-TestTemplate([string]$Root) {
        $output = & pwsh -NoProfile -File (Join-Path $Root '.agents' 'scripts' 'Test-Template.ps1') 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
    }

    $script:Intro = "# Changelog`n`nIntro text.`n`n## [Unreleased]`n"
}

Describe 'Test-Template.ps1 version checks' {
    It 'passes and skips when VERSION and CHANGELOG.md are absent (Project)' {
        $result = Invoke-TestTemplate (New-FixtureRepo)
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'SKIP \[version\]'
    }

    It 'passes with VERSION 0.0.0 and only [Unreleased]' {
        $result = Invoke-TestTemplate (New-FixtureRepo -Version '0.0.0' -Changelog $script:Intro)
        $result.ExitCode | Should -Be 0
    }

    It 'passes when the top version section equals VERSION' {
        $changelog = $script:Intro + "`n## [1.1.0] - 2026-11-02 - Title`n`n### Added`n- x`n`n## [1.0.0] - 2026-10-10 - First`n"
        $result = Invoke-TestTemplate (New-FixtureRepo -Version '1.1.0' -Changelog $changelog)
        $result.ExitCode | Should -Be 0
    }

    It 'passes for a release candidate' {
        $changelog = $script:Intro + "`n## [1.1.0-rc.1] - 2026-11-02 - Title`n"
        $result = Invoke-TestTemplate (New-FixtureRepo -Version '1.1.0-rc.1' -Changelog $changelog)
        $result.ExitCode | Should -Be 0
    }

    It 'fails when VERSION is not valid SemVer: <_>' -ForEach @('v1.0.0', '1.0', 'garbage', '') {
        $result = Invoke-TestTemplate (New-FixtureRepo -Version $_ -Changelog $script:Intro)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[version\]'
    }

    It 'fails when the top version section differs from VERSION' {
        $changelog = $script:Intro + "`n## [1.0.0] - 2026-10-10 - First`n"
        $result = Invoke-TestTemplate (New-FixtureRepo -Version '1.1.0' -Changelog $changelog)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[version\].*1\.0\.0'
    }

    It 'fails when VERSION is past 0.0.0 but CHANGELOG.md has no version sections' {
        $result = Invoke-TestTemplate (New-FixtureRepo -Version '1.0.0' -Changelog $script:Intro)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[version\]'
    }

    # A Project may own a CHANGELOG.md of its own; without VERSION nothing is checked.
    It 'skips when CHANGELOG.md exists without VERSION' {
        $changelog = $script:Intro + "`n## [3.0.0] - 2026-10-10 - Project release`n"
        $result = Invoke-TestTemplate (New-FixtureRepo -Changelog $changelog)
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'SKIP \[version\]'
    }

    It 'validates VERSION alone when CHANGELOG.md is absent' {
        (Invoke-TestTemplate (New-FixtureRepo -Version '1.0.0')).ExitCode | Should -Be 0
        (Invoke-TestTemplate (New-FixtureRepo -Version 'garbage')).ExitCode | Should -Be 1
    }
}
