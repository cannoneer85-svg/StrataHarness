---
name: code-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two core axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?) — plus an optional third axis: Adversary (presumption of failure) on Epic or high-risk tasks. Runs reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to 'review since X'."
---

Review of the changes between a fixed point and the working tree along two core axes, plus an optional third axis for high-risk changes:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / spec?
- **Adversary** (optional, for Epic or high-risk tasks) — attacks the solution under a presumption of failure (race conditions, boundary breaches, unauthorized access, data loss).

The axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

The issue tracker should have been provided to you. If `docs/agents/issue-tracker.md` is missing, tell the user to run `/init-project`.

## Process

### 1. Pin the fixed point

The fixed point defaults to the commit in `.scratch/<feature>/BASE_COMMIT`, recorded by `/implement` when the work started; `<feature>` is the feature under review in this conversation. A fixed point the user names — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. — takes precedence. If there is neither, ask for it.

Resolve it to a commit once: `git rev-parse <fixed-point>`; for a branch, use its merge-base with `HEAD` (`git merge-base <branch> HEAD`). Call the result `<base>`.

Work stays uncommitted until `/close-task`, so the change set is the working tree against `<base>`, not only the commits:

- tracked changes: `git diff <base>`;
- new files: `git ls-files --others --exclude-standard`;
- commits since the fixed point: `git log <base>..HEAD --oneline` (may be empty).

Before going further, confirm the fixed point resolves and the change set — diff plus new files — is non-empty. A bad ref or empty change set should fail here — not inside two parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. A path the user passed as an argument.
2. The feature's spec `docs/specs/<NNNN>-<feature>-spec.md` together with its tickets `.scratch/<feature>/issues/*.md` — each ticket's acceptance criteria count as requirements.
3. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch via the workflow in `docs/agents/issue-tracker.md`.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

The primary source is `CODING_STANDARDS.md` at the repo root; add anything else that documents how code should be written, such as `CONTRIBUTING.md`. If `CODING_STANDARDS.md` is missing or still a stub, say so in the final report; the Standards axis then rests on the smell baseline and any other source found.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change, or duplicates logic already present elsewhere in the repo. → extract the shared shape, call it from both; reuse or generalize the existing unit.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

**Minimal-Diff Breaches** ([`minimal-diff`](../minimal-diff/SKILL.md)) — speculative classes, a seam with only one adapter (count test adapters as adapters — see `codebase-design`), home-rolled wheels where standard libraries or existing utilities exist, unjustified dependencies, near-copies duplicating existing repo logic, or scattered patches instead of root-cause repair. → remove speculative abstractions, consolidate to root cause, adapt existing code.

**False Positives to Suppress**
Apply this closed list of false positives during review and aggregation:
- **Untouched code outside diff**: Remarks or refactoring suggestions targeting code not modified in the current diff (unless the diff directly breaks a caller or dependent contract).
- **Checks already enforced by tooling**: Formatting, linting, syntax, and invariant errors already caught by deterministic validation scripts or linters (e.g., `Test-Template.ps1`).
- **Premature abstractions violating `minimal-diff`**: Suggestions to add extra layers, factories, indirection, or interfaces "for future extensibility" in violation of [`minimal-diff`](../minimal-diff/SKILL.md).
- **Smells or style preferences framed as hard violations**: Treating Fowler smells or personal aesthetic preferences as hard violations when no documented repository rule in `CODING_STANDARDS.md` or `AGENTS.md` explicitly forbids them.

### 4. Spawn sub-agents in parallel

**Standards sub-agent prompt** — include:

- The change set from step 1: the diff command, the new-file list, and the commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report — per file/hunk where relevant — (a) every place the diff violates a documented standard: cite the standard (file + the exact rule quote); every hard violation MUST quote the exact documented rule from `CODING_STANDARDS.md` or `AGENTS.md` — findings without an exact rule quote are strictly judgement calls or smells, never hard violations; (b) any baseline smell or minimal-diff breach you spot (speculative abstractions, unjustified new dependencies, single-adapter seams without test stand-ins, near-copies duplicating existing code, scattered patches instead of root-cause fix); and (c) any concurrency or boundary safety hazards. Suppress false positives: untouched code outside the diff, anything tooling or linters enforce, speculative abstractions disguised as clean code, and personal style preferences lacking a documented repo rule. Distinguish hard violations from judgement calls — documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Do NOT run the repository test suite, integration tests, or build pipelines — testing and test execution belong to the caller/orchestrator; your role is static code review and standard compliance analysis only. Under 400 words."

**Spec sub-agent prompt** — include:

- The change set from step 1: the diff command, the new-file list, and the commit list.
- The path or fetched contents of the spec, and the paths of the tickets.
- The brief: "Report: (a) requirements the spec or tickets asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec or ticket line for each finding. Do NOT run the repository test suite or build pipelines — your role is static requirements verification against the diff only. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

**Adversary sub-agent (Epic & security-critical tasks only)**:
For tasks on the Epic route, or changes modifying authentication, permissions, data migrations, or concurrent resources, spawn a third parallel sub-agent: **Adversary**.
- Brief: "Act as an independent adversary with a presumption of failure. Examine the diff to identify up to 3 concrete failure scenarios: race conditions, unhandled failure/boundary states, resource exhaustion, authorization bypasses, or silent data loss. Quote file and line for each scenario. Do NOT run the repository test suite or build pipelines — your role is static failure scenario and risk analysis against the diff only. Under 400 words."

### 5. Aggregate

**False Positives & Uncited Hard Violations Filtering**:
Before presenting findings and proceeding to fixes, the aggregating agent filters findings deterministically without invoking a second cascade of subagents:
1. Discard any finding matching the `False Positives to Suppress` list.
2. For any finding labelled as a `hard violation`, verify that it quotes the exact rule from `CODING_STANDARDS.md` or `AGENTS.md`. If no exact quote is present or the rule does not exist, downgrade it to a judgement call or discard it if unfounded.

Present the reports under `## Standards`, `## Spec`, and (if spawned) `## Adversary` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings across headings — the axes are deliberately separate (see _Why three axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

### 6. Fix, then stop

Fix every validated hard violation (that passed filtering and cites an exact rule), spec gap, and critical Adversary finding, and each judgement call you agree with. For a finding you leave as is, give the reason in one line. Re-run ONLY targeted tests for the changed files (or lightweight validators like `Test-Template.ps1`/lint); the full heavy repository test suite is reserved for the close-task stage. Then show the user what you fixed and what you left.

**At the stop gate**, first write out the complete review report from start to finish in the message body (findings per axis, what was fixed, what was left, and test results) together with the available next-step options below:
1. **Full task close** (`/close-task`, or commands like «закрывай задачу», «фиксируй», «мерджим»): runs preflight checks, generates the handoff document and updates `LATEST.md`, cleans finished scratch files and removes `.scratch/<feature>/` when complete, and creates a single conventional local git commit (never pushes).
2. **Context transfer without commit** (`/handoff`, or «делай handoff»): summarizes conversation state into `docs/handoff/` and `LATEST.md` for a fresh session, preserves open tickets and `BASE_COMMIT`, cleans only finished tickets/temp files, and leaves all code uncommitted.
3. **Further adjustments**: request any additional edits, refactoring, or tests before closing.
4. **Environment retrospective** (`/retro`): if recurring friction, tooling issues, or preventable review mistakes were encountered, run a retrospective to capture actionable environment improvements (automated checks, linters, or standards).

Only after finishing the full report text, invoke the harness's interactive question tool (when available, per `AGENTS.md`) with these selectable continuation choices, then stop and wait. `/handoff`, `/close-task` and any commit run only on the user's explicit command (including selecting the corresponding action option in the interactive stop-gate prompt).

## Why three axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.

Why the Adversary axis: presumption of failure. The Standards sub-agent checks compliance against documented repo rules; the Spec sub-agent checks whether the code delivers what was promised; the Adversary sub-agent specifically attacks the solution looking for malicious inputs, race conditions, edge-case crashes, boundary breaches, and unauthorized access.
