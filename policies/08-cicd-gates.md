# GLOBAL DEVELOPMENT POLICY — CI/CD GATES & QUALITY ENFORCEMENT

This policy defines the continuous integration standards and release criteria.

---

## 1. MANDATORY CI GATES

Every Pull Request must pass the following pipeline stages before merge approval:

```text
1. Build & Compilation Verification
2. Static Analysis & Linting (ESLint, Checkstyle, Ruff, etc.)
3. Unit Tests Suite
4. Integration & Database Tests Suite
5. Security Scanning & Dependency Vulnerability Check
6. E2E Validation (for critical user-facing paths)
7. Artifact & Packaging Verification
```

---

## 2. STRICT RULE: NO DISABLING FAILING CHECKS

* Agents must **never disable, bypass, or comment out CI checks, linter rules, or test steps** to get a pipeline to pass.
* If a check fails in CI, the agent must inspect the CI log, reproduce the issue locally, and provide a root-cause fix.

---

## 3. DETERMINISTIC REPRODUCIBILITY

* Lockfiles (`pnpm-lock.yaml`, `package-lock.json`, `poetry.lock`, `Cargo.lock`) must always be committed and synchronized.
* CI builds must use `--frozen-lockfile` / deterministic installation flags.
