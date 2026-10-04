<#
.SYNOPSIS
    Template release automation script (spec 0002 D3, ADR 0005).

.DESCRIPTION
    Automates the Template release workflow.
    Modes:
      -Plan      - Verifies preconditions P1–P5, inspects Conventional Commits since the last tag,
                   detects MAJOR candidate flags, computes the proposed next SemVer (or accepts -Bump / -Version),
                   and writes .scratch/release/plan.json and .scratch/release/notes.draft.md.
                   Does NOT commit, tag, or modify tracked files.
      -Apply     - Creates release commit, tag, and atomic push to origin.
      -PushOnly  - Re-attempts push when initial push failed.
      -Undo      - Removes local unpushed release commit and tag.
      -Notes     - Extracts release notes and title for GitHub Release creation in CI.

.PARAMETER Plan
    Runs in plan mode: generates release plan and draft notes without touching tracked files.

.PARAMETER Bump
    Overrides the computed bump type ('major', 'minor', 'patch').

.PARAMETER Version
    Overrides the target version with an exact SemVer string (e.g. '1.0.0' or '1.1.0-rc.1').

.PARAMETER Apply
    Runs in apply mode: commits, tags, and pushes the release.

.PARAMETER NotesFile
    Path to the finalized release notes file for -Apply.

.PARAMETER Title
    Release title for -Apply and the annotated git tag.

.PARAMETER PushOnly
    Re-attempts push of already created release commit and tag.

.PARAMETER Undo
    Rolls back an unpushed local release commit and tag.

.PARAMETER Notes
    Target tag (e.g. 'v1.0.0') whose notes and title should be extracted from CHANGELOG.md and printed.

.PARAMETER OutNotesFile
    Optional file path to write extracted markdown notes body to.

.PARAMETER OutTitleFile
    Optional file path to write extracted release title to.

.PARAMETER RepoRoot
    Path to the target repository root. Defaults to the repository containing this script.

.PARAMETER SkipChecks
    Skips the P3 precondition (Test-Template.ps1 and Pester tests). Useful for testing.

.EXAMPLE
    Invoke-Release.ps1 -Plan
    Invoke-Release.ps1 -Plan -Bump minor
    Invoke-Release.ps1 -Plan -Version 1.0.0
    Invoke-Release.ps1 -Apply -NotesFile .scratch/release/notes.draft.md -Title "Initial Release"
    Invoke-Release.ps1 -Apply -PushOnly
    Invoke-Release.ps1 -Undo
    Invoke-Release.ps1 -Notes v1.0.0
#>

[CmdletBinding(DefaultParameterSetName = 'Plan')]
param(
    # Plan mode
    [Parameter(ParameterSetName = 'Plan')]
    [switch]$Plan,

    [Parameter(ParameterSetName = 'Plan')]
    [ValidateSet('major', 'minor', 'patch', IgnoreCase = $true)]
    [string]$Bump,

    # Version can be used in Plan, Apply, PushOnly, Undo
    [Parameter(ParameterSetName = 'Plan')]
    [Parameter(ParameterSetName = 'Apply')]
    [Parameter(ParameterSetName = 'PushOnly')]
    [Parameter(ParameterSetName = 'Undo')]
    [string]$Version,

    # Apply mode
    [Parameter(ParameterSetName = 'Apply', Mandatory)]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Apply')]
    [string]$NotesFile,

    [Parameter(ParameterSetName = 'Apply')]
    [string]$Title,

    [Parameter(ParameterSetName = 'Apply')]
    [Parameter(ParameterSetName = 'PushOnly', Mandatory)]
    [switch]$PushOnly,

    # Undo mode
    [Parameter(ParameterSetName = 'Undo', Mandatory)]
    [switch]$Undo,

    # Notes mode
    [Parameter(ParameterSetName = 'Notes', Mandatory)]
    [string]$Notes,

    [Parameter(ParameterSetName = 'Notes')]
    [string]$OutNotesFile,

    [Parameter(ParameterSetName = 'Notes')]
    [string]$OutTitleFile,

    # Common parameters
    [Parameter()]
    [string]$RepoRoot,

    [Parameter()]
    [switch]$SkipChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail-Precondition([string]$Rule, [string]$Message) {
    $err = "Precondition $Rule failed: $Message"
    Write-Error $err
    exit 1
}

function Fail-Notes([string]$Message) {
    $err = "Notes error: $Message"
    Write-Error $err
    exit 1
}

# Resolve repository root
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

# Load shared SemVer helpers
$semVerScript = Join-Path $RepoRoot '.agents' 'scripts' 'SemVer.ps1'
if (Test-Path -LiteralPath $semVerScript -PathType Leaf) {
    . $semVerScript
} else {
    throw "Required SemVer helpers not found: '$semVerScript'."
}

function Assert-CleanWorkingTree {
    $gitStatus = & git -C $RepoRoot status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to run 'git status' in '$RepoRoot': $gitStatus"
    }
    if (-not [string]::IsNullOrWhiteSpace($gitStatus)) {
        Fail-Precondition 'P1' "Working tree is dirty. Stash or commit changes before releasing."
    }
}

function Assert-MainBranch {
    $currentBranch = (& git -C $RepoRoot branch --show-current 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get current branch in '$RepoRoot': $currentBranch"
    }
    $currentBranch = ([string]$currentBranch).Trim()
    if ($currentBranch -ne 'main') {
        Fail-Precondition 'P2' "Current branch is '$currentBranch'; releases must be made from 'main'."
    }
}

function Assert-TestsAndChecks {
    $shouldSkipChecks = $SkipChecks -or ($env:RELEASE_SKIP_CHECKS -eq '1')
    if (-not $shouldSkipChecks) {
        $testTemplateScript = Join-Path $RepoRoot '.agents' 'scripts' 'Test-Template.ps1'
        if (Test-Path -LiteralPath $testTemplateScript -PathType Leaf) {
            $ttOutput = & pwsh -NoProfile -File $testTemplateScript 2>&1
            if ($LASTEXITCODE -ne 0) {
                Fail-Precondition 'P3' "Test-Template.ps1 failed:`n$($ttOutput -join "`n")"
            }
        }

        $testsDir = Join-Path $RepoRoot 'tests'
        if (Test-Path -LiteralPath $testsDir -PathType Container) {
            $pesterOutput = & pwsh -NoProfile -Command "Invoke-Pester -Path '$testsDir' -Output None" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Fail-Precondition 'P3' "Pester test suite failed."
            }
        }
    }
}

function Invoke-Plan {
    if (-not [string]::IsNullOrWhiteSpace($Bump) -and -not [string]::IsNullOrWhiteSpace($Version)) {
        throw "Cannot specify both -Bump and -Version."
    }

    # --- Preconditions P1 - P3 ---------------------------------------------------------
    Assert-CleanWorkingTree
    Assert-MainBranch
    Assert-TestsAndChecks

    # --- Find previous tag --------------------------------------------------------------
    $prevTag = $null
    $tagResult = & git -C $RepoRoot describe --tags --abbrev=0 --match="v*" 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($tagResult)) {
        $prevTag = ([string]$tagResult).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($prevTag)) {
        $tagResultAny = & git -C $RepoRoot describe --tags --abbrev=0 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($tagResultAny)) {
            $prevTag = ([string]$tagResultAny).Trim()
        }
    }

    # --- Precondition P4 & Commit collection --------------------------------------------
    $logArgs = @('-C', $RepoRoot, 'log', '--reverse', '--format=%H%x1f%s%x1f%b%x1e')
    if ($prevTag) {
        $logArgs += "$prevTag..HEAD"
    } else {
        $logArgs += 'HEAD'
    }

    $rawLogLines = & git @logArgs 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $rawLogLines) {
        Fail-Precondition 'P4' "No commits found since last tag '$prevTag' (or repository has no commits)."
    }

    $rawLog = ($rawLogLines -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($rawLog)) {
        Fail-Precondition 'P4' "No commits found since last tag '$prevTag' (or repository has no commits)."
    }

    $commitRecords = @($rawLog -split [char]0x1e | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($commitRecords.Count -eq 0) {
        Fail-Precondition 'P4' "No commits found since last tag '$prevTag'."
    }

    # Conventional commit parsing
    $knownTypes = @('feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore', 'revert')
    $ccPattern = '^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)\r\n]+)\))?(?<breaking>!)?:\s+(?<desc>.*)$'

    $commits = [System.Collections.Generic.List[PSObject]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($rec in $commitRecords) {
        $parts = @($rec -split [char]0x1f, 3)
        $sha = $parts[0].Trim()
        $subject = if ($parts.Length -gt 1) { $parts[1].Trim() } else { '' }
        $body = if ($parts.Length -gt 2) { $parts[2].Trim() } else { '' }
        $shortSha = if ($sha.Length -ge 7) { $sha.Substring(0, 7) } else { $sha }

        $match = [regex]::Match($subject, $ccPattern)
        $isConventional = $false
        $type = $null
        $scope = $null
        $hasBang = $false

        if ($match.Success) {
            $candidateType = $match.Groups['type'].Value.ToLowerInvariant()
            if ($candidateType -in $knownTypes) {
                $isConventional = $true
                $type = $candidateType
                $scope = if ($match.Groups['scope'].Success) { $match.Groups['scope'].Value } else { $null }
                $hasBang = $match.Groups['breaking'].Success
            }
        }

        $hasBreakingFooter = ($body -match '(?m)^BREAKING[\s-]CHANGE:\s*') -or ($subject -match '\bBREAKING[\s-]CHANGE:')
        $isBreaking = $hasBang -or $hasBreakingFooter

        if (-not $isConventional) {
            $warnings.Add("Non-conventional commit in $($shortSha): '$subject'")
        }

        # Assign CHANGELOG section
        $section = if ($isBreaking) {
            'Breaking'
        } elseif (-not $isConventional) {
            'Other'
        } elseif ($type -eq 'feat') {
            'Added'
        } elseif ($type -eq 'fix') {
            'Fixed'
        } elseif ($type -in @('refactor', 'perf')) {
            'Changed'
        } elseif ($type -in @('revert')) {
            'Removed'
        } else {
            'Other'
        }

        # Bump vote
        $vote = if ($isBreaking) {
            'major'
        } elseif ($type -eq 'feat') {
            'minor'
        } else {
            'patch'
        }

        $commits.Add([pscustomobject]@{
            Sha            = $sha
            ShortSha       = $shortSha
            Subject        = $subject
            Body           = $body
            Type           = $type
            Scope          = $scope
            IsBreaking     = $isBreaking
            IsConventional = $isConventional
            Section        = $section
            BumpVote       = $vote
        })
    }

    # --- Check for deleted or renamed skill directories (MAJOR candidate) ----------------
    $majorCandidate = $false
    $majorCandidateReasons = [System.Collections.Generic.List[string]]::new()
    $deletedSkillFolders = [System.Collections.Generic.HashSet[string]]::new()

    $diffArgs = @('-C', $RepoRoot, 'diff', '--diff-filter=DR', '--name-status')
    if ($prevTag) {
        $diffArgs += $prevTag
        $diffArgs += 'HEAD'
    } else {
        $diffArgs += '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
        $diffArgs += 'HEAD'
    }
    $diffArgs += '--'
    $diffArgs += '.agents/skills'

    $diffLines = & git @diffArgs 2>$null
    if ($LASTEXITCODE -eq 0 -and $diffLines) {
        foreach ($line in $diffLines) {
            if ($line -match '^[DR]\d*\s+(?<path>\S+)') {
                $path = $Matches['path'].Replace('\', '/')
                if ($path -match '^\.agents/skills/(?<skill>[^/]+)/') {
                    $skillName = $Matches['skill']
                    $existsInHead = & git -C $RepoRoot ls-tree -d --name-only HEAD ".agents/skills/$skillName" 2>$null
                    if ([string]::IsNullOrWhiteSpace($existsInHead)) {
                        $deletedSkillFolders.Add($skillName) | Out-Null
                    }
                }
            }
        }
    }

    # Tree comparison check if previous tag exists
    if ($prevTag) {
        $prevSkills = @(& git -C $RepoRoot ls-tree -d --name-only $prevTag .agents/skills 2>$null)
        $headSkills = @(& git -C $RepoRoot ls-tree -d --name-only HEAD .agents/skills 2>$null)
        foreach ($ps in $prevSkills) {
            $folderName = Split-Path -Leaf ([string]$ps).Trim()
            if (-not [string]::IsNullOrWhiteSpace($folderName)) {
                $stillInHead = $headSkills | Where-Object { (Split-Path -Leaf ([string]$_).Trim()) -eq $folderName }
                if (-not $stillInHead) {
                    $deletedSkillFolders.Add($folderName) | Out-Null
                }
            }
        }
    }

    foreach ($skillName in $deletedSkillFolders) {
        $majorCandidate = $true
        $reason = "Skill folder '$skillName' under '.agents/skills/' was deleted or renamed."
        $majorCandidateReasons.Add($reason)
        $warnings.Add("MAJOR candidate: $reason")
    }

    # --- Calculate proposed bump -------------------------------------------------------
    $hasMajorVote = @($commits | Where-Object { $_.BumpVote -eq 'major' }).Count -gt 0
    $hasMinorVote = @($commits | Where-Object { $_.BumpVote -eq 'minor' }).Count -gt 0

    $proposedBump = if ($hasMajorVote) {
        'major'
    } elseif ($hasMinorVote) {
        'minor'
    } else {
        'patch'
    }

    # Determine base version
    $baseVersion = $null
    $versionFilePath = Join-Path $RepoRoot 'VERSION'
    if (Test-Path -LiteralPath $versionFilePath -PathType Leaf) {
        $vContent = (Get-Content -LiteralPath $versionFilePath -Raw -Encoding utf8).Trim()
        if (Test-SemVer $vContent) {
            $baseVersion = $vContent
        }
    }
    if (-not $baseVersion -and $prevTag) {
        $tagTrimmed = $prevTag.TrimStart('v')
        if (Test-SemVer $tagTrimmed) {
            $baseVersion = $tagTrimmed
        }
    }
    if (-not $baseVersion) {
        $baseVersion = '0.0.0'
    }

    # Determine target version and effective bump
    $bumpSource = 'conventional'
    $effectiveBump = $proposedBump

    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $targetVersion = $Version.Trim()
        if ($targetVersion.StartsWith('v')) {
            $targetVersion = $targetVersion.Substring(1)
        }
        if (-not (Test-SemVer $targetVersion)) {
            throw "Invalid version '$Version': expected X.Y.Z or X.Y.Z-rc.N."
        }
        $bumpSource = 'override-version'
    } elseif (-not [string]::IsNullOrWhiteSpace($Bump)) {
        $effectiveBump = $Bump.ToLowerInvariant()
        $bumpSource = 'override-bump'
        $targetVersion = Step-SemVer -Version $baseVersion -Bump $effectiveBump
    } else {
        $targetVersion = Step-SemVer -Version $baseVersion -Bump $effectiveBump
    }

    $targetTag = "v$targetVersion"

    # --- Precondition P5: Target tag does not already exist -----------------------------
    $existingTag = & git -C $RepoRoot tag -l $targetTag 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingTag)) {
        Fail-Precondition 'P5' "Target tag '$targetTag' already exists."
    }

    # --- Prepare Sections for notes.draft.md and plan.json ------------------------------
    $sectionsDict = [ordered]@{}
    foreach ($sec in @('Breaking', 'Added', 'Changed', 'Fixed', 'Removed', 'Other')) {
        $secCommits = @($commits | Where-Object { $_.Section -eq $sec })
        if ($secCommits.Count -gt 0) {
            $sectionsDict[$sec] = @($secCommits | ForEach-Object { "- $($_.Subject)" })
        }
    }

    $notesLines = [System.Collections.Generic.List[string]]::new()
    foreach ($sec in $sectionsDict.Keys) {
        $notesLines.Add("### $sec")
        foreach ($item in $sectionsDict[$sec]) {
            $notesLines.Add($item)
        }
        $notesLines.Add("")
    }
    $notesContent = ($notesLines -join "`n").TrimEnd() + "`n"

    $headSha = (& git -C $RepoRoot rev-parse HEAD).Trim()

    $releaseScratchDir = Join-Path $RepoRoot '.scratch' 'release'
    if (-not (Test-Path -LiteralPath $releaseScratchDir -PathType Container)) {
        New-Item -ItemType Directory -Path $releaseScratchDir | Out-Null
    }

    $planJsonPath = Join-Path $releaseScratchDir 'plan.json'
    $notesDraftPath = Join-Path $releaseScratchDir 'notes.draft.md'

    $planData = [ordered]@{
        TargetVersion         = $targetVersion
        TargetTag             = $targetTag
        PreviousVersion       = $baseVersion
        PreviousTag           = $prevTag
        HeadSha               = $headSha
        BumpType              = $effectiveBump
        ProposedBump          = $proposedBump
        BumpSource            = $bumpSource
        MajorCandidate        = $majorCandidate
        MajorCandidateReasons = @($majorCandidateReasons)
        Warnings              = @($warnings)
        Commits               = @(
            $commits | ForEach-Object {
                [ordered]@{
                    Sha            = $_.Sha
                    ShortSha       = $_.ShortSha
                    Subject        = $_.Subject
                    Type           = $_.Type
                    Scope          = $_.Scope
                    IsBreaking     = $_.IsBreaking
                    IsConventional = $_.IsConventional
                    Section        = $_.Section
                    BumpVote       = $_.BumpVote
                }
            }
        )
        Sections              = $sectionsDict
        NotesDraftPath        = [System.IO.Path]::GetRelativePath($RepoRoot, $notesDraftPath).Replace('\', '/')
        CreatedAt             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    $planJsonContent = $planData | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $planJsonPath -Value $planJsonContent -Encoding utf8
    Set-Content -LiteralPath $notesDraftPath -Value $notesContent -Encoding utf8

    Write-Output "Release Plan:"
    Write-Output "  Target Version : $targetVersion ($targetTag)"
    Write-Output "  Previous Tag   : $(if ($prevTag) { $prevTag } else { 'none' })"
    Write-Output "  Bump Type      : $effectiveBump (source: $bumpSource, proposed: $proposedBump)"
    Write-Output "  Major Candidate: $majorCandidate"
    if ($majorCandidateReasons.Count -gt 0) {
        foreach ($r in $majorCandidateReasons) {
            Write-Output "    - $r"
        }
    }
    if ($warnings.Count -gt 0) {
        Write-Output "  Warnings       :"
        foreach ($w in $warnings) {
            Write-Output "    - $w"
        }
    }
    Write-Output "  Commits parsed : $($commits.Count)"
    Write-Output "  Plan written   : $planJsonPath"
    Write-Output "  Notes draft    : $notesDraftPath"

    exit 0
}

function Invoke-Apply {
    if ([string]::IsNullOrWhiteSpace($NotesFile)) {
        throw "Parameter -NotesFile is required for -Apply."
    }
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "Parameter -Title is required for -Apply."
    }

    $resolvedNotesFile = if ([System.IO.Path]::IsPathRooted($NotesFile)) {
        $NotesFile
    } else {
        Join-Path $RepoRoot $NotesFile
    }
    if (-not (Test-Path -LiteralPath $resolvedNotesFile -PathType Leaf)) {
        throw "Notes file not found: '$NotesFile' (resolved to '$resolvedNotesFile')."
    }
    $notesContent = Get-Content -LiteralPath $resolvedNotesFile -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($notesContent)) {
        throw "Notes file '$NotesFile' is empty."
    }

    # P1: Clean working tree
    Assert-CleanWorkingTree

    # P2: On branch main
    Assert-MainBranch

    # P3: Tests and validators pass
    Assert-TestsAndChecks

    # Verify plan HEAD if plan.json exists
    $planJsonPath = Join-Path $RepoRoot '.scratch' 'release' 'plan.json'
    $planObj = $null
    if (Test-Path -LiteralPath $planJsonPath -PathType Leaf) {
        try {
            $planObj = (Get-Content -LiteralPath $planJsonPath -Raw -Encoding utf8) | ConvertFrom-Json
        } catch {
            $planObj = $null
        }
    }

    $currentHeadSha = (& git -C $RepoRoot rev-parse HEAD 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get current HEAD commit in '$RepoRoot': $currentHeadSha"
    }
    $currentHeadSha = ([string]$currentHeadSha).Trim()

    if ($planObj -and $planObj.PSObject.Properties['HeadSha'] -and -not [string]::IsNullOrWhiteSpace($planObj.HeadSha)) {
        $expectedHead = [string]$planObj.HeadSha.Trim()
        if ($currentHeadSha -ne $expectedHead) {
            Fail-Precondition 'HEAD' "HEAD has changed since release plan was generated (was $expectedHead, now $currentHeadSha). Please re-run -Plan."
        }
    }

    # Determine target version
    $targetVer = $null
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $targetVer = $Version.Trim()
    } elseif ($planObj -and $planObj.PSObject.Properties['TargetVersion']) {
        $targetVer = [string]$planObj.TargetVersion
    } else {
        throw "Target version must be specified via -Version or via existing .scratch/release/plan.json."
    }

    if ($targetVer.StartsWith('v')) {
        $targetVer = $targetVer.Substring(1)
    }
    if (-not (Test-SemVer $targetVer)) {
        throw "Invalid target version '$targetVer': expected X.Y.Z or X.Y.Z-rc.N."
    }
    $targetTag = "v$targetVer"

    # P5: Target tag does not already exist locally
    $existingTag = & git -C $RepoRoot tag -l $targetTag 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingTag)) {
        Fail-Precondition 'P5' "Target tag '$targetTag' already exists locally."
    }

    # Remote origin checks & P6
    $remotes = & git -C $RepoRoot remote 2>$null
    $hasOrigin = ($LASTEXITCODE -eq 0) -and ($remotes -split "`r?`n" | Where-Object { $_.Trim() -eq 'origin' })
    if ($hasOrigin) {
        # Tag on remote check
        $remoteTag = & git -C $RepoRoot ls-remote --tags origin $targetTag 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteTag)) {
            Fail-Precondition 'P5' "Target tag '$targetTag' already exists on remote 'origin'."
        }

        # Fetch origin
        & git -C $RepoRoot fetch origin 2>$null

        # P6: origin/main ahead check
        $originMainRef = & git -C $RepoRoot rev-parse --verify origin/main 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($originMainRef)) {
            $behindCountStr = (& git -C $RepoRoot rev-list --count main..origin/main 2>$null)
            $behindCount = 0
            if ([int]::TryParse(($behindCountStr -join '').Trim(), [ref]$behindCount) -and $behindCount -gt 0) {
                Fail-Precondition 'P6' "Remote 'origin/main' is ahead of local 'main' by $behindCount commit(s). Pull or rebase before releasing."
            }
        }
    }

    # Update VERSION
    $versionFilePath = Join-Path $RepoRoot 'VERSION'
    Set-Content -LiteralPath $versionFilePath -Value "$targetVer`n" -Encoding utf8 -NoNewline

    # Update CHANGELOG.md
    $changelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
    if (Test-Path -LiteralPath $changelogPath -PathType Leaf) {
        $changelogContent = Get-Content -LiteralPath $changelogPath -Raw -Encoding utf8
        $releaseDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
        $releaseHeader = "## [$targetVer] - $releaseDate - $Title"
        $trimmedNotes = $notesContent.Trim()
        $newReleaseBlock = "$releaseHeader`n`n$trimmedNotes`n"

        if ($changelogContent -match '(?m)^##\s+\[Unreleased\]') {
            $changelogContent = [regex]::Replace(
                $changelogContent,
                '(?m)^##\s+\[Unreleased\](\r?\n)*',
                "## [Unreleased]`n`n$newReleaseBlock`n"
            )
        } else {
            $changelogContent = "## [Unreleased]`n`n$newReleaseBlock`n" + $changelogContent
        }
        Set-Content -LiteralPath $changelogPath -Value $changelogContent -Encoding utf8 -NoNewline
    } else {
        throw "Required changelog file not found: '$changelogPath'."
    }

    # Update .agents/SKILLS.md
    $skillsMdPath = Join-Path $RepoRoot '.agents' 'SKILLS.md'
    if (Test-Path -LiteralPath $skillsMdPath -PathType Leaf) {
        $skillsContent = Get-Content -LiteralPath $skillsMdPath -Raw -Encoding utf8
        $newSkillsContent = [regex]::Replace(
            $skillsContent,
            '(?m)^-\s*\*\*template-version:\*\*.*$',
            "- **template-version:** ``v$targetVer``"
        )
        Set-Content -LiteralPath $skillsMdPath -Value $newSkillsContent -Encoding utf8 -NoNewline
    } else {
        throw "Required registry file not found: '$skillsMdPath'."
    }

    # Create release commit containing only VERSION, CHANGELOG.md, .agents/SKILLS.md
    & git -C $RepoRoot add -- VERSION CHANGELOG.md .agents/SKILLS.md
    $commitOut = & git -C $RepoRoot commit -m "chore(release): v$targetVer" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create release commit: $commitOut"
    }
    $releaseCommitSha = (& git -C $RepoRoot rev-parse HEAD).Trim()

    # Create annotated tag
    $tagOut = & git -C $RepoRoot tag -a $targetTag -m $Title 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create annotated tag '$targetTag': $tagOut"
    }

    # Push to origin atomically if origin is configured
    if ($hasOrigin) {
        $pushOut = & git -C $RepoRoot push --atomic origin main $targetTag 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Release commit $releaseCommitSha ($targetTag) created locally, but failed to push to 'origin':`n$($pushOut -join "`n")"
            exit 1
        }
        Write-Output "Successfully released and pushed $targetTag ($releaseCommitSha) to origin."
    } else {
        Write-Output "Successfully created local release $targetTag ($releaseCommitSha). Remote 'origin' not configured; push skipped."
    }

    exit 0
}

function Invoke-PushOnly {
    Assert-CleanWorkingTree
    Assert-MainBranch

    $remotes = & git -C $RepoRoot remote 2>$null
    $hasOrigin = ($LASTEXITCODE -eq 0) -and ($remotes -split "`r?`n" | Where-Object { $_.Trim() -eq 'origin' })
    if (-not $hasOrigin) {
        throw "Remote 'origin' is not configured."
    }

    $targetVer = $null
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $targetVer = $Version.Trim()
        if ($targetVer.StartsWith('v')) {
            $targetVer = $targetVer.Substring(1)
        }
    } else {
        # Detect from HEAD tag
        $headTags = & git -C $RepoRoot tag --points-at HEAD 2>$null
        if ($headTags) {
            $matchingTag = $headTags | Where-Object { $_ -match '^v\d+\.\d+\.\d+' } | Select-Object -First 1
            if ($matchingTag) {
                $targetVer = $matchingTag.Trim().TrimStart('v')
            }
        }
        if (-not $targetVer) {
            $headSubject = (& git -C $RepoRoot log -1 --format=%s 2>&1)
            if ($headSubject -match '^chore\(release\):\s*v(?<ver>[0-9A-Za-z\.-]+)$') {
                $targetVer = $Matches['ver']
            }
        }
        if (-not $targetVer) {
            $versionFilePath = Join-Path $RepoRoot 'VERSION'
            if (Test-Path -LiteralPath $versionFilePath -PathType Leaf) {
                $vCandidate = (Get-Content -LiteralPath $versionFilePath -Raw -Encoding utf8).Trim()
                if (Test-SemVer $vCandidate) {
                    $targetVer = $vCandidate
                }
            }
        }
    }

    if (-not $targetVer -or -not (Test-SemVer $targetVer)) {
        throw "Unable to determine release version to push. Provide -Version or ensure HEAD is a release commit."
    }

    $targetTag = "v$targetVer"

    # Verify tag exists locally
    $tagExists = & git -C $RepoRoot tag -l $targetTag 2>$null
    if ([string]::IsNullOrWhiteSpace($tagExists)) {
        throw "Tag '$targetTag' does not exist locally."
    }

    # Fetch origin
    & git -C $RepoRoot fetch origin 2>$null

    # P6 check
    $originMainRef = & git -C $RepoRoot rev-parse --verify origin/main 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($originMainRef)) {
        $behindCountStr = (& git -C $RepoRoot rev-list --count main..origin/main 2>$null)
        $behindCount = 0
        if ([int]::TryParse(($behindCountStr -join '').Trim(), [ref]$behindCount) -and $behindCount -gt 0) {
            Fail-Precondition 'P6' "Remote 'origin/main' is ahead of local 'main' by $behindCount commit(s). Pull or rebase before pushing."
        }
    }

    $pushOut = & git -C $RepoRoot push --atomic origin main $targetTag 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push to 'origin':`n$($pushOut -join "`n")"
        exit 1
    }

    Write-Output "Successfully pushed main and $targetTag to origin."
    exit 0
}

function Invoke-Undo {
    Assert-CleanWorkingTree

    # Check HEAD commit
    $headSubject = (& git -C $RepoRoot log -1 --format=%s 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get HEAD commit: $headSubject"
    }
    $headSubject = ([string]$headSubject).Trim()
    $match = [regex]::Match($headSubject, '^chore\(release\):\s*v(?<ver>[0-9A-Za-z\.-]+)$')
    if (-not $match.Success) {
        throw "HEAD commit is not a release commit ('$headSubject'). -Undo can only undo a chore(release) commit."
    }
    $cleanVersion = $match.Groups['ver'].Value
    if (-not (Test-SemVer $cleanVersion)) {
        throw "Version '$cleanVersion' in HEAD commit subject is not a valid SemVer."
    }
    $targetTag = "v$cleanVersion"

    # Check tag points to HEAD
    $headSha = (& git -C $RepoRoot rev-parse HEAD 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get HEAD sha: $headSha"
    }
    $headSha = ([string]$headSha).Trim()

    $tagCommitSha = (& git -C $RepoRoot rev-list -n 1 $targetTag 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tagCommitSha) -or ($tagCommitSha.Trim() -ne $headSha)) {
        throw "Tag '$targetTag' does not exist or does not point to HEAD commit ($headSha)."
    }

    # If origin configured, check if tag exists on remote
    $remotes = & git -C $RepoRoot remote 2>$null
    $hasOrigin = ($LASTEXITCODE -eq 0) -and ($remotes -split "`r?`n" | Where-Object { $_.Trim() -eq 'origin' })
    if ($hasOrigin) {
        $remoteTag = & git -C $RepoRoot ls-remote --tags origin $targetTag 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteTag)) {
            throw "Tag '$targetTag' already exists on remote 'origin'. Published history cannot be undone."
        }
    }

    # Delete local tag
    $delTagOut = & git -C $RepoRoot tag -d $targetTag 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete local tag '$targetTag': $delTagOut"
    }

    # Reset commit
    $resetOut = & git -C $RepoRoot reset --hard HEAD~1 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to reset release commit: $resetOut"
    }

    Write-Output "Successfully undone release ${targetTag}: deleted local tag and reset HEAD."
    exit 0
}

function Invoke-Notes {
    if ([string]::IsNullOrWhiteSpace($Notes)) {
        throw "Parameter -Notes requires a non-empty tag string (e.g. 'v1.0.0')."
    }

    $tag = $Notes.Trim()

    # Precondition: Tag must match VERSION file content (tag == "v$version")
    $versionFilePath = Join-Path $RepoRoot 'VERSION'
    if (-not (Test-Path -LiteralPath $versionFilePath -PathType Leaf)) {
        Fail-Notes "VERSION file not found in '$RepoRoot'."
    }

    $versionContent = (Get-Content -LiteralPath $versionFilePath -Raw -Encoding utf8).Trim()
    if ([string]::IsNullOrWhiteSpace($versionContent)) {
        Fail-Notes "VERSION file in '$RepoRoot' is empty."
    }

    $expectedTag = "v$versionContent"
    if ($tag -ne $expectedTag) {
        Fail-Notes "Tag '$tag' does not match VERSION file content ('$versionContent', expected '$expectedTag')."
    }

    # Precondition: CHANGELOG.md must exist and contain a section for [$versionContent]
    $changelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
    if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) {
        Fail-Notes "CHANGELOG.md file not found in '$RepoRoot'."
    }

    $changelogContent = Get-Content -LiteralPath $changelogPath -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($changelogContent)) {
        Fail-Notes "CHANGELOG.md in '$RepoRoot' is empty."
    }

    # Extract section header and body
    # Section header format: ## [X.Y.Z] - YYYY-MM-DD - <release title> (or ## [X.Y.Z] - <title> or ## [X.Y.Z])
    $escapedVer = [regex]::Escape($versionContent)
    $sectionPattern = "(?ms)^##\s+\[$escapedVer\](?:\s+-\s+(?<hdrRest>[^\r\n]*))?(?:\r?\n(?<body>.*?))?(?=(?:^##\s+\[)|\z)"
    $match = [regex]::Match($changelogContent, $sectionPattern)
    if (-not $match.Success) {
        Fail-Notes "CHANGELOG.md has no section for version '[$versionContent]'."
    }

    $hdrRest = if ($match.Groups['hdrRest'].Success) { $match.Groups['hdrRest'].Value.Trim() } else { '' }
    $body = if ($match.Groups['body'].Success) { $match.Groups['body'].Value.Trim() } else { '' }

    # Parse title from header rest
    $title = ''
    if (-not [string]::IsNullOrWhiteSpace($hdrRest)) {
        if ($hdrRest -match '^\d{4}-\d{2}-\d{2}\s+-\s+(?<t>.*)$') {
            $title = $Matches['t'].Trim()
        } elseif ($hdrRest -match '^\d{4}-\d{2}-\d{2}$') {
            $title = ''
        } else {
            $title = $hdrRest
        }
    }

    $releaseTitle = if (-not [string]::IsNullOrWhiteSpace($title)) {
        "$tag — $title"
    } else {
        $tag
    }

    # Save to scratch release files (or custom output files)
    $releaseScratchDir = Join-Path $RepoRoot '.scratch' 'release'
    if (-not (Test-Path -LiteralPath $releaseScratchDir -PathType Container)) {
        New-Item -ItemType Directory -Path $releaseScratchDir -Force | Out-Null
    }

    $notesFilePath = if (-not [string]::IsNullOrWhiteSpace($OutNotesFile)) {
        if ([System.IO.Path]::IsPathRooted($OutNotesFile)) { $OutNotesFile } else { Join-Path $RepoRoot $OutNotesFile }
    } else {
        Join-Path $releaseScratchDir 'release-notes.md'
    }

    $titleFilePath = if (-not [string]::IsNullOrWhiteSpace($OutTitleFile)) {
        if ([System.IO.Path]::IsPathRooted($OutTitleFile)) { $OutTitleFile } else { Join-Path $RepoRoot $OutTitleFile }
    } else {
        Join-Path $releaseScratchDir 'release-title.txt'
    }

    $notesParentDir = Split-Path -Parent $notesFilePath
    if ($notesParentDir -and -not (Test-Path -LiteralPath $notesParentDir -PathType Container)) {
        New-Item -ItemType Directory -Path $notesParentDir -Force | Out-Null
    }
    $titleParentDir = Split-Path -Parent $titleFilePath
    if ($titleParentDir -and -not (Test-Path -LiteralPath $titleParentDir -PathType Container)) {
        New-Item -ItemType Directory -Path $titleParentDir -Force | Out-Null
    }

    Set-Content -LiteralPath $notesFilePath -Value "$body`n" -Encoding utf8
    Set-Content -LiteralPath $titleFilePath -Value "$releaseTitle`n" -Encoding utf8

    # Populate GITHUB_OUTPUT if running inside GitHub Actions
    if ($env:GITHUB_OUTPUT -and (Test-Path -LiteralPath $env:GITHUB_OUTPUT)) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "title=$releaseTitle" -Encoding utf8
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "section_title=$title" -Encoding utf8
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "notes_file=$notesFilePath" -Encoding utf8
    }

    # Output to stdout: Title and Body
    Write-Output "Title: $title"
    Write-Output "ReleaseTitle: $releaseTitle"
    Write-Output ""
    Write-Output $body

    exit 0
}

# --- Dispatch --------------------------------------------------------------------------
if ($PushOnly -or ($PSCmdlet.ParameterSetName -eq 'PushOnly')) {
    Invoke-PushOnly
} elseif ($Undo -or ($PSCmdlet.ParameterSetName -eq 'Undo')) {
    Invoke-Undo
} elseif ($Apply -or ($PSCmdlet.ParameterSetName -eq 'Apply')) {
    Invoke-Apply
} elseif ($Notes -or ($PSCmdlet.ParameterSetName -eq 'Notes')) {
    Invoke-Notes
} else {
    Invoke-Plan
}
