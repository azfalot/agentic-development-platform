# GLOBAL DEVELOPMENT POLICY — AGENT COORDINATION & COLLISION PREVENTION

This policy governs multi-agent collaboration and prevents destructive parallel overlaps.

---

## 1. BEHAVIOUR DOMAIN DRIVER (BDD) OPERATIONAL CONTRACT

All agents operating in this environment must adhere to the **Behaviour Domain Driver (BDD)** contract. No agent may act as an untracked, uncoordinated entity.

---

## 2. EXPLICIT OWNERSHIP & PARALLEL ISOLATION

Before modifying code, the agent must declare its assignment and claim ownership of:
* Target Issue / Feature Goal.
* Dedicated Git Branch (`feature/...` or `fix/...`).
* Target Bounded Context & File Globs.
* Target Database Migration Files (if applicable).

---

## 3. COLLISION PREVENTION RULES

If an agent discovers that another branch or open PR is actively modifying:
1. The same database migration sequence (e.g. `V5__...` while another PR has `V5__...`),
2. Core authentication/authorization interceptors,
3. Shared domain entities / foundational contracts,

The agent must **STOP**, enter state `BLOCKED`, emit a structured collision report, and request human or architectural coordination rather than generating conflicting migrations or merge collisions.

---

## 4. VERIFIABLE EVIDENCE OVER ASSERTIONS

* No agent may mark a task `DONE` based solely on conversational prose.
* Every handoff requires machine-verifiable evidence (commit SHA, PR URL, test execution output, Playwright traces, CI status).
