# Behaviour Domain Driver v2 — Contract Semantics

BDD means **Behaviour Domain Driver**, not Behaviour-Driven Development. A v2 task contract is JSON and is validated by the platform's PowerShell validator; JSON was chosen to avoid an unpinned YAML parser dependency. It is immutable evidence of intended authority and current lifecycle state, not a prompt to an execution engine.

`task` identifies the work: `id` is the platform task ID; `source` names its originating system; `repository` is the canonical repository identifier; `issue` is the source-system issue ID or `null` when none exists. `goal` is the human-readable objective.

`assignment.role` is a provider-independent canonical role. `assignment.engine` is a selected execution engine or `unassigned`; selecting it does not authorize execution. `scope` declares one bounded context and allow/deny path patterns. `permissions` is the maximum authority granted to this task: filesystem is `none`, `read-only`, or `scoped-write`; Git/GitHub/merge are booleans; production is `denied`, `approval-required`, or `allowed`.

`ownership` is the collision-lock record: task ID, branch (or `null` before branch creation), bounded context, allowed file patterns, and migration patterns. `acceptance_criteria` records testable requirements and their current status. `verification` records deterministic gate outcomes only. `evidence` records immutable artifact locations/identifiers; nullable fields mean evidence is not yet available.

`handoff` declares the next role (or `human`) and why transfer is needed. `timestamps.created` never changes; `timestamps.updated` changes on every accepted state mutation. Every field is defined in the schema and unknown fields are rejected.
