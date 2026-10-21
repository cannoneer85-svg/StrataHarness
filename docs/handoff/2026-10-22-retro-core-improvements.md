# Передача контекста: Бэкпорт платформенных улучшений ядра Шаблона (`retro-core-improvements`)

- **Дата:** 2026-10-22
- **Ветка:** `main`
- **Тип задачи:** Development (Minor)
- **Статус:** Завершено (`/close-task`)

---

## Состояние

### Цель
Критически оценить и перенести в ядро Шаблона (`StrataHarness`) платформенные улучшения, выявленные по итогам эксплуатации в дочернем проекте `phygital`, без загрязнения апстрима спецификой монорепозитория и подмодулей.

### Что сделано
1. **R1 — Уточнение выбора стратегии `In-Place` ([`.agents/skills/implement/SKILL.md`](../../.agents/skills/implement/SKILL.md)):**
   - Условие строки `In-Place` в таблице выбора стратегии сужено до `Minor route, or 1–2 tickets whose total forecast stays under ~60k tokens`, чтобы задачи из 3 и более тикетов гарантированно направлялись в `Sequential Subagents` и не перехватывались первой строкой таблицы по оценке токенов.
   - Генерация `BRIEF.md` сохранена исключительно для `Sequential Subagents` (`## 4`), а во всём файле оставлен канонический путь `.scratch/<feature>/` (без монорепо-специфики `<module>/`).
2. **R2 — Совместимость проверочных скриптов с Windows PowerShell 5.1 и PowerShell 7+ ([`.agents/scripts/Test-Template.ps1`](../../.agents/scripts/Test-Template.ps1), [`.agents/scripts/Sync-ClaudeSkills.ps1`](../../.agents/scripts/Sync-ClaudeSkills.ps1)):**
   - В `Test-Template.ps1` устранены все вызовы `Join-Path` с 3–4 аргументами, метод `.NET Core` `[System.IO.Path]::GetRelativePath` заменён на кросс-версионную операцию `.Substring($Base.Length).TrimStart('\', '/').Replace('\', '/')`, чтение `$IsWindows` защищено для `Set-StrictMode -Version Latest` в PS 5.1, а не-ASCII литералы в Правилах 8 и 9 переведены на ASCII-безопасные Unicode-последовательности (`\uXXXX` и `[regex]::Unescape`) для корректного парсинга UTF-8 файла без BOM в `powershell.exe`.
   - В `Sync-ClaudeSkills.ps1` снято ограничение `#Requires -Version 7.0`, дефолт `$RepoRoot` перенесён из `param(...)` в тело скрипта (в PS 5.1 `$PSScriptRoot` пуст внутри объявления `param`), заменены 3-аргументные `Join-Path` и `[IO.Path]::GetRelativePath`.
   - Добавлены тесты совместимости с `powershell.exe` в [`tests/Test-Template.Tests.ps1`](../../tests/Test-Template.Tests.ps1) и [`tests/Sync-ClaudeSkills.Tests.ps1`](../../tests/Sync-ClaudeSkills.Tests.ps1).
3. **R3 — Исключение `git-hybrid-commit` из апстрима:**
   - Принято решение оставить кастомный скилл `git-hybrid-commit` (`hybrid_commit.ps1`) локальным скиллом проекта `phygital`, чтобы не нарушать инвариант запрета `git push` в `AGENTS.md` и не расходовать общий бюджет длины описаний скиллов.
4. **R4 — Стандарт `.env.example` и запрет боевых фоллбэков ([`.agents/skills/init-project/templates/CODING_STANDARDS.md`](../../.agents/skills/init-project/templates/CODING_STANDARDS.md), [`.agents/skills/code-review/SKILL.md`](../../.agents/skills/code-review/SKILL.md)):**
   - В шаблон стандартов дочерних Проектов добавлен раздел `## Конфигурация окружения и секреты` (обязательность `.env.example` с фиктивными плейсхолдерами и запрет хардкода реальных токенов/адресов в дефолтных фоллбэках).
   - В бриф субагента оси Standards в `code-review/SKILL.md` добавлена проверка опасностей конфигурации окружения.
   - Синхронизировано зеркало `.claude/skills/`.

---

## Открытые тикеты
none

---

## Следующий шаг
При необходимости выпустить патч-релиз Шаблона (`v1.4.3`) с накопленными улучшениями через скилл `/release`.

---

## Рекомендуемые скиллы
- [`release`](../../.agents/skills/release/SKILL.md) — планирование и выпуск новой версии Шаблона (`v1.4.3`).
