# StrataHarness

[English](README.md) | [Русский](README.ru.md)

Готовый к использованию репозиторий-шаблон (Template Repository) для организации профессиональной разработки программного обеспечения с автономными AI-агентами. Содержит структурированный 6-этапный цикл разработки, явные стоп-гейты, протоколы управления контекстом и исчерпывающую библиотеку специализированных скиллов (skills).

Поддерживает совместную работу в нескольких AI-окружениях:
- **Google Antigravity** (нативная поддержка правил и скиллов)
- **Claude Code** (автоматическое зеркалирование скиллов в `.claude/skills/`, правила через `CLAUDE.md`)
- **OpenAI Codex / Codex CLI** (правила через компактный `AGENTS.md`)
- **Cursor** (правила через `AGENTS.md`)

---

## Требования

### Для работы с Проектом
- **git** (версия ≥ 2.30)
- **PowerShell 7+** (`pwsh`) — используется для запуска автоматизации, скриптов инициализации, обновления и валидации на Windows, macOS и Linux.

### Только для разработки Шаблона
- **Pester 5+** — фреймворк тестирования PowerShell (`Install-Module Pester -MinimumVersion 5.0.0`). Необходим только разработчикам шаблона для прогона тестов в `tests/`. Конечным проектам не требуется.

---

## Создание нового Проекта

1. **Создайте репозиторий из шаблона:**
   - Нажмите **«Use this template»** в интерфейсе GitHub или клонируйте репозиторий по определённому тегу релиза:
     ```powershell
     git clone --branch v1.0.0 https://github.com/cannoneer85-svg/StrataHarness.git my-project
     cd my-project
     ```
2. **Инициализируйте проект:**
   - В чате с агентом введите команду: `/init-project`
   - Либо запустите скрипт напрямую в терминале:
     ```powershell
     pwsh -NoProfile -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode New -Tracker local
     ```

### Что произойдёт в режиме `New`
- Удалятся метадокументы разработки самого Шаблона и релизные файлы (`tests/`, `docs/dry-run-checklist.md`, спеки и ADR шаблона, `LICENSE`, `CHANGELOG.md`, `VERSION`, `.github/`, `README.ru.md`, `CONTRIBUTING.md`, `SECURITY.md`, `docs/releasing.md` и скилл `release`).
- Сохранится [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
- Документы заменятся чистыми скелетами для нового проекта (`README.md`, [`.agents/CONTEXT.md`](.agents/CONTEXT.md), `CODING_STANDARDS.md`, [`docs/handoff/LATEST.md`](docs/handoff/LATEST.md)).
- В заголовке Реестра скиллов зафиксируются версия шаблона (`vX.Y.Z (<sha>)`) и источник.
- Настроится трекер задач (например, локальный трекер в `.scratch/<feature>/issues/`).

---

## Режимы работы `Initialize-Project.ps1`

Скрипт инициализации ([`.agents/skills/init-project/scripts/Initialize-Project.ps1`](.agents/skills/init-project/scripts/Initialize-Project.ps1)) поддерживает 4 режима:

| Режим | Назначение | Пример команды |
|---|---|---|
| **New** | Создание чистого проекта из шаблона (удаление мета-файлов, разворачивание каркасов). | `pwsh -NoProfile -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode New -Tracker local` |
| **Adopt** | Подключение правил и скиллов к существующему коду без перезаписи файлов пользователя. Выводит отчёт о конфликтах и обновляет `.gitignore`. | `pwsh -NoProfile -File <путь-к-шаблону>/.agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Adopt -RepoRoot . -Tracker local` |
| **Update** | Обновление правил и скиллов в существующем проекте из новой версии Шаблона. Без `-Apply` показывает diff и выдержку CHANGELOG (dry-run); с `-Apply` применяет изменения. | `pwsh -NoProfile -File <путь-к-шаблону>/.agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Update -RepoRoot . -Apply` |
| **SetTracker** | Смена используемого трекера задач (`local`, `github` или `gitlab`). | `pwsh -NoProfile -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Tracker github` |

Все режимы идемпотентны и безопасны для повторного запуска.

---

## Процесс разработки (Workflow Summary)

Поведение агента определяется строгими правилами в [`AGENTS.md`](AGENTS.md) (для Claude Code зеркалируется через [`CLAUDE.md`](CLAUDE.md)).

```mermaid
flowchart TD
    Step0["Шаг 0: Классификация (Type + Category)"] --> SG0{"Стоп-гейт"}
    SG0 -->|"Подтверждено"| Stage1["1. Интервью (grill-with-docs)"]
    Stage1 --> SG1{"Стоп-гейт"}
    SG1 -->|"Minor"| Stage4["4. Реализация (implement / TDD)"]
    SG1 -->|"Feature / Epic"| Stage2["2. Спецификация (to-spec)"]
    Stage2 --> SG2{"Стоп-гейт"}
    SG2 --> Stage3["3. Тикеты (to-tickets)"]
    Stage3 --> SG3{"Стоп-гейт"}
    SG3 --> Stage4
    Stage4 --> SG4{"Стоп-гейт"}
    SG4 --> Stage5["5. Ревью (code-review)"]
    Stage5 --> SG5{"Стоп-гейт"}
    SG5 -->|"Команда пользователя"| Stage6["6. Закрытие (close-task)"]
```

### 1. Шаг 0 — Классификация до начала работы
В первом сообщении агент объявляет **Тип** и **Категорию** с однострочным обоснованием и ждёт подтверждения пользователя:
- **Тип:**
  - `Development` — меняет код, конфигурацию или тесты.
  - `Analysis` — результатом является документ исследования в `docs/analysis/`, код не меняется.
- **Категория (для Development):**
  - `Minor` — 1–2 файла, один модуль, нет новых сущностей и интеграций.
  - `Feature` — одна подсистема, новый экран/эндпоинт/таблица, интеграция с известным API.
  - `Epic` — несколько модулей, смена базовой архитектуры/контрактов, много неизвестных.
  - `Туман (Fog)` — путь к результату не виден; направляется в `wayfinder` для снятия неопределённости.

### 2. Маршруты и квоты интервью
- **Minor:** 1 раунд интервью (2–4 вопроса) → реализация In-Place → ревью → закрытие.
- **Feature:** ≥ 2 раунда интервью (6–8 вопросов) → спецификация в `docs/specs/` → тикеты в `.scratch/<feature>/issues/` с графом зависимостей `TICKETS.md` → реализация → ревью → закрытие.
- **Epic:** ≥ 3 раунда интервью (10–12+ вопросов) → спецификация → тикеты → реализация через **Оркестратор** (отдельные субагенты по очереди с изолированным брифом) → ревью → закрытие.
- **Анализ:** 1 короткий раунд (4 вопроса) → сбор данных → черновик в `docs/analysis/` → согласование → закрытие.

### 3. Стоп-гейты (Stop Gates)
- **Один этап за один ответ:** агент никогда не перескакивает через этапы и ждёт подтверждения перед переходом к следующему шагу.
- **Жёсткий guardrail:** агент ни при каких условиях не коммитит, не очищает `.scratch/` и не завершает задачу без явной текстовой команды пользователя («закрывай задачу», «фиксируй», «делай handoff»). Команда `/release` («выпускай релиз») — единственная, разрешающая агенту push, и только после явного подтверждения на стоп-гейте релиза; force-push запрещён всегда. Все остальные скиллы (включая `/close-task`) никогда не делают push.

### 4. Handoff vs Close-task
- **Handoff ([`/handoff`](.agents/skills/handoff/SKILL.md)):** перенос контекста в новую сессию или фиксация промежуточного состояния. Создаёт документ `docs/handoff/YYYY-MM-DD-<тема>.md`, обновляет `docs/handoff/LATEST.md`, очищает завершённые тикеты. **Не коммитит.**
- **Close-task ([`/close-task`](.agents/skills/close-task/SKILL.md)):** полное закрытие задачи после ревью по команде пользователя. Выполняет предварительные проверки тестов, формирует handoff, полностью очищает `.scratch/<feature>/`, делает локальный коммит. **Никогда не делает `git push`** (публикация обычных задач всегда остаётся за человеком; единственный скилл с push — `/release` после стоп-гейта).

### 5. Бюджет контекста (Smart zone)
- Рабочая зона глубокого контекста составляет **≈120k токенов**.
- Перед началом написания кода в `/implement` агент оценивает объём задачи по графу тикетов и выбирает стратегию: **In-Place** (в текущем контексте), **Sequential Subagents** (последовательные субагенты с брифом) или **Multi-Session** (разбиение на этапы с handoff между ними).

---

## Версионирование и обновление Шаблона

Шаблон следует [Семантическому версионированию (SemVer)](https://semver.org/):
- Источник истины о версии — файл [`VERSION`](VERSION) (`X.Y.Z`) и аннотированные git-теги (`vX.Y.Z`).
- История изменений ведётся в [`CHANGELOG.md`](CHANGELOG.md).

### Обновление проекта из Шаблона
Чтобы обновить существующий проект улучшениями, исправлениями багов или новыми скиллами из Шаблона:

1. Склонируйте или скачайте целевой тег релиза Шаблона:
   ```powershell
   git clone --branch v1.1.0 https://github.com/cannoneer85-svg/StrataHarness.git ../template-release
   ```
2. Проверьте изменения в режиме предварительного просмотра (dry-run):
   ```powershell
   pwsh -NoProfile -File ../template-release/.agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Update -RepoRoot .
   ```
   Скрипт проверит сохранённую `template-version`, выведет целевую версию, покажет выдержку из CHANGELOG между ними и предупредит о ломающих изменениях (MAJOR), если они есть.
3. Примените обновление:
   ```powershell
   pwsh -NoProfile -File ../template-release/.agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Update -RepoRoot . -Apply
   ```

---

## Навигация и документация

- **Маршрутизатор скиллов:** [`/ask`](.agents/skills/ask/SKILL.md) — интерактивный помощник по выбору подходящего скилла.
- **Реестр скиллов:** [`.agents/SKILLS.md`](.agents/SKILLS.md) — полный каталог всех зарегистрированных скиллов с метаданными.
- **Глоссарий понятий:** [`.agents/CONTEXT.md`](.agents/CONTEXT.md) — единые термины процесса и проекта.
- **Архитектурные решения (ADR):** [`docs/adr/`](docs/adr/) — журнал принятых архитектурных решений.
- **Автоматизация релизов:** [`docs/releasing.md`](docs/releasing.md) — процесс релиза, правила bump и настройка GitHub.
- **Руководство контрибьютора:** [`CONTRIBUTING.md`](CONTRIBUTING.md) — правила участия, Conventional Commits и чек-лист PR.
- **Политика безопасности:** [`SECURITY.md`](SECURITY.md) — отчёт об уязвимостях и поддерживаемые версии.
- **Лицензия:** [`LICENSE`](LICENSE) — лицензия MIT.
- **Уведомления стороннего кода:** [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — авторство и лицензии адаптированных скиллов.
- **Англоязычная документация:** [`README.md`](README.md) — основная документация на английском языке.
