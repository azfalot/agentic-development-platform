---
name: investigate-bug
description: >-
  Use this skill to diagnose and resolve software defects through reproducible reproduction, root-cause analysis, and regression tests.
---

# Skill: Investigate Bug

Systematic bug resolution workflow preventing speculative or random trial-and-error fixes.

## Flow Overview
```text
REPRODUCE ➔ COLLECT EVIDENCE ➔ ROOT CAUSE ➔ REGRESSION TEST ➔ MINIMAL FIX ➔ VERIFY ➔ DOCUMENT
```

## Inputs
- `bug_report` / `issue_id` (string, required)
- `stack_trace` / `error_log` (string, optional)

## Procedure
1. **REPRODUCE:**
   - Set up exact environment and inputs described in the report.
   - Run the application or test suite to observe the failure directly.
2. **COLLECT EVIDENCE:**
   - Capture stack traces, server logs, network payload, or database query logs.
3. **IDENTIFY ROOT CAUSE:**
   - Trace the exact line and logic causing the invalid state.
   - Do NOT apply random changes hoping the error disappears.
4. **WRITE REGRESSION TEST:**
   - Create an automated unit or integration test that exercises the defect.
   - Run the test and confirm it **FAILS** (demonstrating reproduction).
5. **APPLY MINIMAL FIX:**
   - Modify only the specific code required to correct the root cause.
6. **VERIFY:**
   - Run the regression test and confirm it now **PASSES**.
   - Run the full project test suite to verify no regressions were introduced.
7. **DOCUMENT & COMMIT:**
   - Commit with: `fix(<scope>): <description> (Closes #<id>)`
   - Include root cause explanation in commit body.
