# Handoff: release-perf

## State
- **Цель:** Оптимизация производительности и прозрачности выполнения скрипта релиза [`Invoke-Release.ps1`](../../.agents/skills/release/scripts/Invoke-Release.ps1), устранение 6.5-минутной паузы и видимости зависания при выполнении фазы `-Apply`.
- **Достигнутый этап:** Stage 6 — Close (задача полностью реализована, протестирована и проверена на код-ревью).
- **Что сделано:**
  1. В `Invoke-Release.ps1` реализован условный пропуск повторного тяжёлого прогона Pester в режиме `-Apply`, если `.scratch/release/plan.json` существует, его `HeadSha` в точности совпадает с текущим `HEAD`, и проверки в фазе `-Plan` были фактически валидированы (`ChecksValidated == true`). При этом быстрая структурная проверка [`Test-Template.ps1`](../../.agents/scripts/Test-Template.ps1) (<1 сек) сохраняется.
  2. В `Invoke-Plan` добавлено сохранение булева флага `ChecksValidated` в файл плана, предотвращающее ложный пропуск тестов в apply, если план формировался с `-SkipChecks`.
  3. В вызов дочернего процесса Pester добавлена конфигурация `Invoke-Pester -Configuration @{ Run = @{ Path = '$testsDir'; Exit = $true }; Output = @{ Verbosity = 'None' } }`, гарантирующая корректный ненулевой код возврата при падении тестов и исключающая создание мусорных артефактов `testResults.xml`.
  4. Во все сценарии (`-Plan`, `-Apply`, `-PushOnly`, `-Undo`) добавлен вывод структурированных сообщений прогресса `[release] ...`, обеспечивающий полную прозрачность выполнения.
  5. В [`tests/Invoke-Release.Tests.ps1`](../../tests/Invoke-Release.Tests.ps1) исправлена фикстура `New-ReleaseFixture` и добавлены 3 интеграционных теста новой логики.
  6. В [`.agents/skills/release/SKILL.md`](../../.agents/skills/release/SKILL.md) обновлена документация этапа `-Apply`.
- **Что в процессе:** Ничего, реализация завершена.
- **Нюансы и решения:**
  - Pester 5/6 по умолчанию не устанавливает ненулевой `$LASTEXITCODE` при падении тестов без явного указания `Run = @{ Exit = $true }` или `-CI`. Использование конфигурации с `Run.Exit = $true` надёжно и не создаёт артефактов NUnit.

## Open tickets
none

## Next step
Репозиторий готов к работе. При необходимости выпустить следующую версию шаблона с этой оптимизацией использовать `/release`.

## Recommended skills
- [`release`](../../.agents/skills/release/SKILL.md) — релиз новой версии шаблона.
- [`ask`](../../.agents/skills/ask/SKILL.md) — выбор подходящего навыка или маршрута для новой задачи.
- [`retro`](../../.agents/skills/retro/SKILL.md) — ретроспектива для улучшения окружения агента.
