# Agentic Development Platform

`v0.1.0-alpha` is a Windows-first, local toolkit for governing small, human-approved coding tasks performed by an agent. It supplies BDD v2 contracts, scoped worktree execution, an explicit invocation budget, evidence records, and deterministic PowerShell tests.

This is an alpha for dogfooding, not an autonomous delivery system. Codex CLI is the only proven runtime path. Other engines and GitHub orchestration are not implemented.

## What it does

- Validates BDD v2 task contracts before work begins.
- Routes execution through a provider adapter, preserving argument boundaries.
- Requires a branch, file scope, permissions, and an explicit execution budget.
- Produces evidence for a human reviewer; it never auto-merges or approves work.
- Runs deterministic validation without a model or API call.

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Git
- Codex CLI on `PATH` only when using real agent execution

Run local diagnostics (no model inference):

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 doctor
```

The report shows PowerShell, Git, Codex availability/version, advertised sandbox capability, `AGENT_PLATFORM_HOME`, configuration presence, and the guardrail baseline. It is diagnostic-only: a reported capability is not proof that a model task will succeed.

## Install and test from a clean clone

```powershell
git clone https://github.com/azfalot/agentic-development-platform.git
Set-Location agentic-development-platform
$env:AGENT_PLATFORM_HOME = Join-Path $HOME '.agent-platform'
pwsh -NoProfile -File .\scripts\bootstrap.ps1 -ConfirmInstall
pwsh -NoProfile -File .\scripts\test.ps1
```

`bootstrap.ps1` copies the public platform into `AGENT_PLATFORM_HOME` (or `~\.agent-platform`) and stops if that destination already exists. Choose another empty directory to install a separate copy; no overwrite option exists.

Validate a contract without execution:

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 validate .\examples\calculator\TASK_CONTRACT.json
```

Inspect a valid contract without modifying it or starting an engine:

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 status .\examples\calculator\TASK_CONTRACT.json
```

`status` prints the task ID, lifecycle state, assigned role and engine, repository, bounded context, and the task's execution-budget state when a budget exists.

`preflight` tests the configured runtime and its sandbox without requesting model work. `run` can invoke a real agent only after a human creates an execution budget; it costs whatever the selected Codex account/plan charges and may alter files in the contract's scoped worktree. Review its evidence and changes before any merge.

## Tiny example

[`examples/calculator`](examples/calculator) contains a calculator module, tests, BDD v2 task contract, and verification configuration. The example's normal test command is entirely local; it creates no execution budget and makes no model call.

## Safety and known limits

- A human must approve any real invocation, review, merge, and release.
- Concurrent tasks targeting the same ownership path collide by design and are rejected.
- The execution budget is persisted atomically and consumed before a real run; a failed persistence attempt must not spawn a process.
- The repository ships an empty public guardrail baseline. The historical 24 local findings were an environment baseline, not defects in this public repository.
- Windows is the supported alpha target. macOS/Linux portability, providers beyond Codex, hosted GitHub workflows, and autonomous remediation are future work.

Historic failure/retry evidence is published in sanitized form at [`evidence/public-alpha-v01-package.md`](evidence/public-alpha-v01-package.md). It documents the prior Windows argument-boundary failure and the corrected successful retry without publishing workstation paths, account data, or credentials.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Manual](docs/MANUAL.md)
- [Dogfooding results](docs/DOGFOODING.md)
- [Commercialization proposal](docs/COMMERCIALIZATION.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [License](LICENSE)
