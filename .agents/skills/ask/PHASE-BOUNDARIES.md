# Phase boundaries

A **phase** (or stage) is a chunk of work inside a session — interview, spec, ticket breakdown, implementation, review, or an analysis cycle.

The **phase boundary** is the gap between two phases. At a boundary, evaluate context usage against the **Smart zone** (≈120k tokens of working context) and choose how to proceed. Mid-phase, there is no boundary decision: continue or dispatch subagents. Compacting or clearing mid-phase causes the agent to lose the thread.

## The options

| Option | What it does | When to choose |
|---|---|---|
| **Continue** | Stay in the session without switching context. | Default when room remains in the Smart zone (≈120k) and the next phase benefits from full conversational context. |
| **Subagent** | Dispatch a self-contained task to a fresh context window. | Tightly-scoped execution (implementer subagent under Orchestrator, background research, code review). |
| **`/handoff`** | Write `docs/handoff/`, update `LATEST.md`, prune finished scratch files; no commit. | Context full, pausing mid-feature, switching harness, or passing work across Multi-Session milestones. |
| **`/close-task`** | Run preflight checks, execute handoff steps, and commit the feature (never push). | All stages complete, tests pass, and the user explicitly commands task closure. |
| **`/clear`** | Reset context window to empty. | Moving between independent tickets or unrelated tasks when all work is safely on disk. |
| **`/compact`** | Compress current conversation into a summary. | Fallback when staying in the same session but nearing the Smart zone limit. |

## The boundary decision tree

Work top to bottom at the boundary. The first matching condition wins:

**1. Is the task complete?**
If all stages are done, tests are green, and the user explicitly gives a close command («закрывай задачу», «фиксируй»), run **`/close-task`**. It performs preflight checks, executes handoff steps, and records one conventional commit. Never commit or close without the user's explicit command.

**2. Can you continue in this session?**
Two signals make the answer yes:
- The next phase needs this phase as a **primary source** (e.g. interview → spec or spec → tickets, where nuanced decisions matter verbatim).
- You have enough budget left in the **Smart zone** (≈120k tokens total working context) for the next phase to finish comfortably.
Continue costs nothing and loses nothing. Rule it out before considering secondary-source transitions.

**3. Can the work be delegated to a subagent?**
When the task is scoped to a discrete ticket or investigation (e.g. Sequential Subagents in `/implement`, a `/research` query, or parallel `/code-review`), dispatch a **subagent**. The caller stays lean, and the subagent works from a self-contained brief.

**4. Do you need to transfer context across sessions or environments?**
Run **`/handoff`** when you need a clean context break without committing:
- Approaching the Smart zone boundary (~120k tokens) during a large build.
- Splitting an Epic across Multi-Session milestones.
- Switching harness (Antigravity ↔ Claude Code ↔ Codex).
- Stepping away or pausing work mid-flight.
What `/handoff` buys is **portability**: state is preserved in `docs/handoff/` and `LATEST.md`, while code stays uncommitted.

**5. Is the previous context disposable?**
If everything in this session was exploratory, or the previous ticket is fully completed, tested, and stored on disk, run **`/clear`**. It resets the context window cleanly for the next independent unit of work.

**6. Otherwise, `/compact`.**
If you must remain in the same session and harness, but the context window is filling up and cannot hold the next phase, use `/compact`. Provide a focused instruction so the summary retains the specific context needed for the next phase.

## Primary and secondary sources

Every transition other than **Continue** converts a **primary source** (verbatim discussion, nuances, rejected alternatives) into a **secondary source** (a summary, ticket, or handoff document):

| Source | Information fidelity | Noise | Working room |
|---|---|---|---|
| Primary (Continue) | Complete | Higher | Decreasing |
| Secondary (`/handoff`, `/compact`) | Lossy / distilled | Low | Full window reset |

Prioritize **Continue** while within the Smart zone (≈120k). Switch to secondary sources when the token budget threatens reasoning precision.
