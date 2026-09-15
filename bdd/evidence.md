# Behaviour Domain Driver (BDD) — Evidence Standards

This document establishes what constitutes acceptable, machine-verifiable evidence across this platform.

---

## 🚫 Unacceptable Evidence
* Assertions like "The feature works as expected".
* Assertions like "All tests pass" without attaching the command output or test log.
* Claims that a bug was fixed without a failing-then-passing regression test.
* PRs claiming visual UI readiness without screenshots or Playwright traces.

---

## ✅ Acceptable Evidence Types

| Evidence Category | Required Format / Artifact | Verification Mechanism |
| :--- | :--- | :--- |
| **Unit & Integration Tests** | Full test runner output log (`npm test`, `mvn test`, `pytest`). | Exit code 0, test count, 0 failures/errors. |
| **Playwright E2E** | Final state screenshot (`.png`), trace file (`trace.zip`), test summary JSON. | Machine inspection of trace actions & visual snapshot. |
| **Database Migrations** | `psql` schema check, Flyway/Liquibase migration output. | Tables/columns exist in `<project>` / `<project>_test`. |
| **CI Pipeline** | GitHub Actions Run ID / URL and conclusion status. | `gh pr checks <id>` returns `pass` on all rollup items. |
| **Git History** | Commit SHA, clean working tree output (`git status -sb`). | Machine-verifiable commit in remote branch. |
| **Bug Fix Verification** | Regression test log showing **FAIL** before fix and **PASS** after fix. | Diff showing added test + runner output. |
