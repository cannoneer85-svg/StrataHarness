# Аналоги харнесов агентов: что перенять в StrataHarness

- **Дата:** 2026-10-05
- **Аудитория:** автор Шаблона (глубокий технический уровень)
- **Статус:** утверждён

## Вопрос

Какие паттерны, скиллы и workflow из аналогичных харнесов (наборы скиллов, правила агентов, spec-driven фреймворки, IDE-агенты) стоит перенять в StrataHarness? Результат — приоритизированный бэклог идей, который станет входом для будущих задач разработки Шаблона.

## Вывод

1. **Самый большой пробел StrataHarness — у нас нет механического слоя.** Все инварианты (Шаг 0, стоп-гейты, запрет push, восстановление после compaction) записаны только прозой в `AGENTS.md` и скиллах. Ближайшие аналоги (superpowers, ECC, SuperClaude, плагины Anthropic, Kiro) подкрепляют такие правила хуками `SessionStart`/`PreCompact`/`Stop`/`PreToolUse` [1][4][6][3][11].
2. **Второй пробел — Оркестратор не умеет восстанавливаться.** У Оркестратора нет ledger выполнения, по которому он восстановится после compaction. Нет и формального контракта «бриф вниз / результат вверх». Нет ограниченного цикла исправлений [1][2][15].
3. **Третий — ревью и проверка готовности.** Находки ревью никто не перепроверяет [3]. Нет проверки покрытия спеки тикетами до реализации [8]. Нет правила «не утверждать, что готово, без свежих доказательств» [1].
4. **В чём Шаблон уже на уровне лучших аналогов или впереди:**
   - классификация масштаба (Шаг 0 + Fog) — ближе всего к ней BMAD [9];
   - обновление Проектов с трёхсторонним сравнением — так же, как manifest-апгрейд Spec Kit [8];
   - ручные скиллы через `disable-model-invocation` + `openai.yaml` [2][16];
   - handoff в коммитимых файлах, а не в авто-памяти — это прямо рекомендует Windsurf [14].
5. **Тренд, который стоит учесть осознанно.** Agent OS v3, новый BMAD и OpenSpec уходят от жёстких фаз к «процессу по размеру задачи» [12][9][10]. superpowers убирает стоп-гейты *внутри* исполнения плана («Rulings, not stalls») [1]. Стоп-гейты между стадиями стоит сохранить, а внутри Stage 4 в режиме Оркестратора — рассмотреть режим «решай сам и записывай Ruling».
6. **Риск рассинхрона с upstream (mattpocock/skills):**
   - конвенция `CONTEXT.md` переименована в `GLOSSARY.md`;
   - `resolving-merge-conflicts` удалён;
   - появились `retro`, `implement-spec`, `pr`;
   - межскилловые вызовы теперь пишутся как «Call the Skill tool with …» [2].

   Решение нужно принять до следующей синхронизации.
7. **Числовые квоты вопросов интервью ни на чём не основаны и конфликтуют с нашим критерием «пустой фронтир».** Ни один аналог не задаёт нижнюю границу числа вопросов, а upstream прямо отказался от лимитов [2]. Рекомендация: минимум задают обязательные темы раундов, потолка нет, числа служат только сигналом перекатегоризации (см. раздел «Квоты вопросов интервью»).

## Обоснование

### Сравнительная таблица аналогов

| Аналог | Класс | ★ / активность | Маршрутизация по масштабу | Гейты | Память / handoff | Оркестрация | Проверка | Мультихарнес | Распространение |
|---|---|---|---|---|---|---|---|---|---|
| **StrataHarness** | шаблон-репо | — | Шаг 0: Minor/Feature/Epic/Fog + Analysis | после каждой стадии | `docs/handoff/` + `LATEST.md`, `.scratch/` | Оркестратор + субагенты | 2-осевое ревью, Test-Template.ps1 | Claude (зеркало), Antigravity, Codex | `/init-project` (New/Add/Update), `/release` |
| obra/superpowers [1] | скиллы + хуки | 295k, активен | нет | brainstorm→plan; внутри SDD гейтов нет | ledger `.superpowers/sdd/<plan>/progress.md` | свежий implementer на задачу, 2-осевое ревью задачи, финальное ревью ветки | verification-before-completion, тесты триггеров скиллов | 9+ харнесов, `references/<harness>-tools.md` | плагин + marketplace |
| mattpocock/skills [2] | скиллы (наш upstream) | 276k, активен | нет | — | — | `implement-spec`: frontier, worktree на тикет | `retro` | Claude + Codex (`openai.yaml`) | плагин в официальном маркетплейсе, `npx skills` |
| Anthropic feature-dev / code-review [3] | официальные плагины | 149k | нет | 7 фаз, «DO NOT START WITHOUT USER APPROVAL» | — | 2–3 explorer, 2–3 architect, 3–4 reviewer параллельно | каждую находку валидирует отдельный субагент | Claude | плагин |
| affaan-m/ECC [4] | мега-конфиг | 273k | нет | — | `/save-session`, хуки PreCompact/SessionStart | ~68 агентов | `/harness-audit`: 12 категорий | 10+ харнесов | профили установки, `install.ps1` |
| wshobson/agents [5] | 92 плагина | 40k | нет | conductor: Context→Spec→Implement | conductor tracks | agent-teams | `make validate/garden`, CLI smoke в CI | 7 адаптеров (вкл. Antigravity) | генерация из единого источника |
| SuperClaude [6] | фреймворк режимов | 24k | нет | — | pm-скилл (PDCA, восстановление контекста) | персоны | confidence-check ≥90%, prompt-хуки | Claude | install.sh |
| humanlayer `.claude/` [7] | команды | 11.6k | нет | пауза на ручную проверку после каждой фазы | `create_handoff` / `resume_handoff` с YAML-метаданными | locator/analyzer/pattern-finder | auto vs manual критерии успеха | Claude | — |
| GitHub Spec Kit [8] | spec-driven | ~140k | по виду процесса (feature/bug/idea) | ручные + Constitution Check GATE | `specs/<###-feature>/` | — | `/analyze` (покрытие), `/converge` | 30+ интеграций | CLI, manifest-апгрейд |
| BMAD-METHOD [9] | spec + персоны | ~54k | light/full path по 3 сигналам | build→`built`, `done` ставит человек | `tickets.toml`, планы хранятся | `bmad-build-auto` по тикету | review-триаж, retrospective | любые с поддержкой скиллов | `npx skills`, `bmad setup` |
| OpenSpec [10] | spec deltas | ~71k | нет | «no phase gates» | `changes/` → `archive/YYYY-MM-DD-*` | — | `/opsx:verify`, `validate` | 30+ инструментов, пишет `.agents/skills/` | npm CLI `init/update` |
| Kiro [11] | IDE (закрытая) | — | Feature vs Bugfix | approval gates (Quick Spec их пропускает) | steering-файлы | волны задач по графу | Analyze Requirements, PBT | — | продукт |
| Agent OS v3 [12] | стандарты | 5.5k | нет | фазы убраны | `standards/index.yml` | — | — | Claude, Cursor, Antigravity | профили, `--commands-only` |
| Task Master [13] | трекер задач | 28k, замедлился | complexity 1–10 на задачу | нет | `tasks.json` | `next` по зависимостям | `validate-dependencies` | MCP, rules для IDE | npm / MCP |
| Cline / Roo / Cursor / Windsurf / Copilot [14] | IDE-агенты | — | нет | Copilot `handoffs` с `send:false` | Memory Bank (`activeContext`/`progress`), `/newtask` | Roo Orchestrator: явный контракт down/up | Cursor verifier-субагент | — | Roo export/import режима |
| Ruler / rulesync [17] | синхронизаторы | — | — | — | — | — | — | ~20 таргетов (вкл. Antigravity) | генерация из `.ruler/` / `.rulesync/` |

### Разбор ключевых аналогов

**1. obra/superpowers — ближайший по духу аналог** [1]. Процесс brainstorm → plan → subagent-driven development → review → finish. Три механики, которых у нас нет:
- *Ledger:* `.superpowers/sdd/<plan>/progress.md` с маркерами `Task N: complete`. Обоснование из скилла: «controllers that lost their place have re-dispatched entire completed task sequences — the single most expensive failure observed».
- *Ограниченный цикл исправлений:* «Fix round R of 5: R≤3 resume implementer; R≥4 fresh implementer, more capable model» плюс явная модель для каждого субагента.
- *Хук SessionStart* с matcher `startup|clear|compact` заново вставляет роутер скиллов после compaction.

Отдельно ценен `references/antigravity-tools.md`: в Antigravity нет todo-инструмента, его место занимает task-артефакт. Это прямая подсказка для нашей кросс-харнесной адаптации.

**2. mattpocock/skills — upstream** [2]. За время после нашей синхронизации появилось:
- `implement-spec`: граф тикетов с «frontier», worktree на тикет, фоновые implementer'ы;
- `retro`: правило «механическое нарушение → детерминированная проверка, `CODING_STANDARDS.md` — только для суждений»;
- `pr`: Evidence Before/After, «Merge Danger: one-way/two-way door».

Есть ломающие изменения: `GLOSSARY.md` вместо `CONTEXT.md`, удалён `resolving-merge-conflicts`. Upstream распространяется как плагин из официального маркетплейса; список продвигаемых скиллов задаёт `.claude-plugin/plugin.json`.

**3. Anthropic code-review / feature-dev** [3]. code-review делает две вещи, которых нет у нас:
- *Пред-проверка* «нужно ли ревью» на дешёвой модели.
- *Валидация каждой находки* отдельным субагентом; невалидированные находки отбрасываются. Критерий: «Clear, unambiguous CLAUDE.md violations where you can quote the exact rule being broken… If you are not certain an issue is real, do not flag it». К нему приложен список типовых false positives.

feature-dev: фаза «2–3 архитектурных подхода (minimal / clean / pragmatic)» перед реализацией и правило «"whatever you think is best" → дай рекомендацию и получи явное подтверждение».

**4. GitHub Spec Kit** [8]. Две механики:
- `/speckit-analyze`: STRICTLY READ-ONLY, кросс-проверка spec/plan/tasks с процентом покрытия требований задачами.
- `/speckit-converge`: недоделанное дописывается новыми задачами — «Repeat implement → converge until Converged».

Manifest-апгрейд у них устроен так же, как наш `-Mode Update` с трёхсторонним сравнением. Тут мы уже на уровне.

**5. BMAD-METHOD** [9]. Его маршрутизация ближе всех к Шагу 0: «reports three facts… intent gaps, irreversible actions, and footprint. A design clean on all three takes the light path». Ещё два полезных принципа:
- «only what the repository and planning context cannot settle becomes an open question» — сначала искать ответ в репо, потом спрашивать;
- «Keep completed plans. Deleting one removes the state and evidence later builds, review, and retrospective read» — прямой контраргумент к нашей очистке `.scratch/` при close-task.

**6. Kiro и OpenSpec** [11][10].
- Kiro: шаблон bugfix-спеки с секцией «Unchanged Behavior: WHEN … SHALL CONTINUE TO …» (защита от регрессий), EARS-нотация требований, волны задач по графу зависимостей.
- OpenSpec: delta-спеки (`ADDED / MODIFIED / REMOVED Requirements`) и архив `changes/archive/YYYY-MM-DD-<name>/`, который сливается в живые спеки `openspec/specs/`.

**7. ECC и wshobson/agents — инфраструктура качества** [4][5].
- ECC: детерминированный `/harness-audit` по 12 категориям, профили установки (minimal/core/full), lean context profile с явным бюджетом токенов.
- wshobson: инварианты «каждая находка валидатора содержит строку-исправление», «context files ≤~150 строк, тело скилла ≤8 KB (лимит Codex)», drift-gardener, smoke-тест на реальных CLI (включая Antigravity) в CI.

**8. IDE-агенты и стандарты** [14][15][16].
- Roo Orchestrator формализует контракт: «Down: Via the initial instructions… Up: Via the final summary… only this summary returns to the parent».
- Copilot `handoffs` (`label`, `agent`, `prompt`, `send: false`) — по сути машиночитаемый стоп-гейт.
- Cline Memory Bank разделяет `activeContext.md` и `progress.md`; `/newtask` упаковывает в handoff «plan, work accomplished, relevant files, next steps».
- Опубликованные лимиты: Codex — `AGENTS.md` 32 KiB, список скиллов ≤2% контекста или 8000 символов; Windsurf — 12 000 символов на файл правил; Antigravity — 24 000 байт на файл; Agent Skills — `description` ≤1024, `name` = имя каталога, `SKILL.md` ≤500 строк.
- Cursor и Codex читают `.agents/skills/` нативно, зеркало им не нужно.

### Бэклог идей с приоритетами

Ценность и стоимость оцениваются по шкале В/С/Н (высокая/средняя/низкая). Категория — ожидаемая по Шагу 0.

#### P1 — делать в первую очередь

| # | Идея | Что меняется в Шаблоне | Ценность | Стоимость | Категория | Источник |
|---|---|---|---|---|---|---|
| 1 | **Ledger выполнения для Оркестратора** | `.scratch/<feature>/LEDGER.md` с первой строкой-идентификатором, маркерами `Ticket N: complete` и записями `Ruling: что — почему — цена ошибки`. Правило в `implement`: после compaction восстанавливаться по ledger + `git log` | В | Н | Minor | [1] |
| 2 | **Контракт брифа и результата субагента** | Шаблоны в `implement/references/`. Бриф вниз: цель, контекст-указатели, критерии. Результат вверх: что изменено, тесты, открытые вопросы, расхождения в формате Expected/Found/Why | В | Н | Minor | [15][7][2] |
| 3 | **Валидация находок code-review** | Каждая находка по оси Standards цитирует правило. Отдельный субагент перепроверяет находку, невалидированные отбрасываются. Добавить список false positives | В | С | Minor/Feature | [3] |
| 4 | **Evidence before claims** | В отчёт Stage 4: таблица «Утверждение — Доказательство — Чего недостаточно». Критерии успеха в тикетах делятся на Automated и Manual | В | Н | Minor | [1][7] |
| 5 | **Решение по рассинхрону с upstream** | ADR: принять `GLOSSARY.md` или зафиксировать расхождение. Решить судьбу `resolving-merge-conflicts`. Перейти на формулировку «Call the Skill tool with …» | В | Н | Minor (+ADR) | [2] |
| 6 | **Лимиты размера и спеки скиллов в Test-Template.ps1** | Проверки: `name` = каталог, `description` ≤1024 символов и валидный YAML (ловить незакавыченный `: `), `SKILL.md` ≤500 строк / ≤8 KB, сумма description ≤8000 символов, `AGENTS.md`+`CONTEXT.md` ≤32 KiB. К каждой ошибке — строка «как исправить» | В | Н | Minor | [3][5][16][2] |
| 25 | **Квоты интервью → пол по темам + выход по фронтиру** | Колонка Routes в `AGENTS.md`: «Interview floor» (обязательные темы), без потолка вопросов. В README числа помечаются как типичные. Числа служат сигналом перекатегоризации. Подробности — в разделе «Квоты вопросов интервью» | В | Н | Minor | [2][3][8][9] |

#### P2 — следующая волна

| # | Идея | Что меняется | Ценность | Стоимость | Категория | Источник |
|---|---|---|---|---|---|---|
| 7 | **Хуки как механический слой** | `.claude/settings.json`: `SessionStart(startup\|clear\|compact)` вставляет Шаг 0 и активную `.scratch/`; `PreCompact` обновляет ledger/handoff; prompt-хук `Stop` «есть незакоммиченное или незавершённое → отметь»; `PreToolUse` блокирует `git push --force` (обновить `git-guardrails-claude-code` до включённого по умолчанию). Для Antigravity — аналог через его механизмы или явное «не поддерживается» | В | С | Feature | [1][4][6] |
| 8 | **Проверка покрытия спеки до Stage 4 + converge** | Read-only шаг в конце `to-tickets`: таблица «требование → тикеты», непокрытые требования = блокер. Находки spec-оси ревью превращаются в новые тикеты в `TICKETS.md` | В | С | Feature | [8] |
| 9 | **Скрипт графа тикетов** | `Get-ReadyTickets.ps1`: парсит `Blocked by`, ловит циклы и битые id, выводит готовые тикеты и волны. Пометка `[P]` для тикетов, которые можно делать параллельно | С | Н | Minor | [13][8][11] |
| 10 | **Сигналы BMAD в Шаге 0** | Добавить в таблицу Категорий: пробелы в намерении, необратимые действия, площадь изменений. Правило «сначала ищи ответ в репо, спрашивай только то, что репо не решает» в `grill-with-docs` | С | Н | Minor | [9] |
| 11 | **Карта инструментов по харнесам** | `.agents/references/<harness>-tools.md` (Antigravity: task-артефакт вместо todo, `ask_question`, `invoke_subagent`; Claude: TodoWrite, Task; Codex). Ссылки из скиллов | С | Н | Minor | [1] |
| 12 | **Архив вместо удаления при close-task** | Переносить спеку, тикеты и ledger в `docs/archive/YYYY-MM-DD-<feature>/`, а не удалять из `.scratch/`. Опционально: живые спеки по capability | С | Н | Minor | [9][10] |
| 13 | **Опциональный `retro` после Close** | Перенести upstream-`retro`: находки сессии → детерминированные проверки в Test-Template, правки AGENTS.md | С | Н | Minor | [2] |
| 14 | **Bugfix-шаблон для Minor** | Три секции: текущее / ожидаемое / неизменное поведение (WHEN … SHALL CONTINUE TO …). Регрессионный тест на «неизменное» | С | Н | Minor | [11][8] |

#### P3 — по мере необходимости

| # | Идея | Ценность | Стоимость | Источник |
|---|---|---|---|---|
| 15 | Плагин/marketplace-манифест `.claude-plugin/` как второй канал распространения рядом с `/init-project` (ядро процесса отдельно от misc) | С | С | [2][3][1] |
| 16 | Профили `/init-project`: minimal / standard / full | С | С | [4][12] |
| 17 | Детерминированный аудит Шаблона (scorecard поверх Test-Template.ps1) и drift-gardener (битые ссылки, сироты в Реестре) | С | С | [4][5] |
| 18 | Фаза «2–3 архитектурных подхода» перед `to-spec` для Feature/Epic; правило «whatever you think → рекомендация + подтверждение» | С | Н | [3] |
| 19 | Режим «Rulings, not stalls» внутри Stage 4 для Оркестратора: останавливаться только на необратимом, на security, на побочных эффектах вне worktree и на сломанном плане | С | Н | [1] |
| 20 | YAML frontmatter в handoff (`git_commit`, `branch`, `status`, `topic`, `tags`) | Н | Н | [7] |
| 21 | Машиночитаемый блок «Следующая стадия» в стадийных скиллах (как Copilot `handoffs`), генерация `.github/agents/*.agent.md` | Н | С | [15] |
| 22 | Расширить `Sync-ClaudeSkills.ps1` до `-Targets` (Devin/Windsurf) или перейти на rulesync. В Реестре отметить, что Cursor и Codex читают `.agents/skills/` без зеркала | Н | С | [17][14] |
| 23 | Confidence-check перед Stage 4 (дубли, ADR, доки внешних API через context7) | Н | Н | [6] |
| 24 | Тесты триггеринга скиллов (набор промптов, которые должны вызвать нужный скилл) | Н | С | [1] |

### Квоты вопросов интервью: как у нас и как у других

**Как сейчас.** В `AGENTS.md` и README заданы числа: Minor — 1 раунд, 2–4 вопроса; Feature — ≥2 раунда, 6–8 вопросов; Epic — ≥3 раунда, 10–12+ вопросов; Analysis — 1 раунд, 4 пункта. Обоснования этих чисел нигде нет. В спеке v2 они записаны требованием I5 без пояснений (`docs/specs/0001-template-v2-spec.md`), ADR о них нет. Числа задают *масштаб* интервью под Категорию, но не берутся ни из какой методики.

**Где это противоречит нашему же процессу.** `grill-with-docs` строит раунды на `grilling`. По `grilling` интервью закончено, когда пуст *фронтир*: все ветки дерева решений пройдены, ничего не принято молча. Раунд закрывается, «when its theme's frontier is empty». Получается два разных критерия выхода одновременно — число вопросов и пустой фронтир. Отсюда два перекоса:
- **верхняя граница** («6–8») обрывает разбор сложной задачи;
- **нижняя граница** («минимум 6») провоцирует вопросы для галочки, ответ на которые агент мог найти сам. `grilling` прямо это запрещает: «Finding facts is your job, never the user's».

**Как у других.**

| Аналог | Число вопросов | Критерий выхода | Источник |
|---|---|---|---|
| mattpocock/skills (наш upstream) | лимита нет, просьбы ввести его вынесены в out-of-scope | пуст фронтир; пользователь может остановить в любой момент | `.out-of-scope/question-limits.md` [2]: «some plans need three questions, some need fifty. A fixed cap would either cut off useful exploration on hard problems or feel arbitrary on easy ones» |
| Spec Kit `/speckit-clarify` | жёсткий **потолок** 5 вопросов за сессию, ответ — вариант или ≤5 слов | закрыты самые важные неясности спеки | [8] |
| Anthropic feature-dev | числа нет, фаза обязательна: «CRITICAL… DO NOT SKIP» | все неясности сняты; на «whatever you think is best» — рекомендация + явное подтверждение | [3] |
| BMAD | интервью до работы нет | вопросом становится только то, что «the repository and planning context cannot settle»; вопросы задаются по готовому дизайну | [9] |
| Kiro | интервью нет | агент сам генерирует требования, человек правит их на гейте | [11] |
| Cline `/deep-planning` | числа нет | сначала «Silent Investigation» (агент читает репо), потом обсуждение | [14] |

Числовой нижней границы нет ни у кого. Потолок есть только у Spec Kit — для узкого шага уточнения уже написанной спеки. Общий тренд: агент сначала сам собирает факты, а пользователю задаёт только *решения*.

**Рекомендация.** Минимум задавать **темами**, а не числом вопросов:

1. **Минимум — обязательные темы раундов.** Minor: общий план и основной сценарий. Feature: плюс ошибки и граничные случаи. Epic: плюс нефункциональные требования. Analysis: 4 пункта.
2. **Потолка нет.** Агент спрашивает, пока остаются нерешённые вопросы, и может добавить раунды, если ответы открыли новое.
3. **Числа остаются ориентиром.** Если на Minor набирается больше ~6 вопросов, это сигнал перекатегоризировать задачу в Feature.
4. **Факты агент добывает сам.** Пользователю задаются только решения.

Почему не «минимум N вопросов»: на простой задаче агент начнёт придумывать вопросы, лишь бы добрать число.

**Что поменять** (отдельная задача Minor):
- в `AGENTS.md`, таблица Routes: колонку «Interview quota» заменить на обязательные темы и добавить строку «No question cap: ask until no open decisions remain»;
- в `README.md` и `README.ru.md`: числа вопросов убрать или пометить как типичные.

### Что уже есть (не переносить)

- **Защищённое обновление Проектов:** `init-project -Mode Update` уже классифицирует файлы (`Modified in Template`, `Conflict: modified locally`) и не перезаписывает локальные правки. Это эквивалент manifest-апгрейда Spec Kit [8].
- **Ручные скиллы:** `disable-model-invocation: true` + `allow_implicit_invocation: false` уже стоят для стадийных скиллов (см. `.agents/SKILLS.md`) [2][16].
- **Handoff в коммитимых файлах** вместо авто-памяти [14].

## Источники

Веб-источники проверены 2026-10-04/05; звёзды взяты из GitHub API.

1. obra/superpowers — https://github.com/obra/superpowers (`skills/subagent-driven-development/SKILL.md`, `skills/verification-before-completion/SKILL.md`, `hooks/hooks.json`, `skills/using-superpowers/references/antigravity-tools.md`, `docs/testing.md`)
2. mattpocock/skills — https://github.com/mattpocock/skills (`CHANGELOG.md`, `.agents/invocation.md`, `skills/engineering/implement-spec`, `retro`, `pr`, `.claude-plugin/plugin.json`)
3. anthropics/claude-code plugins — https://github.com/anthropics/claude-code/tree/main/plugins (`feature-dev/commands/feature-dev.md`, `code-review/commands/code-review.md`); anthropics/skills — https://github.com/anthropics/skills; Claude Code skills docs — https://code.claude.com/docs/en/skills
4. affaan-m/ECC (бывший everything-claude-code) — https://github.com/affaan-m/ECC (`hooks/README.md`, `manifests/install-profiles.json`, `scripts/harness-audit.js`)
5. wshobson/agents — https://github.com/wshobson/agents (`ARCHITECTURE.md`, `tools/adapters/antigravity.py`, `plugins/conductor`)
6. SuperClaude Framework — https://github.com/SuperClaude-Org/SuperClaude_Framework (`plugins/superclaude/hooks/hooks.json`, `confidence-check`)
7. humanlayer/humanlayer — https://github.com/humanlayer/humanlayer/tree/main/.claude (`commands/create_handoff.md`, `implement_plan.md`)
8. GitHub Spec Kit — https://github.com/github/spec-kit (`templates/`, `templates/commands/analyze.md`, `converge.md`, `docs/upgrade.md`)
9. BMAD-METHOD — https://github.com/bmad-code-org/BMAD-METHOD (`docs/build/build-a-change.md`, `docs/plan/choose-a-planning-path.md`, `docs/plan/break-work-into-stories-and-track-it.md`)
10. OpenSpec — https://github.com/Fission-AI/OpenSpec (`docs/concepts.md`)
11. Kiro — https://kiro.dev/docs/specs/, https://kiro.dev/docs/specs/bugfix-specs/, https://kiro.dev/docs/steering/, https://kiro.dev/docs/hooks/
12. Agent OS — https://github.com/buildermethods/agent-os (`CHANGELOG.md`, v3)
13. Task Master — https://github.com/eyaltoledano/claude-task-master (`docs/task-structure.md`, `docs/command-reference.md`)
14. Cline — https://docs.cline.bot (rules, skills, memory-bank, commands); Cursor — https://cursor.com/docs/rules, https://cursor.com/docs/skills, https://cursor.com/docs/subagents; Windsurf/Devin — https://docs.windsurf.com/windsurf/cascade/memories
15. Roo Code — https://github.com/RooCodeInc/Roo-Code-Docs (`docs/features/boomerang-tasks.mdx`, `custom-modes.mdx`); VS Code Copilot custom agents — https://code.visualstudio.com/docs/copilot/customization/custom-agents
16. AGENTS.md — https://agents.md; Codex AGENTS.md — https://developers.openai.com/codex/guides/agents-md; Codex skills — https://developers.openai.com/codex/skills; Agent Skills spec — https://agentskills.io/specification
17. Ruler — https://github.com/intellectronica/ruler; rulesync — https://github.com/dyoshikawa/rulesync

## Ограничения

- **Метод.** Сбор вели три фоновых субагента `research` по первоисточникам (README, доки, файлы репозиториев через GitHub API/raw). Цитаты сверены субагентами, а не повторно автором документа.
- **Не проверено по первоисточникам:**
  - Aider и OpenHands — только по сводкам поиска;
  - детали Kilo Code (страницы документации вернули 404);
  - статус Cline Workflows (вероятно, влиты в Skills);
  - Copilot prompt files;
  - содержимое evals superpowers (отдельный репозиторий);
  - внутренности ECC (instincts, epic-*);
  - метрики confidence-check SuperClaude;
  - схема зависимостей `tickets.toml` в BMAD.
- **Не исследованы:** Tessl, OpenCode, Gemini CLI extensions, Kimi и другие харнесы за пределами бюджета ~8 кандидатов на группу.
- **Оценки ценности и стоимости** экспертные, без прототипирования. Стоимость хуков (идея 7) может вырасти: поддержка хуков в Antigravity не исследовалась.
- **Быстрое устаревание.** Экосистема меняется за недели: BMAD и Agent OS радикально перестроились в 2026 году, а Windsurf переименован в Devin Desktop. Выводы стоит перепроверить перед реализацией каждой идеи.
- **Что изменило бы вывод:** если окажется, что Antigravity не поддерживает хуки, приоритет идеи 7 падает в пользу чисто текстовых мер (идеи 1, 2, 4).
