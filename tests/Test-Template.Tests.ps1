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

Describe 'Test-Template.ps1 version checks' -Tag 'Unit' {
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

Describe 'Test-Template.ps1 legacy quota checks' -Tag 'Unit' {
    It 'passes when fixture repo has clean AGENTS.md' {
        $result = Invoke-TestTemplate (New-FixtureRepo)
        $result.ExitCode | Should -Be 0
        $result.Output | Should -Not -Match '\[quotas\]'
    }

    It 'detects violation and exits with 1 when AGENTS.md contains legacy numeric question quotas: <_>' -ForEach @(
        '2–4 questions',
        '2–4 вопроса',
        '2–4 вопросов',
        'ровно 1 раунд',
        'apply its round quota',
        'interview quotas'
    ) {
        $root = New-FixtureRepo
        Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Value "# Agent rules`nLegacy quota: $_`n"
        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[quotas\]'
        $result.Output | Should -Match ([regex]::Escape($_))
    }
}

Describe 'Test-Template.ps1 Claude mirror sync checks' -Tag 'Unit' {
    It 'passes when .claude/skills is in sync with .agents/skills' {
        $root = New-FixtureRepo
        $srcSkill = Join-Path $root '.agents' 'skills' 'demo'
        $dstSkill = Join-Path $root '.claude' 'skills' 'demo'
        New-Item -ItemType Directory -Path $srcSkill -Force | Out-Null
        New-Item -ItemType Directory -Path $dstSkill -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $srcSkill 'SKILL.md') -Value "---`nname: demo`n---`n# Demo`n" -NoNewline
        Set-Content -LiteralPath (Join-Path $dstSkill 'SKILL.md') -Value "---`nname: demo`n---`n# Demo`n" -NoNewline
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n`n| [demo](skills/demo/SKILL.md) | Demo | авто | свой | active |`n"

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 0
    }

    It 'fails when a file in .claude/skills is out of sync or missing' {
        $root = New-FixtureRepo
        $srcSkill = Join-Path $root '.agents' 'skills' 'demo'
        $dstSkill = Join-Path $root '.claude' 'skills' 'demo'
        New-Item -ItemType Directory -Path $srcSkill -Force | Out-Null
        New-Item -ItemType Directory -Path $dstSkill -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $srcSkill 'SKILL.md') -Value "---`nname: demo`n---`n# Updated`n" -NoNewline
        Set-Content -LiteralPath (Join-Path $dstSkill 'SKILL.md') -Value "---`nname: demo`n---`n# Old`n" -NoNewline
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n`n| [demo](skills/demo/SKILL.md) | Demo | авто | свой | active |`n"

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[claude-mirror\]'
    }
}

Describe 'Test-Template.ps1 YAML frontmatter and platform limits' -Tag 'Unit' {
    It 'passes when fixture skill has quoted colon-space and valid description' {
        $root = New-FixtureRepo
        $skillDir = Join-Path $root '.agents' 'skills' 'demo'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value "---`nname: demo`ndescription: `"Quoted: with colon-space`"`n---`n# Demo`n"
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n`n| [demo](skills/demo/SKILL.md) | Demo | авто | свой | active |`n"

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 0
    }

    It 'detects unquoted colon-space in YAML frontmatter and provides Fix hint' {
        $root = New-FixtureRepo
        $skillDir = Join-Path $root '.agents' 'skills' 'demo'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value "---`nname: demo`ndescription: Unquoted: with colon-space`n---`n# Demo`n"
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n`n| [demo](skills/demo/SKILL.md) | Demo | авто | свой | active |`n"

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[yaml-frontmatter\]'
        $result.Output | Should -Match 'Fix: Wrap the ''description'' value in quotes'
    }

    It 'detects single skill description exceeding 1024 characters' {
        $root = New-FixtureRepo
        $skillDir = Join-Path $root '.agents' 'skills' 'demo'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        $longDesc = 'A' * 1025
        Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value "---`nname: demo`ndescription: `"$longDesc`"`n---`n# Demo`n"
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n`n| [demo](skills/demo/SKILL.md) | Demo | авто | свой | active |`n"

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[description-length\]'
        $result.Output | Should -Match '1025 characters; maximum allowed is 1024'
        $result.Output | Should -Match 'Fix:'
    }

    It 'detects total skill descriptions exceeding budget of 8000 characters' {
        $root = New-FixtureRepo
        $regLines = [System.Collections.Generic.List[string]]::new()
        $regLines.Add("# Registry`n")
        for ($i = 1; $i -le 9; $i++) {
            $name = "demo$i"
            $skillDir = Join-Path $root '.agents' 'skills' $name
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            $desc = 'D' * 950
            Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value "---`nname: $name`ndescription: `"$desc`"`n---`n# $name`n"
            $regLines.Add("| [$name](skills/$name/SKILL.md) | $name | авто | свой | active |")
        }
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value ($regLines -join "`n")

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[description-length\]'
        $result.Output | Should -Match 'maximum budget for OpenAI Codex compatibility is 8000 characters'
        $result.Output | Should -Match 'Fix:'
    }

    It 'detects combined AGENTS.md and CONTEXT.md exceeding 32 KiB budget' {
        $root = New-FixtureRepo
        $bigAgents = '# Agent rules`n' + ('A' * 20000)
        $bigContext = '# Context`n' + ('C' * 15000)
        Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Value $bigAgents
        Set-Content -LiteralPath (Join-Path $root '.agents' 'CONTEXT.md') -Value $bigContext

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[context-budget\]'
        $result.Output | Should -Match 'maximum allowed is 32768 bytes \(32 KiB\)'
        $result.Output | Should -Match 'Fix:'
    }

    It 'ensures all violation messages include a Fix hint' {
        $root = New-FixtureRepo
        Set-Content -LiteralPath (Join-Path $root '.agents' 'SKILLS.md') -Value "# Registry`n`n| [missing](skills/missing/SKILL.md) | M | авто | свой | active |`n"

        $result = Invoke-TestTemplate $root
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[registry\]'
        $result.Output | Should -Match 'Fix:'
    }
}


