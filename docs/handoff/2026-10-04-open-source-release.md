# Handoff: open-source-release (Подготовка к Open Source и первому релизу)

## State
- **Цель:** Преобразование репозитория-шаблона в публичный Open Source проект под лицензией MIT с версионированием по SemVer, автоматизацией релизов, CI-проверками и документацией для контрибьюторов.
- **Текущий этап:** Завершён Этап 5 (Ревью кода), выполнено частичное закрытие задачи (`/close-task` для тикетов 01–11).
- **Что сделано:**
  - Тикет 01: SemVer-парсер (`.agents/scripts/SemVer.ps1`), базовый файл `VERSION` (`0.0.0`), `CHANGELOG.md`.
  - Тикет 02: Поддержка нового формата версий `vX.Y.Z (<sha>)` в `Initialize-Project.ps1`, режим `Update` с выдержкой чейнджлога и предупреждением о MAJOR-мажорных изменениях.
  - Тикет 03: Режим `-Plan` релизного скрипта `.agents/skills/release/scripts/Invoke-Release.ps1` с анализом Conventional Commits и проверкой предусловий P1–P5.
  - Тикет 04: Режимы `-Apply`, `-PushOnly`, `-Undo` в `Invoke-Release.ps1`, атомарный push, строгий запрет `--force` / `--force-with-lease`.
  - Тикет 05: Режим `-Notes` и GitHub Actions workflow публикации релизов `.github/workflows/release.yml`.
  - Тикет 06: Изоляция Проектов (очистка Meta-файлов и удаление релизной машинерии из дочерних репозиториев в `Initialize-Project.ps1`).
  - Тикет 07: CI workflow `.github/workflows/ci.yml` (матрица Windows + Ubuntu), валидация PR-заголовков, Dependabot, шаблоны issue и PR.
  - Тикет 08: Guardrails в `AGENTS.md` (разрешение на push только через подтверждённый `/release`, запрет force-push, список англоязычных файлов).
  - Тикет 09: Публичные документы (`LICENSE` MIT, `THIRD_PARTY_NOTICES.md`, `CONTRIBUTING.md`, `SECURITY.md`, `README.md`, `README.ru.md`, `docs/releasing.md`).
  - Тикет 10: Проект переименован в `StrataHarness` (`cannoneer85-svg/StrataHarness`).
  - Тикет 11: Создан приватный репозиторий на GitHub, настроен ruleset для ветки `main` с bypass для владельца, подключён `origin`.
  - Пройдено ревью кода по стандартам и по спеке, устранены все замечания.
  - Все тесты зелёные: 198 тестов Pester пройдены, `Test-Template.ps1` возвращает код 0.

## Open tickets
- `.scratch/open-source-release/issues/12-first-release-and-go-public.md` — Status: `ready-for-human`. Выпуск первого релиза `v1.0.0` через команду `/release`, публикация GitHub Release через Action, переключение репозитория в Public.

## Next step
Запустить команду `/release -Version 1.0.0` (или «выпускай релиз»):
1. Скрипт сформирует релизные заметки версии `1.0.0`.
2. Показать релизный стоп-гейт пользователю (название релиза, версия, заметки).
3. После подтверждения пользователя выполнить `-Apply` (скрипт создаст коммит `chore(release): v1.0.0`, аннотированный тег `v1.0.0` и сделает первый атомарный push `git push --atomic origin main v1.0.0`).
4. Проверить выполнение GitHub Actions workflow и переключить репозиторий в публичный доступ по чек-листу.

## Recommended skills
- `/release` (`.agents/skills/release/SKILL.md`) — выпуск первого релиза `v1.0.0`.
