# Changelog

All notable changes to this template are documented in this file. Newest versions come first.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the template follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). For a template, MAJOR means a change that breaks `Initialize-Project.ps1 -Mode Update` for existing projects (a removed or renamed skill, changed `Initialize-Project.ps1` parameters, a new skill Registry format, changed routes, stop gates or guardrails in `AGENTS.md`); MINOR adds a skill or capability; PATCH covers fixes, wording, documentation and CI. The full bump rules live in `docs/releasing.md`.

Each release section is titled `## [X.Y.Z] - YYYY-MM-DD - <release title>` and may contain the subsections Breaking, Added, Changed, Fixed, Removed and Other; empty subsections are omitted.

## [Unreleased]

## [1.2.1] - 2026-10-14 - Optimize release apply mode with conditional test caching and progress logging

### Changed
- Skip redundant full Pester test suite in `Invoke-Release.ps1 -Apply` when release plan was validated on the exact same commit, reducing apply duration from 6.5 minutes to ~2 seconds while preserving structural template validation.
- Guard test-skip trust boundary by recording checks validation state in `plan.json`, ensuring Pester is never skipped if `-Plan` bypassed checks.
- Add structured console progress logging (`[release] ...`) across all release modes (`-Plan`, `-Apply`, `-PushOnly`, `-Undo`) to eliminate perceived freezes.
- Configure Pester execution with `Run.Exit = $true` to ensure proper non-zero exit codes on failures without leaving stray NUnit XML artifacts.

## [1.2.0] - 2026-10-14 - Upstream skills backport, retro & pr skills, and bash validation

### Added
- **Skills `retro` and `pr`**: Introduced the `retro` skill for session retrospectives focused on turning mechanical friction into deterministic automated checks while safeguarding `AGENTS.md` invariants, and the `pr` skill for structured Show-Me, Evidence, and Merge Danger PR descriptions without unauthorized push.
- **Bash LF and syntax validation (Rule 10)**: Added Rule 10 to `Test-Template.ps1` to automatically enforce Unix LF line endings and validate `bash -n` syntax across all shell scripts under `.agents/`.

### Fixed
- **Interactive wizard runtime**: Resolved 10 runtime defects in `wizard/template.sh`, including Readline arrow navigation (`read -e`), robust single-quote escaping in `.env`, graceful EOF termination, and execution isolation via `run_wizard "$@"; exit`.
- **Tracker CLI templates and label setup**: Replaced broken `gh pr list` author association queries with paginated `gh api` calls, corrected GitLab CLI flags to `-O json`, added sub-issue instructions, and automated triage label creation in `init-project`.
- **Core skill safeguards**: Hardened `claude-handoff` against shell interpolation via temporary file summary transfer, added forced mutation `diff` verification in `diagnosing-bugs`, required seam tradeoff notes in `tdd`, added round separators and affirmative phrasing in `grilling`, and eliminated tracker hallucinations in `wayfinder`.

### Changed
- **Skill Registry and notices**: Registered 41 skills in `.agents/SKILLS.md`, synchronized Claude Code mirror, and updated `THIRD_PARTY_NOTICES.md` to track 35 adapted skills anchored to upstream commit `49dd158` (`v1.3.1`).
- **Audit and documentation**: Completed comprehensive audit of upstream `mattpocock/skills` (`docs/analysis/2026-10-14-mattpocock-skills-audit.md`) and specification `docs/specs/0005-skills-backport-spec.md`.

## [1.1.0] - 2026-10-13 - Minimal-Diff Discipline, Process Hardening, and Multi-Language Support

### Added
- **Minimal-Diff Discipline**: Added the `minimal-diff` skill with a 7-step solution ladder, conscious tradeoff documentation (`// TRADEOFF`), and strict Forbidden Zones (security, authorization, boundary validation, error handling, contract compatibility, and behavior tests).
- **Thematic Interview Rounds**: Replaced brittle numeric question quotas with mandatory round themes across task categories, added immediate user override via stop phrases («хватит / пиши спеку»), and established an escalation threshold for Minor tasks.
- **Three-Axis Code Review**: Expanded `code-review` to incorporate minimal-diff and duplication audits, plus an optional third `Adversary` axis for security-critical tasks.
- **Two-Tier Testing Standards**: Introduced test suite separation in `CODING_STANDARDS.md` and tagged template tests into fast Unit (< 20s) and Integration suites, preventing agent stalling during implementation.
- **Multi-Language READMEs**: Added translations for Simplified Chinese (`zh-CN`), Spanish (`es`), French (`fr`), and Portuguese (`pt-PT`) with a top-level language switcher.

### Fixed
- **Cross-Platform Test Fixtures**: Resolved cross-platform dot-folder traversal and dynamic SemVer parsing issues in test helpers.

### Other
- **Documentation & Analysis**: Added in-depth comparison with agent harness analogs, clarified tracker ticket lifecycles (`ready-for-human` to `in-progress`), and updated agent invocation guidelines.

## [1.0.0] - 2026-10-04 - Initial Open Source Release

### Added
- **Multi-harness AI agent support:** Native support and configuration for Google Antigravity, Anthropic Claude Code, OpenAI Codex, and Cursor with unified rules (`AGENTS.md`) and automatic skill mirroring (`CLAUDE.md`).
- **Comprehensive 6-stage development lifecycle:** Standardized workflow (`Step 0 -> Interview -> Spec -> Tickets -> Implementation -> Review -> Close`) with strict stop gates and context budget management.
- **Skill library:** 38 specialized skills covering TDD, codebase design, domain modeling, bug diagnosis, research, writing, and git automation.
- **Project initialization & update machinery (`Initialize-Project.ps1`):** Flexible setup modes (`New`, `Adopt`, `Update`, `SetTracker`) with automatic template isolation, SemVer compatibility checks, and changelog diffing.
- **Automated release engineering (`/release`):** SemVer-based release planning from Conventional Commits, interactive release notes editing, atomic tagging, and direct GitHub publishing.
- **Continuous Integration & Contributor Experience:** GitHub Actions CI matrix across Windows and Ubuntu runners, Conventional Commits PR title validation, Dependabot automation, and English contributor templates.
- **Public Open Source documentation:** Bilingual documentation (`README.md` and `README.ru.md`), `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` (MIT), and `THIRD_PARTY_NOTICES.md`.

