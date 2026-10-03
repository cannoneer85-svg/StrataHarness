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
        & git -C $templateResolved init --quiet
        & git -C $templateResolved config user.name "TestTemplate"
        & git -C $templateResolved config user.email "test@example.com"

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
        $skillsContent = $skillsContent.TrimEnd() + "`n" + $fixtureSkillsRows + "`n"
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
        $skillsContentV2 = $skillsContentV2.TrimEnd() + "`n| [skill-added-v2](skills/skill-added-v2/SKILL.md) | Test skill | авто | свой | active |`n"
        Set-Content -LiteralPath $skillsMdPath -Value $skillsContentV2 -Encoding utf8 -NoNewline

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
        $skillsText | Should -Match '- \*\*template-version:\*\* `\d{4}-\d{2}-\d{2}'
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
        & $script:InitScript -Mode Adopt -RepoRoot $target -TemplateSource $script:TemplateRoot -TemplateVersion '2026-10-03 testver'

        $skillsText = Get-Content -LiteralPath (Join-Path $target '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsText | Should -Match "- \*\*template-source:\*\* ``$([regex]::Escape($script:TemplateRoot))``"
        $skillsText | Should -Match '- \*\*template-version:\*\* `2026-10-03 testver`'
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
        $skillsContent | Should -Match "- \*\*template-version:\*\* ``.*$($fix.V2Sha)``"
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
}


