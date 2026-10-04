#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Tests for CI workflow (.github/workflows/ci.yml), Dependabot, and contributor templates.
# Spec 0002: D9 (CI, PR title, Dependabot, templates).

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:CiWorkflowPath = Join-Path $script:RepoRoot '.github' 'workflows' 'ci.yml'
    $script:DependabotPath = Join-Path $script:RepoRoot '.github' 'dependabot.yml'
    $script:PrTemplatePath = Join-Path $script:RepoRoot '.github' 'PULL_REQUEST_TEMPLATE.md'
    $script:IssueConfigPath = Join-Path $script:RepoRoot '.github' 'ISSUE_TEMPLATE' 'config.yml'
    $script:BugTemplatePath = Join-Path $script:RepoRoot '.github' 'ISSUE_TEMPLATE' 'bug.yml'
    $script:FeatureTemplatePath = Join-Path $script:RepoRoot '.github' 'ISSUE_TEMPLATE' 'feature.yml'
}

Describe 'CI Workflow (.github/workflows/ci.yml)' {
    It 'exists and has read-only contents permission' {
        Test-Path -LiteralPath $script:CiWorkflowPath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $content | Should -Match '(?m)^\s*permissions:\s*(\r?\n\s+contents:\s*read)'
    }

    It 'triggers on push to main and pull_request with required event types' {
        $content = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $content | Should -Match '(?m)^\s*push:\s*(\r?\n\s+branches:\s*(\r?\n\s+-\s*main)?)'
        $content | Should -Match '(?m)^\s*pull_request:'
        $content | Should -Match 'opened'
        $content | Should -Match 'edited'
        $content | Should -Match 'synchronize'
        $content | Should -Match 'reopened'
    }

    It 'pins third-party actions by full SHA and avoids pull_request_target' {
        $content = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $content | Should -Not -Match 'pull_request_target'
        $content | Should -Match 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\s+#\s*v4\.2\.2'
    }

    It 'configures test matrix with Windows and Ubuntu runners' {
        $content = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $content | Should -Match 'windows-latest'
        $content | Should -Match 'ubuntu-latest'
    }

    It 'executes Pester installation, Test-Template.ps1 and Invoke-Pester' {
        $content = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $content | Should -Match 'Install-Module\s+-Name\s+Pester\s+-MinimumVersion\s+5\.0\.0\s+-Force\s+-SkipPublisherCheck'
        $content | Should -Match 'Test-Template\.ps1'
        $content | Should -Match 'Invoke-Pester\s+-Path\s+tests\s+-CI\s+-Output\s+Detailed'
    }

    It 'has pr-title job conditional on pull_request' {
        $content = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $content | Should -Match 'pr-title:'
        $content | Should -Match 'if:\s*github\.event_name\s*==\s*''pull_request'''
    }
}

Describe 'PR Title Validation' {
    BeforeAll {
        $ciContent = Get-Content -LiteralPath $script:CiWorkflowPath -Raw -Encoding utf8
        $match = [regex]::Match($ciContent, '\$pattern\s*=\s*''(?<pat>[^'']+)''')
        $match.Success | Should -BeTrue
        $script:Pattern = $match.Groups['pat'].Value
    }

    It 'extracts a valid Conventional Commits pattern from ci.yml' {
        $script:Pattern | Should -Not -BeNullOrEmpty
    }

    Context 'Valid Conventional Commits titles' {
        It 'matches valid title: <Title>' -ForEach @(
            @{ Title = 'feat: add gitlab mirror support' }
            @{ Title = 'fix: resolve race condition in test runner' }
            @{ Title = 'docs: update README quickstart' }
            @{ Title = 'style: format markdown files' }
            @{ Title = 'refactor: simplify SemVer helper functions' }
            @{ Title = 'perf: cache module discovery' }
            @{ Title = 'test: add unit tests for init-project' }
            @{ Title = 'build: upgrade powershell dependency' }
            @{ Title = 'ci: add github workflows' }
            @{ Title = 'chore: clean up scratch files' }
            @{ Title = 'revert: undo previous release' }
            @{ Title = 'feat(api): support custom endpoints' }
            @{ Title = 'fix(init/core): handle spaces in paths' }
            @{ Title = 'chore(release): v1.0.0' }
            @{ Title = 'feat!: breaking change without scope' }
            @{ Title = 'feat(api)!: breaking change with scope' }
            @{ Title = 'fix(sub-system_01.v2)!: complex valid scope with breaking bang' }
        ) {
            $Title -cmatch $script:Pattern | Should -BeTrue
        }
    }

    Context 'Invalid Conventional Commits titles' {
        It 'rejects invalid title: <Title>' -ForEach @(
            @{ Title = 'Update README.md' }
            @{ Title = 'wip: working on changes' }
            @{ Title = 'feat:' }
            @{ Title = 'feat: ' }
            @{ Title = 'feat:   ' }
            @{ Title = 'feat:x' }
            @{ Title = 'feat(): missing scope body' }
            @{ Title = 'FEAT: uppercase type' }
            @{ Title = 'Fix(core): capitalized type' }
            @{ Title = 'feat(scope with spaces): invalid scope' }
            @{ Title = 'unknown(scope): unsupported type' }
            @{ Title = 'random commit message' }
        ) {
            $Title.Trim() -cmatch $script:Pattern | Should -BeFalse
        }
    }

    Context 'PR Title Script execution' {
        BeforeAll {
            function Test-PrTitleScript([string]$Title) {
                $scriptBlock = {
                    param([string]$T, [string]$Pat)
                    if ([string]::IsNullOrWhiteSpace($T)) { return 1 }
                    $cleanTitle = ($T -replace '\r?\n', ' ').Trim()
                    if ($cleanTitle -cmatch $Pat) { return 0 } else { return 1 }
                }
                return (& $scriptBlock $Title $script:Pattern)
            }
        }

        It 'exits 0 for valid conventional title' {
            Test-PrTitleScript 'feat(scope): valid title' | Should -Be 0
        }

        It 'exits 1 for non-conventional title' {
            Test-PrTitleScript 'bad commit title' | Should -Be 1
        }

        It 'exits 1 for empty title' {
            Test-PrTitleScript '' | Should -Be 1
        }
    }
}

Describe 'Dependabot Configuration (.github/dependabot.yml)' {
    It 'exists and has version 2 with weekly github-actions updates' {
        Test-Path -LiteralPath $script:DependabotPath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:DependabotPath -Raw -Encoding utf8
        $content | Should -Match '(?m)^\s*version:\s*2'
        $content | Should -Match 'package-ecosystem:\s*[''"]?github-actions[''"]?'
        $content | Should -Match 'directory:\s*[''"]?/[''"]?'
        $content | Should -Match 'interval:\s*[''"]?weekly[''"]?'
    }
}

Describe 'Contributor Templates' {
    It 'PR template exists and has all required checklist items' {
        Test-Path -LiteralPath $script:PrTemplatePath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:PrTemplatePath -Raw -Encoding utf8
        $content | Should -Match 'Conventional Commits'
        $content | Should -Match 'Test-Template\.ps1'
        $content | Should -Match 'Invoke-Pester'
        $content | Should -Match 'SKILLS\.md'
        $content | Should -Match 'Sync-ClaudeSkills\.ps1'
        $content | Should -Match 'Description'
    }

    It 'Issue config.yml disables blank issues and links to SECURITY.md' {
        Test-Path -LiteralPath $script:IssueConfigPath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:IssueConfigPath -Raw -Encoding utf8
        $content | Should -Match '(?m)^\s*blank_issues_enabled:\s*false'
        $content | Should -Match 'SECURITY\.md'
        $content | Should -Match 'Security Vulnerability Report'
    }

    It 'Bug report issue form exists with required sections' {
        Test-Path -LiteralPath $script:BugTemplatePath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:BugTemplatePath -Raw -Encoding utf8
        $content | Should -Match 'name:\s*Bug Report'
        $content | Should -Match 'title:\s*[''"]?fix:\s*[''"]?'
        $content | Should -Match 'needs-triage'
        $content | Should -Match 'Bug Description'
        $content | Should -Match 'Steps to Reproduce'
        $content | Should -Match 'Expected Behavior'
        $content | Should -Match 'Environment'
    }

    It 'Feature request issue form exists with required sections' {
        Test-Path -LiteralPath $script:FeatureTemplatePath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:FeatureTemplatePath -Raw -Encoding utf8
        $content | Should -Match 'name:\s*Feature Request'
        $content | Should -Match 'title:\s*[''"]?feat:\s*[''"]?'
        $content | Should -Match 'needs-triage'
        $content | Should -Match 'Problem Statement'
        $content | Should -Match 'Proposed Solution'
    }
}
