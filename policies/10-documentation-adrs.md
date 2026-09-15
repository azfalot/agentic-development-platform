# GLOBAL DEVELOPMENT POLICY — DOCUMENTATION & ARCHITECTURE DECISION RECORDS (ADR)

This policy establishes documentation standards and the mandatory recording of significant architectural decisions.

---

## 1. DOCUMENTATION SYNCHRONIZED WITH REALITY

* Any pull request that alters user workflows, environment variables, APIs, or operational steps must update the corresponding `README.md`, `openapi.yaml`, or project documentation.
* Outdated documentation that contradicts actual code behavior is considered a defect.

---

## 2. ARCHITECTURE DECISION RECORDS (ADR)

Significant architectural decisions must be recorded as an ADR in `docs/adr/` or `docs/architecture/` within the repository.

### When to write an ADR:
* Introducing a new framework, persistence engine, or message broker.
* Restructuring bounded contexts or domain boundaries.
* Changing authentication/authorization mechanics or security models.
* Adopting a new API protocol or contract format.

### ADR Mandatory Structure:
```markdown
# [Number]. [Title in Imperative Mood]

* **Status:** [Proposed | Accepted | Superseded | Deprecated]
* **Date:** [YYYY-MM-DD]
* **Author / Agent:** [Agent ID / Name]

## Context
What problem are we trying to solve? What are the business and technical constraints?

## Decision
What is the specific architectural change or standard we are adopting?

## Alternatives Considered
1. Alternative A (Why was it rejected?)
2. Alternative B (Why was it rejected?)

## Consequences
* **Positive:** What benefits do we gain?
* **Negative / Trade-offs:** What complexity or maintenance cost are we taking on?
```

Agents must search existing ADRs before proposing or implementing changes that conflict with an established decision.
