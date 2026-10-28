---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
---

# Test-Driven Development

TDD is the red → green → refactor loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle — consult them before and during the loop, not after.

When exploring the codebase, read `CONTEXT.md` (if it exists) so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists — and survives refactors because it doesn't care about internal structure.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Seams — where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. Give each proposed seam a one-line note on what it catches and what it misses. No test is written at an unconfirmed seam. You can't test everything — agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Ask: "What's the public interface, and which seams should we test?"

When the shape of that interface is itself in question — how deep the module is, where the seam belongs, what the interface should expose — call the Skill tool with "codebase-design" for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is a reference to consult, not a session to run.

## Anti-patterns

- **Implementation-coupled** — mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological** — the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth — a known-good literal, a worked example, the spec.
- **Hollow assertion** — the test stays green when the unit under test returns an empty value or becomes a no-op (e.g. asserting only `toBeDefined()` or "did not throw"). Strengthen it to assert the observable outcome (or delete it if redundant with existing seam coverage); if the agreed seam cannot observe honest behavior, renegotiate the seam with the user (or report `blocked` to the Orchestrator) instead of fabricating internal mocks or skipping required coverage.
- **Horizontal slicing** — writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead — one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, run it, and watch it fail on the expected assertion — never count a syntax, import, or setup error as red. Write only enough code to pass it, without anticipating future tests or speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Pin before refactoring uncovered code.** Before structurally refactoring existing code that lacks test coverage, lock down its current observable behavior with a passing characterization (pinning) test at an agreed public seam (the characterization exception to Red before green).
- **Refactor locally within the slice.** Local micro-refactoring in the green phase within the current slice (removing duplication, cleaning names, keeping code readable under test protection) is part of the red → green → refactor loop. Wide, cross-cutting, or architectural refactoring across modules belongs to the review stage (see the `code-review` skill) or dedicated tasks.
