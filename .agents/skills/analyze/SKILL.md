---
name: analyze
description: Analysis flow — short interview, evidence gathering, then a dated finding document in docs/analysis/. Use when the task's result is a finding rather than a code change: research question, comparison, audit, evaluation, recommendation.
---

# Analyze

Run an Analysis task: the result is a finding written to `docs/analysis/`; code, configuration and tooling stay unchanged. The flow has two stop gates — after the interview and after the draft — and ends only on the user's command.

`<topic>` is a short kebab-case slug of the question.

## 1. Interview

One short round, with the harness's interactive question tool when it has one (Antigravity: `ask_question`), otherwise in the format of [grilling](../grilling/SKILL.md). Ask only for what the request leaves open. Cover four points:

- **Question** — the exact question to answer and the decision it feeds.
- **Audience** — who reads the document and what they already know.
- **Result format** — recommendation, comparison table, audit checklist or other; depth and length.
- **Sources** — which to use (code, docs, web, papers, people), which to trust most, which are off-limits.

The interview is complete when all four points have an answer.

**⛔ Stop gate.** Show the summary of the four points, the planned path `docs/analysis/YYYY-MM-DD-<topic>.md` and a short plan of the work. Wait for the user's explicit confirmation.

## 2. Work

Gather evidence from the agreed sources. Delegate reading-heavy legwork to [research](../research/SKILL.md) or to subagents; their findings files become sources of the analysis.

The work is complete when every part of the question has an answer traced to a source, or is recorded as a limitation.

## 3. Draft

Write `docs/analysis/YYYY-MM-DD-<topic>.md` (today's date; if the file exists, append `-2`, `-3`, …) from [`references/analysis-template.md`](references/analysis-template.md), in the human-facing language set in the root `AGENTS.md`. Fill every section and remove the template's guidance comments.

**⛔ Stop gate.** Show the document's path, the conclusion and the limitations. Wait for approval; revise the draft on each remark until the user approves it.

## 4. Close

Close only on the user's explicit command:

- **Handoff** — [handoff](../handoff/SKILL.md): move the context to a fresh session, nothing committed.
- **Close-task** — [close-task](../close-task/SKILL.md): handoff plus one commit carrying the analysis document. An Analysis task has no tickets, tests or code review: record those preflight checks as "not applicable".
