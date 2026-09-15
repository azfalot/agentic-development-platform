---
name: bootstrap-project
description: >-
  Use this skill when initializing a new software project, repository, or service to ensure standard global architecture, shared PostgreSQL, and BDD setup.
---

# Skill: Bootstrap Project

Standardized initialization of new projects ensuring complete alignment with global policies.

## Inputs
- `project_name` (string, required)
- `stack` (string: e.g. Node/TypeScript, Java/Spring Boot, Python/FastAPI)
- `bounded_contexts` (array of strings)

## Preconditions
- Git installed and initialized.
- Global development platform installed at `~/.agents/`.
- Shared PostgreSQL container running (`dev-network` accessible).

## Procedure
1. Create project directory and initialize Git repository on `main`.
2. Generate project structure and runtime scaffolding.
3. Create minimal `AGENTS.md` inheriting `~/.agents/` policies.
4. Configure database connection:
   - Name: `<project_name>`
   - Host (local): `localhost:5432` / Docker: `shared-postgres:5432`
   - User/Pass: `postgres / postgres`
   - Red: `dev-network` (external: true)
5. Create initial database via `shared-postgres`:
   `docker exec -i shared-postgres psql -U postgres -c "CREATE DATABASE <project_name>;"`
   `docker exec -i shared-postgres psql -U postgres -c "CREATE DATABASE <project_name>_test;"`
6. Configure initial database migration tool (Flyway, Liquibase, Prisma, Alembic).
7. Configure CI pipeline (`.github/workflows/ci.yml`) with standard build, lint, and test gates.
8. Commit initial scaffolding with conventional commit: `chore: initial project bootstrap`.

## Required Evidence
- Successful build and test execution log.
- Clean database connectivity check.
- `AGENTS.md` and `.env.example` in repo root.

## Definition of Done
- No local PostgreSQL container defined in `docker-compose.yml`.
- Application starts and connects to `shared-postgres`.
- CI pipeline configured and passing.
