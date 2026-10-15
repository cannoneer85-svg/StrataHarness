---
name: to-tickets
description: Break a plan, spec, or the current conversation into a set of tracer-bullet tickets, each declaring its blocking edges, published to the configured tracker — edges as text in one file per ticket locally, or native blocking links on a real tracker.
disable-model-invocation: true
---

# To Tickets

Break a plan, spec, or conversation into a set of **tickets** — tracer-bullet vertical slices, each declaring the tickets that **block** it.

The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/init-project`.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each ticket its **blocking edges** — the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change — rename a column, retype a shared symbol — whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify ticket — green is promised only there.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Below the list, read [references/tickets-map-template.md](references/tickets-map-template.md) and draw the tickets map's Mermaid diagram and legend so the user sees the blocking edges and initial frontier:

- **Nodes**: `T<NN>["<NN> <short title>"]` (at most four words).
- **Colour classes**: include all four fixed `classDef` lines (`ready`, `inprogress`, `done`, `blocked`) from the template and assign each node its initial `class` — tickets with no blockers in `ready` (blue frontier), tickets with any blocker in `blocked` (grey).
- **Legend**: include the legend line (`**Легенда:** ...`) immediately below the Mermaid block.

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct — does each ticket only depend on tickets that genuinely gate it?
- Should any tickets be merged or split further?

Iterate until the user approves the breakdown.

### 5. Publish the tickets to the configured tracker

Publish the approved tickets. **How** depends on the tracker `/init-project` configured — the tickets are the same either way, only the shape of the blocking edges changes:

- **Local files** → write one file per ticket under `.scratch/<feature>/issues/<NN>-<slug>.md` (`<feature>` is the slug of the spec and interview log), numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers/titles it depends on. Use the per-ticket file template below — one ticket per file, never a single combined file.
- **A real issue tracker (GitHub, Linear, …)** → publish one issue per ticket in dependency order (blockers first) so each ticket's blocking edges can reference real identifiers. If the source was an existing issue, make each ticket its sub-issue. Use the platform's native blocking / sub-issue relationship where it has one; otherwise set each ticket's "Blocked by" to the blocking issues. Apply the `ready-for-agent` triage label unless instructed otherwise — the tickets are agent-grabbable by construction.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Every ticket starts at `ready-for-agent` and moves `ready-for-agent → in-progress → done`; the ticket's **Status** is the source of truth. Blocked is drawn, not stored: a `ready-for-agent` ticket with an unfinished blocker shows as blocked on the tickets map.

Then build the **tickets map** from [references/tickets-map-template.md](references/tickets-map-template.md): a Mermaid dependency graph coloured by status (all four `classDef` lines and `class` assignments), the legend line immediately below it, and a table of every ticket. Always build it, for any tracker:

- **Local files** → write it to `.scratch/<feature>/TICKETS.md`, beside the `issues/` folder. It is an index; each ticket stays in its own file.
- **A real issue tracker** → post it as a comment on the parent issue, or in your message to the user when there is no parent.

Do NOT close the parent issue or edit its body.

<local-ticket-template>

# <NN> — <Ticket title>

**What to build:** the end-to-end behaviour this ticket makes work, from the user's perspective — not a layer-by-layer implementation list.

**Blocked by:** the numbers/titles of the tickets that gate this one, or "None — can start immediately".

**Status:** ready-for-agent

- [ ] `[auto]` Acceptance criterion 1
- [ ] `[manual]` Acceptance criterion 2

</local-ticket-template>

<issue-template>

## Parent

A reference to the parent issue on the tracker (if the source was an existing issue, otherwise omit this section).

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective — not layer-by-layer implementation.

## Acceptance criteria

- [ ] `[auto]` Criterion 1
- [ ] `[manual]` Criterion 2

## Blocked by

- A reference to each blocking ticket, or "None — can start immediately". Omit this section when blockers were set as native edges.

</issue-template>

In either form, avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

### 6. Verify spec coverage

Before showing the tickets map, build a coverage matrix matching every Acceptance Criterion from the spec `docs/specs/<NNNN>-<feature>-spec.md` (or each requirement from the source issue/conversation if no formal spec exists) to the ticket(s) that deliver it. Every criterion must be accounted for:

| Spec AC # / Requirement | Type | Ticket(s) |
|---|---|---|
| AC 1 | `[auto]` | 01 |
| AC 2 | `[manual]` | 02 |

Any uncovered requirement is a blocker: add or adjust tickets to cover it before showing the map to the user.

### 7. Show the tickets map

Show the user the published tickets map — the colour-coded Mermaid diagram (with all four `classDef` lines and `class` assignments), the legend line right below it, the table, the Rulings & Decisions section, the coverage matrix, and where they live — then stop at the tickets stop gate. Done when every published ticket appears in the map with its Status, its node colour class (`ready` or `blocked`), the legend, and all spec requirements are covered.
