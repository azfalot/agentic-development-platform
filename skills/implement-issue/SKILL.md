---
name: implement-issue
description: >-
  Use this skill to execute end-to-end implementation of an issue or feature from planning and branching through testing, PR creation, and handoff.
---

# Skill: Implement Issue

The core implementation workflow following the Behaviour Domain Driver (BDD) contract.

## Flow Overview
```text
READ ➔ UNDERSTAND ➔ INSPECT ➔ PLAN ➔ BRANCH ➔ IMPLEMENT ➔ TEST ➔ E2E ➔ DOCS ➔ COMMIT ➔ PUSH ➔ PR ➔ CI ➔ EVIDENCE ➔ HANDOFF
```

## Inputs
- `issue_id` / `issue_url` (string, required)
- `acceptance_criteria` (array of strings, required)
- `target_bounded_context` (string)

## Preconditions
- Repository clean on `main`.
- Up-to-date repository status (`git pull --ff-only origin main`).
- No active lock/collision on target bounded context.

## Procedure
1. **READ & UNDERSTAND:** Analyze issue requirements and acceptance criteria.
2. **INSPECT:** Search codebase, existing ADRs, test suites, and database models.
3. **PLAN:** Formulate technical implementation plan. Transition BDD state to `PLANNING`.
4. **BRANCH:** Create dedicated branch: `feature/<issue-id>-<short-description>`.
5. **IMPLEMENT:** Apply minimal, clean code changes. Transition BDD state to `IMPLEMENTING`.
6. **TEST:**
   - Write unit tests covering new logic and edge cases.
   - Write/update integration tests using test DB (`<project>_test`).
   - Run full test suite locally. Transition BDD state to `TESTING`.
7. **E2E (if user-facing):** Run Playwright suite and record screenshot/trace evidence.
8. **DOCUMENT:** Update `README.md`, OpenAPI contracts, and create ADR if architectural boundaries changed.
9. **COMMIT:** Atomic Conventional Commits (`feat(...)`, `test(...)`).
10. **PUSH & PR:** Push branch and open GitHub PR with BDD template:
    `gh pr create --title "feat(...): ..." --body "..."`
11. **CI WATCH:** Monitor CI run: `gh pr checks <pr-number> --watch`. Transition state to `WAITING_CI`.
12. **HANDOFF:** Compile BDD handoff payload with machine-verifiable evidence. Transition state to `DONE`.

## Required Evidence
- Full local test suite execution log.
- Playwright trace / screenshot (if frontend changes).
- GitHub PR URL and commit SHA.
- GitHub Actions CI status (`SUCCESS`).

## Failure Handling
- If CI fails: Reproduce failure locally, fix root cause, commit, push, and re-watch. Never disable tests or bypass gates.
- If collision detected: Transition to `BLOCKED`, emit conflict report, and await coordination.
