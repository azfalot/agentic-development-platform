# Behaviour Domain Driver v2 — Canonical State Machine

The only valid states are `CREATED`, `PLANNING`, `READY`, `CLAIMED`, `IMPLEMENTING`, `VERIFYING`, `REVIEWING`, `BLOCKED`, `READY_FOR_HUMAN`, `DONE`, `FAILED`, and `CANCELLED`. `WAITING_REVIEW` is retired; use `REVIEWING`.

| State | Meaning | Legal next states |
|---|---|---|
| CREATED | Contract exists but has not been analyzed. | PLANNING, CANCELLED, FAILED |
| PLANNING | Scope, constraints, and acceptance criteria are being defined. | READY, BLOCKED, FAILED, CANCELLED |
| READY | Plan and permissions are ready for a claim. | CLAIMED, BLOCKED, CANCELLED |
| CLAIMED | Ownership is reserved; no implementation has started. | IMPLEMENTING, BLOCKED, CANCELLED, FAILED |
| IMPLEMENTING | Authorized work is in progress. | VERIFYING, BLOCKED, FAILED, CANCELLED |
| VERIFYING | Deterministic checks are running or being assessed. | REVIEWING, IMPLEMENTING, BLOCKED, FAILED, CANCELLED |
| REVIEWING | Independent review examines changes and evidence. | READY_FOR_HUMAN, IMPLEMENTING, BLOCKED, FAILED, CANCELLED |
| BLOCKED | Work cannot safely continue. | PLANNING, READY, CLAIMED, IMPLEMENTING, VERIFYING, REVIEWING, FAILED, CANCELLED |
| READY_FOR_HUMAN | All automation is complete; a human merge/decision gate remains. | DONE, IMPLEMENTING, BLOCKED, FAILED, CANCELLED |
| DONE | Terminal: human decision/merge handoff completed. | none |
| FAILED | Terminal: work ended unsuccessfully. | none |
| CANCELLED | Terminal: work intentionally stopped. | none |

The transition validator accepts only the pairs above. It does not infer state from prose, command output, or provider status.
