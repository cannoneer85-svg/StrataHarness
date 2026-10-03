#Requires -Version 7.0
<#
.SYNOPSIS
    Makes .claude/skills/ an exact copy of .agents/skills/ for Claude Code.

.DESCRIPTION
    .agents/skills/ is the single source of truth (ADR 0002). Claude Code only reads
    .claude/skills/, so this script mirrors the source into it: copies new files,
    overwrites files whose content differs, and deletes files and folders that no
    longer exist in the source. Unchanged files are not touched, so a repeated run
    changes nothing. Nothing outside .claude/skills/ is modified.

    Prints one summary line: "Claude skills mirror: added N, updated N, removed N" (file counts).

.PARAMETER RepoRoot
    Repository root. Defaults to two levels above this script (.agents/scripts/ -> repo root).

.EXAMPLE
    pwsh .agents/scripts/Sync-ClaudeSkills.ps1
.EXAMPLE
    pwsh .agents/scripts/Sync-ClaudeSkills.ps1 -RepoRoot D:\path\to\project
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..' '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$sourceDir = Join-Path $root '.agents' 'skills'
$mirrorDir = Join-Path $root '.claude' 'skills'

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    throw "Source folder not found: $sourceDir"
}

function Get-RelativeFileSet([string]$Dir) {
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $Dir -PathType Container) {
        Get-ChildItem -LiteralPath $Dir -Recurse -File -Force | ForEach-Object {
            [void]$set.Add([IO.Path]::GetRelativePath($Dir, $_.FullName))
        }
    }
    return , $set
}

function Test-SameContent([string]$PathA, [string]$PathB) {
    if ((Get-Item -LiteralPath $PathA).Length -ne (Get-Item -LiteralPath $PathB).Length) { return $false }
    return (Get-FileHash -LiteralPath $PathA -Algorithm SHA256).Hash -eq
           (Get-FileHash -LiteralPath $PathB -Algorithm SHA256).Hash
}

$sourceFiles = Get-RelativeFileSet $sourceDir
$mirrorFiles = Get-RelativeFileSet $mirrorDir
$added = 0
$updated = 0
$removed = 0

foreach ($rel in $sourceFiles) {
    $from = Join-Path $sourceDir $rel
    $to = Join-Path $mirrorDir $rel
    if ($mirrorFiles.Contains($rel)) {
        if (Test-SameContent $from $to) { continue }
        $updated++
    }
    else {
        New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null
        $added++
    }
    Copy-Item -LiteralPath $from -Destination $to -Force
}

foreach ($rel in $mirrorFiles) {
    if ($sourceFiles.Contains($rel)) { continue }
    Remove-Item -LiteralPath (Join-Path $mirrorDir $rel) -Force
    $removed++
}

# Drop folders left empty. Deepest first, so a parent is checked after its children are gone.
if (Test-Path -LiteralPath $mirrorDir -PathType Container) {
    Get-ChildItem -LiteralPath $mirrorDir -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
        Remove-Item -Force
}

Write-Output "Claude skills mirror: added $added, updated $updated, removed $removed"
