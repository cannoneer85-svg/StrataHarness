# Handoff: Двойной контур на Стоп-гейтах (`dual-stop-gate`)

- **Дата:** 2026-10-26
- **Маршрут:** Development — Minor (`1 → 4 (In-Place) → 5 → 6`)
- **Базовый коммит:** `ccf58f34f73b482e667393cf0e91d2b5cdcaaa7a`

## State

- **Цель:** Устранить проблему потери контекста продолжения на Стоп-гейтах, когда интерактивный инструмент опроса (`ask_question` / `AskUserQuestion`) не вызывается моделью на длинных отчётах или блокируется системным промптом среды, внедрив обязательный «двойной контур» (резюме следующего активного шага и нумерованный список вариантов в конце текста отчёта + одновременный вызов `ask_question` / `AskUserQuestion` в том же ходе).
- **Достигнутый этап:** Этап 6 (`Close-task` — задача полностью завершена).
- **Что сделано:**
  1. В [`AGENTS.md`](../../AGENTS.md) (`## Stop gates`) удалён запрет `Do NOT print the continuation options as a text list in the report`. Зафиксировано правило двойного контура в одном ходе: сначала полный отчёт этапа, завершающийся явным указанием следующего активного шага и нумерованными вариантами (`1 / 2` на Шаге 0 и подтверждающих гейтах Stages 1–4, Analysis, Release; `1..4` на Stage 5 Review), и следом в этом же ходе вызов `ask_question` / `AskUserQuestion` с теми же опциями (печать текстового списка является обязательным fallback-контуром и никогда не заменяет вызов тула).
  2. Синхронизированы формулировки Стоп-гейтов в скиллах этапов:
     - [`.agents/skills/implement/SKILL.md`](../../.agents/skills/implement/SKILL.md)
     - [`.agents/skills/code-review/SKILL.md`](../../.agents/skills/code-review/SKILL.md)
     - [`.agents/skills/analyze/SKILL.md`](../../.agents/skills/analyze/SKILL.md)
     - [`.agents/skills/release/SKILL.md`](../../.agents/skills/release/SKILL.md)
  3. Обновлено зеркало `.claude/skills/` через `.agents/scripts/Sync-ClaudeSkills.ps1`.
  4. Проведено двухконтурное код-ревью (`Standards`: 0 hard violations, 1 judgement call оставлен без изменений; `Spec`: 0 замечаний) и пройдены все preflight-проверки (`Test-Template.ps1` — OK, Pester — `218 passed, 0 failed`).
- **Что в работе:** ничего (задача закрыта).
- **Принятые решения и нюансы (не зафиксированные в отдельных спеках/ADR):**
  - На маршруте `Minor` отдельная спецификация в `docs/specs/` не создавалась; решения `D1`–`D3` (формат нумерованного блока `1 / 2` и `1..4`, обязательность обоих каналов в одном ходе и синхронизация 4 скиллов этапов) полностью отражены в `AGENTS.md` и перечисленных `SKILL.md`.

## Open tickets

none

## Next step

Опубликовать локальный коммит в удалённый репозиторий (`git push`) или при необходимости выпустить патч-релиз Шаблона через `/release`.

## Recommended skills

- [`release`](../../.agents/skills/release/SKILL.md) — расчёт следующей версии SemVer, подготовка заметок о релизе и публикация тега после подтверждения на Стоп-гейте.
- [`ask`](../../.agents/skills/ask/SKILL.md) — маршрутизация следующей задачи по правилам `AGENTS.md`.
