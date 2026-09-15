---
name: architecture-review
description: >-
  Use this skill to audit system architecture, review ADR compliance, detect technical debt, and ensure bounded context boundaries are intact.
---

# Skill: Architecture Review

Comprehensive audit procedure for system structure and technical governance.

## Inputs
- `project_path` (string, required)

## Procedure
1. **MAP BOUNDED CONTEXTS:**
   - Review package structures, module dependencies, and service boundaries.
   - Detect circular dependencies or leaking internal domain models.
2. **AUDIT ADRs:**
   - Compare existing records in `docs/adr/` against current codebase implementation.
   - Flag deprecated practices or undocumented architectural changes.
3. **INFRASTRUCTURE & DOCKER AUDIT:**
   - Confirm adherence to shared infrastructure policies (`shared-postgres`, `dev-network`).
4. **EMIT ARCHITECTURE REPORT:**
   - Document strengths, risks, compliance state, and recommended refactorings.
