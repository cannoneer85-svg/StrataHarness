# Issue Tracker: Local Markdown

Issues in this repo are tracked as local Markdown files under `.scratch/<feature>/issues/`.

## Ticket Structure
- Each ticket is a Markdown file: `.scratch/<feature>/issues/<NN>-<slug>.md`
- Contains:
  - **Title & Goal**
  - **Prerequisites / Blocking edges** (which tickets must be completed before this one)
  - **Acceptance Criteria**
  - **Verification Steps**

## Workflow
1. `/to-tickets` outputs tickets to `.scratch/<feature>/issues/`.
2. `/implement` picks up unblocked tickets in order following the chosen execution strategy.
3. Upon completion, `/handoff` (only when explicitly requested by user) archives or removes the completed scratch issues and commits the work.
