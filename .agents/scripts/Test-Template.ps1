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

function Add-Violation([string]$Rule, [string]$Message) {
    $script:Violations.Add("[$Rule] $Message")
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
        ForEach-Object { Add-Violation 'registry' "Skill '$($_.Name)' is listed $($_.Count) times in .agents/SKILLS.md." }
} else {
    Add-Violation 'registry' 'Registry .agents/SKILLS.md is missing.'
}

foreach ($folder in $skillFolders | Where-Object { $_ -notin $registrySkills }) {
    Add-Violation 'registry' "Skill folder '.agents/skills/$folder' is not listed in .agents/SKILLS.md."
}
foreach ($listed in $registrySkills | Sort-Object -Unique | Where-Object { $_ -notin $skillFolders }) {
    Add-Violation 'registry' "Registry lists '$listed', but folder '.agents/skills/$listed' does not exist."
}

# --- Rules 2 and 3: frontmatter name and manual-invocation flags ------------------------

foreach ($folder in $skillFolders) {
    $skillMd = Join-Path $SkillsDir $folder 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
        Add-Violation 'name' "'.agents/skills/$folder/SKILL.md' is missing."
        continue
    }

    $frontmatter = Get-Frontmatter $skillMd
    if ($null -eq $frontmatter) {
        Add-Violation 'name' "'.agents/skills/$folder/SKILL.md' has no YAML frontmatter."
        continue
    }

    $name = Get-YamlScalar $frontmatter 'name'
    if ($name -cne $folder) {
        Add-Violation 'name' "'.agents/skills/$folder/SKILL.md' has name '$name', expected '$folder'."
    }

    $manualInSkill = (Get-YamlScalar $frontmatter 'disable-model-invocation') -eq 'true'

    $openaiYaml = Join-Path $SkillsDir $folder 'agents' 'openai.yaml'
    $manualInYaml = $false
    if (Test-Path -LiteralPath $openaiYaml -PathType Leaf) {
        $yamlText = Get-Content -LiteralPath $openaiYaml -Raw -Encoding utf8
        $manualInYaml = (Get-YamlScalar ([string]$yamlText) 'allow_implicit_invocation') -eq 'false'
    }

    if ($manualInSkill -and -not $manualInYaml) {
        Add-Violation 'flags' "'$folder': SKILL.md has 'disable-model-invocation: true', but agents/openai.yaml lacks 'policy.allow_implicit_invocation: false'."
    } elseif ($manualInYaml -and -not $manualInSkill) {
        Add-Violation 'flags' "'$folder': agents/openai.yaml has 'allow_implicit_invocation: false', but SKILL.md lacks 'disable-model-invocation: true'."
    }
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
            Add-Violation 'links' "$(Get-RelativePath $source): broken link '$target'."
        }
    }
}

# --- Rule 5: legacy .agents/AGENTS.md ---------------------------------------------------

if (Test-Path -LiteralPath $LegacyAgentsPath) {
    Add-Violation 'legacy-agents' '.agents/AGENTS.md must not exist; the root AGENTS.md is the only rules file.'
}

# --- Rule 6: root AGENTS.md size --------------------------------------------------------

if (Test-Path -LiteralPath $RootAgentsPath -PathType Leaf) {
    $size = (Get-Item -LiteralPath $RootAgentsPath).Length
    if ($size -ge $AgentsMdMaxBytes) {
        Add-Violation 'agents-size' "AGENTS.md is $size bytes; it must be smaller than $AgentsMdMaxBytes bytes (24 KB)."
    }
} else {
    Write-Output 'SKIP [agents-size] root AGENTS.md does not exist yet.'
}

# --- Rule 7: VERSION <=> CHANGELOG.md ---------------------------------------------------

if (Test-Path -LiteralPath $VersionPath -PathType Leaf) {
    $version = ([string](Get-Content -LiteralPath $VersionPath -Raw -Encoding utf8)).Trim()
    if (-not (Test-SemVer $version)) {
        Add-Violation 'version' "VERSION contains '$version'; expected X.Y.Z or X.Y.Z-rc.N (no 'v' prefix)."
    } elseif (Test-Path -LiteralPath $ChangelogPath -PathType Leaf) {
        $changelogText = [string](Get-Content -LiteralPath $ChangelogPath -Raw -Encoding utf8)
        $changelogText = [regex]::Replace($changelogText, '(?ms)^[ \t]*(```|~~~).*?^[ \t]*\1[^\n]*$', '')
        $topSection = [regex]::Matches($changelogText, '(?m)^##\s+\[(?<v>[^\]]+)\]') |
            ForEach-Object { $_.Groups['v'].Value.Trim() } |
            Where-Object { $_ -ne 'Unreleased' } |
            Select-Object -First 1
        if ($null -eq $topSection) {
            if ($version -ne '0.0.0') {
                Add-Violation 'version' "VERSION is $version, but CHANGELOG.md has no version sections."
            }
        } elseif ($topSection -cne $version) {
            Add-Violation 'version' "Top CHANGELOG.md section is [$topSection], but VERSION is $version."
        }
    }
} else {
    Write-Output 'SKIP [version] VERSION does not exist (Project).'
}

# --- Rule 8: release skill in 'Только Шаблон' section -----------------------------------

if ($skillFolders -contains 'release') {
    if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
        $registryText = [string](Get-Content -LiteralPath $RegistryPath -Raw -Encoding utf8)
        if ($registryText -match '(?ms)##\s+Только Шаблон\s*\r?\n(?<section>.*)') {
            $templateOnlySection = $Matches['section']
            if ($templateOnlySection -notmatch '(?m)skills/release/SKILL\.md') {
                Add-Violation 'release-registry' "The 'release' skill exists, but is not listed in the '## Только Шаблон' section of .agents/SKILLS.md."
            }
        } else {
            Add-Violation 'release-registry' "The 'release' skill exists, but the '## Только Шаблон' section is missing in .agents/SKILLS.md."
        }
    }
}

# --- Report -----------------------------------------------------------------------------

if ($script:Violations.Count -eq 0) {
    Write-Output "OK: $($skillFolders.Count) skills, Registry, flags and links are consistent."
    exit 0
}

Write-Output "FAIL: $($script:Violations.Count) violation(s):"
$script:Violations | ForEach-Object { Write-Output "  $_" }
exit 1
