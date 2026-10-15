# Changelog

All notable changes to this template are documented in this file. Newest versions come first.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the template follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). For a template, MAJOR means a change that breaks `Initialize-Project.ps1 -Mode Update` for existing projects (a removed or renamed skill, changed `Initialize-Project.ps1` parameters, a new skill Registry format, changed routes, stop gates or guardrails in `AGENTS.md`); MINOR adds a skill or capability; PATCH covers fixes, wording, documentation and CI. The full bump rules live in `docs/releasing.md`.

Each release section is titled `## [X.Y.Z] - YYYY-MM-DD - <release title>` and may contain the subsections Breaking, Added, Changed, Fixed, Removed and Other; empty subsections are omitted.

## [Unreleased]

## [1.4.2] - 2026-10-15 - Ticket map colour enforcement, stop-gate tool calls, and Codex budget docs

### Fixed
- **Ticket map Mermaid colour classes and legend enforcement (`to-tickets`):** Require reading `references/tickets-map-template.md` before drawing the ticket dependency graph in Step 4 (`Quiz the user`) and explicitly mandate short node labels (`T<NN>["<NN> <short title>"]`), all four fixed `classDef` lines (`ready`, `inprogress`, `done`, `blocked`), initial `ready`/`blocked` node class assignments, and the status legend line across Steps 4, 5, and 7.
- **Interactive stop-gate tool invocation (`AGENTS.md`):** Require calling the harness's interactive question tool (`ask_question` / `AskUserQuestion`) in the same turn immediately after writing out the full stage report, passing continuation options strictly as selectable tool choices rather than a plain-text list.

### Other
- **OpenAI Codex progressive disclosure budget documentation:** Clarify the platform origin of the 8,000-character total skill description budget in `Test-Template.ps1` violation hints and `SKILL-MECHANICS.md` (`### Description limits and context budget`).

## [1.4.1] - 2026-10-15 - Sequential report-then-question stop-gate rule

### Changed
- **Stop-gate report sequence and cross-harness phrasing:** Replace simultaneous "same-turn / alongside" wording with a strict two-step sequence across `AGENTS.md` and stage skills (`analyze`, `grill-with-docs`, `implement`, `code-review`, `release`): agents must first write out the complete stage report from start to finish in the message body, and only after finishing the report text invoke the harness's interactive question tool (removing hardcoded vendor-specific tool names).

## [1.4.0] - 2026-10-15 - Harness P1/P2 improvements and stop-gate text precedence

### Added
- **Platform limits and fix hints in validator:** Enforce real parser limits in `Test-Template.ps1` (`yaml-frontmatter` colon-space quoting, `description-length` <= 1024 / <= 8000 total budget, `context-budget` <= 32 KiB for `AGENTS.md` and `CONTEXT.md`), accompanied by explicit `Fix: ...` remediation hints for all 14 rules.
- **Orchestrator compaction recovery and rulings log:** Standardize `## Rulings & Decisions` and `## Spec AC Coverage` sections in ticket maps, introduce non-destructive recovery for in-progress tickets during compaction without `git reset`, and formalize deviation reporting via `Expected / Found / Why`.
- **Evidence-based completion and test tracing:** Require explicit `[auto]` and `[manual]` prefixes on acceptance criteria across specs and tickets, enforce a spec coverage verification matrix in `to-tickets`, and mandate an `Evidence Table` in `implement` completion.
- **Review false-positive suppression and rule citations:** Establish a closed `False Positives to Suppress` catalog in `code-review` and mandate exact standard/rule quotes for `hard violation` findings with deterministic aggregator filtering.
- **Silent investigation and Step 0 signals:** Formalize repository pre-investigation (`Silent Investigation`) in `grill-with-docs` before Round 1, and refine Category selection signals in `AGENTS.md` (footprint, intent gaps, irreversible actions).
- **Stop-gate mandatory text precedence:** Enforce that stage deliverables and reports must be generated directly in the message body on every stop gate before invoking interactive question tools, preventing obscured reports.

### Changed
- **PowerShell standards:** Document mandatory immediate local capture of regex named groups (`$Matches`) in `CODING_STANDARDS.md` to prevent silent capture overwrites across chained `-match` statements.

## [1.3.1] - 2026-10-15 - Template coding standards, Claude mirror validation, and fixture caching

### Added
- **Root `CODING_STANDARDS.md` for the Template**: Add an English `CODING_STANDARDS.md` at the repository root defining judgement-call standards for `/code-review` (`writing-for-agents` single source of truth, progressive disclosure, `-Mode Update` compatibility, and two-tier testing / fixture isolation).
- **Claude skills mirror sync check (Rule 11)**: Add Rule 11 (`claude-mirror`) to `Test-Template.ps1` and unit tests in `tests/Test-Template.Tests.ps1` to deterministically verify that `.claude/skills/` matches `.agents/skills/` when present.

### Changed
- **Integration test fixture caching & byte comparison**: Cache golden `New` and `Update` fixtures in `BeforeAll` and replace `byte[]` pipeline unrolling in `Should -Be` with `Enumerable.SequenceEqual` in `tests/Initialize-Project.Tests.ps1`, cutting test execution time in half and eliminating git CRLF warnings.

## [1.3.0] - 2026-10-15 - Interactive stop-gate confirmations across agent harnesses

### Added
- **Interactive stop-gate confirmations**: Require calling the harness's interactive question tool (Antigravity `ask_question`, Claude Code `AskUserQuestion`) at every stop gate (Step 0, Stages 1–5, Analysis, and Release) alongside the stage report, with automatic fallback to plain text in harnesses without such a tool.
- **Standardized stop-gate button options**: Define a 2-option confirmation pattern (`(Recommended)` approve and proceed vs. request adjustments/clarifications) for Step 0 and confirmation stop gates (Stages 1–4, Analysis, Release), and selectable next-step choices (`/close-task`, `/handoff`, further edits, `/retro`) at the Stage 5 (Review) stop gate.

### Changed
- **Hard guardrail button equivalence**: Recognize explicit selection of `/close-task`, `/handoff`, or release confirmation buttons in the interactive stop-gate prompt as an explicit user command.
- **Cross-harness question tool references**: Synchronize `Claude Code: AskUserQuestion` alongside `Antigravity: ask_question` in `AGENTS.md`, `grill-with-docs`, and `analyze`.

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

