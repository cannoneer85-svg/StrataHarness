# Template Coding Standards (StrataHarness)

This document defines the architectural, authoring, and engineering judgement standards for developing the StrataHarness Template itself. Automated `/code-review` checks changes along the **Standards** axis against this file.

> When a downstream Project is initialized with `Initialize-Project.ps1 -Mode New`, this file is automatically replaced by the project skeleton from `.agents/skills/init-project/templates/CODING_STANDARDS.md` (as declared in `.agents/skills/init-project/manifest.psd1`).

## 1. Agent Guidance & Skills (`writing-for-agents`)

- **Single Source of Truth:** Global routing rules, category thresholds, interview round themes, and stop-gate invariants live in the root [`AGENTS.md`](AGENTS.md). Stage-specific procedures live in the corresponding stage's `SKILL.md`. Avoid duplicating `AGENTS.md` invariants across stage skills unless a skill is designed to be invoked standalone and requires that context directly.
- **Progressive Disclosure:** Keep `AGENTS.md` and `SKILL.md` focused on the steps and rules needed on every run. Push templates, long checklists, and reference material down into `references/` or `templates/` files reached via explicit context pointers.
- **Positive Phrasing:** State instructions positively in terms of the target behavior. Reserve negations for hard guardrails that cannot be phrased positively, and pair them with the positive target action.
- **Prune No-Ops:** Do not add prose rules that models obey by default or that deterministic tooling (`Test-Template.ps1`, Pester, linters) already enforces.

## 2. PowerShell Scripts & Backward Compatibility

- **Update Mode Contract:** Changes to `.agents/skills/init-project/`, `.agents/SKILLS.md` format, or payload structure must preserve compatibility with `Initialize-Project.ps1 -Mode Update` for existing Projects, or explicitly flag a MAJOR version transition.
- **Cross-Platform Execution:** Scripts under `.agents/` must run cleanly on PowerShell 7+ across Windows, Linux, and macOS. Use `Join-Path` and `-LiteralPath` for filesystem operations, and keep all `.sh` files in Unix LF format.
- **Regex Group Isolation:** When parsing text with `-match`, always capture named groups into local variables (`$key = $Matches['key']`) immediately before executing any subsequent string or regex operations, as subsequent `-match` operations overwrite the automatic `$Matches` variable.

## 3. Two-Tier Testing & Fixture Isolation

- **Fast Verification During Implementation & Review:** Run `.agents/scripts/Test-Template.ps1` and targeted unit tests (`-Tag 'Unit'`) during implementation and after review fixes. Reserve the full integration suite (`-Tag 'Integration'`) for `/close-task` preflight, `/release -Plan`, and CI.
- **Fixture Isolation & Reuse:** All Pester tests must operate strictly inside `$TestDrive` fixtures and never mutate the live repository. Heavy integration test files should build immutable golden fixtures once in `BeforeAll` and clone them per `It` block rather than rebuilding git repositories from scratch on every test.
