# Changelog

All notable changes to this template are documented in this file. Newest versions come first.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the template follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). For a template, MAJOR means a change that breaks `Initialize-Project.ps1 -Mode Update` for existing projects (a removed or renamed skill, changed `Initialize-Project.ps1` parameters, a new skill Registry format, changed routes, stop gates or guardrails in `AGENTS.md`); MINOR adds a skill or capability; PATCH covers fixes, wording, documentation and CI. The full bump rules live in `docs/releasing.md`.

Each release section is titled `## [X.Y.Z] - YYYY-MM-DD - <release title>` and may contain the subsections Breaking, Added, Changed, Fixed, Removed and Other; empty subsections are omitted.

## [Unreleased]

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

