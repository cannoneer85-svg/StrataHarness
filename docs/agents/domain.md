# Domain Documentation

This repository uses a **single-context** domain layout:

- **Ubiquitous Language & Glossary**: [`.agents/CONTEXT.md`](../../.agents/CONTEXT.md).
- **Architectural Decision Records (ADRs)**: Stored in [`docs/adr/`](../adr/).

## Rules for Agents
1. Before implementing domain logic, consult `.agents/CONTEXT.md` for agreed terminology.
2. If introducing new domain concepts or resolving ambiguity during `/grill-with-docs`, update `.agents/CONTEXT.md`.
3. Significant architectural decisions that are hard to reverse must be recorded as ADRs in `docs/adr/XXXX-<title>.md`.
