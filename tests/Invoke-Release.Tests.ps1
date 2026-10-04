#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Seam A: Invoke-Release.ps1 -Plan
# Tests release planning, conventional commit parsing, SemVer bump computation,
# candidate flags, warnings, precondition checks P1-P5, and output artifacts.

BeforeAll {
    $script:TemplateRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ReleaseScript = Join-Path $script:TemplateRoot '.agents' 'skills' 'release' 'scripts' 'Invoke-Release.ps1'

    function New-ReleaseFixture {
        param(
            [string]$InitialVersion = '1.0.0',
            [string]$Branch = 'main'
        )
        $tmpDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        $resolved = (Resolve-Path -LiteralPath $tmpDir).Path

        # git init
        & git -C $resolved init --quiet -b $Branch
        & git -C $resolved config user.name "ReleaseTester"
        & git -C $resolved config user.email "tester@example.com"
        & git -C $resolved config commit.gpgsign false
        & git -C $resolved config core.autocrlf false
        & git -C $resolved config advice.crlf false

        # Copy minimal .agents structure needed
        $fixtureScripts = Join-Path $resolved '.agents' 'scripts'
        New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.agents' 'scripts' 'SemVer.ps1') -Destination $fixtureScripts
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.agents' 'scripts' 'Test-Template.ps1') -Destination $fixtureScripts

        # Copy release skill
        $releaseSkillDest = Join-Path $resolved '.agents' 'skills' 'release'
        New-Item -ItemType Directory -Path (Split-Path -Parent $releaseSkillDest) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:TemplateRoot '.agents' 'skills' 'release') -Destination $releaseSkillDest -Recurse

        # Dummy sample skill to allow testing deleted skill directory
        $dummySkillDir = Join-Path $resolved '.agents' 'skills' 'sample-skill'
        New-Item -ItemType Directory -Path $dummySkillDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dummySkillDir 'SKILL.md') -Value "---\nname: sample-skill\n---\n# Sample" -Encoding utf8

        # .gitignore
        Set-Content -LiteralPath (Join-Path $resolved '.gitignore') -Value ".scratch/`n" -Encoding utf8

        # CHANGELOG.md
        $initialChangelog = @"
# Changelog

All notable changes documented here.

## [Unreleased]
"@
        if ($InitialVersion -and $InitialVersion -ne '0.0.0') {
            $initialChangelog += "`n`n## [$InitialVersion] - 2026-10-01 - Baseline Release`n`n### Added`n- baseline"
        }
        Set-Content -LiteralPath (Join-Path $resolved 'CHANGELOG.md') -Value $initialChangelog -Encoding utf8

        # VERSION file
        if ($InitialVersion) {
            Set-Content -LiteralPath (Join-Path $resolved 'VERSION') -Value $InitialVersion -Encoding utf8
        }

        # Registry and AGENTS files
        $skillsHeader = if ($InitialVersion) { "- **template-version:** ``v$InitialVersion```n`n" } else { "" }
        Set-Content -LiteralPath (Join-Path $resolved '.agents' 'SKILLS.md') -Value "$skillsHeader# Registry`n`n| [release](skills/release/SKILL.md) | Release | ручной | свой | active |`n| [sample-skill](skills/sample-skill/SKILL.md) | Sample | авто | свой | active |`n" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $resolved 'AGENTS.md') -Value "# Agents`n" -Encoding utf8

        # Commit initial state
        & git -C $resolved add -A
        & git -C $resolved commit -m "chore: initial baseline" --quiet

        # Create initial tag
        if ($InitialVersion) {
            & git -C $resolved tag -a "v$InitialVersion" -m "v$InitialVersion"
        }

        return $resolved
    }

    function New-BareOrigin {
        param(
            [string]$Branch = 'main'
        )
        $bareDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.git')
        New-Item -ItemType Directory -Path $bareDir -Force | Out-Null
        $resolved = (Resolve-Path -LiteralPath $bareDir).Path
        & git init --bare --quiet -b $Branch $resolved
        & git -C $resolved config advice.crlf false
        return $resolved
    }

    function Invoke-ReleasePlan {
        param(
            [string]$RepoRoot,
            [string]$Bump,
            [string]$Version,
            [switch]$SkipChecks,
            [string[]]$AdditionalArgs
        )
        $cmdArgs = @('-NoProfile', '-File', $script:ReleaseScript, '-Plan', '-RepoRoot', $RepoRoot)
        if ($SkipChecks) { $cmdArgs += '-SkipChecks' }
        if ($Bump) { $cmdArgs += @('-Bump', $Bump) }
        if ($Version) { $cmdArgs += @('-Version', $Version) }
        if ($AdditionalArgs) { $cmdArgs += $AdditionalArgs }

        $output = & pwsh @cmdArgs 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    function Invoke-ReleaseApply {
        param(
            [string]$RepoRoot,
            [string]$NotesFile,
            [string]$Title,
            [string]$Version,
            [switch]$SkipChecks,
            [switch]$PushOnly,
            [string[]]$AdditionalArgs
        )
        $cmdArgs = @('-NoProfile', '-File', $script:ReleaseScript, '-Apply', '-RepoRoot', $RepoRoot)
        if ($SkipChecks) { $cmdArgs += '-SkipChecks' }
        if ($NotesFile) { $cmdArgs += @('-NotesFile', $NotesFile) }
        if ($Title) { $cmdArgs += @('-Title', $Title) }
        if ($Version) { $cmdArgs += @('-Version', $Version) }
        if ($PushOnly) { $cmdArgs += '-PushOnly' }
        if ($AdditionalArgs) { $cmdArgs += $AdditionalArgs }

        $output = & pwsh @cmdArgs 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    function Invoke-ReleasePushOnly {
        param(
            [string]$RepoRoot,
            [string]$Version,
            [switch]$SkipChecks,
            [switch]$ApplySwitch
        )
        $cmdArgs = if ($ApplySwitch) {
            @('-NoProfile', '-File', $script:ReleaseScript, '-Apply', '-PushOnly', '-RepoRoot', $RepoRoot)
        } else {
            @('-NoProfile', '-File', $script:ReleaseScript, '-PushOnly', '-RepoRoot', $RepoRoot)
        }
        if ($SkipChecks) { $cmdArgs += '-SkipChecks' }
        if ($Version) { $cmdArgs += @('-Version', $Version) }

        $output = & pwsh @cmdArgs 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    function Invoke-ReleaseUndo {
        param(
            [string]$RepoRoot,
            [string]$Version
        )
        $cmdArgs = @('-NoProfile', '-File', $script:ReleaseScript, '-Undo', '-RepoRoot', $RepoRoot)
        if ($Version) { $cmdArgs += @('-Version', $Version) }

        $output = & pwsh @cmdArgs 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    function Invoke-ReleaseNotes {
        param(
            [string]$RepoRoot,
            [string]$Tag,
            [string]$OutNotesFile,
            [string]$OutTitleFile,
            [string[]]$AdditionalArgs
        )
        $cmdArgs = @('-NoProfile', '-File', $script:ReleaseScript, '-Notes', $Tag, '-RepoRoot', $RepoRoot)
        if ($OutNotesFile) { $cmdArgs += @('-OutNotesFile', $OutNotesFile) }
        if ($OutTitleFile) { $cmdArgs += @('-OutTitleFile', $OutTitleFile) }
        if ($AdditionalArgs) { $cmdArgs += $AdditionalArgs }

        $output = & pwsh @cmdArgs 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }
}

Describe 'Invoke-Release.ps1 -Plan Conventional Commits classification' {
    It 'proposes MINOR and section Added for feat commits' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'new-feature.txt') -Value 'feature'
        & git -C $fix add -A
        & git -C $fix commit -m "feat(api): add new endpoints" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'minor'
        $plan.TargetVersion | Should -Be '1.1.0'
        $plan.TargetTag | Should -Be 'v1.1.0'
        $plan.MajorCandidate | Should -BeFalse

        $notes = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -Raw -Encoding utf8
        $notes | Should -Match '### Added'
        $notes | Should -Match 'feat\(api\): add new endpoints'
        $notes | Should -Not -Match '### Fixed'
    }

    It 'proposes PATCH and section Fixed for fix commits' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'fix.txt') -Value 'fix'
        & git -C $fix add -A
        & git -C $fix commit -m "fix: resolve edge case in parser" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'patch'
        $plan.TargetVersion | Should -Be '1.0.1'

        $notes = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -Raw -Encoding utf8
        $notes | Should -Match '### Fixed'
        $notes | Should -Match 'fix: resolve edge case in parser'
        $notes | Should -Not -Match '### Added'
    }

    It 'proposes MAJOR and section Breaking for feat! commit' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'breaking.txt') -Value 'breaking'
        & git -C $fix add -A
        & git -C $fix commit -m "feat!: drop legacy configuration" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'major'
        $plan.TargetVersion | Should -Be '2.0.0'

        $notes = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -Raw -Encoding utf8
        $notes | Should -Match '### Breaking'
        $notes | Should -Match 'feat!: drop legacy configuration'
    }

    It 'proposes MAJOR and section Breaking for BREAKING CHANGE in commit body' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'breaking.txt') -Value 'breaking'
        & git -C $fix add -A
        $msg = "refactor: restructure agent folders`n`nBREAKING CHANGE: paths in config have changed."
        & git -C $fix commit -m $msg --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'major'
        $plan.TargetVersion | Should -Be '2.0.0'

        $notes = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -Raw -Encoding utf8
        $notes | Should -Match '### Breaking'
    }

    It 'groups mixed commits into their respective sections' {
        $fix = New-ReleaseFixture -InitialVersion '1.2.0'
        Set-Content -LiteralPath (Join-Path $fix 'f1.txt') -Value 'f1'
        & git -C $fix add -A
        & git -C $fix commit -m "fix(core): quick fix" --quiet

        Set-Content -LiteralPath (Join-Path $fix 'f2.txt') -Value 'f2'
        & git -C $fix add -A
        & git -C $fix commit -m "feat(ui): add dashboard" --quiet

        Set-Content -LiteralPath (Join-Path $fix 'f3.txt') -Value 'f3'
        & git -C $fix add -A
        & git -C $fix commit -m "docs: update install instructions" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'minor'
        $plan.TargetVersion | Should -Be '1.3.0'

        $notes = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -Raw -Encoding utf8
        $notes | Should -Match '### Added'
        $notes | Should -Match 'feat\(ui\): add dashboard'
        $notes | Should -Match '### Fixed'
        $notes | Should -Match 'fix\(core\): quick fix'
        $notes | Should -Match '### Other'
        $notes | Should -Match 'docs: update install instructions'
    }
}

Describe 'Invoke-Release.ps1 -Plan non-conventional commits' {
    It 'places non-conventional commits in Other and adds a warning' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'misc.txt') -Value 'misc'
        & git -C $fix add -A
        & git -C $fix commit -m "Just an informal commit message" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'patch'
        $plan.Warnings | Should -Match 'Non-conventional commit'
        $plan.Warnings | Should -Match 'Just an informal commit message'

        $notes = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -Raw -Encoding utf8
        $notes | Should -Match '### Other'
        $notes | Should -Match 'Just an informal commit message'
    }
}

Describe 'Invoke-Release.ps1 -Plan deleted skill directory' {
    It 'flags deleted skill folder as MAJOR candidate' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        # sample-skill was created in baseline fixture; now remove it
        & git -C $fix rm -r '.agents/skills/sample-skill' --quiet
        & git -C $fix commit -m "fix: remove sample skill" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.MajorCandidate | Should -BeTrue
        $plan.MajorCandidateReasons | Should -Match 'sample-skill'
        $plan.Warnings | Should -Match 'MAJOR candidate.*sample-skill'
        # Commit type alone suggested patch, but candidate flag is set
        $plan.BumpType | Should -Be 'patch'
    }
}

Describe 'Invoke-Release.ps1 -Plan bump and version overrides' {
    It 'overrides calculated bump with -Bump' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: standard feature" --quiet

        # Default would be minor (1.1.0), override to major
        $res = Invoke-ReleasePlan -RepoRoot $fix -Bump major -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.BumpType | Should -Be 'major'
        $plan.ProposedBump | Should -Be 'minor'
        $plan.BumpSource | Should -Be 'override-bump'
        $plan.TargetVersion | Should -Be '2.0.0'
    }

    It 'overrides target version with -Version' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: standard feature" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -Version '3.2.1-rc.1' -SkipChecks
        $res.ExitCode | Should -Be 0

        $plan = Get-Content -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -Raw -Encoding utf8 | ConvertFrom-Json
        $plan.TargetVersion | Should -Be '3.2.1-rc.1'
        $plan.TargetTag | Should -Be 'v3.2.1-rc.1'
        $plan.BumpSource | Should -Be 'override-version'
    }

    It 'throws when both -Bump and -Version are specified' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: standard feature" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -Bump minor -Version '2.0.0' -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Cannot specify both -Bump and -Version'
    }
}

Describe 'Invoke-Release.ps1 -Plan precondition failures' {
    It 'fails P1 when working tree is dirty' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: valid commit" --quiet

        # Dirty the tree
        Set-Content -LiteralPath (Join-Path $fix 'dirty.txt') -Value 'untracked file'

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Precondition P1 failed'
    }

    It 'fails P2 when not on main branch' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: valid commit" --quiet

        & git -C $fix checkout -b 'feature/release-test' --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Precondition P2 failed'
    }

    It 'fails P3 when validation checks fail and -SkipChecks is omitted' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        # Corrupt VERSION to make Test-Template.ps1 fail
        Set-Content -LiteralPath (Join-Path $fix 'VERSION') -Value 'not-a-valid-semver'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: bad version" --quiet

        $res = Invoke-ReleasePlan -RepoRoot $fix
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Precondition P3 failed'
    }

    It 'fails P4 when no commits exist since last tag' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        # No commits made after v1.0.0 tag

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Precondition P4 failed'
    }

    It 'fails P5 when target tag already exists' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: some feature" --quiet

        # Target tag v1.0.0 already exists
        $res = Invoke-ReleasePlan -RepoRoot $fix -Version '1.0.0' -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Precondition P5 failed'
    }
}

Describe 'Invoke-Release.ps1 -Plan file and history safety' {
    It 'does not modify tracked files, create commits, or create tags' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'f'
        & git -C $fix add -A
        & git -C $fix commit -m "feat: safe check" --quiet

        $headBefore = (& git -C $fix rev-parse HEAD).Trim()
        $tagsBefore = @(& git -C $fix tag -l)

        $res = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $res.ExitCode | Should -Be 0

        # HEAD commit has not changed
        $headAfter = (& git -C $fix rev-parse HEAD).Trim()
        $headAfter | Should -Be $headBefore

        # Tags have not changed
        $tagsAfter = @(& git -C $fix tag -l)
        $tagsAfter.Count | Should -Be $tagsBefore.Count
        foreach ($t in $tagsBefore) {
            $tagsAfter | Should -Contain $t
        }

        # Tracked files status is clean (excluding git-ignored .scratch/)
        $status = & git -C $fix status --porcelain
        $status | Should -BeNullOrEmpty

        # Plan artifacts exist
        Test-Path -LiteralPath (Join-Path $fix '.scratch/release/plan.json') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $fix '.scratch/release/notes.draft.md') -PathType Leaf | Should -BeTrue
    }
}

Describe 'Invoke-Release.ps1 -Apply release commit, tag, and push' {
    It 'creates single commit, annotated tag, and pushes to bare origin' {
        $bare = New-BareOrigin
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        & git -C $fix remote add origin ($bare.Replace('\', '/'))
        & git -C $fix push origin main --quiet

        Set-Content -LiteralPath (Join-Path $fix 'feature.txt') -Value 'new feature'
        & git -C $fix add feature.txt
        & git -C $fix commit -m "feat(core): add core feature" --quiet

        $headBeforeRelease = (& git -C $fix rev-parse HEAD).Trim()

        $notesFile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-notes.md')
        $notesContent = "### Added`n- feat(core): add core feature`n"
        Set-Content -LiteralPath $notesFile -Value $notesContent -Encoding utf8

        $res = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "First Feature Release" -Version "1.1.0" -SkipChecks
        $res.ExitCode | Should -Be 0

        # Verify exactly one commit created
        $releaseCommit = (& git -C $fix rev-parse HEAD).Trim()
        $releaseCommit | Should -Not -Be $headBeforeRelease
        (& git -C $fix rev-parse HEAD~1).Trim() | Should -Be $headBeforeRelease

        # Commit message
        (& git -C $fix log -1 --format=%s) | Should -Be "chore(release): v1.1.0"

        # Modified files in the release commit: exactly VERSION, CHANGELOG.md, .agents/SKILLS.md
        $changedFiles = @(& git -C $fix diff-tree --no-commit-id --name-only -r HEAD) | Sort-Object
        $changedFiles.Count | Should -Be 3
        $changedFiles[0] | Should -Be '.agents/SKILLS.md'
        $changedFiles[1] | Should -Be 'CHANGELOG.md'
        $changedFiles[2] | Should -Be 'VERSION'

        # File contents
        (Get-Content -LiteralPath (Join-Path $fix 'VERSION') -Raw -Encoding utf8).Trim() | Should -Be '1.1.0'
        $changelog = Get-Content -LiteralPath (Join-Path $fix 'CHANGELOG.md') -Raw -Encoding utf8
        $changelog | Should -Match '(?m)^##\s+\[1\.1\.0\]\s+-\s+\d{4}-\d{2}-\d{2}\s+-\s+First Feature Release'
        $changelog | Should -Match 'feat\(core\): add core feature'
        $skillsMd = Get-Content -LiteralPath (Join-Path $fix '.agents/SKILLS.md') -Raw -Encoding utf8
        $skillsMd | Should -Match '(?m)^-\s*\*\*template-version:\*\*\s*`v1\.1\.0`'

        # Annotated tag
        $tagCommit = (& git -C $fix rev-list -n 1 'v1.1.0').Trim()
        $tagCommit | Should -Be $releaseCommit
        $tagType = (& git -C $fix cat-file -t 'v1.1.0').Trim()
        $tagType | Should -Be 'tag'
        $tagMsg = [string]::Join("`n", @(& git -C $fix tag -l --format='%(contents:subject)' 'v1.1.0')).Trim()
        $tagMsg | Should -Be "First Feature Release"

        # Verify pushed to bare origin
        $originHead = (& git -C $bare rev-parse refs/heads/main).Trim()
        $originHead | Should -Be $releaseCommit
        $originTag = (& git -C $bare rev-parse refs/tags/v1.1.0).Trim()
        $originTag | Should -Not -BeNullOrEmpty
    }

    It 'works for first release into an empty bare origin' {
        $bare = New-BareOrigin
        $fix = New-ReleaseFixture -InitialVersion '0.0.0'
        & git -C $fix remote add origin ($bare.Replace('\', '/'))
        # Do not push initial baseline - origin is completely empty!

        Set-Content -LiteralPath (Join-Path $fix 'init.txt') -Value 'initial work'
        & git -C $fix add init.txt
        & git -C $fix commit -m "feat: initial feature" --quiet

        $notesFile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-notes.md')
        Set-Content -LiteralPath $notesFile -Value "### Added`n- initial release content`n" -Encoding utf8

        $res = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "Version 1.0.0" -Version "1.0.0" -SkipChecks
        $res.ExitCode | Should -Be 0

        (Get-Content -LiteralPath (Join-Path $fix 'VERSION') -Raw -Encoding utf8).Trim() | Should -Be '1.0.0'
        $originHead = (& git -C $bare rev-parse refs/heads/main).Trim()
        $localHead = (& git -C $fix rev-parse HEAD).Trim()
        $originHead | Should -Be $localHead
        (& git -C $bare tag -l 'v1.0.0') | Should -Be 'v1.0.0'
    }

    It 'applies release using target version from plan.json when -Version is omitted' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat.txt') -Value 'feat'
        & git -C $fix add feat.txt
        & git -C $fix commit -m "feat: new feature" --quiet

        # Run -Plan first
        $planRes = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $planRes.ExitCode | Should -Be 0

        $notesFile = Join-Path $fix '.scratch/release/notes.draft.md'
        # Run -Apply without -Version
        $applyRes = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "Release from Plan" -SkipChecks
        $applyRes.ExitCode | Should -Be 0

        (Get-Content -LiteralPath (Join-Path $fix 'VERSION') -Raw -Encoding utf8).Trim() | Should -Be '1.1.0'
        (& git -C $fix tag -l 'v1.1.0') | Should -Be 'v1.1.0'
    }

    It 'fails when HEAD has changed since plan.json was generated' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feat1.txt') -Value '1'
        & git -C $fix add feat1.txt
        & git -C $fix commit -m "feat: first" --quiet

        # Run -Plan
        $planRes = Invoke-ReleasePlan -RepoRoot $fix -SkipChecks
        $planRes.ExitCode | Should -Be 0

        # Change HEAD after plan
        Set-Content -LiteralPath (Join-Path $fix 'feat2.txt') -Value '2'
        & git -C $fix add feat2.txt
        & git -C $fix commit -m "feat: second after plan" --quiet

        $notesFile = Join-Path $fix '.scratch/release/notes.draft.md'
        $applyRes = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "Should Fail" -SkipChecks
        $applyRes.ExitCode | Should -Not -Be 0
        $applyRes.Output | Should -Match 'HEAD has changed since release plan'
    }
}

Describe 'Invoke-Release.ps1 -Apply precondition P6: origin/main ahead' {
    It 'fails before creating commit or tag when origin/main is ahead' {
        $bare = New-BareOrigin
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        & git -C $fix remote add origin ($bare.Replace('\', '/'))
        & git -C $fix push origin main --quiet

        # Advance origin via another clone
        $cloneDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        & git clone --quiet ($bare.Replace('\', '/')) $cloneDir
        & git -C $cloneDir config user.name "OtherDev"
        & git -C $cloneDir config user.email "other@example.com"
        Set-Content -LiteralPath (Join-Path $cloneDir 'upstream.txt') -Value 'upstream work'
        & git -C $cloneDir add upstream.txt
        & git -C $cloneDir commit -m "feat: upstream change" --quiet
        & git -C $cloneDir push origin main --quiet

        # Local commits in $fix
        Set-Content -LiteralPath (Join-Path $fix 'local.txt') -Value 'local work'
        & git -C $fix add local.txt
        & git -C $fix commit -m "feat: local change" --quiet

        $headBefore = (& git -C $fix rev-parse HEAD).Trim()
        $notesFile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-notes.md')
        Set-Content -LiteralPath $notesFile -Value "### Added`n- local change`n" -Encoding utf8

        # Run -Apply
        $res = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "P6 test" -Version "1.1.0" -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'Precondition P6 failed'
        $res.Output | Should -Match 'ahead of local'

        # Commit and tag must NOT have been created
        (& git -C $fix rev-parse HEAD).Trim() | Should -Be $headBefore
        (& git -C $fix tag -l 'v1.1.0') | Should -BeNullOrEmpty
        (Get-Content -LiteralPath (Join-Path $fix 'VERSION') -Raw -Encoding utf8).Trim() | Should -Be '1.0.0'
    }
}

Describe 'Invoke-Release.ps1 -Apply push failures and -PushOnly recovery' {
    It 'preserves local commit and tag when push fails, and succeeds on -PushOnly once fixed' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        # Add broken remote
        & git -C $fix remote add origin "file:///C:/nonexistent_broken_origin_dir_xyz123/bare.git"

        Set-Content -LiteralPath (Join-Path $fix 'feature.txt') -Value 'feat'
        & git -C $fix add feature.txt
        & git -C $fix commit -m "feat: push test" --quiet

        $notesFile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-notes.md')
        Set-Content -LiteralPath $notesFile -Value "### Added`n- feat: push test`n" -Encoding utf8

        $res = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "Broken Origin Test" -Version "1.1.0" -SkipChecks
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match "(?s)failed to push to.*'origin'"

        # Commit and tag remain intact!
        (& git -C $fix log -1 --format=%s) | Should -Be "chore(release): v1.1.0"
        (& git -C $fix tag -l 'v1.1.0') | Should -Be "v1.1.0"

        # Now fix origin
        $validBare = New-BareOrigin
        & git -C $fix remote set-url origin ($validBare.Replace('\', '/'))

        # Run -PushOnly
        $resPush = Invoke-ReleasePushOnly -RepoRoot $fix -SkipChecks
        $resPush.ExitCode | Should -Be 0
        $resPush.Output | Should -Match "Successfully pushed"

        # Bare origin received main and tag
        (& git -C $validBare log -1 --format=%s) | Should -Be "chore(release): v1.1.0"
        (& git -C $validBare tag -l 'v1.1.0') | Should -Be "v1.1.0"
    }

    It 'supports -Apply -PushOnly syntax' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        $validBare = New-BareOrigin
        & git -C $fix remote add origin ($validBare.Replace('\', '/'))

        # Prepare a release commit manually
        Set-Content -LiteralPath (Join-Path $fix 'VERSION') -Value "1.1.0`n" -Encoding utf8
        & git -C $fix add VERSION
        & git -C $fix commit -m "chore(release): v1.1.0" --quiet
        & git -C $fix tag -a "v1.1.0" -m "v1.1.0"

        $res = Invoke-ReleasePushOnly -RepoRoot $fix -ApplySwitch -SkipChecks
        $res.ExitCode | Should -Be 0
        (& git -C $validBare tag -l 'v1.1.0') | Should -Be "v1.1.0"
    }
}

Describe 'Invoke-Release.ps1 -Undo rollback behavior' {
    It 'undoes local tag and commit when unpushed' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'feature.txt') -Value 'feat'
        & git -C $fix add feature.txt
        & git -C $fix commit -m "feat: feature to release" --quiet
        $headBeforeRelease = (& git -C $fix rev-parse HEAD).Trim()

        $notesFile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-notes.md')
        Set-Content -LiteralPath $notesFile -Value "### Added`n- feat: feature to release`n" -Encoding utf8

        # Apply locally without remote origin
        $res = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "Undo Me" -Version "1.1.0" -SkipChecks
        $res.ExitCode | Should -Be 0
        (& git -C $fix tag -l 'v1.1.0') | Should -Be 'v1.1.0'
        (& git -C $fix log -1 --format=%s) | Should -Be 'chore(release): v1.1.0'

        # Now undo
        $resUndo = Invoke-ReleaseUndo -RepoRoot $fix
        $resUndo.ExitCode | Should -Be 0

        # Local tag is deleted
        (& git -C $fix tag -l 'v1.1.0') | Should -BeNullOrEmpty

        # HEAD is reset to previous commit
        (& git -C $fix rev-parse HEAD).Trim() | Should -Be $headBeforeRelease

        # VERSION is restored
        (Get-Content -LiteralPath (Join-Path $fix 'VERSION') -Raw -Encoding utf8).Trim() | Should -Be '1.0.0'
    }

    It 'refuses to undo when tag is already on origin' {
        $bare = New-BareOrigin
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        & git -C $fix remote add origin ($bare.Replace('\', '/'))

        Set-Content -LiteralPath (Join-Path $fix 'feature.txt') -Value 'feat'
        & git -C $fix add feature.txt
        & git -C $fix commit -m "feat: feature" --quiet

        $notesFile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-notes.md')
        Set-Content -LiteralPath $notesFile -Value "### Added`n- feat: feature`n" -Encoding utf8

        $res = Invoke-ReleaseApply -RepoRoot $fix -NotesFile $notesFile -Title "Pushed Release" -Version "1.1.0" -SkipChecks
        $res.ExitCode | Should -Be 0

        # Undo must fail because tag is on origin
        $resUndo = Invoke-ReleaseUndo -RepoRoot $fix
        $resUndo.ExitCode | Should -Not -Be 0
        $resUndo.Output | Should -Match "already exists on remote 'origin'"

        # Tag and commit remain
        (& git -C $fix tag -l 'v1.1.0') | Should -Be 'v1.1.0'
        (& git -C $fix log -1 --format=%s) | Should -Be 'chore(release): v1.1.0'
    }

    It 'refuses to undo when HEAD is not a release commit' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'normal.txt') -Value 'normal'
        & git -C $fix add normal.txt
        & git -C $fix commit -m "feat: normal commit" --quiet

        $resUndo = Invoke-ReleaseUndo -RepoRoot $fix
        $resUndo.ExitCode | Should -Not -Be 0
        $resUndo.Output | Should -Match 'HEAD commit is not a release commit'
    }
}

Describe 'Invoke-Release.ps1 code safety inspection' {
    It 'contains no --force or --force-with-lease flags' {
        $scriptContent = Get-Content -LiteralPath $script:ReleaseScript -Raw -Encoding utf8
        $scriptContent | Should -Not -Match '--force\b'
        $scriptContent | Should -Not -Match '--force-with-lease'
    }
}

Describe 'Invoke-Release.ps1 -Notes release notes extraction' {
    It 'returns notes body and title for matching tag and CHANGELOG section' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        # The fixture already creates CHANGELOG with:
        # ## [1.0.0] - 2026-10-01 - Baseline Release
        # ### Added
        # - baseline

        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.0.0'
        $res.ExitCode | Should -Be 0
        $res.Output | Should -Match 'Baseline Release'
        $res.Output | Should -Match 'v1\.0\.0 — Baseline Release'
        $res.Output | Should -Match '### Added'
        $res.Output | Should -Match '- baseline'

        # Default scratch files created
        Test-Path -LiteralPath (Join-Path $fix '.scratch/release/release-notes.md') -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $fix '.scratch/release/release-notes.md') -Raw -Encoding utf8).Trim() | Should -Be "### Added`n- baseline"
        (Get-Content -LiteralPath (Join-Path $fix '.scratch/release/release-title.txt') -Raw -Encoding utf8).Trim() | Should -Be 'v1.0.0 — Baseline Release'
    }

    It 'extracts notes body and title for pre-release tag like -rc.1' {
        $fix = New-ReleaseFixture -InitialVersion '1.1.0-rc.1'
        $rcChangelog = @"
# Changelog

## [Unreleased]

## [1.1.0-rc.1] - 2026-10-02 - Release Candidate 1

### Changed
- rc improvements
"@
        Set-Content -LiteralPath (Join-Path $fix 'CHANGELOG.md') -Value $rcChangelog -Encoding utf8

        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.1.0-rc.1'
        $res.ExitCode | Should -Be 0
        $res.Output | Should -Match 'Release Candidate 1'
        $res.Output | Should -Match 'v1\.1\.0-rc\.1 — Release Candidate 1'
        $res.Output | Should -Match '### Changed'
        $res.Output | Should -Match '- rc improvements'
    }

    It 'extracts only the requested section when multiple sections exist' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        $multiChangelog = @"
# Changelog

## [Unreleased]

## [1.1.0] - 2026-10-05 - Newer Version

### Added
- feature in newer version

## [1.0.0] - 2026-10-01 - Baseline Release

### Added
- baseline feature
"@
        Set-Content -LiteralPath (Join-Path $fix 'CHANGELOG.md') -Value $multiChangelog -Encoding utf8

        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.0.0'
        $res.ExitCode | Should -Be 0
        $res.Output | Should -Match 'Baseline Release'
        $res.Output | Should -Match '- baseline feature'
        $res.Output | Should -Not -Match 'Newer Version'
        $res.Output | Should -Not -Match 'feature in newer version'
    }

    It 'supports custom output file paths via -OutNotesFile and -OutTitleFile' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        $customNotes = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-custom-notes.md')
        $customTitle = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '-custom-title.txt')

        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.0.0' -OutNotesFile $customNotes -OutTitleFile $customTitle
        $res.ExitCode | Should -Be 0

        Test-Path -LiteralPath $customNotes -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath $customNotes -Raw -Encoding utf8).Trim() | Should -Be "### Added`n- baseline"
        Test-Path -LiteralPath $customTitle -PathType Leaf | Should -BeTrue
        (Get-Content -LiteralPath $customTitle -Raw -Encoding utf8).Trim() | Should -Be 'v1.0.0 — Baseline Release'
    }

    It 'fails when tag does not match VERSION file' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'

        # Wrong version number
        $resWrongVer = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.0.1'
        $resWrongVer.ExitCode | Should -Not -Be 0
        $resWrongVer.Output | Should -Match 'does not match VERSION'

        # Missing 'v' prefix
        $resNoV = Invoke-ReleaseNotes -RepoRoot $fix -Tag '1.0.0'
        $resNoV.ExitCode | Should -Not -Be 0
        $resNoV.Output | Should -Match 'does not match VERSION'
    }

    It 'fails when CHANGELOG.md has no section for that version' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Set-Content -LiteralPath (Join-Path $fix 'VERSION') -Value "2.0.0`n" -Encoding utf8

        # CHANGELOG has [1.0.0] but not [2.0.0]
        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v2.0.0'
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'CHANGELOG\.md has no section for version.*\[2\.0\.0\]'
    }

    It 'fails when VERSION file is missing' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Remove-Item -LiteralPath (Join-Path $fix 'VERSION') -Force

        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.0.0'
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'VERSION file not found'
    }

    It 'fails when CHANGELOG.md is missing' {
        $fix = New-ReleaseFixture -InitialVersion '1.0.0'
        Remove-Item -LiteralPath (Join-Path $fix 'CHANGELOG.md') -Force

        $res = Invoke-ReleaseNotes -RepoRoot $fix -Tag 'v1.0.0'
        $res.ExitCode | Should -Not -Be 0
        $res.Output | Should -Match 'CHANGELOG\.md file not found'
    }
}

Describe 'GitHub release workflow inspection' {
    It 'exists and has valid release configuration' {
        $workflowPath = Join-Path $script:TemplateRoot '.github' 'workflows' 'release.yml'
        Test-Path -LiteralPath $workflowPath -PathType Leaf | Should -BeTrue

        $content = Get-Content -LiteralPath $workflowPath -Raw -Encoding utf8

        # Trigger on push of tags v*
        $content | Should -Match '(?m)^\s*push:\s*(\r?\n\s+tags:\s*(\r?\n\s+-\s*[''"]?v\*[''"]?)?)'

        # Explicit write permissions
        $content | Should -Match '(?m)^\s*permissions:\s*(\r?\n\s+contents:\s*write)'

        # Pinned action SHA
        $content | Should -Match 'actions/checkout@[0-9a-f]{40}\s+#\s*v'

        # Calls Invoke-Release.ps1 -Notes
        $content | Should -Match 'Invoke-Release\.ps1\s+-Notes'

        # Pre-release flag when tag matches -rc
        $content | Should -Match '-rc'
        $content | Should -Match '--prerelease'
    }
}


