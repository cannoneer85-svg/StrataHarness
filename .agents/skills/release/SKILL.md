---
name: release
description: Release a new version of the Template — SemVer calculation from commits, release notes draft, stop gate, commit, tag, and push.
disable-model-invocation: true
---

# Release

Release a new version of the Template: calculate the next version from Conventional Commits, prepare release notes, present them at a stop gate for owner confirmation, create the release commit and annotated tag, and atomically push to GitHub (ADR 0005, spec 0002 D5).

Run only on the repository owner's explicit command, such as `/release` or «выпускай релиз». Force-push (`--force`, `--force-with-lease`) is strictly prohibited under all circumstances.

The release machinery is for the Template only; `Initialize-Project.ps1` does not copy the `release` skill into downstream Projects.

## Workflow

### 1. Plan

Run the release script in `-Plan` mode:

```powershell
pwsh -NoProfile -File .agents/skills/release/scripts/Invoke-Release.ps1 -Plan
```

Options:
- `-Bump <major|minor|patch>` — override the calculated bump.
- `-Version <X.Y.Z>` — set an exact target version.
- `-SkipChecks` — bypass P3 precondition (used in automated tests).

The script verifies preconditions:
- **P1**: Working tree is clean.
- **P2**: Current branch is `main`.
- **P3**: `Test-Template.ps1` and Pester tests pass.
- **P4**: Commits exist since the previous tag (or since repository root for first release).
- **P5**: Target tag `vX.Y.Z` does not already exist.

Outputs written to `.scratch/release/`:
- `plan.json`: Machine-readable release plan including target version, previous tag, commit classifications, warnings, and MAJOR candidate flags.
- `notes.draft.md`: Draft release notes grouped by section (`Breaking`, `Added`, `Changed`, `Fixed`, `Removed`, `Other`).

Tracked files and git history remain untouched during `-Plan`.

### 2. Notes Editing

Read `.scratch/release/notes.draft.md` and `plan.json`:
- Rewrite raw commit messages into clear, human-readable English prose.
- Keep every meaningful change without losing items.
- Propose a concise release title in English (e.g. `Release skill pushes after confirmation`).
- Ensure non-conventional commits in `Other` are accurately documented or accounted for.
- Save the finalized notes (e.g. updating `.scratch/release/notes.draft.md` or a dedicated notes file).

### 3. Stop Gate

Present the proposed release to the user at the stop gate:
- Target version and tag (e.g. `1.1.0` / `v1.1.0`).
- Proposed release title.
- Edited release notes.
- Flags and warnings:
  - MAJOR candidate flags (e.g. removed or renamed skill folders).
  - Non-conventional commits.

Wait for the owner's explicit confirmation or requested adjustments before proceeding. Do NOT run `-Apply` until the user explicitly approves.

### 4. Apply

After explicit approval:

```powershell
pwsh -NoProfile -File .agents/skills/release/scripts/Invoke-Release.ps1 -Apply -NotesFile .scratch/release/notes.draft.md -Title "<Title>"
```

The script:
1. Re-verifies preconditions (P1–P3, P5) and checks that HEAD has not changed since the plan.
2. Checks that local `main` is not behind `origin/main` (P6).
3. Updates `VERSION`, prepends the new release section to `CHANGELOG.md`, and updates `template-version` in `.agents/SKILLS.md`.
4. Creates a single release commit `chore(release): vX.Y.Z`.
5. Creates an annotated tag `vX.Y.Z` with the release title.
6. Pushes `main` and the tag atomically to `origin` (`git push --atomic origin main vX.Y.Z`).

#### Agent Report
After `-Apply` completes, report the outcome to the user:
- Release commit SHA and target tag (`vX.Y.Z`).
- Push status (atomic push to `origin` confirmed, or local release created if remote is not configured).
- Link to GitHub Actions: `https://github.com/cannoneer85-svg/StrataHarness/actions`.

### 5. Recovery

- **Push failure (`-PushOnly`)**: If the atomic push fails (e.g. transient network issue or remote rejection), the local release commit and tag remain intact. Retry push with:
  ```powershell
  pwsh -NoProfile -File .agents/skills/release/scripts/Invoke-Release.ps1 -Apply -PushOnly
  ```
- **Local rollback (`-Undo`)**: To abort an unpushed release (HEAD is the release commit, tag not present on `origin`):
  ```powershell
  pwsh -NoProfile -File .agents/skills/release/scripts/Invoke-Release.ps1 -Undo
  ```
  The script removes the local tag and rolls back the release commit from HEAD. It refuses to undo if the tag already exists on remote `origin` or if HEAD is not a release commit.
- **Force-push forbidden**: Force-push (`--force`, `--force-with-lease`) is strictly forbidden under all circumstances. If an already-pushed release requires changes or corrections, release a new follow-up PATCH version.
- **Notes extraction**: GitHub Actions workflow extracts release notes and title for the tag via:
  ```powershell
  pwsh -NoProfile -File .agents/skills/release/scripts/Invoke-Release.ps1 -Notes $tag
  ```
