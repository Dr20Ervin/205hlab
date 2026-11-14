# PostgreSQL 18 — Centralized Relational Data Tier & Admin Tools

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.3-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Adminer](https://img.shields.io/badge/Adminer-Web%20UI-43536A?style=for-the-badge&logo=adminer&logoColor=white)](https://www.adminer.org/)
[![Databasus](https://img.shields.io/badge/Databasus-v3.65.0-336791?style=for-the-badge)](https://github.com/databasus/databasus)
[![Checksums](https://img.shields.io/badge/Data%20Integrity---data--checksums-success?style=for-the-badge)](https://www.postgresql.org/docs/current/app-initdb.html)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Internal Ingress URLs (LAN Only):**  
> - **Adminer DB Client:** `https://adminer.internal.205hlab.com`  
> - **Databasus Management:** `https://databasus.internal.205hlab.com`  
> **Database Hostname (Internal Network):** `postgres:5432` / `205hlab-pgdb`  
> **Category:** Core Data Infrastructure

This stack provides high-performance, centralized relational persistence for the entire `205hlab` production homelab. Initialized with **hardware-level data checksums** (`--data-checksums`) to detect silent bit rot, it hosts isolated, per-application schemas and roles across all household, identity, and media automation stacks. Administrative interfaces (**Adminer** and **Databasus**) are restricted to internal LAN routing (`*.internal.205hlab.com`) and fortified with Authentik ForwardAuth.

---

## 🏗️ Architecture & Database Segmentation

```
             [ Traefik Proxy (Internal Ingress) ]
                           │
             ┌─────────────┴─────────────┐
             │ Authentik ForwardAuth     │ Authentik ForwardAuth
             ▼                           ▼
    [ Adminer (:8080) ]         [ Databasus (:4005) ]
             │                           │
             └─────────────┬─────────────┘
                           │ (postgres_network)
                           ▼
          [ PostgreSQL 18 Container (:5432) ]
          • --data-checksums
          • Hostname: 205hlab-pgdb
          • CPU: 2.0 / Memory: 4GB Limit
                           │
        ┌──────────────────┴──────────────────┐
        │       Shared Application Databases  │
        ├──────────────────┬──────────────────┤
        │ authentik        │ mealie           │
        │ paperless        │ freshrss         │
        │ sonarr-main      │ radarr-main      │
        │ lidarr-main      │ chaptarr-main    │
        │ prowlarr-main    │ qui              │
        │ reactive-resume  │ speedtest_tracker│
        └──────────────────┴──────────────────┘
```

- **Network Segregation:** Attached to `postgres_network`. Database port `5432` is **never exposed or published** to the host network interfaces, preventing rogue port scanning on the local LAN.
- **Resource Constraints:** Governed with `limits: cpus: '2.0'`, `memory: 4G`.
- **Integrity Guarantee:** Initialized with `POSTGRES_INITDB_ARGS=--data-checksums` to enable online page verification against storage degradation.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

Administrative database management interfaces are strictly gated behind Authentik at the Traefik layer:

```yaml
labels:
  - "traefik.http.routers.adminer_https.middlewares=authentik@docker"
  - "traefik.http.routers.databasus_https.middlewares=authentik@docker"
```

* **Domain Restriction:** Both interfaces live solely on the internal split-horizon DNS zone (`adminer.internal.205hlab.com` and `databasus.internal.205hlab.com`).
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
| `POSTGRES_USER` | Superuser username | `postgres` |
| `POSTGRES_PASSWORD` | Superuser password | *(generated via `setup_secrets.sh`)* |
| `POSTGRES_DB` | Default root database | `postgres` |
| `DATABASUS_BACKUP` | Host path for automated SQL dumps | `/srv/backups/postgresql` |

---

## 🚀 Deployment & Operations

1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/postgres
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN and DATABASUS_BACKUP
   ```

2. **Start the Database Tier**:
   ```bash
   docker compose up -d
   ```

3. **Verify Database Health**:
   ```bash
   docker exec -it postgres pg_isready -U postgres
   ```

---

## 💾 Backup & Disaster Recovery

- **Automated Dumps via Databasus:** Databasus automatically schedules periodic `pg_dump` backups across all databases into `${DATABASUS_BACKUP}`.
- **Physical Data Files:** All tables, indexes, and write-ahead logs (WAL) reside in Docker named volume `postgres_data` (`/var/lib/postgresql/data`).
- **Manual Full Cluster Backup:**
  ```bash
  docker exec -t postgres pg_dumpall -U postgres > full_cluster_backup_$(date +%F).sql
  ```

---

## 🩺 Healthcheck & Monitoring

- **PostgreSQL Health**: Continuously probed every 10s via `pg_isready -U ${POSTGRES_USER}`.
- **Adminer Health**: Probed every 30s via `wget --spider http://localhost:8080/`.
- **Prometheus Telemetry**: Scraped by `postgres-exporter` on port `:9187` with database auto-discovery enabled, visualized in the pre-configured [PostgreSQL Grafana Dashboard](../../grafana-dashboards/core/postgresql-dashbaord.json).
