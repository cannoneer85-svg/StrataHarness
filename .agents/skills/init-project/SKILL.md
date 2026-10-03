---
name: init-project
description: Initialize a new project from the Template (New), adopt it into an existing repository, or update an existing project; configure the issue tracker.
disable-model-invocation: true
---

# Initialize Project

Manage the lifecycle of a Project derived from this Template. Run this skill only on explicit user invocation (`/init-project`).

## Modes

1. **New** — Transform a fresh copy of the Template into a clean Project. Cleans template development metadata, installs clean project skeletons, updates registry version and source, synchronizes Claude skills, and runs interactive post-scaffold setup.
2. **Adopt** — Copy the payload into an existing repository without overwriting existing files, reporting conflicts, appending missing `.gitignore` entries, and guiding conflict resolution.
3. **Update** — Inspect payload changes from the upstream Template source (added, modified, removed, and conflicts), apply updates with confirmation, and bump `template-version` while safely preserving local project modifications.
4. **Configure Tracker** — Reconfigure or switch the issue tracker in an existing Project without touching other files.

---

## Mode 1: New Project

Run this mode once immediately after creating a new repository from the Template.

### Step 1: Run the initialization script

Execute the deterministic initialization script:

```powershell
pwsh -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode New
```

The script performs:
- Cleans template metadata (`docs/specs/*`, `docs/adr/*`, `docs/handoff/*`, `docs/analysis/*`, `docs/research/*`, `tests/`).
- Installs fresh skeletons defined in `manifest.psd1` (`.agents/CONTEXT.md`, `docs/handoff/LATEST.md`, `README.md`, `CODING_STANDARDS.md`).
- Updates `template-version` and `template-source` in `.agents/SKILLS.md`.
- Invokes `.agents/scripts/Sync-ClaudeSkills.ps1` to populate `.claude/skills/`.
- Runs `.agents/scripts/Test-Template.ps1` to confirm repository consistency.

### Step 2: Interactive Issue Tracker Setup

Guide the user through configuring their issue tracker.

#### Section A: Choose tracker

Ask the user where issues will be tracked:
- **GitHub** — Uses the `gh` CLI. Copy `templates/issue-tracker-github.md` to `docs/agents/issue-tracker.md`.
- **GitLab** — Uses the `glab` CLI. Copy `templates/issue-tracker-gitlab.md` to `docs/agents/issue-tracker.md`.
- **Local Markdown** — Issues tracked under `.scratch/<feature>/issues/`. Copy `templates/issue-tracker-local.md` to `docs/agents/issue-tracker.md`.
- **Other** (Jira, Linear, etc.) — Ask the user for a brief summary and document it in `docs/agents/issue-tracker.md`.

Default recommendation:
- If `git remote -v` points to GitHub, recommend GitHub.
- If `git remote -v` points to GitLab, recommend GitLab.
- Otherwise, recommend Local Markdown.

#### Section B: Triage labels

If the `triage` skill is present in `.agents/skills/`:
- Ask if the user wants the five canonical triage roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).
- Copy `templates/triage-labels.md` to `docs/agents/triage-labels.md`, customizing labels if the user provides custom mapping.

If `triage` is not installed, omit `docs/agents/triage-labels.md`.

#### Section C: Domain docs layout

Default to **single-context** (`.agents/CONTEXT.md` + `docs/adr/`). Copy `templates/domain.md` to `docs/agents/domain.md`.
If the repository has monorepo markers (`pnpm-workspace.yaml`, nested packages), offer multi-context (`CONTEXT-MAP.md`).

#### Section D: Update AGENTS.md rules

Update the `## Agent skills` section in `AGENTS.md` (and `CLAUDE.md` if separate):

```markdown
## Agent skills

### Issue tracker

[One-line summary of tracker]. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

Five canonical roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

Single-context: one glossary plus ADRs. See [`docs/agents/domain.md`](docs/agents/domain.md).
```

### Step 3: Define Technology Stack

Prompt the user to specify their project stack:
- Programming language and runtime environment
- Core frameworks and libraries
- Database or storage layer
- Test runner and linter

Record these details in `.agents/CONTEXT.md` under the `## Стек технологий` heading.

### Step 4: Customize Coding Standards

Present `CODING_STANDARDS.md` to the user and prompt for team-specific conventions:
- Formatting rules and style guides
- Linter and typechecker commands
- Architectural constraints or layer isolation boundaries

Save the agreed conventions into `CODING_STANDARDS.md`.

### Completion Criteria

- `Initialize-Project.ps1` completed with exit code 0.
- `docs/agents/issue-tracker.md`, `domain.md`, and (if triage present) `triage-labels.md` exist and match user choice.
- `## Agent skills` section in `AGENTS.md` reflects configured tracker.
- `.agents/CONTEXT.md` contains the configured technology stack.
- `CODING_STANDARDS.md` contains initial team rules.
- `.agents/scripts/Test-Template.ps1` exits 0.

---

## Mode 2: Adopt into Existing Repository

Use this mode to install the Template's workflow, agents, and skills into an existing repository without overwriting existing files.

### Step 1: Run Adopt mode

Execute the deterministic initialization script, pointing `-TemplateSource` to the root of the Template:

```powershell
pwsh -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Adopt -TemplateSource <path-to-template>
```

The script performs:
- Copies payload files and directories defined in `manifest.psd1` (`.agents/`, `AGENTS.md`, `CLAUDE.md`, `docs/agents/`, `.gitattributes`, directory skeletons `docs/{adr,specs,handoff,analysis}/`).
- **Never overwrites existing files.** If a destination file exists with differing content, it is detected and reported as a conflict.
- Appends missing entries from `manifest.GitIgnoreEntries` (`.claude/skills/`, `.scratch/`) to `.gitignore` without duplicating existing lines.
- Excludes all Meta files (`tests/`, `docs/specs/*`, `docs/adr/*`, `docs/handoff/*`, `docs/analysis/*`, `docs/research/*`).
- Places `.agents/CONTEXT.md` and `docs/handoff/LATEST.md` from skeletons only if they do not already exist in the target repository.
- Updates `template-version` and `template-source` in `.agents/SKILLS.md`.
- Invokes `.agents/scripts/Sync-ClaudeSkills.ps1` and validates with `.agents/scripts/Test-Template.ps1`.
- Safe to re-run; repeat runs are idempotent.

### Step 2: Conflict Resolution Walkthrough

Review the conflicts reported by the script. For each conflict:
1. **`AGENTS.md`**: The existing file was preserved. Present the differences to the user. Walk the user through integrating Step 0 routing, stage definitions, and invariants from the Template into their existing `AGENTS.md`. If the user wants to replace their file with the Template's version, copy it explicitly.
2. **Other conflicting files**: Show the diff between the target repository's version and the Template's version. Prompt the user to decide whether to keep the existing version, replace with the Template version, or merge manually.

### Step 3: Tracker and Context Configuration

1. If the repository does not have a configured issue tracker, run **Step 2: Interactive Issue Tracker Setup** (or run `Initialize-Project.ps1 -Mode SetTracker -Tracker <github|gitlab|local>`).
2. If `.agents/CONTEXT.md` was freshly created, guide the user through defining the technology stack (**Step 3**).
3. If `CODING_STANDARDS.md` was created, prompt the user for team conventions (**Step 4**).

### Completion Criteria

- `Initialize-Project.ps1 -Mode Adopt` completed with exit code 0.
- All conflicts reported by the script were reviewed and resolved with the user.
- Pre-existing project source code, configurations, and documentation remain intact.
- `.gitignore` contains required template entries without duplicates.
- `.agents/scripts/Test-Template.ps1` exits 0.

---

## Mode 3: Update Existing Project from Template

Use this mode to bring updates and improvements from the upstream Template into an already initialized Project without overwriting local customizations.

### Step 1: Inspect Changes (Dry Run)

Run the script in Update mode without `-Apply` to inspect changes:

```powershell
pwsh -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Update
```

The script determines the Template source from `-TemplateSource` parameter, or parses `template-source:` from `.agents/SKILLS.md`. It compares the target Project's payload against the upstream Template payload and categorizes every file:
- **`Added in Template`**: New file added upstream, missing in target project.
- **`Modified in Template`**: File updated upstream, unchanged in target project since adoption.
- **`Removed in Template`**: File was present in base template version but removed upstream.
- **`Conflict: modified locally`**: File modified locally in target project (differs from both base template and upstream template, or base version is unavailable for non-git sources).

In dry-run mode, the repository remains completely untouched.

### Step 2: Review and Confirm Changes

Present the categorized change list to the user:
1. Walk through the list of additions, modifications, and removals.
2. If conflicts were detected, inspect diffs against upstream using `git diff` or file comparison and ask the user how to handle each conflicting file:
   - **Keep local**: Leave the local customization untouched (default safe behavior).
   - **Accept upstream**: Replace the local version with the upstream version.
   - **Merge**: Manually integrate upstream improvements into the local file.

### Step 3: Apply Updates

Apply the approved changes:

```powershell
# Apply all non-conflicting updates
pwsh -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Update -Apply

# Or apply only specific files
pwsh -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode Update -Apply -Files 'AGENTS.md', '.agents/skills/init-project/SKILL.md'
```

With `-Apply`, the script:
- Copies non-conflicting additions and modifications from the Template.
- Removes deleted template payload files.
- Skips conflicting locally modified files with a warning, preserving local code.
- Updates `template-version` in `.agents/SKILLS.md` to the upstream Template version/SHA.
- Runs `.agents/scripts/Sync-ClaudeSkills.ps1` to mirror updated skills to `.claude/skills/`.
- Executes `.agents/scripts/Test-Template.ps1` to validate consistency.

### Step 4: Resolve Any Deferred Conflicts

If the user agreed to overwrite or merge specific conflicting files in Step 2:
- Copy or manually merge the agreed files from the Template source.
- Update `.agents/SKILLS.md` if custom skills or descriptions were adjusted.
- Re-run `Sync-ClaudeSkills.ps1` if `.agents/skills/` was modified.

### Step 5: Validate Consistency

Verify that repository integrity is preserved:

```powershell
pwsh -File .agents/scripts/Test-Template.ps1
```

### Completion Criteria

- `Initialize-Project.ps1 -Mode Update -Apply` completed with exit code 0.
- Approved template improvements applied to the project.
- Locally modified files preserved or resolved deliberately.
- `template-version` in `.agents/SKILLS.md` updated to current template version.
- Claude skills mirror `.claude/skills/` synchronized with `.agents/skills/`.
- `.agents/scripts/Test-Template.ps1` exits 0.

---

## Mode 4: Standalone Tracker Reconfiguration

When switching or reconfiguring the issue tracker in an existing project (e.g. migrating from Local Markdown to GitHub):

### Step 1: Execute tracker reconfiguration

Run the tracker reconfiguration operation:

```powershell
pwsh -File .agents/skills/init-project/scripts/Initialize-Project.ps1 -Mode SetTracker -Tracker <github|gitlab|local>
```

This operation:
- Copies the tracker specification (`templates/issue-tracker-<tracker>.md`) to `docs/agents/issue-tracker.md`.
- Updates the `### Issue tracker` block under `## Agent skills` in `AGENTS.md`.
- Touches **no other files** in the repository.

### Step 2: Validate Consistency

Verify that repository links remain consistent:

```powershell
pwsh -File .agents/scripts/Test-Template.ps1
```

### Completion Criteria

- `docs/agents/issue-tracker.md` matches the selected tracker template.
- `AGENTS.md` issue tracker block references the selected tracker.
- No other repository files were modified.
- `Test-Template.ps1` exits 0.

