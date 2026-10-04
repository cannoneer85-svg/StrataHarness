## Description

<!-- Provide a brief summary of the changes made in this pull request. -->

## Type of Change

- [ ] `fix`: Bug fix (non-breaking change which fixes an issue)
- [ ] `feat`: New feature (non-breaking change which adds functionality)
- [ ] `feat!`: Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] `docs`: Documentation updates
- [ ] `refactor`: Code refactoring without functionality changes
- [ ] `test`: Adding or updating tests
- [ ] `ci`: CI configuration changes
- [ ] `chore`: Maintenance, dependencies, or tooling changes

## Checklist

- [ ] Pull request title follows [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat(scope): description`, `fix: description`)
- [ ] Template validation passes:
  ```powershell
  pwsh -NoProfile -File .agents/scripts/Test-Template.ps1
  ```
- [ ] Pester test suite passes:
  ```powershell
  pwsh -NoProfile -Command "Invoke-Pester -Path tests -Output Detailed"
  ```
- [ ] If skills under `.agents/skills/` were added, removed, or modified:
  - [ ] Updated the Skill Registry in `.agents/SKILLS.md`
  - [ ] Ran synchronization script:
    ```powershell
    pwsh -NoProfile -File .agents/scripts/Sync-ClaudeSkills.ps1
    ```
- [ ] Public documentation updated (if applicable)
