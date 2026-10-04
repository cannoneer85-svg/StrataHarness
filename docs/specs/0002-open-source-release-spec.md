# 0002 — Open-source публикация, версии и релизы Шаблона

- **Статус:** draft
- **Дата:** 2026-10-04
- **Категория:** Epic
- **Метка:** `ready-for-agent`
- **Источники:** интервью `.scratch/open-source-release/OPEN_QUESTIONS.md` (23 вопроса + 2 пересмотра), ADR [0004](../adr/0004-semver-template-version.md), [0005](../adr/0005-release-skill-pushes-after-confirmation.md); опирается на ADR [0001](../adr/0001-repo-root-is-the-template.md), [0002](../adr/0002-flat-skills-with-claude-mirror.md), [0003](../adr/0003-edit-upstream-skills-in-place.md)
- **Словарь:** термины с заглавной буквы — в [`.agents/CONTEXT.md`](../../.agents/CONTEXT.md) (в т.ч. новые **Версия Шаблона**, **Релиз**)

> [!NOTE]
> Как и в спеке 0001, здесь указаны пути к файлам: в Шаблоне файлы и их расположение и есть контракты.

> [!IMPORTANT]
> **Название проекта не выбрано.** Везде ниже `<project-name>` — заглушка. Имя выбирается до первого push (тикет переименования). GitHub-аккаунт: `cannoneer85-svg`; репозиторий: `cannoneer85-svg/<project-name>`.

---

## Problem Statement

Я хочу опубликовать Шаблон на GitHub как open-source продукт. Сейчас:

1. **Нет версий.** `template-version` в Реестре — «дата + sha» (`2026-10-03 821c2a7`). Нельзя сказать «у вас 1.2.0, вышла 1.3.0, вот что изменилось», нельзя понять, ломает ли обновление Проект.
2. **Нет истории изменений.** Ни CHANGELOG, ни GitHub Releases. Пользователь Шаблона не видит, что поменялось между версиями.
3. **Выпуск версии — ручной и непроверяемый.** Нет процедуры: что проверить, как назвать, как описать, как опубликовать.
4. **Репозиторий не готов к публикации.** Нет LICENSE, нет правил для внешних контрибьюторов, нет CI на PR, README только на русском, в Реестре — абсолютный локальный путь `d:/YandexDisk/...`. Скиллы Matt Pocock (MIT) включены без уведомления об авторстве.
5. **Внешние PR без формата.** Если люди пришлют PR, нет шаблона, нет автоматической проверки и нет связи между PR и CHANGELOG.

## Solution

1. **SemVer.** Версия Шаблона хранится в файле `VERSION` и git-теге `vX.Y.Z`. Первый Релиз — `v1.0.0`. Проекты записывают `template-version: vX.Y.Z (<sha>)`; `-Mode Update` сравнивает версии и показывает выдержку CHANGELOG (ADR 0004).
2. **Скилл `/release`.** По явной команде владельца агент через скрипт вычисляет следующую версию из Conventional Commits, собирает черновик заметок, переписывает его на английском и **останавливается на стоп-гейте**: номер, название, описание. После «ок» — релизный коммит, аннотированный тег и атомарный push в `origin`. GitHub Action по тегу публикует GitHub Release с текстом из CHANGELOG (ADR 0005).
3. **Публичный слой на английском:** `README.md` (+ `README.ru.md`), `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md`, `LICENSE` (MIT, Sergey Bizikin), шаблоны PR/issue, `docs/releasing.md`. Внутренние документы (спеки, ADR, handoff, тикеты, глоссарий) — на русском.
4. **CI на каждый PR:** `Test-Template.ps1` + Pester на `windows-latest` и `ubuntu-latest`, проверка заголовка PR на Conventional Commits. Merge — только squash: заголовок PR становится строкой CHANGELOG.
5. **Публикация в два шага:** приватный репозиторий → подготовка по чек-листу → переключение в публичный.

---

## User Stories

### Владелец: релизы

1. As the owner, I want to run `/release` and get a proposed next version computed from commits since the last tag, so that I don't decide MAJOR/MINOR/PATCH by hand each time.
2. As the owner, I want the proposal to show the version number, the release title and the full release notes in English before anything is written, so that I can approve or edit them.
3. As the owner, I want nothing to be committed, tagged or pushed until I say "ok", so that a release never happens by accident.
4. As the owner, I want to override the proposed bump (`major|minor|patch`) or set an exact version, so that I can correct the heuristic.
5. As the owner, I want removed or renamed skill folders to be flagged as a MAJOR candidate, so that breaking changes for Projects aren't released as MINOR.
6. As the owner, I want commits that don't follow Conventional Commits to appear under "Other" with a warning, so that nothing silently disappears from the notes.
7. As the owner, I want `/release` to refuse when the working tree is dirty, so that the release commit contains only release files.
8. As the owner, I want `/release` to refuse when I'm not on `main`, so that releases come only from the main line.
9. As the owner, I want `/release` to refuse when `Test-Template.ps1` or Pester tests fail, so that I never release a broken Template.
10. As the owner, I want `/release` to refuse when there are no commits since the last tag, so that empty releases don't happen.
11. As the owner, I want `/release` to refuse to push when my local `main` is behind `origin/main`, so that I don't overwrite or diverge from merged PRs.
12. As the owner, I want the release commit and tag to be pushed atomically, so that GitHub never has a tag without its commit or vice versa.
13. As the owner, I want a failed push to leave the local commit and tag intact and tell me why, so that I can fix auth and retry.
14. As the owner, I want `/release -Undo` to remove an unpushed release (tag + commit), so that I can redo a release I got wrong before publishing.
15. As the owner, I want `-Undo` to refuse once the tag is on the remote, so that published history is never rewritten.
16. As the owner, I want the agent to never force-push, so that the public history is safe.
17. As the owner, I want the first release to work against an empty remote, so that `v1.0.0` publishes the whole repository in one step.
18. As the owner, I want `VERSION`, `CHANGELOG.md` and the Template's own Registry version updated in the same release commit, so that all version markers agree.
19. As the owner, I want the GitHub Release to be created automatically from the tag with the matching CHANGELOG section, so that I don't copy text into the GitHub UI.
20. As the owner, I want the Action to fail without publishing if the tag doesn't match `VERSION` or the CHANGELOG has no section for it, so that inconsistent releases are never published.
21. As the owner, I want the version parser to accept `-rc.N` suffixes, so that pre-releases can be added later without breaking changes.

### Владелец: публикация репозитория

22. As the owner, I want a checklist for creating the private GitHub repository and its settings (Template repository, squash-only, branch rules, Private Vulnerability Reporting, Dependabot), so that I configure GitHub once and correctly.
23. As the owner, I want the agent to add `origin` and verify that git can push without prompts, so that `/release` works on the first try.
24. As the owner, I want a checklist for switching from private to public (no secrets in history, no local paths, LICENSE and README in place), so that going public is safe.
25. As the owner, I want the absolute local path removed from `template-source`, so that my disk layout doesn't leak.
26. As the owner, I want to rename the project folder and the title in `README.md` / `CONTEXT.md` once a name is chosen, so that the product has a proper name before the first push.

### Внешний пользователь Шаблона

27. As a Template user, I want an English README explaining what the Template is and how to create a Project, so that I can evaluate and adopt it.
28. As a Russian-speaking user, I want `README.ru.md`, so that I can read the docs in Russian.
29. As a Template user, I want a CHANGELOG with clear sections (Breaking, Added, Changed, Fixed, Removed), so that I can decide whether to update.
30. As a Project owner, I want `-Mode Update` to tell me my current version, the target version and the CHANGELOG excerpt between them, so that I know what an update brings.
31. As a Project owner with an old `date + sha` version, I want Update to still work and migrate my version field, so that pre-1.0 Projects aren't stranded.
32. As a Template user, I want README instructions to update from a specific tag (`git clone --branch vX.Y.Z`), so that I update to a known version.
33. As a Template user, I want a MIT LICENSE, so that I can legally use and modify the Template.
34. As a Template user, I want `THIRD_PARTY_NOTICES.md` crediting Matt Pocock's skills, so that licensing is clear.
35. As a new Project created via `/init-project`, I want the Template's `CHANGELOG.md`, `VERSION`, `LICENSE`, `.github/` and the `release` skill removed, so that my Project doesn't inherit the Template's release machinery.
36. As a new Project, I want `THIRD_PARTY_NOTICES.md` kept, so that the MIT notice travels with the copied skills.

### Внешний контрибьютор

37. As a contributor, I want `CONTRIBUTING.md` explaining branch, commit and PR rules, so that my PR is mergeable.
38. As a contributor, I want a PR template with a checklist, so that I don't forget tests and the Registry.
39. As a contributor, I want bug and feature issue forms, so that I report problems in a structured way.
40. As a contributor, I want CI to run the Template validator and tests on my PR on Windows and Linux, so that I know my change works before review.
41. As a contributor, I want CI to tell me if my PR title isn't a Conventional Commit, so that it lands correctly in the CHANGELOG after squash.
42. As a security researcher, I want `SECURITY.md` pointing to GitHub Private Vulnerability Reporting, so that I can report privately.

### Безопасность

43. As the owner, I want CI workflows to have read-only permissions and the release workflow only `contents: write`, so that a compromised step can do minimal damage.
44. As the owner, I want all third-party actions pinned by commit SHA and updated by Dependabot, so that a hijacked tag can't inject code.
45. As the owner, I want PRs from forks to run via `pull_request` without secrets, so that external code can't exfiltrate tokens.

---

## Implementation Decisions

### D1. Версия Шаблона (ADR 0004)

- Источник истины — файл `VERSION` в корне: одна строка `X.Y.Z` (без `v`), допускается `X.Y.Z-rc.N`. Тег — `vX.Y.Z`, аннотированный, сообщение = название Релиза.
- До первого Релиза `VERSION` = `0.0.0`, а `CHANGELOG.md` содержит только `[Unreleased]`; первый Релиз выпускается с явной `-Version 1.0.0` и сам пишет `1.0.0` и секцию `[1.0.0]` (утверждено на этапе тикетов: иначе секция задублировалась бы).
- Сравнение версий — по SemVer (pre-release < release той же тройки). Старый формат `YYYY-MM-DD[ sha]` трактуется как версия ниже `1.0.0`.
- В Проекте: `template-version: vX.Y.Z (<short-sha>)`. Sha нужен `-Mode Update` для получения базовой версии файлов через git (как сейчас).
- В самом Шаблоне Реестр хранит `template-version: vX.Y.Z` (без sha: sha релизного коммита неизвестен до коммита); `template-source` — `https://github.com/cannoneer85-svg/<project-name>`.

### D2. Правила bump для Шаблона

| Уровень | Когда | Как определяется |
|---|---|---|
| MAJOR | Изменение, ломающее `-Mode Update` у существующих Проектов: удаление/переименование скилла; изменение параметров `Initialize-Project.ps1`; формат Реестра; маршруты, стоп-гейты, guardrails в `AGENTS.md` | `!` или `BREAKING CHANGE:` в коммите; скрипт дополнительно помечает удалённые/переименованные папки в `.agents/skills/` как кандидат MAJOR; остальное — суждение агента на стоп-гейте |
| MINOR | Новый скилл или возможность | `feat` |
| PATCH | Исправления, тексты, документация, CI | `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `perf`, `style`, `build` |

Пользователь переопределяет через `-Bump major|minor|patch` или `-Version X.Y.Z`. Правила описаны в `docs/releasing.md`.

### D3. Релизный скрипт (шов A)

Новый скилл `.agents/skills/release/` (ручной запуск, источник `свой`), скрипт `scripts/Invoke-Release.ps1`. Режимы:

| Режим | Побочные эффекты | Что делает |
|---|---|---|
| `-Plan [-Bump …] [-Version …]` | только запись плана в `.scratch/release/` | Предусловия (P1–P5) → последний тег → коммиты с тех пор → группировка по типам → предлагаемая версия + флаги (MAJOR-кандидаты, не-Conventional коммиты) → `plan.json` + `notes.draft.md` |
| `-Apply -NotesFile <path> -Title <text>` | коммит, тег, push | Повторная проверка предусловий и того, что HEAD = HEAD из плана → `VERSION`, новая секция в `CHANGELOG.md`, версия в Реестре → коммит `chore(release): vX.Y.Z` → аннотированный тег → P6 → `git push --atomic origin main vX.Y.Z` |
| `-Undo` | удаляет тег и релизный коммит | Только если HEAD — релизный коммит, тег существует локально и **отсутствует** на `origin` (`git ls-remote`); иначе отказ |
| `-Notes <tag>` | нет (stdout) | Для Action: проверяет `tag == v + VERSION` и наличие секции в CHANGELOG, печатает тело секции; иначе exit ≠ 0 |

Предусловия: **P1** чистое дерево; **P2** ветка `main`; **P3** `Test-Template.ps1` и Pester зелёные; **P4** есть коммиты после последнего тега (для первого Релиза — после начала истории); **P5** тег целевой версии ещё не существует; **P6** (перед push) `git fetch origin`, локальный `main` не отстаёт от `origin/main`; отсутствие `origin/main` (пустой remote) допустимо.

Ошибки push: локальные коммит и тег сохраняются, скрипт возвращает код ошибки и текст причины; агент предлагает повтор (`-Apply -PushOnly` — только push уже созданного) или `-Undo`. Force-push в скрипте отсутствует.

Вывод `-Plan` машиночитаем (`plan.json`), чтобы агент не парсил текст.

### D4. Формат CHANGELOG

Английский, по мотивам Keep a Changelog; новые версии сверху:

```md
## [1.1.0] - 2026-11-02 - Release skill pushes after confirmation

### Breaking
### Added
### Changed
### Fixed
### Removed
### Other
```

Пустые разделы не пишутся. Заголовок секции содержит название Релиза; название GitHub Release = `vX.Y.Z — <title>`. Над версиями — короткое вступление и ссылка на SemVer-правила.

### D5. Скилл `/release` — поведение агента

1. Запуск только по явной команде (`/release`, «выпускай релиз»); скилл ручной (`disable-model-invocation: true`).
2. `-Plan` → агент переписывает черновик в человеческий английский (без потери пунктов), предлагает название.
3. **Стоп-гейт:** показ версии, названия, заметок, флагов. Правки — по указанию пользователя.
4. После явного «ок» — `-Apply`. Отчёт: sha, тег, результат push, ссылка на Actions.

### D6. Guardrails и язык в `AGENTS.md`

- Hard guardrail дополняется: `/release` / «выпускай релиз» — единственная команда, разрешающая агенту push; только после подтверждения на стоп-гейте релиза; force-push запрещён всегда.
- Правило Language: явный список англоязычных публичных файлов (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md`, `LICENSE`, `.github/**`, `docs/releasing.md`, сообщения коммитов и заголовки PR). Остальные человеко-ориентированные документы — русский. `README.ru.md` — русский перевод.

### D7. Init-project и наследники (шов B)

- `manifest.psd1`: в Meta добавляются `CHANGELOG.md`, `VERSION`, `LICENSE`, `.github/`, `README.ru.md`, `CONTRIBUTING.md`, `SECURITY.md`, `docs/releasing.md`, `.agents/skills/release/`. `THIRD_PARTY_NOTICES.md` добавляется в Payload.
- Скилл `release` помечается в Реестре как «только Шаблон» (отдельная секция Реестра). `-Mode New` / `Adopt` / `Update` не переносят папку и удаляют/не добавляют его строку в Реестр Проекта, чтобы `Test-Template.ps1` в Проекте оставался зелёным.
- Запись версии: `vX.Y.Z (<sha>)`, где `X.Y.Z` читается из `VERSION` Шаблона **до** очистки Meta; при отсутствии `VERSION` — прежний формат «дата + sha».
- `-Mode Update`: выводит `Current: <old>`, `Target: <new>`, предупреждение при росте MAJOR и выдержку `CHANGELOG.md` Шаблона для версий `(current, target]`; для старого формата — все секции до target. После `-Apply` пишет новый формат.

### D8. Test-Template (шов C)

Новые проверки, если файлы существуют (в Проекте их нет — проверки пропускаются):
- `VERSION` — валидный SemVer;
- верхняя секция `CHANGELOG.md` совпадает с `VERSION`;
- скилл `release` присутствует в секции «только Шаблон» Реестра.

### D9. GitHub

- `.github/workflows/ci.yml`: `pull_request` + `push` в `main`; матрица `windows-latest`, `ubuntu-latest`; шаги: checkout (SHA-pinned), установка Pester 5, `Test-Template.ps1`, Pester. `permissions: contents: read`.
- Job проверки заголовка PR (в `ci.yml` или `pr-title.yml`): regex Conventional Commits на `github.event.pull_request.title` средствами pwsh, без сторонних actions. Триггеры `opened`, `edited`, `synchronize`.
- `.github/workflows/release.yml`: `push` тегов `v*`; checkout → `Invoke-Release.ps1 -Notes $tag` → `gh release create` с телом и названием; `permissions: contents: write`; pre-release-флаг, если в теге есть `-rc`.
- `.github/dependabot.yml`: ecosystem `github-actions`, еженедельно.
- `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml`, `config.yml` (ссылка на Security).
- Настройки репозитория (руками, по чек-листу в `docs/releasing.md`): private; Template repository; merge — только squash, заголовок squash = заголовок PR; ruleset на `main` — запрет force-push и удаления, обязательные проверки CI для PR, **bypass для владельца** (иначе `/release` не сможет пушить релизный коммит в `main`); Private Vulnerability Reporting; Dependabot alerts.

### D10. Публичные документы

- `README.md` (EN): что это, поддерживаемые harness, быстрый старт, режимы `Initialize-Project`, обзор Цикла разработки, версии и обновление, ссылки на CONTRIBUTING/SECURITY/LICENSE/README.ru.
- `README.ru.md`: перевод текущего README, синхронизированный с английским.
- `CONTRIBUTING.md`: Conventional Commits, правило squash, требования (Test-Template, Pester, Registry + Sync-ClaudeSkills), язык.
- `SECURITY.md`: Private Vulnerability Reporting, поддерживаемые версии (последний MAJOR).
- `THIRD_PARTY_NOTICES.md`: Matt Pocock skills, MIT, текст лицензии, список скиллов с источником `matt`/`matt+правки` (из Реестра).
- `LICENSE`: MIT, `Copyright (c) 2026 Sergey Bizikin`.
- `docs/releasing.md`: правила bump (D2), процесс `/release`, восстановление после ошибок, чек-лист настройки GitHub, чек-лист private → public.
- `.gitignore`: уже содержит `.scratch/` и `.claude/skills/`; план `/release` живёт в `.scratch/release/` — отдельных записей не нужно. Проверить отсутствие других локальных артефактов.

### D11. Переименование проекта

Отдельный тикет, блокирует первый push: замена `NEW-PROJECT-SETUP` в заголовках `README.md` / `README.ru.md` / `.agents/CONTEXT.md`, `template-source`; инструкция по переименованию папки (закрыть IDE, переименовать, дождаться синхронизации Яндекс.Диска, открыть заново, продолжить по `.scratch/`). Handoff-документы не меняются (история).

---

## Testing Decisions

- Тестируем **внешнее поведение через швы**, не внутренние функции: вызов скрипта с параметрами → состояние git-репозитория, файлов, код выхода, вывод.
- **Шов A — `Invoke-Release.ps1`** (новый `tests/Invoke-Release.Tests.ps1`). Фикстура: временный репозиторий с Conventional-коммитами + локальный bare-репозиторий как `origin`. Prior art: фикстуры git-репозиториев в `Describe 'Initialize-Project.ps1 -Mode Update'`. Предусловие P3 (тесты) в тестах подменяется параметром/переменной, чтобы не запускать Pester рекурсивно.
- **Шов B — `Initialize-Project.ps1`** (расширение `tests/Initialize-Project.Tests.ps1`): новые Meta/Payload, формат версии, Update со старым и новым форматом, выдержка CHANGELOG, исключение скилла `release`. Существующие ожидания формата `\d{4}-\d{2}-\d{2}` обновляются.
- **Шов C — `Test-Template.ps1`**: прогон на текущем репозитории (exit 0) + ручная проверка нарушения на копии; отдельных Pester-тестов не требуется, если их нет сейчас.
- Без автотестов: YAML workflows, шаблоны, документы — проверяются живым прогоном на GitHub (тестовый PR, первый Релиз) и ревью.

---

## Acceptance Criteria

1. `VERSION` = `1.0.0`; `CHANGELOG.md` содержит секцию `[1.0.0]`; `Test-Template.ps1` → exit 0.
2. `-Plan` на репозитории с `feat` после последнего тега предлагает MINOR; с `fix` — PATCH; с `feat!` или `BREAKING CHANGE:` — MAJOR; с удалённой папкой скилла — флаг MAJOR-кандидата.
3. `-Plan` не меняет ни одного отслеживаемого файла и не создаёт коммитов/тегов.
4. Не-Conventional коммит попадает в «Other» и в список предупреждений плана.
5. `-Plan`/`-Apply` отказывают (exit ≠ 0, понятное сообщение) при: грязном дереве; ветке ≠ `main`; отсутствии коммитов после тега; существующем теге целевой версии; падении проверок.
6. `-Apply` создаёт ровно один коммит `chore(release): vX.Y.Z`, меняющий только `VERSION`, `CHANGELOG.md`, `.agents/SKILLS.md`, и аннотированный тег `vX.Y.Z` с названием Релиза.
7. `-Apply` пушит коммит и тег атомарно в bare-`origin`; с пустым `origin` первый Релиз проходит.
8. Если `origin/main` впереди локального `main`, `-Apply` отказывает до push; локальный коммит/тег не создаются (проверка до коммита) или сохраняются с понятным статусом.
9. При ошибке push локальные коммит и тег остаются; `-Apply -PushOnly` повторяет push.
10. `-Undo` удаляет незапушенные тег и релизный коммит; при теге на `origin` — отказ; без релизного коммита в HEAD — отказ.
11. В скрипте и скилле нет `--force` / `--force-with-lease`.
12. `-Notes v1.0.0` печатает тело секции `[1.0.0]`; при несовпадении с `VERSION` или отсутствии секции — exit ≠ 0.
13. Парсер принимает `1.1.0-rc.1` и упорядочивает его ниже `1.1.0`.
14. `-Mode New` удаляет `CHANGELOG.md`, `VERSION`, `LICENSE`, `.github/`, `README.ru.md`, `CONTRIBUTING.md`, `SECURITY.md`, `docs/releasing.md`, `.agents/skills/release/` и строку скилла из Реестра; оставляет `THIRD_PARTY_NOTICES.md`; пишет `template-version: v1.0.0 (<sha>)`; `Test-Template.ps1` в Проекте → exit 0.
15. `-Mode Adopt`/`Update` не переносят скилл `release` и Meta-файлы релизов; переносят `THIRD_PARTY_NOTICES.md`.
16. `-Mode Update` для Проекта с `vA (sha)` выводит текущую и целевую версии и секции CHANGELOG `(A, target]`; при росте MAJOR — предупреждение; для старого формата — все секции до target; после `-Apply` формат новый.
17. Все Pester-тесты зелёные на Windows и Linux (CI).
18. CI на PR падает при заголовке не по Conventional Commits и проходит при корректном.
19. Пуш тега `vX.Y.Z` создаёт GitHub Release `vX.Y.Z — <title>` с телом из CHANGELOG; при несовпадении — workflow падает, Release не создаётся.
20. Все сторонние actions закреплены по SHA; `permissions` заданы явно в каждом workflow.
21. В отслеживаемых файлах нет `YandexDisk` и абсолютных локальных путей; `template-source` — URL GitHub.
22. Есть `LICENSE` (MIT, Sergey Bizikin), `THIRD_PARTY_NOTICES.md`, `CONTRIBUTING.md`, `SECURITY.md`, шаблоны PR/issue, `README.md` (EN), `README.ru.md`, `docs/releasing.md`; публичные файлы — на английском.
23. `AGENTS.md` содержит исключение для push в `/release` и список англоязычных файлов; размер < 24 KB.
24. Скилл `release` в Реестре, зеркало обновлено `Sync-ClaudeSkills.ps1`.
25. `origin` = `cannoneer85-svg/<project-name>`; проверено, что push проходит без интерактивного запроса.

---

## Out of Scope

- Выбор названия проекта (решает пользователь; здесь — только тикет переименования).
- Предрелизы как процесс (`/release -Pre rc`) — только поддержка формата парсером.
- Code of Conduct.
- GitLab-зеркало и публикация вне GitHub.
- Автоскачивание Шаблона в `-Mode Update` (`-FromGitHub`), дополнительные артефакты к Release.
- Перевод внутренних документов (спеки, ADR, handoff, глоссарий) на английский.
- `/release` для Проектов (релизы самих Проектов).
- Переписывание git-истории; release-please / semantic-release.

## Further Notes

- Порядок внедрения: документы и LICENSE → версия и Init → релизный скрипт → CI/GitHub → переименование → `git remote add` + настройка GitHub → первый Релиз `v1.0.0` через `/release` (он же первый push) → проверка Action → чек-лист private → public.
- Первый Релиз пишет секцию `[1.0.0]` вручную (через стоп-гейт), а не из коммитов: прежняя история — предрелизная.
- Ruleset `main` обязан разрешать bypass владельцу, иначе D3 конфликтует с защитой ветки.
