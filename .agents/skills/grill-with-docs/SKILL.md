---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Call the Skill tool twice, for "grilling" and "domain-modeling".

---

### Multi-Round Depth Calibration (Калибровка глубины интервью)

Before asking questions, categorize the task size and strictly enforce the round quota:
- **Minor (1 round, 2–4 questions):** Small isolated changes. Focus on immediate design choices.
- **Feature (2 mandatory rounds, 6–8 questions total):**
  - *Round 1 (Happy Path & Scope):* Core intent, interfaces, MVP boundaries.
  - *Round 2 (Unhappy Path & Edge Cases):* Errors, invalid inputs, failure states, edge conditions.
- **Epic / Architecture (3 mandatory rounds, 10–12+ questions total):**
  - *Round 1 (Happy Path & Architecture):* High-level approach, boundaries, main flow.
  - *Round 2 (Unhappy Path & Resilience):* Degradation, error recovery, concurrency, edge cases.
  - *Round 3 (Lifecycle & NFR):* Performance, security, token/resource limits, observability, deployment.

Never jump to spec creation until all mandatory rounds for the detected category are fully completed through interactive `ask_question` calls.