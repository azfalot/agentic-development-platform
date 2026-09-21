# Architecture Review: OpenHands Fit-Gap & Reuse Analysis

**Document Status:** Approved Architecture Review  
**Date:** 2026-09-21  
**Author:** Antigravity / AgentHub Architecture  
**Target:** AgentHub v1 Control Plane & Roadmap  
**Scope:** OpenHands (`OpenHands/OpenHands`, `OpenHands/software-agent-sdk`, `OpenHands/sandbox-server`) vs. AgentHub

---

## 1. Executive Summary & Core Finding

AgentHub's guiding principle is **REUSE-BEFORE-BUILD**: if a mature open-source component already solves a problem well and can run locally without mandatory paid orchestration SaaS, AgentHub should integrate or reuse it rather than duplicate engineering.

### Core Finding
**OpenHands and AgentHub occupy complementary, non-competing layers of the autonomous development stack:**

```
+-------------------------------------------------------------------------------+
|                             AGENTHUB (Control Plane)                          |
|  - BDD Task Contracts (scope, permissions, acceptance criteria)               |
|  - Deterministic Pre-Agent Readiness & Environment Discovery (0 token cost)   |
|  - Atomic Execution Budget Gates (human opt-in spend protection)              |
|  - Git Worktree & Branch Ownership Isolation                                  |
|  - Contract Progress Classification (product vs. test vs. docs changes)       |
|  - Global Guardrail Audits & Baseline Identity Regression Detection           |
|  - Deterministic Verification Suites & Immutable Evidence Persistence         |
+-------------------------------------------------------------------------------+
                                      |
                      [AgentAdapter Boundary (CLI / Process)]
                                      |
       +------------------------------+------------------------------+
       |                              |                              |
  [CodexAdapter]                [ClaudeAdapter]              [OpenHandsAdapter]
  (Codex CLI)                   (Claude Code CLI)             (OpenHands CLI/SDK)
       |                              |                              |
       v                              v                              v
  OpenAI Models                 Anthropic Models              LiteLLM / Ollama /
  & Local CLI Sandboxes         & Native Tool Loop            Docker & Sandboxes
```

- **OpenHands IS AN AGENT AND RUNTIME:** It implements the prompt-to-LLM loop, tool execution (bash, file editor, browser, IPython), multi-agent micro-delegations (`DelegatorAgent`, `CodeAct`), and container sandboxing (`DockerRuntime` / `sandbox-server`).
- **AgentHub IS NOT AN AGENT RUNTIME:** It does not construct raw LLM prompts, does not parse LLM responses, and does not maintain internal prompt-tool loops. It is a **deterministic governance and verification control plane** that treats coding agents (Codex CLI, Claude Code CLI, OpenHands) as black-box execution engines.

### Strategic Verdict
1. **AgentHub must NOT build its own agent runtime, prompt-tool engine, raw LLM router, or complex DAG scheduler.** OpenHands solves the autonomous agent runtime domain.
2. **OpenHands should be integrated into AgentHub as a first-class `OpenHandsAdapter`**, sitting alongside `CodexAdapter` and `ClaudeAdapter`.
3. **AgentHub's completed governance layers (BDD v2 contracts, Environment Readiness, Project Environment Discovery, Execution Budgets, Progress Classifier, Guardrail Baselines, Evidence Logging) must be KEPT.** OpenHands does not provide pre-execution deterministic contract validation, task-scoped atomic token spend protection, contract scope filtering, or baseline guardrail regression tracking.

---

## 2. Technical Profile: OpenHands

### 2.1 Ecosystem & Repositories Reviewed
- **Core Platform:** `OpenHands/OpenHands` (v0.18+ / v1.0 architecture transition)
- **SDK:** `OpenHands/software-agent-sdk` (Pydantic-based V1 SDK)
- **Sandbox Plane:** `OpenHands/sandbox-server` (Containerized execution API)
- **Licensing:** MIT License (100% Free and Open Source).

### 2.2 OpenHands Capabilities (Local OSS vs. Cloud SaaS)

| Capability | Local Open Source (OSS) Status | Cloud / Enterprise SaaS Status |
| :--- | :--- | :--- |
| **Agent Execution Loop** | Full `CodeAct` reasoning-execution cycle locally | Hosted scalable compute |
| **CLI / Headless Mode** | `openhands --headless -t "..." --json` | Web UI / Agent Canvas |
| **Tool Execution** | Bash, File Editing, IPython, Web Browsing | Remote cloud sandboxes |
| **Sandboxing & Isolation** | Docker container (`DockerRuntime`) or host (`LocalWorkspace`) | Hosted ephemeral VMs |
| **LLM Integration** | LiteLLM (OpenAI, Anthropic, Gemini, Ollama, vLLM, DeepSeek) | Managed API proxy / keys |
| **Cost & Budget Tracking** | `max_budget_per_task` (monitors API USD spend) | Organization-wide billing & quotas |
| **Multi-Agent / Delegation** | `DelegatorAgent`, micro-agents, sub-agent spawning | Distributed team workers |
| **GitHub Integration** | `github-resolver` CLI (issue to PR locally) | GitHub App webhook orchestration |
| **Event History** | Event-sourced JSONL stream (`EventStream`) | Centralized web logs |

### 2.3 Operational & Cost Characteristics
- **Mandatory Paid Orchestration:** NONE. OpenHands runs 100% locally via Docker or Python CLI.
- **Model / Provider Lock-In:** NONE. Uses LiteLLM and supports 100+ API providers plus local offline models (Ollama, vLLM).
- **Execution Overhead:** Running full Docker containers creates non-trivial memory/startup overhead compared to native process execution or lightweight Git worktrees, but `LocalWorkspace` provides a zero-container alternative.

---

## 3. Technical Profile: AgentHub Current Baseline

AgentHub currently consists of a lean, zero-dependency, deterministic control plane:

1. **`BDDValidator.psm1` (BDD v2 Schema):** Validates strict task contracts, ownership claims, file scope boundaries (`allowed` / `forbidden` globs), role permissions (`scoped-write`, `git_write`), and lifecycle state transitions.
2. **`ProjectEnvironmentDiscovery.psm1`:** Deterministically inspects repositories to discover ecosystems (`node`, `maven`, `gradle`, `python`, `dotnet`, `powershell`), package managers (`npm`, `pnpm`, `yarn`, `mvnw`, etc.), dependency states (`READY`, `MISSING`), Docker compose manifests, verification tooling (`playwright`, `mvnw`, `pester`), and sandbox write accessibility *before spending any model tokens*.
3. **`EnvironmentReadiness.psm1`:** Validates and deterministically prepares dependencies and services before agent invocation; blocks execution before model tokens are spent if prerequisites fail.
4. **`ExecutionGate.psm1`:** Manages atomic, filesystem-locked task execution budgets (`.agenthub-budgets`), preventing real engine execution unless explicitly authorized by a human operator.
5. **`AgentExecutionCore.psm1` & `CodexAdapter.psm1`:** Adapter pattern that generates structured, non-mutating execution specifications and preflights agent capabilities.
6. **`ProgressClassifier.psm1`:** Contract-aware diff classification that checks whether modifications stayed within declared scope and whether source/test progress was achieved.
7. **`GuardrailGate.psm1` & `GlobalGuardrailAudit.psm1`:** Baseline comparison audit detecting newly introduced security and policy regressions.
8. **`agenthub.ps1`:** CLI controller orchestrating isolated Git worktree setup, preflight, readiness, budget locking, agent execution, post-verification, guardrails, and immutable evidence emission (`.agenthub-evidence-*.json`).

---

## 4. Comprehensive Fit-Gap Matrix

| Capability / Area | AgentHub Status | OpenHands Status | Overlap | OpenHands Local OSS Capability | AgentHub Differentiation | Decision | RATIONALE |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BDD Task Contracts** | Implemented (v2 JSON schema) | None (informal prompt / issue text) | None | None | Machine-validated scope, boundaries, permissions, acceptance criteria | **KEEP** | Essential for strict enterprise/team governance and preventing scope creep. |
| **Pre-Agent Environment Discovery** | Implemented (`ProjectEnvironmentDiscovery.psm1`) | None (LLM explores environment during runtime) | None | None | Deterministic, 0-token repo inspection for runtime, tools, and sandboxes | **KEEP** | Prevents wasting LLM tokens on unready or incompatible environments. |
| **Pre-Agent Environment Readiness** | Implemented (`EnvironmentReadiness.psm1`) | None (assumes environment or container is ready) | None | None | Deterministic check & policy-controlled dependency/service preparation | **KEEP** | Catches missing dependencies, failed services, and blocked tooling before invocation. |
| **Execution Budgets & Opt-In Gates** | Implemented (`ExecutionGate.psm1`) | Partial (`max_budget_per_task` tracks USD spend) | Partial | Tracks API cost during runtime; stops on limit | Atomic, file-locked, pre-invocation human authorization gate | **KEEP** | Protects against accidental autonomous runaways and unauthorized invocations. |
| **Agent Adapter Boundary** | Implemented (`AgentExecutionCore.psm1`) | Agent platform with ACP & CLI | Medium | Can be invoked as an external process via CLI/SDK | Unified CLI process wrapper for Codex, Claude, and OpenHands | **KEEP & INTEGRATE** | Keep AgentHub adapter interface; add `OpenHandsAdapter` to run OpenHands as an engine. |
| **LLM Prompt / Reasoning Loop** | Planned in early roadmap | Fully implemented (`CodeActAgent`, SDK) | Full | Mature prompt-to-tool loop with history and error recovery | None (AgentHub should not build LLM loops) | **DELETE / REPLACE** | Never implement an LLM prompt/tool loop in AgentHub. Use OpenHands/Codex/Claude instead. |
| **Tool Execution Engine (Bash/Edit/Browser)** | Not implemented (delegated to agent) | Fully implemented (`openhands.tools`) | High | Terminal, file editor, browser, IPython inside Docker/host | None | **DELETE / REPLACE** | Delegate tool execution entirely to the underlying agent (Codex CLI, Claude Code, OpenHands). |
| **Multi-Agent Collaboration & DAGs** | Speculative roadmap | Fully implemented (`DelegatorAgent`, micro-agents) | High | Spawns sub-agents, delegates sub-tasks, event streaming | None | **DELETE / DEFER** | Do not build custom DAG or multi-agent engines in AgentHub. AgentHub governs single-task contracts. |
| **Model / Provider Routing (LiteLLM)** | Speculative roadmap | Fully implemented (LiteLLM integration) | Full | Routes to 100+ LLMs and local models | None | **DELETE / REPLACE** | Model routing belongs in OpenHands or the specific agent CLI, not in AgentHub control plane. |
| **Container Sandboxing (Docker/VM)** | Out of scope (uses Git worktrees) | Fully implemented (`sandbox-server`, Docker) | Low | Ephemeral Docker containers with tool execution API | Git worktrees provide fast, lightweight local isolation | **DEFER / REUSE** | Keep Git worktrees for local tasks; reuse OpenHands Docker runtime when container isolation is needed. |
| **Git Worktree Isolation** | Implemented (`agenthub.ps1`) | Local clone or mounted volume | Low | Manages Git checkout/patch creation | Automatic worktree creation, branch isolation, and collision detection | **KEEP** | Fast, local-first, zero-overhead isolation without requiring Docker daemon. |
| **Contract-Aware Progress Classification** | Implemented (`ProgressClassifier.psm1`) | None (relies on raw diff or LLM evaluation) | None | None | Deterministic classification of product vs test vs documentation changes against scope | **KEEP** | Prevents hallucinated success or out-of-scope modifications from passing unnoticed. |
| **Global Guardrails Baseline Audit** | Implemented (`GlobalGuardrailAudit.psm1`) | None | None | None | Baseline identity diffing to ensure no new security/quality violations | **KEEP** | Independent compliance audit preventing security regressions. |
| **Deterministic Post-Verification** | Implemented (`agenthub.ps1` verification gate) | Partial (agent runs test tools internally) | Low | Agent can execute test commands if prompted | Independent execution of verification commands with exit-code enforcement | **KEEP** | Verification must be enforced by the governance plane, not trusted to agent self-reporting. |
| **Immutable Evidence Persistence** | Implemented (`.agenthub-evidence-*.json`) | EventStream logs (JSONL/DB) | Low | Event stream for debugging agent steps | Tamper-evident, audit-ready compliance record for human PR approval | **KEEP** | Core differentiator for enterprise compliance, auditing, and human handoff. |
| **Automated PR & GitHub Resolver** | Planned roadmap | Implemented (`github-resolver` CLI) | Medium | Fetches issue, runs agent, makes branch, submits PR | AgentHub delegates PR creation to human or GitHub CLI | **DEFER / INTEGRATE** | Let OpenHands Resolver or standard GitHub Actions handle remote PR creation after AgentHub signoff. |

---

## 5. Answers to the 13 Special Questions

### 1. Should AgentHub build its own workspace/sandbox abstraction?
**NO.** AgentHub should continue using native Git worktrees (`.agenthub-worktrees/<task-id>`) for fast, local filesystem isolation. When strong containerized or virtualized sandboxing is required, AgentHub should delegate sandbox execution to OpenHands (via `OpenHandsAdapter`) or Docker rather than writing custom sandbox orchestrators.

### 2. Should AgentHub build its own generic agent runtime?
**NO.** Building an agent runtime (prompt crafting, LLM call management, token streaming, tool-call parsing, and retry loops) is an enormous, duplicative engineering effort. OpenHands already provides a best-in-class, MIT-licensed agent runtime. AgentHub's role is to govern and verify agents, not be an agent.

### 3. Should AgentHub build its own multi-agent conversation/runtime?
**NO.** Multi-agent sub-task delegation, micro-agents, and agent communication loops are fully implemented in OpenHands (`DelegatorAgent`, micro-agents) and Claude Code. AgentHub must stay focused on contract-level single-task or sequential-task governance.

### 4. Should AgentHub build its own complex DAG/task execution engine?
**NO.** Complex DAG engines introduce massive state management overhead. In v1, AgentHub should orchestrate atomic, deterministic Task Contracts. Multi-step workflows should be sequenced by standard CI/CD pipelines, shell scripts, or external orchestrators invoking AgentHub per step.

### 5. Should AgentHub build model-provider routing?
**NO.** AgentHub routes between **Agent Engines** (Codex CLI, Claude Code CLI, OpenHands), not between raw LLM APIs. When OpenHands is used, LiteLLM handles all model routing. When Codex or Claude Code is used, vendor CLIs handle their respective models.

### 6. Should AgentHub continue implementing Git/worktree lifecycle itself?
**YES.** AgentHub's local Git worktree lifecycle (`git worktree add`, branch management, diff hashing, and worktree cleanup) is lightweight (under 30 lines of PowerShell), deterministic, zero-dependency, and works across Windows, macOS, and Linux without Docker or Python dependencies.

### 7. Can OpenHands be treated as another AgentAdapter?
**YES.** OpenHands provides a headless CLI (`openhands --headless -t "<goal>" --json`) and a Python SDK. AgentHub can implement an `OpenHandsAdapter.psm1` conforming to `Resolve-AgentExecutionSpecification`, `Test-AgentExecutionSpecification`, and `Invoke-AgentExecutionSpecification` just like `CodexAdapter`.

### 8. Can AgentHub orchestrate independently installed Codex CLI and Claude Code while optionally delegating execution/workspace capabilities to OpenHands?
**YES.** This is AgentHub's core architectural strength. AgentHub acts as a neutral control plane:
- Task A can be assigned to `engine: codex` (invoking Codex CLI with local sandbox).
- Task B can be assigned to `engine: claude` (invoking Claude Code CLI).
- Task C can be assigned to `engine: openhands` (invoking OpenHands in Docker or local workspace).
All three pass through the exact same BDD contracts, readiness checks, budget gates, progress classifiers, guardrail audits, and evidence records.

### 9. Does OpenHands already provide an abstraction that could replace our planned AgentAdapter?
**NO.** OpenHands provides the Agent Client Protocol (ACP) and internal agent abstractions, but adopting OpenHands as AgentHub's internal adapter layer would force a heavy Python/Docker dependency onto users who only want to run native Codex CLI or Claude Code. AgentHub's lightweight Adapter boundary (process-based, provider-agnostic) is essential.

### 10. Can AgentHub reuse OpenHands without forcing Codex/Claude execution through OpenHands?
**YES.** By placing OpenHands behind the `AgentAdapter` interface, OpenHands becomes an *optional peer engine* alongside Codex and Claude. Users who do not install OpenHands can still use AgentHub with Codex CLI or Claude Code.

### 11. Which AgentHub capabilities are genuinely differentiated?
The following AgentHub capabilities do not exist in OpenHands or raw agent CLIs:
1. **Machine-Enforced BDD Task Contracts:** Strict JSON schema defining bounded contexts, file scope globs, and permitted capabilities.
2. **Deterministic Pre-Execution Discovery & Readiness:** Automatic zero-token inspection of runtimes, package managers, Compose, dependencies, and sandbox write capability before invocation.
3. **Task-Scoped Execution Budgets:** Atomic filesystem-locked gates requiring explicit human authorization before real spend.
4. **Contract-Aware Progress Classification:** Independent verification that changes touched only allowed files and produced valid implementation/test progress.
5. **Baseline Guardrail Audits:** Finding-identity regression checks preventing new security/quality violations.
6. **Immutable Evidence Artifacts:** Standardized `.agenthub-evidence-*.json` capturing end-to-end provenance for human signoff.

### 12. Which current AgentHub files/modules become redundant if OpenHands is integrated?
**NONE of the current AgentHub codebase becomes redundant.**
Every existing module (`BDDValidator`, `EnvironmentReadiness`, `ProjectEnvironmentDiscovery`, `ExecutionGate`, `ProgressClassifier`, `GuardrailGate`, `GlobalGuardrailAudit`, `AgentExecutionCore`, `agenthub.ps1`) performs governance and verification outside the agent loop. However, planned future roadmap features (such as internal LLM loops, SQLite task DAGs, and prompt engineering modules) are rendered obsolete and should be deleted from the roadmap.

### 13. Which completed capabilities should remain even if OpenHands is adopted?
**ALL completed capabilities must remain:**
- BDD v2 Contract Validation (`BDDValidator.psm1`)
- Environment Readiness Gate (`EnvironmentReadiness.psm1`)
- Project Environment Discovery (`ProjectEnvironmentDiscovery.psm1`)
- Execution Gate & Budget Persistence (`ExecutionGate.psm1`)
- Progress Classifier & Scope Gate (`ProgressClassifier.psm1`)
- Guardrail Baseline Gate (`GuardrailGate.psm1`, `GlobalGuardrailAudit.psm1`)
- Adapter Execution Core (`AgentExecutionCore.psm1`)
- Worktree Lifecycle & Evidence Logging (`agenthub.ps1`)

---

## 6. Cost, Lock-In, and Operational Analysis

### 6.1 Licensing & Software Costs
- **AgentHub:** Open Source (MIT / Apache-2.0 compatible).
- **OpenHands Local Stack:** Open Source (MIT License).
- **Orchestration SaaS:** $0. No subscription, SaaS token, or cloud platform is required for local execution.

### 6.2 Model Inference & API Costs
- When using **OpenHands Adapter**, API costs are paid directly to the chosen LLM provider (OpenAI, Anthropic, DeepSeek) or $0 when using local Ollama/vLLM.
- When using **Codex Adapter**, costs are governed by the user's OpenAI subscription or API key.
- When using **Claude Adapter**, costs are governed by the user's Anthropic credentials.
- **AgentHub Execution Budgets** guarantee that no agent can be invoked without explicit, bounded authorization.

### 6.3 Infrastructure & Platform Overhead
- **AgentHub Core:** Zero external dependencies (runs natively via PowerShell 7+ on Windows, Linux, macOS).
- **OpenHands Engine (Optional):** Requires Python 3.11+ and optional Docker daemon for container isolation.

---

## 7. Target Architecture: The Defensible AgentHub v1

```
                                 [TASK CONTRACT]
                           (BDD v2 JSON Schema Scope)
                                       |
                                       v
                    +-------------------------------------+
                    |       AGENTHUB CONTROL PLANE        |
                    +-------------------------------------+
                    | 1. Contract Validation              |
                    | 2. Project Environment Discovery    |
                    | 3. Environment Readiness Gate       |
                    | 4. Worktree Isolation Setup         |
                    | 5. Execution Budget Authorization   |
                    +-------------------------------------+
                                       |
                                       v
                      [AgentAdapter Execution Boundary]
                                       |
          +----------------------------+----------------------------+
          |                            |                            |
    [CodexAdapter]              [ClaudeAdapter]             [OpenHandsAdapter]
    - Codex CLI                 - Claude Code CLI           - OpenHands CLI / SDK
    - Local Windows Sandbox     - Local CLI Execution       - Docker / Local Runtime
          |                            |                            |
          +----------------------------+----------------------------+
                                       |
                                       v
                    +-------------------------------------+
                    |       POST-EXECUTION GOVERNANCE     |
                    +-------------------------------------+
                    | 6. Scope & Progress Classification  |
                    | 7. Deterministic Verification Tests |
                    | 8. Guardrail Baseline Audit         |
                    | 9. Evidence Persistence             |
                    +-------------------------------------+
                                       |
                                       v
                             [HUMAN REVIEW GATE]
                        (PR Ready / Handoff Evidence)
```

---

## 8. Roadmap Impact (P0 - P14 Delta)

### P0 — Operational Autonomy (Current Focus)
- **Repository Validation & Worktree Isolation:** **KEEP**. Finish remaining worktree ownership and repository state checks.
- **Environment Readiness & Discovery:** **KEEP (COMPLETED)**. Deterministic 0-token inspection is fully tested.
- **Artifact Classification:** **KEEP**. Implement lightweight file filtering (distinguishing `node_modules`, `target`, `.agenthub-*` from product files).

### P1 — Multi-Agent & Orchestration
- **Custom Agent Runtime / Prompt-Tool Loops:** **DELETE**. Never implement.
- **Custom Task DAG Engine:** **DELETE / DEFER**. Rely on single-contract execution and external pipelines.
- **OpenHands Adapter Integration:** **ADD (INTEGRATE)**. Implement `OpenHandsAdapter.psm1` to support OpenHands as an execution engine.

### P2 — Provider & Model Management
- **Raw LLM Model Routing (LiteLLM clone):** **DELETE**. Delegated to OpenHands / agent CLIs.
- **Claude Code CLI Adapter:** **KEEP (PLANNED)**. Implement `ClaudeAdapter.psm1` for Anthropic CLI support.

### P3 — Security, Governance & Verification
- **Guardrail Baseline Diffing:** **KEEP (COMPLETED)**.
- **Execution Budget Atomic Persistence:** **KEEP (COMPLETED)**.
- **Deterministic Verification Suites:** **KEEP (COMPLETED)**.

### P4-P14 — Extended Ecosystem
- **SQLite Database for Task DAGs:** **DELETE**. Task contracts and evidence JSON files provide sufficient auditability.
- **Learning & Memory Subsystems:** **DEFER**. Focus on human feedback loops and rejected/accepted contract evidence.
- **GitHub PR Automation:** **DEFER / REUSE**. Rely on OpenHands `github-resolver` or GitHub CLI (`gh pr create`) for remote operations.

---

## 9. Conclusion & Next Step Recommendation

AgentHub's product justification is clear and validated: **AgentHub is a governance and contract control plane, not an agent runtime.** 

OpenHands strengthens AgentHub by providing an open-source, model-agnostic execution engine that can be plugged in via an adapter, eliminating any need for AgentHub to build custom agent loops, prompt engineering systems, or container runners.

### Recommended Next Feature
Continue with the remaining bounded P0 roadmap feature:
**`P0_ARTIFACT_CLASSIFICATION`** (Distinguishing product changes from runtime/build artifacts to prevent disposable caches from triggering false scope violations).
