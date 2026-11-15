# ADR-001: Centralize Relational Application Data on a Hardened PostgreSQL 18 Instance

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-10` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | Data Tier & Persistence |
| **Related Stacks** | [`compose/postgres/`](../../compose/postgres/), [`compose/databasus/`](../../compose/databasus/), [`compose/tracearr/`](../../compose/tracearr/), [`disaster-recovery.md`](../runbooks/disaster-recovery.md) |

---

## Context and Problem Statement

When designing the `205hlab` production baseline on a single primary bare-metal host (Fujitsu ESPRIMO P710: Intel Core i7-3770 4C/8T, **32 GB DDR3 RAM**, SATA SSD storage), more than a dozen self-hosted services require durable relational persistence — including identity management (Authentik), document OCR indexing (Paperless-ngx), media acquisition automation (Sonarr, Radarr, Lidarr, Chaptarr, Prowlarr), download management UI (qui), household utilities (Mealie, FreshRSS, Reactive Resume), and network telemetry (Speedtest Tracker).

Under a 32 GB non-ECC memory ceiling alongside memory-intensive services (Authentik, Paperless/Tika/Gotenberg, Prometheus, Jellyfin), how should relational data be structured to maximize storage integrity, eliminate concurrency lock failures, minimize idle RAM consumption, and maintain a reliable automated backup strategy?

**Evolutionary Context (3–4 Years of Prior Labs):** Earlier homelab iterations combined embedded **SQLite** databases (wherever an application offered it by default) with earlier major releases of **PostgreSQL**, administered first through **phpMyAdmin** (for legacy SQL stacks) and later via a desktop **pgAdmin** client running on a personal laptop. Moving into the clean `205hlab` baseline, standardizing onto a centralized **PostgreSQL 18** cluster solved the operational fragmentation of managing scattered DB instances — making automated scheduled backups (**Databasus**) and quick browser-based table inspection/editing (**Adminer** at `adminer.internal.205hlab.com`) uniform from any authorized LAN session without workstation client dependencies.

## Decision Drivers

- **Memory Density on 32 GB DDR3:** Avoid running 12+ separate database server processes, each duplicating shared buffers, WAL writers, and autovacuum workers.
- **Silent Corruption Detection:** Ensure database storage detects bit rot early on consumer-grade SATA SSD media via page-level checksums (`--data-checksums`).
- **Concurrency Under Load:** Eliminate SQLite `database is locked` failures triggered by simultaneous webhooks, API scans, and background indexing (most notably in Authentik and the `*arr` automation suite).
- **Unified Backup Surface:** Consolidate automated `pg_dump` snapshots into a single managed schedule rather than writing per-container backup cron scripts across 12 volumes.
- **Least-Privilege Multi-Tenancy:** Prevent an application compromise or misconfiguration in one stack from accessing or corrupting another service's schema.

## Considered Options

1. **Option 1 (Chosen):** Centralized PostgreSQL 18 Server with Per-App Role/Schema Isolation (`db-init.sql`) and Unified Databasus Backups
2. **Option 2:** Per-Stack Isolated Database Containers (Dedicated PostgreSQL/MariaDB sidecar per Compose stack)
3. **Option 3:** Embedded Per-Container SQLite Databases

### Options Analysis

#### Option 1 — Centralized PostgreSQL 18 Server (`--data-checksums` + `db-init.sql`)
- **Pros:**
  - Single shared memory pool (`postgres:18.3` capped at `2.0` CPUs / `4G` RAM) saves multiple gigabytes of aggregate RAM compared to 12+ sidecars.
  - Native block-level checksums (`POSTGRES_INITDB_ARGS=--data-checksums`) catch silent page corruption on consumer SATA SSDs.
  - True MVCC concurrency handles heavy simultaneous writes from Authentik workers, Paperless tasks, and Servarr indexers without lock errors.
  - Single backup orchestrator (**Databasus** `v3.65.0`) executes structured automated dumps across all hosted application databases.
  - Single monitoring endpoint (`postgres-exporter`) feeds Prometheus and Grafana dashboards.
- **Cons:**
  - Creates a shared blast radius: restarting or upgrading the `postgres` container temporarily interrupts dependent stacks.
  - Major PostgreSQL version upgrades require coordinated `pg_upgrade` or dump/restore maintenance across all tenant databases.

#### Option 2 — Per-Stack Isolated Database Containers
- **Pros:**
  - Complete failure and upgrade isolation; each stack controls its own PostgreSQL minor/major version independently.
  - Simpler stack teardown (removing a stack leaves no orphaned schema in a central DB).
- **Cons:**
  - Running 12+ separate `postgres` instances (plus their exporters and backup hooks) wastes ~3–5 GB of valuable DDR3 RAM and increases disk I/O contention.
  - Multiplies backup orchestration complexity (12 independent backup targets, schedules, and volume mounts).
  - Higher operational overhead for patching security updates across a dozen identical engines.

#### Option 3 — Embedded Per-Container SQLite Databases
- **Pros:**
  - Zero network configuration or separate DB container needed; self-contained file backups.
- **Cons:**
  - Frequent `database is locked` errors in concurrent workloads (especially Sonarr, Radarr, Lidarr, and Paperless).
  - No unified point-in-time SQL dump tooling (copying live SQLite WAL files without quiescing risks corrupt snapshots).
  - No centralized query/lock/cache-hit observability in Prometheus/Grafana.

## Decision Outcome

**Chosen Option:** **Option 1 — Centralized PostgreSQL 18 Server with Per-App Isolation and Unified Databasus Backups**

The core data tier is standardized on a single `docker.io/library/postgres:18.3` container (`205hlab-pgdb`) managed in [`compose/postgres/`](../../compose/postgres/):

1. **Data Integrity & Hardening:** Initialized with `POSTGRES_INITDB_ARGS=--data-checksums`, strict cgroup caps (`cpus: '2.0'`, `memory: 4G`), and attached exclusively to the internal `postgres_network` bridge — port `5432` is **never published** to host interfaces.
2. **Per-Application Isolation (`db-init.sql`):** Each client service receives a dedicated database and unprivileged application role (e.g., `authentik` / `authentik_app`, `paperless` / `paperless_app`, `mealie` / `mealie_app`, `sonarr-main` / `sonarr_app`) provisioned declaratively via each stack's version-controlled `db-init.sql`.
3. **Unified Operations & Decoupled Backup / Automated Verification (`compose/databasus/`):** Managed internally via **Adminer** (`adminer.internal.205hlab.com`), while **Databasus** (`databasus.internal.205hlab.com`) and the official **`databasus-verifier`** agent container operate in a decoupled stack ([`compose/databasus/`](../../compose/databasus/)) to enforce a **24h RPO** (daily snapshots to OpenZFS `BinPool` datasets at `${DATABASUS_BACKUP}`, verified into ephemeral PostgreSQL 18 containers after backup for schema and per-table row-count sanity checks, and manually copied to secondary offline media) and **< 15m / < 30m Target RTO** (documented in [`docs/runbooks/disaster-recovery.md`](../runbooks/disaster-recovery.md)). Both Adminer and Databasus are gated behind Traefik and Authentik ForwardAuth (`pgdb_admins`).

### Deliberate Architectural Exceptions

- **Tracearr Time-Series Isolation (`compose/tracearr/`):** **Tracearr** deliberately runs a dedicated `timescale/timescaledb-ha:pg18.4-ts2.29.1` container (`tracearr-db` on `tracearr_backend`) rather than sharing the primary PostgreSQL 18 instance. High-frequency media analytics require TimescaleDB extension libraries (`timescaledb.max_tuples_decompressed_per_dml_transaction=100000`, `max_locks_per_transaction=4096`) and produce heavy chunk-compression writes that should stay decoupled from transactional IAM and household databases.
- **Native Single-File Services:** Applications without PostgreSQL support or with purely local state (such as **Grafana** dashboards state, **Kavita**, and **ChangeDetection.io**) retain local persistent volumes rather than forcing unsupported database adapters.

## Consequences

### Positive Consequences
- **Low Memory Footprint:** Keeps the entire 12-app relational data tier comfortably within a `4G` container memory limit on the 32 GB host.
- **High Write Reliability:** Completely eliminates SQLite database lock errors across the Servarr automation pipeline and Paperless-ngx.
- **Automated Backup Coverage:** Adding a new PostgreSQL-backed app requires adding one database connection in **Databasus** rather than building new backup scripts.
- **Observable Performance:** `postgres-exporter` surfaces transaction rates, lock waits, and cache hit ratios for all tenant databases in one Grafana dashboard.

### Negative Consequences & Mitigations
- **Trade-off (Single Point of Restart / Upgrade Coupling):** Maintenance on the `postgres` container affects all 12 dependent applications simultaneously.  
  **Mitigation:** Use pinned image minor tags (`postgres:18.3`), enforce `condition: service_healthy` startup probes (`pg_isready`), and mandate a verified **Databasus** snapshot before any PostgreSQL version upgrade.
- **Trade-off (Host Crash Blast Radius on Non-ECC RAM):** Power loss or kernel panic could affect all schemas concurrently.  
  **Mitigation:** `--data-checksums` immediately flags corrupted pages, and the host is protected by an **APC Back-UPS XS 950U** monitored by HAOS to trigger clean shutdowns before battery exhaustion.

## Compliance & Verification (Fitness Functions)

- **Compose Enforcement:** [`compose/postgres/compose.yaml`](../../compose/postgres/compose.yaml) defines `POSTGRES_INITDB_ARGS=--data-checksums`, exposes **zero** `ports:` bindings, and sets `limits: cpus: '2.0', memory: 4G`.
- **Network Isolation:** All tenant stacks connect to `postgres_network` declared `external: true` rather than exposing `5432` on the host LAN.
- **Provisioning Traceability:** Every PostgreSQL-dependent stack directory (`authentik`, `paperless`, `mealie`, `freshrss`, `servarr`, `downloaderr`, `reactive-resume`, `network-mon`) maintains a version-controlled `db-init.sql` defining least-privilege roles.
- **CI Validation:** [`.github/workflows/validate-compose.yml`](../../.github/workflows/validate-compose.yml) creates the mock `postgres_network` bridge and verifies all tenant stacks render cleanly without undefined DB variables.
