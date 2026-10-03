---
name: close-task
description: Close the current task — preflight checks, the handoff steps, then one conventional commit. Never pushes.
disable-model-invocation: true
---

# Close task

Close the current task: check that it is ready, run the handoff, and commit the task's changes in one commit. Run only on the user's explicit command, such as «закрывай задачу» or «фиксируй». Publishing stays with the user: the skill ends at a local commit and never runs `git push`.

`<feature>` is the slug of the task being closed, as in `.scratch/<feature>/`.

## 1. Preflight

Record a result for each check before acting on any of them:

- **Open tickets** — tickets in `.scratch/<feature>/issues/` whose Status is not `done`.
- **Tests** — run the project's full test suite and the validators it documents (`CODING_STANDARDS.md`, `README.md`, the spec, package scripts). Record the commands and pass/fail counts, or "no tests" when the project has none.
- **Review** — whether `/code-review` ran for this task, in this conversation or according to a handoff document. When you cannot tell, record "not run".
- **Out-of-scope changes** — from `git status --short`, every changed or untracked file this task did not produce.

The preflight is complete when all four checks have a recorded result.

## 2. Gate

All four clean — no open tickets, tests green or absent, review ran, no out-of-scope changes — continue to step 3.

Otherwise show the user the list of what is not ready and ask whether to close partially, with the harness's interactive question tool when it has one. Then wait.

- **Yes** — continue. Open tickets stay in `.scratch/` for the handoff to list; out-of-scope files stay out of the commit.
- **No** — stop here; nothing has changed.

## 3. Handoff

Read [`../handoff/SKILL.md`](../handoff/SKILL.md) and execute every step of it; fold its report into the summary in step 5. Its handoff document and `LATEST.md` join this task's commit.

## 4. Commit

Stage the task's files by explicit path — the files the task changed, created or deleted, plus the handoff document and `docs/handoff/LATEST.md`: `git add -A -- <paths>`. Out-of-scope files stay unstaged; `.scratch/` is git-ignored. Check `git diff --cached --stat` against that list before committing.

Make exactly one commit. This message format is fixed and overrides any other commit convention, including a global `commit` skill:

```
<type>(<scope>): <summary>

<body>
```

- **type** — the dominant kind of change: `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `ci`, `perf` or `chore`.
- **scope** — the feature slug, or the main module touched.
- **summary** — imperative mood, lowercase start, no trailing period, the whole first line at most 72 characters.
- **body** — 1–5 lines starting with `- `: what changed and why, the spec path if there is one, and on a partial close the open tickets left.
- English; no issue references, trailers or co-author lines unless the user asks for them.

Pass the subject and the body as two `-m` arguments to `git commit`. If a commit hook fails, show its output and stop for the user's decision.

## 5. Summary

Report to the user, in the user's language:

- the commit hash and subject, and the number of files committed;
- the handoff document's path and the files removed from `.scratch/`;
- on a partial close: the open tickets left and the out-of-scope files left uncommitted;
- that publishing is theirs: `git push` when they are ready.
