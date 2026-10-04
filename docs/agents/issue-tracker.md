# Issue Tracker: Local Markdown

Issues in this repo are tracked as local Markdown files under `.scratch/<feature>/`, one folder per feature. `<feature>` is the kebab-case slug fixed at the interview and reused by the spec and the tickets.

## Layout

```
.scratch/<feature>/
├── OPEN_QUESTIONS.md   interview log
├── TICKETS.md          tickets map: dependency graph coloured by status + table
├── BASE_COMMIT         commit hash recorded when implementation starts; the review's fixed point
└── issues/
    └── <NN>-<slug>.md  one ticket per file, numbered from 01 in dependency order
```

Specs live in the repo, outside `.scratch`: `docs/specs/<NNNN>-<feature>-spec.md`, numbered sequentially across the repo. ADRs live in [`docs/adr/`](../adr/).

## Ticket Structure

- Each ticket is a Markdown file `.scratch/<feature>/issues/<NN>-<slug>.md` with: title, **What to build**, **Blocked by**, **Status**, and acceptance criteria as checkboxes. Template: [`to-tickets`](../../.agents/skills/to-tickets/SKILL.md).
- **Status** moves `(ready-for-agent | ready-for-human) → in-progress → done` and is the source of truth. `TICKETS.md` mirrors it (format: [tickets map template](../../.agents/skills/to-tickets/references/tickets-map-template.md)); a ticket with an unfinished blocker or awaiting human intervention is drawn as blocked there. As soon as work starts on any ticket — whether by an autonomous agent, orchestrator, or interactively with the user — its Status must transition to `in-progress` immediately.

## Workflow

1. `/grill-with-docs` writes the interview log `OPEN_QUESTIONS.md`.
2. `/to-spec` writes the spec to `docs/specs/` and the ADRs to `docs/adr/`.
3. `/to-tickets` writes the tickets to `issues/` and the tickets map to `TICKETS.md`.
4. `/implement` records `BASE_COMMIT`, works the frontier (tickets whose blockers are all `done`), and moves each ticket's Status, updating `TICKETS.md` in the same edit.
5. `/code-review` reviews the changes since `BASE_COMMIT` against the spec and the tickets, fixes findings, and prompts the user with next-step closing options (`/close-task` vs `/handoff` vs further edits).
6. `/handoff` — only on the user's explicit command — writes the handoff document to `docs/handoff/`, updates `docs/handoff/LATEST.md`, and removes finished tickets and temporary files from `.scratch/<feature>/`; open tickets stay. It does not commit.
7. `/close-task` — only on the user's explicit command — does everything `/handoff` does, then commits.
