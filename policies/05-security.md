# GLOBAL DEVELOPMENT POLICY — SECURITY & SECURE DEFAULTS

This policy defines mandatory security standards across all codebases.

---

## 1. ZERO COMMITTED SECRETS

* Hardcoded secrets, API tokens, JWT private keys, certificates, or database passwords must **never** be committed to version control.
* All configuration must be supplied via environment variables (`.env`, `.env.example` with dummy values) or a secret manager.

---

## 2. AUTHENTICATION & AUTHORIZATION BOUNDARIES

* Enforce strict role-based or permission-based access control at the service layer, not just the UI layer.
* Never trust client-supplied user IDs or tenant IDs; derive them cryptographically from authenticated session tokens.

---

## 3. MULTI-TENANT ISOLATION

* In multi-tenant systems, all database queries and repository operations must include explicit tenant filtering (`tenant_id = :tenantId`).
* Cross-tenant data leakage is considered a critical P0 vulnerability.

---

## 4. INPUT VALIDATION & SANITIZATION

* Validate all external inputs at the system boundary using schemas (Zod, Bean Validation, Pydantic, OpenAPI).
* Prevent SQL Injection by always using parameterized queries and ORM abstractions.
* Sanitize user input before rendering in web contexts to prevent XSS.

---

## 5. LEAST PRIVILEGE & LOGGING SAFETY

* Database connections and background jobs must run with the least required privileges.
* Sensitive fields (passwords, tokens, credit card numbers, PII) must be masked and never emitted in application logs.
