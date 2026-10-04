#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Seam C: Initialize-Project.ps1 -Mode New turns a Template copy into a clean Project.
# Every test runs against a fixture repo in $TestDrive, never against the real repo.

BeforeAll {
    $script:TemplateRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:InitScript = Join-Path $script:TemplateRoot '.agents' 'skills' 'init-project' 'scripts' 'Initialize-Project.ps1'

    function New-FixtureRepo {
        $root = (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $resolvedRoot = (Resolve-Path -LiteralPath $root).Path

        # Copy non-ignored template files into the fixture
        Get-ChildItem -LiteralPath $script:TemplateRoot -Recurse -File |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git([\\/]|$)' -and
                $_.FullName -notmatch '[\\/]\.scratch([\\/]|$)' -and
                $_.FullName -notmatch '[\\/]\.claude([\\/]|$)'
            } |
            ForEach-Object {
                $rel = [System.IO.Path]::GetRelativePath($script:TemplateRoot, $_.FullName)
                $dest = Join-Path $resolvedRoot $rel
                $destDir = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }

        # Seed meta files that must be cleaned in New mode
        $metaFiles = @{
            'docs/specs/0001-template-v2-spec.md' = '# Spec'
            'docs/adr/0001-adr.md'               = '# ADR'
            'docs/handoff/2026-10-03-sample.md'  = '# Handoff'
            'docs/analysis/2026-10-03-audit.md'  = '# Analysis'
            'docs/research/sample.md'            = '# Research'
            'tests/Sample.Tests.ps1'             = '# Tests'
            'LICENSE'                            = "MIT License`n"
            '.github/workflows/ci.yml'           = "name: CI`n"
            'README.ru.md'                       = "# Описание`n"
            'CONTRIBUTING.md'                    = "# Contributing`n"
            'SECURITY.md'                        = "# Security Policy`n"
            'docs/releasing.md'                  = "# Release Process`n"
            'THIRD_PARTY_NOTICES.md'             = "# Third Party Notices`n"
        }
        foreach ($rel in $metaFiles.Keys) {
            $p = Join-Path $resolvedRoot $rel
            $dir = Split-Path -Parent $p
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Set-Content -LiteralPath $p -Value $metaFiles[$rel] -Encoding utf8
        }

        # Seed reset files with initial template values
        Set-Content -LiteralPath (Join-Path $resolvedRoot '.agents/CONTEXT.md') -Value 'Initial template context' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $resolvedRoot 'docs/handoff/LATEST.md') -Value 'Initial template latest' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $resolvedRoot 'README.md') -Value 'Initial template readme' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $resolvedRoot 'CODING_STANDARDS.md') -Value 'Initial template standards' -Encoding utf8

        return $resolvedRoot
    }

    function New-TargetRepo {
        $root = (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $resolvedRoot = (Resolve-Path -LiteralPath $root).Path

        # Seed target repo with its own existing files
        Set-Content -LiteralPath (Join-Path $resolvedRoot 'README.md') -Value "# Existing Target Project`n`nCustom project readme." -Encoding utf8
        Set-Content -LiteralPath (Join-Path $resolvedRoot 'AGENTS.md') -Value "# Custom Target AGENTS`n`nKeep custom agent rules." -Encoding utf8

        $docsDir = Join-Path $resolvedRoot 'docs'
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $docsDir 'existing.md') -Value "# Existing doc in target." -Encoding utf8

        # .gitignore with pre-existing entries
        Set-Content -LiteralPath (Join-Path $resolvedRoot '.gitignore') -Value "node_modules/`n*.log`n" -Encoding utf8

        return $resolvedRoot
    }

    function Initialize-GitRepoFixture {
        param(
            [string]$Path,
            [string]$UserName = 'Tester',
            [string]$UserEmail = 'tester@example.com'
        )
        & git -C $Path init --quiet
        & git -C $Path config user.name $UserName
        & git -C $Path config user.email $UserEmail
        & git -C $Path config commit.gpgsign false
        & git -C $Path config core.autocrlf false
        & git -C $Path config advice.crlf false
    }

    function New-UpdateFixture {
        $tmpDir = (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        $templateDir = Join-Path $tmpDir 'template'
        $projectDir = Join-Path $tmpDir 'project'
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        $templateResolved = (Resolve-Path -LiteralPath $templateDir).Path
        $projectResolved = (Resolve-Path -LiteralPath $projectDir).Path

        # Initialize template git repo
        Initialize-GitRepoFixture -Path $templateResolved -UserName 'TestTemplate' -UserEmail 'test@example.com'

        # Copy baseline files needed for scripts and manifest
        $filesToCopy = @(
            'AGENTS.md',
            'CLAUDE.md',
            '.gitattributes'
        )
        foreach ($f in $filesToCopy) {
            $src = Join-Path $script:TemplateRoot $f
            if (Test-Path -LiteralPath $src -PathType Leaf) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $templateResolved $f) -Force
            }
        }

        # Copy .agents recursively
        $agentsSrc = Join-Path $script:TemplateRoot '.agents'
        $agentsDest = Join-Path $templateResolved '.agents'
        Copy-Item -LiteralPath $agentsSrc -Destination $agentsDest -Recurse -Force

        # Ensure docs/agents exists
        $docsAgentsSrc = Join-Path $script:TemplateRoot 'docs' 'agents'
        if (Test-Path -LiteralPath $docsAgentsSrc) {
            $docsAgentsDest = Join-Path $templateResolved 'docs' 'agents'
            Copy-Item -LiteralPath $docsAgentsSrc -Destination $docsAgentsDest -Recurse -Force
        }

        # Register fixture skills in template SKILLS.md
        $skillsMdPath = Join-Path $templateResolved '.agents' 'SKILLS.md'
        $skillsContent = Get-Content -LiteralPath $skillsMdPath -Raw -Encoding utf8
        $fixtureSkillsRows = @"
| [skill-to-modify](skills/skill-to-modify/SKILL.md) | Test skill | авто | свой | active |
| [skill-to-remove](skills/skill-to-remove/SKILL.md) | Test skill | авто | свой | active |
| [skill-local-edit](skills/skill-local-edit/SKILL.md) | Test skill | авто | свой | active |
"@
        if ($skillsContent -match '(?m)^##\s+Только Шаблон\b') {
            $skillsContent = [regex]::Replace($skillsContent, '(?m)^##\s+Только Шаблон\b', "$fixtureSkillsRows`n## Только Шаблон")
        } else {
            $skillsContent = $skillsContent.TrimEnd() + "`n" + $fixtureSkillsRows + "`n"
        }
        Set-Content -LiteralPath $skillsMdPath -Value $skillsContent -Encoding utf8 -NoNewline

        # Create specific fixture skills for v1
        $skillModDir = Join-Path $templateResolved '.agents' 'skills' 'skill-to-modify'
        New-Item -ItemType Directory -Path $skillModDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillModDir 'SKILL.md') -Value @"
---
name: skill-to-modify
description: Test
---
# Skill v1
Initial content
"@ -Encoding utf8

        $skillRemDir = Join-Path $templateResolved '.agents' 'skills' 'skill-to-remove'
        New-Item -ItemType Directory -Path $skillRemDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillRemDir 'SKILL.md') -Value @"
---
name: skill-to-remove
description: Test
---
# Remove me
Initial content
"@ -Encoding utf8

        $skillLocalDir = Join-Path $templateResolved '.agents' 'skills' 'skill-local-edit'
        New-Item -ItemType Directory -Path $skillLocalDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillLocalDir 'SKILL.md') -Value @"
---
name: skill-local-edit
description: Test
---
# Skill local edit
Initial content
"@ -Encoding utf8

        # Commit Template v1
        & git -C $templateResolved add .
        & git -C $templateResolved commit -m "Template v1" --quiet
        $v1Sha = (& git -C $templateResolved rev-parse --short HEAD).Trim()

        # Adopt into Project repo from Template v1
        & $script:InitScript -Mode Adopt -RepoRoot $projectResolved -TemplateSource $templateResolved -TemplateVersion "2026-10-03 $v1Sha" | Out-Null

        # In Template, create v2 changes:
        # a) Added skill
        $skillAddDir = Join-Path $templateResolved '.agents' 'skills' 'skill-added-v2'
        New-Item -ItemType Directory -Path $skillAddDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillAddDir 'SKILL.md') -Value @"
---
name: skill-added-v2
description: Test
---
# Skill added in v2
New skill content
"@ -Encoding utf8

        # b) Modified skill
        Set-Content -LiteralPath (Join-Path $skillModDir 'SKILL.md') -Value @"
---
name: skill-to-modify
description: Test
---
# Skill v2
Updated content in v2
"@ -Encoding utf8

        # c) Removed skill
        Remove-Item -LiteralPath $skillRemDir -Recurse -Force

        # d) Template also modifies skill-local-edit
        Set-Content -LiteralPath (Join-Path $skillLocalDir 'SKILL.md') -Value @"
---
name: skill-local-edit
description: Test
---
# Skill local edit
Template v2 modified this too
"@ -Encoding utf8

        # Update SKILLS.md in Template v2: remove skill-to-remove, add skill-added-v2
        $skillsContentV2 = Get-Content -LiteralPath $skillsMdPath -Raw -Encoding utf8
        $skillsContentV2 = [regex]::Replace($skillsContentV2, '(?m)^\|\s*\[skill-to-remove\].*$', '')
        if ($skillsContentV2 -match '(?m)^##\s+Только Шаблон\b') {
            $skillsContentV2 = [regex]::Replace($skillsContentV2, '(?m)^##\s+Только Шаблон\b', "| [skill-added-v2](skills/skill-added-v2/SKILL.md) | Test skill | авто | свой | active |`n`n## Только Шаблон")
        } else {
            $skillsContentV2 = $skillsContentV2.TrimEnd() + "`n| [skill-added-v2](skills/skill-added-v2/SKILL.md) | Test skill | авто | свой | active |`n"
        }
        Set-Content -LiteralPath $skillsMdPath -Value $skillsContentV2 -Encoding utf8 -NoNewline

        # Set VERSION and CHANGELOG.md in Template v2
        Set-Content -LiteralPath (Join-Path $templateResolved 'VERSION') -Value "2.0.0`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $templateResolved 'CHANGELOG.md') -Value @"
# Changelog

All notable changes documented here.

## [Unreleased]

## [2.0.0] - 2026-11-01 - Major Release
### Added
- skill-added-v2

## [1.0.0] - 2026-10-04 - Initial Release
### Added
- initial template skills
"@ -Encoding utf8

        # Commit Template v2
        & git -C $templateResolved add .
        & git -C $templateResolved commit -m "Template v2" --quiet
        $v2Sha = (& git -C $templateResolved rev-parse --short HEAD).Trim()

        # In Project repo, create local modification in skill-local-edit
        $projectLocalSkillPath = Join-Path $projectResolved '.agents' 'skills' 'skill-local-edit' 'SKILL.md'
        Set-Content -LiteralPath $projectLocalSkillPath -Value @"
---
name: skill-local-edit
description: Test
---
# Skill local edit
Locally modified by project team.
"@ -Encoding utf8

        return @{
            TemplateRoot = $templateResolved
            ProjectRoot  = $projectResolved
            V1Sha        = $v1Sha
            V2Sha        = $v2Sha
        }
    }
}

Describe 'Initialize-Project.ps1 -Mode New' {
    It 'cleans meta directories and deletes tests/' {
        $root = New-FixtureRepo
        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        Test-Path -LiteralPath (Join-Path $root 'tests') | Should -BeFalse

        Test-Path -LiteralPath (Join-Path $root 'docs/specs') | Should -BeTrue
        (Get-ChildItem -LiteralPath (Join-Path $root 'docs/specs') -File).Count | Should -Be 0

        Test-Path -LiteralPath (Join-Path $root 'docs/adr') | Should -BeTrue
        (Get-ChildItem -LiteralPath (Join-Path $root 'docs/adr') -File).Count | Should -Be 0

        Test-Path -LiteralPath (Join-Path $root 'docs/analysis') | Should -BeTrue
        (Get-ChildItem -LiteralPath (Join-Path $root 'docs/analysis') -File).Count | Should -Be 0

        $handoffFiles = Get-ChildItem -LiteralPath (Join-Path $root 'docs/handoff') -File
        $handoffFiles.Count | Should -Be 1
        $handoffFiles[0].Name | Should -Be 'LATEST.md'
    }

    It 'replaces reset files with fresh skeletons' {
        $root = New-FixtureRepo
        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $contextContent = Get-Content -LiteralPath (Join-Path $root '.agents/CONTEXT.md') -Raw -Encoding utf8
        $contextContent | Should -Match '## Стек технологий'
        $contextContent | Should -Not -Match 'Initial template context'

        $latestContent = Get-Content -LiteralPath (Join-Path $root 'docs/handoff/LATEST.md') -Raw -Encoding utf8
        $latestContent | Should -Match 'Текущее состояние проекта'
        $latestContent | Should -Not -Match 'Initial template latest'

        $readmeContent = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw -Encoding utf8
        $readmeContent | Should -Match 'Разработка с AI-агентами'
        $readmeContent | Should -Not -Match 'Initial template readme'

        $standardsContent = Get-Content -LiteralPath (Join-Path $root 'CODING_STANDARDS.md') -Raw -Encoding utf8
        $standardsContent | Should -Match 'Стандарты кодирования'
        $standardsContent | Should -Not -Match 'Initial template standards'
    }

    It 'records template-version and template-source in .agents/SKILLS.md' {
        $root = New-FixtureRepo
        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $skillsText = Get-Content -LiteralPath (Join-Path $root '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match '- \*\*template-source:\*\* `https://github\.com/my-org/my-template`'
        $skillsText | Should -Match '- \*\*template-version:\*\* `v0\.0\.0'
    }

    It 'records vX.Y.Z (<sha>) in .agents/SKILLS.md when template is a git repo with VERSION' {
        $root = New-FixtureRepo
        Initialize-GitRepoFixture -Path $root
        & git -C $root add .
        & git -C $root commit -m "Initial commit" --quiet
        $sha = (& git -C $root rev-parse --short HEAD).Trim()

        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $skillsText = Get-Content -LiteralPath (Join-Path $root '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match "- \*\*template-version:\*\* ``v0\.0\.0 \($sha\)``"
    }

    It 'falls back to YYYY-MM-DD <sha> in New mode when VERSION does not exist' {
        $root = New-FixtureRepo
        Remove-Item -LiteralPath (Join-Path $root 'VERSION') -Force
        Initialize-GitRepoFixture -Path $root
        & git -C $root add .
        & git -C $root commit -m "Initial commit" --quiet
        $sha = (& git -C $root rev-parse --short HEAD).Trim()

        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $skillsText = Get-Content -LiteralPath (Join-Path $root '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match "- \*\*template-version:\*\* ``\d{4}-\d{2}-\d{2} $sha``"
    }

    It 'leaves payload files untouched' {
        $root = New-FixtureRepo
        $agentsBefore = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding utf8
        $claudeBefore = Get-Content -LiteralPath (Join-Path $root 'CLAUDE.md') -Raw -Encoding utf8
        $trackerBefore = Get-Content -LiteralPath (Join-Path $root 'docs/agents/issue-tracker.md') -Raw -Encoding utf8

        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $agentsAfter = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding utf8
        $claudeAfter = Get-Content -LiteralPath (Join-Path $root 'CLAUDE.md') -Raw -Encoding utf8
        $trackerAfter = Get-Content -LiteralPath (Join-Path $root 'docs/agents/issue-tracker.md') -Raw -Encoding utf8

        $agentsAfter | Should -Be $agentsBefore
        $claudeAfter | Should -Be $claudeBefore
        $trackerAfter | Should -Be $trackerBefore
    }

    It 'is idempotent on repeated runs' {
        $root = New-FixtureRepo
        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $contextFirst = Get-Content -LiteralPath (Join-Path $root '.agents/CONTEXT.md') -Raw -Encoding utf8
        $skillsFirst = Get-Content -LiteralPath (Join-Path $root '.agents/SKILLS.md') -Raw -Encoding utf8

        # Second run should execute cleanly without error
        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        $contextSecond = Get-Content -LiteralPath (Join-Path $root '.agents/CONTEXT.md') -Raw -Encoding utf8
        $skillsSecond = Get-Content -LiteralPath (Join-Path $root '.agents/SKILLS.md') -Raw -Encoding utf8

        $contextSecond | Should -Be $contextFirst
        $skillsSecond | Should -Be $skillsFirst
    }

    It 'resolves repo root relative to the script when -RepoRoot is omitted' {
        $root = New-FixtureRepo
        $scriptInFixture = Join-Path $root '.agents' 'skills' 'init-project' 'scripts' 'Initialize-Project.ps1'

        & $scriptInFixture -Mode New -TemplateSource 'https://github.com/my-org/my-template'

        Test-Path -LiteralPath (Join-Path $root 'tests') | Should -BeFalse
        $readmeContent = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw -Encoding utf8
        $readmeContent | Should -Match 'Разработка с AI-агентами'
    }

    It 'cleans all release Meta files, deletes release skill, strips release from SKILLS.md, keeps THIRD_PARTY_NOTICES.md, and passes Test-Template' {
        $root = New-FixtureRepo
        Initialize-GitRepoFixture -Path $root
        Set-Content -LiteralPath (Join-Path $root 'VERSION') -Value "1.2.3`n" -Encoding utf8
        & git -C $root add .
        & git -C $root commit -m "Initial template commit" --quiet
        $sha = (& git -C $root rev-parse --short HEAD).Trim()

        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/cannoneer85-svg/test-project'

        # Release machinery files removed
        Test-Path -LiteralPath (Join-Path $root 'CHANGELOG.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'VERSION') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'LICENSE') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root '.github') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'README.ru.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'CONTRIBUTING.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'SECURITY.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'docs/releasing.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root '.agents/skills/release') | Should -BeFalse

        # THIRD_PARTY_NOTICES.md preserved
        Test-Path -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md') | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md') -Raw -Encoding utf8) | Should -Match 'Third Party Notices'

        # SKILLS.md template-version recorded from VERSION before cleaning, release skill and header removed
        $skillsContent = Get-Content -LiteralPath (Join-Path $root '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsContent | Should -Match "- \*\*template-version:\*\* ``v1\.2\.3 \($sha\)``"
        $skillsContent | Should -Not -Match 'Только Шаблон'
        $skillsContent | Should -Not -Match 'skills/release/SKILL\.md'

        # Test-Template.ps1 in new project exits 0
        $testOutput = & (Join-Path $root '.agents/scripts/Test-Template.ps1')
        $LASTEXITCODE | Should -Be 0
        ($testOutput | Where-Object { $_ -match '^OK:' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Initialize-Project.ps1 -Mode Adopt' {
    It 'leaves existing files byte-for-byte unchanged' {
        $target = New-TargetRepo
        $readmeBefore = [System.IO.File]::ReadAllBytes((Join-Path $target 'README.md'))
        $agentsBefore = [System.IO.File]::ReadAllBytes((Join-Path $target 'AGENTS.md'))
        $docBefore = [System.IO.File]::ReadAllBytes((Join-Path $target 'docs/existing.md'))

        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        $readmeAfter = [System.IO.File]::ReadAllBytes((Join-Path $target 'README.md'))
        $agentsAfter = [System.IO.File]::ReadAllBytes((Join-Path $target 'AGENTS.md'))
        $docAfter = [System.IO.File]::ReadAllBytes((Join-Path $target 'docs/existing.md'))

        $readmeAfter | Should -Be $readmeBefore
        $agentsAfter | Should -Be $agentsBefore
        $docAfter | Should -Be $docBefore
    }

    It 'lists conflicts when destination files already exist' {
        $target = New-TargetRepo
        $output = & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        $conflictFound = ($output | Where-Object { $_ -match 'Conflict.*AGENTS\.md' }).Count -gt 0
        $conflictFound | Should -BeTrue
    }

    It 'appends missing .gitignore entries without duplicates' {
        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        $lines = (Get-Content -LiteralPath (Join-Path $target '.gitignore') -Encoding utf8) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        # Pre-existing lines preserved
        $lines | Should -Contain 'node_modules/'
        $lines | Should -Contain '*.log'

        # Missing entries appended
        $lines | Should -Contain '.claude/skills/'
        $lines | Should -Contain '.scratch/'

        # No duplicate lines
        @($lines | Where-Object { $_ -eq '.claude/skills/' }).Count | Should -Be 1
        @($lines | Where-Object { $_ -eq '.scratch/' }).Count | Should -Be 1
    }

    It 'does not copy meta files or directories' {
        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        Test-Path -LiteralPath (Join-Path $target 'tests') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'docs/research') | Should -BeFalse

        # docs/specs should exist as scaffold directory but contain no template specs
        Test-Path -LiteralPath (Join-Path $target 'docs/specs') | Should -BeTrue
        (Get-ChildItem -LiteralPath (Join-Path $target 'docs/specs') -File).Count | Should -Be 0

        # docs/adr should exist as scaffold directory but contain no template ADRs
        Test-Path -LiteralPath (Join-Path $target 'docs/adr') | Should -BeTrue
        (Get-ChildItem -LiteralPath (Join-Path $target 'docs/adr') -File).Count | Should -Be 0

        # docs/analysis should exist as scaffold directory but contain no files
        Test-Path -LiteralPath (Join-Path $target 'docs/analysis') | Should -BeTrue
        (Get-ChildItem -LiteralPath (Join-Path $target 'docs/analysis') -File).Count | Should -Be 0

        # docs/handoff should contain at most LATEST.md, no template handoffs
        $handoffFiles = Get-ChildItem -LiteralPath (Join-Path $target 'docs/handoff') -File
        $handoffFiles.Count | Should -Be 1
        $handoffFiles[0].Name | Should -Be 'LATEST.md'
    }

    It 'records template-version and template-source in target repo .agents/SKILLS.md' {
        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        $skillsText = Get-Content -LiteralPath (Join-Path $target '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match "- \*\*template-source:\*\* ``$([regex]::Escape($script:TemplateRoot))``"
        $skillsText | Should -Match '- \*\*template-version:\*\* `v0\.0\.0'
    }

    It 'records explicit vX.Y.Z (<sha>) in target repo when -TemplateVersion is provided' {
        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot -TemplateVersion 'v1.2.3 (abc1234)'

        $skillsText = Get-Content -LiteralPath (Join-Path $target '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match '- \*\*template-version:\*\* `v1\.2\.3 \(abc1234\)`'
    }

    It 'falls back to legacy date in Adopt mode when VERSION does not exist in template source' {
        $nonVerTemplate = (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $nonVerTemplate -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot 'AGENTS.md') -Destination (Join-Path $nonVerTemplate 'AGENTS.md')
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.agents') -Destination $nonVerTemplate -Recurse -Force
        if (Test-Path -LiteralPath (Join-Path $nonVerTemplate 'VERSION')) {
            Remove-Item -LiteralPath (Join-Path $nonVerTemplate 'VERSION') -Force
        }

        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $nonVerTemplate

        $skillsText = Get-Content -LiteralPath (Join-Path $target '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match '- \*\*template-version:\*\* `\d{4}-\d{2}-\d{2}'
    }

    It 'is idempotent on repeat runs without making any changes' {
        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        # Capture state of all files after first run
        $filesBefore = @{}
        Get-ChildItem -LiteralPath $target -Recurse -File | ForEach-Object {
            $rel = [System.IO.Path]::GetRelativePath($target, $_.FullName)
            $filesBefore[$rel] = [System.IO.File]::ReadAllBytes($_.FullName)
        }

        # Second run should execute cleanly
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot

        $filesAfter = @{}
        Get-ChildItem -LiteralPath $target -Recurse -File | ForEach-Object {
            $rel = [System.IO.Path]::GetRelativePath($target, $_.FullName)
            $filesAfter[$rel] = [System.IO.File]::ReadAllBytes($_.FullName)
        }

        $filesAfter.Count | Should -Be $filesBefore.Count
        foreach ($rel in $filesBefore.Keys) {
            $filesAfter.ContainsKey($rel) | Should -BeTrue
            $filesAfter[$rel] | Should -Be $filesBefore[$rel]
        }
    }

    It 'does not copy release skill or release Meta files, copies THIRD_PARTY_NOTICES.md, and strips release from SKILLS.md' {
        # Create template source with release files and THIRD_PARTY_NOTICES.md
        $tplSource = (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $tplSource -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot 'AGENTS.md') -Destination (Join-Path $tplSource 'AGENTS.md')
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.gitattributes') -Destination (Join-Path $tplSource '.gitattributes')
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.agents') -Destination $tplSource -Recurse -Force

        # Seed release meta files and THIRD_PARTY_NOTICES.md in template
        Set-Content -LiteralPath (Join-Path $tplSource 'CHANGELOG.md') -Value "# Changelog`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $tplSource 'VERSION') -Value "1.0.0`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $tplSource 'LICENSE') -Value "MIT License`n" -Encoding utf8
        New-Item -ItemType Directory -Path (Join-Path $tplSource '.github') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tplSource '.github' 'ci.yml') -Value "name: CI`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $tplSource 'README.ru.md') -Value "# Ru`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $tplSource 'CONTRIBUTING.md') -Value "# Contrib`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $tplSource 'SECURITY.md') -Value "# Sec`n" -Encoding utf8
        $docRelDir = Join-Path $tplSource 'docs'
        if (-not (Test-Path -LiteralPath $docRelDir)) { New-Item -ItemType Directory -Path $docRelDir -Force | Out-Null }
        Set-Content -LiteralPath (Join-Path $docRelDir 'releasing.md') -Value "# Rel`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $tplSource 'THIRD_PARTY_NOTICES.md') -Value "# Third Party Notices`n" -Encoding utf8

        $target = New-TargetRepo
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $tplSource

        # Release meta files not copied
        Test-Path -LiteralPath (Join-Path $target 'CHANGELOG.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'VERSION') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'LICENSE') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target '.github') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'README.ru.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'CONTRIBUTING.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'SECURITY.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target 'docs/releasing.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target '.agents/skills/release') | Should -BeFalse

        # THIRD_PARTY_NOTICES.md copied
        Test-Path -LiteralPath (Join-Path $target 'THIRD_PARTY_NOTICES.md') | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $target 'THIRD_PARTY_NOTICES.md') -Raw -Encoding utf8) | Should -Match 'Third Party Notices'

        # SKILLS.md does not contain release skill or Только Шаблон section
        $skillsContent = Get-Content -LiteralPath (Join-Path $target '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsContent | Should -Not -Match 'Только Шаблон'
        $skillsContent | Should -Not -Match 'skills/release/SKILL\.md'

        # Test-Template.ps1 exits 0
        $testOutput = & (Join-Path $target '.agents/scripts/Test-Template.ps1')
        $LASTEXITCODE | Should -Be 0
        ($testOutput | Where-Object { $_ -match '^OK:' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Initialize-Project.ps1 tracker reconfiguration' {
    It 'updates only docs/agents/issue-tracker.md and AGENTS.md tracker section' {
        $root = New-FixtureRepo
        & $script:InitScript -Mode New -RepoRoot $root -TemplateSource 'https://github.com/my-org/my-template'

        # Initial tracker is local
        (Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding utf8) |
            Should -Match 'Local Markdown under'

        # Snapshot all other files
        $otherFilesBefore = @{}
        Get-ChildItem -LiteralPath $root -Recurse -File |
            Where-Object {
                $_.FullName -ne (Join-Path $root 'AGENTS.md') -and
                $_.FullName -ne (Join-Path $root 'docs/agents/issue-tracker.md')
            } |
            ForEach-Object {
                $rel = [System.IO.Path]::GetRelativePath($root, $_.FullName)
                $otherFilesBefore[$rel] = [System.IO.File]::ReadAllBytes($_.FullName)
            }

        # Switch tracker to github
        & $script:InitScript -Mode SetTracker -Tracker github -RepoRoot $root

        # Verify docs/agents/issue-tracker.md updated
        $trackerContent = Get-Content -LiteralPath (Join-Path $root 'docs/agents/issue-tracker.md') -Raw -Encoding utf8
        $trackerContent | Should -Match '# Issue tracker: GitHub'

        # Verify AGENTS.md issue tracker block updated
        $agentsContent = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding utf8
        $agentsContent | Should -Match 'GitHub issues via `gh` CLI. See \[`docs/agents/issue-tracker\.md`\]\(docs/agents/issue-tracker\.md\)\.'
        $agentsContent | Should -Not -Match 'Local Markdown under'
        # Verify other sections in AGENTS.md remained intact
        $agentsContent | Should -Match '# Agent rules'
        $agentsContent | Should -Match '### Triage labels'
        $agentsContent | Should -Match '### Domain docs'

        # Verify ALL other files in the repo are completely untouched
        foreach ($rel in $otherFilesBefore.Keys) {
            $currentBytes = [System.IO.File]::ReadAllBytes((Join-Path $root $rel))
            $currentBytes | Should -Be $otherFilesBefore[$rel]
        }

        # Switch tracker to gitlab
        & $script:InitScript -Mode SetTracker -Tracker gitlab -RepoRoot $root

        $trackerContentGitlab = Get-Content -LiteralPath (Join-Path $root 'docs/agents/issue-tracker.md') -Raw -Encoding utf8
        $trackerContentGitlab | Should -Match '# Issue tracker: GitLab'

        $agentsContentGitlab = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding utf8
        $agentsContentGitlab | Should -Match 'GitLab issues via `glab` CLI. See \[`docs/agents/issue-tracker\.md`\]\(docs/agents/issue-tracker\.md\)\.'
        $agentsContentGitlab | Should -Not -Match 'GitHub issues via'

        foreach ($rel in $otherFilesBefore.Keys) {
            $currentBytes = [System.IO.File]::ReadAllBytes((Join-Path $root $rel))
            $currentBytes | Should -Be $otherFilesBefore[$rel]
        }
    }
}

Describe 'Initialize-Project.ps1 -Mode Update' {
    It 'correctly categorizes added, modified, removed, and conflict files in dry-run' {
        $fix = New-UpdateFixture
        $output = & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot

        ($output | Where-Object { $_ -match 'Added in Template' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-added-v2' }) | Should -Not -BeNullOrEmpty

        ($output | Where-Object { $_ -match 'Modified in Template' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-to-modify' }) | Should -Not -BeNullOrEmpty

        ($output | Where-Object { $_ -match 'Removed in Template' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-to-remove' }) | Should -Not -BeNullOrEmpty

        ($output | Where-Object { $_ -match 'Conflict: modified locally' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-local-edit' }) | Should -Not -BeNullOrEmpty
    }

    It 'leaves target repository completely unchanged in dry-run without -Apply' {
        $fix = New-UpdateFixture
        $filesBefore = @{}
        Get-ChildItem -LiteralPath $fix.ProjectRoot -Recurse -File | ForEach-Object {
            $rel = [System.IO.Path]::GetRelativePath($fix.ProjectRoot, $_.FullName)
            $filesBefore[$rel] = [System.IO.File]::ReadAllBytes($_.FullName)
        }

        & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot

        $filesAfter = @{}
        Get-ChildItem -LiteralPath $fix.ProjectRoot -Recurse -File | ForEach-Object {
            $rel = [System.IO.Path]::GetRelativePath($fix.ProjectRoot, $_.FullName)
            $filesAfter[$rel] = [System.IO.File]::ReadAllBytes($_.FullName)
        }

        $filesAfter.Count | Should -Be $filesBefore.Count
        foreach ($rel in $filesBefore.Keys) {
            $filesAfter.ContainsKey($rel) | Should -BeTrue
            $filesAfter[$rel] | Should -Be $filesBefore[$rel]
        }
    }

    It 'applies added, modified, and removed updates with -Apply, while preserving locally modified conflict file' {
        $fix = New-UpdateFixture

        & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot -Apply

        # 1. Added file is copied
        $addedPath = Join-Path $fix.ProjectRoot '.agents' 'skills' 'skill-added-v2' 'SKILL.md'
        Test-Path -LiteralPath $addedPath -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath $addedPath -Raw -Encoding utf8) | Should -Match 'Skill added in v2'

        # 2. Modified file is updated
        $modPath = Join-Path $fix.ProjectRoot '.agents' 'skills' 'skill-to-modify' 'SKILL.md'
        (Get-Content -LiteralPath $modPath -Raw -Encoding utf8) | Should -Match 'Updated content in v2'

        # 3. Removed file is deleted
        $remPath = Join-Path $fix.ProjectRoot '.agents' 'skills' 'skill-to-remove' 'SKILL.md'
        Test-Path -LiteralPath $remPath | Should -BeFalse

        # 4. Conflicting file is NOT overwritten
        $localPath = Join-Path $fix.ProjectRoot '.agents' 'skills' 'skill-local-edit' 'SKILL.md'
        Test-Path -LiteralPath $localPath -PathType Leaf | Should -BeTrue
        $localContent = Get-Content -LiteralPath $localPath -Raw -Encoding utf8
        $localContent | Should -Match 'Locally modified by project team'
        $localContent | Should -Not -Match 'Template v2 modified this too'

        # 5. Template version is updated in .agents/SKILLS.md
        $skillsContent = Get-Content -LiteralPath (Join-Path $fix.ProjectRoot '.agents' 'SKILLS.md') -Raw -Encoding utf8
        $skillsContent | Should -Match "- \*\*template-version:\*\* ``v2\.0\.0 \($($fix.V2Sha)\)``"
    }

    It 'displays Current and Target versions, warns on MAJOR bump, and outputs changelog excerpt for legacy project' {
        $fix = New-UpdateFixture
        $output = & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot

        ($output | Where-Object { $_ -match "^Current version:\s+2026-10-03\s+$($fix.V1Sha)" }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match "^Target version:\s+v2\.0\.0\s+\($($fix.V2Sha)\)" }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'WARNING: Target version \(2\.0\.0\) introduces a MAJOR version bump over current version \(2026-10-03\)' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'Changelog excerpt' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match '## \[2\.0\.0\]' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match '## \[1\.0\.0\]' }) | Should -Not -BeNullOrEmpty
    }

    It 'retrieves base commit sha from vX.Y.Z (<sha>) format' {
        $fix = New-UpdateFixture
        # Update SKILLS.md in Project repo to new format with V1Sha
        $projectSkillsPath = Join-Path $fix.ProjectRoot '.agents' 'SKILLS.md'
        $projectSkillsContent = Get-Content -LiteralPath $projectSkillsPath -Raw -Encoding utf8
        $projectSkillsContent = [regex]::Replace($projectSkillsContent, '(?m)^-\s*\*\*template-version:\*\*.*$', "- **template-version:** ``v1.0.0 ($($fix.V1Sha))``")
        Set-Content -LiteralPath $projectSkillsPath -Value $projectSkillsContent -Encoding utf8 -NoNewline

        $output = & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot

        ($output | Where-Object { $_ -match "Base git commit:\s+$($fix.V1Sha)" }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-added-v2' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-to-modify' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-to-remove' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'skill-local-edit' }) | Should -Not -BeNullOrEmpty
    }

    It 'does not warn on MINOR bump and filters changelog excerpt to (current, target]' {
        $fix = New-UpdateFixture
        # Set project version to v2.0.0 ($fix.V1Sha)
        $projectSkillsPath = Join-Path $fix.ProjectRoot '.agents' 'SKILLS.md'
        $projectSkillsContent = Get-Content -LiteralPath $projectSkillsPath -Raw -Encoding utf8
        $projectSkillsContent = [regex]::Replace($projectSkillsContent, '(?m)^-\s*\*\*template-version:\*\*.*$', "- **template-version:** ``v2.0.0 ($($fix.V1Sha))``")
        Set-Content -LiteralPath $projectSkillsPath -Value $projectSkillsContent -Encoding utf8 -NoNewline

        # Update Template v2 VERSION to 2.1.0 and add section [2.1.0] to CHANGELOG.md
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'VERSION') -Value "2.1.0`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'CHANGELOG.md') -Value @"
# Changelog

## [Unreleased]

## [2.1.0] - 2026-11-15 - Minor Feature
### Added
- minor-feature-skill

## [2.0.0] - 2026-11-01 - Major Release
### Added
- skill-added-v2

## [1.0.0] - 2026-10-04 - Initial Release
### Added
- initial template skills
"@ -Encoding utf8

        & git -C $fix.TemplateRoot add .
        & git -C $fix.TemplateRoot commit -m "Template v2.1" --quiet
        $v21Sha = (& git -C $fix.TemplateRoot rev-parse --short HEAD).Trim()

        $output = & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot

        ($output | Where-Object { $_ -match "^Current version:\s+v2\.0\.0" }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match "^Target version:\s+v2\.1\.0\s+\($v21Sha\)" }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match 'WARNING.*MAJOR' }) | Should -BeNullOrEmpty
        ($output | Where-Object { $_ -match '## \[2\.1\.0\]' }) | Should -Not -BeNullOrEmpty
        ($output | Where-Object { $_ -match '## \[2\.0\.0\]' }) | Should -BeNullOrEmpty
        ($output | Where-Object { $_ -match '## \[1\.0\.0\]' }) | Should -BeNullOrEmpty
    }

    It 'is idempotent and reports no pending updates on repeat run after applying clean changes' {
        $fix = New-UpdateFixture
        # Revert skill-local-edit in Project to match Template v2 so all files are clean
        $localPath = Join-Path $fix.ProjectRoot '.agents' 'skills' 'skill-local-edit' 'SKILL.md'
        $tplPath = Join-Path $fix.TemplateRoot '.agents' 'skills' 'skill-local-edit' 'SKILL.md'
        Copy-Item -LiteralPath $tplPath -Destination $localPath -Force

        # First update
        & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot -Apply

        # Second update
        $repeatOutput = & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot
        ($repeatOutput | Where-Object { $_ -match 'No pending template updates' }) | Should -Not -BeNullOrEmpty
    }

    It 'treats differing files as conflicts when base version cannot be retrieved (non-git template source)' {
        $target = New-TargetRepo
        # Non-git directory template
        $nonGitTemplate = (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $nonGitTemplate -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot 'AGENTS.md') -Destination (Join-Path $nonGitTemplate 'AGENTS.md')
        New-Item -ItemType Directory -Path (Join-Path $nonGitTemplate '.agents') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.agents' 'SKILLS.md') -Destination (Join-Path $nonGitTemplate '.agents' 'SKILLS.md')

        # Target has differing AGENTS.md
        Set-Content -LiteralPath (Join-Path $target 'AGENTS.md') -Value 'Custom AGENTS content' -Encoding utf8
        # Target SKILLS.md with non-git source
        $skillsText = "- **template-version:** ``2026-10-03```n- **template-source:** ``$nonGitTemplate```n"
        New-Item -ItemType Directory -Path (Join-Path $target '.agents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $target '.agents' 'SKILLS.md') -Value $skillsText -Encoding utf8

        $output = & $script:InitScript -Mode Update -RepoRoot $target -TemplateSource $nonGitTemplate
        ($output | Where-Object { $_ -match 'Conflict: modified locally' -and $_ -match 'AGENTS\.md' }) | Should -Not -BeNullOrEmpty
    }

    It 'does not copy release skill or release Meta files during Update, but copies THIRD_PARTY_NOTICES.md' {
        $fix = New-UpdateFixture

        # In Template, add release meta files, release skill, and THIRD_PARTY_NOTICES.md
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'LICENSE') -Value "MIT License`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'README.ru.md') -Value "# Ru`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'CONTRIBUTING.md') -Value "# Contrib`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'SECURITY.md') -Value "# Sec`n" -Encoding utf8
        $docRelDir = Join-Path $fix.TemplateRoot 'docs'
        Set-Content -LiteralPath (Join-Path $docRelDir 'releasing.md') -Value "# Rel`n" -Encoding utf8
        $ghDir = Join-Path $fix.TemplateRoot '.github'
        New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $ghDir 'ci.yml') -Value "name: CI`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $fix.TemplateRoot 'THIRD_PARTY_NOTICES.md') -Value "# Third Party Notices v2`n" -Encoding utf8

        $relSkillDir = Join-Path $fix.TemplateRoot '.agents' 'skills' 'release'
        if (-not (Test-Path -LiteralPath $relSkillDir)) {
            New-Item -ItemType Directory -Path $relSkillDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $relSkillDir 'SKILL.md') -Value "---\nname: release\n---\n# Release" -Encoding utf8
        }

        & git -C $fix.TemplateRoot add .
        & git -C $fix.TemplateRoot commit -m "Add release files and notices in template" --quiet

        $dryRun = & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot

        # Release machinery is NOT reported as Added in Template
        ($dryRun | Where-Object { $_ -match 'Added in Template.*(?:release|LICENSE|README\.ru|CONTRIBUTING|SECURITY|\.github)' }) | Should -BeNullOrEmpty
        # THIRD_PARTY_NOTICES.md IS reported as Added in Template
        ($dryRun | Where-Object { $_ -match 'Added in Template.*THIRD_PARTY_NOTICES\.md' }) | Should -Not -BeNullOrEmpty

        # Apply update
        & $script:InitScript -Mode Update -RepoRoot $fix.ProjectRoot -Apply

        # Target project does not have release files or release skill
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot 'LICENSE') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot 'README.ru.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot 'CONTRIBUTING.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot 'SECURITY.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot '.github') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot '.agents/skills/release') | Should -BeFalse

        # Target project has THIRD_PARTY_NOTICES.md
        Test-Path -LiteralPath (Join-Path $fix.ProjectRoot 'THIRD_PARTY_NOTICES.md') | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $fix.ProjectRoot 'THIRD_PARTY_NOTICES.md') -Raw -Encoding utf8) | Should -Match 'Third Party Notices v2'

        # Project SKILLS.md does not contain release skill or Только Шаблон section
        $skillsContent = Get-Content -LiteralPath (Join-Path $fix.ProjectRoot '.agents' 'SKILLS.md') -Raw -Encoding utf8
        $skillsContent | Should -Not -Match 'Только Шаблон'
        $skillsContent | Should -Not -Match 'skills/release/SKILL\.md'

        # Test-Template.ps1 in Project exits 0
        $testOutput = & (Join-Path $fix.ProjectRoot '.agents/scripts/Test-Template.ps1')
        $LASTEXITCODE | Should -Be 0
        ($testOutput | Where-Object { $_ -match '^OK:' }) | Should -Not -BeNullOrEmpty
    }
}


