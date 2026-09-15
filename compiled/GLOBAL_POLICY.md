# PERSONAL AGENTIC DEVELOPMENT PLATFORM v1 — GLOBAL POLICIES

> Compilado automaticamente desde C:\Users\Hokaido\.agents\policies. NO editar manualmente.


---

# GLOBAL DEVELOPMENT POLICY — SHARED POSTGRESQL

This policy is **mandatory for every project and every coding agent** working in my local development environment.

The objective is to prevent each project, agent, Docker Compose stack, test environment, or generated setup from creating its own PostgreSQL instance.

## 1. SINGLE SHARED POSTGRESQL INSTANCE

There is already a centralized PostgreSQL development instance running on this machine.

**DO NOT create another PostgreSQL instance.**

This applies to:
* Docker Compose
* Docker containers
* local services
* development environments
* generated scaffolding
* bootstrap scripts
* Makefiles
* devcontainers
* IDE configurations
* agent-generated infrastructure
* E2E environments
* integration-test environments

Unless explicitly authorized, there must be **ONE PostgreSQL server for local development**.

---

## 2. CONNECTION DETAILS

### Applications running directly on the host (Windows)
```text
Host: localhost
Port: 5432
User: postgres
Password: <LOCAL_POSTGRES_PASSWORD>
Database: <project_database>
Connection URL: postgresql://postgres:<LOCAL_POSTGRES_PASSWORD>@localhost:5432/<project_database>
```

### Applications running inside Docker
Preferred configuration:
```text
Host: shared-postgres
Port: 5432
User: postgres
Password: <LOCAL_POSTGRES_PASSWORD>
Database: <project_database>
Connection URL: postgresql://postgres:<LOCAL_POSTGRES_PASSWORD>@shared-postgres:5432/<project_database>
```

The container must join the existing external Docker network:
```yaml
networks:
  dev-network:
    external: true
```

Example `docker-compose.yml`:
```yaml
services:
  app:
    build: .
    environment:
      DATABASE_URL: postgresql://postgres:<LOCAL_POSTGRES_PASSWORD>@shared-postgres:5432/my_project
    networks:
      - dev-network

networks:
  dev-network:
    external: true
```

Alternative only when required: `host.docker.internal:5432`.
Always prefer `shared-postgres` through `dev-network`.

---

## 3. DATABASE ISOLATION

Each project gets its **own database**, not its own PostgreSQL server.

Example:
```text
ONE PostgreSQL server (localhost:5432 / shared-postgres:5432)
        │
        ├── hookr
        ├── campulse
        ├── licitaia
        ├── aiecrf
        └── convivia
```

Never solve database isolation by creating additional PostgreSQL containers.

---

## 4. STRICT DOCKER COMPOSE RULE

Before modifying any `docker-compose.yml`, `compose.yml`, devcontainer, Docker script, or infrastructure configuration:

**Check whether PostgreSQL is being declared as a service.**

Configurations such as:
```yaml
services:
  postgres:
    image: postgres
```
or:
```yaml
services:
  db:
    image: postgres:...
```
are **STRICTLY PROHIBITED for local development**.

Remove or replace them with the shared PostgreSQL connection.
Do not expose another `5432`, `5433`, `5434`, etc. simply to avoid a port conflict.
The solution is to reuse `shared-postgres`.

---

## 5. NEW PROJECT BOOTSTRAP

Whenever creating or configuring a new project:
1. Determine a stable database name from the project name (e.g. `mi_proyecto`).
2. Assume that database will be created in the shared PostgreSQL instance.
3. Configure the application to use it.
4. If the application runs in Docker, attach it to `dev-network`.
5. Configure migrations normally using the project's migration framework.
6. Verify connectivity.
7. Run migrations.
8. Run integration/E2E tests.
9. Document the database name and connection mechanism in the project's README.

Do **not** bootstrap another PostgreSQL server.

---

## 6. MIGRATIONS REMAIN PROJECT-SPECIFIC

Sharing PostgreSQL does NOT mean sharing schemas or migrations.
Each project owns its own database and migration history.
Never apply one project's migrations to another project's database.

---

## 7. TESTING POLICY

Do not automatically create a permanent PostgreSQL container just for tests.
Prefer:
```text
shared PostgreSQL → project_test database (e.g. hookr_test, convivia_test, aiecrf_test)
```

Tests must remain isolated from development data.
Agents must never run destructive tests against the normal development database.

If ephemeral database infrastructure such as Testcontainers is genuinely required for reproducibility, CI qualification, PostgreSQL-version compatibility testing, or destructive isolation, the agent must **explicitly justify the exception before introducing it**.

Do not introduce Testcontainers merely because a framework tutorial or default scaffold uses it.

---

## 8. CI/CD IS A SEPARATE ENVIRONMENT

This policy applies primarily to the **local development environment**.
Do not hardcode `postgres/postgres`, `localhost` or `shared-postgres` into production or staging configuration.
Production credentials must always come from secrets/environment configuration.

---

## 9. AGENT DECISION RULE

Whenever you are about to:
* install PostgreSQL
* start PostgreSQL
* add a PostgreSQL Docker service
* create a PostgreSQL container
* expose another PostgreSQL port
* add Testcontainers PostgreSQL
* create database infrastructure

**STOP.**

First ask:
> Can this project use the existing shared PostgreSQL instance with its own isolated database?

In normal local development, the answer is **YES**.
Reuse the shared infrastructure (`shared-postgres` / `localhost:5432` / `dev-network`).
Do not duplicate it.

---

## 10. SECURITY SCOPE

The credentials `postgres / postgres` are **LOCAL DEVELOPMENT CREDENTIALS ONLY**.
They must never be reused for production, staging, public deployments, or cloud databases.
Never commit real production credentials to Git.


---

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


---

# GLOBAL DEVELOPMENT POLICY — TESTING PYRAMID & RIGOR

This policy defines the automated testing standards and guarantees regression resistance across all projects.

---

## 1. TESTING PYRAMID

Every project must maintain a balanced testing strategy:

```text
       /\
      /  \       Playwright E2E Tests (Critical user paths & UI state)
     /────\
    /      \     API & Contract Tests (OpenAPI/HTTP endpoint contracts)
   /────────\
  /          \   Integration & DB Tests (Isolated against <project>_test DB)
 /────────────\
/              \ Unit Tests (Domain logic, services, utilities, edge cases)
────────────────
```

---

## 2. STRICT RULE: NO GREEN-BY-DELETION

* Agents are **strictly forbidden from weakening, commenting out, or deleting existing tests** simply to make CI or test suites green.
* If a test fails, the agent must identify the underlying root cause and fix the implementation or update the test only when the business specification has explicitly changed.

---

## 3. MANDATORY REGRESSION TESTS FOR BUG FIXES

* When fixing a bug, the agent must write an automated regression test reproducing the original defect **before** applying the fix.
* The test must fail before the fix and pass after the fix.

---

## 4. DATABASE TESTING ISOLATION

* Automated integration tests using PostgreSQL must connect to the project's dedicated test database (e.g. `hookr_test`, `convivia_test`).
* Tests must never execute destructive operations (`DROP`, `TRUNCATE`, bulk deletions) against the active development database (`hookr`, `convivia`).

---

## 5. SECURITY & NEGATIVE TESTING

* Include negative tests verifying authorization barriers, invalid inputs, unauthorized tenant access, and edge-case validation.


---

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


---

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


---

# GLOBAL DEVELOPMENT POLICY — DOCKER & SHARED INFRASTRUCTURE

This policy governs the creation and use of Docker containers and local development services.

---

## 1. PREFER SHARED LOCAL INFRASTRUCTURE

Before introducing a new container or service to a project's `docker-compose.yml`, agents must inspect existing local infrastructure.

* **PostgreSQL:** Always reuse `shared-postgres` on `dev-network` (`localhost:5432` / `shared-postgres:5432`).
* **Redis / Cache:** If a shared Redis instance exists on `dev-network`, reuse it with key prefixing or dedicated logical DB numbers.
* **MinIO / S3:** Prefer shared local S3-compatible storage with separate buckets per project.
* **Maildev / Fake SMTP:** Prefer a shared SMTP container for developer email previewing.

---

## 2. STRICT JUSTIFICATION FOR DEDICATED INFRASTRUCTURE

* Creating a dedicated container for a service that already exists globally requires **explicit technical justification** documented in the PR or ADR (e.g., custom C extensions, incompatible major versions, destructive integration tests).

---

## 3. CLEAN DOCKER COMPOSE CONFIGURATION

When configuring an application in `docker-compose.yml`:
```yaml
services:
  app:
    build: .
    environment:
      DATABASE_URL: postgresql://postgres:<LOCAL_POSTGRES_PASSWORD>@shared-postgres:5432/<project_name>
    networks:
      - dev-network

networks:
  dev-network:
    external: true
```
Never bind host ports arbitrarily or spin up duplicate database engines to resolve port conflicts.


---

# GLOBAL DEVELOPMENT POLICY — THIRD-PARTY DEPENDENCIES

This policy defines the evaluation protocol before adding new libraries or dependencies to any project.

---

## 1. PRE-INSTALLATION CHECKLIST

Before running `npm install`, `pnpm add`, `pip install`, `cargo add`, or adding Maven/Gradle dependencies, the agent must verify:
1. **Existing Code:** Does the codebase already contain a utility or function that solves this problem?
2. **Framework Capabilities:** Does the underlying framework (Spring Boot, Node standard library, React, FastAPI, etc.) natively support this without extra packages?
3. **Maintenance & Popularity:** Is the package actively maintained, well-tested, and widely adopted?
4. **License & Security:** Does the package have known CVEs or an incompatible license (e.g. AGPL in commercial contexts)?

---

## 2. PROHIBITION OF CASUAL DEPENDENCIES

* Agents must **not** introduce heavy libraries (e.g. Lodash, Moment.js, Axios, Apache Commons) for trivial operations that require only a few lines of standard modern language code.
* Justify any non-trivial runtime dependency in the PR description.


---

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


---

# GLOBAL DEVELOPMENT POLICY — OBSERVABILITY & SYSTEM HEALTH

This policy defines the standard telemetry and observability baseline for all backend and frontend services.

---

## 1. FIRST-CLASS CITIZEN

Observability is an integral part of feature implementation, **not** an afterthought added after production deployment.

---

## 2. BASELINE TELEMETRY REQUIREMENTS

1. **Structured Logging:**
   - Logs must be formatted as JSON or structured key-value pairs in production.
   - Include contextual metadata: timestamp, log level, service name, environment.
2. **Correlation / Request IDs:**
   - Every inbound HTTP request or message must carry or generate a unique `correlation_id` / `trace_id`.
   - Propagate this ID across downstream service calls and database operations.
3. **Health Check Endpoints:**
   - Expose standard health probes (`/health/live`, `/health/ready`, `/actuator/health`).
   - The readiness probe must verify database connectivity and required external dependencies.
4. **Error Tracking & Sentry:**
   - Unhandled exceptions must be captured with stack traces and request context.
   - Mask sensitive credentials, cookies, and tokens before transmission to error tracking services.


---

# GLOBAL DEVELOPMENT POLICY — DOCUMENTATION & ARCHITECTURE DECISION RECORDS (ADR)

This policy establishes documentation standards and the mandatory recording of significant architectural decisions.

---

## 1. DOCUMENTATION SYNCHRONIZED WITH REALITY

* Any pull request that alters user workflows, environment variables, APIs, or operational steps must update the corresponding `README.md`, `openapi.yaml`, or project documentation.
* Outdated documentation that contradicts actual code behavior is considered a defect.

---

## 2. ARCHITECTURE DECISION RECORDS (ADR)

Significant architectural decisions must be recorded as an ADR in `docs/adr/` or `docs/architecture/` within the repository.

### When to write an ADR:
* Introducing a new framework, persistence engine, or message broker.
* Restructuring bounded contexts or domain boundaries.
* Changing authentication/authorization mechanics or security models.
* Adopting a new API protocol or contract format.

### ADR Mandatory Structure:
```markdown
# [Number]. [Title in Imperative Mood]

* **Status:** [Proposed | Accepted | Superseded | Deprecated]
* **Date:** [YYYY-MM-DD]
* **Author / Agent:** [Agent ID / Name]

## Context
What problem are we trying to solve? What are the business and technical constraints?

## Decision
What is the specific architectural change or standard we are adopting?

## Alternatives Considered
1. Alternative A (Why was it rejected?)
2. Alternative B (Why was it rejected?)

## Consequences
* **Positive:** What benefits do we gain?
* **Negative / Trade-offs:** What complexity or maintenance cost are we taking on?
```

Agents must search existing ADRs before proposing or implementing changes that conflict with an established decision.


---

# GLOBAL DEVELOPMENT POLICY — AGENT COORDINATION & COLLISION PREVENTION

This policy governs multi-agent collaboration and prevents destructive parallel overlaps.

---

## 1. BEHAVIOUR DOMAIN DRIVER (BDD) OPERATIONAL CONTRACT

All agents operating in this environment must adhere to the **Behaviour Domain Driver (BDD)** contract. No agent may act as an untracked, uncoordinated entity.

---

## 2. EXPLICIT OWNERSHIP & PARALLEL ISOLATION

Before modifying code, the agent must declare its assignment and claim ownership of:
* Target Issue / Feature Goal.
* Dedicated Git Branch (`feature/...` or `fix/...`).
* Target Bounded Context & File Globs.
* Target Database Migration Files (if applicable).

---

## 3. COLLISION PREVENTION RULES

If an agent discovers that another branch or open PR is actively modifying:
1. The same database migration sequence (e.g. `V5__...` while another PR has `V5__...`),
2. Core authentication/authorization interceptors,
3. Shared domain entities / foundational contracts,

The agent must **STOP**, enter state `BLOCKED`, emit a structured collision report, and request human or architectural coordination rather than generating conflicting migrations or merge collisions.

---

## 4. VERIFIABLE EVIDENCE OVER ASSERTIONS

* No agent may mark a task `DONE` based solely on conversational prose.
* Every handoff requires machine-verifiable evidence (commit SHA, PR URL, test execution output, Playwright traces, CI status).
