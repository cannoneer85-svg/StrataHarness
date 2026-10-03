---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

> [!CAUTION]
> **Запуск только по прямой команде пользователя**: Данный скилл и шаг жизненного цикла запускаются **ИСКЛЮЧИТЕЛЬНО** по явному указанию пользователя (*«делай handoff»*, *«фиксируй»*, *«закрывай задачу»*). Агент ни при каких обстоятельствах не имеет права запускать `/handoff` автоматически.

Write a handoff document summarising the current conversation so a fresh agent can continue the work. 
Save the handoff document directly to the project repository under `docs/handoff/YYYY-MM-DD-<feature>.md` and update `docs/handoff/LATEST.md`.
Clean up temporary files and completed task tickets from `.scratch/<feature>/`.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
