# Changelog

All notable changes to this template are documented in this file. Newest versions come first.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the template follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). For a template, MAJOR means a change that breaks `Initialize-Project.ps1 -Mode Update` for existing projects (a removed or renamed skill, changed `Initialize-Project.ps1` parameters, a new skill Registry format, changed routes, stop gates or guardrails in `AGENTS.md`); MINOR adds a skill or capability; PATCH covers fixes, wording, documentation and CI. The full bump rules live in `docs/releasing.md`.

Each release section is titled `## [X.Y.Z] - YYYY-MM-DD - <release title>` and may contain the subsections Breaking, Added, Changed, Fixed, Removed and Other; empty subsections are omitted.

## [Unreleased]

## [1.0.0] - 2026-10-04 - Initial Open Source Release

### Added
- **Multi-harness AI agent support:** Native support and configuration for Google Antigravity, Anthropic Claude Code, OpenAI Codex, and Cursor with unified rules (`AGENTS.md`) and automatic skill mirroring (`CLAUDE.md`).
- **Comprehensive 6-stage development lifecycle:** Standardized workflow (`Step 0 -> Interview -> Spec -> Tickets -> Implementation -> Review -> Close`) with strict stop gates and context budget management.
- **Skill library:** 38 specialized skills covering TDD, codebase design, domain modeling, bug diagnosis, research, writing, and git automation.
- **Project initialization & update machinery (`Initialize-Project.ps1`):** Flexible setup modes (`New`, `Adopt`, `Update`, `SetTracker`) with automatic template isolation, SemVer compatibility checks, and changelog diffing.
- **Automated release engineering (`/release`):** SemVer-based release planning from Conventional Commits, interactive release notes editing, atomic tagging, and direct GitHub publishing.
- **Continuous Integration & Contributor Experience:** GitHub Actions CI matrix across Windows and Ubuntu runners, Conventional Commits PR title validation, Dependabot automation, and English contributor templates.
- **Public Open Source documentation:** Bilingual documentation (`README.md` and `README.ru.md`), `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` (MIT), and `THIRD_PARTY_NOTICES.md`.

