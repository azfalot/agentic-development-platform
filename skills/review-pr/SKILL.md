---
name: review-pr
description: >-
  Use this skill to conduct a zero-trust, independent code review on a pull request, inspecting diffs, tests, architecture, migrations, and CI status.
---

# Skill: Review Pull Request

Zero-trust independent review protocol for peer agents and human developers.

## Golden Rule
**NEVER TRUST:**
- The PR description author assertions.
- Claims that "tests pass" without verifying machine-verifiable evidence.
- Summaries that omit database migration or security impact.

## Inputs
- `pr_number` / `pr_url` (string, required)

## Procedure
1. **FETCH PR & DIFF:**
   `gh pr view <pr_number> --json number,title,headRefName,baseRefName,commits,files,reviews,statusCheckRollup`
   `gh pr diff <pr_number>`
2. **INSPECT ISSUE & ACCEPTANCE CRITERIA:**
   Verify if the diff completely and accurately addresses the original requirements.
3. **INSPECT ARCHITECTURE & BOUNDARIES:**
   - Are domain boundaries respected?
   - Are new dependencies justified?
   - Is an ADR required and present?
4. **INSPECT TESTS & VERIFY NO GREEN-BY-DELETION:**
   - Did the author delete or weaken any tests?
   - Are new edge cases covered by unit/integration tests?
5. **INSPECT DATABASE MIGRATIONS & DOCKER:**
   - Ensure NO new postgres service or container was added.
   - Verify migration is backward-compatible and idempotent.
6. **INSPECT SECURITY:**
   - No hardcoded secrets, no SQL injection risks, tenant filters enforced.
7. **VERIFY CI STATUS:**
   - Check status check rollup: all required jobs must be green.
8. **EMIT REVIEW DECISION:**
   - `APPROVE`: All criteria met, verifiable evidence attached.
   - `REQUEST_CHANGES`: Specific, actionable feedback referencing exact lines.
   - `BLOCKED`: Critical policy violation (e.g. duplicate postgres container, security flaw).

## Required Output
- Structured review comment posted via `gh pr review <pr_number> --comment -b "..."` or `--approve` / `--request-changes`.
