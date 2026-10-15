<!-- Copied from docs/handoff/2026-10-15-tickets-map-colors.md -->
# Передача контекста: Обязательная цветовая градация и легенда Mermaid-карты тикетов в `to-tickets`

- **Дата:** 2026-10-15
- **Ветка:** `main`
- **Категория:** Minor
- **Статус:** Завершено (`/close-task`)

---

## Состояние

### Цель
Исключить пропуск чтения шаблона [`tickets-map-template.md`](../../.agents/skills/to-tickets/references/tickets-map-template.md) агентом на этапе создания тикетов (`/to-tickets`), из-за которого в превью (шаг 4) и итоговом отчёте (шаги 5 и 7) мог генерироваться неокрашенный граф `flowchart TD` без классов статусов (`classDef` / `class`), коротких меток узлов и строки легенды.

### Что сделано
1. В [`.agents/skills/to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md#L50-L55) (шаг 4 `Quiz the user`) косвенная отсылка `(see step 5)` заменена на прямое требование прочитать [`references/tickets-map-template.md`](../../.agents/skills/to-tickets/references/tickets-map-template.md) перед отрисовкой диаграммы и включить три обязательных элемента:
   - **Nodes:** короткие метки `T<NN>["<NN> <short title>"]` (до 4 слов).
   - **Colour classes:** все четыре фиксированных `classDef` (`ready`, `inprogress`, `done`, `blocked`) и привязка `class` к каждому узлу (`ready` для стартового фронтира без блокеров, `blocked` для зависимых тикетов).
   - **Legend:** строка `**Легенда:** ...` непосредственно под блоком Mermaid.
2. В шагах 5 и 7 [`.agents/skills/to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md#L72-L130) явно закреплено требование включать все четыре `classDef`, привязку `class` и строку легенды как при сохранении карты тикетов (`TICKETS.md`), так и при выводе пользователю на стоп-гейте этапа.
3. Синхронизировано зеркало `.claude/skills/to-tickets/SKILL.md` через [`.agents/scripts/Sync-ClaudeSkills.ps1`](../../.agents/scripts/Sync-ClaudeSkills.ps1).
4. Пройдены валидатор Шаблона (`Test-Template.ps1` — 0 нарушений), полный набор Pester-тестов (`tests/` — 216 passed, 0 failed) и параллельное ревью `/code-review` по осям Standards и Spec (`0 hard violations`).

---

## Открытые тикеты
Нет (`none`).

---

## Следующий шаг
Репозиторий находится в чистом и консистентном состоянии. Можно переходить к следующим задачам или подготовке релиза (`/release -Plan`).

---

## Рекомендуемые скиллы
- [`ask`](../../.agents/skills/ask/SKILL.md) — выбор подходящего маршрута и скилла для новой задачи.
- [`to-tickets`](../../.agents/skills/to-tickets/SKILL.md) — декомпозиция спецификации на вертикальные тикеты с окрашенной Mermaid-картой зависимостей.
- [`release`](../../.agents/skills/release/SKILL.md) — выпуск новой версии Шаблона.
