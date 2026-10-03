# Manifest of template files, meta cleanup targets, and reset skeletons.
# Spec: 0001-template-v2-spec.md §14.

@{
    # Payload: files and directories copied into the Project during Adopt / Update.
    Payload = @(
        '.agents'
        'AGENTS.md'
        'CLAUDE.md'
        'docs/agents'
        'docs/adr'
        'docs/specs'
        'docs/handoff'
        'docs/analysis'
        '.gitattributes'
    )

    # Meta: Template development artifacts cleaned in New mode, never copied in Adopt/Update.
    Meta = @(
        'docs/dry-run-checklist.md'
        'docs/specs/*'
        'docs/adr/*'
        'docs/handoff/*'
        'docs/analysis/*'
        'docs/research/*'
        'tests/'
    )

    # Reset: files replaced with fresh project skeletons during New mode.
    Reset = @{
        '.agents/CONTEXT.md'     = 'templates/CONTEXT.md'
        'docs/handoff/LATEST.md' = 'templates/LATEST.md'
        'README.md'              = 'templates/README.md'
        'CODING_STANDARDS.md'    = 'templates/CODING_STANDARDS.md'
    }

    # GitIgnoreEntries: entries that must exist in .gitignore.
    GitIgnoreEntries = @(
        '.claude/skills/'
        '.scratch/'
    )
}
