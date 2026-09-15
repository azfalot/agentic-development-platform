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
