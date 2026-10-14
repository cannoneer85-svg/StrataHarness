# Аудит обновлений mattpocock/skills (v1.3.0 – v1.3.1 и main) относительно Шаблона StrataHarness

- **Дата:** 2026-10-14
- **Аудитория:** мейнтейнер Шаблона (знаком с архитектурой `.agents/`, Реестром скиллов и Циклом разработки)
- **Статус:** утверждён

## Вопрос

Какие изменения и новые скиллы вышли в репозитории `mattpocock/skills` после коммита, взятого нами за основу Шаблона, и что из этого стоит перенести в наш **Реестр скиллов** и шаблоны трекеров, а где наша реализация уже ушла вперёд под наш **Цикл разработки**? Результат служит основанием для решения — планировать ли задачу разработки на бэкпорт/адаптацию изменений из апстрима.

## Вывод

1. **Точка отсчёта установлена точно:** наш Шаблон был ответвлён от `mattpocock/skills` на коммите `9c9f36c` от `2026-08-17` (сразу после релиза `v1.2.3`, включает PR `#878`–`#891`) — на этом коммите 31 из 35 исходных скиллов совпадают с нашим базовым коммитом `821c2a7` побайтово [1, 2]. С тех пор в апстриме вышли релизы **`v1.3.0`**, **`v1.3.1`** и ещё **16 невыпущенных changeset-правок** в ветке `main` (до коммита `49dd158` от `2026-10-09`) [1, 3, 4].
2. **Ядро процесса у нас реализовано значительно глубже и надёжнее, чем в апстриме.** Наши адаптированные скиллы (`grill-with-docs`, `to-spec`, `to-tickets`, `implement`, `code-review`, `handoff`, `close-task`, `init-project`, `ask`, `analyze`, `minimal-diff`) превосходят апстрим (включая новый апстримный `implement-spec`) по управляемости контекстом, стоп-гейтам, экономии токенов на тестах, работе с артефактами в репозитории и защите от потери состояния [5, 6].
3. **Из 4 новых скиллов апстрима стоит взять один обязательно (с адаптацией) и один опционально:**
   - **`retro`** (`engineering/retro`) — **взять с адаптацией**: компактная ретроспектива сессии для улучшения *окружения агента* (с важным правилом: механические нарушения превращать в детерминированные проверки линтера/CI/тестов, а `CODING_STANDARDS.md` оставлять только для judgement calls) [7].
   - **`pr`** (`engineering/pr`) — **взять опционально (с адаптацией)**: справочник структуры описания PR (минимальная схема из `show-me`, доказательство `Before/After` и оценка риска `One-way/Two-way Door` + `Blast Radius`) [8].
   - **`implement-spec`** и **`chief-of-staff`** — **пропустить**: первый полностью перекрыт и превзойдён нашим Оркестратором в [`implement`](../../.agents/skills/implement/SKILL.md) (без хрупких параллельных worktree и merger-субагентов) [9], второй — сырой 45-строчный черновик из `in-progress/`, идеи которого уже закрыты нашими `minimal-diff` и `retro` [10].
4. **В существующих общих скиллах и шаблонах трекеров есть 8 точечных багфиксов и улучшений, которые однозначно стоит перенести** (исправление падающих команд `gh pr list` и `glab issue list -O json` в шаблонах трекеров, 10 фиксов bash-шаблона `wizard/template.sh`, защита от шелл-интерполяции в `claude-handoff`, привязка якоря рабочей папки в `teach`, проверка мутации через `diff` в `diagnosing-bugs`, 4 уточнения в `wayfinder`, пояснение компромиссов швов в `tdd` и микро-улучшения в `grilling`) [4, 11–18].
5. **Глобальные конвенции апстрима `v1.3.0` переносить не нужно:** переименование `CONTEXT.md` → `GLOSSARY.md` сломает обратную совместимость `Initialize-Project.ps1 -Mode Update` и противоречит тому, что наш [`.agents/CONTEXT.md`](../../.agents/CONTEXT.md) хранит также стек технологий; удаление `resolving-merge-conflicts` и тотальная зачистка длинных тире (`—`) практической пользы для Шаблона не несут [3, 6].

**Рекомендация:** запланировать одну задачу категории **Feature** (1 сессия) на точечный перенос 8 багфиксов в существующие скиллы/шаблоны трекеров и адаптацию скилла `retro` (плюс опционально `pr`).

## Обоснование

### 1. Хронология изменений в `mattpocock/skills` после нашей базовой точки

Сверка git-истории нашего репозитория (`821c2a7` от `2026-10-03`) с историей `mattpocock/skills` показывает, что слепок скиллов был взят на коммите `9c9f36c` (`2026-08-17`, сразу после `v1.2.3`) [1, 2]. Всё, что вышло в `v1.1.0`–`v1.2.3` (включая `research`, `wait-what`, `to-questionnaire`, `wizard`, `writing-for-agents`, Fowler smell baseline в `code-review`, переход `to-prd` → `to-spec`), у нас **уже есть** [2, 3].

Дельта апстрима с коммита `9c9f36c` по текущий `HEAD` (`49dd158` от `2026-10-09`) делится на три волны [1, 3, 4]:

| Волна в апстриме | Ключевые изменения |
|---|---|
| **`v1.3.0`** (`984a2c0`, 2026-09-29 / релиз 2026-10-04) | 1. Выпущены в `engineering/` три новых скилла: `implement-spec`, `pr`, `retro` (`#1120`).<br>2. Удалён скилл `resolving-merge-conflicts` (`daa01d8`).<br>3. Конвенция `CONTEXT.md` / `CONTEXT-MAP.md` переименована в `GLOSSARY.md` / `GLOSSARY-MAP.md` в 11 скиллах (`#876`).<br>4. Из всех текстов репозитория удалены длинные тире `—` (`#905`) и взяты в кавычки `description` в YAML frontmatter с двоеточиями (`#911`).<br>5. В `grilling` вопросы внутри раунда разделены линией `---` (`#917`); в `wait-what` добавлена поддержка `CONTEXT-MAP.md` / `GLOSSARY-MAP.md` (`#904`). |
| **`v1.3.1`** (`24fe0ef`, 2026-10-04) | В `ask-matt` после `diagnosing-bugs` убрана устаревшая ссылка на post-mortem и добавлена маршрутизация в `/retro` и `/improve-codebase-architecture` (`#1121`). |
| **Unreleased `main`** (`24fe0ef..49dd158`, 2026-10-05 — 2026-10-09) | 1. Добавлен экспериментальный скилл `in-progress/chief-of-staff` (`e47c149`).<br>2. Добавлены `SCOPE.md` и база отказов `.out-of-scope/*.md` (`#1179`, `#1190`, `#1240`).<br>3. **16 точечных багфиксов** (в `.changeset/*.md`) по жалобам пользователей: `wizard` (`#1198`, `#1237`), `claude-handoff` (`#1185`), `handoff` (`#1184`), `wayfinder` (`#1181`), `to-tickets` (`#1188`), `setup-matt-pocock-skills` и шаблоны GitHub/GitLab трекеров (`#1187`, `#1197`), `diagnosing-bugs` (`#1209`), `code-review` (`#1208`), `implement` (`#1189`, `#1196`), `tdd` (`#1192`), `teach` (`#1183`), `grilling` (`#1193`), `ask-matt` (`#1194`). |

---

### 2. Разбор новых скиллов апстрима (отсутствующих в StrataHarness)

| Новый скилл в `mattpocock/skills` | Папка / Статус у Мэтта | Суть скилла | Сравнение с StrataHarness и вердикт |
|---|---|---|---|
| **`retro`** [7] | `engineering/` (active, выпуск в `v1.3.0`) | Ретроспектива сессии после реализации или отладки бага. Ищет кандидатов на улучшение **окружения агента** по 7 категориям: *Navigation*, *Automated checks*, *Coding standards*, *Global AGENTS.md*, *Tool economy*, *No-ops*, *Information access*. Вводит жёсткое правило: механические нарушения (синтаксис, импорты, запрещённые API) превращать в детерминированные проверки (линтер, pre-commit, CI), а `CODING_STANDARDS.md` беречь только для *judgement calls*. Отсутствие pre-commit/CI в репозитории само по себе фиксируется как проблема. | **ВЗЯТЬ С АДАПТАЦИЕЙ.** У нас нет проектного скилла для рефлексии по итогам задачи (только системная подсказка `/learn`). Принцип «детерминированный чек вместо расплывчатого правила в стандартах» идеально ложится на нашу практику (как мы делали Pester-тесты в `tests/`). При адаптации: заменить `GLOSSARY.md` на `.agents/CONTEXT.md`, учесть роль нашего `AGENTS.md` (роутер + инварианты, не трогать ядро маршрутизации без веской причины) и прописать его в [`ask`](../../.agents/skills/ask/SKILL.md). |
| **`pr`** [8] | `engineering/` (active, выпуск в `v1.3.0`) | Model-invoked шаблон оформления тела Pull Request (адаптирует `show-me` от Dex Horthy):<br>1. `## Summary` — минимальная визуализация сути (псевдокод, call tree, shallow file tree, Mermaid или точечный diff-скетч).<br>2. `## Evidence` — пара `Before` / `After` (скриншот или вывод падающего/проходящего теста).<br>3. `## Merge Danger` — оценка обратимости (`Door: one-way or two-way`) и `Blast Radius`. | **ВЗЯТЬ ОПЦИОНАЛЬНО (С АДАПТАЦИЕЙ).** Хотя в нашем процессе агент не пушит и не открывает PR сам (кроме `/release`), разработчик часто просит сгенерировать текст PR после `/close-task`. Кроме того, рубрика `One-way / Two-way Door + Blast Radius + Before/After` очень полезна. При адаптации: заменить `GLOSSARY.md` на `.agents/CONTEXT.md` и уточнить, что скилл формирует текст описания PR (не выполняя `git push` или `gh pr create` без явной команды). |
| **`implement-spec`** [9] | `engineering/` (active, выпуск в `v1.3.0`) | Реализация всей спеки за один прогон: создаёт интеграционную ветку, запускает параллельных субагентов-имплементеров в отдельных `git worktree` по фронтиру тикетов, сливает их через отдельного `merger subagent`, открывает draft PR и в конце вызывает `code-review`. | **ПРОПУСТИТЬ (У НАС УЖЕ ЛУЧШЕ).** Наш [`implement`](../../.agents/skills/implement/SKILL.md) уже содержит зрелый протокол **Оркестратора** (§4, `Sequential Subagents`) с формализованным `BRIEF.md`, шаблоном отчёта, независимой верификацией Оркестратором, точечным запуском тестов, синхронизацией `TICKETS.md` и работой в одной ветке без `worktree` и без автокоммитов. Подход `implement-spec` с параллельными worktree и merger-субагентами порождает гонки, конфликты слияния и кратный перерасход токенов. |
| **`chief-of-staff`** [10] | `in-progress/` (экспериментальный, 2026-10-05) | Короткий (45 строк) промпт для бесконечной сессии управления фоновыми субагентами и расписаниями (`Schedules`). Призывает думать на двух треках: тактическом (задача) и стратегическом (улучшение окружения: *pit of success*, доступ к логам/БД/браузеру, правило *no workarounds*). | **ПРОПУСТИТЬ.** Сырой черновик, который противоречит нашему структурированному **Циклу разработки** со **Стоп-гейтами**. Полезные принципы из него у нас уже реализованы системно: запрет костылей (*no workarounds*) закреплён в [`minimal-diff`](../../.agents/skills/minimal-diff/SKILL.md) (*Fix at the root cause*), а улучшение окружения гораздо предметнее описано в `retro`. |

---

### 3. Полная сверка всех 39 скиллов нашего Реестра с апстримом

В таблице ниже приведены все скиллы нашего [Реестра скиллов](../../.agents/SKILLS.md), их статус в `mattpocock/skills` (`v1.3.1` + `main`), суть изменений апстрима (за вычетом механической замены `—` и переименования `CONTEXT.md` → `GLOSSARY.md`) и итоговый вердикт.

#### 3.1. Процесс разработки

| Скилл в StrataHarness | Источник в Реестре | Что изменилось в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`grill-with-docs`](../../.agents/skills/grill-with-docs/SKILL.md) | `matt+правки` | Только механическая замена `CONTEXT.md` → `GLOSSARY.md` и удаление тире. В `.out-of-scope/native-question-tool.md` Мэтт явно отказался от поддержки нативных question tools и раундовых квот [19]. | **У нас уже лучше.** Тематические раунды по категориям (`Outline and happy path`, `Errors and edge cases`, `NFR`), эскалация `Minor → Feature`, стоп-фраза, лог `.scratch/<feature>/OPEN_QUESTIONS.md`, `ADR candidates` и поддержка `ask_question` с фоллбэком на `grilling`. **Ничего менять не нужно.** |
| [`grill-me`](../../.agents/skills/grill-me/SKILL.md) | `matt` | Без смысловых изменений (только пунктуация). | **Паритет.** Оставить как есть. |
| [`grilling`](../../.agents/skills/grilling/SKILL.md) | `matt` | 1. Между вопросами `Q1` и `Q2` в шаблоне раунда добавлен разделитель `---` (`#917`) [3].<br>2. Добавлено правило: *«Word each question so "yes" accepts your recommended answer»* (`#1193` / `#706`) [15]. | **Взять 2 микро-улучшения.** Оба изменения повышают читаемость вопросов (в текстовом режиме) и удобство ответа «да» на рекомендацию. |
| [`wayfinder`](../../.agents/skills/wayfinder/SKILL.md) | `matt+правки` | 4 исправления по багрепортам (`#1181` / `8295b8e`) [17]:<br>1. Не вешать триаж-лейблы (`ready-for-agent`) на карту и тикеты-решения (только `wayfinder:*`).<br>2. Писать кросс-ссылки `#<n>` только во втором проходе с реальными ID (чтобы плейсхолдеры не линковались на чужие issues).<br>3. Не открывать PR из веток `research/<name>`.<br>4. В `Work through the map` шаг 3: определять тип тикета по его лейблу `wayfinder:<type>`, так как в теле тип не указан. | **Взять 3 из 4 уточнений (п. 1, 2, 4) и адаптировать п. 3.** У нас в `wayfinder` уже встроен расчёт под `Smart zone (≈120k)` и `/init-project`, но эти 4 точечные страховки от типичных галлюцинаций агента при работе с трекером очень полезны (п. 3 адаптировать без `git push`, так как пуш агенту запрещён). |
| [`to-spec`](../../.agents/skills/to-spec/SKILL.md) | `matt+правки` | Без смысловых изменений (только кавычки в YAML frontmatter и `GLOSSARY.md`). | **У нас уже лучше.** Интеграция с `OPEN_QUESTIONS.md`, фильтр **`minimal-diff`**, секция `Acceptance Criteria`, выпуск ADR из кандидатов и стоп-гейт. **Ничего менять не нужно.** |
| [`to-tickets`](../../.agents/skills/to-tickets/SKILL.md) | `matt+правки` | В `#1188` (`cffab50`, `9e2abf8`) [13]:<br>1. Для реального трекера (GitHub/GitLab) явно предписано делать каждый тикет sub-issue родительского issue-спеки (`If the source was an existing issue, make each ticket its sub-issue`).<br>2. В шаблоне `<issue-template>` для секции `## Blocked by` добавлено: *«Omit this section when blockers were set as native edges»* (чтобы не дублировать блокеры дважды, `#262`). | **У нас уже лучше (по процессу и `TICKETS.md`), но взять 2 строчки для реальных трекеров.** Наш `to-tickets` строит визуальную карту `TICKETS.md` с Mermaid-графом и статусами, чего нет у Мэтта. При этом два уточнения из `#1188` для ветки реального трекера (`sub-issue` и отказ от дублирования `## Blocked by` при нативных связях) полезно добавить. |
| [`implement`](../../.agents/skills/implement/SKILL.md) | `matt+правки` | В `#1189` (`04320ee`) `/tdd` и `/code-review` заменены на `Call the Skill tool with...`; в `#1196` (`6d6a5b9`) добавлена строка: *«If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.»* [14] | **У нас уже на порядок лучше; можно взять только 1 фразу про внешний тикет.** Наш `implement` — это 64-строчный протокол с `BASE_COMMIT`, стратегиями исполнения, Оркестратором, `BRIEF.md` и `minimal-diff`. Автовызов `code-review` через Skill tool из апстрима нам **противопоказан** (нарушает стоп-гейт этапа 4). А вот уточнение «если передан ID внешнего тикета, прочитай его из трекера и назови заголовок» можно аккуратно добавить. |
| [`code-review`](../../.agents/skills/code-review/SKILL.md) | `matt+правки` | В `#1208` (`3da8c01`) [12]:<br>1. В шаге 3: искать все файлы стандартов в репо, обязательно включая `CODING_STANDARDS.md` и `CONTRIBUTING.md`.<br>2. В шаге 4: явно вызывать субагентов во фронте (`in the foreground`) и агрегировать их отчёты.<br>3. В шаге 2: ссылаться на «tracker doc» вместо хардкода пути. | **У нас уже лучше.** У нас уже есть 3 оси (включая **Adversary**), проверка **Minimal-Diff Breaches**, работа по рабочему дереву от `BASE_COMMIT` (а не только по коммитам), запрет субагентам гонять тесты и меню закрытия на стоп-гейте. Можно лишь добавить слово `in the foreground (and wait for their reports)` в шаг 4, если нужно исключить фоновый запуск. |
| [`handoff`](../../.agents/skills/handoff/SKILL.md) | `matt+правки` | В `#1184` (`4f4e943`, `#272`) уточнён порядок поиска системной temp-папки (`$TMPDIR`, `/tmp`, `%TEMP%`). | **Пропустить (у нас принципиально лучше).** Мы не пишем handoff в системную мусорку `%TEMP%`: у нас структурированный архив `docs/handoff/YYYY-MM-DD-<feature>.md` + `docs/handoff/LATEST.md` и селективная очистка `.scratch/<feature>/`. |
| [`close-task`](../../.agents/skills/close-task/SKILL.md) | `свой` | В апстриме отсутствует. | **Наше собственное преимущество.** Предпроверка, шаги handoff и единый коммит без push. |
| [`claude-handoff`](../../.agents/skills/claude-handoff/SKILL.md) | `matt` | В `#1185` (`07b7105`, `4ec00d9`, `#562`) исправлен баг шелл-интерполяции: раньше саммари передавалось в двойных кавычках `claude --bg --name "..." "<summary>"`, из-за чего bash исполнял `` `...` `` и `$(...)` и раскрывал `$VAR` внутри текста. Теперь саммари сохраняется во временный файл и передаётся как `claude --bg --name "<descriptive name>" -- "$(cat <summary file>)"` [18]. | **Однозначно взять.** Прямой фикс безопасности и целостности промпта для `claude --bg`. |
| [`triage`](../../.agents/skills/triage/SKILL.md) | `matt+правки` | Только механическая замена `CONTEXT.md` → `GLOSSARY.md` и удаление тире. | **У нас уже адаптировано** (ссылается на `/init-project` и сохраняет `CONTEXT.md`). **Ничего менять не нужно.** |
| [`to-questionnaire`](../../.agents/skills/to-questionnaire/SKILL.md) | `matt` | Без смысловых изменений (только удаление тире и замена `—` на `:` в шаблоне вопросов). | **Паритет.** Оставить как есть. |

#### 3.2. Анализ и исследование

| Скилл в StrataHarness | Источник в Реестре | Что изменилось в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`analyze`](../../.agents/skills/analyze/SKILL.md) | `свой` | В апстриме отсутствует. | **Наше собственное преимущество.** Полноценный флоу для задач анализа с двумя стоп-гейтами и шаблоном в `docs/analysis/`. |
| [`research`](../../.agents/skills/research/SKILL.md) | `matt` | Без смысловых изменений (замена одного тире на двоеточие). | **Паритет.** Оставить как есть. |
| [`prototype`](../../.agents/skills/prototype/SKILL.md) | `matt` | Без смысловых изменений (замена тире в `SKILL.md`, `LOGIC.md`, `UI.md`). | **Паритет.** Оставить как есть. |

#### 3.3. Качество и отладка

| Скилл в StrataHarness | Источник в Реестре | Что изменилось в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`tdd`](../../.agents/skills/tdd/SKILL.md) | `matt` | В `#1192` (`3f59913`, `#607`) при предложении швов (seams) пользователю добавлено требование: *«Give each proposed seam a one-line note on what it catches and what it misses.»* [16] | **Однозначно взять.** Помогает пользователю принимать осознанное решение о выборе шва тестирования (полезно также продублировать в шаг 2 `to-spec`). |
| [`diagnosing-bugs`](../../.agents/skills/diagnosing-bugs/SKILL.md) | `matt` | В `#1209` (`f3fc563`, `#955`) в Phase 5 (Fix, шаг 2 «Watch it fail») добавлена страховка: *«If you forced the red by mutating code or a fixture, `diff` against a pristine copy to prove the mutation landed before you trust it.»* [11] | **Однозначно взять.** Защищает от классической ошибки агента, когда мутация для проверки красного теста молча не применилась, а агент поверил результату. |
| [`minimal-diff`](../../.agents/skills/minimal-diff/SKILL.md) | `свой` | В апстриме отсутствует. | **Наше собственное преимущество.** Лестница из 7 ступеней, запретные зоны и контроль зависимостей. |
| [`migrate-to-shoehorn`](../../.agents/skills/migrate-to-shoehorn/SKILL.md) | `matt` | 0 изменений (побайтово идентичен `HEAD`). | **Паритет.** |

#### 3.4. Домен и дизайн

| Скилл в StrataHarness | Источник в Реестре | Что изменилось в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`domain-modeling`](../../.agents/skills/domain-modeling/SKILL.md) | `matt` | Только переименование `CONTEXT.md` → `GLOSSARY.md` и `CONTEXT-FORMAT.md` → `GLOSSARY-FORMAT.md` (`#876`). | **Пропустить.** Мы сохраняем конвенцию `.agents/CONTEXT.md`. |
| [`codebase-design`](../../.agents/skills/codebase-design/SKILL.md) | `matt` | Только замена `CONTEXT.md` → `GLOSSARY.md` и тире. | **Паритет.** Оставить как есть. |
| [`improve-codebase-architecture`](../../.agents/skills/improve-codebase-architecture/SKILL.md) | `matt` | Только замена `CONTEXT.md` → `GLOSSARY.md` и тире (YAGNI-фильтр по последним 20 коммитам из `#533` у нас уже есть!). | **Паритет.** Оставить как есть. |
| [`setup-ts-deep-modules`](../../.agents/skills/setup-ts-deep-modules/SKILL.md) | `matt` | Только замена тире в комментариях и тексте. | **Паритет.** Оставить как есть. |

#### 3.5. Письмо, Обучение и продуктивность

| Скилл в StrataHarness | Источник в Реестре | Что изменилось в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`writing-fragments`](../../.agents/skills/writing-fragments/SKILL.md), [`writing-beats`](../../.agents/skills/writing-beats/SKILL.md), [`writing-shape`](../../.agents/skills/writing-shape/SKILL.md) | `matt` | Только замена тире и кавычки в YAML `description`. | **Паритет.** (Наш `Test-Template.ps1` не требует кавычек вокруг `: `, если парсер корректен, но при желании кавычки в `description` можно добавить для совместимости со сторонними CLI). |
| [`teach`](../../.agents/skills/teach/SKILL.md) | `matt` | В `#1183` (`ad5400b`, `#377`, `#611`) [16]:<br>1. Явно зафиксировано, что пути рабочей области (`./lessons/` и др.) отсчитываются от директории, в которой запущен `/teach`, а не от папки скилла.<br>2. В квизах добавлено требование менять позицию правильного ответа (`Vary which position holds the correct answer across questions`). | **Однозначно взять оба исправления.** Без первого уточнения агенты при чтении `.agents/skills/teach/SKILL.md` могут создавать `./lessons/` внутри `.agents/skills/teach/`. |
| [`loop-me`](../../.agents/skills/loop-me/SKILL.md) | `matt` | Только замена тире. | **Паритет.** Оставить как есть. |
| [`wait-what`](../../.agents/skills/wait-what/SKILL.md) | `matt` | В `#904` (`d6cd26f`) добавлено уточнение: *(follow `CONTEXT-MAP.md` to the right one if the repo has more than one)* [3]. | **Взять с сохранением имени `CONTEXT.md`.** Полезная деталь для мультиконтекстных монорепозиториев (при выборе multi-context в `/init-project`). |
| [`scaffold-exercises`](../../.agents/skills/scaffold-exercises/SKILL.md) | `matt` | 0 изменений (побайтово идентичен `HEAD`). | **Паритет.** |

#### 3.6. Инфраструктура и git

| Скилл в StrataHarness | Источник в Реестре | Что изменилось в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`resolving-merge-conflicts`](../../.agents/skills/resolving-merge-conflicts/SKILL.md) | `matt` | Удалён из `mattpocock/skills` в `v1.3.0` (`daa01d8`) с формулировкой «больше не нужен, агент справляется сам» [3]. | **Оставить у нас.** Скилл компактный (29 строк), содержит здравую дисциплину (`git diff --diff-filter=U`, запрет угадывать бизнес-логику при конфликте без чтения обоих коммитов), а его удаление потребует правки `THIRD_PARTY_NOTICES.md` и затронет обновление существующих Проектов. |
| [`git-guardrails-claude-code`](../../.agents/skills/git-guardrails-claude-code/SKILL.md) | `matt` | Только замена одного тире. | **Паритет.** |
| [`setup-pre-commit`](../../.agents/skills/setup-pre-commit/SKILL.md) | `matt` | Только замена одного тире. | **Паритет.** |
| [`wizard`](../../.agents/skills/wizard/SKILL.md) | `matt` | Два крупных багфикс-релиза `template.sh` (`#1198` / `868c4cf` и `#1237` / `49dd158`), закрывающие 10 багов bash-скрипта [11]:<br>1. `read -e` (Readline) в `ask` для работы стрелок (`#741`).<br>2. Одинарные кавычки в `write_env` для защиты пробелов, `#`, `$` (`#770`) и декодирование кавычек в `_existing` (`#1220`).<br>3. `printf -v "$key"` в `write_env`, чтобы переменная сразу появлялась в окружении скрипта (`#1041`).<br>4. Запись через временный файл в целевой файл (сохранение симлинков `.env` и прав доступа, `#811`).<br>5. Завершение при `EOF` в `ask` и `ask_secret` вместо бесконечного цикла (`#852`).<br>6. Предупреждение в `open_url`, если нет утилиты открытия браузера (`#774`).<br>7. Фоллбэк `_clear` на ANSI-последовательность, если `tput clear` не сработал (`#1081`).<br>8. Обёртка `run_wizard "$@"; exit` вокруг секции `STAGES`, чтобы правка скрипта во время работы не ломала чтение файла bash-интерпретатором (`#1142`).<br>9. Удалена неиспользуемая переменная `RED` (`#1003`). | **Однозначно взять обновлённый `wizard/template.sh` и `wizard/SKILL.md`.** Это чистые технические багфиксы bash-рантайма, которые напрямую повышают надёжность сгенерированных визардов. |

#### 3.7. Мета и управление Шаблоном

| Скилл в StrataHarness | Источник в Реестре | Аналог и изменения в `mattpocock/skills` (`9c9f36c..49dd158`) | Где лучше и вердикт |
|---|---|---|---|
| [`ask`](../../.agents/skills/ask/SKILL.md) | `свой` | Аналог: `ask-matt`. В апстриме добавлены маршруты в `retro` и `pr` (`#1120`, `#1121`) и правило в начале файла: *«Before stating what a skill does or recommending a step be skipped, read that skill's SKILL.md: the summaries here are for orientation only»* (`#1194` / `#614`) [4]. | **У нас уже лучше под наш процесс**, но **стоит взять правило `#1194`** (прочитать `SKILL.md` перед тем, как утверждать детали работы скилла или предлагать пропустить шаг) и добавить ссылку на `retro` (и `pr`, если примем его). |
| [`init-project`](../../.agents/skills/init-project/SKILL.md) + [`templates/`](../../.agents/skills/init-project/templates/) | `свой` | Аналог: `setup-matt-pocock-skills`. В апстриме вышли важные фиксы CLI-команд в шаблонах трекеров (`#1187`, `#1197`, `#1188`) [13, 14]:<br>1. `issue-tracker-github.md`: замена неработающего `gh pr list --json ... authorAssociation` на `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' ...` (`#468`); чтение issue через `gh issue view <n> --json number,title,body,labels,comments` (`#733`); команда создания sub-issue (`gh issue create --parent` / `gh issue edit --add-sub-issue` / `gh api .../sub_issues`, `#554`).<br>2. `issue-tracker-gitlab.md`: исправление неверного флага `glab issue list -F json` на `-O json` (`#635`) и плейсхолдера `<child-iid>`.<br>3. `triage-labels.md`: точное имя колонки `"Label in our tracker"` (`#801`).<br>4. Создание отсутствующих лейблов в трекере через `gh label create` / `glab label create` при настройке (`#616`). | **Архитектурно `init-project` у нас на голову выше** (4 детерминированных режима `New`/`Adopt`/`Update`/`SetTracker` на PowerShell), но **фиксы CLI-команд в `templates/issue-tracker-github.md`, `issue-tracker-gitlab.md` и `triage-labels.md` нужно обязательно забрать** — сейчас в наших шаблонах лежат те же старые баги с `authorAssociation` и `glab issue list -F json`! |
| [`writing-for-agents`](../../.agents/skills/writing-for-agents/SKILL.md) | `matt` | Только замена `CONTEXT.md` → `GLOSSARY.md` и тире. | **Паритет.** Оставить как есть. |
| [`release`](../../.agents/skills/release/SKILL.md) | `свой` | В апстриме отсутствует (Мэтт использует `@changesets/cli`). | **Наше собственное преимущество** для SemVer-релизов Шаблона. |

---

### 4. Сводный список рекомендуемых заимствований для следующей итерации

Если мы решим провести обновление, в него войдут ровно те элементы, где апстрим нашёл реальные баги эксплуатации или добавил недостающий инструмент:

1. **Багфиксы в существующих скиллах и шаблонах (высокий приоритет, нулевой риск для архитектуры):**
   - [`wizard/template.sh`](../../.agents/skills/wizard/template.sh) и [`wizard/SKILL.md`](../../.agents/skills/wizard/SKILL.md) — перенести 10 фиксов bash-шаблона (`#1198`, `#1237`).
   - [`init-project/templates/issue-tracker-github.md`](../../.agents/skills/init-project/templates/issue-tracker-github.md), [`issue-tracker-gitlab.md`](../../.agents/skills/init-project/templates/issue-tracker-gitlab.md), [`triage-labels.md`](../../.agents/skills/init-project/templates/triage-labels.md) и [`docs/agents/issue-tracker.md`](../../docs/agents/issue-tracker.md) — исправить `gh api .../pulls` вместо `authorAssociation`, `gh issue view --json`, `gh issue create --parent`, `glab issue list -O json`, а в [`init-project/SKILL.md`](../../.agents/skills/init-project/SKILL.md) добавить шаг `gh/glab label create` для триаж-лейблов (`#1187`, `#1188`, `#1197`).
   - [`claude-handoff/SKILL.md`](../../.agents/skills/claude-handoff/SKILL.md) — передавать саммари в `claude --bg` через временный файл `-- "$(cat <summary file>)"` для защиты от шелл-интерполяции (`#1185`).
   - [`teach/SKILL.md`](../../.agents/skills/teach/SKILL.md) — зафиксировать разрешение путей относительно рабочей папки запуска и рандомизацию позиции правильного ответа в квизах (`#1183`).
   - [`diagnosing-bugs/SKILL.md`](../../.agents/skills/diagnosing-bugs/SKILL.md) — добавить проверку `diff` при принудительной мутации кода/фикстуры перед доверием красному тесту в Phase 5 (`#1209`).
   - [`tdd/SKILL.md`](../../.agents/skills/tdd/SKILL.md) (и опционально [`to-spec/SKILL.md`](../../.agents/skills/to-spec/SKILL.md)) — добавить требование указывать в 1 строку для каждого предлагаемого шва, что он ловит и что пропускает (`#1192`).
   - [`grilling/SKILL.md`](../../.agents/skills/grilling/SKILL.md) — добавить разделитель `---` между вопросами в шаблоне раунда (`#917`) и правило формулировать вопрос так, чтобы «да» означало согласие с рекомендацией (`#1193`).
   - [`wayfinder/SKILL.md`](../../.agents/skills/wayfinder/SKILL.md) — перенести уточнения про запрет `ready-for-agent` на тикетах-решениях, кросс-ссылки только с реальными ID во втором проходе, запрет открытия PR из research-веток и чтение типа тикета из лейбла `wayfinder:<type>` (`#1181`).
   - [`to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md), [`implement/SKILL.md`](../../.agents/skills/implement/SKILL.md), [`ask/SKILL.md`](../../.agents/skills/ask/SKILL.md), [`wait-what/SKILL.md`](../../.agents/skills/wait-what/SKILL.md) — точечные однострочные дополнения (`sub-issue` и опускание дублирующего `Blocked by` на реальном трекере в `to-tickets`; чтение и озвучивание заголовка переданного тикета в `implement`; чтение `SKILL.md` перед пропуском шага в `ask`; упоминание `CONTEXT-MAP.md` в `wait-what`).
2. **Новый скилл (средний/высокий приоритет):**
   - Адаптировать **`retro`** (`matt+правки`, запуск `ручной`) в категорию «Качество и отладка» или «Процесс разработки» нашего Реестра, заменив `GLOSSARY.md` на `.agents/CONTEXT.md` и согласовав с правилами `AGENTS.md` и `THIRD_PARTY_NOTICES.md`.
   - Опционально адаптировать **`pr`** (`matt+правки`, запуск `авто`) как справочник формата PR-описания.

## Источники

1. История коммитов и тегов `mattpocock/skills` (`https://github.com/mattpocock/skills`, клон ветки `main` на коммите `49dd158` от `2026-10-09`, проверено `2026-10-14`).
2. Базовый коммит StrataHarness `821c2a7` (`2026-10-03`) и [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).
3. `CHANGELOG.md` репозитория `mattpocock/skills` (релизы `v1.1.0` – `v1.3.1`, проверено `2026-10-14`).
4. Невыпущенные файлы изменений `.changeset/*.md` в `mattpocock/skills` на коммите `49dd158` (16 файлов, проверено `2026-10-14`).
5. Реестр скиллов StrataHarness [`.agents/SKILLS.md`](../../.agents/SKILLS.md) и правила [`AGENTS.md`](../../AGENTS.md).
6. [`docs/adr/0003-edit-upstream-skills-in-place.md`](../adr/0003-edit-upstream-skills-in-place.md) и [`docs/adr/0004-semver-template-version.md`](../adr/0004-semver-template-version.md).
7. Скилл `retro` в `mattpocock/skills`: `skills/engineering/retro/SKILL.md` (коммиты `8fa1886`, `6654f6b`, `0243b6e`, `a7d038f`).
8. Скилл `pr` в `mattpocock/skills`: `skills/engineering/pr/SKILL.md` (коммиты `d75dcf1`, `00cf26e`, `c55ee46`, `a7d038f`).
9. Скилл `implement-spec` в `mattpocock/skills`: `skills/engineering/implement-spec/SKILL.md` (коммиты `84b5ee5`, `153fc1b`, `24f41cc`) и локальный [`implement/SKILL.md`](../../.agents/skills/implement/SKILL.md).
10. Скилл `chief-of-staff` в `mattpocock/skills`: `skills/in-progress/chief-of-staff/SKILL.md` (коммиты `e47c149`, `4588b32`, `2b47ffc`).
11. Изменения в `wizard` (`868c4cf`, `49dd158`) и `diagnosing-bugs` (`f3fc563`) в `mattpocock/skills`.
12. Изменения в `code-review` (`3da8c01`) в `mattpocock/skills` и локальный [`code-review/SKILL.md`](../../.agents/skills/code-review/SKILL.md).
13. Изменения в `to-tickets` (`cffab50`, `9e2abf8`) в `mattpocock/skills` и локальный [`to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md).
14. Изменения в `setup-matt-pocock-skills` (`e0efb6e`, `8e67db2`, `5b7cade`) и `implement` (`e48341a`, `6d6a5b9`) в `mattpocock/skills` и локальный [`init-project/SKILL.md`](../../.agents/skills/init-project/SKILL.md).
15. Изменения в `grilling` (`85f83d3`, `95249b0`) в `mattpocock/skills`.
16. Изменения в `tdd` (`3f59913`) и `teach` (`ad5400b`) в `mattpocock/skills`.
17. Изменения в `wayfinder` (`8295b8e`) в `mattpocock/skills`.
18. Изменения в `claude-handoff` (`07b7105`, `4ec00d9`) и `handoff` (`4f4e943`) в `mattpocock/skills`.
19. Политики `SCOPE.md` и `.out-of-scope/*.md` в `mattpocock/skills` (коммиты `f0588cd`, `4d04daa`, `8267225`).

## Ограничения

- Анализ выполнен по состоянию ветки `main` репозитория `mattpocock/skills` на коммите `49dd158` (`2026-10-09`); открытые и невлитые Pull Requests в апстриме не рассматривались.
- Обновлённый bash-шаблон `wizard/template.sh` из коммита `49dd158` проверялся статическим чтением diff-патча и описаний changeset без интерактивного запуска в WSL/Git Bash.
- Уверенность в выводах **высокая**: базовая точка заимствования (`9c9f36c`) установлена детерминированно по совпадению хешей 31 из 35 скиллов, а весь diff `9c9f36c..49dd158` просмотрен полностью по всем 70 затронутым файлам. Выводы могут измениться только при выходе новых коммитов в `mattpocock/skills` после `49dd158`.
