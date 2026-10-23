# Аудит предложений по улучшению Шаблона из ретроспективы дочернего Проекта (Upstream Proposal)

- **Дата:** 2026-10-23
- **Аудитория:** Автор и мейнтейнер Шаблона (`StrataHarness`)
- **Статус:** утверждено

## Вопрос

Необходимо ли вносить в ядро **Шаблона** (`StrataHarness` `v1.4.3`) 4 архитектурных изменения из входного документа ретроспективы дочернего **Проекта** (`STRATAHARNESS_UPSTREAM_PROPOSAL.md` [1]), какие из них устраняют реальные системные уязвимости маршрутизации **Цикла разработки**, а какие требуют калибровки или отклонения, чтобы не сломать обратную совместимость и не вызвать ложные срабатывания на типовых задачах? Результат анализа напрямую определяет состав и точные формулировки для последующей **Задачи разработки** в **Шаблоне**.

## Вывод

**Да, вносить изменения в Шаблон необходимо, но не буквальным копированием, а с обязательной архитектурной калибровкой (3 пункта — принять с калибровкой, 1 пункт — принять практически как есть, подпункт про `CONTEXT-MAP.md` — отклонить).**

Все 4 проблемы, выявленные при боевой эксплуатации [1], указывают на реальные зазоры в текущих инструкциях **Шаблона** (`v1.4.3`), которые остались открытыми после предыдущего бэкпорта (`retro-core-improvements` [8]) и Спецификации 0006 [9]:

1. **Пункт 1 (Синхронизация выбора `In-Place` vs `Sequential Subagents` между Этапами 3 и 4) — Принять с калибровкой:**
   - **Что исправляем:** Устраняем «слепую зону» ленивого чтения скиллов между `to-tickets` [4] и `implement` [6], а также иллюзию в таблице `Routes` корневого `AGENTS.md` [2], где пометка `4 (Orchestrator)` стоит только у `Epic`. Обязываем агента объявлять стратегию исполнения уже на **Стоп-гейте** Этапа 3 и вводим `Hard override` на Этапе 4.
   - **Что калибруем (отсекаем перегибы):** Исключаем из жёсткого триггера Оркестратора условие `modifies >3 files` и `external I/O probes` для задач из 1–2 тикетов. В любой типизированной кодовой базе с TDD даже минимальный тикет затрагивает 3–4 файла (реализация, типы/интерфейс, модульный тест); принудительный запуск Оркестратора на задаче из 1 тикета лишь удваивает расход токенов на генерацию `BRIEF.md` и повторный прогон тестов без выигрыша по контексту между тикетами.
2. **Пункт 2 (Универсальный детерминированный триггер субагента `Adversary` на Этапе 5) — Принять в `code-review/SKILL.md` с калибровкой, отклонить в части `CONTEXT-MAP.md`:**
   - **Что отклоняем (`2.1 CONTEXT-MAP.md`):** В **Шаблоне** не существует файла `.agents/CONTEXT-MAP.md` — это локальный кастомный артефакт монорепозитория `phygital` [10]. Сам **Шаблон** использует single-context схему (`.agents/CONTEXT.md` + `docs/adr/` [3, 11]), а опциональный корневой `CONTEXT-MAP.md` в скилле `domain-modeling` [12] предназначен исключительно для описания ограниченных контекстов (DDD) и по явному правилу не должен содержать процессных деталей реализации.
   - **Что принимаем и калибруем (`2.2 Триггеры диффа в code-review/SKILL.md`):** Убираем из `code-review/SKILL.md` [7] дезориентирующие маркеры `optional` и `(Epic & security-critical tasks only)`. Делаем запуск **Adversary** обязательным на любом маршруте (`Minor`, `Feature`, `Epic`) при срабатывании детерминированного чек-листа из 5 категорий риск-сигналов в `git diff` (или при явном указании в `CODING_STANDARDS.md`). При этом удаляем противоречивую приписку `Skip ONLY when pure static UI styling/copy or documentation`, чтобы не запускать 3-го субагента вхолостую на чистых функциях, типах и изолированных тестах без риск-сигналов.
3. **Пункт 3 (Запрет горизонтальных «тестовых тикетов» в `to-tickets/SKILL.md`) — Принять как есть (с оговоркой для `expand–contract`):**
   - Явный запрет на вынос автотестов тикетов `01..N-1` в отдельный финальный тикет `N` полностью закрывает лазейку, через которую субагенты обходили требование TDD в `implement/SKILL.md` [6].
4. **Пункт 4 (Защита от потери стадии при Compaction на границе Этапов 4 и 5) — Принять с калибровкой:**
   - Добавление строки метаданных `**Active Stage:** ... | **Execution Strategy:** ...` в шапку `TICKETS.md` (`tickets-map-template.md` [5]) идеально ложится в архитектуру Спецификации 0006 [9] (консолидация состояния внутри `TICKETS.md` без создания лишних файлов). Калибровка состоит в том, чтобы явно прописать обязанность обновления `Active Stage` не только в шаблоне и `implement/SKILL.md`, но и на старте `code-review/SKILL.md` [7].

---

## Обоснование

### 1. Сводная матрица аудита предложений

| № | Предложение из `STRATAHARNESS_UPSTREAM_PROPOSAL.md` [1] | Целевые файлы | Вердикт | Причина и суть калибровки |
|---|---|---|---|---|
| **1.1** | Убрать привязку `Orchestrator` только к `Epic` в `AGENTS.md` (`Routes` и `Context budget`) | `AGENTS.md` [2] | **Принять с калибровкой** | В `AGENTS.md` действительно есть перекос: `4 (Orchestrator)` указан только у `Epic`. Нужно явно указать `1–2 tickets → In-Place; ≥3 tickets → Orchestrator`, но без жёсткого запрета `In-Place` при касании `>3 файлов` на 1–2 тикетах. |
| **1.2** | Выбор `Execution Strategy` уже на Стоп-гейте Этапа 3 (`to-tickets`) | `.agents/skills/to-tickets/SKILL.md` [4] | **Принять с калибровкой** | Закрывает слепую зону ленивого чтения `implement/SKILL.md`. Формула выбора синхронизируется с Этапом 4: `≥3 тикетов` или многотикетная правка крупных файлов (`>1,000 строк` / прогноз `>60k` токенов) = строго `Sequential Subagents`. |
| **1.3** | Жёсткий предохранитель (`Hard override`) выбора стратегии на Этапе 4 | `.agents/skills/implement/SKILL.md` [6] | **Принять с калибровкой** | В бэкпорте `retro-core-improvements` [8] таблица в `implement/SKILL.md` уже была сужена до `1–2 tickets under ~60k tokens`, но без `Hard override` агент продолжает исполнять `In-Place`, если пообещал его на Этапе 3. Добавляем явный `Hard override`. |
| **2.1** | Колонка `Review Profile` в `.agents/CONTEXT-MAP.md` | `.agents/CONTEXT-MAP.md` | **Отклонить** | Файла `.agents/CONTEXT-MAP.md` нет в **Шаблоне** (`StrataHarness` использует single-context `.agents/CONTEXT.md` [3, 11]). Смешивать доменный глоссарий с настройками пайплайна ревью запрещено правилами `domain-modeling` [12]. При необходимости проектные правила модулей фиксируются в `CODING_STANDARDS.md`. |
| **2.2** | Детерминированный триггер субагента **Adversary** по риск-сигналам `git diff` | `.agents/skills/code-review/SKILL.md` [7] | **Принять с калибровкой** | Заголовок `(Epic & security-critical tasks only)` и слово `optional` в `code-review/SKILL.md` [7] провоцируют пропуск **Adversary** на инфраструктурных и сетевых задачах категории `Feature`. Переводим в обязательный триггер по 5 группам сигналов диффа, убирая противоречивую фразу про «только статический UI/документацию». |
| **3** | Запрет выделения автотестов в отдельный финальный тикет | `.agents/skills/to-tickets/SKILL.md` [4] | **Принять как есть** | Прямо защищает цикл TDD и шаг верификации Оркестратора (`implement/SKILL.md §4.3`). Уточняем совместимость с существующим исключением `expand–contract` для широких рефакторингов [4]. |
| **4** | Поле `Active Stage` и `Execution Strategy` в `TICKETS.md` для защиты от Compaction между стадиями | `tickets-map-template.md` [5], `implement/SKILL.md` [6], `code-review/SKILL.md` [7] | **Принять с калибровкой** | Развивает решение Спецификации 0006 [9] (единый источник состояния в `TICKETS.md`). Дополняем предложением обновлять `Active Stage` в `to-tickets`, на финише `implement` и на входе в `code-review`. |

---

### 2. Детальный разбор по пунктам

#### Пункт 1: Слепая зона между Этапом 3 (`to-tickets`) и Этапом 4 (`implement`)

**Проверка корневой причины по коду Шаблона:**
- В [AGENTS.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/AGENTS.md#L39-L45) таблица `Routes` выглядит так:
  - `Minor`: `1 → 4 (In-Place) → 5 → 6`
  - `Feature`: `1 → 2 → 3 → 4 → 5 → 6`
  - `Epic`: `1 → 2 → 3 → 4 (Orchestrator) → 5 → 6`
- В разделе `Context budget` ([AGENTS.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/AGENTS.md#L64-L67)) указано лишь `Smart zone: ≈120k tokens` и дана ссылка на `implement/SKILL.md` [6].
- В ходе предыдущего бэкпорта (`2026-10-22-retro-core-improvements.md` [8]) в [implement/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/implement/SKILL.md#L21-L27) условие `In-Place` уже было сужено до `Minor route, or 1–2 tickets whose total forecast stays under ~60k tokens`.
- Однако из-за правила ленивой загрузки скиллов (`Once the user confirms a stage, read its SKILL.md` [2]) агент на Этапе 3 (`to-tickets` [4]) ещё не видел порога `1–2 tickets / ~60k` из `implement/SKILL.md`. Видя в `AGENTS.md` бюджет `120k` и пометку `(Orchestrator)` только напротив `Epic`, агент на **Стоп-гейте** Этапа 3 предлагает пользователю `In-Place` даже для 4 тикетов, а на Этапе 4 считает себя связанным утверждённым решением пользователя.

**Почему часть условий из `STRATAHARNESS_UPSTREAM_PROPOSAL.md` нужно откалибровать:**
- В предложении [1] формула для обязательного запуска `Sequential Subagents` включает:
  `whenever the breakdown has 3 or more tickets, touches any file >1,000 lines, modifies >3 files, or involves external network/process/hardware probes`.
- **Риск ложных срабатываний:**
  1. Условие `modifies >3 files`: в реальной разработке по TDD даже один небольшой вертикальный срез из 1 тикета почти всегда меняет 3–5 файлов (например, модель/схема, обработчик/компонент, файл типов и файл тестов). Если запретить `In-Place` при касании `>3 файлов`, то задачи из 1 тикета будут принудительно переводиться в режим **Оркестратора**.
  2. На задаче из **1 тикета** запуск субагента-исполнителя через **Оркестратора** не экономит рабочий контекст между тикетами (так как второго тикета нет), но заставляет **Оркестратора** создавать `.scratch/<feature>/BRIEF.md`, ждать завершения дочерней сессии и повторно запускать те же самые проверки (`implement/SKILL.md §4.3`).
  3. Условие `involves external network/process/hardware probes` относится к профилю риска для код-ревью (**Adversary**), а не к размеру контекстного окна на этапе написания кода: сам по себе вызов `fetch` или `spawn` в одном тикете не переполняет окно в `120k` токенов.
- **Оптимальная калибровка для Шаблона:**
  - `In-Place`: маршрут `Minor`, либо строго **1–2 тикета**, чей совокупный прогноз укладывается в `≤60k токенов` (половина `Smart zone`) и которые не требуют последовательного редактирования крупных файлов (`>1,000 строк`) в нескольких тикетах подряд.
  - `Sequential Subagents` (**Оркестратор**): **обязателен** при **3 и более тикетах**, либо при **2 тикетах**, затрагивающих крупные файлы (`>1,000 строк`) или имеющих прогноз `>60k токенов`, либо для любого тяжёлого тикета с широким радиусом изменений.
  - `Hard override` в `implement/SKILL.md`: если в задаче `≥3 тикетов` (или 2 тикета поверх файлов `>1,000 строк`), агент **обязан** переключиться на `Sequential Subagents` на старте Этапа 4, даже если на более раннем этапе обсуждался `In-Place`.

---

#### Пункт 2: Детерминированный триггер 3-го субагента ревью (`Adversary`)

**Проверка корневой причины по коду Шаблона:**
- В [code-review/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/code-review/SKILL.md#L10) ось **Adversary** описана как `optional, for Epic or high-risk tasks`, а в шаге 4 ([code-review/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/code-review/SKILL.md#L90-L91)) озаглавлена:
  `**Adversary sub-agent (Epic & security-critical tasks only)**: For tasks on the Epic route, or changes modifying authentication, permissions, data migrations, or concurrent resources, spawn a third parallel sub-agent: **Adversary**.`
- Как показал кейс в `phygital` [1], при работе по маршруту `Feature` агент воспринимает заголовок `(Epic & security-critical tasks only)` буквально: если задача не меняет авторизацию/пермишены напрямую, но меняет сетевой опрос, выполнение внешних команд, управление процессами или асинхронные гонки состояний UI/кэша, **Adversary** не запускается.

**Почему подпункт `2.1 (.agents/CONTEXT-MAP.md)` необходимо отклонить:**
- В репозитории **Шаблона** (`StrataHarness`) файла `.agents/CONTEXT-MAP.md` нет — проверка дерева репозитория и манифеста инициализации ([init-project/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/init-project/SKILL.md#L67-L71)) показывает, что по умолчанию используется **single-context** структура (`.agents/CONTEXT.md` + `docs/adr/` [11]).
- Файл `d:\YandexDisk\AWG\phygital\.agents\CONTEXT-MAP.md` [10] — это кастомная таблица маршрутизации 10 сабмодулей монорепозитория `phygital`.
- В самом **Шаблоне** формат опционального корневого `CONTEXT-MAP.md` задан в [CONTEXT-FORMAT.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/domain-modeling/CONTEXT-FORMAT.md#L36-L52) как карта ограниченных доменных контекстов и их связей (`Ordering → Fulfillment`), а [domain-modeling/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/domain-modeling/SKILL.md#L64) прямо запрещает помещать в доменные файлы детали процесса и реализации.
- Следовательно, привязывать универсальный скилл `code-review/SKILL.md` к колонке в несуществующем `.agents/CONTEXT-MAP.md` нельзя. Если конкретный **Проект** хочет объявить отдельные директории или модули критическими по умолчанию, штатным местом для этого в **Шаблоне** является `CODING_STANDARDS.md`.

**Как откалибровать подпункт `2.2` в `code-review/SKILL.md`:**
- Полностью принимаем идею перевода **Adversary** из `optional (Epic & security-critical tasks only)` в **обязательный детерминированный триггер по риск-сигналам** на любом маршруте (`Minor`, `Feature`, `Epic`).
- Устраняем логическое противоречие из строки 102 входного предложения [1] (`Skip Adversary ONLY when the diff is strictly limited to pure static UI styling/copy or documentation`). Если оставить эту фразу одновременно со списком из 5 категорий риск-сигналов, агент будет обязан запускать **Adversary** даже на чистых математических утилитах, мапперах типов, шаблонах документов или рефакторинге юнит-тестов, где нет ни сети, ни процессов, ни конкурентности, ни ФС, ни авторизации.
- Вместо этого формулируем строгое двустороннее правило: **Adversary запускается в обязательном порядке**, если выполняется хотя бы одно из 3 условий (маршрут `Epic`, правило в `CODING_STANDARDS.md`, либо наличие в `git diff` любого из 5 классов риск-сигналов), и **пропускается**, если ни один из этих сигналов в диффе не присутствует.

---

#### Пункт 3: Запрет горизонтальных «тестовых тикетов» в `to-tickets/SKILL.md`

**Проверка по коду Шаблона:**
- В [to-tickets/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/to-tickets/SKILL.md#L29-L36) блок `<vertical-slice-rules>` требует:
  `- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer`.
- На практике модели часто нарушают это правило неявным образом: первые тикеты (`01..N-1`) содержат только код с формальной проверкой компиляции/типов, а все полноценные модульные и интеграционные тесты выносятся в финальный тикет `N («Написание тестов»)`.
- В режиме `Sequential Subagents` это обесценивает шаг верификации **Оркестратора** ([implement/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/implement/SKILL.md#L57)): субагенты тикетов `01..N-1` сдают код без тестов, а субагент последнего тикета вынужден загружать в контекст весь объём кода, написанный предшественниками.
- **Калибровка:** Принимаем предложенную формулировку в `<vertical-slice-rules>` практически без изменений, добавив лишь явную отсылку к уже описанному в `to-tickets/SKILL.md` (строка 40 [4]) единственному исключению — финальному интеграционному тикету при паттерне `expand–contract` с общей интеграционной веткой.

---

#### Пункт 4: Защита от потери ориентации при Compaction на границах этапов

**Проверка по коду Шаблона:**
- В рамках Спецификации 0006 [9] в [implement/SKILL.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/implement/SKILL.md#L62-L69) был добавлен блок `Compaction and session recovery`, который опирается на `.scratch/<feature>/BASE_COMMIT` и `.scratch/<feature>/TICKETS.md`.
- Этот механизм отлично работает *внутри* цикла исполнения тикетов на Этапе 4 (пока хотя бы один тикет имеет статус `ready-for-agent` или `in-progress`).
- Однако когда все тикеты переведены в `done`, наступает пограничное состояние:
  1. Агент сформировал отчёт Этапа 4 и ждёт подтверждения на **Стоп-гейте** реализации;
  2. Пользователь подтвердил переход к Этапу 5 (`/code-review`), агент прочитал `code-review/SKILL.md`, и в этот момент произошло авто-сжатие контекста (`compaction`).
- После `compaction` агент перечитывает `TICKETS.md`, видит все тикеты в статусе `done`, но не видит в `TICKETS.md`, находится ли он всё ещё на финише Этапа 4 или уже внутри Этапа 5 (`Code Review`).
- **Калибровка:**
  - Включение метаданных `**Active Stage:** ... | **Execution Strategy:** ...` в шапку [tickets-map-template.md](file:///d:/YandexDisk/MyProjects/AI/strataharness/.agents/skills/to-tickets/references/tickets-map-template.md) полностью следует принципу `minimal-diff` из Спецификации 0006 [9] (не плодить отдельные файлы состояния, хранить всё в `TICKETS.md`).
  - Чтобы этот маркер гарантированно работал на границе Этапов 4 и 5, инструкцию по его обновлению необходимо синхронно прописать в трёх местах:
    1. `tickets-map-template.md` (правило `Stage & Strategy header` в секции `## Rules` и строка в блоке шаблона `## Block`);
    2. `implement/SKILL.md` (при старте реализации ставить `Stage 4 (Implement)`, а при восстановлении после `compaction` проверять поле `Active Stage`);
    3. `code-review/SKILL.md` (в шаге 1 при наличии `.scratch/<feature>/TICKETS.md` сразу обновлять поле на `Stage 5 (Code Review)` перед запуском субагентов).

---

### 3. Готовые откалиброванные формулировки (Диффы для внедрения в Шаблон)

Ниже приведены точные изменения, готовые к переносу в **Шаблон** на маршруте **Development** (с сохранением всех инвариантов `Test-Template.ps1`, включая лимиты размера `AGENTS.md` и кавычки во frontmatter YAML).

#### 3.1. Корневой файл правил `AGENTS.md`

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -40,7 +40,7 @@
 | Route | Stages | Interview mandatory rounds |
 |---|---|---|
 | Minor | 1 → 4 (In-Place) → 5 → 6 | 1 round: Outline and happy path |
-| Feature | 1 → 2 → 3 → 4 → 5 → 6 | 2 rounds: Happy path + Errors & edge cases |
+| Feature | 1 → 2 → 3 → 4 (In-Place for 1–2 tickets; Orchestrator for ≥3) → 5 → 6 | 2 rounds: Happy path + Errors & edge cases |
 | Epic | 1 → 2 → 3 → 4 (Orchestrator) → 5 → 6 | 3 rounds: Happy path + Errors & edge cases + NFR |
 | Fog | 1 (wayfinder) → 2 → 3 → 4 → 5 → 6 | set by wayfinder |
 | Analysis | [analyze](.agents/skills/analyze/SKILL.md): interview ⛔ → work → draft in `docs/analysis/` ⛔ → close (handoff or close-task) | 1 short round: 4 points |
@@ -64,5 +64,5 @@
 ## Context budget
 
 - **Smart zone:** ≈120k tokens of working context.
-- Before writing code, propose an execution strategy — In-Place, Sequential Subagents or Multi-Session — sized against the Smart zone and the ticket graph. Criteria and the Orchestrator protocol: [implement](.agents/skills/implement/SKILL.md).
+- Before writing code (and at the Stage 3 stop gate), propose an execution strategy — **In-Place** (only for `Minor` or 1–2 tickets within ~60k tokens), **Sequential Subagents / Orchestrator** (mandatory for ≥3 tickets, or 2 tickets editing files >1,000 lines or exceeding ~60k tokens), or **Multi-Session**. Full criteria and the Orchestrator protocol: [implement](.agents/skills/implement/SKILL.md).
```

#### 3.2. Скилл декомпозиции тикетов `.agents/skills/to-tickets/SKILL.md`

```diff
--- a/.agents/skills/to-tickets/SKILL.md
+++ b/.agents/skills/to-tickets/SKILL.md
@@ -29,6 +29,7 @@
 <vertical-slice-rules>
 
 - Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer
+- **No standalone "Tests-only" or single-layer tickets:** Every ticket MUST include its own `[auto]` unit/integration test criteria so each implementer runs TDD (red → green → refactor) and proves its slice green before finishing. Never defer automated tests for Tickets `01..N-1` into a final Ticket `N` (the only exception is the final integrate-and-verify ticket of an expand–contract wide refactor when intermediate batches cannot stay green alone).
 - A completed slice is demoable or verifiable on its own
 - Each slice is sized to fit in a single fresh context window
 - Any prefactoring should be done first
@@ -130,4 +131,11 @@
 
 ### 7. Show the tickets map
 
-Show the user the published tickets map — the colour-coded Mermaid diagram (with all four `classDef` lines and `class` assignments), the legend line right below it, the table, the Rulings & Decisions section, the coverage matrix, and where they live — then stop at the tickets stop gate. Done when every published ticket appears in the map with its Status, its node colour class (`ready` or `blocked`), the legend, and all spec requirements are covered.
+Show the user the published tickets map — the header metadata (`Active Stage` and `Execution Strategy`), the colour-coded Mermaid diagram (with all four `classDef` lines and `class` assignments), the legend line right below it, the table, the Rulings & Decisions section, the coverage matrix, the proposed **Stage 4 Execution Strategy**, and where they live — then stop at the tickets stop gate.
+
+**Execution Strategy Selection Rule (must match `implement`):**
+- **In-Place:** Allowed ONLY for `Minor` or strictly **1–2 tickets** whose total forecast stays under `~60k tokens` and does not require multi-ticket edits across files `>1,000 lines`.
+- **Sequential Subagents (Orchestrator — 1 implementer subagent per ticket):** **Mandatory** whenever the breakdown has **3 or more tickets**, or **2 tickets** touching files `>1,000 lines` or exceeding `~60k tokens`, or any heavy ticket with a wide change footprint.
+- **Multi-Session:** Whenever a human check is required between milestones.
+
+Done when every published ticket appears in the map with its Status, its node colour class (`ready` or `blocked`), the legend, the Execution Strategy justification, and all spec requirements are covered.
```

#### 3.3. Шаблон карты тикетов `.agents/skills/to-tickets/references/tickets-map-template.md`

```diff
--- a/.agents/skills/to-tickets/references/tickets-map-template.md
+++ b/.agents/skills/to-tickets/references/tickets-map-template.md
@@ -10,6 +10,7 @@
 
 ## Rules
 
+- **Header metadata** — right below the spec/tickets links, record `**Active Stage:** <stage>` (`Stage 3 (Tickets)` → `Stage 4 (Implement)` → `Stage 5 (Code Review)`) and `**Execution Strategy:** <In-Place | Sequential Subagents | Multi-Session>`. Update `Active Stage` at each stage transition so post-compaction recovery always knows the active stage even after all tickets are `done`.
 - **Nodes** — one per ticket: id `T<NN>`, quoted label `"<NN> <short title>"` of at most four words.
 - **Edges** — one `T<A> --> T<B>` per blocking edge, read "A blocks B". The edges are exactly the tickets' **Blocked by** lines.
 - **Classes** — the four `classDef` lines are fixed. Each ticket gets one class, derived from its **Status** field, the source of truth:
@@ -34,6 +35,7 @@
 # <feature> — карта тикетов
 
 Спека: [`docs/specs/<NNNN>-<feature>-spec.md`](../../docs/specs/<NNNN>-<feature>-spec.md). Тикеты: [`issues/`](./issues/).
+**Active Stage:** Stage 3 (Tickets) | **Execution Strategy:** <In-Place | Sequential Subagents | Multi-Session>
 
 Стрелка `A --> B` означает «A блокирует B». Цвет узла показывает статус тикета. Источник истины по статусу — поле **Status** в файле тикета.
```

#### 3.4. Скилл реализации `.agents/skills/implement/SKILL.md`

```diff
--- a/.agents/skills/implement/SKILL.md
+++ b/.agents/skills/implement/SKILL.md
@@ -19,11 +19,12 @@
 Read the tickets and their **Blocked by** edges, and forecast the token footprint against the Smart zone (≈120k). Announce the strategy with a one-line reason before writing code.
 
 | Strategy | When | Who writes the code |
 |---|---|---|
-| In-Place | Minor route, or 1–2 tickets whose total forecast stays under ~60k tokens | you, ticket by ticket, in this thread |
-| Sequential Subagents | 3 or more tickets, or any heavy ticket (large test suite, wide change, big token footprint) | one implementer subagent per ticket; you are the Orchestrator (§4) |
+| In-Place | Minor route, or strictly 1–2 tickets whose total forecast stays under ~60k tokens without multi-ticket edits on files >1,000 lines | you, ticket by ticket, in this thread |
+| Sequential Subagents | **Mandatory** for 3 or more tickets, 2 tickets editing files >1,000 lines, or any heavy ticket (large test suite, wide change, >60k token footprint) | one implementer subagent per ticket; you are the Orchestrator (§4) |
 | Multi-Session | a human must check the result between milestones | split the work into milestones, one session each, with the user's `/handoff` between them; each session picks In-Place or Sequential Subagents for its milestone |
 
 Multi-Session wins whenever a human check is needed; otherwise take the first row that matches.
+**Hard override:** If the task has **3 or more tickets** (or 2 tickets touching files `>1,000 lines` / exceeding `~60k tokens`), you MUST execute via **Sequential Subagents** (or Multi-Session) — never `In-Place`, even if `In-Place` was tentatively discussed in an earlier stage. Update `**Active Stage:** Stage 4 (Implement)` and `**Execution Strategy:**` in `.scratch/<feature>/TICKETS.md` when starting Stage 4.
 
 ## 3. Rules for whoever writes the code
@@ -62,7 +63,7 @@
 **Compaction and session recovery.** If the conversation is compacted or restarted mid-run:
-1. Re-read `.scratch/<feature>/BASE_COMMIT`, `.scratch/<feature>/TICKETS.md` (including `## Rulings & Decisions`), and inspect the working tree (`git status`, `git diff`).
+1. Re-read `.scratch/<feature>/BASE_COMMIT`, `.scratch/<feature>/TICKETS.md` (including `**Active Stage:**` and `## Rulings & Decisions`), and inspect the working tree (`git status`, `git diff`). If `Active Stage` is already `Stage 5 (Code Review)`, resume `/code-review` rather than re-running Stage 4.
 2. Tickets marked `done` are settled and never re-dispatched.
```

#### 3.5. Скилл код-ревью `.agents/skills/code-review/SKILL.md`

```diff
--- a/.agents/skills/code-review/SKILL.md
+++ b/.agents/skills/code-review/SKILL.md
@@ -1,16 +1,16 @@
 ---
 name: code-review
-description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two core axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?) — plus an optional third axis: Adversary (presumption of failure) on Epic or high-risk tasks. Runs reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to 'review since X'."
+description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two core axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?) — plus a third axis: Adversary (presumption of failure), mandatory on Epic or whenever diff risk signals match. Runs reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to 'review since X'."
 ---
 
 Review of the changes between a fixed point and the working tree along two core axes, plus a third axis triggered on risk signals:
 
 - **Standards** — does the code conform to this repo's documented coding standards?
 - **Spec** — does the code faithfully implement the originating issue / spec?
-- **Adversary** (optional, for Epic or high-risk tasks) — attacks the solution under a presumption of failure (race conditions, boundary breaches, unauthorized access, data loss).
+- **Adversary** (mandatory whenever route or diff risk signals match §4) — attacks the solution under a presumption of failure (race conditions, boundary breaches, unauthorized access, data loss).
 
 The axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.
@@ -20,6 +20,8 @@
 ### 1. Pin the fixed point
 
+If `.scratch/<feature>/TICKETS.md` exists, update its header to `**Active Stage:** Stage 5 (Code Review)` before spawning review sub-agents so post-compaction recovery knows Stage 5 is active.
+
 The fixed point defaults to the commit in `.scratch/<feature>/BASE_COMMIT`, recorded by `/implement` when the work started; `<feature>` is the feature under review in this conversation. A fixed point the user names — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. — takes precedence. If there is neither, ask for it.
@@ -90,5 +92,13 @@
-**Adversary sub-agent (Epic & security-critical tasks only)**:
-For tasks on the Epic route, or changes modifying authentication, permissions, data migrations, or concurrent resources, spawn a third parallel sub-agent: **Adversary**.
+**Adversary sub-agent (Mandatory on Risk Signals — across Minor, Feature, and Epic)**:
+Spawn the third parallel sub-agent **Adversary** whenever ANY of the following holds:
+1. **Route:** The task is on the `Epic` route;
+2. **Repo standards:** The target module or directory is marked as requiring adversary/security review in `CODING_STANDARDS.md`;
+3. **Diff risk signals:** The change set (`git diff <base>` or new files) touches ANY of:
+   - Process, shell, or external command execution (`exec`, `spawn`, PowerShell, bash, SSH, `eval`);
+   - Network I/O, HTTP/REST/RPC handlers, WebSockets, IPC, or external API clients;
+   - Concurrency, async coordination (`Promise.all*`, workers, threads), locks/mutexes, queues, timers/polling, or shared state/caches;
+   - Authentication, authorization (RBAC/permissions/ACL), sessions, secrets, or environment config;
+   - File-system paths/traversal, symlinks/junctions, state persistence, or database migrations/writes.
+Skip `Adversary` only when none of the above signals apply (e.g., pure documentation, static UI/styling, isolated pure functions/types, or test-only refactors).
 - Brief: "Act as an independent adversary with a presumption of failure. Examine the diff to identify up to 3 concrete failure scenarios: race conditions, unhandled failure/boundary states, resource exhaustion, authorization bypasses, or silent data loss. Quote file and line for each scenario. Do NOT run the repository test suite or build pipelines — your role is static failure scenario and risk analysis against the diff only. Under 400 words."
```

---

## Источники

1. Входное предложение из дочернего проекта: `d:\YandexDisk\AWG\phygital\.scratch\STRATAHARNESS_UPSTREAM_PROPOSAL.md`.
2. Корневые правила агента **Шаблона**: [`AGENTS.md`](../../AGENTS.md).
3. Глоссарий **Шаблона**: [`.agents/CONTEXT.md`](../../.agents/CONTEXT.md).
4. Скилл декомпозиции тикетов: [`.agents/skills/to-tickets/SKILL.md`](../../.agents/skills/to-tickets/SKILL.md).
5. Шаблон карты тикетов: [`.agents/skills/to-tickets/references/tickets-map-template.md`](../../.agents/skills/to-tickets/references/tickets-map-template.md).
6. Скилл реализации и протокол **Оркестратора**: [`.agents/skills/implement/SKILL.md`](../../.agents/skills/implement/SKILL.md).
7. Скилл код-ревью и оси **Adversary**: [`.agents/skills/code-review/SKILL.md`](../../.agents/skills/code-review/SKILL.md).
8. Handoff предыдущего бэкпорта из `phygital`: [`docs/handoff/2026-10-22-retro-core-improvements.md`](../handoff/2026-10-22-retro-core-improvements.md).
9. Спецификация 0006 (консолидация состояния в `TICKETS.md`, фильтрация ревью, лимиты валидатора): [`docs/specs/0006-analogs-p1-improvements-spec.md`](../specs/0006-analogs-p1-improvements-spec.md).
10. Кастомная карта модулей монорепозитория `phygital`: `d:\YandexDisk\AWG\phygital\.agents\CONTEXT-MAP.md`.
11. Правила доменной документации **Шаблона**: [`docs/agents/domain.md`](../agents/domain.md).
12. Скилл доменного моделирования и формат контекстов: [`.agents/skills/domain-modeling/SKILL.md`](../../.agents/skills/domain-modeling/SKILL.md) и [`.agents/skills/domain-modeling/CONTEXT-FORMAT.md`](../../.agents/skills/domain-modeling/CONTEXT-FORMAT.md).
13. Скрипт валидации инвариантов **Шаблона**: [`.agents/scripts/Test-Template.ps1`](../../.agents/scripts/Test-Template.ps1).

## Ограничения

- **Область проверки:** Аудит опирается на статический анализ правил и шаблонов в репозитории `StrataHarness` (`v1.4.3`) и артефактов в `d:\YandexDisk\AWG\phygital`. Полные транскрипты диалогов сессий в проекте `phygital` не анализировались, так как корневые причины в `STRATAHARNESS_UPSTREAM_PROPOSAL.md` [1] однозначно верифицируются по тексту текущих `SKILL.md` и `AGENTS.md`.
- **Допущения:** Предполагается, что бюджет `Smart zone ≈ 120k tokens` остаётся базовым ориентиром для всех поддерживаемых харнесов (Antigravity, Claude Code, Codex, Cursor), а порог `~60k tokens` (1–2 тикета) оставляет достаточный запас контекста для прохождения Этапа 5 (`/code-review`) без принудительного сжатия.
- **Уверенность в выводах:** Высокая. Все расхождения между предложением и устройством **Шаблона** (в частности, отсутствие `.agents/CONTEXT-MAP.md` в апстриме и наличие таблицы выбора стратегии в `implement/SKILL.md`) проверены напрямую по файловой системе и скрипту `Test-Template.ps1` [13] (текущий размер `AGENTS.md` — `8 922 / 24 000` байт, сумма `AGENTS.md + CONTEXT.md` — `15 123 / 32 768` байт, запас по бюджету более чем двукратный).
- **Что может изменить выводы:** Если в будущем в **Шаблон** будет официально введён режим монорепозитория с табличным реестром пакетов/сабмодулей (отличным от DDD-карты в `domain-modeling`), концепция колонки `Review Profile` из пункта `2.1` может быть пересмотрена.
