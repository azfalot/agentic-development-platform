---
name: e2e-validation
description: >-
  Use this skill to execute Playwright browser testing and collect machine-verifiable visual and trace evidence for user-facing features.
---

# Skill: E2E Validation

Playwright testing and evidence collection procedure.

## Inputs
- `test_suite_path` (string, optional)
- `base_url` (string, default: `http://localhost:3000` or `http://localhost:8080`)

## Procedure
1. **ENVIRONMENT READINESS:**
   - Ensure backend and frontend services are running and connected to `shared-postgres`.
   - Verify health probes respond with 200 OK.
2. **EXECUTE PLAYWRIGHT:**
   - Run tests with trace capture enabled:
     `pnpm exec playwright test --trace on` (or `npx playwright test`)
3. **COLLECT EVIDENCE:**
   - On success: Capture screenshot of final application state.
   - On failure: Inspect `test-results/` folder, extract failed screenshot and `trace.zip`.
4. **RECORD REPORT:**
   - Summarize passed tests, execution duration, and browser matrices.

## Definition of Done
- All critical user workflows pass in real browser engine.
- Artifacts (screenshots, logs, traces) attached to BDD handoff.
