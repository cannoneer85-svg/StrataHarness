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

**Category** (development only). Weigh: footprint (modules/files touched), intent gaps (clarity of requirements vs. open decisions), irreversible actions (data migrations, breaking contract changes, external side effects), open unknowns, and whether it fits in one session.

| Category | Signals |
|---|---|
| Minor | 1–2 files in one module (small footprint); intent is clear (no intent gaps); fully reversible (no irreversible actions or data migrations); no new entities or contracts; no integrations; few unknowns |
| Feature | one subsystem; a new screen, endpoint, table or entity; moderate intent gaps resolved in 2 interview rounds; standard reversible changes or safe migrations; integration against a known API; fits in one session |
| Epic | several modules or a new service (large footprint); major intent gaps; irreversible actions or destructive migrations; core architecture or cross-cutting contracts change; hardware or protocol integration; many unknowns |
| Fog (Туман) | the path to the result is not visible; fundamental intent gaps; will not fit in one session |

Re-categorise during the interview when answers reveal a different scale, up or down: announce the new Category with its reason and apply its round themes from then on.

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

| Route | Stages | Interview mandatory rounds |
|---|---|---|
| Minor | 1 → 4 (In-Place) → 5 → 6 | 1 round: Outline and happy path |
| Feature | 1 → 2 → 3 → 4 → 5 → 6 | 2 rounds: Happy path + Errors & edge cases |
| Epic | 1 → 2 → 3 → 4 (Orchestrator) → 5 → 6 | 3 rounds: Happy path + Errors & edge cases + NFR |
| Fog | 1 (wayfinder) → 2 → 3 → 4 → 5 → 6 | set by wayfinder |
| Analysis | [analyze](.agents/skills/analyze/SKILL.md): interview ⛔ → work → draft in `docs/analysis/` ⛔ → close (handoff or close-task) | 1 short round: 4 points |

- **No question cap:** ask until no open architectural, contract or MVP decisions remain; resolve implementation trivia with sensible defaults yourself.
- **Adaptive follow-ups:** follow-up questions belong to the active round's theme; settle current decisions before moving to the next theme.
- **User override:** the user may halt the interview at any time with a stop phrase such as «хватит / пиши спеку». The stop phrase closes all remaining mandatory rounds immediately; record the open frontier as assumptions in `.scratch/<feature>/OPEN_QUESTIONS.md`, and `/to-spec` lists them under Further Notes.
- **Escalation signal:** if a Minor interview uncovers more than 4 open decision questions, announce re-categorisation to Feature immediately and run Round 2.
- Ask interview questions with the harness's interactive question tool when it has one; grill-with-docs defines the rounds.
- Offer the spec only after every mandatory round of the current Category is done.

## Stop gates

- One stage per response. At every stop gate (Step 0, Stages 1–5, Analysis, Release), follow this strict sequence:
  1. **First — write the full report:** Write out the complete stage deliverable and report from start to finish in the message body. Never omit or abbreviate the report.
  2. **Second — ask for confirmation:** Only after finishing the full report text, invoke the harness's interactive question tool with the continuation options below (or ask in plain text when the harness has no interactive question tool):
     - **Step 0 and confirmation stop gates (Stages 1–4, Analysis, Release):** present 2 options — `(Recommended)` approve and proceed, or request adjustments/clarifications.
     - **Stage 5 (Review) stop gate:** present the next-step options in the report and as selectable choices: full close via `/close-task` (preflight + handoff + scratch cleanup + local commit), context transfer via `/handoff` (session handoff without commit), further edits, or `/retro` (when recurring friction occurred).
- Hard guardrail: run handoff or close, commit, or clean `.scratch/` only on an explicit user command — either a typed command (such as «делай handoff», «фиксируй», «закрывай задачу», «мерджим») or selecting the corresponding action button in the Stage 5 interactive stop-gate prompt. The command `/release` / «выпускай релиз» is the single command permitting the agent to push, and ONLY after explicit confirmation on the release stop gate (via the interactive stop-gate prompt or typed confirmation). Force-push (`--force`, `--force-with-lease`) is strictly prohibited under all circumstances. Other skills (`close-task`, `handoff`) retain the prohibition on push — publishing regular task work stays with the user.

## Context budget

- **Smart zone:** ≈120k tokens of working context.
- Before writing code, propose an execution strategy — In-Place, Sequential Subagents or Multi-Session — sized against the Smart zone and the ticket graph. Criteria and the Orchestrator protocol: [implement](.agents/skills/implement/SKILL.md).

## Language

- Agent-facing text (`AGENTS.md`, `SKILL.md`, script comments): English.
- Public files (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md`, `LICENSE`, `.github/**`, `docs/releasing.md`, commit messages, and PR titles): English.
- Human-facing internal documents (specs, ADRs, tickets, handoffs, Registry, `README.ru.md` and other `README.<lang>.md` translations) and every reply to the user: Russian.

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
