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
