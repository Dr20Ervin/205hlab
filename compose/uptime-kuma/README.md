# Uptime Kuma — Service Sentinel & Public Status Page

[![Uptime Kuma](https://img.shields.io/badge/Uptime%20Kuma-v2-13B567?style=for-the-badge&logo=uptimekuma&logoColor=white)](https://uptime.kuma.pet/)
[![Database](https://img.shields.io/badge/Database-MariaDB%2011.6-003545?style=for-the-badge&logo=mariadb&logoColor=white)](https://mariadb.org/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)
[![Telemetry](https://img.shields.io/badge/Metrics-Prometheus%20Scrape-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)

> **Admin Dashboard:** `https://uptime.205hlab.com` *(Protected by Authentik SSO · Group: `kuma_admins`)*  
> **Public Status Page:** `https://status.205hlab.com` *(Public / Unauthenticated)*  
> **Direct Management Port:** `${MNGT_IP}:3001` *(Out-of-band LAN probe for HAOS watchdog)*  
> **Access Group:** `kuma_admins`  
> **Category:** Observability & Uptime Sentinel  
> **Architecture Decision Record:** See [**ADR-006: Deploy Dual-Instance Uptime Kuma Monitoring Topology with Dedicated MariaDB**](../../docs/adr/ADR-006-dual-instance-uptime-kuma-monitoring.md)

Uptime Kuma serves as the primary blackbox monitoring sentinel and status reporting engine for `205hlab`. It provides real-time HTTP(S) synthetic probing, automated TLS certificate expiry alerts, internal Docker container state inspection via the host Docker daemon socket, and internal PostgreSQL port availability tracking. It operates alongside an out-of-band auxiliary watchdog instance (`uptime-kuma-aux`) running on the dedicated battery-backed **ASUS X540SA** companion host (Home Assistant OS).

---

## 🏗️ Architecture & Dual-Instance Sentinel Topology

```
[ Public / Household Visitors ]               [ Administrator ]
               │                                       │
               │ HTTPS (status.205hlab.com)             │ HTTPS (uptime.205hlab.com)
               ▼                                       ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                 Traefik v3 Reverse Proxy                     │
  └───────────────┬────────────────────────────┬─────────────────┘
                  │ (Public Ingress)           │ (ForwardAuth Gate)
                  │                            ▼
                  │                 ┌──────────────────────┐
                  │                 │ Authentik SSO Outpost│
                  │                 └──────────┬───────────┘
                  │                            │ (Authenticated)
                  ▼                            ▼
  ┌──────────────────────────────────────────────────────────────┐
  │              uptime-kuma:2  (:3001)                          │
  │  • Container Healthchecks (/var/run/docker.sock:ro)          │
  │  • HTTP/S Synthetic Probes & TLS Cert Expiry Monitoring       │
  │  • PostgreSQL Listener (postgres:5432)                       │
  │  • Discord Webhook Dispatch (#homelab-monitoring)            │
  └───────────────┬────────────────────────────┬─────────────────┘
                  │ Internal Bridge            │ Port Bind
                  ▼                            ▼
  ┌────────────────────────────┐    ┌──────────────────────────┐
  │  uptime-kuma-db (MariaDB)  │    │  ${MNGT_IP}:3001 Bind    │
  │  InnoDB Row-Level Locking  │    └──────────▲───────────────┘
  └────────────────────────────┘               │ Direct LAN Probe
                                               │
               ┌───────────────────────────────┴────────────────────────┐
               │    Auxiliary Watchdog: uptime-kuma-aux (HAOS Node)     │
               │    • Decoupled Battery-Backed ASUS X540SA Appliance    │
               │    • Cloudflare Tunnel + Native 2FA (No Authentik)     │
               │    • Probes: ${MNGT_IP}:3001, Server Ping, DNS, WAN    │
               │    • Emergency Discord Webhook: #infrastructure-alerts │
               └────────────────────────────────────────────────────────┘
```

- **Dual-Instance Separation**:
  - **Primary Node (`uptime-kuma`)**: Runs on the primary Ubuntu Server node (**Fujitsu ESPRIMO P710**). Deeply monitors local container states, internal services, and TLS certificates.
  - **Auxiliary Watchdog (`uptime-kuma-aux`)**: Runs out-of-band on the **ASUS X540SA** companion host (Home Assistant OS per [ADR-005](../../docs/adr/ADR-005-decouple-smart-home-haos-appliance.md)). Powered by internal laptop battery and the APC UPS, it probes `${MNGT_IP}:3001`, host ICMP ping, Technitium DNS (`:53`), and WAN connectivity. If the primary host shuts down or kernel panics, the watchdog immediately pushes an emergency alert to Discord.
- **Direct Management Port (`${MNGT_IP}:3001`)**: Bypasses Traefik, Authentik, and Cloudflare. Allows the HAOS watchdog to directly verify whether the main Uptime Kuma process is responsive.
- **Resource Constraints**:
  - `uptime-kuma`: Governed with `limits: cpus: '0.5'`, `memory: 256M`.
  - `uptime-kuma-db`: Governed with `limits: cpus: '0.5'`, `memory: 384M`.

---

## 🗄️ Dedicated MariaDB Architecture (Why Not SQLite?)

While `205hlab` standardizes centrally on PostgreSQL 18 ([ADR-001](../../docs/adr/ADR-001-centralized-postgresql-18.md)), upstream Uptime Kuma does not support PostgreSQL. Instead, it supports **SQLite** and **MariaDB** (introduced officially in v2).

A dedicated **MariaDB 11.6** sidecar is deployed for Uptime Kuma for critical reliability reasons:

1. **Elimination of `SQLITE_BUSY` Locking**: SQLite locks the entire database file during write operations. With 25+ Docker containers and multiple HTTP endpoints writing heartbeat intervals every 20s–60s, SQLite frequently deadlocks, dropping metrics and reporting false-positive timeouts.
2. **InnoDB Row-Level Concurrency**: MariaDB handles high-frequency concurrent writes via row-level locks and multi-connection pooling (`UPTIME_KUMA_DB_POOL_MAX_CONNECTIONS=10`).
3. **Crash & Power-Cut Resilience**: MariaDB with InnoDB journaling prevents database corruption during sudden host crashes or power outages, unlike SQLite's WAL journal which can corrupt when ungracefully terminated.
4. **Isolated Bridge Footprint**: MariaDB runs strictly within `uptime_kuma_backend`, isolated from all other containers, and uses an optimized buffer pool (`--innodb-buffer-pool-size=128M`) consuming under 200 MB of RAM.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth / Proxy Provider)

Uptime Kuma does not provide native OIDC. It integrates with Authentik via a **Proxy Provider** running behind Traefik ForwardAuth:

### Step 1: Create Application & Provider in Authentik

1. Log in to Authentik as an administrator at `https://authentik.205hlab.com`.
2. Navigate to **Applications** > **Applications** and click **New Application**:
   - **Name**: `Uptime Kuma`
   - **Slug**: `uptime-kuma`
   - **Group**: `Monitoring & Observability`
3. Click **Next** and select **Proxy Provider** as the provider type.
4. Configure the Proxy Provider:
   - **Name**: `uptime-kuma-proxy`
   - **Authorization flow**: `default-provider-authorization-explicit-consent` (or default flow)
   - **Mode**: `Forward auth (single application)`
   - **External host**: `https://uptime.205hlab.com`
   - **Internal host**: `http://uptime-kuma:3001`
   - **Advanced protocol settings** > **Unauthenticated Paths**:
     Add the following regex patterns to permit public access to status pages, badges, push monitor endpoints, and static assets without requiring an Authentik session:
     ```text
     ^/status(/.*)?$
     ^/status-page$
     ^/assets/.*
     ^/api/push/.*
     ^/api/badge/.*
     ^/api/status-page/.*
     ^/icon.svg$
     ^/upload/.*
     ```
5. Click **Submit** to save the application and provider.

### Step 2: Configure Policy & Group Binding (RBAC)

1. Under the newly created `Uptime Kuma` application, navigate to the **Policy / Group / User Bindings** tab.
2. Click **Bind existing policy** and select **Group**: choose **`kuma_admins`**.
3. Set policy order and click **Submit**. Only users assigned to the `kuma_admins` group in Authentik are authorized to pass ForwardAuth and access the admin dashboard.

### Step 3: Assign to Proxy Outpost

1. Navigate to **Applications** > **Outposts**.
2. Edit the **authentik Embedded Outpost** (or proxy outpost).
3. Under **Available Applications**, select `Uptime Kuma` and move it to **Selected Applications**.
4. Click **Update**.

### Step 4: Configure Uptime Kuma Dashboard

1. Log in to the Uptime Kuma dashboard with the initial local admin credentials.
2. Navigate to **Settings** > **Security**.
3. Under **Advanced**, click **Disable Auth** and confirm with the administrator password (delegating all authentication to Authentik).
4. Navigate to **Settings** > **Reverse Proxy** and set **Trust Proxy** to **Yes**.

### Step 5: Public Status Page Configuration & Admin UI Isolation

1. In Uptime Kuma, click **Status Pages** > **New Status Page** (or edit existing).
2. Under status page settings, set **Domain Name / Custom Domain** to `status.205hlab.com`.
3. Visitors accessing `https://status.205hlab.com` are served the public status page directly via Traefik without ever being prompted by Authentik.
4. **Strict Ingress Isolation & Attack Surface Prevention**:
   - Because built-in authentication is disabled in favor of Authentik, exposing `status.205hlab.com` without path protection would allow anyone to browse to `/dashboard` unauthenticated.
   - Traefik enforces a **Strict Path Whitelist** on `status.205hlab.com` allowing only `Path(/)` and `PathPrefix(/status, /status-page, /assets, /api/status-page, /api/badge, /icon.svg, /upload)`.
   - Traefik blocks administrative WebSocket traffic (`/socket.io`) from `status.205hlab.com`.
   - **Stealth Mode (Zero-Leak Security)**: Traefik does not redirect admin attempts to `uptime.205hlab.com`. Any request to non-whitelisted paths (`/dashboard`, `/settings`, `/manage-status-page`, `/socket.io`, or arbitrary endpoints) returns a dead-end **`404 Not Found`**, completely hiding the admin hostname from external visitors. Administrative access is only possible by explicitly navigating to `https://uptime.205hlab.com` through Authentik SSO.

---

## 📢 Discord Webhook Alerting Strategy

Both Uptime Kuma instances dispatch alerts to private Discord channels via Discord Webhooks:

| Instance | Notification Channel | Bot Identity | Severity / Trigger Scope |
| :--- | :--- | :--- | :--- |
| **Primary (`uptime-kuma`)** | `#homelab-monitoring` | `205hlab Sentinel (Primary)` | Container crashes, HTTP 5xx errors, database timeouts, TLS expiry (< 14d warning, < 7d alert). |
| **Auxiliary (`uptime-kuma-aux`)** | `#infrastructure-alerts` | `205hlab Watchdog (Aux - HAOS)` | Main server down (`${MNGT_IP}` unreachable), Primary DNS down (`:53`), Gateway offline, WAN cut. Fires `@everyone` emergency mention. |

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `MNGT_IP` | Host management IP for direct out-of-band watchdog probe | `192.168.1.50` |
| `UPTIME_KUMA_PORT` | Direct host port binding for Uptime Kuma | `3001` |
| `KUMA_DB_NAME` | Dedicated MariaDB database name | `uptime_kuma` |
| `KUMA_DB_USER` | Dedicated MariaDB application username | `kuma_app` |
| `KUMA_DB_PASSWORD` | Cryptographically secure database password | *(Generated via `setup_secrets.sh`)* |
| `KUMA_DB_ROOT_PASSWORD` | MariaDB root administrative password | *(Generated via `setup_secrets.sh`)* |

---

## 🚀 Standard Operating Procedures (SOP)

### First-Time Initialization
1. Generate secure credentials:
   ```bash
   bash setup_secrets.sh
   ```
2. Deploy the stack:
   ```bash
   docker compose up -d
   ```
3. Follow the [Authentik Integration Guide](#-authentik-integration-method-2-traefik-forwardauth--proxy-provider) to link `https://uptime.205hlab.com` and disable local authentication.

### Database Backup & Maintenance
MariaDB data persists in the Docker volume `uptime-kuma-db-data`. To take an ad-hoc dump:
```bash
docker exec uptime-kuma-db mariadb-dump -u root -p"${KUMA_DB_ROOT_PASSWORD}" uptime_kuma > uptime_kuma_backup.sql
```
