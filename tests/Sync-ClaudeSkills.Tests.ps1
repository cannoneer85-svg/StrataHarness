#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Seam B: Sync-ClaudeSkills.ps1 makes .claude/skills/ an exact copy of .agents/skills/.
# Every test runs against a fixture repo in $TestDrive, never against the real repo.

BeforeAll {
    $script:SyncScript = Join-Path $PSScriptRoot '..' '.agents' 'scripts' 'Sync-ClaudeSkills.ps1'

    function New-FixtureRepo {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $files = @{
            '.agents/skills/alpha/SKILL.md'              = "---`nname: alpha`n---`nAlpha body"
            '.agents/skills/alpha/agents/openai.yaml'    = "policy:`n  allow_implicit_invocation: false"
            '.agents/skills/beta/SKILL.md'               = "---`nname: beta`n---`nBeta body"
            '.agents/skills/beta/references/guide.md'    = 'Beta guide'
            '.agents/skills/beta/scripts/run.ps1'        = 'Write-Output beta'
            '.claude/settings.json'                      = '{ "permissions": {} }'
        }
        foreach ($rel in $files.Keys) {
            $path = Join-Path $root $rel
            New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $files[$rel] -NoNewline
        }
        return $root
    }

    # Map of relative path (forward slashes) -> SHA256 for every file under $Dir.
    function Get-TreeSnapshot([string]$Dir) {
        $map = @{}
        if (-not (Test-Path -LiteralPath $Dir)) { return $map }
        $base = (Resolve-Path -LiteralPath $Dir).Path
        Get-ChildItem -LiteralPath $base -Recurse -File -Force | ForEach-Object {
            $rel = [IO.Path]::GetRelativePath($base, $_.FullName) -replace '\\', '/'
            $map[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
        return $map
    }

    function Assert-MirrorMatchesSource([string]$Root) {
        $source = Get-TreeSnapshot (Join-Path $Root '.agents/skills')
        $mirror = Get-TreeSnapshot (Join-Path $Root '.claude/skills')
        ($mirror.Keys | Sort-Object) | Should -Be ($source.Keys | Sort-Object)
        foreach ($key in $source.Keys) {
            $mirror[$key] | Should -Be $source[$key] -Because "file $key must match the source"
        }
    }

    function Invoke-Sync([string]$Root) {
        $output = & $script:SyncScript -RepoRoot $Root 6>&1 | Out-String
        return $output
    }
}

Describe 'Sync-ClaudeSkills.ps1' {
    It 'creates a full copy when the mirror does not exist' {
        $root = New-FixtureRepo

        Invoke-Sync $root | Out-Null

        $mirror = Get-TreeSnapshot (Join-Path $root '.claude/skills')
        $mirror.Keys | Should -Contain 'alpha/SKILL.md'
        $mirror.Keys | Should -Contain 'alpha/agents/openai.yaml'
        $mirror.Keys | Should -Contain 'beta/references/guide.md'
        $mirror.Keys | Should -Contain 'beta/scripts/run.ps1'
        Assert-MirrorMatchesSource $root
    }

    It 'updates a file that changed in the source' {
        $root = New-FixtureRepo
        Invoke-Sync $root | Out-Null

        Set-Content -LiteralPath (Join-Path $root '.agents/skills/beta/references/guide.md') -Value 'Beta guide v2' -NoNewline
        Invoke-Sync $root | Out-Null

        Get-Content -LiteralPath (Join-Path $root '.claude/skills/beta/references/guide.md') -Raw | Should -Be 'Beta guide v2'
        Assert-MirrorMatchesSource $root
    }

    It 'removes from the mirror a skill deleted from the source' {
        $root = New-FixtureRepo
        Invoke-Sync $root | Out-Null

        Remove-Item -LiteralPath (Join-Path $root '.agents/skills/beta') -Recurse -Force
        Invoke-Sync $root | Out-Null

        Test-Path -LiteralPath (Join-Path $root '.claude/skills/beta') | Should -BeFalse
        Assert-MirrorMatchesSource $root
    }

    It 'removes a stray file that exists only in the mirror' {
        $root = New-FixtureRepo
        Invoke-Sync $root | Out-Null

        Set-Content -LiteralPath (Join-Path $root '.claude/skills/alpha/stale.md') -Value 'stale'
        Invoke-Sync $root | Out-Null

        Test-Path -LiteralPath (Join-Path $root '.claude/skills/alpha/stale.md') | Should -BeFalse
        Assert-MirrorMatchesSource $root
    }

    It 'reports added, updated and removed counts' {
        $root = New-FixtureRepo

        Invoke-Sync $root | Should -Match 'added 5, updated 0, removed 0'

        Set-Content -LiteralPath (Join-Path $root '.agents/skills/alpha/SKILL.md') -Value 'Alpha v2' -NoNewline
        Remove-Item -LiteralPath (Join-Path $root '.agents/skills/beta') -Recurse -Force
        Invoke-Sync $root | Should -Match 'added 0, updated 1, removed 3'
    }

    It 'changes nothing on a repeated run' {
        $root = New-FixtureRepo
        Invoke-Sync $root | Out-Null
        $mirrorDir = Join-Path $root '.claude/skills'
        # Stamp every mirror file: a rewrite would replace the stamp.
        $stamp = [datetime]::new(2000, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        Get-ChildItem -LiteralPath $mirrorDir -Recurse -File | ForEach-Object { $_.LastWriteTimeUtc = $stamp }

        Invoke-Sync $root | Should -Match 'added 0, updated 0, removed 0'

        Get-ChildItem -LiteralPath $mirrorDir -Recurse -File | ForEach-Object {
            $_.LastWriteTimeUtc | Should -Be $stamp -Because "$($_.Name) must not be rewritten"
        }
        Assert-MirrorMatchesSource $root
    }

    It 'does not touch files outside .claude/skills/' {
        $root = New-FixtureRepo
        Set-Content -LiteralPath (Join-Path $root 'README.md') -Value 'readme'
        New-Item -ItemType Directory -Path (Join-Path $root '.claude/commands') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root '.claude/commands/hello.md') -Value 'hello'
        $outsideBefore = Get-TreeSnapshot $root
        $outsideBefore.Keys.Where({ $_ -like '.claude/skills/*' }) | Should -BeNullOrEmpty

        Invoke-Sync $root | Out-Null
        Remove-Item -LiteralPath (Join-Path $root '.agents/skills/beta') -Recurse -Force
        $outsideBefore.Keys.Where({ $_ -like '.agents/skills/beta/*' }) | ForEach-Object { $outsideBefore.Remove($_) }
        Invoke-Sync $root | Out-Null

        $after = Get-TreeSnapshot $root
        foreach ($key in @($after.Keys)) { if ($key -like '.claude/skills/*') { $after.Remove($key) } }
        ($after.Keys | Sort-Object) | Should -Be ($outsideBefore.Keys | Sort-Object)
        foreach ($key in $outsideBefore.Keys) {
            $after[$key] | Should -Be $outsideBefore[$key] -Because "$key is outside the mirror"
        }
    }

    It 'resolves the repo root relative to the script when -RepoRoot is omitted' {
        $root = New-FixtureRepo
        $scriptsDir = Join-Path $root '.agents/scripts'
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Copy-Item -LiteralPath $script:SyncScript -Destination $scriptsDir

        & (Join-Path $scriptsDir 'Sync-ClaudeSkills.ps1') | Should -Match 'added 5, updated 0, removed 0'

        Assert-MirrorMatchesSource $root
    }
}
