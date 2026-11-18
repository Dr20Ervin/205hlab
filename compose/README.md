# Docker Compose Stacks — Production Homelab Orchestration

[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2.30+-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![CI: Validate Compose](https://github.com/Dr20Ervin/205hlab/actions/workflows/validate-compose.yml/badge.svg)](https://github.com/Dr20Ervin/205hlab/actions/workflows/validate-compose.yml)
[![Stacks](https://img.shields.io/badge/Production%20Stacks-23%20Active-007ACC?style=for-the-badge)](https://github.com/Dr20Ervin/205hlab/tree/main/compose)
[![Network Isolation](https://img.shields.io/badge/Network-Microsegmented-2ea44f?style=for-the-badge&logo=wireguard&logoColor=white)](#-network-topology--microsegmentation)
[![Resource Limits](https://img.shields.io/badge/Limits-Strict%20CPU%20%26%20RAM-9b51e0?style=for-the-badge)](#-production-engineering-standards)
[![Central Database](https://img.shields.io/badge/Data%20Tier-PostgreSQL%2018%20%26%20TimescaleDB-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](postgres/)
[![ADRs](https://img.shields.io/badge/Architecture-ADRs%20001--006-blue?style=for-the-badge)](../docs/adr/README.md)
[![Runbooks](https://img.shields.io/badge/Operations-5%20Runbooks-238636?style=for-the-badge)](../docs/runbooks/README.md)

This directory houses the **23 production Docker Compose stacks** powering the `205hlab` bare-metal infrastructure. Every stack is engineered as an autonomous, self-contained unit adhering to uniform DevOps standards: strict cgroup resource constraints, standardized healthchecks, isolated bridge networks, centralized persistence, and zero-trust edge authentication.

---

## 📑 Master Stack Catalog

| Stack | Category | Primary Ingress URL | Auth Model | Data & Persistence | Dedicated Runbook |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[`authentik`](authentik/)** | IAM & Security | `https://authentik.205hlab.com` | **IdP Core** | PostgreSQL 18 (DB & Worker Queue) | [Runbook](authentik/README.md) |
| **[`traefik`](traefik/)** | Edge Routing & TLS | `https://*.205hlab.com` | **Edge Middleware** | Let's Encrypt DNS-01 (`acme.json`) | [Runbook](traefik/README.md) |
| **[`technitium`](technitium/)** | DNS & Ad-Blocking | `https://technitium.internal.205hlab.com` | Method 1 (Native OIDC) | Authoritative Zones, Catalog Sync | [Runbook](technitium/README.md) |
| **[`postgres`](postgres/)** | Relational Data Tier | `https://adminer.internal.205hlab.com` | Method 2 (ForwardAuth) | PostgreSQL 18 (`--data-checksums`), Adminer | [Runbook](postgres/README.md) |
| **[`databasus`](databasus/)** | Backup & Verification | `https://databasus.internal.205hlab.com` | Method 2 (ForwardAuth) | Automated `pg_dump`, `databasus-verifier` Agent | [Runbook](databasus/README.md) |
| **[`prometheus`](prometheus/)** | Metrics TSDB | `https://prometheus.internal.205hlab.com` | Internal LAN Only | 30d TSDB Retention (50 GB cap) | [Runbook](prometheus/README.md) |
| **[`prom-exporters`](prom-exporters/)** | Telemetry Scrapers | *(Internal Scrape Targets)* | Internal Scrape Network | Host `/proc`, `/sys`, `/dev/zfs`, S.M.A.R.T. | [Runbook](prom-exporters/README.md) |
| **[`grafana`](grafana/)** | Observability UI | `https://grafana.205hlab.com` | Method 1 (Native OIDC) | Provisioned Dashboards, SQLite | [Runbook](grafana/README.md) |
| **[`paperless`](paperless/)** | Document OCR Archive | `https://paperless.205hlab.com` | Method 1 (Native OIDC) | PostgreSQL 18, Valkey 9, Tika, Gotenberg | [Runbook](paperless/README.md) |
| **[`mealie`](mealie/)** | Recipe & Meal Planner | `https://mealie.205hlab.com` | Method 1 (Native OIDC) | PostgreSQL 18, Named Volume | [Runbook](mealie/README.md) |
| **[`freshrss`](freshrss/)** | Release Sentinel / RSS | `https://freshrss.205hlab.com` | Method 1 (Native OIDC) | PostgreSQL 18, Dynamic OPML Feeds | [Runbook](freshrss/README.md) |
| **[`reactive-resume`](reactive-resume/)** | Career Builder | `https://resume.205hlab.com` | Method 1 (Native OIDC) | PostgreSQL 18, Valkey 9 Queue | [Runbook](reactive-resume/README.md) |
| **[`jelly`](jelly/)** | Media Streaming & Seerr | `https://jellyfin.205hlab.com` | Method 1 (SSO) / Method 2 | Intel HD 4000 VAAPI, ZFS Media Pools | [Runbook](jelly/README.md) |
| **[`kavita`](kavita/)** | Digital Reading Library | `https://kavita.205hlab.com` | Method 1 (Native OIDC) | Read-only Book/Manga ZFS Mounts | [Runbook](kavita/README.md) |
| **[`servarr`](servarr/)** | Media Automation Suite | `https://*.205hlab.com` (sonarr, radarr...) | Method 1 (Profilarr) / Method 2 | PostgreSQL 18 (`*-main`), SQLite | [Runbook](servarr/README.md) |
| **[`downloaderr`](downloaderr/)** | Acquisition Engine | `https://qui.205hlab.com`, `metube...` | Method 1 (qui) / Method 2 | PostgreSQL 18, AirVPN WireGuard | [Runbook](downloaderr/README.md) |
| **[`tracearr`](tracearr/)** | Stream Analytics | `https://tracearr.205hlab.com` | Method 2 (ForwardAuth) | TimescaleDB Hypertables, Redis 8 | [Runbook](tracearr/README.md) |
| **[`searxng`](searxng/)** | Private Metasearch | `https://search.205hlab.com` | Method 2 (ForwardAuth) | Valkey 9 Cache, AirVPN WireGuard | [Runbook](searxng/README.md) |
| **[`network-mon`](network-mon/)** | Network Diagnostics | `https://speedtest.205hlab.com` | Method 2 (ForwardAuth) / LAN | PostgreSQL 18, Host Port Binds | [Runbook](network-mon/README.md) |
| **[`uptime-kuma`](uptime-kuma/)** | Observability & Sentinel | `https://uptime.205hlab.com`<br>`https://status.205hlab.com` | Method 2 (ForwardAuth) / Public | MariaDB 11.6, Docker Socket, MNGT Port Bind | [Runbook](uptime-kuma/README.md) |
| **[`changedetection`](changedetection/)** | Web Diff & Alerting | `https://changedetection.internal...` | Method 2 (ForwardAuth) | Playwright Stealth Chrome Engine | [Runbook](changedetection/README.md) |
| **[`vikunja`](vikunja/)** | Task & Maintenance Reminders | `https://vikunja.205hlab.com` | Method 1 (Native OIDC) | PostgreSQL 18 (`vikunja`), `vikunja-data` | [Runbook](vikunja/README.md) |
| **[`web-tools`](web-tools/)** | Client-Side WASM Utilities | `https://it-tools.205hlab.com` (omni, draw, pdf) | Method 2 (ForwardAuth) | Stateless (`read_only: true` Rootfs) | [Runbook](web-tools/README.md) |

---

## 🏗️ Cross-Stack Architecture & Dependency Graph

The stacks operate in a layered topology where foundational services (Ingress, DNS, IAM, and Databases) provision shared capabilities to application workloads:

```mermaid
flowchart TD
    subgraph Layer0["Tier 0: Edge Ingress & Network Hardening"]
        Traefik["traefik (v3.7.18)\nEdge Proxy & ACME TLS"]
        Technitium["technitium (15.6.2)\nSplit-Horizon Authoritative DNS"]
    end

    subgraph Layer1["Tier 1: Identity & Centralized State"]
        Authentik["authentik (2026.8.5)\nCentralized OIDC & ForwardAuth"]
        Postgres["postgres (18.3)\nCentralized DB with Checksums"]
        Databasus["databasus (v3.65.0)\nBackups & databasus-verifier Agent"]
        Timescale["tracearr-timescaledb\nTimescaleDB HA Cluster"]
        Postgres -.->|Daily Backups| Databasus
    end

    subgraph Layer2["Tier 2: Observability & Telemetry"]
        Prometheus["prometheus (v3.11.3)\nCentral TSDB Engine"]
        Exporters["prom-exporters\n(Node, cAdvisor, ZFS, S.M.A.R.T.)"]
        Grafana["grafana (13.0.1)\nTelemetry Dashboards"]
        UptimeKuma["uptime-kuma (v2)\nMariaDB & Ingress Sentinel"]
        Exporters -->|Scrape| Prometheus
        UptimeKuma -.->|Metrics| Prometheus
        Prometheus -->|Data Source| Grafana
    end

    subgraph Layer3["Tier 3: Productivity & Household SaaS"]
        Paperless["paperless (Paperless-ngx)"]
        Mealie["mealie (Recipes)"]
        FreshRSS["freshrss (Release Sentinel)"]
        Resume["reactive-resume (Builder)"]
        Vikunja["vikunja (Tasks & Maintenance)"]
        WebTools["web-tools (IT-Tools, Draw, PDF)"]
        SearXNG["searxng (Private Search)"]
        ChangeDet["changedetection (Diff Alerts)"]
        NetMon["network-mon (Speedtest, MyIP)"]
    end

    subgraph Layer4["Tier 4: Media Streaming & Automation"]
        Jellyfin["jelly (Jellyfin & Seerr)"]
        Kavita["kavita (Books & Manga)"]
        Servarr["servarr (*arr Suite)"]
        Downloaderr["downloaderr (qBittorrent & qui)"]
        Tracearr["tracearr (Analytics)"]
    end

    %% Ingress & Auth Wiring
    Traefik <-->|ForwardAuth Check| Authentik
    Traefik -->|Routed HTTPS| Layer3
    Traefik -->|Routed HTTPS| Layer4
    Traefik -->|Routed HTTPS| Grafana

    %% Persistence Wiring
    Layer3 -->|SQL Connections| Postgres
    Layer4 -->|SQL Connections| Postgres
    Tracearr -->|Time-Series SQL| Timescale
    Authentik -->|App DB| Postgres
```

---

## 🔒 Two-Tier Authentication Strategy

Every container in this repository follows a strict access hierarchy defined in [`compose/authentik/`](authentik/README.md):

```
                                  Incoming Ingress Request
                                              │
                     ┌────────────────────────┴────────────────────────┐
                     │                                                 │
            Application supports                              Application lacks
            Native OIDC / OAuth2                              Native OIDC support
                     │                                                 │
                     ▼                                                 ▼
      ┌─────────────────────────────┐                   ┌─────────────────────────────┐
      │   METHOD 1: Native OIDC     │                   │   METHOD 2: ForwardAuth     │
      │                             │                   │                             │
      │ • Client ID & Client Secret │                   │ • Traefik Edge Interception │
      │ • PKCE Verification         │                   │ • authentik@docker Header   │
      │ • In-App User Provisioning  │                   │ • Zero Unauth Packet Reach  │
      │ • Role/Group Entitlements   │                   │ • Instant Session Timeout   │
      └─────────────────────────────┘                   └─────────────────────────────┘
```

1. **Method 1: Native OpenID Connect (OIDC)**  
   Preferred for applications with built-in OAuth2 support (e.g. Mealie, Paperless-ngx, FreshRSS, Grafana, Kavita, Reactive Resume, Technitium, and Jellyfin SSO). The application receives standardized claims (`email`, `groups`, `preferred_username`) and handles user profiles and role mapping internally.

2. **Method 2: Traefik ForwardAuth (Proxy Provider)**  
   Enforced at the reverse proxy layer for applications without native OIDC (e.g. Sonarr, Radarr, Prowlarr, Bazarr, Chaptarr, Adminer, MeTube, BentoPDF, IT-Tools, SearXNG, and Speedtest Tracker). The request is intercepted by Traefik and redirected to Authentik for verification before any packets reach the upstream container.

---

## 🌐 Network Topology & Microsegmentation

Containers never share a single flat Docker bridge network. Instead, external bridge networks segregate distinct architectural responsibilities:

| Network Name | Driver | External | Purpose & Connected Workloads |
| :--- | :--- | :--- | :--- |
| **`traefik_network`** | `bridge` | `true` | Ingress gateway. Connects Traefik to all HTTP-serving containers. Direct inter-container communication across apps is blocked. |
| **`postgres_network`** | `bridge` | `true` | Isolated database tier. Connects central PostgreSQL 18 and Adminer only to database consumers (Authentik, Mealie, Paperless, FreshRSS, Servarr, qui, Reactive Resume, Speedtest, Vikunja). Port 5432 is never exposed to the host LAN. |
| **`monitoring_network`**| `bridge` | `true` | Telemetry bus. Dedicated for Prometheus scraping of cAdvisor, Node Exporter, PostgreSQL Exporter, Technitium Exporter, and Traefik metrics. |
| **`servarr_backend`** | `bridge` | `true` | Automation pipeline. Interconnects Sonarr, Radarr, Lidarr, Prowlarr, Seerr, Bazarr, and the download clients (qBittorrent, qui). |
| **Stack-Internal** | `bridge` | `false` | Private subnets declared within individual stacks (e.g., `paperless_internal`, `tracearr_internal`, `searxng_internal`) for local worker-to-broker queues. |

---

## 🛡️ Production Engineering Standards

All 22 compose stacks enforce standardized operational rules:

1. **Strict Resource Constraints**:  
   Every container defines explicit cgroup limits preventing rogue processes or memory leaks from destabilizing the host:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '1.0'
         memory: 1G
   ```
2. **Automated Healthchecks**:  
   Every service defines a native `healthcheck` testing application viability (`interval: 30s-60s`, `retries: 3-5`), enabling automated restart policies upon deadlock.
3. **Log Rotation Caps**:  
   Docker daemon and container definitions enforce log rollover (`max-size: 10m`, `max-file: 3`) to prevent host storage exhaustion during high-volume debug cycles.
4. **Principle of Least Privilege**:  
   Services run with `security_opt: no-new-privileges:true`. Rootless container execution and read-only mounts (`:ro`) are enforced wherever possible (e.g., in Web Tools, Tika, Gotenberg, and media consumers).
5. **Zero-Plaintext Secrets & Dockhand Injection**:  
   In production, secrets are managed and injected at deploy time via **Dockhand's encrypted database**, ensuring that **no plain-text `.env` files containing production secrets exist on the host disk**. Secret values are masked (`***`) in the Dockhand UI and cannot be retrieved after saving. Every stack folder in this repository contains:
   - `compose.yaml`: Version-controlled service definitions using strict variable parameterization (`${VARIABLE:?error_message}`).
   - `example.env`: Fully documented non-sensitive environment template with parameter guards.
   - `setup_secrets.sh`: Executable script for generating cryptographically secure test/bootstrap tokens via `openssl rand -hex`.
   - `.env`: Git-ignored local file used exclusively during offline bootstrap or development testing.

---

## 🚀 Standard Operating Procedures (SOP)

### 1. Primary Lifecycle: Automated CI/CD (GitHub Actions + Dockhand GitOps)

In production on the Ubuntu Server, manual SSH commands are minimized in favor of a two-stage CI/CD pipeline (architectural rationale documented in [**ADR-004**](../docs/adr/ADR-004-dockhand-gitops-continuous-deployment.md)):

```
[ Developer / Admin Workstation ]
               │ git commit && git push
               ▼
[ GitHub Repository (Dr20Ervin/205hlab) ]
               │
               ▼
   [ GitHub Actions CI Gate ] ──► Dynamically discovers & lints all compose stacks
               │ (Pass)
               ▼
[ Dockhand (Primary Node: Ubuntu Server) ]
   ├── Scheduled Git pull & sync
   ├── Injects encrypted secrets at deploy time (No .env on disk)
   ├── Automates zero-downtime stack redeployments
   └── Observes remote HAOS node via Hawser Agent (v0.2.52)
```

1. **Continuous Integration (CI):** Every push or PR touching `compose/**` triggers [`.github/workflows/validate-compose.yml`](../.github/workflows/validate-compose.yml). GitHub Actions dynamically scans all stack directories at runtime, validating syntax and variable resolution against their `example.env` templates before code can be deployed.
2. **Continuous Deployment (CD / GitOps):** Once validated on `main`, **Dockhand** on the Ubuntu Server periodically pulls repository updates, dynamically injects encrypted secrets from its vault, and redeploys containers.
3. **Auxiliary Node Monitoring (ASUS X540SA / HAOS):** Connected to Dockhand via a **Hawser agent (standard v0.2.52)**.
   > [!IMPORTANT]
   > The GitHub repository is **not** synced to or executed on the HAOS machine. Home Assistant strictly manages its own operating system and add-ons natively. Dockhand + Hawser on the X540SA is used exclusively for **remote multi-node container observation, resource monitoring, and administrative troubleshooting/fixing**.

---

### 2. Manual CLI Operations (Emergency Fallback & Initial Provisioning)

If bootstrapping a brand new server or conducting offline maintenance:

#### A. Initial Stack Bootstrapping

```bash
cd compose/<stack-name>

# 1. Create environment configuration from template
cp example.env .env

# 2. Generate cryptographically strong secrets
chmod +x setup_secrets.sh && ./setup_secrets.sh

# 3. Adjust site-specific variables (FQDN, OIDC IDs, etc.)
nano .env

# 4. If the stack uses PostgreSQL, execute its db-init.sql against the database
docker exec -i postgres psql -U postgres < db-init.sql

# 5. Launch stack in background mode
docker compose up -d

# 6. Verify healthcheck status and live logs
docker compose ps
docker compose logs -f
```

#### B. Safe Manual Stack Upgrade

```bash
cd compose/<stack-name>

# 1. Pull the latest image specified in compose.yaml
docker compose pull

# 2. Recreate containers with zero downtime when possible
docker compose up -d --remove-orphans

# 3. Clean up dangling images to conserve SSD storage
docker image prune -f
```

#### C. Graceful Stack Teardown

```bash
# Stop containers while preserving all data volumes
docker compose down

# Stop and remove internal networks (volumes remain untouched)
docker compose down --remove-orphans
```

#### D. Database & Data Backup Runbook

- **PostgreSQL Databases & Automated Restore Verification:** Backed up automatically via **Databasus** (`databasus.internal.205hlab.com`) in [`compose/databasus/`](databasus/), which schedules daily `pg_dump` jobs onto dedicated datasets on OpenZFS mirror pool **`BinPool`** (`${DATABASUS_BACKUP}`) alongside an official containerized **`databasus-verifier`** agent (`./verification-agent run`) that validates restores into ephemeral containers after each backup (**RPO:** `24h` · **Target RTO:** `< 15m` single DB / `< 30m` full cluster). Database dumps are manually replicated from `BinPool` to secondary offline LAN storage. See [**`docs/runbooks/disaster-recovery.md`**](../docs/runbooks/disaster-recovery.md) for verification checks, single-DB rollbacks, and cold bare-metal recovery procedures.
- **Critical State & Appliance Configs:** High-value documents (Paperless-ngx `media/`), appliance snapshots (OpenWrt `.tar.gz`, HAOS `.tar`, Technitium `.zip`), and Dockhand state (`/app/data` + master encryption key) are backed up to `BinPool` and copied to secondary LAN devices as part of the intermediate data protection posture.
- **Storage Roadmap:** Future expansion will introduce an upgraded OpenZFS pool and a fully automated 3-2-1 backup pipeline (local SSD $\rightarrow$ mechanical ZFS pool `BinPool` $\rightarrow$ encrypted offsite cloud storage).
