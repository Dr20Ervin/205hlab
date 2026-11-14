# Tracearr — Media Analytics & Playback Telemetry Platform

[![Tracearr](https://img.shields.io/badge/Tracearr-latest-4A148C?style=for-the-badge&logo=prometheus&logoColor=white)](https://github.com/connorgallopo/tracearr)
[![TimescaleDB](https://img.shields.io/badge/Database-TimescaleDB%20(pg18)-FDB515?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.timescale.com/)
[![Redis](https://img.shields.io/badge/Broker-Redis%208-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Ingress URL:** `https://tracearr.205hlab.com`  
> **Upstream Project:** [connorgallopo/tracearr](https://github.com/connorgallopo/tracearr)  
> **Category:** Media Analytics & Telemetry

Tracearr is a dedicated analytics and watch-history tracking engine for media servers. It captures real-time playback sessions, stream durations, device usage, transcoding vs. direct-play ratios, and user consumption habits. In this homelab, Tracearr pairs with a tuned **TimescaleDB** time-series database (PostgreSQL 18 engine with hypertables and compression), a **Redis 8** caching broker, and Authentik ForwardAuth security.

---

## 🏗️ Architecture & Time-Series Data Tier

```
[ Jellyfin / Media Servers ]
             │ Playback Webhooks & Session Telemetry
             ▼
[ Traefik Ingress Proxy ]
             │ ForwardAuth Gate (Authentik)
             ▼
[ Tracearr Application (:3000) ]
   ├── Session Caching & Job Queues ──► [ Redis 8 Broker ]
   ├── Time-Series Hypertables ──► [ TimescaleDB HA (pg18.4) ]
   └── Media Server Synchronization ──► [ servarr_backend ]
```

- **TimescaleDB (`tracearr-db`)**: Runs `timescale/timescaledb-ha:pg18.4-ts2.29.1` with custom tuning parameters (`timescaledb.max_tuples_decompressed_per_dml_transaction=100000`, `max_locks_per_transaction=4096`, `nofile: 65536`) to ingest high-frequency playback ticks efficiently.
- **Message Broker (`tracearr-redis`)**: Runs Redis 8 Alpine with append-only persistence enabled (`redis-server --appendonly yes`).
- **Resource Constraints:**
  - `tracearr`: Governed with `limits: cpus: '1.5'`, `memory: 2G`.
  - `tracearr-db`: Governed with `limits: cpus: '1.5'`, `memory: 2G`.
  - `tracearr-redis`: Governed with `limits: cpus: '0.5'`, `memory: 512M`.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

Tracearr is protected at the reverse proxy edge by the Authentik ForwardAuth middleware:

```yaml
labels:
  - "traefik.http.routers.tracearr_https.middlewares=authentik@docker"
```

* **Access Control:** Bound to group `jellyfin-users` or `authentik Admins`.
* **Zero Direct Exposure:** External clients cannot probe API endpoints or database connections without an authenticated Authentik session.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `TRACEARR_DB_USER` | TimescaleDB username | `tracearr_app` |
| `TRACEARR_DB_NAME` | TimescaleDB database name | `tracearr-main` |
| `TRACEARR_DB_PASSWORD` | TimescaleDB password | *(generated via `setup_secrets.sh`)* |
| `TRACEARR_JWT_SECRET` | Token signing secret | *(generated via `setup_secrets.sh`)* |
| `TRACEARR_COOKIE_SECRET`| Cookie encryption secret | *(generated via `setup_secrets.sh`)* |

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/tracearr
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Link Media Server**:
   Navigate to `https://tracearr.205hlab.com`. Under **Settings** > **Servers**, add Jellyfin using internal hostname `http://jellyfin:8096` over the `servarr_backend` network.

---

## 💾 Backup & Data Persistence

- **Time-Series Metrics**: Persisted in Docker named volume `timescale_data` (`/home/postgres/pgdata/data`).
- **Application Config & Backups**: Stored in named volumes `tracearr_data` and `tracearr_backups`.
- **Cached Artwork**: Stored in `tracearr_images`.

---

## 🩺 Healthcheck & Monitoring

- **TimescaleDB Health**: Verified every 10s via `pg_isready -U tracearr_app`.
- **Redis Broker Health**: Verified every 10s via `redis-cli ping`.
- **Web Application**: Evaluated via Traefik ingress metrics and internal HTTP endpoints.
