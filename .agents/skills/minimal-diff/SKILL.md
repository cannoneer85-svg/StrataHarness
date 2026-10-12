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

## The 7-Step Ladder

Walk down the ladder from top to bottom. Stop at the **first step** that fully satisfies the task.

1. **Is it needed at all?**
   Eliminate speculative work added "just in case" or "for future extensibility": unused parameters, premature configuration flags, interfaces with a single implementer, wrappers around single functions. Requirements explicitly requested in the spec are never cut by this step.
2. **Does it already exist in the project?**
   Search the repository before writing new code. Reuse existing utilities, composables, helpers, or domain patterns. Duplicating logic produces drift.
3. **Does the standard library solve it?**
   Use language built-ins (e.g. native collection methods, standard regex, math/date utilities) without inventing custom wrappers over them.
4. **Does the platform, framework, or database solve it?**
   Prefer platform capabilities over custom code: CSS over JavaScript animations, database constraints (unique, foreign key, check) over redundant application-layer validations, native framework hooks over custom state machines.
5. **Does an already installed dependency solve it?**
   Check direct packages already declared in the project manifest (`package.json`, `pyproject.toml`, etc.). Never depend on transitive packages.
6. **Is one line enough?**
   If a single clean statement or built-in call solves the requirement, that is the entire implementation.
7. **Minimal implementation:**
   Write the narrowest, cleanest, self-contained implementation that fulfills the acceptance criteria, and nothing beyond.

## External Dependencies vs Home-Grown Code

- **Never reinvent non-trivial wheels:** For complex domains (cryptography, parsing binary/complex formats like XLSX or PDF, AST manipulation, specialized network protocols), writing home-grown code is dangerous and brittle. Using a mature, standard package is explicitly required over hundreds of lines of fragile custom code.
- **Spec justification:** When introducing a new external dependency, state the rationale explicitly in the spec or ticket (e.g. *«XLSX binary parsing cannot be handled reliably by stdlib; adding mature `exceljs` dependency»*).
- **Home-grown threshold:** Implement custom helpers only when the logic is straightforward and self-contained (under ~20–30 lines), where adding a third-party package creates unwarranted dependency bloat.

## Forbidden Zones (Simplification Prohibited)

In these critical zones, full and thorough implementations are mandatory. Steps 1–2 cannot be used to discard safety measures:

- **Validation at trust boundaries:** User input, external webhook payloads, third-party API responses.
- **Error handling that prevents data loss or silent corruption:** Database transactions, retry safety, rollback cleanup.
- **Security and access control:** Authentication guards, role-based checks, tenant isolation, secret handling.
- **Accessibility baselines:** Keyboard focus management, ARIA labels, semantic markup.
- **Explicit user requirements:** Anything explicitly requested by the user or specified in the approved acceptance criteria.

## Implementation Principles

- **Fix at the root, not at call sites:** When fixing a bug, find the source and repair it once. Applying N patches across N calling functions introduces N points of future failure.
- **Prefer deletion to addition:** The best diff is one that removes obsolete code while delivering the capability.
- **Boring over clever:** Clever, dense code is difficult to debug under incident pressure. Prefer readable, idiomatically standard code.
- **Self-verifying logic:** Any non-trivial branch, loop, state transition, or calculation must be covered by at least one targeted test that provably fails if the logic is altered.

## Anti-patterns

- ❌ Cutting acceptance criteria to make the diff smaller.
- ❌ Simplifying within forbidden zones ("we will add input sanitization later").
- ❌ Adding a new npm/pip package for a 2-line helper that standard library covers easily.
- ❌ Writing a 1000-line home-rolled crypto/parser engine instead of using a trusted library.
- ❌ Creating speculative abstractions, interfaces, or factories with only one consumer.
