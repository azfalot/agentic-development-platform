# GLOBAL DEVELOPMENT POLICY — END-TO-END & PLAYWRIGHT VALIDATION

This policy governs the verification of user-facing workflows across web and mobile applications.

---

## 1. EVIDENCE STANDARD FOR USER WORKFLOWS

* An agent must **never claim "the feature works"** solely because unit tests pass or the code compiles when the change alters a user workflow or visual interface.
* User-facing features require machine-verifiable end-to-end evidence.

---

## 2. PLAYWRIGHT STANDARDS

When Playwright (or the project's established E2E framework) is present:
* Tests must run against realistic rendering engines (Chromium/Firefox/WebKit).
* Evidence must be captured and recorded:
  - Screenshots of final state or critical modal interactions.
  - Playwright Traces (`trace.zip`) on failure or for high-risk changes.
  - Console logs / network HAR files where API interactions are involved.

---

## 3. FLAKINESS PREVENTION

* Avoid arbitrary sleep delays (`await page.waitForTimeout(5000)`).
* Use deterministic web assertions based on locator state (`await expect(page.getByRole('button')).toBeVisible()`).
* Ensure test fixtures clean up their own test state or use isolated tenant/user accounts.
