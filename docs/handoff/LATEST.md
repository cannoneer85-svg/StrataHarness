<!-- Copy of 2026-10-14-skills-backport.md -->
# Handoff: Бэкпорт точечных улучшений и адаптация скиллов retro и pr из mattpocock/skills

- **Дата:** 2026-10-14
- **Тип задачи:** Разработка (`Development`, Feature)
- **Статус:** Закрыта (`/close-task`)

## Состояние

- **Цель:** Перенос проверенных практикой багфиксов и адаптация новых скиллов `retro` и `pr` из репозитория `mattpocock/skills` (по состоянию на коммит `49dd158` / `v1.3.1`) на основании аналитического отчета [`docs/analysis/2026-10-14-mattpocock-skills-audit.md`](../analysis/2026-10-14-mattpocock-skills-audit.md).
- **Спецификация:** [`docs/specs/0005-skills-backport-spec.md`](../specs/0005-skills-backport-spec.md).
- **Выполненные работы:**
  1. **Рантайм-мастер (`wizard`):** В [`.agents/skills/wizard/template.sh`](../../.agents/skills/wizard/template.sh) и `SKILL.md` исправлено 10 подтвержденных рантайм-дефектов: навигация стрелками и Readline (`read -e`), экранирование спецсимволов и кавычек в `.env`, немедленная инициализация `$key`, сохранение прав и симлинков при записи `.env`, выход по EOF (Ctrl+D), фоллбэк очистки терминала, защитная обертка `run_wizard "$@"; exit` и строгие Unix LF line endings.
  2. **Шаблоны трекеров и лейблы (`init-project`):** В [`.agents/skills/init-project/templates/issue-tracker-github.md`](../../.agents/skills/init-project/templates/issue-tracker-github.md) заменен падающий `gh pr list --json ... authorAssociation` на пагинированный вызов `gh api .../pulls`, добавлены команды чтения issue с полным набором JSON-полей и поддержка `sub-issue`. В `issue-tracker-gitlab.md` исправлен флаг на `-O json` и плейсхолдер `<child-iid>`. В `init-project/SKILL.md` добавлен шаг создания отсутствующих триаж-лейблов через `gh label create` / `glab label create`.
  3. **Защитные правила в существующих скиллах:**
     - В [`claude-handoff`](../../.agents/skills/claude-handoff/SKILL.md) устранена уязвимость шелл-интерполяции при вызове `claude --bg` за счет передачи саммари через временный файл `-- "$(cat <file>)"`.
     - В [`teach`](../../.agents/skills/teach/SKILL.md) зафиксирована привязка путей к текущему рабочему каталогу запуска и вариативность позиций правильного ответа в тестах.
     - В [`diagnosing-bugs`](../../.agents/skills/diagnosing-bugs/SKILL.md) добавлена проверка мутации через `diff` перед признанием красного теста надежным.
     - В [`tdd`](../../.agents/skills/tdd/SKILL.md) введено требование однострочной фиксации компромиссов («что ловит и что пропускает») для предлагаемых швов.
     - В [`grilling`](../../.agents/skills/grilling/SKILL.md) внедрен разделитель `---` и формулировка вопросов под согласие «да».
     - В [`wayfinder`](../../.agents/skills/wayfinder/SKILL.md) добавлены правила защиты от галлюцинаций с трекером (запрет `ready-for-agent` на картах, кросс-ссылки с реальными ID, запрет PR из research-веток).
     - Точечные уточнения внесены в `to-tickets`, `implement`, `ask`, `wait-what`.
  4. **Новые скиллы:**
     - Создан скилл [`.agents/skills/retro/SKILL.md`](../../.agents/skills/retro/SKILL.md) для сессионной рефлексии по 7 категориям трения, с жестким приоритетом детерминированных проверок над расплывчатыми правилами в стандартах, защитой системного ядра `AGENTS.md` и интерактивным согласованием изменений.
     - Создан скилл [`.agents/skills/pr/SKILL.md`](../../.agents/skills/pr/SKILL.md) для формирования лаконичного описания Pull Request (Show-Me, Before/After Evidence, One-way/Two-way Door + Blast Radius) со строгим запретом на несогласованный `git push`.
  5. **Метаданные и Реестр:**
     - Скиллы зарегистрированы в [`.agents/SKILLS.md`](../../.agents/SKILLS.md) (общее число скиллов — 41), обновлен [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md) (35 адаптированных скиллов со ссылкой на коммит `49dd158`).
     - Маршруты интегрированы в [`ask/SKILL.md`](../../.agents/skills/ask/SKILL.md), а также предложены в качестве шагов улучшения окружения в `code-review` и `close-task`.
  6. **Ретроспектива и автоматизация окружения:**
     - В валидатор [`.agents/scripts/Test-Template.ps1`](../../.agents/scripts/Test-Template.ps1) добавлено **Правило 10**: обязательный контроль Unix LF line endings и синтаксиса `bash -n` для всех `.sh`-файлов в `.agents/`.
     - В [`.agents/skills/implement/references/brief-template.md`](../../.agents/skills/implement/references/brief-template.md) добавлена явная подсказка по разделению быстрых тестов (< 5с) и тяжелых интеграционных наборов.
     - В шаблоны трекеров добавлены поясняющие комментарии для исключения путаницы с локальным трекером репозитория.

## Открытые тикеты

none

## Следующий шаг

При необходимости публикации обновлений — запустить команду выпуска релиза Шаблона [`/release`](../../.agents/skills/release/SKILL.md).

## Рекомендуемые скиллы

- [`release`](../../.agents/skills/release/SKILL.md) — процедура выпуска новой версии Шаблона.
- [`retro`](../../.agents/skills/retro/SKILL.md) — ретроспектива сессий для непрерывного улучшения окружения агента.
- [`ask`](../../.agents/skills/ask/SKILL.md) — выбор подходящего процесса или скилла для новой задачи.
