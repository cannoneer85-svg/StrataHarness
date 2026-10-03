---
status: accepted
date: 2026-10-03
---

# Плоские скиллы в `.agents/skills` и генерируемое зеркало для Claude Code

Шаблон должен работать в Antigravity, Claude Code, Codex и Cursor. Antigravity, Codex и Cursor читают `.agents/skills/`, Claude Code — только `.claude/skills/`. Antigravity сканирует папку на один уровень. Поэтому скиллы лежат **плоско** в `.agents/skills/<name>/` — это единственный источник истины. Для Claude Code скрипт на PowerShell 7 копирует их в `.claude/skills/`. Копия в `.gitignore` и пересоздаётся при каждом запуске `/init-project`. Категории скиллов задаются в Реестре (`.agents/SKILLS.md`), а не папками.

## Considered Options

- **Папки-категории** (`skills/engineering/...`, как в исходниках Matt Pocock). Отклонено: Antigravity и, вероятно, Claude Code их не находят. У Matt это структура для распространения, а не та папка, которую читает агент.
- **Симлинки на каждый скилл.** Отклонено: на Windows нужны Developer Mode и `core.symlinks`, иначе git создаёт текстовые файлы вместо ссылок.
- **Claude-плагин со списком путей.** Отклонено: нужна установка через marketplace, а для одного разработчика в своих проектах это лишний шаг.

## Consequences

- Cursor читает и `.agents/skills`, и `.claude/skills`, поэтому возможны дубли. Это проверяется на пробном прогоне.
- После клонирования Проекта Claude Code не видит скиллы, пока не запущен `/init-project` или скрипт синхронизации.
