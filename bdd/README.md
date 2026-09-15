# Behaviour Domain Driver (BDD) — Operational Contract

## Canonical version

**BDD v2 is the canonical contract.** Its JSON Schema, semantics, state machine, role model, and deterministic PowerShell validator are in [`v2`](./v2/). BDD means **Behaviour Domain Driver**, not Behaviour-Driven Development.

BDD v1 files remain only to document the superseded prototype and must not be used for new task contracts or state transitions.

> **Definition:** In this ecosystem, **BDD** stands for **Behaviour Domain Driver (BDD)**. It is the formal, persistent operational contract that defines agent behavior, identity, assignments, ownership, states, handoffs, evidence standards, and cross-agent coordination.

---

## 🎯 Purpose of BDD

1. **Eliminate Reliance on Conversational Memory:** Agent chat history is ephemeral and loses detail across compactions or turns. BDD state provides deterministic, machine-readable persistence.
2. **Prevent Parallel Agent Collisions:** Enforces mutually exclusive ownership over bounded contexts, branches, and database migrations.
3. **Enforce Evidence-Based Handoffs:** Requires verifiable artifacts (test logs, traces, PR URLs, SHAs) before marking any task `DONE`.
4. **Standardize Multi-Agent Collaboration:** Enables Antigravity (Architect), Codex (Implementer), and Gemini (Researcher/Reviewer) to hand off tasks seamlessly.

---

## 📂 BDD Specification Documents

* [`schema.yaml`](./schema.yaml): Machine-readable YAML schema for active agent state and handoff metadata.
* [`states.md`](./states.md): Formal definition of the 8 lifecycle states and valid transitions.
* [`handoff.md`](./handoff.md): Standard handoff payload and protocol.
* [`evidence.md`](./evidence.md): Standard catalog of acceptable machine-verifiable evidence.
* [`collision-prevention.md`](./collision-prevention.md): Locking protocol and conflict resolution.
