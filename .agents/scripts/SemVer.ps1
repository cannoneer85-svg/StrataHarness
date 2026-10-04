<#
.SYNOPSIS
    Shared SemVer helpers for the Template Version (spec 0002 D1, ADR 0004).

.DESCRIPTION
    Dot-source this file to get:
      Test-SemVer                - $true if a string is a strict Template SemVer: `X.Y.Z` or `X.Y.Z-rc.N`
                                   (no `v` prefix, no leading zeros, no other pre-release or build tags).
      ConvertFrom-SemVer         - parses a strict SemVer string; throws on anything else.
      ConvertFrom-TemplateVersion - parses any `template-version` value: a strict SemVer, the Registry
                                   form `vX.Y.Z[-rc.N][ (<sha>)]`, or the legacy form `YYYY-MM-DD[ <sha>]`;
                                   throws on anything else.
      Compare-SemVer             - compares two versions (strings or parsed objects); returns -1, 0 or 1.
                                   A release candidate sorts below the release of the same X.Y.Z.
                                   A legacy `date[ sha]` version sorts below every SemVer (hence below 1.0.0);
                                   two legacy versions compare by date.
      Step-SemVer                - calculates the next version string ('X.Y.Z') given a version and
                                   a bump type ('major', 'minor', 'patch').

    Parsed versions are objects with: Major, Minor, Patch (int), Rc (int or $null), IsLegacy (bool),
    LegacyDate (string or $null), Sha (string or $null), Text (canonical `X.Y.Z[-rc.N]`, or the date).

    Used by Test-Template.ps1, Initialize-Project.ps1 and the release script.

.EXAMPLE
    . (Join-Path $PSScriptRoot 'SemVer.ps1')
    Compare-SemVer '1.1.0-rc.1' '1.1.0'   # -1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Regex fragments are functions, not variables, so dot-sourcing does not depend on caller scopes.
function Get-SemVerPattern { '(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-rc\.(?<rc>0|[1-9]\d*))?' }
function Get-ShaPattern { '[0-9a-fA-F]{4,40}' }

function New-SemVerObject {
    param([System.Text.RegularExpressions.Match]$Match, [string]$Sha)
    $rc = if ($Match.Groups['rc'].Success) { [int]$Match.Groups['rc'].Value } else { $null }
    $text = '{0}.{1}.{2}' -f $Match.Groups['major'].Value, $Match.Groups['minor'].Value, $Match.Groups['patch'].Value
    if ($null -ne $rc) { $text += "-rc.$rc" }
    return [pscustomobject]@{
        Major      = [int]$Match.Groups['major'].Value
        Minor      = [int]$Match.Groups['minor'].Value
        Patch      = [int]$Match.Groups['patch'].Value
        Rc         = $rc
        IsLegacy   = $false
        LegacyDate = $null
        Sha        = if ([string]::IsNullOrEmpty($Sha)) { $null } else { $Sha }
        Text       = $text
    }
}

function Test-SemVer {
    [OutputType([bool])]
    param([Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Version)
    return [regex]::IsMatch($Version, "\A$(Get-SemVerPattern)\z")
}

function ConvertFrom-SemVer {
    param([Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Version)
    $match = [regex]::Match($Version, "\A$(Get-SemVerPattern)\z")
    if (-not $match.Success) {
        throw "Invalid SemVer '$Version': expected X.Y.Z or X.Y.Z-rc.N."
    }
    return New-SemVerObject -Match $match
}

function ConvertFrom-TemplateVersion {
    param([Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Value)
    $trimmed = $Value.Trim()

    $match = [regex]::Match($trimmed, "\Av?$(Get-SemVerPattern)(?:\s+\(?(?<sha>$(Get-ShaPattern))\)?)?\z")
    if ($match.Success) {
        return New-SemVerObject -Match $match -Sha $match.Groups['sha'].Value
    }

    $legacy = [regex]::Match($trimmed, "\A(?<date>\d{4}-\d{2}-\d{2})(?:\s+\(?(?<sha>$(Get-ShaPattern))\)?)?\z")
    if ($legacy.Success) {
        $date = $legacy.Groups['date'].Value
        return [pscustomobject]@{
            Major      = 0
            Minor      = 0
            Patch      = 0
            Rc         = $null
            IsLegacy   = $true
            LegacyDate = $date
            Sha        = if ($legacy.Groups['sha'].Success) { $legacy.Groups['sha'].Value } else { $null }
            Text       = $date
        }
    }

    throw "Invalid template version '$Value': expected X.Y.Z[-rc.N], vX.Y.Z[-rc.N] (<sha>) or YYYY-MM-DD[ <sha>]."
}

function Compare-SemVer {
    [OutputType([int])]
    param(
        [Parameter(Mandatory, Position = 0)]$Left,
        [Parameter(Mandatory, Position = 1)]$Right
    )
    $a = if ($Left -is [string]) { ConvertFrom-TemplateVersion $Left } else { $Left }
    $b = if ($Right -is [string]) { ConvertFrom-TemplateVersion $Right } else { $Right }

    if ($a.IsLegacy -or $b.IsLegacy) {
        if ($a.IsLegacy -and $b.IsLegacy) { return [math]::Sign([string]::CompareOrdinal($a.LegacyDate, $b.LegacyDate)) }
        if ($a.IsLegacy) { return -1 }
        return 1
    }

    foreach ($part in 'Major', 'Minor', 'Patch') {
        if ($a.$part -ne $b.$part) { return [math]::Sign($a.$part - $b.$part) }
    }
    # A release (no rc) is greater than any release candidate of the same X.Y.Z.
    if ($null -eq $a.Rc -and $null -eq $b.Rc) { return 0 }
    if ($null -eq $a.Rc) { return 1 }
    if ($null -eq $b.Rc) { return -1 }
    return [math]::Sign($a.Rc - $b.Rc)
}

function Step-SemVer {
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]$Version,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$Bump
    )
    $v = if ($Version -is [string]) { ConvertFrom-TemplateVersion $Version } else { $Version }
    $b = $Bump.ToLowerInvariant()
    switch ($b) {
        'major' {
            return '{0}.0.0' -f ($v.Major + 1)
        }
        'minor' {
            return '{0}.{1}.0' -f $v.Major, ($v.Minor + 1)
        }
        'patch' {
            return '{0}.{1}.{2}' -f $v.Major, $v.Minor, ($v.Patch + 1)
        }
    }
}
