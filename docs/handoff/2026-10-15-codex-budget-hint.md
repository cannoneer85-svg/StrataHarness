# Передача контекста: Уточнение лимита контекстного бюджета OpenAI Codex в валидаторе и документации

- **Дата:** 2026-10-15
- **Ветка:** `main`
- **Категория:** Minor
- **Статус:** Завершено (`/close-task`)

---

## Состояние

### Цель
Сделать диагностическое сообщение валидатора [`Test-Template.ps1`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/scripts/Test-Template.ps1) и руководство по механике скиллов [`SKILL-MECHANICS.md`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/writing-for-agents/SKILL-MECHANICS.md) прозрачными для разработчиков и агентов, явно указав платформенное происхождение суммарного лимита описаний скиллов (8 000 символов) — требование совместимости с рантаймом OpenAI Codex и предотвращение отсечения избыточных скиллов.

### Что сделано
1. В [`.agents/scripts/Test-Template.ps1`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/scripts/Test-Template.ps1#L179-L181) обновлен текст нарушения правила `description-length`:
   - В само сообщение об ошибке добавлено: `maximum budget for OpenAI Codex compatibility is 8000 characters (excess skills may be omitted by runtime)`.
   - В подсказку `Fix:` добавлено пояснение: `(Codex progressive disclosure limit)`.
2. В [`tests/Test-Template.Tests.ps1`](file:///d:/YandexDisk/MyProjects/AI/strataharness/tests/Test-Template.Tests.ps1#L205-L210) актуализирован юнит-тест проверки текста ошибки валидатора.
3. В [`.agents/skills/writing-for-agents/SKILL-MECHANICS.md`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/writing-for-agents/SKILL-MECHANICS.md#L16-L23) добавлен подраздел `### Description limits and context budget` с явным разделением двух границ:
   - Лимит на отдельный `SKILL.md` (1 024 символа по спецификации Agent Skills).
   - Суммарный лимит на каталог описаний (8 000 символов по рантайм-бюджету прогрессивного раскрытия OpenAI Codex).
4. Зеркало [`.claude/skills/writing-for-agents/SKILL-MECHANICS.md`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.claude/skills/writing-for-agents/SKILL-MECHANICS.md) синхронизировано через [`.agents/scripts/Sync-ClaudeSkills.ps1`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/scripts/Sync-ClaudeSkills.ps1).
5. Пройден полный цикл проверок: TDD Red/Green, предпроверочные тесты (35 тестов green), код-ревью субагентами Standards и Spec (0 нарушений).

---

## Открытые тикеты
Нет (`none`).

---

## Следующий шаг
Репозиторий находится в стабильном консистентном состоянии с проходящими тестами. Готов к выполнению следующих продуктовых задач или формированию релиза (`/release -Plan`).

---

## Рекомендуемые скиллы
- [`ask`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/ask/SKILL.md) — выбор подходящего маршрута и скилла для новой задачи.
- [`code-review`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/code-review/SKILL.md) — статический анализ изменений по осям Standards, Spec и Adversary.
- [`release`](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/release/SKILL.md) — выпуск новой версии Шаблона.
