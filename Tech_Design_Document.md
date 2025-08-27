
# Tech Design Document — ci-cd-monitor

**Repository:** `git@github.com:amoltalentica/ci-cd-monitor.git`  
**Generated:** 2025-08-24

---

## 1. High-level architecture

**Overview**  
`ci-cd-monitor` is a small multi-container application that monitors CI/CD pipeline runs and exposes metrics and a web UI. The repository contains three main parts:

- **backend** — Python service (API + data ingestion / metrics)  
- **frontend** — Web UI (single-page app)  
- **nginx** — Reverse proxy serving the frontend and reverse-proxying API requests  
- **docker-compose.yml** — Orchestration for local/dev deployment  
- **env.production** — Environment variables (DB credentials, ports, optional Slack webhook)

**Data flow (high level)**

1. CI systems (e.g., GitHub Actions) or scripts push pipeline execution data to the **backend** API (ingest endpoints).
2. **Backend** stores events/aggregates them in the **database** and exposes metric endpoints (e.g. `/api/metrics`) and health endpoints (e.g. `/health`).
3. **Frontend** fetches metric endpoints (e.g. `/metrics` or `/api/metrics`) and renders charts, tables and alerts in real-time (polling or websockets).
4. Optional alerting/integrations (Slack) are performed by the backend when thresholds or failures are detected.

**Deployment topology (dev)**

- `docker-compose` starts:
  - `db` (Postgres) — persistent storage.
  - `backend` — Python API (port 8000).
  - `frontend` — static SPA served by nginx (port 8080 local mapping).
  - `nginx` — reverse proxy (optional container) to serve frontend and route `/api/*` to backend.

**Non-functional considerations**

- **Resilience:** Scale backend horizontally behind a load balancer in production. Use managed Postgres or run Postgres with backups.
- **Observability:** Backend should expose Prometheus-compatible metrics and a `/health` endpoint. Add logging structured JSON.
- **Security:** Do not store secrets in repo; use environment variables or a secrets manager. Restrict API endpoints if ingesting data from external sources.
- **Authentication & Authorization:** If ingestion endpoints are public-facing, add an API token or signed webhook mechanism.

---

## 2. API structure (routes, sample response)

> Notes: The repo exposes at least `/health` and `/api/metrics` based on observed behavior. Below is a suggested API surface that matches and expands on that.

### Public (health & status)
- `GET /health`  
  - Purpose: Liveness & readiness check.  
  - Sample response (200):
```json
{
  "status": "ok",
  "uptime_seconds": 12345,
  "timestamp": "2025-08-27T08:00:00Z"
}
```

### Metrics & Dashboard
- `GET /api/metrics`  
  - Purpose: Primary metrics consumed by the frontend. Returns aggregated statistics and recent pipeline runs.  
  - Query params (optional):
    - `from` (ISO8601), `to` (ISO8601), `group_by` (e.g., `day`, `hour`), `limit`  
  - Sample response:
```json
{
  "summary": {
    "total_runs": 1024,
    "success_rate": 0.87,
    "avg_duration_seconds": 312.4,
    "last_updated": "2025-08-27T08:00:00Z"
  },
  "time_series": [
    {"timestamp":"2025-08-26T00:00:00Z","success":20,"failure":3,"avg_duration":300},
    {"timestamp":"2025-08-27T00:00:00Z","success":30,"failure":5,"avg_duration":320}
  ],
  "recent_runs": [
    {
      "id": "run_20250827_001",
      "workflow": "build-and-test",
      "status": "failure",
      "duration_seconds": 421,
      "started_at": "2025-08-27T06:15:00Z",
      "finished_at": "2025-08-27T06:22:01Z",
      "repo": "org/repo",
      "branch": "main",
      "triggered_by": "push"
    }
  ]
}
```

### Ingest (if present)
- `POST /api/events`  
  - Purpose: Accept a pipeline run/event payload from GitHub Actions or other CI.  
  - Authentication: Bearer token / HMAC signature recommended.  
  - Sample request:
```json
{
  "id": "run_20250827_001",
  "workflow": "build",
  "status": "success",
  "duration_seconds": 123,
  "started_at": "2025-08-27T06:00:00Z",
  "finished_at": "2025-08-27T06:02:03Z",
  "repo": "org/repo",
  "branch": "main",
  "meta": {"runner":"ubuntu-latest"}
}
```
  - Sample response: `201 Created` with created resource.

### Alerts / Integration endpoints (optional)
- `POST /api/alerts/test` — test Slack/webhook integration
- `GET /api/config` — read-only config for UI (if needed)

---

## 3. Database schema

> Assumes a Postgres database (env variables in repository include `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`). The schema below is a recommended mapping for pipeline events and aggregates.

### Tables

#### `pipeline_runs`
- `id` VARCHAR PRIMARY KEY — unique run id (e.g., GitHub run id or composed string)
- `workflow` VARCHAR NOT NULL
- `repo` VARCHAR NOT NULL
- `branch` VARCHAR
- `status` VARCHAR NOT NULL CHECK (status IN ('success','failure','cancelled','running','queued'))
- `duration_seconds` INTEGER
- `started_at` TIMESTAMP WITH TIME ZONE
- `finished_at` TIMESTAMP WITH TIME ZONE
- `triggered_by` VARCHAR
- `metadata` JSONB — raw payload or runner details
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

Indexes: `CREATE INDEX idx_runs_repo ON pipeline_runs(repo);`  
Composite index on `(repo, workflow, started_at)` for queries.

#### `workflow_aggregates` (optional materialized view for fast dashboard)
- `id` SERIAL PRIMARY KEY
- `repo` VARCHAR
- `workflow` VARCHAR
- `period_start` TIMESTAMP WITH TIME ZONE
- `period_end` TIMESTAMP WITH TIME ZONE
- `runs_total` INTEGER
- `runs_failed` INTEGER
- `avg_duration_seconds` FLOAT
- `success_rate` FLOAT

Populate via periodic ETL or use DB materialized views refreshed every minute.

#### `alerts`
- `id` SERIAL PRIMARY KEY
- `name` VARCHAR
- `threshold_type` VARCHAR (e.g., `failure_rate`, `duration`)
- `threshold_value` FLOAT
- `last_triggered` TIMESTAMP WITH TIME ZONE
- `enabled` BOOLEAN DEFAULT true

---

## 4. UI layout (explanation)

The frontend is a single page app that should provide the following screens/sections:

### Header / Global Controls
- Top bar with app title, refresh button, environment indicator (dev/prod), and timezone selector.
- Global filters: repository selector, workflow selector, time range picker (last 24h / 7d / 30d / custom).

### Summary KPIs (top row)
- **Success Rate** (percent)
- **Total Runs** (count)
- **Avg Duration** (human readable)
- **Failed Runs (last 24h)** (count)

Each KPI card should show a small sparkline (time series mini-chart) and comparison vs previous period.

### Time-series charts (main area)
- **Success vs Failure** stacked bar or line chart over the selected period.
- **Average Duration** line chart.
- Toggle for grouping by `hour/day/week`.

### Recent Runs Table (below charts)
- Table columns:
  - Time (started_at)
  - Repo
  - Workflow
  - Branch
  - Duration
  - Status (color-coded: green/yellow/red)
  - Actions: View raw payload / Re-run link (if integrated with CI)

Rows should be clickable to open a side-panel with full run details and raw JSON.

### Alerts & Notifications panel (right side or modal)
- List of active alerts with quick actions (acknowledge, mute).
- Button to test Slack/webhook integration.

### Settings page
- Manage integrations (Slack webhook)
- API token for ingestion
- Retention/aggregation policies

---

## 5. Deployment & local-run notes

**Local quick start (suggested)**

1. Copy env example to `.env` or `env.production` and set Postgres credentials.
2. `docker-compose up --build` — starts db, backend, frontend, nginx.
3. Visit `http://localhost:8080` (or the port mapped in docker-compose) for UI.
4. Hit `http://localhost:8000/health` to check backend health and `http://localhost:8000/api/metrics` for metrics.

**Production recommendations**

- Use a managed Postgres (RDS/Azure Database) with automated backups.
- Deploy backend as containerized service behind an ALB/Ingress.
- Use TLS termination (Cloud LB or nginx with certbot).
- Use CI to build and push images to a registry and deploy via an orchestrator (ECS/EKS/GKE).

---

## 6. Next steps / Actionable items for repository

1. Add/confirm `README` sections with exact API endpoint docs and environment variables.
2. Add API authentication (API token or HMAC) to ingestion endpoints.
3. Create DB migrations (e.g., Alembic) and include `migrations/` in repo.
4. Add automated tests for API and sample data fixtures.
5. Add Prometheus metrics endpoint and optionally Grafana dashboards.
6. Add GitHub Actions workflow to build/test/publish Docker images.

---

## 7. Appendix — Quick reference of endpoints (summary)

- `GET /health` -> health status
- `GET /api/metrics` -> dashboard metrics (summary, time_series, recent_runs)
- `POST /api/events` -> ingest new pipeline event (recommended to protect)
- `POST /api/alerts/test` -> test alerting integration (optional)

---

