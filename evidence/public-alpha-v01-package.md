# Agent Execution v0.1 — Public Alpha Evidence Package

This sanitized record contains no credentials, user-specific paths, or raw process logs.

## Engineering progression

1. A historical Windows restricted-sandbox execution accepted `workspace-write` but failed before child-process launch.
2. Deterministic, non-model probes isolated the environment behavior.
3. An updated signed CLI was activated and the non-model sandbox probes passed.
4. A disposable calculator task then succeeded but revealed an adapter-bypass defect in the orchestration path.
5. The correction made AgentHub use one structured adapter specification for resolution, preflight, and generic execution.
6. A fresh disposable calculator task, with division support and tests, succeeded through that corrected route.

## Final architectural E2E evidence

| Field | Result |
| --- | --- |
| Codex version | `0.154.0-alpha.6.2` |
| Sandbox | `workspace-write` |
| Process exit | `0` |
| Execution result | `SUCCESS` |
| BDD final state | `READY_FOR_HUMAN` |
| Source and test change | yes |
| Scope and unit verification | passed |
| Specification identity | adapter, preflight, and runner IDs identical |
| Budget | one authorized, one consumed, zero remaining |
| Guardrails | 24 local baseline findings, zero new regressions |

## Deterministic safeguards

- BDD v2 validation and state checks
- adapter capability and argument-boundary tests
- mock specification identity and direct-provider-bypass tests
- budget persistence: initial creation, backups, orphan cleanup, failure-before-spawn, concurrency, and exactly-once consumption
- guardrail baseline identity scenarios

The 24 historical guardrail findings were an environment baseline, not a public-repository defect. This public alpha starts with an explicit empty baseline. The evidence demonstrates a corrected path once; it does not promise that every Windows configuration or future CLI version will behave identically.
