---
name: minimal-diff
description: Solution scope discipline — seven-step ladder before writing code (needed at all → in project → stdlib → platform → dependency → one line → minimal implementation), forbidden zones where simplifying is prohibited, and dependency rules. Use during spec design, before implementing non-trivial tasks, or whenever a solution introduces new abstractions or packages.
---

# Minimal Diff — Solution Scope Discipline

Minimal-diff is the discipline of governing **how much code to write**, not how to cut requirements. It directly counters the tendency of AI agents to over-engineer: generating speculative abstractions, adding unnecessary dependencies, or scattering band-aids across call sites instead of fixing the root cause.

## Golden Rules

1. **Acceptance criteria take absolute precedence.** The specification, user stories, and acceptance criteria must be satisfied 100%. Minimal-diff governs the internal implementation volume, never external functionality. Dropping a required feature or edge case under the guise of "minimalism" is a strict defect.
2. **Understanding precedes brevity.** Never write a short diff in the wrong place. Trace the full flow and locate the root cause before applying changes.
3. **Correctness is never compromised.** Between two solutions of equal volume, always choose the one robust against boundary conditions and concurrent failures.
4. **Measure the resulting codebase, not the diff:** Adapting an existing unit (and its callers) beats a near-copy, even when the diff is larger.

## The 7-Step Ladder

Walk down the ladder from top to bottom. Stop at the **first step** that fully satisfies the task.

1. **Is it needed at all?**
   Eliminate speculative work added "just in case" or "for future extensibility": unused parameters, premature configuration flags, a seam with only one adapter (count test adapters as adapters) — see codebase-design, wrappers around single functions. Requirements explicitly requested in the spec are never cut by this step.
2. **Does it already exist in the project?**
   Search the repository before writing new code. Reuse existing utilities, composables, helpers, or domain patterns. Duplicating logic produces drift.
3. **Does the standard library solve it?**
   Use language built-ins (e.g. native collection methods, standard regex, math/date utilities) without inventing custom wrappers over them.
4. **Does the platform, framework, or database solve it?**
   Prefer platform capabilities over custom code: CSS over JavaScript animations, database constraints (unique, foreign key, check) as the source of truth for data invariants (boundary validation for user-facing errors stays), native framework hooks over custom state machines.
5. **Does an already installed dependency solve it?**
   Check direct packages already declared in the project manifest (`package.json`, `pyproject.toml`, etc.). Never depend on transitive packages.
6. **Is one line enough?**
   If a single clean statement or built-in call solves the requirement and stays readable, that is the entire implementation.
7. **Minimal implementation:**
   Write the narrowest, cleanest, self-contained implementation that fulfills the acceptance criteria, and nothing beyond.

## External Dependencies vs Home-Grown Code

- **Never reinvent non-trivial wheels:** For complex domains (cryptography, parsing binary/complex formats like XLSX or PDF, AST manipulation, specialized network protocols), writing home-grown code is dangerous and brittle. Using a mature, standard package is explicitly required over hundreds of lines of fragile custom code.
- **Spec justification:** When introducing a new external dependency, state the rationale explicitly in the spec or ticket (e.g. *«XLSX binary parsing cannot be handled reliably by stdlib; adding mature `exceljs` dependency»*).
- **Home-grown threshold:** Implement custom helpers only when the logic is straightforward and self-contained (under ~20–30 lines), where adding a third-party package creates unwarranted dependency bloat.

## Forbidden Zones (Simplification Prohibited)

In these critical zones, full and thorough implementations are mandatory. No ladder step may remove, weaken, or simplify safety and security measures:

- **Validation at trust boundaries:** User input, external webhook payloads, third-party API responses (database constraints ensure data integrity, but never replace boundary validation for user-facing errors).
- **Security and access control:** Authentication guards, role-based checks (RBAC/ABAC), multi-tenant isolation, IDOR prevention, injection defense (SQLi, XSS, SSRF, path traversal), and secret handling (never log secrets, tokens, or PII).
- **Error handling:** Comprehensive error handling and failure logging (prevent silent suppression with empty catch blocks, data loss, or silent corruption; database transactions, retry safety, rollback cleanup).
- **Contract compatibility:** Public contract, schema, and migration backward compatibility.
- **Resource management:** Proper resource cleanup and idempotency.
- **Behavior tests:** Tests verifying observable behavior through public interfaces.
- **Accessibility baselines:** Keyboard focus management, ARIA labels, semantic markup.
- **Explicit user requirements:** Anything explicitly requested by the user or specified in the approved acceptance criteria.

## Conscious Tradeoffs

When a developer consciously chooses a localized simplification or near-copy over generalized abstraction (e.g. to avoid premature coupling or when two use cases have not diverged sufficiently), document the decision explicitly in code.

Standard comment format:
- In code (C-style languages, TypeScript, Go, etc.):
  `// TRADEOFF(<ticket>): <why>`
- In scripts (Bash, Python, PowerShell):
  `# TRADEOFF(<ticket>): <why>`

Examples:
- `// TRADEOFF(01-auth): localized helper preferred over shared module until second consumer arrives`
- `# TRADEOFF(fix-deploy): inlined curl retry logic to keep deployment script dependency-free`

Such tradeoffs must be conscious, localized, and explicitly tagged so they can be identified, tracked, and revisited during refactoring or code review.

## Implementation Principles

- **Fix at the root, not at call sites:** When fixing a bug, find the source and repair it once. Applying N patches across N calling functions introduces N points of future failure.
- **Prefer deletion to addition within the task's scope, and only code proven unused:** The best diff is one that removes obsolete or dead code within the task's boundaries while delivering the capability, without sweeping refactoring of unrelated code.
- **Boring over clever:** Clever, dense code is difficult to debug under incident pressure. Prefer readable, idiomatically standard code.
- **Self-verifying logic:** Any non-trivial branch, loop, state transition, or calculation must be covered through the public interface by a behaviour test that provably fails if the logic is altered (verifying observable behavior rather than internal implementation details per TDD).

## Anti-patterns

- ❌ Cutting acceptance criteria to make the diff smaller.
- ❌ Simplifying within forbidden zones ("we will add input sanitization later").
- ❌ Duplicating existing logic or creating near-copies to keep a diff small instead of adapting existing units and their callers.
- ❌ Adding a new npm/pip package for a 2-line helper that standard library covers easily.
- ❌ Writing a 1000-line home-rolled crypto/parser engine instead of using a trusted library.
- ❌ Creating speculative abstractions, interfaces, or seams with only one adapter (count test adapters as adapters — see codebase-design).
