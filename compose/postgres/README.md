# PostgreSQL 18 — Centralized Relational Data Tier & Admin Tools

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.3-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Adminer](https://img.shields.io/badge/Adminer-Web%20UI-43536A?style=for-the-badge&logo=adminer&logoColor=white)](https://www.adminer.org/)
[![Checksums](https://img.shields.io/badge/Data%20Integrity---data--checksums-success?style=for-the-badge)](https://www.postgresql.org/docs/current/app-initdb.html)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Internal Ingress URL (LAN Only):** `https://adminer.internal.205hlab.com`  
> **Database Hostname (Internal Network):** `postgres:5432` / `205hlab-pgdb`  
> **Category:** Core Data Infrastructure  
> **Architecture Decision Record:** See [**ADR-001: Centralize Relational Application Data on a Hardened PostgreSQL 18 Instance**](../../docs/adr/ADR-001-centralized-postgresql-18.md) for the engineering trade-offs behind this stack.  
> **Backups & Restore Verification:** Automated backups and the `databasus-verifier` automated restore verification agent are decoupled into [`compose/databasus/`](../databasus/) — see the [**Disaster Recovery Runbook**](../../docs/runbooks/disaster-recovery.md).

This stack provides high-performance, centralized relational persistence for the entire `205hlab` production homelab. Initialized with **hardware-level data checksums** (`--data-checksums`) to detect silent bit rot, it hosts isolated, per-application schemas and roles across all household, identity, and media automation stacks. Administrative access via **Adminer** (`adminer.internal.205hlab.com`) is restricted to internal LAN routing and fortified with Authentik ForwardAuth.

---

## 🏗️ Architecture & Database Segmentation

```
             [ Traefik Proxy (Internal Ingress) ]
                           │
                           │ Authentik ForwardAuth
                           ▼
                   [ Adminer (:8080) ]
                           │
                           ▼
                [ PostgreSQL 18 Prod (:5432) ]   (postgres / 205hlab-pgdb)
                  • --data-checksums             ◄── Automated Daily Backups +
                  • CPU: 2.0 / Memory: 4GB Limit     databasus-verifier (compose/databasus/)
                           │
        ┌──────────────────┴──────────────────┐
        │             Shared Production Databases           │
        ├─────────────────────────┬─────────────────────────┤
        │ authentik               │ mealie                  │
        │ paperless               │ freshrss                │
        │ sonarr-main / log       │ radarr-main / log       │
        │ lidarr-main / log       │ chaptarr-main/log/cache │
        │ prowlarr-main / log     │ qui                     │
        │ reactive-resume         │ speedtest_tracker       │
        └─────────────────────────┴─────────────────────────┘
```

- **Network Segregation:** Attached to `postgres_network`. Database port `5432` is **never exposed or published** to the host network interfaces, preventing rogue port scanning on the local LAN.
- **Resource Constraints:** Governed with `limits: cpus: '2.0'`, `memory: 4G`.
- **Integrity Guarantee:** Initialized with `POSTGRES_INITDB_ARGS=--data-checksums` to enable online page verification against storage degradation.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

The Adminer database web interface is strictly gated behind Authentik at the Traefik layer:

```yaml
labels:
  - "traefik.http.routers.adminer_https.middlewares=authentik@docker"
```

* **Domain Restriction:** Lives solely on the internal split-horizon DNS zone (`adminer.internal.205hlab.com`).
* **Access Control:** Bound to group `pgdb_admins` or `authentik Admins`.

---

## 🗄️ Application Database Catalog

Each application maintains an isolated database and restricted user. Provisioning scripts are version-controlled in each stack's `db-init.sql`:

| Database Name | Application User | Owning Compose Stack |
| :--- | :--- | :--- |
| `authentik` | `authentik_app` | [`compose/authentik/`](../authentik/) |
| `mealie` | `mealie_app` | [`compose/mealie/`](../mealie/) |
| `paperless` | `paperless_app` | [`compose/paperless/`](../paperless/) |
| `freshrss` | `freshrss_app` | [`compose/freshrss/`](../freshrss/) |
| `sonarr-main` / `log` | `sonarr_app` | [`compose/servarr/`](../servarr/) |
| `radarr-main` / `log` | `radarr_app` | [`compose/servarr/`](../servarr/) |
| `lidarr-main` / `log` | `lidarr_app` | [`compose/servarr/`](../servarr/) |
| `chaptarr-main` / `log` / `cache` | `chaptarr_app` | [`compose/servarr/`](../servarr/) |
| `prowlarr-main` / `log` | `prowlarr_app` | [`compose/servarr/`](../servarr/) |
| `qui` | `qui_app` | [`compose/downloaderr/`](../downloaderr/) |
| `reactive-resume` | `reactive-resume_app`| [`compose/reactive-resume/`](../reactive-resume/) |
| `speedtest_tracker` | `speedtest_app` | [`compose/network-mon/`](../network-mon/) |

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `POSTGRES_USER` | Superuser username | `postgres_admin` |
| `POSTGRES_PASSWORD` | Superuser password | *(generated via `setup_secrets.sh`)* |
| `POSTGRES_DB` | Default root database | `postgres` |

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/postgres
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN and POSTGRES_PASSWORD
   ```

2. **Start the Database Tier**:
   ```bash
   docker compose up -d
   ```

3. **Verify Database Health**:
   ```bash
   docker exec -it postgres pg_isready -U "$POSTGRES_USER"
   ```

---

## 💾 Backup & Disaster Recovery

- **Decoupled Automated Backups & Restore Verification (`compose/databasus/`):** Daily scheduled `pg_dump` backups and automated post-backup restore verification (**`databasus-verifier`**) are managed in the dedicated [`compose/databasus/`](../databasus/) stack (`databasus.internal.205hlab.com`) so backup and verification workflows stay independent of primary `postgres` container uptime.
- **Step-by-Step Recovery Playbooks:** See [**`docs/runbooks/disaster-recovery.md`**](../../docs/runbooks/disaster-recovery.md) for RPO (`24h`) / RTO (`< 15m` single DB, `< 30m` full cluster) targets, automated verification, manual restore drills, single-app rollbacks, and cold bare-metal recovery.
- **Physical Data Files:** All tables, indexes, and write-ahead logs (WAL) reside in Docker named volume `postgres_data` (`/var/lib/postgresql/data`).
- **Manual Full Cluster Backup:**
  ```bash
  docker exec -t postgres pg_dumpall -U "$POSTGRES_USER" > full_cluster_backup_$(date +%F).sql
  ```

---

## 🩺 Healthcheck & Monitoring

- **PostgreSQL Health**: Continuously probed every 10s via `pg_isready -U ${POSTGRES_USER}`.
- **Adminer Health**: Probed every 30s via `wget --spider http://localhost:8080/`.
- **Prometheus Telemetry**: Scraped by `postgres-exporter` on port `:9187` with database auto-discovery enabled, visualized in the pre-configured [PostgreSQL Grafana Dashboard](../../grafana-dashboards/core/postgresql-dashbaord.json).
