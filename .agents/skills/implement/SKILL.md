---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

# Implement

Implement the work described in the spec or in the tickets under `.scratch/<feature>/issues/`.

## 1. Record the base commit

Before the first edit, write the output of `git rev-parse HEAD` to `.scratch/<feature>/BASE_COMMIT`. `/code-review` uses it as its fixed point. When resuming work and the file already exists, keep it.

If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.

## 2. Choose the execution strategy

Read the tickets and their **Blocked by** edges, and forecast the token footprint against the Smart zone (≈120k). Announce the strategy with a one-line reason before writing code.

| Strategy | When | Who writes the code |
|---|---|---|
| In-Place | Minor route, or strictly 1–2 tickets whose total forecast stays under ~60k tokens without multi-ticket edits on files >1,000 lines | you, ticket by ticket, in this thread |
| Sequential Subagents | **Mandatory** for 3 or more tickets, 2 tickets editing files >1,000 lines, or any heavy ticket (large test suite, wide change, >60k token footprint) | one implementer subagent per ticket; you are the Orchestrator (§4) |
| Multi-Session | a human must check the result between milestones | split the work into milestones, one session each, with the user's `/handoff` between them; each session picks In-Place or Sequential Subagents for its milestone |

Multi-Session wins whenever a human check is needed; otherwise take the first row that matches.
**Hard override:** If the task has **3 or more tickets** (or 2 tickets touching files `>1,000 lines` / exceeding `~60k tokens`), you MUST execute via **Sequential Subagents** (or Multi-Session) — never `In-Place`, even if `In-Place` was tentatively discussed in an earlier stage. Update `**Active Stage:** Stage 4 (Implement)` and `**Execution Strategy:**` in `.scratch/<feature>/TICKETS.md` when starting Stage 4.

## 3. Rules for whoever writes the code

- Drive the work with **/tdd** (red → green → refactor) at the seams agreed in the spec.
- Design deep modules with narrow interfaces (**codebase-design**).
- Keep the solution scope per **minimal-diff**; forbidden zones (security, authorization, boundary validation, error handling, backward compatibility, behavior tests) are never simplified.
- Run typechecking and targeted unit tests per seam during implementation; running full heavy integration or E2E suites is reserved for completion (§5) and close-task preflight.
- Leave every change uncommitted; committing belongs to `/close-task`.

**Ticket status.** Move each ticket's **Status** `ready-for-agent → in-progress → done`, and update `.scratch/<feature>/TICKETS.md` in the same edit. How to update the map — node classes, table row, the frontier (`blocked` → `ready`) — is defined once in [tickets-map-template.md § Rules](../to-tickets/references/tickets-map-template.md); follow its **Sync** rule. Under Sequential Subagents only the Orchestrator does this.

## 4. Orchestrator protocol (Sequential Subagents)

As the Orchestrator you dispatch tickets and verify results. Your edits are limited to ticket Status fields, `TICKETS.md`, the Brief, and housekeeping; product code and tests are written only by implementer subagents, even for a one-line fix.

**Once, before the first ticket:** write the Brief from [references/brief-template.md](references/brief-template.md) to `.scratch/<feature>/BRIEF.md`. It carries everything the tickets share; the subagent sees nothing of this conversation. Keep it lean: prescribe ONLY targeted test commands per seam/ticket, never a blanket full test suite command per ticket, and forbid subagents from running baseline test suites on startup. The full test suite runs once at completion (§5).

**Spawning a subagent** — use the harness's built-in tool with a generic subagent:

- Antigravity: `invoke_subagent` with the built-in `self` subagent.
- Claude Code: the Agent (Task) tool with the general-purpose subagent.
- Codex, Cursor: the built-in subagent spawn.

Subagents run one at a time, in this workspace, on the current branch — no worktrees or branches.

**Loop** until every ticket is `done` or a stop condition fires:

1. **Pick & Mark in-progress** — select the next frontier ticket whose blockers are all `done`. Update its issue file (`Status: in-progress`) AND `.scratch/<feature>/TICKETS.md` (set node class to `inprogress` and table status to `in-progress`) **before any execution begins** (spawning a subagent, running interactive steps with the user, or executing orchestrator commands). Never work on a ticket or spawn a subagent while the ticket still shows `ready-for-agent` or `ready-for-human`.
2. **Spawn** one implementer. The prompt holds: the Brief's path, the ticket's path, and per-ticket notes (what earlier tickets produced that this one builds on, user decisions it depends on, known pitfalls). Wait for its report in the format of [references/report-template.md](references/report-template.md).
3. **Verify** yourself rather than trusting the report: re-run the ticket's targeted tests and relevant validators (do not run the full repository test suite here), and compare `git status` / `git diff` with the ticket's scope. Delete stray artifacts the run left behind, such as test result files.
4. **Pass** — green and within scope: set the ticket `done` and continue with step 1 without stopping for the user.
5. **Retry once** — red or out of scope: spawn a fresh implementer with the same Brief, the failure log, and your remarks.
6. **Stop and report to the user** on a second failure of the same ticket, on a `blocked` report or an open question only the user can answer, or on any deviation from the spec. These are the only early stops.

**Compaction and session recovery.** If the conversation is compacted or restarted mid-run:
1. Re-read `.scratch/<feature>/BASE_COMMIT`, `.scratch/<feature>/TICKETS.md` (including `**Active Stage:**` and `## Rulings & Decisions`), and inspect the working tree (`git status`, `git diff`). If `Active Stage` is already `Stage 5 (Code Review)`, resume `/code-review` rather than re-running Stage 4.
2. Tickets marked `done` are settled and never re-dispatched.
3. If a ticket is marked `in-progress` and uncommitted edits exist: do NOT run destructive commands (`git reset`, `checkout -- .`, `clean -fd`). Instead, run the ticket's targeted tests and compare the diff against its checkboxes:
   - If tests are green and all checkboxes are satisfied: mark the ticket `done` in its file and `TICKETS.md`, log a ruling, and advance to the next ticket.
   - If tests fail or work is partial: spawn a fresh implementer with the existing diff, the test failure output, and explicit instructions to bring the in-progress ticket to green without discarding valid work. Record the intervention in `## Rulings & Decisions`.
4. If no ticket is `in-progress`, resume from step 1 of the main loop.

**Recording rulings.** Whenever the Orchestrator makes an architectural choice, settles an ambiguous decision, or recovers an in-progress ticket, append a row to `## Rulings & Decisions` in `.scratch/<feature>/TICKETS.md` (`Ticket | Ruling / Decision | Why | Cost of being wrong`).

## 5. Completion

- Compile an **Evidence Table** proving every claimed criterion:
  - For Feature / Epic routes: map each ticket's acceptance criterion marked `[auto]` or `[manual]` to its verification proof:
    `Criterion / Claim | Verification command & fresh result | Manual checks remaining`
  - For Minor route: map each key decision / requirement from the interview log (`.scratch/<feature>/OPEN_QUESTIONS.md`) to its verification proof.
  - Never claim a criterion is met without citing fresh test/command output executed in this verification step.
- First, write out the full completion report from start to finish in the message body: the tickets implemented, the Evidence Table, any deviations reported by implementers (Expected / Found / Why), and the final tickets map — diagram, table, and Rulings from `TICKETS.md` — ending with the explicit next active step (**Stage 5: `/code-review`**) and the numbered continuation options (`1` approve and proceed to `/code-review`, `2` request adjustments).
- In the exact same turn immediately after the report and numbered text options, stop at the implementation stop gate and invoke the harness's interactive question tool (`ask_question` / `AskUserQuestion`, per `AGENTS.md`) with the matching options for permission to run **/code-review**.
