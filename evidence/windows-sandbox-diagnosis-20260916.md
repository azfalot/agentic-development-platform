# Codex Windows workspace-write sandbox diagnosis

Date: 2026-09-16. This record contains no credentials or prompts that trigger model inference.

## Environment

- Windows 10 Pro 10.0.19045, PowerShell 7.6.5.
- Codex CLI 0.146.0, standalone Windows x86_64. `codex doctor --json` reports 0.154.0 available.
- Codex config parses successfully and contains `[windows] sandbox = "elevated"`.
- `codex exec --help` accepts `read-only`, `workspace-write`, and `danger-full-access`; it does not accept `elevated` as an exec sandbox argument.

## Independent non-model reproduction

The documented direct harness was invoked with the built-in `:workspace` profile in an empty temporary directory:

```text
codex sandbox --permission-profile :workspace --cd <empty-temp-dir> -- C:\Windows\System32\cmd.exe /d /c "echo AGENTHUB_SANDBOX_PROBE_OK"
```

It exits 1 with:

```text
windows sandbox failed: CreateProcessWithLogonW failed: 2
```

The same result occurs with Windows PowerShell and Codex's bundled PowerShell. Both executables launch successfully outside Codex sandboxing. Therefore error 2 is raised by the restricted-token sandbox process-creation path before the requested child executes; it is not a missing requested executable, worktree path, or prompt/argument boundary defect.

## Preserved prior execution evidence

- Failed workspace-write agent execution stderr: `C:\Users\Hokaido\AppData\Local\Temp\ahrealretry-8372a7dd-6616-48b2-89eb-8e56b57f9b40\.agenthub-worktrees\real-retry\.agenthub-codex.stderr.log`.
- Invalid `--sandbox elevated` execution evidence: `C:\Users\Hokaido\AppData\Local\Temp\agenthub-real-e2e-0567f3fb-3d57-4cc6-aa73-cfb94d2de60e\.agenthub-worktrees\real-e2e\.agenthub-evidence-20260916001623525.json`.

No evidence files were deleted or overwritten.

## AgentHub preflight behavior

`CodexAdapter.psm1` now exposes a non-model `Test-CodexWorkspaceSandbox` probe. `agenthub preflight` reports `cli_accepted` separately from `sandbox_operational`; its latter value is false on this host and includes the direct-harness failure. AgentHub remains unable to dispatch real tasks with the zero execution budget.

## Classification and readiness

Classification: `CODEX_WINDOWS_SANDBOX_DEFECT`.

Readiness: no. The CLI accepts the workspace-write argument, but sandbox operation is independently disproven. Safe remediation is to update Codex to the doctor-reported current version and rerun this same direct non-model probe. Do not weaken to `danger-full-access` or disable sandboxing.
