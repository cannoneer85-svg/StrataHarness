# Передача контекста: Внедрение откалиброванных улучшений из ретроспективы (`upstream-retro-improvements`)

- **Дата:** 2026-10-24
- **Ветка:** `main`
- **Тип задачи:** Analysis + Development (Minor)
- **Статус:** Завершено (`/close-task`)

---

## Состояние

### Цель
Провести архитектурный аудит предложений из `STRATAHARNESS_UPSTREAM_PROPOSAL.md` дочернего проекта `phygital`, отделить универсальные улучшения **Шаблона** от избыточных порогов и локальной специфики монорепозитория (такой как `.agents/CONTEXT-MAP.md`), и внедрить откалиброванные правила в ядро **Шаблона** (`StrataHarness`).

### Что сделано
1. **Аналитический аудит ([`docs/analysis/2026-10-23-upstream-retro-proposal-audit.md`](../analysis/2026-10-23-upstream-retro-proposal-audit.md)):**
   - Оценены все 4 пункта входного предложения; отклонена привязка к несуществующему в апстриме `.agents/CONTEXT-MAP.md` и избыточные триггеры `>3 files` / `external I/O probes` для 1–2 тикетов; подготовлены откалиброванные диффы для 5 целевых файлов.
2. **D1 — Синхронизация порогов `In-Place` vs `Orchestrator` в [`AGENTS.md`](../../AGENTS.md):**
   - В таблице `Routes` маршрут `Feature` уточнён как `1 → 2 → 3 → 4 (In-Place for 1–2 tickets; Orchestrator for ≥3) → 5 → 6`.
   - В разделе `Context budget` синхронизированы пороги выбора `In-Place` (`Minor` или 1–2 тикета до `~60k` токенов) против обязательного `Sequential Subagents / Orchestrator` (`≥3` тикетов или 2 тикета по файлам `>1,000` строк / `>60k` токенов) с анонсом стратегии на **Стоп-гейте** Этапа 3.
3. **D2 — Правило выбора стратегии и запрет тестовых тикетов в [`.agents/skills/to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md):**
   - В `<vertical-slice-rules>` добавлен запрет на вынос автотестов тикетов `01..N-1` в отдельный финальный тикет `N` (`No standalone "Tests-only" or single-layer tickets`, с оговоркой для финального шага `expand–contract`).
   - В шаге 7 (`Show the tickets map`) добавлен обязательный вывод метаданных `Active Stage` / `Execution Strategy` и блок `Execution Strategy Selection Rule`.
4. **D3 — Защита от потери стадии при Compaction в [`.agents/skills/to-tickets/references/tickets-map-template.md`](../../.agents/skills/to-tickets/references/tickets-map-template.md):**
   - В `## Rules` и `## Block` добавлена строка `**Active Stage:** Stage 3 (Tickets) | **Execution Strategy:** <In-Place | Sequential Subagents | Multi-Session>`, обновляемая при переходах между этапами 3, 4 и 5.
5. **D4 — `Hard override` стратегии и проверка `Active Stage` в [`.agents/skills/implement/SKILL.md`](../../.agents/skills/implement/SKILL.md):**
   - В `## 2. Choose the execution strategy` добавлен `Hard override`, запрещающий `In-Place` при `≥3` тикетах или 2 тикетах по файлам `>1,000` строк даже при предварительном обсуждении `In-Place` на более ранних этапах, и обновление `Active Stage: Stage 4 (Implement)`.
   - В блоке `Compaction and session recovery` добавлена проверка `Active Stage: Stage 5 (Code Review)`.
6. **D5 & D6 — Детерминированный триггер `Adversary` в [`.agents/skills/code-review/SKILL.md`](../../.agents/skills/code-review/SKILL.md) и [`.agents/SKILLS.md`](../../.agents/SKILLS.md):**
   - Субагент **Adversary** переведён из `optional (Epic & security-critical tasks only)` в обязательный по чек-листу из 3 условий (маршрут `Epic`, требование в `CODING_STANDARDS.md`, либо наличие в диффе любого из 5 классов риск-сигналов: процессы/shell, сеть/API/IPC, конкурентность/таймеры/кэши, аутентификация/права/секреты/конфиг, пути ФС/симлинки/миграции).
   - В шаге 1 `code-review/SKILL.md` добавлено обновление `Active Stage: Stage 5 (Code Review)` в `TICKETS.md`; обновлена строка описания `code-review` в `.agents/SKILLS.md`; синхронизировано зеркало `.claude/skills/`.

---

## Открытые тикеты
none

---

## Следующий шаг
При необходимости выпустить новый патч-релиз Шаблона (`v1.4.4`) через скилл `/release` или опубликовать накопленные коммиты через `git push`.

---

## Рекомендуемые скиллы
- [`release`](../../.agents/skills/release/SKILL.md) — планирование и выпуск новой версии Шаблона.
