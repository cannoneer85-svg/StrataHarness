---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

# Implement

Implement the work described in the spec or in the tickets under `.scratch/<feature>/issues/`.

## 1. Record the base commit

Before the first edit, write the output of `git rev-parse HEAD` to `.scratch/<feature>/BASE_COMMIT`. `/code-review` uses it as its fixed point. When resuming work and the file already exists, keep it.

## 2. Choose the execution strategy

Read the tickets and their **Blocked by** edges, and forecast the token footprint against the Smart zone (≈120k). Announce the strategy with a one-line reason before writing code.

| Strategy | When | Who writes the code |
|---|---|---|
| In-Place | Minor route, or the forecast for all tickets stays under ~60k tokens | you, ticket by ticket, in this thread |
| Sequential Subagents | 3 or more tickets, or any heavy ticket (large test suite, wide change, big token footprint) | one implementer subagent per ticket; you are the Orchestrator (§4) |
| Multi-Session | a human must check the result between milestones | split the work into milestones, one session each, with the user's `/handoff` between them; each session picks In-Place or Sequential Subagents for its milestone |

Multi-Session wins whenever a human check is needed; otherwise take the first row that matches.

## 3. Rules for whoever writes the code

- Drive the work with **/tdd** (red → green → refactor) at the seams agreed in the spec.
- Design deep modules with narrow interfaces (**codebase-design**).
- Run typechecking and unit tests often, and the full test suite once at the end.
- Leave every change uncommitted; committing belongs to `/close-task`.

**Ticket status.** Move each ticket's **Status** `ready-for-agent → in-progress → done`, and update `.scratch/<feature>/TICKETS.md` in the same edit. How to update the map — node classes, table row, the frontier (`blocked` → `ready`) — is defined once in [tickets-map-template.md § Rules](../to-tickets/references/tickets-map-template.md); follow its **Sync** rule. Under Sequential Subagents only the Orchestrator does this.

## 4. Orchestrator protocol (Sequential Subagents)

As the Orchestrator you dispatch tickets and verify results. Your edits are limited to ticket Status fields, `TICKETS.md`, the Brief, and housekeeping; product code and tests are written only by implementer subagents, even for a one-line fix.

**Once, before the first ticket:** write the Brief from [references/brief-template.md](references/brief-template.md) to `.scratch/<feature>/BRIEF.md`. It carries everything the tickets share; the subagent sees nothing of this conversation.

**Spawning a subagent** — use the harness's built-in tool with a generic subagent:

- Antigravity: `invoke_subagent` with the built-in `self` subagent.
- Claude Code: the Agent (Task) tool with the general-purpose subagent.
- Codex, Cursor: the built-in subagent spawn.

Subagents run one at a time, in this workspace, on the current branch — no worktrees or branches.

**Loop** until every ticket is `done` or a stop condition fires:

1. **Pick** the next frontier ticket — all its blockers `done`. Set it `in-progress`.
2. **Spawn** one implementer. The prompt holds: the Brief's path, the ticket's path, and per-ticket notes (what earlier tickets produced that this one builds on, user decisions it depends on, known pitfalls). Wait for its report in the format of [references/report-template.md](references/report-template.md).
3. **Verify** yourself rather than trusting the report: re-run the ticket's tests and the project's validators, and compare `git status` / `git diff` with the ticket's scope. Delete stray artifacts the run left behind, such as test result files.
4. **Pass** — green and within scope: set the ticket `done` and continue with step 1 without stopping for the user.
5. **Retry once** — red or out of scope: spawn a fresh implementer with the same Brief, the failure log, and your remarks.
6. **Stop and report to the user** on a second failure of the same ticket, on a `blocked` report or an open question only the user can answer, or on any deviation from the spec. These are the only early stops.

## 5. Completion

- Report to the user: the tickets implemented, the test commands you ran with their results, the deviations the implementers reported, and the final tickets map — the diagram and table from `TICKETS.md`.
- Stop and ask the user for permission to run **/code-review**.
