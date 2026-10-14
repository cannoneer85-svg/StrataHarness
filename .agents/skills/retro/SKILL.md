---
name: retro
description: Run a retrospective on a session to find actionable improvements to the agent's environment.
disable-model-invocation: true
---

# Retrospective — Environment Improvement

Run a retrospective after an implementation session, bug diagnosis, or review to systematically identify and eliminate friction in the agent's working environment. The objective is to make future agent sessions faster, more deterministic, and less prone to repeated investigation or review friction.

A retrospective improves the **agent environment**, not the code written during the task.

## The Core Rule: Deterministic Checks over Prose

> **Convert mechanical violations into deterministic automated checks.**

Whenever the agent or reviewer caught mechanical mistakes — such as formatting, import sorting, forbidden APIs, broken typings, syntax conventions, or file naming — **never add prose instructions to `CODING_STANDARDS.md`**. Prose rules inflate context load, decay over time, and leave compliance to chance.

Instead, enforce mechanical rules through automated, deterministic tooling:
- **Linters and formatters:** ESLint, Biome, Ruff, PSScriptAnalyzer, Prettier.
- **Type checks and compiler flags:** TypeScript strict mode, pyright/mypy, compiler warnings treated as errors.
- **Pre-commit hooks:** Husky, lint-staged, git pre-commit hooks.
- **Automated test assertions:** Unit tests, integration tests, or Pester test suites verifying repository invariants.
- **CI workflows:** GitHub Actions / GitLab CI jobs blocking pull requests on violations.

If the repository lacks pre-commit hooks or CI, flag that missing infrastructure as an environment friction item in the retrospective.

`CODING_STANDARDS.md` (or `CONTRIBUTING.md`) is strictly reserved for **human judgement calls**: architectural patterns, domain idioms, subjective tradeoffs, and high-level design decisions that cannot be expressed as deterministic tooling.

## System Invariants: Protected `AGENTS.md`

> [!IMPORTANT]
> **Do not alter the routing rules or stop gates in AGENTS.md. Propose changes to project coding standards, linter rules, CI tests, or file an issue.**

The root `AGENTS.md` file defines the repository's foundational harness invariants: Step 0 classification, category thresholds, interview mandatory rounds, stop gates, context budgets, and language rules. These invariants are protected against ad-hoc session modifications.

When retrospective feedback touches process, routing, or agent behavior:
1. Direct coding conventions to `CODING_STANDARDS.md` (judgement calls only).
2. Direct mechanical constraints to linters, pre-commit hooks, or CI tests.
3. If an invariant, harness tool, or routing definition itself requires enhancement, document the proposal and ask the user to file a ticket/issue or approve a targeted harness refactor.

## The 7 Categories of Friction

Audit the completed session across these 7 categories:

### 1. Navigation
- **Question:** How easily did the agent locate entry points, architecture seams, configuration files, and relevant tests?
- **Friction signals:** Multiple exploratory directory listings, broad file globbing, confusion over module boundaries, or missing file indices.
- **Remedies:** Add entry-point notes to `README.md`, record domain terms and architectural entry points in [`.agents/CONTEXT.md`](../../CONTEXT.md), or add index/barrel exports.

### 2. Automated checks
- **Question:** Were mechanical mistakes caught late by human review or manual inspection rather than deterministic tooling?
- **Friction signals:** Review comments on formatting, missing test coverage for an edge case, broken imports, deprecated API usage, or missing pre-commit/CI checks.
- **Remedies:** Add a linter rule, configure a pre-commit hook, add a targeted unit or Pester test, or introduce a CI pipeline step.

### 3. Coding standards
- **Question:** Did the session reveal unwritten team idioms, domain conventions, or architectural tradeoffs?
- **Friction signals:** Reviewer comments requiring a specific design pattern, preferred error-handling style, or domain-specific structure that tooling cannot verify.
- **Remedies:** Add concise, actionable guidance to `CODING_STANDARDS.md` or `CONTRIBUTING.md`. **Enforce the judgement-only rule:** verify the item cannot be checked deterministically before adding it here.

### 4. System invariants (`AGENTS.md`)
- **Question:** Did the session encounter ambiguity in task classification, phase transitions, or harness tooling?
- **Protection rule:** Do not alter the routing rules or stop gates in `AGENTS.md`. Propose changes to project coding standards, linter rules, CI tests, or file an issue.
- **Remedies:** If harness workflow issues emerged, log an issue under `.scratch/<feature>/issues/` or the issue tracker for explicit consideration.

### 5. Tool economy
- **Question:** Did the agent waste tool calls, execute repetitive searches, run redundant tests, or loop on broad file scans?
- **Friction signals:** Unbounded `grep` or regex searches scanning `node_modules` or build artifacts; running the entire test suite when a targeted command was needed; rereading unchanged files.
- **Remedies:** Add test-running shortcuts in `package.json` / Makefile / scripts; configure `.gitignore` or tool search ignore patterns; document exact targeted test commands.

### 6. No-ops
- **Question:** Are there existing instructions, prompt rules, or documentation lines that models already obey by default, or that are consistently ignored?
- **Friction signals:** Bloated guidelines advising "write clean code" or "be thorough"; rules that never triggered; stale comments describing dead workflows.
- **Remedies:** Prune no-op instructions ruthlessly following `.agents/skills/writing-for-agents/SKILL.md`. Eliminate redundant words; replace fuzzy guidelines with concrete, binary criteria.

### 7. Information access
- **Question:** Did the agent lack necessary diagnostic logs, database schemas, environment variables, or API contracts?
- **Friction signals:** Guessing database column names, missing `.env.example` keys, opaque error messages lacking stack traces, or missing local fixture data.
- **Remedies:** Provide `.env.example` templates, export database schema dumps, add sample mock fixtures, or improve error formatting in dev scripts.

## Interactive Process

Run the retrospective through these five sequential steps. Do not modify repository files without user consent.

### Step 1: Gather Friction Evidence
Review the session context:
- Tool execution history: failed commands, repetitive searches, or long diagnostic loops.
- Reviewer feedback: comments from code review or user interventions.
- Test and build failures: errors encountered during implementation.
- Missing context: questions the agent had to ask because documentation was lacking.

### Step 2: Categorize Candidates
Map each observed friction point into one of the 7 categories above. Summarize candidates concisely:
```markdown
- [Category] <Observed friction> -> <Proposed concrete fix>
```

### Step 3: Apply the Invariant Filters
Filter the candidates before presenting:
1. **Deterministic filter:** If a candidate proposes adding a rule to `CODING_STANDARDS.md`, can a linter, compiler flag, or test check it? If yes, redirect it to an automated check.
2. **AGENTS.md guardrail:** If a candidate touches `AGENTS.md`, ensure it does not alter routing rules or stop gates. Redirect to tooling, standards, or an issue.

### Step 4: Propose Diffs Interactively
Present the prioritized candidates to the user with exact diffs or file content snippets:
- Name the affected file.
- Show the exact proposed diff or command to run.
- Explain the benefit in one line (tokens saved, error prevented deterministically).

### Step 5: Await Explicit Approval
Wait for the user to approve, modify, or reject each proposed improvement. Once approved:
1. Apply the approved changes cleanly.
2. Run targeted tests or linters to verify the changes.
3. Report the applied improvements back to the user.
