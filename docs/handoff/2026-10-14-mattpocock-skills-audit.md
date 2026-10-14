# Handoff: Аудит обновлений mattpocock/skills (v1.3.0 – v1.3.1 и main)

- **Дата:** 2026-10-14
- **Тип задачи:** Задача анализа (`Analysis`)
- **Статус:** Закрыта

## Состояние

- **Цель:** Провести полный сравнительный аудит последних релизов (`v1.3.0`, `v1.3.1`) и невыпущенных коммитов ветки `main` репозитория `mattpocock/skills` (до коммита `49dd158` от `2026-10-09`) относительно базовой версии скиллов в нашем Шаблоне, выявить кандидатов на перенос и оценить, где наша реализация уже ушла вперёд.
- **Итоговый документ анализа:** [`docs/analysis/2026-10-14-mattpocock-skills-audit.md`](../analysis/2026-10-14-mattpocock-skills-audit.md).
- **Ключевые выводы:**
  1. Базовая точка заимствования в StrataHarness установлена точно: коммит `9c9f36c` (`2026-08-17`, сразу после `v1.2.3`) — 31 из 35 исходных скиллов совпадают с нашим базовым коммитом `821c2a7` побайтово.
  2. Ядро нашего **Цикла разработки** (`grill-with-docs`, `to-spec`, `to-tickets`, `implement`, `code-review`, `handoff`, `close-task`, `init-project`, `ask`, `analyze`, `minimal-diff`) существенно превосходит апстрим (включая новый апстримный `implement-spec`) по управлению контекстом, стоп-гейтам, Оркестратору, трёхосевому ревью (`Adversary`), экономии тестовых прогонов и детерминированному обновлению Проектов.
  3. Из 4 новых скиллов апстрима рекомендовано:
     - **взять с адаптацией:** `retro` (`engineering/retro`) — ретроспектива сессии для улучшения окружения агента с разделением механических нарушений (в детерминированные проверки линтера/CI/тестов) и *judgement calls* (в `CODING_STANDARDS.md`);
     - **взять опционально:** `pr` (`engineering/pr`) — компактный шаблон описания PR (`Summary` по `show-me`, `Before/After Evidence`, `One-way/Two-way Door` + `Blast Radius`);
     - **пропустить:** `implement-spec` (перекрыт нашим `implement`) и `chief-of-staff` (экспериментальный черновик).
  4. Выделены **8 точечных багфиксов и улучшений** в общих скиллах и шаблонах трекеров для переноса в следующей задаче разработки:
     - [`wizard/template.sh`](../../.agents/skills/wizard/template.sh) и [`wizard/SKILL.md`](../../.agents/skills/wizard/SKILL.md) — 10 технических фиксов bash-шаблона (`#1198`, `#1237`);
     - шаблоны трекеров в [`init-project/templates/`](../../.agents/skills/init-project/templates/) — исправление падающего `gh pr list --json ... authorAssociation` на `gh api .../pulls`, флага `glab issue list -O json`, чтения `gh issue view --json`, привязки `sub-issue` и создания триаж-лейблов (`#1187`, `#1188`, `#1197`);
     - [`claude-handoff/SKILL.md`](../../.agents/skills/claude-handoff/SKILL.md) — передача саммари через временный файл `-- "$(cat <summary file>)"` без шелл-интерполяции (`#1185`);
     - [`teach/SKILL.md`](../../.agents/skills/teach/SKILL.md) — привязка путей `./lessons/` к рабочей директории запуска и смена позиции правильного ответа в квизах (`#1183`);
     - [`diagnosing-bugs/SKILL.md`](../../.agents/skills/diagnosing-bugs/SKILL.md) — проверка принудительной мутации через `diff` в Phase 5 перед доверием красному тесту (`#1209`);
     - [`tdd/SKILL.md`](../../.agents/skills/tdd/SKILL.md) — однострочная заметка «что ловит и что пропускает» для каждого предлагаемого шва (`#1192`);
     - [`grilling/SKILL.md`](../../.agents/skills/grilling/SKILL.md) — разделитель `---` между вопросами раунда и формулировка вопроса так, чтобы «да» принимало рекомендацию (`#917`, `#1193`);
     - [`wayfinder/SKILL.md`](../../.agents/skills/wayfinder/SKILL.md), [`to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md), [`implement/SKILL.md`](../../.agents/skills/implement/SKILL.md), [`ask/SKILL.md`](../../.agents/skills/ask/SKILL.md), [`wait-what/SKILL.md`](../../.agents/skills/wait-what/SKILL.md) — точечные уточнения по работе с трекером, чтению `SKILL.md` и `CONTEXT-MAP.md`.
  5. Переименование `CONTEXT.md` → `GLOSSARY.md` и удаление `resolving-merge-conflicts` из апстрима отклонены.

## Открытые тикеты

none

## Следующий шаг

При решении внедрить найденные улучшения — запустить задачу разработки категории **Feature** по списку из раздела 4 отчёта [`docs/analysis/2026-10-14-mattpocock-skills-audit.md`](../analysis/2026-10-14-mattpocock-skills-audit.md) (бэкпорт 8 точечных багфиксов и адаптация скилла `retro`, опционально `pr`).

## Рекомендуемые скиллы

- [`grill-with-docs`](../../.agents/skills/grill-with-docs/SKILL.md) — интервью для задачи разработки по переносу выбранных улучшений и адаптации `retro`.
- [`to-spec`](../../.agents/skills/to-spec/SKILL.md) — формирование спецификации обновления скиллов.
- [`implement`](../../.agents/skills/implement/SKILL.md) — реализация изменений в `.agents/skills/` и шаблонах трекеров.
