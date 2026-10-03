---
name: ask
description: Ask which skill or flow fits your situation. A router over the skills and routes in this repo.
---

# Ask

When uncertain which route, stage, or helper skill fits the task, `/ask` guides the decision.

Process rules, invariant stages, and interview quotas live in the root [`AGENTS.md`](../../../AGENTS.md). Glossary terms are defined in [`.agents/CONTEXT.md`](../../CONTEXT.md). The full catalog of skills with categories and invocation modes lives in the [Skill Registry](../../SKILLS.md).

## Step 0 and routes

Every task starts by classifying its **Type** and (for development) **Category** before any work begins.

### Task Type

- **Development** — the task modifies code, configuration, tests, or build tooling. Follows one of the four development routes below.
- **Analysis** — the task produces an investigation finding, comparison, or audit document; code and configuration remain unchanged. Follows the [Analysis flow](#analysis-flow).

### Development Categories

Weigh the signals: modules touched, new entities or contracts, external integrations, open unknowns, and whether the work fits into a single session.

#### Minor

- **Signals:** Touches 1–2 files within one module; no new entities, contracts, or migrations; no external API integrations; minimal unknowns; easily fits in one session.
- **Route:** Stage 1 (Interview) → Stage 4 (Implementation: In-Place) → Stage 5 (Review: code-review) → Stage 6 (Close: close-task). Skips formal spec and ticket generation.
- **Examples:**
  - Fixing an off-by-one bug in a date formatting helper.
  - Adding a configurable timeout parameter to an existing HTTP client function.
  - Updating a build script or linter rule.

#### Feature

- **Signals:** Scope spans one subsystem or module; adds a new screen, endpoint, database entity, or integration against a known API; contains few architectural unknowns; fits in one session.
- **Route:** Stage 1 (Interview: grill-with-docs) → Stage 2 (Spec: to-spec) → Stage 3 (Tickets: to-tickets) → Stage 4 (Implementation: implement) → Stage 5 (Review: code-review) → Stage 6 (Close: close-task).
- **Examples:**
  - Adding a new REST endpoint `/api/v1/export-csv` with tests and schema validation.
  - Creating a user notifications settings page.
  - Adding an audit log table and recording events on user profile updates.

#### Epic

- **Signals:** Spans multiple modules, packages, or services; modifies core architecture or cross-cutting contracts; integrates hardware or new external protocols; carries many unknowns; requires the Orchestrator strategy with sequential subagents.
- **Route:** Stage 1 (Interview: grill-with-docs) → Stage 2 (Spec: to-spec) → Stage 3 (Tickets: to-tickets) → Stage 4 (Implementation: implement with Orchestrator) → Stage 5 (Review: code-review) → Stage 6 (Close: close-task).
- **Examples:**
  - Migrating authentication from session cookies to OAuth2/OIDC across frontend and backend.
  - Refactoring an entire storage subsystem to abstract cloud providers.
  - Adding real-time websocket synchronization across three distributed microservices.

#### Fog (Туман)

- **Signals:** The path from the starting idea to the destination is not visible; problem space cannot fit in a single session; multiple unresolved architectural decisions or unknowns.
- **Route:** Stage 1 replaces `grill-with-docs` with [`wayfinder`](../wayfinder/SKILL.md). Wayfinder charts a shared map of decision tickets on the tracker and resolves them iteratively until the fog clears. Once the path is clear, it merges into the standard flow at Stage 2 (`to-spec`) → `to-tickets` → `implement` → `code-review` → `close-task`.
- **Examples:**
  - Greenfield initiative: "We want an automated AI evaluation pipeline, but haven't chosen the models, test harness, dataset storage, or CI runner."
  - Untangling a legacy monolithic system with undocumented dependencies into bounded contexts.

*Note on interview quotas:* See the Routes table in [`AGENTS.md`](../../../AGENTS.md) for mandatory question and round counts per Category.

### Analysis flow

Tasks whose outcome is a document or recommendation rather than a code change run through [`analyze`](../analyze/SKILL.md):
1. **Interview:** 1 short round covering 4 points (question, audience, result format, sources). ⛔ Stop gate.
2. **Work:** Gathering evidence from sources, optionally delegating reading legwork to [`research`](../research/SKILL.md) or subagents.
3. **Draft:** Authoring `docs/analysis/YYYY-MM-DD-<topic>.md`. ⛔ Stop gate.
4. **Close:** Handing off or closing on user command.

- **Examples:**
  - Evaluating three competing UI component libraries for accessibility and bundle weight.
  - Security audit of authentication token validation logic.
  - Investigating the root cause and architectural impact of an external dependency outage.

## Handoff vs Close-task

The two end-of-stage transitions serve distinct purposes:

| Aspect | `/handoff` | `/close-task` |
|---|---|---|
| **Purpose** | Context transfer between sessions or environments. | Terminal completion of a finished task. |
| **Git commit** | **Never commits.** Working tree changes remain uncommitted. | **Commits.** Runs preflight checks, then creates one conventional commit. |
| **Git push** | Never pushes. | Never pushes. Publishing stays with the human. |
| **Artifacts** | Writes `docs/handoff/YYYY-MM-DD-<feature>.md` and updates `docs/handoff/LATEST.md`. | Runs `/handoff` steps; handoff doc and `LATEST.md` join the commit. |
| **Scratch cleanup** | Removes finished tickets and temporary files from `.scratch/`; open tickets remain. | Same scratch cleanup; removes entire `.scratch/<feature>/` if no open tickets remain. |
| **Trigger** | User command mid-feature, when switching harness, or between Multi-Session milestones. | User explicit command («закрывай задачу», «фиксируй») after review is resolved. |
| **Reference** | [`../handoff/SKILL.md`](../handoff/SKILL.md) | [`../close-task/SKILL.md`](../close-task/SKILL.md) |

## Phase boundaries

At the gap between stages, evaluate working context against the **Smart zone** (≈120k tokens) and decide how to transition. See [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) for the complete decision tree:
1. **Is the task finished?** Run `/close-task` upon user command.
2. **Can you continue in this session?** Stay in-session if subsequent work needs primary conversational context and context budget permits.
3. **Can the work be delegated?** Dispatch a subagent for scoped tickets, research, or code review.
4. **Do you need portability?** Run `/handoff` when switching harness, hitting the context limit, or pausing work.
5. **Is prior context disposable?** Run `/clear` between self-contained tickets.
6. **Otherwise:** Run `/compact` to summarize before continuing.

## Helper skills: when to reach for

Helper skills support specific phases of work without defining the outer lifecycle. Reach for them when their triggering condition arises:

### Research and investigation

- [`research`](../research/SKILL.md) — When you need reading legwork on high-trust primary sources (APIs, documentation, papers) delegated to a background agent. Produces a Markdown findings file without halting conversation.
- [`prototype`](../prototype/SKILL.md) — When a design, state model, or UI question cannot be resolved on paper. Builds throwaway code to evaluate concrete behavior before formal implementation.
- [`diagnosing-bugs`](../diagnosing-bugs/SKILL.md) — When diagnosing stubborn bugs, flaky tests, or performance regressions. Enforces establishing a tight, repeatable red test before attempting fixes.

### Planning and problem framing

- [`triage`](../triage/SKILL.md) — When processing incoming bug reports or feature requests that you did not author. Classifies issues into triage roles and prepares agent-ready briefs (never run triage on tickets generated by `/to-tickets`).
- [`to-questionnaire`](../to-questionnaire/SKILL.md) — When progress is blocked by decisions or missing facts held by external stakeholders. Formats an asynchronous questionnaire to send outside the agent session.
- [`grill-me`](../grill-me/SKILL.md) / [`grilling`](../grilling/SKILL.md) — When you want an interactive stress-test interview outside of a repository or without writing persistent documentation.

### Architecture, domain, and coding

- [`codebase-design`](../codebase-design/SKILL.md) — When designing or deepening a module's interface, finding clean seams, or hiding implementation details.
- [`domain-modeling`](../domain-modeling/SKILL.md) — When resolving overloaded vocabulary, updating `CONTEXT.md`, or recording hard-to-reverse architectural decisions as ADRs.
- [`tdd`](../tdd/SKILL.md) — When implementing discrete units of functionality test-first (red-green-refactor) at agreed seams.
- [`improve-codebase-architecture`](../improve-codebase-architecture/SKILL.md) — When auditing a codebase for shallow modules and generating visual reports on deepening opportunities.

### Human interaction, learning, and writing

- [`wizard`](../wizard/SKILL.md) — When execution hits steps only a human can perform (cloud console provisioning, OAuth setup, secrets entry). Generates an interactive bash script to walk the human through it.
- [`teach`](../teach/SKILL.md) — When the user wants to learn a new programming concept or skill incrementally in this workspace.
- [`wait-what`](../wait-what/SKILL.md) — When an agent explanation was unclear or overloaded; resets and re-pitches the explanation in simple terms using project glossary definitions.
- [`writing-fragments`](../writing-fragments/SKILL.md), [`writing-beats`](../writing-beats/SKILL.md), [`writing-shape`](../writing-shape/SKILL.md) — When drafting prose or documentation: explore raw fragments → sequence beats → shape final prose.
- [`writing-for-agents`](../writing-for-agents/SKILL.md) — When authoring or revising skills, `AGENTS.md`, or other agent-facing guidance.

For the complete categorized list of active skills, consult the [Skill Registry](../../SKILLS.md).
