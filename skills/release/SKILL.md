---
name: release
description: >-
  Use this skill to execute a safe software release, generate changelogs, tag versions, and verify release artifacts.
---

# Skill: Release

Structured procedure for tagging and delivering versioned software releases.

## Preconditions
- `main` branch is green and all CI checks pass.
- No unmerged blockers or open critical bugs.

## Procedure
1. **DETERMINE SEMVER:**
   - Analyze commit history since last tag (`feat` -> MINOR, `fix` -> PATCH, `BREAKING CHANGE` -> MAJOR).
2. **UPDATE CHANGELOG & VERSION:**
   - Update `CHANGELOG.md` with categorized changes.
   - Update project version descriptor (`package.json`, `pom.xml`, `pyproject.toml`).
3. **COMMIT & TAG:**
   `git add CHANGELOG.md package.json`
   `git commit -m "chore(release): vX.Y.Z"`
   `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
4. **PUSH & RELEASE:**
   `git push origin main --tags`
   `gh release create vX.Y.Z --notes-file CHANGELOG.md`
5. **VERIFY POST-RELEASE CI:**
   - Confirm release build and docker packaging workflows pass successfully.
