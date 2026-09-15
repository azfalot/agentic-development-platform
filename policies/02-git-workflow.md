# GLOBAL DEVELOPMENT POLICY — GIT & PULL REQUEST WORKFLOW

This policy defines the mandatory version control and collaboration standards for all agents in this environment.

---

## 1. NEVER DEVELOP DIRECTLY ON MAIN

* Direct commits to `main` (or `master`) are **strictly prohibited**.
* All work must originate from an issue/task, progress through a dedicated feature or fix branch, and land via a Pull Request.

---

## 2. BRANCH NAMING CONVENTIONS

Branches must follow structured prefixes:
* `feature/<issue-number>-<short-description>` (e.g., `feature/42-guest-invitations`)
* `fix/<issue-number>-<short-description>` (e.g., `fix/89-login-race-condition`)
* `refactor/<short-description>`
* `chore/<short-description>`

---

## 3. ATOMIC & CONVENTIONAL COMMITS

Commits must follow Conventional Commits standard:
```text
<type>(<scope>): <short description in imperative mood>

[optional body explaining motivation and architectural rationale]

[optional footer: Closes #42]
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`.

* Commits must be atomic: do not bundle unrelated refactorings or formatting changes with feature logic.

---

## 4. PULL REQUEST REQUIREMENTS

Every PR must contain:
1. **Summary of Changes:** What was implemented and why.
2. **Acceptance Criteria Verification:** Checklist of fulfilled requirements.
3. **Machine-Verifiable Evidence:** Test logs, Playwright traces/screenshots, or CI run IDs.
4. **Impact Assessment:** Database migrations, breaking changes, or configuration additions.
5. **Behaviour Domain Driver (BDD) Handoff Block:** Standardized metadata for peer review.

---

## 5. REVIEW & AUTONOMOUS MERGE PROTOCOL

* Agents must **NEVER silently self-merge** their own PRs unless the project's configuration explicitly enables autonomous merging for specific automated tasks.
* Peer review (by human developer or designated reviewer agent) requires independent inspection of the diff, test evidence, CI status, and security implications.

---

## 6. CLEANUP & POST-MERGE PROTOCOL

* After a PR is successfully merged to `main`:
  1. Pull latest `main` with `--ff-only`.
  2. Delete local and remote feature branch.
  3. Verify clean working tree (`git status -sb`).

---

## 7. CONFLICT RESOLUTION & ROLLBACK STRATEGY

* Rebase or merge `main` into the feature branch when conflicts arise; never force-push to `main`.
* If a merged PR introduces a production/staging defect, execute an atomic revert (`git revert -m 1 <commit-sha>`) via a dedicated fix PR rather than applying hasty forward hotfixes without tests.
