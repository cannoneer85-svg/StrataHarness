<#
.SYNOPSIS
    Initializes a new project from the Template (New), adopts into an existing repo, or updates.

.DESCRIPTION
    Deterministic file operations for template lifecycle (spec 0001 §14):
      - New: Cleans meta files, installs reset skeletons from templates,
             records template-version and template-source in .agents/SKILLS.md,
             synchronizes Claude skills mirror, and validates with Test-Template.ps1.
      - Adopt: Copies template payload into an existing repository without overwriting
               existing files, reports conflicts, appends missing .gitignore entries,
               records template version/source, synchronizes Claude skills, and validates.
      - Update: (ticket 12)
      - SetTracker: Switches issue tracker, rewriting docs/agents/issue-tracker.md
                    and the tracker block in AGENTS.md without touching other files.

    Safe to re-run; operations are idempotent.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('New', 'Adopt', 'Update', 'SetTracker')]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$TemplateSource,

    [Parameter(Mandatory = $false)]
    [string]$TemplateVersion,

    [Parameter(Mandatory = $false)]
    [ValidateSet('github', 'gitlab', 'local')]
    [string]$Tracker,

    [Parameter(Mandatory = $false)]
    [switch]$Apply,

    [Parameter(Mandatory = $false)]
    [Alias('Files', 'Paths')]
    [string[]]$SelectedPaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Mode)) {
    if (-not [string]::IsNullOrWhiteSpace($Tracker)) {
        $Mode = 'SetTracker'
    } else {
        throw "Parameter -Mode is required ('New', 'Adopt', 'Update', 'SetTracker')."
    }
}

# Resolve RepoRoot: defaults to 4 levels above this script
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ManifestPath = Join-Path $SkillRoot 'manifest.psd1'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest file not found: '$ManifestPath'."
}

$manifest = Import-PowerShellDataFile -Path $ManifestPath

function Test-IsMetaPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [array]$MetaPatterns
    )
    $normalized = $RelativePath.Replace('\', '/')
    foreach ($pattern in $MetaPatterns) {
        $entryPattern = $pattern.Replace('\', '/')
        if ($entryPattern.EndsWith('/*')) {
            $prefix = $entryPattern.Substring(0, $entryPattern.Length - 1)
            if ($normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } elseif ($entryPattern.EndsWith('/')) {
            if ($normalized.StartsWith($entryPattern, [System.StringComparison]::OrdinalIgnoreCase) -or
                $normalized.Equals($entryPattern.TrimEnd('/'), [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } else {
            if ($normalized.Equals($entryPattern, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    return $false
}

function Test-FileContentEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path1,

        [Parameter(Mandatory = $true)]
        [string]$Path2
    )
    if (-not (Test-Path -LiteralPath $Path1 -PathType Leaf) -or -not (Test-Path -LiteralPath $Path2 -PathType Leaf)) {
        return $false
    }
    $bytes1 = [System.IO.File]::ReadAllBytes($Path1)
    $bytes2 = [System.IO.File]::ReadAllBytes($Path2)
    if ($bytes1.Length -ne $bytes2.Length) {
        return $false
    }
    for ($i = 0; $i -lt $bytes1.Length; $i++) {
        if ($bytes1[$i] -ne $bytes2[$i]) {
            return $false
        }
    }
    return $true
}
 
function Get-NormalizedRegistryText {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $clean = $Text.Replace("`r`n", "`n").TrimEnd("`n")
    return [regex]::Replace($clean, '(?m)^-\s*\*\*template-(version|source):\*\*.*$', '').Trim()
}

function Test-SkillsMdContentEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path1,

        [Parameter(Mandatory = $true)]
        [string]$Path2
    )
    if (-not (Test-Path -LiteralPath $Path1 -PathType Leaf) -or -not (Test-Path -LiteralPath $Path2 -PathType Leaf)) {
        return $false
    }
    $content1 = Get-Content -LiteralPath $Path1 -Raw -Encoding utf8
    $content2 = Get-Content -LiteralPath $Path2 -Raw -Encoding utf8
    $norm1 = Get-NormalizedRegistryText -Text $content1
    $norm2 = Get-NormalizedRegistryText -Text $content2
    return ($norm1 -eq $norm2)
}

function Test-IsPayloadPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [array]$PayloadEntries,

        [Parameter(Mandatory = $true)]
        [array]$MetaPatterns
    )
    $normalized = $RelativePath.Replace('\', '/')
    if ($normalized.StartsWith('.git/') -or $normalized.StartsWith('.scratch/') -or $normalized.StartsWith('.claude/')) {
        return $false
    }
    if (Test-IsMetaPath -RelativePath $normalized -MetaPatterns $MetaPatterns) {
        return $false
    }
    if ($normalized -eq '.agents/CONTEXT.md') {
        return $false
    }
    foreach ($entry in $PayloadEntries) {
        $entryNormalized = $entry.Replace('\', '/')
        if ($normalized.Equals($entryNormalized, [System.StringComparison]::OrdinalIgnoreCase) -or
            $normalized.StartsWith("$entryNormalized/", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-GitFileText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitRepo,

        [Parameter(Mandatory = $true)]
        [string]$Commit,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )
    $gitPath = $RelativePath.Replace('\', '/')
    $output = & git -C $GitRepo show "$($Commit):$gitPath" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return ($output -join "`n")
}

function Test-TextContentEqual {
    param(
        [string]$Text1,
        [string]$Text2,
        [string]$RelativePath
    )
    if ($Text1 -eq $null -or $Text2 -eq $null) {
        return ($Text1 -eq $null -and $Text2 -eq $null)
    }
    $normalized1 = $Text1.Replace("`r`n", "`n").TrimEnd("`n")
    $normalized2 = $Text2.Replace("`r`n", "`n").TrimEnd("`n")
    if ($RelativePath.Replace('\', '/') -eq '.agents/SKILLS.md') {
        $normalized1 = Get-NormalizedRegistryText -Text $normalized1
        $normalized2 = Get-NormalizedRegistryText -Text $normalized2
    }
    return ($normalized1 -eq $normalized2)
}

function Get-PayloadFilesFromDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryRoot,

        [Parameter(Mandatory = $true)]
        [array]$PayloadEntries,

        [Parameter(Mandatory = $true)]
        [array]$MetaPatterns
    )
    $fileMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($entry in $PayloadEntries) {
        $fullPath = Join-Path $DirectoryRoot $entry
        if (-not (Test-Path -LiteralPath $fullPath)) {
            continue
        }
        if (Test-Path -LiteralPath $fullPath -PathType Container) {
            $files = Get-ChildItem -LiteralPath $fullPath -Recurse -File
            if ($files) {
                foreach ($f in $files) {
                    $rel = [System.IO.Path]::GetRelativePath($DirectoryRoot, $f.FullName)
                    $normRel = $rel.Replace('\', '/')
                    if (Test-IsPayloadPath -RelativePath $normRel -PayloadEntries $PayloadEntries -MetaPatterns $MetaPatterns) {
                        $fileMap[$normRel] = $f.FullName
                    }
                }
            }
        } else {
            $normRel = $entry.Replace('\', '/')
            if (Test-IsPayloadPath -RelativePath $normRel -PayloadEntries $PayloadEntries -MetaPatterns $MetaPatterns) {
                $fileMap[$normRel] = $fullPath
            }
        }
    }
    return $fileMap
}

function Set-ProjectTracker {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetRepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$TrackerName,

        [Parameter(Mandatory = $true)]
        [string]$SkillDirectory,

        [Parameter(Mandatory = $false)]
        [string]$TemplateSrc
    )

    $trackerTemplatePath = Join-Path $SkillDirectory 'templates' "issue-tracker-$TrackerName.md"
    if (-not (Test-Path -LiteralPath $trackerTemplatePath -PathType Leaf)) {
        if (-not [string]::IsNullOrWhiteSpace($TemplateSrc)) {
            $altPath = Join-Path $TemplateSrc '.agents' 'skills' 'init-project' 'templates' "issue-tracker-$TrackerName.md"
            if (Test-Path -LiteralPath $altPath -PathType Leaf) {
                $trackerTemplatePath = $altPath
            }
        }
    }
    if (-not (Test-Path -LiteralPath $trackerTemplatePath -PathType Leaf)) {
        throw "Issue tracker template not found: '$trackerTemplatePath'."
    }

    $destTrackerPath = Join-Path $TargetRepoRoot 'docs' 'agents' 'issue-tracker.md'
    $destTrackerDir = Split-Path -Parent $destTrackerPath
    if (-not (Test-Path -LiteralPath $destTrackerDir -PathType Container)) {
        New-Item -ItemType Directory -Path $destTrackerDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $trackerTemplatePath -Destination $destTrackerPath -Force

    $trackerSummaries = @{
        'github' = 'GitHub issues via `gh` CLI. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).'
        'gitlab' = 'GitLab issues via `glab` CLI. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).'
        'local'  = 'Local Markdown under `.scratch/<feature>/issues/`. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).'
    }

    $summaryText = $trackerSummaries[$TrackerName]
    $agentsMdPath = Join-Path $TargetRepoRoot 'AGENTS.md'
    if (Test-Path -LiteralPath $agentsMdPath -PathType Leaf) {
        $agentsContent = Get-Content -LiteralPath $agentsMdPath -Raw -Encoding utf8
        if ($agentsContent -match '(?m)^###\s+Issue tracker\b') {
            $pattern = '(?s)(###\s+Issue tracker\r?\n\r?\n).*?(?=\r?\n\r?\n###|\r?\n\r?\n##|\z)'
            $agentsContent = [regex]::Replace($agentsContent, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + $summaryText })
        } elseif ($agentsContent -match '(?m)^##\s+Agent skills\b') {
            $pattern = '(?s)(##\s+Agent skills\r?\n\r?\n)'
            $agentsContent = [regex]::Replace($agentsContent, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "### Issue tracker`n`n$summaryText`n`n" })
        } else {
            $agentsContent = $agentsContent.TrimEnd() + "`n`n## Agent skills`n`n### Issue tracker`n`n$summaryText`n"
        }
        Set-Content -LiteralPath $agentsMdPath -Value $agentsContent -Encoding utf8 -NoNewline
    }
}

switch ($Mode) {
    'New' {
        # 1. Clean meta directories and files
        if ($manifest.ContainsKey('Meta')) {
            foreach ($item in $manifest.Meta) {
                if ($item.EndsWith('/*')) {
                    $relDir = $item.Substring(0, $item.Length - 2)
                    $targetDir = Join-Path $RepoRoot $relDir
                    if (Test-Path -LiteralPath $targetDir) {
                        Get-ChildItem -LiteralPath $targetDir -Force | Remove-Item -Recurse -Force
                    } else {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }
                } else {
                    $relPath = $item.TrimEnd('/', '\')
                    $targetPath = Join-Path $RepoRoot $relPath
                    if (Test-Path -LiteralPath $targetPath) {
                        Remove-Item -LiteralPath $targetPath -Recurse -Force
                    }
                }
            }
        }

        # 2. Place reset skeletons from templates
        if ($manifest.ContainsKey('Reset')) {
            foreach ($targetRel in $manifest.Reset.Keys) {
                $templateRel = $manifest.Reset[$targetRel]
                $sourcePath = Join-Path $SkillRoot $templateRel
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                    throw "Reset template '$sourcePath' not found."
                }
                $destPath = Join-Path $RepoRoot $targetRel
                $destDir = Split-Path -Parent $destPath
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $sourcePath -Destination $destPath -Force
            }
        }

        # 3. Update template-version and template-source in .agents/SKILLS.md
        $registryPath = Join-Path $RepoRoot '.agents' 'SKILLS.md'
        if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
            $regContent = Get-Content -LiteralPath $registryPath -Raw -Encoding utf8

            $ver = $TemplateVersion
            if ([string]::IsNullOrWhiteSpace($ver)) {
                $sha = ''
                try {
                    $sha = (git -C $RepoRoot rev-parse --short HEAD 2>$null)
                } catch {}
                $dateStr = (Get-Date).ToString('yyyy-MM-dd')
                if (-not [string]::IsNullOrWhiteSpace($sha)) {
                    $ver = "$dateStr $sha"
                } else {
                    $ver = $dateStr
                }
            }

            $src = $TemplateSource
            if ([string]::IsNullOrWhiteSpace($src)) {
                try {
                    $remote = (git -C $RepoRoot remote get-url origin 2>$null)
                    if (-not [string]::IsNullOrWhiteSpace($remote)) {
                        $src = $remote.Trim()
                    }
                } catch {}
            }

            if (-not [string]::IsNullOrWhiteSpace($ver)) {
                $regContent = [regex]::Replace($regContent, '(?m)^-\s*\*\*template-version:\*\*.*$', "- **template-version:** ``$ver``")
            }
            if (-not [string]::IsNullOrWhiteSpace($src)) {
                $regContent = [regex]::Replace($regContent, '(?m)^-\s*\*\*template-source:\*\*.*$', "- **template-source:** ``$src``")
            }

            Set-Content -LiteralPath $registryPath -Value $regContent -Encoding utf8 -NoNewline
        }

        # Optional tracker setup
        if (-not [string]::IsNullOrWhiteSpace($Tracker)) {
            Set-ProjectTracker -TargetRepoRoot $RepoRoot -TrackerName $Tracker -SkillDirectory $SkillRoot -TemplateSrc $TemplateSource
        }

        # 4. Synchronize Claude skills mirror
        $syncScript = Join-Path $RepoRoot '.agents' 'scripts' 'Sync-ClaudeSkills.ps1'
        if (Test-Path -LiteralPath $syncScript -PathType Leaf) {
            & $syncScript -RepoRoot $RepoRoot
        }

        # 5. Run template validation
        $testScript = Join-Path $RepoRoot '.agents' 'scripts' 'Test-Template.ps1'
        if (Test-Path -LiteralPath $testScript -PathType Leaf) {
            & $testScript
        }

        Write-Output "Project initialized successfully in New mode (RepoRoot: $RepoRoot)."
    }

    'Adopt' {
        if ([string]::IsNullOrWhiteSpace($TemplateSource)) {
            throw "Parameter -TemplateSource <path> is required for Adopt mode."
        }
        if (-not (Test-Path -LiteralPath $TemplateSource -PathType Container)) {
            throw "TemplateSource directory '$TemplateSource' does not exist."
        }
        $resolvedTemplateSource = (Resolve-Path -LiteralPath $TemplateSource).Path

        $conflicts = [System.Collections.Generic.List[string]]::new()
        $metaPatterns = @()
        if ($manifest.ContainsKey('Meta')) {
            $metaPatterns = $manifest.Meta
        }

        # 1. Process Payload entries from manifest
        if ($manifest.ContainsKey('Payload')) {
            foreach ($entry in $manifest.Payload) {
                $srcEntryPath = Join-Path $resolvedTemplateSource $entry
                if (-not (Test-Path -LiteralPath $srcEntryPath)) {
                    # If it's a directory that doesn't exist in source, ensure directory exists in dest
                    $destDirPath = Join-Path $RepoRoot $entry
                    if (-not (Test-Path -LiteralPath $destDirPath)) {
                        New-Item -ItemType Directory -Path $destDirPath -Force | Out-Null
                    }
                    continue
                }

                if (Test-Path -LiteralPath $srcEntryPath -PathType Container) {
                    # Ensure container exists in target
                    $destContainer = Join-Path $RepoRoot $entry
                    if (-not (Test-Path -LiteralPath $destContainer)) {
                        New-Item -ItemType Directory -Path $destContainer -Force | Out-Null
                    }

                    # Enumerate all files inside container recursively
                    $files = Get-ChildItem -LiteralPath $srcEntryPath -Recurse -File
                    if ($files) {
                        foreach ($file in $files) {
                            $relPath = [System.IO.Path]::GetRelativePath($resolvedTemplateSource, $file.FullName)
                            $normalizedRel = $relPath.Replace('\', '/')

                        # Never copy .git, .scratch, .claude
                        if ($normalizedRel.StartsWith('.git/') -or $normalizedRel.StartsWith('.scratch/') -or $normalizedRel.StartsWith('.claude/')) {
                            continue
                        }

                        # Never copy meta
                        if (Test-IsMetaPath -RelativePath $normalizedRel -MetaPatterns $metaPatterns) {
                            continue
                        }

                        # Special case for .agents/CONTEXT.md: do not copy template's CONTEXT.md
                        if ($normalizedRel -eq '.agents/CONTEXT.md') {
                            continue
                        }

                        $destFilePath = Join-Path $RepoRoot $relPath
                        if (Test-Path -LiteralPath $destFilePath -PathType Leaf) {
                            $isEqual = if ($normalizedRel -eq '.agents/SKILLS.md') {
                                Test-SkillsMdContentEqual -Path1 $file.FullName -Path2 $destFilePath
                            } else {
                                Test-FileContentEqual -Path1 $file.FullName -Path2 $destFilePath
                            }

                            if (-not $isEqual) {
                                $conflicts.Add($normalizedRel)
                                Write-Output "Conflict: file '$normalizedRel' already exists in target repository. Preserved existing file."
                            }
                            # Never overwrite existing file
                            continue
                        }

                        $parentDir = Split-Path -Parent $destFilePath
                        if (-not (Test-Path -LiteralPath $parentDir)) {
                            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                        }
                        Copy-Item -LiteralPath $file.FullName -Destination $destFilePath -Force
                    }
                }
            } else {
                    # Single file
                    $normalizedRel = $entry.Replace('\', '/')
                    if (Test-IsMetaPath -RelativePath $normalizedRel -MetaPatterns $metaPatterns) {
                        continue
                    }

                    $destFilePath = Join-Path $RepoRoot $entry
                    if (Test-Path -LiteralPath $destFilePath -PathType Leaf) {
                        $isEqual = if ($normalizedRel -eq '.agents/SKILLS.md') {
                            Test-SkillsMdContentEqual -Path1 $srcEntryPath -Path2 $destFilePath
                        } else {
                            Test-FileContentEqual -Path1 $srcEntryPath -Path2 $destFilePath
                        }

                        if (-not $isEqual) {
                            $conflicts.Add($normalizedRel)
                            Write-Output "Conflict: file '$normalizedRel' already exists in target repository. Preserved existing file."
                        }
                        continue
                    }

                    $parentDir = Split-Path -Parent $destFilePath
                    if (-not (Test-Path -LiteralPath $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $srcEntryPath -Destination $destFilePath -Force
                }
            }
        }

        # 2. Place skeletons for .agents/CONTEXT.md and docs/handoff/LATEST.md if they do NOT exist
        $targetContext = Join-Path $RepoRoot '.agents' 'CONTEXT.md'
        if (-not (Test-Path -LiteralPath $targetContext -PathType Leaf)) {
            $contextSkeleton = Join-Path $SkillRoot 'templates' 'CONTEXT.md'
            if (-not (Test-Path -LiteralPath $contextSkeleton -PathType Leaf)) {
                $contextSkeleton = Join-Path $resolvedTemplateSource '.agents' 'skills' 'init-project' 'templates' 'CONTEXT.md'
            }
            if (Test-Path -LiteralPath $contextSkeleton -PathType Leaf) {
                $destDir = Split-Path -Parent $targetContext
                if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Copy-Item -LiteralPath $contextSkeleton -Destination $targetContext -Force
            }
        }

        $targetLatest = Join-Path $RepoRoot 'docs' 'handoff' 'LATEST.md'
        if (-not (Test-Path -LiteralPath $targetLatest -PathType Leaf)) {
            $latestSkeleton = Join-Path $SkillRoot 'templates' 'LATEST.md'
            if (-not (Test-Path -LiteralPath $latestSkeleton -PathType Leaf)) {
                $latestSkeleton = Join-Path $resolvedTemplateSource '.agents' 'skills' 'init-project' 'templates' 'LATEST.md'
            }
            if (Test-Path -LiteralPath $latestSkeleton -PathType Leaf) {
                $destDir = Split-Path -Parent $targetLatest
                if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Copy-Item -LiteralPath $latestSkeleton -Destination $targetLatest -Force
            }
        }

        # 3. Update .gitignore with entries from manifest.GitIgnoreEntries without duplicates
        if ($manifest.ContainsKey('GitIgnoreEntries')) {
            $gitIgnorePath = Join-Path $RepoRoot '.gitignore'
            $existingLines = @()
            if (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf) {
                $existingLines = Get-Content -LiteralPath $gitIgnorePath -Encoding utf8
            }

            $linesToAdd = [System.Collections.Generic.List[string]]::new()
            foreach ($entry in $manifest.GitIgnoreEntries) {
                $entryTrimmed = $entry.Trim()
                $found = $false
                foreach ($line in $existingLines) {
                    $lineTrimmed = $line.Trim()
                    if ($lineTrimmed -eq $entryTrimmed -or ($entryTrimmed.EndsWith('/') -and $lineTrimmed -eq $entryTrimmed.TrimEnd('/')) -or ($lineTrimmed.EndsWith('/') -and $lineTrimmed.TrimEnd('/') -eq $entryTrimmed)) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    $linesToAdd.Add($entry)
                }
            }

            if ($linesToAdd.Count -gt 0) {
                if (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf) {
                    $raw = Get-Content -LiteralPath $gitIgnorePath -Raw -Encoding utf8
                    $prefix = ''
                    if (-not [string]::IsNullOrEmpty($raw) -and -not $raw.EndsWith("`n")) {
                        $prefix = "`n"
                    }
                    $contentToAppend = $prefix + ($linesToAdd -join "`n") + "`n"
                    [System.IO.File]::AppendAllText($gitIgnorePath, $contentToAppend, [System.Text.Encoding]::UTF8)
                } else {
                    $content = ($linesToAdd -join "`n") + "`n"
                    Set-Content -LiteralPath $gitIgnorePath -Value $content -Encoding utf8 -NoNewline
                }
            }
        }

        # 4. Write template-version and template-source in target repo .agents/SKILLS.md
        $registryPath = Join-Path $RepoRoot '.agents' 'SKILLS.md'
        if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
            $regContent = Get-Content -LiteralPath $registryPath -Raw -Encoding utf8

            $ver = $TemplateVersion
            if ([string]::IsNullOrWhiteSpace($ver)) {
                $sha = ''
                try {
                    $sha = (git -C $resolvedTemplateSource rev-parse --short HEAD 2>$null)
                } catch {}
                if ([string]::IsNullOrWhiteSpace($sha)) {
                    try {
                        $sha = (git -C $RepoRoot rev-parse --short HEAD 2>$null)
                    } catch {}
                }
                $dateStr = (Get-Date).ToString('yyyy-MM-dd')
                if (-not [string]::IsNullOrWhiteSpace($sha)) {
                    $ver = "$dateStr $sha"
                } else {
                    $ver = $dateStr
                }
            }

            $src = $TemplateSource
            if ([string]::IsNullOrWhiteSpace($src)) {
                try {
                    $remote = (git -C $resolvedTemplateSource remote get-url origin 2>$null)
                    if (-not [string]::IsNullOrWhiteSpace($remote)) {
                        $src = $remote.Trim()
                    }
                } catch {}
            }

            if (-not [string]::IsNullOrWhiteSpace($ver)) {
                $regContent = [regex]::Replace($regContent, '(?m)^-\s*\*\*template-version:\*\*.*$', "- **template-version:** ``$ver``")
            }
            if (-not [string]::IsNullOrWhiteSpace($src)) {
                $regContent = [regex]::Replace($regContent, '(?m)^-\s*\*\*template-source:\*\*.*$', "- **template-source:** ``$src``")
            }

            Set-Content -LiteralPath $registryPath -Value $regContent -Encoding utf8 -NoNewline
        }

        # 5. Optional tracker configuration if -Tracker parameter was provided
        if (-not [string]::IsNullOrWhiteSpace($Tracker)) {
            Set-ProjectTracker -TargetRepoRoot $RepoRoot -TrackerName $Tracker -SkillDirectory $SkillRoot -TemplateSrc $TemplateSource
        }

        # 6. Synchronize Claude skills mirror on target repo
        $syncScript = Join-Path $RepoRoot '.agents' 'scripts' 'Sync-ClaudeSkills.ps1'
        if (Test-Path -LiteralPath $syncScript -PathType Leaf) {
            & $syncScript -RepoRoot $RepoRoot
        }

        # 7. Run template validation on target repo
        $testScript = Join-Path $RepoRoot '.agents' 'scripts' 'Test-Template.ps1'
        if (Test-Path -LiteralPath $testScript -PathType Leaf) {
            & $testScript
        }

        if ($conflicts.Count -gt 0) {
            Write-Output "Conflicts encountered ($($conflicts.Count)): $($conflicts -join ', ')"
        }
        Write-Output "Project successfully adopted (RepoRoot: $RepoRoot)."
    }

    'Update' {
        # 1. Resolve TemplateSource: parameter or .agents/SKILLS.md in target repo
        if ([string]::IsNullOrWhiteSpace($TemplateSource)) {
            $registryPath = Join-Path $RepoRoot '.agents' 'SKILLS.md'
            if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
                $regContent = Get-Content -LiteralPath $registryPath -Raw -Encoding utf8
                if ($regContent -match '(?m)^-\s*\*\*template-source:\*\*\s*`?([^`\r\n]+)`?') {
                    $TemplateSource = $matches[1].Trim()
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($TemplateSource)) {
            throw "Parameter -TemplateSource is required or must be present in .agents/SKILLS.md under template-source."
        }

        if (-not (Test-Path -LiteralPath $TemplateSource -PathType Container)) {
            throw "TemplateSource directory '$TemplateSource' does not exist."
        }
        $resolvedTemplateSource = (Resolve-Path -LiteralPath $TemplateSource).Path

        # 2. Retrieve base version / commit from target .agents/SKILLS.md
        $baseVerStr = ''
        $registryPath = Join-Path $RepoRoot '.agents' 'SKILLS.md'
        if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
            $regContent = Get-Content -LiteralPath $registryPath -Raw -Encoding utf8
            if ($regContent -match '(?m)^-\s*\*\*template-version:\*\*\s*`?([^`\r\n]+)`?') {
                $baseVerStr = $matches[1].Trim()
            }
        }

        # 3. Check if template source is a git repository and resolve base git commit
        $isGitRepo = $false
        try {
            $gitDir = & git -C $resolvedTemplateSource rev-parse --git-dir 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitDir)) {
                $isGitRepo = $true
            }
        } catch {}

        $baseCommit = $null
        if ($isGitRepo -and -not [string]::IsNullOrWhiteSpace($baseVerStr)) {
            $shaMatch = [regex]::Match($baseVerStr, '\b([0-9a-f]{7,40})\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($shaMatch.Success) {
                $candidate = $shaMatch.Groups[1].Value
                $commitSha = & git -C $resolvedTemplateSource rev-parse --verify --quiet "$candidate^{commit}" 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commitSha)) {
                    $baseCommit = $commitSha.Trim()
                }
            }
            if ($baseCommit -eq $null) {
                $lastToken = ($baseVerStr.Trim().Split(" `t`r`n", [System.StringSplitOptions]::RemoveEmptyEntries))[-1]
                $commitSha = & git -C $resolvedTemplateSource rev-parse --verify --quiet "$lastToken^{commit}" 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commitSha)) {
                    $baseCommit = $commitSha.Trim()
                }
            }
        }

        # 4. Enumerate payload files from Template, Target, and Base
        $metaPatterns = @()
        if ($manifest.ContainsKey('Meta')) {
            $metaPatterns = $manifest.Meta
        }
        $payloadEntries = @()
        if ($manifest.ContainsKey('Payload')) {
            $payloadEntries = $manifest.Payload
        }

        $templateFiles = Get-PayloadFilesFromDir -DirectoryRoot $resolvedTemplateSource -PayloadEntries $payloadEntries -MetaPatterns $metaPatterns
        $targetFiles = Get-PayloadFilesFromDir -DirectoryRoot $RepoRoot -PayloadEntries $payloadEntries -MetaPatterns $metaPatterns

        $basePayloadFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        if ($baseCommit -ne $null) {
            $treeLines = & git -C $resolvedTemplateSource ls-tree -r --name-only $baseCommit 2>$null
            if ($LASTEXITCODE -eq 0 -and $treeLines) {
                foreach ($line in $treeLines) {
                    $normRel = $line.Trim().Replace('\', '/')
                    if (Test-IsPayloadPath -RelativePath $normRel -PayloadEntries $payloadEntries -MetaPatterns $metaPatterns) {
                        [void]$basePayloadFiles.Add($normRel)
                    }
                }
            }
        }

        # 5. Categorize changes
        $addedInTemplate = [System.Collections.Generic.List[string]]::new()
        $modifiedInTemplate = [System.Collections.Generic.List[string]]::new()
        $removedInTemplate = [System.Collections.Generic.List[string]]::new()
        $conflicts = [System.Collections.Generic.List[string]]::new()

        # Check all files present in current Template payload
        foreach ($rel in $templateFiles.Keys) {
            if ($targetFiles.ContainsKey($rel)) {
                # File exists in both Template and Target
                $tplText = [System.IO.File]::ReadAllText($templateFiles[$rel], [System.Text.Encoding]::UTF8)
                $tgtText = [System.IO.File]::ReadAllText($targetFiles[$rel], [System.Text.Encoding]::UTF8)

                if (Test-TextContentEqual -Text1 $tgtText -Text2 $tplText -RelativePath $rel) {
                    # Identical - up to date
                    continue
                }

                # Differs: determine if locally modified or modified in template
                if ($baseCommit -ne $null) {
                    $baseText = Get-GitFileText -GitRepo $resolvedTemplateSource -Commit $baseCommit -RelativePath $rel
                    if ($baseText -ne $null) {
                        if (Test-TextContentEqual -Text1 $tgtText -Text2 $baseText -RelativePath $rel) {
                            $modifiedInTemplate.Add($rel)
                        } else {
                            $conflicts.Add($rel)
                        }
                    } else {
                        # File was added in template after base, but target already has differing file
                        $conflicts.Add($rel)
                    }
                } else {
                    # Base cannot be retrieved: difference is treated as conflict
                    $conflicts.Add($rel)
                }
            } else {
                # Exists in template, missing in target
                $addedInTemplate.Add($rel)
            }
        }

        # Check files removed in template (existed in base payload, missing in template, present in target)
        if ($baseCommit -ne $null) {
            foreach ($rel in $basePayloadFiles) {
                if (-not $templateFiles.ContainsKey($rel) -and $targetFiles.ContainsKey($rel)) {
                    $tgtText = [System.IO.File]::ReadAllText($targetFiles[$rel], [System.Text.Encoding]::UTF8)
                    $baseText = Get-GitFileText -GitRepo $resolvedTemplateSource -Commit $baseCommit -RelativePath $rel
                    if ($baseText -ne $null) {
                        if (Test-TextContentEqual -Text1 $tgtText -Text2 $baseText -RelativePath $rel) {
                            $removedInTemplate.Add($rel)
                        } else {
                            $conflicts.Add($rel)
                        }
                    }
                }
            }
        }

        $addedInTemplate.Sort()
        $modifiedInTemplate.Sort()
        $removedInTemplate.Sort()
        $conflicts.Sort()

        # 6. Report findings
        $totalChanges = $addedInTemplate.Count + $modifiedInTemplate.Count + $removedInTemplate.Count + $conflicts.Count
        Write-Output "Template Update Report"
        Write-Output "Target repository: $RepoRoot"
        Write-Output "Template source:   $resolvedTemplateSource"
        if (-not [string]::IsNullOrWhiteSpace($baseVerStr)) {
            Write-Output "Base version:      $baseVerStr"
        }
        if (-not [string]::IsNullOrWhiteSpace($baseCommit)) {
            Write-Output "Base git commit:   $baseCommit"
        } else {
            Write-Output "Base git commit:   (not available - differences treated as conflicts)"
        }
        Write-Output ""

        if ($totalChanges -eq 0) {
            Write-Output "No pending template updates. Project is up to date."
        } else {
            Write-Output "Changes categorized:"
            Write-Output "  Added in Template:           $($addedInTemplate.Count)"
            Write-Output "  Modified in Template:        $($modifiedInTemplate.Count)"
            Write-Output "  Removed in Template:         $($removedInTemplate.Count)"
            Write-Output "  Conflict: modified locally:  $($conflicts.Count)"
            Write-Output ""

            if ($addedInTemplate.Count -gt 0) {
                Write-Output "Added in Template:"
                foreach ($f in $addedInTemplate) {
                    Write-Output "  + [Added in Template] $f"
                }
            }
            if ($modifiedInTemplate.Count -gt 0) {
                Write-Output "Modified in Template:"
                foreach ($f in $modifiedInTemplate) {
                    Write-Output "  ~ [Modified in Template] $f"
                }
            }
            if ($removedInTemplate.Count -gt 0) {
                Write-Output "Removed in Template:"
                foreach ($f in $removedInTemplate) {
                    Write-Output "  - [Removed in Template] $f"
                }
            }
            if ($conflicts.Count -gt 0) {
                Write-Output "Conflict: modified locally:"
                foreach ($f in $conflicts) {
                    Write-Output "  ! [Conflict: modified locally] $f (local modifications detected; will not be silently overwritten)"
                }
            }
        }

        # 7. Apply updates if -Apply was requested
        if ($Apply) {
            $filterPaths = $null
            if ($SelectedPaths -and $SelectedPaths.Count -gt 0) {
                $filterPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($fp in $SelectedPaths) {
                    [void]$filterPaths.Add($fp.Replace('\', '/'))
                }
            }

            # Copy additions
            foreach ($f in $addedInTemplate) {
                if ($filterPaths -ne $null -and -not $filterPaths.Contains($f)) {
                    continue
                }
                $src = Join-Path $resolvedTemplateSource $f
                $dest = Join-Path $RepoRoot $f
                $destDir = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $src -Destination $dest -Force
                Write-Output "Applied (added): $f"
            }

            # Copy modifications
            foreach ($f in $modifiedInTemplate) {
                if ($filterPaths -ne $null -and -not $filterPaths.Contains($f)) {
                    continue
                }
                $src = Join-Path $resolvedTemplateSource $f
                $dest = Join-Path $RepoRoot $f
                $destDir = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $src -Destination $dest -Force
                Write-Output "Applied (modified): $f"
            }

            # Remove deleted files
            foreach ($f in $removedInTemplate) {
                if ($filterPaths -ne $null -and -not $filterPaths.Contains($f)) {
                    continue
                }
                $dest = Join-Path $RepoRoot $f
                if (Test-Path -LiteralPath $dest -PathType Leaf) {
                    Remove-Item -LiteralPath $dest -Force
                    Write-Output "Applied (removed): $f"
                }
                # Clean up empty parent directory if inside .agents/skills or docs/agents
                $parent = Split-Path -Parent $dest
                while ($parent -and (Test-Path -LiteralPath $parent) -and $parent -ne $RepoRoot) {
                    $children = @(Get-ChildItem -LiteralPath $parent -Force)
                    if ($children.Count -eq 0) {
                        Remove-Item -LiteralPath $parent -Force
                        $parent = Split-Path -Parent $parent
                    } else {
                        break
                    }
                }
            }

            # Skip conflicts with warning
            foreach ($f in $conflicts) {
                Write-Output "Skipping conflicting file '$f' (local modifications preserved)."
            }

            # 8. Update template-version and template-source in .agents/SKILLS.md
            $registryPath = Join-Path $RepoRoot '.agents' 'SKILLS.md'
            if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
                $regContent = Get-Content -LiteralPath $registryPath -Raw -Encoding utf8

                $ver = $TemplateVersion
                if ([string]::IsNullOrWhiteSpace($ver)) {
                    $sha = ''
                    try {
                        $sha = (git -C $resolvedTemplateSource rev-parse --short HEAD 2>$null)
                    } catch {}
                    if ([string]::IsNullOrWhiteSpace($sha)) {
                        try {
                            $sha = (git -C $RepoRoot rev-parse --short HEAD 2>$null)
                        } catch {}
                    }
                    $dateStr = (Get-Date).ToString('yyyy-MM-dd')
                    if (-not [string]::IsNullOrWhiteSpace($sha)) {
                        $ver = "$dateStr $sha"
                    } else {
                        $ver = $dateStr
                    }
                }

                $src = $TemplateSource
                if ([string]::IsNullOrWhiteSpace($src)) {
                    try {
                        $remote = (git -C $resolvedTemplateSource remote get-url origin 2>$null)
                        if (-not [string]::IsNullOrWhiteSpace($remote)) {
                            $src = $remote.Trim()
                        }
                    } catch {}
                }

                if (-not [string]::IsNullOrWhiteSpace($ver)) {
                    $regContent = [regex]::Replace($regContent, '(?m)^-\s*\*\*template-version:\*\*.*$', "- **template-version:** ``$ver``")
                }
                if (-not [string]::IsNullOrWhiteSpace($src)) {
                    $regContent = [regex]::Replace($regContent, '(?m)^-\s*\*\*template-source:\*\*.*$', "- **template-source:** ``$src``")
                }

                Set-Content -LiteralPath $registryPath -Value $regContent -Encoding utf8 -NoNewline
            }

            # 9. Sync Claude skills mirror
            $syncScript = Join-Path $RepoRoot '.agents' 'scripts' 'Sync-ClaudeSkills.ps1'
            if (Test-Path -LiteralPath $syncScript -PathType Leaf) {
                & $syncScript -RepoRoot $RepoRoot
            }

            # 10. Run template validation
            $testScript = Join-Path $RepoRoot '.agents' 'scripts' 'Test-Template.ps1'
            if (Test-Path -LiteralPath $testScript -PathType Leaf) {
                & $testScript
            }

            Write-Output "Project successfully updated to template version '$ver' (RepoRoot: $RepoRoot)."
        } else {
            Write-Output ""
            Write-Output "Dry run complete. Use -Apply to apply non-conflicting changes."
        }
    }

    'SetTracker' {
        if ([string]::IsNullOrWhiteSpace($Tracker)) {
            throw "Parameter -Tracker <github|gitlab|local> is required for SetTracker mode."
        }
        Set-ProjectTracker -TargetRepoRoot $RepoRoot -TrackerName $Tracker -SkillDirectory $SkillRoot -TemplateSrc $TemplateSource

        $testScript = Join-Path $RepoRoot '.agents' 'scripts' 'Test-Template.ps1'
        if (Test-Path -LiteralPath $testScript -PathType Leaf) {
            & $testScript
        }

        Write-Output "Tracker successfully set to '$Tracker' (RepoRoot: $RepoRoot)."
    }
}
