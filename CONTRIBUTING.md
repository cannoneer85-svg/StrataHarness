# Contributing to StrataHarness

Thank you for your interest in contributing to the AI Agent Template project! We welcome contributions, bug reports, and suggestions.

Please take a moment to review this document before submitting contributions.

---

## Code of Conduct & Etiquette

- Be respectful and constructive in all discussions, issues, and pull requests.
- Focus on clear technical arguments, reproducible examples, and verifiable behavior.

---

## Development & PR Workflow

1. **Fork and Branch:**
   - Fork the repository on GitHub.
   - Create a feature or bugfix branch from `main` (e.g. `feat/new-skill` or `fix/path-normalization`).
2. **Make Changes:**
   - Adhere to the project standards and cross-platform PowerShell conventions (PowerShell 7+, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`).
   - If adding or updating skills, follow the instructions below.
3. **Verify Locally:**
   - Run the validation and test suite before submitting:
     ```powershell
     # 1. Template integrity validation (must print OK and exit 0)
     pwsh -NoProfile -File .agents/scripts/Test-Template.ps1

     # 2. Pester test suite (all tests must pass)
     pwsh -NoProfile -Command "Invoke-Pester -Path tests -Output Detailed"
     ```
4. **Submit Pull Request:**
   - Open a PR against `main`.
   - Fill out all sections in the [PR template](.github/PULL_REQUEST_TEMPLATE.md).

---

## Pull Request Requirements

Every pull request must satisfy the following checklist:

1. **Conventional Commits:**
   - The **Pull Request title** MUST follow [Conventional Commits](https://www.conventionalcommits.org/):
     ```text
     <type>[optional scope]: <description>
     ```
   - Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
   - Breaking changes must use `!` after the type/scope (e.g. `feat!: breaking change` or `feat(init)!: breaking change`).
   - PR titles are verified by automated CI checks.
2. **GitHub Merge Policy:**
   - We use **Squash and merge** exclusively on GitHub.
   - The squash commit message defaults to the PR title. This ensures that every merged PR lands cleanly into the commit history and directly feeds our release changelog generator.
3. **Skill Changes:**
   - If any skill under `.agents/skills/` is added, renamed, modified, or removed:
     - Update the Skill Registry in [`.agents/SKILLS.md`](.agents/SKILLS.md) in the same change.
     - Synchronize the Claude Code mirror:
       ```powershell
       pwsh -NoProfile -File .agents/scripts/Sync-ClaudeSkills.ps1
       ```
     - Run `.agents/scripts/Test-Template.ps1` to ensure all frontmatter, flags, and mirror files are consistent.
4. **Tests:**
   - All tests in `tests/` must pass on both Windows and Ubuntu runners in GitHub Actions CI.

---

## Language Rules

Our repository maintains a deliberate bilingual convention documented in [`AGENTS.md`](AGENTS.md):

- **English (Public Layer):**
  - Public facing files: [`README.md`](README.md), [`CHANGELOG.md`](CHANGELOG.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md), [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md), [`LICENSE`](LICENSE), `.github/**`, [`docs/releasing.md`](docs/releasing.md).
  - All git commit messages, branch names, and PR titles/descriptions.
  - Agent-facing operational instructions (`AGENTS.md`, `SKILL.md` files, PowerShell script comments).
- **Russian (Internal Human Documents):**
  - Project specifications in `docs/specs/`.
  - Architecture Decision Records (ADRs) in `docs/adr/`.
  - Task tickets in `.scratch/<feature>/issues/` and `TICKETS.md`.
  - Session handoffs in `docs/handoff/`.
  - Skill Registry notes in [`.agents/SKILLS.md`](.agents/SKILLS.md) and glossary in [`.agents/CONTEXT.md`](.agents/CONTEXT.md).
  - Russian README translation in [`README.ru.md`](README.ru.md).

---

## Reporting Issues & Vulnerabilities

- **Bug Reports:** Open an issue using the [Bug Report](https://github.com/cannoneer85-svg/StrataHarness/issues/new?template=bug.yml) template.
- **Feature Requests:** Open an issue using the [Feature Request](https://github.com/cannoneer85-svg/StrataHarness/issues/new?template=feature.yml) template.
- **Security Vulnerabilities:** Do **NOT** report security issues via public GitHub issues. Please follow the instructions in [`SECURITY.md`](SECURITY.md) to report privately.
