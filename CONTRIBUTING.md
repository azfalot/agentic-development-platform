# Contributing

Use Windows PowerShell and run `pwsh -NoProfile -File .\scripts\test.ps1` before opening a pull request. Keep tests deterministic: CI must not invoke a model, consume API quota, or require credentials.

Changes to execution routing, budgets, or sandbox behavior require a regression test and evidence that distinguishes capability discovery from a real model invocation. Do not commit personal paths, account data, secrets, or raw local process logs.
