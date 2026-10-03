---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

# Implement

Implement the work described by the user in the spec or tickets.

## 1. Assess & Choose Execution Strategy

Before writing any code, analyze the tickets in `.scratch/<feature>/issues/`, their dependencies (`Blocked by`), and estimated context/token footprint:

- **In-Place Execution (Current Context)**: Use when tasks are compact, straightforward, and total session context is predicted to stay well within the Smart Zone (< 100k tokens). Execute tickets sequentially in the current thread.
- **Sequential Subagents**: Use when tasks involve heavy logic, large test suites, or high token footprint. As orchestrator, dispatch isolated subagents one ticket at a time following the dependency graph. Each subagent runs TDD, achieves green tests, and reports back.
- **Multi-Session Work**: Recommend to the user when the scope is exceptionally massive and requires manual inspection between milestones via opening fresh sessions/conversations.

State the chosen strategy clearly to the user before starting.

## 2. Implementation Rules

- Drive implementation with **/tdd** (`red-green-refactor`) at agreed seams.
- Design deep modules with narrow interfaces (**codebase-design**).
- Run typechecking and unit tests frequently during development, and the full test suite once at the end.

## 3. Completion

- Present a summary of implemented tickets and test results.
- Stop and ask the user for permission to run **/code-review**.
