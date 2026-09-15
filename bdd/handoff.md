# DEPRECATED: Behaviour Domain Driver (BDD) — Standard Handoff Protocol

> New contracts use the canonical v2 handoff fields in [`v2/SEMANTICS.md`](./v2/SEMANTICS.md). `WAITING_REVIEW` is not a valid v2 state; use `REVIEWING` or `READY_FOR_HUMAN` as applicable.

Every agent must generate this standardized handoff payload upon completing work or handing over to a peer agent.

---

## Handoff Template

```markdown
## 🤝 BDD Handoff Report

* **Agent ID / Role:** `[e.g. codex-implementer-1 / Implementer]`
* **Project / Branch:** `[e.g. convivia / feature/42-guest-tokens]`
* **Issue / Goal:** `[e.g. #42 / Implement expiring guest invitation tokens]`
* **State:** `[DONE | WAITING_REVIEW | BLOCKED]`

### 1. Summary of Changes
- [Brief bulleted summary of functional changes]

### 2. Files & Modules Modified
- `services/api/src/main/java/com/convivia/identity/...`
- `apps/web/src/features/invitations/...`
- `db/migration/V4__guest_tokens.sql`

### 3. Machine-Verifiable Evidence
* **Commit SHA:** `[e.g. 8a7b6c5d4e3f]`
* **Pull Request:** `[e.g. https://github.com/azfalot/convivia/pull/48]`
* **Tests Passed:** `[e.g. 14 unit tests, 3 integration tests (IdentityModuleTests)]`
* **Test Output Log:** `[attached / path / link]`
* **Playwright Evidence:** `[Screenshot: /evidence/modal.png, Trace: /evidence/trace.zip]`
* **CI Status:** `[SUCCESS (GitHub Actions Run #123456)]`

### 4. Known Risks & Considerations
- [e.g. Requires migration V4 to run before backend deployment]

### 5. Recommended Next Action
- [e.g. Antigravity architecture review & approval on PR #48]
```
