---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

Two-axis review of the changes between a fixed point and the working tree:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

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
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
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

### 4. Spawn both sub-agents in parallel

**Standards sub-agent prompt** — include:

- The change set from step 1: the diff command, the new-file list, and the commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report — per file/hunk where relevant — (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls — documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** — include:

- The change set from step 1: the diff command, the new-file list, and the commit list.
- The path or fetched contents of the spec, and the paths of the tickets.
- The brief: "Report: (a) requirements the spec or tickets asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec or ticket line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings — the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

### 6. Fix, then stop

Fix the findings: every hard violation and spec gap, and each judgement call you agree with. For a finding you leave as is, give the reason in one line. Re-run the tests, then show the user what you fixed and what you left.

**At the stop gate**, explicitly present the user with the available next-step options and commands so they know what to do next:
1. **Full task close** (`/close-task`, or commands like «закрывай задачу», «фиксируй», «мерджим»): runs preflight checks, generates the handoff document and updates `LATEST.md`, cleans finished scratch files and removes `.scratch/<feature>/` when complete, and creates a single conventional local git commit (never pushes).
2. **Context transfer without commit** (`/handoff`, or «делай handoff»): summarizes conversation state into `docs/handoff/` and `LATEST.md` for a fresh session, preserves open tickets and `BASE_COMMIT`, cleans only finished tickets/temp files, and leaves all code uncommitted.
3. **Further adjustments**: request any additional edits, refactoring, or tests before closing.

Then stop and wait. `/handoff`, `/close-task` and any commit run only on the user's explicit command.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
