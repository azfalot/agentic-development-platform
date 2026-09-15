# GLOBAL DEVELOPMENT POLICY — TESTING PYRAMID & RIGOR

This policy defines the automated testing standards and guarantees regression resistance across all projects.

---

## 1. TESTING PYRAMID

Every project must maintain a balanced testing strategy:

```text
       /\
      /  \       Playwright E2E Tests (Critical user paths & UI state)
     /────\
    /      \     API & Contract Tests (OpenAPI/HTTP endpoint contracts)
   /────────\
  /          \   Integration & DB Tests (Isolated against <project>_test DB)
 /────────────\
/              \ Unit Tests (Domain logic, services, utilities, edge cases)
────────────────
```

---

## 2. STRICT RULE: NO GREEN-BY-DELETION

* Agents are **strictly forbidden from weakening, commenting out, or deleting existing tests** simply to make CI or test suites green.
* If a test fails, the agent must identify the underlying root cause and fix the implementation or update the test only when the business specification has explicitly changed.

---

## 3. MANDATORY REGRESSION TESTS FOR BUG FIXES

* When fixing a bug, the agent must write an automated regression test reproducing the original defect **before** applying the fix.
* The test must fail before the fix and pass after the fix.

---

## 4. DATABASE TESTING ISOLATION

* Automated integration tests using PostgreSQL must connect to the project's dedicated test database (e.g. `hookr_test`, `convivia_test`).
* Tests must never execute destructive operations (`DROP`, `TRUNCATE`, bulk deletions) against the active development database (`hookr`, `convivia`).

---

## 5. SECURITY & NEGATIVE TESTING

* Include negative tests verifying authorization barriers, invalid inputs, unauthorized tenant access, and edge-case validation.
