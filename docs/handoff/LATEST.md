<!-- copy of docs/handoff/2026-10-15-retro-env-improvements.md -->
# Handoff: retro-env-improvements

## State
- **Цель:** Устранение точек трения окружения по итогам ретроспективы (`/retro`) после внедрения интерактивных Стоп-гейтов и выпуска `v1.3.0`.
- **Достигнутый этап:** Stage 6 — Close (все 3 выбранных в `/retro` кандидата реализованы, протестированы и зафиксированы).
- **Что сделано:**
  1. Создан корневой [`CODING_STANDARDS.md`](../../CODING_STANDARDS.md) на английском языке для самого Шаблона (содержит judgement-критерии для оси **Standards** в `/code-review`: `writing-for-agents`, контракт обратной совместимости `Initialize-Project.ps1 -Mode Update` и двухуровневое тестирование / изоляция фикстур в `$TestDrive`). При `Initialize-Project.ps1 -Mode New` он штатно заменяется на `templates/CODING_STANDARDS.md`.
  2. В [`.agents/scripts/Test-Template.ps1`](../../.agents/scripts/Test-Template.ps1) добавлено правило **Rule 11 (`claude-mirror`)**: детерминированная проверка синхронизации `.claude/skills/` с `.agents/skills/` (через быстрое сравнение размеров и `SequenceEqual` байтовых массивов). В [`tests/Test-Template.Tests.ps1`](../../tests/Test-Template.Tests.ps1) добавлены 2 юнит-теста для Rule 11.
  3. В [`tests/Initialize-Project.Tests.ps1`](../../tests/Initialize-Project.Tests.ps1) внедрено кэширование эталонных фикстур (`GoldenNewFixture` и `GoldenUpdateFixture`) в `BeforeAll` с очисткой в `AfterAll`, конвейерные сравнения `byte[] | Should -Be` заменены на `[System.Linq.Enumerable]::SequenceEqual(...) | Should -BeTrue`, отключены предупреждения `core.safecrlf` в фикстурах. Время прогона `Initialize-Project.Tests.ps1` сократилось с 274–307 с до 138.4 с.
- **Что в процессе:** Ничего, задача полностью завершена.
- **Нюансы и решения:**
  - В Pester 5/6 передача `byte[]` по конвейеру в `Should -Be` поэлементно распаковывает массив в конвейер PowerShell, что на сотнях файлов в фикстурах давало ~150 секунд накладных расходов; использование `[System.Linq.Enumerable]::SequenceEqual` устраняет эту задержку.

## Open tickets
none

## Next step
Репозиторий в чистом состоянии и готов к следующим задачам.

## Recommended skills
- [`ask`](../../.agents/skills/ask/SKILL.md) — выбор подходящего навыка или маршрута для новой задачи.
- [`release`](../../.agents/skills/release/SKILL.md) — выпуск новой версии Шаблона.
