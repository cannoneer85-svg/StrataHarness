# Реестр скиллов

Каталог всех скиллов Шаблона из `.agents/skills/`. Категории задаются здесь, а не папками (см. ADR 0002). При добавлении, удалении или переименовании скилла Реестр обновляется в том же изменении. Согласованность проверяет `.agents/scripts/Test-Template.ps1`.

- **template-version:** `v0.0.0`
- **template-source:** `https://github.com/cannoneer85-svg/StrataHarness`

**Колонки.** Запуск: `ручной` — модель не вызывает скилл сама (`disable-model-invocation: true` в `SKILL.md` и `allow_implicit_invocation: false` в `agents/openai.yaml`), только слэш-командой или чтением по пути; `авто` — модель может выбрать скилл сама. Источник: `matt` — скилл Matt Pocock без изменений, `matt+правки` — скилл Matt с нашими правками (см. ADR 0003), `свой` — написан для Шаблона. Статус: `active` или `in-progress`.

## Процесс разработки

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [grill-with-docs](skills/grill-with-docs/SKILL.md) | Интервью по плану задачи с фиксацией терминов в глоссарии и решений в ADR | ручной | matt+правки | active |
| [grill-me](skills/grill-me/SKILL.md) | Жёсткое интервью, чтобы заострить план или дизайн, без записи документов | авто | matt | active |
| [grilling](skills/grilling/SKILL.md) | Стресс-тест идеи или решения вопросами; формат вопросов для других интервью | авто | matt | active |
| [wayfinder](skills/wayfinder/SKILL.md) | Планирование очень большой работы (больше одной сессии) как карты тикетов-решений | ручной | matt+правки | active |
| [to-spec](skills/to-spec/SKILL.md) | Свести обсуждение в спецификацию без нового интервью | ручной | matt+правки | active |
| [to-tickets](skills/to-tickets/SKILL.md) | Разбить спеку или план на тикеты-трассеры с зависимостями `Blocked by` | ручной | matt+правки | active |
| [implement](skills/implement/SKILL.md) | Реализовать работу по спеке или тикетам | ручной | matt+правки | active |
| [code-review](skills/code-review/SKILL.md) | Ревью изменений от фиксированной точки по двум осям: Standards и Spec | авто | matt+правки | active |
| [handoff](skills/handoff/SKILL.md) | Передать контекст новой сессии: документ в `docs/handoff/`, `LATEST.md`, очистка завершённого в `.scratch`; без коммита | ручной | matt+правки | active |
| [close-task](skills/close-task/SKILL.md) | Закрыть задачу: предпроверка, шаги handoff и один conventional-коммит, без push | ручной | свой | active |
| [claude-handoff](skills/claude-handoff/SKILL.md) | Передать разговор свежему фоновому агенту, который сразу продолжит работу | авто | matt | active |
| [triage](skills/triage/SKILL.md) | Провести issues и внешние PR через роли триажа и подготовить брифы для агента | авто | matt+правки | active |
| [to-questionnaire](skills/to-questionnaire/SKILL.md) | Превратить решение, на которое нет полного ответа, в опросник для другого человека | авто | matt | active |

## Анализ и исследование

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [analyze](skills/analyze/SKILL.md) | Задача анализа (не код): короткое интервью, сбор фактов, документ-вывод в `docs/analysis/`; два стоп-гейта | авто | свой | active |
| [research](skills/research/SKILL.md) | Исследовать вопрос по первичным источникам и сохранить выводы в Markdown в репозитории | авто | matt | active |
| [prototype](skills/prototype/SKILL.md) | Одноразовый прототип, чтобы проверить модель состояний, логику или вид UI | авто | matt | active |

## Качество и отладка

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [tdd](skills/tdd/SKILL.md) | Разработка через тесты (red-green-refactor), интеграционные тесты | авто | matt | active |
| [diagnosing-bugs](skills/diagnosing-bugs/SKILL.md) | Цикл диагностики сложных багов и регрессий производительности | авто | matt | active |
| [migrate-to-shoehorn](skills/migrate-to-shoehorn/SKILL.md) | Перевести тесты с утверждений типа `as` на `@total-typescript/shoehorn` | авто | matt | active |

## Домен и дизайн

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [domain-modeling](skills/domain-modeling/SKILL.md) | Уточнить терминологию проекта, вести глоссарий `CONTEXT.md` и ADR | авто | matt | active |
| [codebase-design](skills/codebase-design/SKILL.md) | Спроектировать глубокий модуль: интерфейс, швы, тестируемость | авто | matt | active |
| [improve-codebase-architecture](skills/improve-codebase-architecture/SKILL.md) | Найти в коде возможности углубить модули, HTML-отчёт и разбор выбранной | авто | matt | active |
| [setup-ts-deep-modules](skills/setup-ts-deep-modules/SKILL.md) | Настроить dependency-cruiser в TypeScript-репозитории, чтобы пакеты были глубокими модулями | авто | matt | active |

## Письмо

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [writing-fragments](skills/writing-fragments/SKILL.md) | Письмо, разведка: набрать сырые фрагменты без структуры | авто | matt | active |
| [writing-beats](skills/writing-beats/SKILL.md) | Письмо: собрать материал в последовательность смысловых шагов (beats) | авто | matt | active |
| [writing-shape](skills/writing-shape/SKILL.md) | Письмо: оформить материал в статью абзац за абзацем | авто | matt | active |

## Обучение и продуктивность

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [teach](skills/teach/SKILL.md) | Научить пользователя новому навыку или понятию в этом рабочем пространстве | авто | matt | active |
| [loop-me](skills/loop-me/SKILL.md) | Интервью о спецификации рабочих процессов, которые пользователь хочет построить | авто | matt | active |
| [wait-what](skills/wait-what/SKILL.md) | Последний ответ непонятен — переформулировать его заново | авто | matt | active |
| [scaffold-exercises](skills/scaffold-exercises/SKILL.md) | Создать структуру упражнений курса: разделы, задачи, решения, пояснения | авто | matt | active |

## Инфраструктура и git

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [resolving-merge-conflicts](skills/resolving-merge-conflicts/SKILL.md) | Разрешить незавершённый merge или rebase с конфликтами | авто | matt | active |
| [git-guardrails-claude-code](skills/git-guardrails-claude-code/SKILL.md) | Хуки Claude Code, блокирующие опасные git-команды (push, reset --hard и др.) | авто | matt | active |
| [setup-pre-commit](skills/setup-pre-commit/SKILL.md) | Настроить pre-commit хуки Husky: lint-staged, проверка типов, тесты | авто | matt | active |
| [wizard](skills/wizard/SKILL.md) | Интерактивный bash-мастер для шагов, которые может сделать только человек | авто | matt | active |

## Мета (Шаблон)

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [ask](skills/ask/SKILL.md) | Спросить, какой скилл или флоу подходит к ситуации (роутер по скиллам) | авто | свой | active |
| [init-project](skills/init-project/SKILL.md) | Инициализация и обновление Проекта из Шаблона: Новый / Добавить / Обновить, настройка трекера | ручной | свой | active |
| [writing-for-agents](skills/writing-for-agents/SKILL.md) | Писать документы для агентов: скиллы, `AGENTS.md`, `CLAUDE.md` | авто | matt | active |

## Только Шаблон

| Скилл | Когда использовать | Запуск | Источник | Статус |
|---|---|---|---|---|
| [release](skills/release/SKILL.md) | Выпуск новой версии Шаблона: план SemVer, черновик заметок, релизный коммит, тег и push | ручной | свой | active |
