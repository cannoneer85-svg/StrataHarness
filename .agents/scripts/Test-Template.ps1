<#
.SYNOPSIS
    Validates that the Template's skills, Registry, flags and links are consistent.

.DESCRIPTION
    Checks (spec 0001, section 15):
      1. Every folder in .agents/skills/ is listed in the Registry (.agents/SKILLS.md) and vice versa.
      2. Frontmatter `name` in each SKILL.md equals its folder name.
      3. `disable-model-invocation: true` in SKILL.md <=> `allow_implicit_invocation: false`
         in agents/openai.yaml.
      4. Relative markdown links in the root AGENTS.md (if present), the Registry,
         .agents/skills/ask/SKILL.md (if present) and docs/agents/* point to existing paths.
      5. Legacy .agents/AGENTS.md does not exist.
      6. Root AGENTS.md is smaller than 24 KB (24000 bytes), if present.
      7. (spec 0002, D8) If VERSION exists: it is a valid SemVer (X.Y.Z or X.Y.Z-rc.N); if CHANGELOG.md
         also exists and has version sections, the top one equals VERSION; with VERSION 0.0.0 there may be
         no version sections. Without VERSION (a Project) the rule is skipped.
      8. Active agent instructions (.agents/skills/*, .agents/CONTEXT.md, AGENTS.md) contain no legacy numeric question quota phrasing.
      9. The 'release' skill (if present) is listed in the '## Только Шаблон' section of .agents/SKILLS.md.
      10. All .sh files in .agents/ use Unix LF line endings and pass bash syntax check.
      11. If .claude/skills/ exists, its file tree and file contents match .agents/skills/.
      12. All scalar values in SKILL.md YAML frontmatter containing ': ' must be quoted (yaml-frontmatter).
      13. Each skill description must be <= 1024 chars, and total description budget <= 8000 chars (description-length).
      14. Combined size of root AGENTS.md and .agents/CONTEXT.md must be <= 32 KiB (32768 bytes) (context-budget).

    The repository root is resolved relative to this script, so it can be run from any folder.
    Prints every violation and exits with 0 (no violations) or 1 (violations found).
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'SemVer.ps1')

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$AgentsDir = Join-Path $RepoRoot '.agents'
$SkillsDir = Join-Path $AgentsDir 'skills'
$RegistryPath = Join-Path $AgentsDir 'SKILLS.md'
$RootAgentsPath = Join-Path $RepoRoot 'AGENTS.md'
$LegacyAgentsPath = Join-Path $AgentsDir 'AGENTS.md'
$VersionPath = Join-Path $RepoRoot 'VERSION'
$ChangelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
$AgentsMdMaxBytes = 24000

$script:Violations = [System.Collections.Generic.List[string]]::new()

function Add-Violation([string]$Rule, [string]$Message, [string]$Fix = '') {
    if (-not [string]::IsNullOrWhiteSpace($Fix)) {
        if (-not $Fix.StartsWith('Fix:')) {
            $Fix = "Fix: $Fix"
        }
        $script:Violations.Add("[$Rule] $Message $Fix")
    } elseif ($Message -match '\bFix:') {
        $script:Violations.Add("[$Rule] $Message")
    } else {
        $script:Violations.Add("[$Rule] $Message Fix: Address the [$Rule] violation.")
    }
}

function Get-RelativePath([string]$Path) {
    return [System.IO.Path]::GetRelativePath($RepoRoot, $Path).Replace('\', '/')
}

# Returns the YAML frontmatter text of a markdown file, or $null if there is none.
function Get-Frontmatter([string]$Path) {
    $text = [string](Get-Content -LiteralPath $Path -Raw -Encoding utf8)
    $match = [regex]::Match($text, '\A\uFEFF?---\r?\n(?<fm>.*?)\r?\n---\s*(\r?\n|\z)', 'Singleline')
    if (-not $match.Success) { return $null }
    return $match.Groups['fm'].Value
}

function Get-YamlScalar([string]$Yaml, [string]$Key) {
    $match = [regex]::Match($Yaml, "(?m)^\s*$([regex]::Escape($Key)):\s*(?<v>.*?)\s*$")
    if (-not $match.Success) { return $null }
    return $match.Groups['v'].Value.Trim('"', "'")
}

# Markdown text with fenced code blocks removed and inline code spans neutralised,
# so that link-like text inside code is not treated as a link.
function Get-LinkableText([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ($null -eq $text) { return '' }
    $text = [regex]::Replace($text, '(?ms)^[ \t]*(```|~~~).*?^[ \t]*\1[^\n]*$', '')
    return [regex]::Replace($text, '`[^`\r\n]*`', 'code')
}

# --- Rule 1: skill folders <=> Registry -------------------------------------------------

$skillFolders = @(Get-ChildItem -LiteralPath $SkillsDir -Directory | ForEach-Object Name | Sort-Object)

$registrySkills = @()
if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
    $registryText = Get-LinkableText $RegistryPath
    $registrySkills = @(
        [regex]::Matches($registryText, '(?m)^\|\s*\[[^\]]*\]\(skills/(?<name>[^/)]+)/SKILL\.md\)') |
            ForEach-Object { $_.Groups['name'].Value }
    )
    $registrySkills |
        Group-Object |
        Where-Object Count -gt 1 |
        ForEach-Object { Add-Violation 'registry' "Skill '$($_.Name)' is listed $($_.Count) times in .agents/SKILLS.md." "Fix: Remove duplicate entries from .agents/SKILLS.md." }
} else {
    Add-Violation 'registry' 'Registry .agents/SKILLS.md is missing.' 'Fix: Create .agents/SKILLS.md or run Initialize-Project.ps1.'
}

foreach ($folder in $skillFolders | Where-Object { $_ -notin $registrySkills }) {
    Add-Violation 'registry' "Skill folder '.agents/skills/$folder' is not listed in .agents/SKILLS.md." "Fix: Add skill '$folder' to .agents/SKILLS.md."
}
foreach ($listed in $registrySkills | Sort-Object -Unique | Where-Object { $_ -notin $skillFolders }) {
    Add-Violation 'registry' "Registry lists '$listed', but folder '.agents/skills/$listed' does not exist." "Fix: Create folder '.agents/skills/$listed' or remove it from .agents/SKILLS.md."
}

# --- Rules 2, 3, 12, 13: frontmatter name, flags, YAML scalars, description length ---

$totalSkillDescLength = 0
$maxSingleDescLength = 1024
$maxTotalDescLength = 8000

foreach ($folder in $skillFolders) {
    $skillMd = Join-Path $SkillsDir $folder 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
        Add-Violation 'name' "'.agents/skills/$folder/SKILL.md' is missing." "Fix: Add SKILL.md to '.agents/skills/$folder/'."
        continue
    }

    $frontmatter = Get-Frontmatter $skillMd
    if ($null -eq $frontmatter) {
        Add-Violation 'name' "'.agents/skills/$folder/SKILL.md' has no YAML frontmatter." "Fix: Add YAML frontmatter with 'name' and 'description' to '.agents/skills/$folder/SKILL.md'."
        continue
    }

    # Rule 12: yaml-frontmatter (check unquoted colon-space in frontmatter scalar lines)
    $fmLines = $frontmatter -split "`r?`n"
    foreach ($line in $fmLines) {
        if ($line -match '^\s*(?<key>[a-zA-Z0-9_-]+):\s*(?<val>.*)$') {
            $key = $Matches['key']
            $rawVal = $Matches['val'].Trim()
            if (-not [string]::IsNullOrEmpty($rawVal)) {
                $isQuoted = ($rawVal.Length -ge 2) -and (($rawVal.StartsWith('"') -and $rawVal.EndsWith('"')) -or ($rawVal.StartsWith("'") -and $rawVal.EndsWith("'")))
                if (-not $isQuoted -and $rawVal.Contains(': ')) {
                    Add-Violation 'yaml-frontmatter' "'.agents/skills/$folder/SKILL.md' contains unquoted colon-space in field '$key'." "Fix: Wrap the '$key' value in quotes in '.agents/skills/$folder/SKILL.md'."
                }
            }
        }
    }

    $name = Get-YamlScalar $frontmatter 'name'
    if ($name -cne $folder) {
        Add-Violation 'name' "'.agents/skills/$folder/SKILL.md' has name '$name', expected '$folder'." "Fix: Set 'name: $folder' in '.agents/skills/$folder/SKILL.md'."
    }

    # Rule 13: description-length (single skill description <= 1024 chars)
    $desc = Get-YamlScalar $frontmatter 'description'
    if (-not [string]::IsNullOrEmpty($desc)) {
        if ($desc.Length -gt $maxSingleDescLength) {
            Add-Violation 'description-length' "'.agents/skills/$folder/SKILL.md' description is $($desc.Length) characters; maximum allowed is $maxSingleDescLength." "Fix: Shorten the description in '.agents/skills/$folder/SKILL.md' to $maxSingleDescLength characters or fewer."
        }
        $totalSkillDescLength += $desc.Length
    }

    $manualInSkill = (Get-YamlScalar $frontmatter 'disable-model-invocation') -eq 'true'

    $openaiYaml = Join-Path $SkillsDir $folder 'agents' 'openai.yaml'
    $manualInYaml = $false
    if (Test-Path -LiteralPath $openaiYaml -PathType Leaf) {
        $yamlText = Get-Content -LiteralPath $openaiYaml -Raw -Encoding utf8
        $manualInYaml = (Get-YamlScalar ([string]$yamlText) 'allow_implicit_invocation') -eq 'false'
    }

    if ($manualInSkill -and -not $manualInYaml) {
        Add-Violation 'flags' "'$folder': SKILL.md has 'disable-model-invocation: true', but agents/openai.yaml lacks 'policy.allow_implicit_invocation: false'." "Fix: Set 'allow_implicit_invocation: false' in '.agents/skills/$folder/agents/openai.yaml'."
    } elseif ($manualInYaml -and -not $manualInSkill) {
        Add-Violation 'flags' "'$folder': agents/openai.yaml has 'allow_implicit_invocation: false', but SKILL.md lacks 'disable-model-invocation: true'." "Fix: Set 'disable-model-invocation: true' in '.agents/skills/$folder/SKILL.md'."
    }
}

if ($totalSkillDescLength -gt $maxTotalDescLength) {
    Add-Violation 'description-length' "Total length of all skill descriptions is $totalSkillDescLength characters; maximum budget is $maxTotalDescLength." "Fix: Shorten skill descriptions across .agents/skills/ to fit within the $maxTotalDescLength character budget."
}

# --- Rule 4: relative links -------------------------------------------------------------

$linkSources = [System.Collections.Generic.List[string]]::new()
foreach ($candidate in @($RootAgentsPath, $RegistryPath, (Join-Path $SkillsDir 'ask' 'SKILL.md'))) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $linkSources.Add($candidate) }
}
$docsAgentsDir = Join-Path $RepoRoot 'docs' 'agents'
if (Test-Path -LiteralPath $docsAgentsDir -PathType Container) {
    Get-ChildItem -LiteralPath $docsAgentsDir -File -Recurse -Filter '*.md' |
        ForEach-Object { $linkSources.Add($_.FullName) }
}

foreach ($source in $linkSources) {
    $sourceDir = Split-Path -Parent $source
    $links = [regex]::Matches((Get-LinkableText $source), '\[[^\]]*\]\((?<target>[^)\s]+)(\s+"[^"]*")?\)')
    foreach ($link in $links) {
        $target = $link.Groups['target'].Value.Trim('<', '>')
        if ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or $target.StartsWith('#')) { continue }

        $pathPart = [uri]::UnescapeDataString(($target -split '[#?]', 2)[0])
        if ([string]::IsNullOrEmpty($pathPart)) { continue }

        $resolved = if ($pathPart.StartsWith('/')) {
            Join-Path $RepoRoot $pathPart.TrimStart('/')
        } else {
            Join-Path $sourceDir $pathPart
        }
        if (-not (Test-Path -LiteralPath $resolved)) {
            Add-Violation 'links' "$(Get-RelativePath $source): broken link '$target'." "Fix: Update link target '$target' to an existing file path."
        }
    }
}

# --- Rule 5: legacy .agents/AGENTS.md ---------------------------------------------------

if (Test-Path -LiteralPath $LegacyAgentsPath) {
    Add-Violation 'legacy-agents' '.agents/AGENTS.md must not exist; the root AGENTS.md is the only rules file.' 'Fix: Delete .agents/AGENTS.md and keep rules in the root AGENTS.md.'
}

# --- Rule 6: root AGENTS.md size --------------------------------------------------------

if (Test-Path -LiteralPath $RootAgentsPath -PathType Leaf) {
    $size = (Get-Item -LiteralPath $RootAgentsPath).Length
    if ($size -ge $AgentsMdMaxBytes) {
        Add-Violation 'agents-size' "AGENTS.md is $size bytes; it must be smaller than $AgentsMdMaxBytes bytes (24 KB)." "Fix: Shorten AGENTS.md to under 24 KB (move reference sections to skills or docs)."
    }
} else {
    Write-Output 'SKIP [agents-size] root AGENTS.md does not exist yet.'
}

# --- Rule 7: VERSION <=> CHANGELOG.md ---------------------------------------------------

if (Test-Path -LiteralPath $VersionPath -PathType Leaf) {
    $version = ([string](Get-Content -LiteralPath $VersionPath -Raw -Encoding utf8)).Trim()
    if (-not (Test-SemVer $version)) {
        Add-Violation 'version' "VERSION contains '$version'; expected X.Y.Z or X.Y.Z-rc.N (no 'v' prefix)." "Fix: Format VERSION as SemVer (e.g. 1.0.0 or 1.0.0-rc.1)."
    } elseif (Test-Path -LiteralPath $ChangelogPath -PathType Leaf) {
        $changelogText = [string](Get-Content -LiteralPath $ChangelogPath -Raw -Encoding utf8)
        $changelogText = [regex]::Replace($changelogText, '(?ms)^[ \t]*(```|~~~).*?^[ \t]*\1[^\n]*$', '')
        $topSection = [regex]::Matches($changelogText, '(?m)^##\s+\[(?<v>[^\]]+)\]') |
            ForEach-Object { $_.Groups['v'].Value.Trim() } |
            Where-Object { $_ -ne 'Unreleased' } |
            Select-Object -First 1
        if ($null -eq $topSection) {
            if ($version -ne '0.0.0') {
                Add-Violation 'version' "VERSION is $version, but CHANGELOG.md has no version sections." "Fix: Add '## [$version] - YYYY-MM-DD - <Title>' section to CHANGELOG.md."
            }
        } elseif ($topSection -cne $version) {
            Add-Violation 'version' "Top CHANGELOG.md section is [$topSection], but VERSION is $version." "Fix: Align top CHANGELOG.md section with VERSION ($version)."
        }
    }
} else {
    Write-Output 'SKIP [version] VERSION does not exist (Project).'
}

# --- Rule 8: legacy numeric quota phrasing ---------------------------------------------

$quotaRegex = [regex]'(?i)\b\d+\s*[–—-]\s*\d+\s+(?:questions|вопрос(?:а|ов)?)\b|ровно\s+\d+\s+раунд|\bapply its round quota\b|\binterview quotas\b'
$activeAgentFiles = [System.Collections.Generic.List[string]]::new()

if (Test-Path -LiteralPath $RootAgentsPath -PathType Leaf) {
    $activeAgentFiles.Add($RootAgentsPath)
}
if (Test-Path -LiteralPath $AgentsDir -PathType Container) {
    Get-ChildItem -LiteralPath $AgentsDir -File -Filter '*.md' |
        ForEach-Object { $activeAgentFiles.Add($_.FullName) }
}
if (Test-Path -LiteralPath $SkillsDir -PathType Container) {
    Get-ChildItem -LiteralPath $SkillsDir -File -Recurse -Filter '*.md' |
        ForEach-Object { $activeAgentFiles.Add($_.FullName) }
}

foreach ($filePath in ($activeAgentFiles | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { continue }
    $content = [string](Get-Content -LiteralPath $filePath -Raw -Encoding utf8)
    if ([string]::IsNullOrWhiteSpace($content)) { continue }
    $foundMatches = $quotaRegex.Matches($content)
    foreach ($match in $foundMatches) {
        Add-Violation 'quotas' "File '$(Get-RelativePath $filePath)' contains legacy numeric quota phrasing: '$($match.Value)'" "Fix: Replace numeric quota phrasing with mandatory round themes."
    }
}

# --- Rule 9: release skill in 'Только Шаблон' section -----------------------------------

if ($skillFolders -contains 'release') {
    if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
        $registryText = [string](Get-Content -LiteralPath $RegistryPath -Raw -Encoding utf8)
        if ($registryText -match '(?ms)##\s+Только Шаблон\s*\r?\n(?<section>.*)') {
            $templateOnlySection = $Matches['section']
            if ($templateOnlySection -notmatch '(?m)skills/release/SKILL\.md') {
                Add-Violation 'release-registry' "The 'release' skill exists, but is not listed in the '## Только Шаблон' section of .agents/SKILLS.md." "Fix: Move or add 'release' skill entry under '## Только Шаблон' in .agents/SKILLS.md."
            }
        } else {
            Add-Violation 'release-registry' "The 'release' skill exists, but the '## Только Шаблон' section is missing in .agents/SKILLS.md." "Fix: Add '## Только Шаблон' section with 'release' skill to .agents/SKILLS.md."
        }
    }
}

# --- Rule 10: bash script line endings and syntax --------------------------------------

if (Test-Path -LiteralPath $AgentsDir -PathType Container) {
    $shFiles = @(Get-ChildItem -LiteralPath $AgentsDir -File -Recurse -Filter '*.sh')
    $bashPath = $null
    if ($IsWindows -and -not [string]::IsNullOrEmpty($env:ProgramFiles)) {
        $gitBash = Join-Path $env:ProgramFiles 'Git' 'bin' 'bash.exe'
        if (Test-Path -LiteralPath $gitBash) {
            $bashPath = $gitBash
        }
    }
    if ($null -eq $bashPath) {
        $candidate = Get-Command 'bash' -ErrorAction SilentlyContinue
        if ($null -ne $candidate -and (-not $IsWindows -or $candidate.Source -notmatch '(?i)system32\\bash\.exe$')) {
            $bashPath = $candidate.Source
        }
    }

    foreach ($sh in $shFiles) {
        $bytes = [System.IO.File]::ReadAllBytes($sh.FullName)
        if ($bytes -contains 13) {
            Add-Violation 'bash-lf' "File '$(Get-RelativePath $sh.FullName)' contains CRLF line endings; bash scripts must use Unix LF." "Fix: Convert '$(Get-RelativePath $sh.FullName)' line endings to Unix LF."
        }
        if ($null -ne $bashPath) {
            $syntaxOutput = & $bashPath -n $sh.FullName 2>&1
            if ($LASTEXITCODE -ne 0) {
                Add-Violation 'bash-syntax' "File '$(Get-RelativePath $sh.FullName)' failed bash syntax check: $syntaxOutput" "Fix: Correct bash syntax errors in '$(Get-RelativePath $sh.FullName)'."
            }
        }
    }
}

# --- Rule 11: .claude/skills mirror sync -----------------------------------------------

$ClaudeSkillsDir = Join-Path $RepoRoot '.claude' 'skills'
if ((Test-Path -LiteralPath $ClaudeSkillsDir -PathType Container) -and (Test-Path -LiteralPath $SkillsDir -PathType Container)) {
    $srcSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    Get-ChildItem -LiteralPath $SkillsDir -File -Recurse -Force | ForEach-Object {
        [void]$srcSet.Add([System.IO.Path]::GetRelativePath($SkillsDir, $_.FullName).Replace('\', '/'))
    }

    $dstSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    Get-ChildItem -LiteralPath $ClaudeSkillsDir -File -Recurse -Force | ForEach-Object {
        [void]$dstSet.Add([System.IO.Path]::GetRelativePath($ClaudeSkillsDir, $_.FullName).Replace('\', '/'))
    }

    foreach ($rel in ($srcSet | Sort-Object)) {
        if (-not $dstSet.Contains($rel)) {
            Add-Violation 'claude-mirror' "Missing in .claude/skills/: '$rel'. Run .agents/scripts/Sync-ClaudeSkills.ps1." "Fix: Run .agents/scripts/Sync-ClaudeSkills.ps1."
            continue
        }
        $srcFile = Join-Path $SkillsDir $rel
        $dstFile = Join-Path $ClaudeSkillsDir $rel
        $same = ((Get-Item -LiteralPath $srcFile).Length -eq (Get-Item -LiteralPath $dstFile).Length) -and
                [System.Linq.Enumerable]::SequenceEqual([System.IO.File]::ReadAllBytes($srcFile), [System.IO.File]::ReadAllBytes($dstFile))
        if (-not $same) {
            Add-Violation 'claude-mirror' "Out-of-sync file '.claude/skills/$rel'. Run .agents/scripts/Sync-ClaudeSkills.ps1." "Fix: Run .agents/scripts/Sync-ClaudeSkills.ps1."
        }
    }

    foreach ($rel in ($dstSet | Sort-Object)) {
        if (-not $srcSet.Contains($rel)) {
            Add-Violation 'claude-mirror' "Stale file in .claude/skills/: '$rel'. Run .agents/scripts/Sync-ClaudeSkills.ps1." "Fix: Run .agents/scripts/Sync-ClaudeSkills.ps1."
        }
    }
}

# --- Rule 14: context-budget (AGENTS.md + CONTEXT.md <= 32 KiB) -------------------------

$contextBudgetMaxBytes = 32768
$totalContextBytes = 0
if (Test-Path -LiteralPath $RootAgentsPath -PathType Leaf) {
    $totalContextBytes += (Get-Item -LiteralPath $RootAgentsPath).Length
}
$contextMdPath = Join-Path $AgentsDir 'CONTEXT.md'
if (Test-Path -LiteralPath $contextMdPath -PathType Leaf) {
    $totalContextBytes += (Get-Item -LiteralPath $contextMdPath).Length
}
if ($totalContextBytes -gt $contextBudgetMaxBytes) {
    Add-Violation 'context-budget' "Combined size of AGENTS.md and .agents/CONTEXT.md is $totalContextBytes bytes; maximum allowed is $contextBudgetMaxBytes bytes (32 KiB)." "Fix: Shorten AGENTS.md and/or .agents/CONTEXT.md to fit within $contextBudgetMaxBytes bytes."
}

# --- Report -----------------------------------------------------------------------------

if ($script:Violations.Count -eq 0) {
    Write-Output "OK: $($skillFolders.Count) skills, Registry, flags and links are consistent."
    exit 0
}

Write-Output "FAIL: $($script:Violations.Count) violation(s):"
$script:Violations | ForEach-Object { Write-Output "  $_" }
exit 1
