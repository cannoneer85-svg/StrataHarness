---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Call the Skill tool twice, for "grilling" and "domain-modeling".

---

## Rounds

The number of mandatory rounds and questions per Category is set in the Routes table of the root `AGENTS.md`. A route with N mandatory rounds runs the first N themes below, in order; adapt each theme to the domain (UI, API, data, hardware, documents):

1. **Outline and happy path** — core intent, scope and MVP boundaries, interfaces and contracts, the main flow. On the Minor route this single round covers the immediate design choices.
2. **Errors and edge cases** — invalid input, failure states, degradation and recovery, concurrency, boundary conditions.
3. **NFR** — performance, security, resource and token limits, observability, deployment.

Within a round, work the grilling frontier; follow-up questions raised by the answers stay in the same round. A round is done when its theme's frontier is empty and its answers are in the log. Offer the next stage (`/to-spec`; on Minor, implementation) only once every mandatory round of the current Category is done.

## Question format

Ask each round through the harness's interactive question tool when it has one (Antigravity: `ask_question`), with your recommended answer as the first option. Without such a tool, use the `grilling` question format.

## Interview log

Keep the log at `.scratch/<feature>/OPEN_QUESTIONS.md`, where `<feature>` is the kebab-case feature slug that the spec and tickets reuse. Create it with the first round. After each round, append:

- the round number and theme;
- each question with the user's answer;
- the decisions that follow;
- questions still open.

Terms still go into the glossary the moment they resolve (domain-modeling). ADR candidates — decisions meeting domain-modeling's three criteria — go into an **ADR candidates** section of the log instead of `docs/adr/`; `/to-spec` writes them as ADRs. On the Minor route, which has no spec stage, offer each candidate as an ADR at the interview stop gate.