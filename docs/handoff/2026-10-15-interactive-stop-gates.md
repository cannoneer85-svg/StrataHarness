# Handoff: interactive-stop-gates

## State
- **Цель:** Внедрение интерактивного кнопочного подтверждения на Стоп-гейтах Шаблона через нативный инструмент вопроса среды (Antigravity: `ask_question`, Claude Code: `AskUserQuestion`; с автоматическим текстовым fallback для сред без такого инструмента).
- **Достигнутый этап:** Stage 6 — Close (маршрут **Development — Minor**: интервью, реализация In-Place, код-ревью и полный preflight завершены).
- **Что сделано:**
  1. В корневом [`AGENTS.md`](../../AGENTS.md) в секции `## Stop gates` закреплён вызов интерактивного инструмента вопроса среды на всех Стоп-гейтах (Шаг 0, этапы Stage 1–5, флоу Analysis и Release) параллельно с выводом отчёта этапа в тело сообщения.
  2. Зафиксирован стандарт вариантов кнопок:
     - На Шаге 0 и подтверждающих Стоп-гейтах (Stages 1–4, Analysis, Release): 2 варианта — `(Recommended)` согласовать и перейти дальше, либо запросить правки/уточнения.
     - На Стоп-гейте Stage 5 (Review): явное представление вариантов следующего шага в отчёте и в виде интерактивных кнопок выбора (`/close-task`, `/handoff`, дополнительные правки, `/retro`).
  3. В `Hard guardrail` в [`AGENTS.md`](../../AGENTS.md) и в [`.agents/skills/code-review/SKILL.md`](../../.agents/skills/code-review/SKILL.md) закреплено, что явный выбор пользователем соответствующей кнопки действия на Стоп-гейте Stage 5 (`/close-task`, `/handoff`) или Release приравнивается к явной команде пользователя.
  4. В [`AGENTS.md`](../../AGENTS.md), [`.agents/skills/grill-with-docs/SKILL.md`](../../.agents/skills/grill-with-docs/SKILL.md) и [`.agents/skills/analyze/SKILL.md`](../../.agents/skills/analyze/SKILL.md) синхронизировано указание нативных инструментов для Antigravity (`ask_question`) и Claude Code (`AskUserQuestion`), в [`.agents/skills/implement/SKILL.md`](../../.agents/skills/implement/SKILL.md) уточнена формулировка Стоп-гейта завершения реализации, а также синхронизировано зеркало `.claude/skills/`.
- **Что в процессе:** Ничего, задача полностью завершена.
- **Нюансы и решения:**
  - В Antigravity вызов `ask_question` в одном шаге ответа (`PLANNER_RESPONSE`) с текстовым отчётом рендерит отчёт прямо над карточкой с кнопками и ставит выполнение на паузу до клика пользователя, после чего агент сразу переходит к следующему этапу без лишнего хода.
  - Единым источником истины по механике Стоп-гейтов оставлен раздел `## Stop gates` в [`AGENTS.md`](../../AGENTS.md), чтобы не дублировать правило во всех проходных скиллах (согласно дисциплине `writing-for-agents`).

## Open tickets
none

## Next step
Репозиторий в чистом состоянии и готов к следующим задачам или выпуску релиза через `/release`.

## Recommended skills
- [`ask`](../../.agents/skills/ask/SKILL.md) — выбор подходящего навыка или маршрута для новой задачи.
- [`release`](../../.agents/skills/release/SKILL.md) — выпуск новой версии Шаблона.
- [`retro`](../../.agents/skills/retro/SKILL.md) — ретроспектива окружения агента.
