# ADR-006: Deploy Dual-Instance Uptime Kuma Monitoring Topology with Dedicated MariaDB and Out-of-Band HAOS Watchdog

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-11` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | Observability & Reliability |
| **Related Stacks & Docs** | [`compose/uptime-kuma/`](../../compose/uptime-kuma/), [`compose/traefik/`](../../compose/traefik/), [`compose/authentik/`](../../compose/authentik/), [`ADR-001`](ADR-001-centralized-postgresql-18.md), [`ADR-005`](ADR-005-decouple-smart-home-haos-appliance.md) |

---

## Context and Problem Statement

`205hlab` operates 22 production Docker Compose stacks on a primary bare-metal tower (**Fujitsu ESPRIMO P710**). Internal health and resource consumption are monitored through **Prometheus**, **cAdvisor**, **Node Exporter**, and specialized database/storage scrapers.

However, this architecture suffers from a foundational observability blind spot:
1. **Coupled Telemetry Failure Domain**: Because Prometheus and Grafana reside on the primary server, if the Ubuntu kernel crashes, hardware fails, or the tower is powered off for maintenance, all telemetry silently ceases. The administrator receives no out-of-band notification that the homelab has gone dark.
2. **Absence of Blackbox Probing & TLS Tracking**: While container processes report runtime status, the environment lacked synthetic HTTP(S) blackbox verification to test end-to-end Traefik ingress routing, reverse proxy responsiveness, and impending TLS certificate expiry (> 14d warning, > 7d alert).
3. **Absence of Public Status Reporting**: Household members and external consumers of services (`jellyfin`, `paperless`, `freshrss`, `searxng`) had no independent, unauthenticated public status page to check whether an issue was local or server-wide.
4. **Database Concurrency in Uptime Kuma**: Uptime Kuma is the industry standard for lightweight blackbox synthetic monitoring and public status pages, but upstream does **not** support PostgreSQL ([ADR-001](ADR-001-centralized-postgresql-18.md)). Default deployments rely on SQLite, which suffers severe file-level write locking (`SQLITE_BUSY: database is locked`) when recording concurrent heartbeats from 25+ monitors, and carries database corruption risks during abrupt host reboots.

## Decision Drivers

- **Out-of-Band Fault Isolation**: An auxiliary watchdog must run on physically isolated, battery-backed hardware ([ADR-005](ADR-005-decouple-smart-home-haos-appliance.md)) to detect and alert on primary server failure.
- **Dual-Domain Ingress Segregation**: Provide clean, unauthenticated public status visibility at `status.205hlab.com` while strictly gating administrative monitoring controls at `uptime.205hlab.com` behind Authentik SSO.
- **Direct Management Port Accessibility**: Allow the auxiliary watchdog to directly probe the primary Uptime Kuma process over the LAN/management IP (`${MNGT_IP}:3001`), bypassing Traefik, Authentik, and Cloudflare.
- **Database Durability & Concurrency**: Eliminate SQLite lock contention and database bloat without breaking the centralized PostgreSQL baseline.
- **Immediate Incident Dispatch**: Push instant, actionable notifications to a private Discord channel via Discord Webhooks with differentiated severity.

## Considered Options

1. **Option 1 (Chosen):** Dual-Instance Topology: Primary **Uptime Kuma v2** with Dedicated **MariaDB 11.6** Sidecar on Primary Server + Decoupled Auxiliary Watchdog on **ASUS X540SA** (HAOS)
2. **Option 2:** Single Uptime Kuma Instance with Built-in SQLite on Primary Compute Server
3. **Option 3:** Prometheus Alertmanager Solo with Prometheus Blackbox Exporter

### Options Analysis

#### Option 1 — Dual-Instance Topology: Primary (MariaDB) + Auxiliary (HAOS Watchdog)
- **Pros:**
  - **True Out-of-Band Resilience**: The auxiliary instance runs on the battery-backed **ASUS X540SA** companion laptop. If the primary Fujitsu server crashes or loses power, the auxiliary watchdog immediately fires an emergency Discord alert (`#infrastructure-alerts`).
  - **MariaDB Concurrency & Zero SQLite Bloat**: Official MariaDB support in Uptime Kuma v2 provides InnoDB row-level locking, handling rapid concurrent heartbeat writes without `SQLITE_BUSY` errors or database corruption.
  - **Clean Dual Routing**: `status.205hlab.com` is public for household users; `uptime.205hlab.com` is gated behind Authentik Proxy Provider / ForwardAuth.
  - **Decoupled HAOS Boundary**: Preserves [ADR-005](ADR-005-decouple-smart-home-haos-appliance.md) by running the auxiliary watchdog inside the native HAOS ecosystem, exposed via Cloudflare Tunnel with independent 2FA and zero Git repository entanglement.
- **Cons:**
  - Introduces a second container (`uptime-kuma-db`) into `compose/uptime-kuma/` requiring ~180 MB of RAM.

#### Option 2 — Single Uptime Kuma Instance with Built-in SQLite
- **Pros:**
  - Minimal configuration footprint; single container deployment.
- **Cons:**
  - **Zero Out-of-Band Capability**: If the primary server fails, Uptime Kuma dies with it; no alert is ever dispatched.
  - **SQLite Locking & Instability**: File-level locking causes heartbeat timeouts and high CPU usage during vacuuming. Database is prone to corruption on sudden power cuts.

#### Option 3 — Prometheus Alertmanager Solo with Prometheus Blackbox Exporter
- **Pros:**
  - Fits directly into the existing Prometheus/Grafana pipeline without introducing a new software ecosystem.
- **Cons:**
  - No built-in, polished public status page for household users.
  - Significantly heavier configuration overhead for synthetic checks and TLS expiration tracking.
  - Still vulnerable to primary host downtime unless Alertmanager is clustered onto the low-spec Celeron HAOS node.

## Decision Outcome

**Chosen Option:** **Option 1 — Dual-Instance Topology with Dedicated MariaDB and HAOS Auxiliary Watchdog**

The observability architecture is divided into two cooperative tiers:

1. **Primary Compute Tier (`uptime-kuma` on Fujitsu ESPRIMO P710)**:
   - **Engine**: Deployed in `compose/uptime-kuma/` using `louislam/uptime-kuma:2`.
   - **Dedicated Persistence**: Backed by a dedicated **MariaDB 11.6** sidecar (`uptime-kuma-db`) running in an isolated bridge network (`uptime_kuma_backend`) with tuned buffer pool (`128M`) and row-level locking.
   - **Direct Port Bind**: Binds `${MNGT_IP}:3001` on the host management interface for direct LAN scraping.
   - **Deep Monitoring**: Probes local container health via `/var/run/docker.sock:ro`, verifies Traefik HTTP routes and TLS certificate expiration across `*.205hlab.com` and `*.internal.205hlab.com`, and checks PostgreSQL `:5432` availability.
   - **Ingress & IAM**:
     - `uptime.205hlab.com`: Protected by Authentik Proxy Provider (`authentik@docker`) bound to group `kuma_admins`. Built-in auth is disabled in Kuma.
     - `status.205hlab.com`: Routed directly via Traefik without Authentik to serve public status. Hardened in **Stealth Mode** with a strict Traefik path whitelist (`Path(/)` and `PathPrefix(/status, /assets, /api/status-page, etc.)`); any request to administrative paths (`/dashboard`, `/settings`, `/manage-status-page`, or `/socket.io`) returns a dead-end `404 Not Found` without redirection, completely masking the admin hostname and preventing unauthorized access through the public status domain.
   - **Alert Channel**: Pushes application, container, and certificate alerts to Discord (`#homelab-monitoring`).
2. **Auxiliary Out-of-Band Tier (`uptime-kuma-aux` on ASUS X540SA)**:
   - **Engine**: Deployed as a native Home Assistant OS add-on on the battery-backed ASUS X540SA laptop.
   - **Access**: Exposed via Cloudflare Tunnel with native 2FA (TOTP), completely independent of Authentik and GitOps sync ([ADR-005](ADR-005-decouple-smart-home-haos-appliance.md)).
   - **Watchdog Scope**: Continuously probes the primary server IP, direct Uptime Kuma port (`${MNGT_IP}:3001`), Technitium DNS (`:53`), OpenWrt router gateway (`192.168.1.1`), and WAN uplink (`1.1.1.1`).
   - **Alert Channel**: Pushes emergency host-down and network failure alerts to Discord (`#infrastructure-alerts`) with `@everyone` push notification.

## Consequences

### Positive Consequences
- **Zero Observability Blind Spot**: Complete out-of-band detection for catastrophic server outages, power failure, or network cuts.
- **High Concurrency & Database Reliability**: MariaDB InnoDB row-level locking eliminates SQLite write deadlocks and corruption risks permanently.
- **Household Transparency**: Public status page at `status.205hlab.com` provides real-time service visibility without exposing internal topology or requiring Authentik credentials.
- **Edge Security**: The administrative console at `uptime.205hlab.com` is protected by unified Authentik SSO.

### Negative Consequences & Mitigations
- **Trade-off (Two Database Engines in Production)**: Adds MariaDB alongside PostgreSQL 18.  
  *Mitigation:* MariaDB is strictly encapsulated inside `compose/uptime-kuma/` on a private bridge network (`uptime_kuma_backend`) dedicated exclusively to Kuma. It does not interface with the shared PostgreSQL cluster and uses minimal memory (~180 MB).
- **Trade-off (Dual-Instance Maintenance)**: Managing two distinct Kuma configurations.  
  *Mitigation:* The auxiliary watchdog on HAOS maintains a minimal, static probe catalog (5 probes total) that rarely changes, while active application monitoring is managed on the primary instance.

## Compliance & Verification (Fitness Functions)

- **Compose Validation**: `compose/uptime-kuma/compose.yaml` validates cleanly in CI (`validate-compose.yml`) with strict resource limits (`limits.cpus: '0.5'`, `limits.memory: 256M` for Kuma; `cpus: '0.5'`, `memory: 384M` for MariaDB).
- **Network Isolation**: MariaDB is attached only to `uptime_kuma_backend`; port 3306 is never bound to host interfaces.
- **Authentik Protection**: Traefik router `uptime_kuma_admin_https` enforces `authentik@docker` middleware, while `uptime_kuma_status_https` serves unauthenticated status traffic.
- **Prometheus Metric Scrape**: Prometheus scrapes `uptime-kuma:3001/metrics` every 30s for historical telemetry in Grafana.
