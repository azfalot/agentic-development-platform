# AgentHub — Agentic Development Platform

[![Status](https://img.shields.io/badge/Status-P0%20Operational%20Autonomy%20Complete-brightgreen.svg)](docs/ROADMAP_TO_V1.md)
[![Tests](https://img.shields.io/badge/Tests-17%20Deterministic%20Suites%20Passing-success.svg)](scripts/test.ps1)
[![Cost](https://img.shields.io/badge/Test%20Cost-0%20Tokens-blue.svg)](tests/p0-vertical-flow.tests.ps1)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20PowerShell%207%2B-informational.svg)](scripts/agenthub.ps1)

**AgentHub** is a deterministic, fail-closed **governance and control plane** for autonomous coding agents. It orchestrates task contracts, verifies environment readiness, isolates execution in dedicated Git worktrees, enforces bounded-context file scopes, runs independent verification suites, and produces human-reviewable evidence without model self-certification.

---

## 🎯 Architectural Principles

1. **Lightweight Governance / Control Plane:** AgentHub enforces the Task Contract and safeguards the repository. It does not implement internal LLM loops or prompt templates; external agents (e.g., Codex, OpenHands) run via isolated, pluggable `AgentAdapter` boundaries.
2. **Deterministic & Zero-Token Testing:** The entire AgentHub control-plane test suite (17 test suites, including vertical flow scenarios A–K) executes deterministically with **zero model invocations** and **zero token consumption**.
3. **Fail-Closed by Design:** Any uncertainty in repository state, tool readiness, file scope, test results, or worktree ownership prevents task completion (`READY_FOR_HUMAN`) and leaves the repository clean.
4. **Strict Project Agnosticism:** AgentHub is completely decoupled from downstream target projects. Real projects are consumers of AgentHub, never hardcoded fixtures or dependencies.

---

## 🔄 End-to-End Control Plane Lifecycle

```
Task Contract
     ↓
Repository Resolution  (Branch / Remote / Clean Git Tree Verification)
     ↓
Environment Discovery  (Deterministic Runtime, Dependency & Service Detection)
     ↓
Environment Readiness  (Readiness Gate & Policy-Governed Preparation)
     ↓
Worktree Isolation     (Dedicated .agenthub-worktrees/<task-id>)
     ↓
Budget Lock & Gate     (Atomic Token / Invocation Budget Gate)
     ↓
Agent Execution        (Isolated AgentAdapter Process Execution)
     ↓
Artifact Classification (Distinguishes Product, Tests, Docs, Disposable Caches)
     ↓
Automatic Validation   (Deterministic Multi-Category Verification Suite)
     ↓
Guardrails Evaluation  (Baseline Diff & Regression Detection)
     ↓
Minimal Git Completion (Selective Staging of Authorized Files & Local Commit)
     ↓
READY_FOR_HUMAN        (Machine-Readable Evidence Package for Human Review)
```

---

## 🚀 Key Capabilities (P0 Complete)

* **Repository Resolution (`RepositoryResolution.psm1`):** Resolves canonical repo identity, verifies working tree cleanliness, validates base branch tracking, and ensures safe worktree isolation.
* **Project Environment Discovery (`ProjectEnvironmentDiscovery.psm1`):** Automatically detects project runtime ecosystems (Node.js, Python, Java, .NET, Rust, Go), package managers, Docker services, and test suites.
* **Environment Readiness (`EnvironmentReadiness.psm1`):** Evaluates command prerequisites, dependency installations, and HTTP service health checks before spending execution budget.
* **Artifact Classification & Disposable Filtering (`ArtifactClassification.psm1`):** Categorizes changes into `PRODUCT_CHANGE`, `TEST_CHANGE`, `DOCUMENTATION_CHANGE`, `DEPENDENCY_ARTIFACT`, `BUILD_ARTIFACT`, `TEST_ARTIFACT`, and `AGENTHUB_EVIDENCE`. Prevents disposable caches (e.g. `.npm-cache/`, `target/`) from triggering false scope violations.
* **Automatic Validation Collection (`ValidationCollection.psm1`):** Executes verification commands independently of agent self-reporting, capturing exit codes, durations, and output streams into structured evidence.
* **Minimal Git Completion (`GitCompletion.psm1`):** Stages strictly authorized, scope-relevant files (excluding all disposable artifacts and AgentHub metadata) and generates a single local commit with deterministic trailers (`Task-Id`, `Role`, `Engine`, `Validation`).

---

## 📋 Requirements

* **Windows 10/11** or **Windows Server**
* **PowerShell 7+** (`pwsh`) or **PowerShell 5.1+**
* **Git 2.30+**
* External Agent CLI (such as OpenAI Codex CLI) available on `PATH` for live agent execution.

---

## 🛠️ Getting Started

### 1. Run Diagnostics (No Model Inference)

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 doctor
```

Inspects PowerShell version, Git availability, AgentAdapter discovery, sandbox capabilities, and guardrail baseline status.

### 2. Validate a Task Contract

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 validate .\examples\calculator\TASK_CONTRACT.json
```

Validates contract schema compliance, scope definitions, required verification categories, and permissions.

### 3. Check Task Status & Budget

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 status .\examples\calculator\TASK_CONTRACT.json
```

Displays task metadata, current lifecycle state, assigned engine, and execution budget allocation.

### 4. Execute Full Deterministic Test Suite

```powershell
pwsh -NoProfile -File .\scripts\test.ps1
```

Runs all 17 deterministic acceptance test suites (100% offline, 0 tokens consumed).

---

## 📁 Repository Structure

```
├── bdd/                    # BDD v2 JSON Schemas & Validation Contracts
├── docs/                   # Architecture, Roadmap, and Fit-Gap Analyses
│   ├── ARCHITECTURE.md
│   ├── ROADMAP_TO_V1.md    # Living v1 milestone progress
│   └── architecture/       # Architectural ADRs & Fit-Gap Reviews
├── examples/               # Generic reference projects (e.g. calculator)
├── guardrails/             # Guardrail baseline definitions
├── policies/               # Global development policies & rules
├── scripts/                # AgentHub core modules & CLI
│   ├── agenthub.ps1        # Primary AgentHub Control Plane CLI
│   ├── AgentExecutionCore.psm1
│   ├── ArtifactClassification.psm1
│   ├── CodexAdapter.psm1
│   ├── EnvironmentReadiness.psm1
│   ├── ExecutionGate.psm1
│   ├── GitCompletion.psm1
│   ├── ProgressClassifier.psm1
│   ├── ProjectEnvironmentDiscovery.psm1
│   ├── RepositoryResolution.psm1
│   ├── ValidationCollection.psm1
│   └── test.ps1            # Test harness running all test suites
└── tests/                  # Deterministic test suites (A-Z matrices & vertical flow)
```

---

## 🛡️ Safety, Review & Governance

* **Human-in-the-Loop:** AgentHub never auto-merges, force-pushes, or deletes branches. The human engineer remains the sole authority for PR approval and production deployments.
* **Isolated Worktrees:** Every task executes in its own isolated worktree (`.agenthub-worktrees/<task-id>`) to prevent interference with the main working directory.
* **Cryptographic Evidence Audit:** Every lifecycle transition is recorded with SHA-256 hashes of contracts, manifests, logs, diffs, and git commits in `.agenthub-evidence-*.json`.

---

## 📜 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
