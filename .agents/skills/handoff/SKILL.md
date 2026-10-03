---
name: handoff
description: Write a handoff document for the next session, update LATEST.md and clear finished work from .scratch — without committing.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Use it at any point: mid-stage to move the context into a fresh session, or as a step of `/close-task`.

Run it only on the user's explicit command, such as «делай handoff», or when `/close-task` calls it. Leave every change uncommitted: committing belongs to `/close-task`.

`<feature>` is the slug of the current task, as in `.scratch/<feature>/`. Work with no `.scratch` folder gets a short kebab-case slug of its topic.

## 1. Write the document

Save it to `docs/handoff/YYYY-MM-DD-<feature>.md` (today's date). If that file exists, append `-2`, `-3`, … to the name. Write it in the human-facing language set in the root `AGENTS.md`.

The document carries:

- **State** — the goal, the stage reached, what is done, what is in progress, and the decisions and gotchas not yet recorded anywhere else.
- **Open tickets** — every ticket in `.scratch/<feature>/issues/` whose Status is not `done`: path, Status, one line on what is left. Write "none" when there are none.
- **Next step** — the first concrete action for the next session.
- **Recommended skills** — the skills the next agent should run, each with the path to its `SKILL.md`, so manual-only skills can be read by path.

Reference specs, ADRs, tickets, commits and diffs by path or URL; restate only what lives nowhere else.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the document accordingly.

## 2. Update `LATEST.md`

Overwrite `docs/handoff/LATEST.md` with a copy of the new document, with one first line naming the dated file it copies. A resuming agent reads only `LATEST.md`; the dated files are the archive.

## 3. Clean `.scratch/<feature>/`

Remove finished work only; whatever the next session still needs stays.

- **Remove** tickets whose Status is `done`, and temporary files: `BRIEF.md`, drafts, notes, logs, test result files.
- **Keep** open tickets — any Status other than `done` — together with `TICKETS.md`, `BASE_COMMIT` and `OPEN_QUESTIONS.md` while any work on the feature remains.
- **Keep `TICKETS.md` consistent:** for each removed ticket, replace its link in the table with the plain title. Nodes, edges and statuses stay, so the map still shows what unblocked the open tickets.
- **Feature finished** — no open tickets remain (or the task never had tickets) and either `/code-review` has run or `/close-task` is closing the task: remove the whole `.scratch/<feature>/` folder.

When unsure whether a file is finished, keep it and name it in the document.

The step is complete when every file left in `.scratch/<feature>/` is either open work or named in the document.

## 4. Report

Tell the user the document's path and every file removed from `.scratch/`.
