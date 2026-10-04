#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Shared SemVer helpers (.agents/scripts/SemVer.ps1): parsing and comparison of the
# Template Version, reused by Test-Template, Initialize-Project and the release script.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' '.agents' 'scripts' 'SemVer.ps1')
}

Describe 'Test-SemVer' {
    It 'accepts <_>' -ForEach @('0.0.0', '1.0.0', '1.2.3', '10.20.30', '1.1.0-rc.1', '2.0.0-rc.12') {
        Test-SemVer $_ | Should -BeTrue
    }

    It 'rejects <_>' -ForEach @(
        '', ' ', 'v1.0.0', '1.0', '1', '1.0.0.0', '01.0.0', '1.02.0', '1.0.0-rc', '1.0.0-rc.', '1.0.0-beta.1',
        '1.0.0-rc.01', '1.0.0+build', 'abc', '1.0.0 ', '2026-10-03', '2026-10-03 821c2a7'
    ) {
        Test-SemVer $_ | Should -BeFalse
    }
}

Describe 'ConvertFrom-SemVer' {
    It 'parses a release version' {
        $v = ConvertFrom-SemVer '1.2.3'
        $v.Major | Should -Be 1
        $v.Minor | Should -Be 2
        $v.Patch | Should -Be 3
        $v.Rc | Should -BeNullOrEmpty
        $v.IsLegacy | Should -BeFalse
        $v.Text | Should -Be '1.2.3'
    }

    It 'parses a release candidate' {
        $v = ConvertFrom-SemVer '1.1.0-rc.2'
        $v.Major | Should -Be 1
        $v.Minor | Should -Be 1
        $v.Patch | Should -Be 0
        $v.Rc | Should -Be 2
        $v.Text | Should -Be '1.1.0-rc.2'
    }

    It 'throws on garbage' {
        { ConvertFrom-SemVer 'not-a-version' } | Should -Throw
        { ConvertFrom-SemVer 'v1.0.0' } | Should -Throw
    }
}

Describe 'ConvertFrom-TemplateVersion' {
    It 'parses a bare SemVer' {
        (ConvertFrom-TemplateVersion '1.2.3').Text | Should -Be '1.2.3'
    }

    It 'parses the Registry form <_>' -ForEach @('v1.2.3', 'v1.2.3 (abc1234)', 'v1.2.3-rc.1 (abc1234)') {
        $v = ConvertFrom-TemplateVersion $_
        $v.IsLegacy | Should -BeFalse
        $v.Major | Should -Be 1
        $v.Minor | Should -Be 2
        $v.Patch | Should -Be 3
    }

    It 'returns the sha of the Registry form' {
        (ConvertFrom-TemplateVersion 'v1.2.3 (abc1234)').Sha | Should -Be 'abc1234'
        (ConvertFrom-TemplateVersion 'v1.2.3').Sha | Should -BeNullOrEmpty
    }

    It 'parses the legacy form <_>' -ForEach @('2026-10-03', '2026-10-03 821c2a7') {
        $v = ConvertFrom-TemplateVersion $_
        $v.IsLegacy | Should -BeTrue
        $v.LegacyDate | Should -Be '2026-10-03'
    }

    It 'returns the sha of the legacy form' {
        (ConvertFrom-TemplateVersion '2026-10-03 821c2a7').Sha | Should -Be '821c2a7'
    }

    It 'throws on garbage <_>' -ForEach @('', 'latest', 'v1.0', '1.0.0-beta', '2026-13-45x') {
        { ConvertFrom-TemplateVersion $_ } | Should -Throw
    }
}

Describe 'Compare-SemVer' {
    It '<Left> vs <Right> is <Expected>' -ForEach @(
        @{ Left = '1.0.0'; Right = '1.0.0'; Expected = 0 }
        @{ Left = '1.0.0'; Right = '1.0.1'; Expected = -1 }
        @{ Left = '1.1.0'; Right = '1.0.9'; Expected = 1 }
        @{ Left = '2.0.0'; Right = '1.99.99'; Expected = 1 }
        @{ Left = '1.10.0'; Right = '1.9.0'; Expected = 1 }
        @{ Left = '1.1.0-rc.1'; Right = '1.1.0'; Expected = -1 }
        @{ Left = '1.1.0'; Right = '1.1.0-rc.1'; Expected = 1 }
        @{ Left = '1.1.0-rc.1'; Right = '1.1.0-rc.2'; Expected = -1 }
        @{ Left = '1.1.0-rc.10'; Right = '1.1.0-rc.9'; Expected = 1 }
        @{ Left = '1.1.0-rc.1'; Right = '1.0.0'; Expected = 1 }
        @{ Left = 'v1.2.0 (abc1234)'; Right = '1.2.0'; Expected = 0 }
        @{ Left = '2026-10-03 821c2a7'; Right = '1.0.0'; Expected = -1 }
        @{ Left = '1.0.0'; Right = '2026-10-03'; Expected = 1 }
        @{ Left = '2026-10-03'; Right = '0.0.0'; Expected = -1 }
        @{ Left = '2026-10-03'; Right = '2026-10-04 aaa1111'; Expected = -1 }
        @{ Left = '2026-10-03 bbb2222'; Right = '2026-10-03 aaa1111'; Expected = 0 }
    ) {
        Compare-SemVer $Left $Right | Should -Be $Expected
    }

    It 'accepts parsed objects' {
        Compare-SemVer (ConvertFrom-SemVer '1.0.0') (ConvertFrom-SemVer '1.0.0-rc.1') | Should -Be 1
    }

    It 'throws on garbage' {
        { Compare-SemVer 'garbage' '1.0.0' } | Should -Throw
    }
}

Describe 'Step-SemVer' {
    It '<Version> bumped by <Bump> is <Expected>' -ForEach @(
        @{ Version = '1.0.0'; Bump = 'patch'; Expected = '1.0.1' }
        @{ Version = '1.0.0'; Bump = 'minor'; Expected = '1.1.0' }
        @{ Version = '1.0.0'; Bump = 'major'; Expected = '2.0.0' }
        @{ Version = '1.2.3'; Bump = 'patch'; Expected = '1.2.4' }
        @{ Version = '1.2.3'; Bump = 'minor'; Expected = '1.3.0' }
        @{ Version = '1.2.3'; Bump = 'major'; Expected = '2.0.0' }
        @{ Version = '0.0.0'; Bump = 'major'; Expected = '1.0.0' }
        @{ Version = '0.0.0'; Bump = 'minor'; Expected = '0.1.0' }
        @{ Version = '0.0.0'; Bump = 'patch'; Expected = '0.0.1' }
        @{ Version = 'v1.2.3'; Bump = 'minor'; Expected = '1.3.0' }
        @{ Version = 'v1.2.3 (abc1234)'; Bump = 'major'; Expected = '2.0.0' }
    ) {
        Step-SemVer $Version $Bump | Should -Be $Expected
    }

    It 'accepts parsed objects' {
        $parsed = ConvertFrom-SemVer '1.2.3'
        Step-SemVer $parsed 'minor' | Should -Be '1.3.0'
    }

    It 'throws on invalid bump' {
        { Step-SemVer '1.0.0' 'invalid' } | Should -Throw
    }
}
