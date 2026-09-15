# Behaviour Domain Driver (BDD) — Agent Collision Prevention

This protocol prevents two autonomous agents from making conflicting changes to the same critical codebase area in parallel.

---

## 🔒 Protected Core Areas (High Collision Risk)

1. **Database Migrations:** Sequential version numbers (e.g. `V5__...`).
2. **Security & Identity:** Authentication interceptors, JWT parsers, role guards.
3. **Shared Domain Kernels:** Core data entities used across multiple bounded contexts.
4. **Build & Infrastructure:** `docker-compose.yml`, root `package.json`, CI workflows.

---

## 🛑 Collision Protocol

Before creating a branch or modifying code:
1. **Query Remote State:**
   `gh pr list --state open`
   `git branch -r`
2. **Inspect Overlap:**
   - Does an open PR or active branch touch the same bounded context or migration sequence?
3. **If Overlap Exists:**
   - **DO NOT** attempt to write conflicting migrations or duplicate code.
   - Transition BDD state to `BLOCKED`.
   - Output Conflict Notification:
     ```text
     ⚠️ BDD COLLISION DETECTED
     Target: Migration sequence V5 in project 'convivia'
     Active Conflict: PR #45 (Branch: feature/45-user-roles) by agent Codex-1
     Resolution: Awaiting merge of PR #45 before rebasing and continuing.
     ```
