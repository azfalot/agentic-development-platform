# DEPRECATED: Behaviour Domain Driver (BDD) — Agent Lifecycle States

> The canonical vocabulary and legal transitions are in [`v2/STATES.md`](./v2/STATES.md). In particular, `WAITING_REVIEW` is retired and `REVIEWING` is canonical.

This document formally defines the allowed lifecycle states of any agent in this development platform.

---

## State Transition Diagram

```text
               ┌─────────────┐
               │  AVAILABLE  │
               └──────┬──────┘
                      │ (Claim assignment)
                      ▼
               ┌─────────────┐
               │  PLANNING   │◄──────────────┐
               └──────┬──────┘               │
                      │ (Plan ready)         │
                      ▼                      │
               ┌─────────────┐               │
               │IMPLEMENTING │               │ (Fix issues /
               └──────┬──────┘               │  Address changes)
                      │ (Code complete)      │
                      ▼                      │
               ┌─────────────┐               │
               │   TESTING   ├───────────────┤
               └──────┬──────┘               │
                      │ (Tests green)        │
                      ▼                      │
               ┌─────────────┐               │
               │ WAITING_CI  ├───────────────┘
               └──────┬──────┘
                      │ (CI Success)
                      ▼
               ┌─────────────┐
               │  REVIEWING  │
               └──────┬──────┘
                      │ (Approved)
                      ▼
               ┌─────────────┐
               │    DONE     │
               └─────────────┘
                      ▲
                      │
               ┌──────┴──────┐
               │   BLOCKED   │ (Collision / Missing Dependency / Needs Human Decision)
               └─────────────┘
```

---

## State Definitions

| State | Description | Allowed Actions | Exit Criteria |
| :--- | :--- | :--- | :--- |
| **AVAILABLE** | Agent is idle with no active assignment. | Inspect open issues, wait for assignment. | Assignment claimed and branch created. |
| **PLANNING** | Analyzing repository, ADRs, and bounded contexts. | Read files, grep, analyze schemas, draft implementation plan. | Plan finalized and approved. |
| **IMPLEMENTING** | Writing minimal feature/fix code. | Edit files declared in `ownership.files`. | Code changes complete. |
| **TESTING** | Executing automated test suites. | Run unit, integration, DB tests on `<proj>_test`, Playwright. | All tests pass locally with evidence. |
| **WAITING_CI** | PR created, waiting for GitHub Actions. | Watch CI logs (`gh pr checks --watch`). | All CI status checks green. |
| **REVIEWING** | Peer review of a PR. | Read diff, verify evidence, check security & no green-by-deletion. | Review decision posted (`APPROVE`/`REQUEST_CHANGES`). |
| **BLOCKED** | Execution paused due to collision or external dependency. | Emit conflict report, notify developer/architect. | Blocking condition resolved. |
| **DONE** | Task complete, PR merged or handed off with evidence. | Post BDD handoff payload, clean up branch. | Handoff recorded. |
