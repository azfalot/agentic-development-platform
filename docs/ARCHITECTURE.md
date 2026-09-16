# Architecture

The platform has five small layers:

1. **BDD v2:** JSON task contracts define state, ownership, scope, permissions, checks, and evidence.
2. **AgentHub:** validates a contract, creates an isolated Git worktree, tracks state, and emits evidence for human review.
3. **Adapter boundary:** `engine-routing.psd1` selects a provider adapter. The adapter creates one structured execution specification; generic core preflights and runs that same specification. This avoids reconstructing shell arguments in orchestration code.
4. **Execution gate:** a persisted, atomically consumed budget makes real invocations opt-in and prevents a process spawn if budget persistence fails.
5. **Guardrails:** a baseline is compared by finding identity; only new findings block a task.

`doctor`, validation, the tests, and mocked adapter checks do not perform model inference. Real `run` remains human-authorized, provider-dependent, and subject to account cost.
