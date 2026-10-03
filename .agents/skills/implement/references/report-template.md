# Report template

The implementer's final message. The Orchestrator checks it field by field: re-runs the listed commands itself, compares **Files changed** with `git status`, and reads **Deviations / decisions** against the spec.

```markdown
## Ticket <NN> — report

**Result:** done | blocked
**What was done:** bullet list
**Files changed:** list, each marked created / modified / deleted
**Test commands and results:** exact commands, pass/fail counts, exit codes
**Deviations / decisions:** anything not literally in the ticket, with the reason; "none" if none
**Open questions:** for the Orchestrator or the user; "none" if none
```
