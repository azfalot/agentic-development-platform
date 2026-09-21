# AgentHub Roadmap to v1

## P0 — Operational Autonomy

### Repository

- [x] Validate repository/worktree availability before agent execution
- [x] Verify write capability before model invocation
- [x] Resolve configured project repository
- [x] Validate repository state and expected base branch
- [x] Validate remote
- [x] Detect unsupported filesystem/sandbox configuration
- [x] Create isolated worktree ownership records

Repository resolution, identity normalization, safety verification, and worktree isolation are proved by `tests/repository-resolution.tests.ps1`.

### Environment readiness

- [x] Detect project runtime requirements and package manager
- [x] Detect missing declared dependencies
- [x] Prepare declared dependencies deterministically when explicitly permitted by policy
- [x] Detect Docker requirements
- [x] Start declared local services when explicitly permitted by policy
- [x] Execute declared HTTP health/readiness checks
- [x] Validate declared verification-command prerequisites
- [x] Fail before model invocation when required environment readiness is blocked
- [x] Persist machine-readable environment readiness evidence

The readiness gate is proved by `tests/environment-readiness.tests.ps1` and project environment discovery is proved by `tests/project-environment-discovery.tests.ps1`, including deterministic verification of multi-service dependency prerequisites and missing tool blockers.

### Artifact classification

- [x] Distinguish product changes from runtime artifacts
- [x] Recognize caches, dependency directories, test reports, and AgentHub runtime artifacts
- [x] Avoid reporting disposable runtime artifacts as product scope violations

Artifact classification, tracked state differentiation, and scope relevance are proved by `tests/artifact-classification.tests.ps1` (including the `RUNTIME_ARTIFACT_FALSE_SCOPE_REGRESSION` fixture).

### Automatic validation collection

- [x] Resolve deterministic validation plan from Task Contract, project config, and environment discovery
- [x] Execute commands, file assertions, git diff checks, and artifact assertions independently of agent self-reporting
- [x] Enforce worktree ownership isolation, bounded timeouts, and secret redaction
- [x] Persist machine-readable validation evidence and evaluate overall GO / NO_GO status

Validation plan resolution, execution safety, and machine-readable evidence collection are proved by `tests/validation-collection.tests.ps1`.

### Minimal Git completion & End-to-End P0 Autonomy

- [x] Verify worktree and branch ownership before completion
- [x] Refuse completion fail-closed if validation != GO, scope violation exists, guardrails fail, or no progress
- [x] Stage ONLY authorized scope-relevant files (excluding disposable caches, dependencies, build outputs, and AgentHub evidence)
- [x] Create deterministic local commit with task trailers (`Task-Id`, `Role`, `Engine`, `Validation`)
- [x] Transition contract state to `READY_FOR_HUMAN` upon verified completion
- [x] Persist `commit_sha`, `committed_paths`, `excluded_paths`, and complete execution evidence

The end-to-end P0 control-plane flow and fail-closed invariants are proved across scenarios A-K by `tests/p0-vertical-flow.tests.ps1` (0 model invocations, 0 tokens consumed).

**Status: P0 Operational Autonomy is COMPLETE.**

## Architecture & Integration Boundaries

Following the architectural fit-gap review documented in `docs/architecture/OPENHANDS_FIT_GAP.md`:
- **AgentHub Core Role:** AgentHub is strictly a deterministic governance and control plane (task contracts, preflight safety gates, execution budgets, bounded context scoping, verification enforcement, handoff proof).
- **Agent Execution Boundaries:** AgentHub does not implement internal autonomous agent loops, prompt templates, or raw LLM provider clients. External execution engines (such as OpenHands or Codex) operate through isolated, swappable `AgentAdapter` contracts. AgentHub maintains zero runtime dependency on external orchestration frameworks.
- **Strict Project Isolation:** AgentHub core, tests, fixtures, and documentation must remain project-agnostic. Real projects may be used externally for acceptance testing, but their implementation details, repository names, incidents, and architecture must not become AgentHub dependencies or core fixtures.
