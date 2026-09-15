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
