# Agent rules

Route every task through **Step 0**, then follow one route stage by stage. Procedures live in the stage skills; this file holds the route and the invariants. Capitalised terms are defined in the glossary [`.agents/CONTEXT.md`](.agents/CONTEXT.md).

## Step 0 — classify before any work

In your first message, announce the **Type** and, for development, the **Category**, each with a one-line reason that names the signals below. Then stop until the user confirms or corrects the route.

**Resuming vs New task:**
- Before classifying, check `.scratch/`: if the user's request matches an active `.scratch/<feature>/` (or continues unfinished work), resume that feature: read its handoff (`docs/handoff/*-<feature>.md` or `LATEST.md` if matching) and check `.scratch/<feature>/TICKETS.md` rather than re-interviewing. If multiple active features exist and the target is ambiguous, ask the user.
- If `.scratch/` has no matching active feature or the request is an unrelated new topic, treat it as a new task: do not load past handoffs; classify cleanly via Step 0.

**Type**

- **Development** — the result changes code, configuration or tooling.
- **Analysis** — the result is a finding or a document (research, comparison, audit); code stays unchanged.

**Category** (development only). Weigh: modules touched, new entities or contracts, external integrations, open unknowns, fits in one session.

| Category | Signals |
|---|---|
| Minor | 1–2 files in one module; no new entities or contracts; no integrations; few unknowns |
| Feature | one subsystem; a new screen, endpoint, table or entity; integration against a known API; fits in one session |
| Epic | several modules or a new service; core architecture or cross-cutting contracts change; hardware or protocol integration; many unknowns |
| Fog (Туман) | the path to the result is not visible and will not fit in one session |

Re-categorise during the interview when answers reveal a different scale, up or down: announce the new Category with its reason and apply its round quota from then on.

## Stages

Each stage ends at a stop gate. Read the stage's `SKILL.md` at the path below when the stage starts.

| # | Stage | Skill | Stop gate — show, then wait for |
|---|---|---|---|
| 1 | Interview | [grill-with-docs](.agents/skills/grill-with-docs/SKILL.md); Fog: [wayfinder](.agents/skills/wayfinder/SKILL.md) | interview summary; approval of the next stage |
| 2 | Spec | [to-spec](.agents/skills/to-spec/SKILL.md) | spec approval |
| 3 | Tickets | [to-tickets](.agents/skills/to-tickets/SKILL.md) | approval of the ticket list and order |
| 4 | Implementation | [implement](.agents/skills/implement/SKILL.md) | green-test report; approval to run review |
| 5 | Review | [code-review](.agents/skills/code-review/SKILL.md) | review fixed; the user's close command |
| 6 | Close | [close-task](.agents/skills/close-task/SKILL.md) | terminal |

## Routes

| Route | Stages | Interview quota |
|---|---|---|
| Minor | 1 → 4 (In-Place) → 5 → 6 | 1 round, 2–4 questions |
| Feature | 1 → 2 → 3 → 4 → 5 → 6 | ≥ 2 rounds, 6–8 questions |
| Epic | 1 → 2 → 3 → 4 (Orchestrator) → 5 → 6 | ≥ 3 rounds, 10–12+ questions |
| Fog | 1 (wayfinder) → 2 → 3 → 4 → 5 → 6 | set by wayfinder |
| Analysis | [analyze](.agents/skills/analyze/SKILL.md): interview ⛔ → work → draft in `docs/analysis/` ⛔ → close (handoff or close-task) | 1 short round, 4 points |

- Ask interview questions with the harness's interactive question tool (Antigravity: `ask_question`) when it has one; grill-with-docs defines the rounds.
- Offer the spec only after every mandatory round of the current Category is done.

## Stop gates

- One stage per response. End each stage — and Step 0 — by showing the result, then wait for the user's explicit confirmation before starting the next.
- At the Stage 5 (Review) stop gate, explicitly present the user with the next-step options: full close via `/close-task` (preflight + handoff + scratch cleanup + local commit), context transfer via `/handoff` (session handoff without commit), or further edits.
- Hard guardrail: run handoff or close, commit, or clean `.scratch/` only on an explicit user command, such as «делай handoff», «фиксируй», «закрывай задачу», «мерджим».

## Context budget

- **Smart zone:** ≈120k tokens of working context.
- Before writing code, propose an execution strategy — In-Place, Sequential Subagents or Multi-Session — sized against the Smart zone and the ticket graph. Criteria and the Orchestrator protocol: [implement](.agents/skills/implement/SKILL.md).

## Language

- Agent-facing text (`AGENTS.md`, `SKILL.md`, script comments): English.
- Human-facing documents (specs, ADRs, tickets, handoffs, Registry, README) and every reply to the user: Russian.

## Skills by path

Stage skills are manual-only and may be missing from your skill list. Once the user confirms a stage, read its `SKILL.md` at the path in the table and follow it. Do the same for any skill named in the Registry that you cannot see.

## Where things live

- **Glossary:** [`.agents/CONTEXT.md`](.agents/CONTEXT.md) — use its terms in code, docs and replies.
- **Skill Registry:** [`.agents/SKILLS.md`](.agents/SKILLS.md). When you add, remove or rename a skill, update the Registry in the same change, run `.agents/scripts/Sync-ClaudeSkills.ps1`, then `.agents/scripts/Test-Template.ps1` must exit 0.
- **ADRs:** [`docs/adr/`](docs/adr/).
- **Latest handoff:** `docs/handoff/LATEST.md` — read it when resuming work.

## Agent skills

### Issue tracker

Local Markdown under `.scratch/<feature>/issues/`. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

Five canonical roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

Single-context: one glossary plus ADRs. See [`docs/agents/domain.md`](docs/agents/domain.md).
