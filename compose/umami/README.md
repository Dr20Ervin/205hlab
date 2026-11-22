# Umami — Privacy-First Web Analytics & Hybrid Telemetry Hub

[![Umami](https://img.shields.io/badge/Umami-v3-000000?style=for-the-badge&logo=umami&logoColor=white)](https://umami.is)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Admin Dashboard (LAN Only):** `https://umami.internal.205hlab.com` *(Protected by Authentik ForwardAuth · Group: `umami_admins`)*  
> **Public Stealth Collector (WAN + LAN):** `https://analytics.205hlab.com` *(Strict whitelist: `/pulse.js` and `/api/collect` only)*  
> **Category:** Observability & Privacy Analytics  
> **Related Docs:** [**ADR-001**](../../docs/adr/ADR-001-centralized-postgresql-18.md), [**ADR-002**](../../docs/adr/ADR-002-authentik-unified-iam.md), [**ADR-003**](../../docs/adr/ADR-003-split-horizon-technitium-dns.md), [**Traefik Runbook**](../traefik/README.md), and [**Disaster Recovery**](../../docs/runbooks/disaster-recovery.md)

**Umami v3** serves as the self-hosted, cookieless web analytics engine for `205hlab`. It runs a **hybrid telemetry architecture** that separates public client-side portfolio metrics from ad-blocker-proof server-side proxy telemetry across other homelab services, backed by the centralized **PostgreSQL 18** cluster (`--data-checksums`).

---

## 🏗️ Hybrid Telemetry Architecture & Stealth Isolation

```
[ Portfolio Visitor (me.205hlab.com) ]         [ Public App Visitor (e.g. status.205hlab.com) ]
                 │                                                      │
                 │ GET /pulse.js & POST /api/collect                    │ HTTPS Request
                 ▼                                                      ▼
   ┌───────────────────────────────────────────────────────────────────────────────┐
   │                        Traefik v3 Reverse Proxy (:443)                        │
   │                                                                               │
   │  • Public Stealth Router (analytics.205hlab.com)                              │
   │    Strict Path Whitelist + CF-Connecting-IP Rate Limit                        │
   │    (All admin/login paths return dead-end 404)                                │
   │                                                                               │
   │  • Server-Side Feeder Middleware (umami-feeder@file)                          │
   │    Batches HTTP hits asynchronously via traefik-umami-feeder                  │
   │                                                                               │
   │  • Admin Router (umami.internal.205hlab.com)                                  │
   │    LAN-Only Split-Horizon Zone + Authentik ForwardAuth (authentik@docker)     │
   └───────────┬───────────────────────────┬───────────────────────────┬───────────┘
               │                           │                           │
               │ Public Script / Collect   │ Internal /api/send        │ Authenticated UI
               ▼                           ▼                           ▼
   ┌───────────────────────────────────────────────────────────────────────────────┐
   │                              umami (:3000)                                    │
   │  • Renamed Script: TRACKER_SCRIPT_NAME=pulse.js                               │
   │  • Renamed Endpoint: COLLECT_API_ENDPOINT=/api/collect                        │
   │  • LAN/VPN Exclusion: IGNORE_IP=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16       │
   └───────────────────────────────────────┬───────────────────────────────────────┘
                                           │ postgres_network (:5432)
                                           ▼
                                [ PostgreSQL 18 (umami DB) ]
```

### 1. Client-Side Collector (`https://analytics.205hlab.com`)
- Used by the static portfolio (`me.205hlab.com`) via `<script defer src="https://analytics.205hlab.com/pulse.js" ...>` to capture pageviews, screen sizes, session duration, and custom click events (`data-umami-event`).
- **Renamed Tracker & Endpoint:** Uses `TRACKER_SCRIPT_NAME=pulse.js` and `COLLECT_API_ENDPOINT=/api/collect` instead of the default `/script.js` and `/api/send` paths to reduce false-positive blocks from generic filter lists.
- **Stealth Path Whitelist:** The public Traefik router (`umami_collector_https`) matches **only** `Path('/pulse.js') || Path('/api/collect')` (matching the configured `UMAMI_TRACKER_SCRIPT_NAME` and `UMAMI_COLLECT_API_ENDPOINT`) and enforces per-IP rate limiting (`30 req/s` average, `60` burst keyed by `CF-Connecting-IP`). Any probe to `/login`, `/dashboard`, or `/api/auth` returns a dead-end `404` without revealing or redirecting to the internal admin hostname.

### 2. Server-Side Traefik Middleware (`traefik-umami-feeder`)
- For other homelab services (`status.205hlab.com`, etc.), [`github.com/astappiev/traefik-umami-feeder`](https://github.com/astappiev/traefik-umami-feeder) forwards request metadata directly over the internal `traefik_network` to `http://umami:3000` (`/api/send` / `/api/batch`) without modifying container HTML or relaxing upstream CSP headers.
- See [`../traefik/dynamic/umami.example.yml`](../traefik/dynamic/umami.example.yml) and [`../traefik/README.md`](../traefik/README.md) for setup and middleware chaining rules.
- **Double-Counting Prevention:** Never attach `umami-feeder@file` to `me.205hlab.com` (already tracked client-side), `analytics.205hlab.com`, `umami.internal.205hlab.com`, or `authentik.205hlab.com`.

### 3. Protected Admin Dashboard (`https://umami.internal.205hlab.com`)
- Exists strictly in Technitium's private `internal.205hlab.com` split-horizon zone ([ADR-003](../../docs/adr/ADR-003-split-horizon-technitium-dns.md))—never exposed in public Cloudflare DNS.
- Guarded at Traefik by `authentik@docker` ForwardAuth.

### 4. Dual-Path Client IP Resolution (WAN + Split-Horizon LAN)
- `CLIENT_IP_HEADER` is **intentionally left unset**.
- Umami's built-in header precedence evaluates `cf-connecting-ip` first and falls back to `x-real-ip` and `x-forwarded-for`.
- This ensures Cloudflare-proxied WAN visitors resolve to their real client IP, while split-horizon LAN clients (which hit Traefik directly without `CF-Connecting-IP`) fall back to their LAN IP so `IGNORE_IP` excludes homelab traffic cleanly.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `POSTGRES_HOST` | Central PostgreSQL 18 hostname | `postgres` |
| `POSTGRES_PORT` | Central PostgreSQL port | `5432` |
| `POSTGRES_USER` | Dedicated PostgreSQL role | `umami_app` |
| `POSTGRES_DB` | Dedicated PostgreSQL database | `umami` |
| `POSTGRES_PASSWORD` | Database password | *(Generated via `setup_secrets.sh`)* |
| `UMAMI_APP_SECRET` | Cryptographic secret signing Umami tokens | *(Generated via `setup_secrets.sh`)* |
| `UMAMI_TRACKER_SCRIPT_NAME` | Public JS filename (no leading slash) | `pulse.js` |
| `UMAMI_COLLECT_API_ENDPOINT` | Public ingestion path (leading slash required) | `/api/collect` |
| `UMAMI_IGNORE_IP` | Comma-separated CIDRs excluded from analytics | `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` |

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

1. Log in to Authentik (`https://authentik.205hlab.com`) and create a **Proxy Provider** (`Forward auth (single application)`) with external host `https://umami.internal.205hlab.com` and internal host `http://umami:3000`.
2. Create an **Application** (`umami`) bound to the **`umami_admins`** group.
3. Attach the application to the **`authentik Embedded Outpost`**.

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to `main` are pulled automatically, with `POSTGRES_PASSWORD` and `UMAMI_APP_SECRET` injected at deploy time from Dockhand's encrypted vault (zero plaintext `.env` files on disk).

### First-Time Initialization

1. **Generate Secrets & Database Init Script**:
   ```bash
   cd compose/umami
   bash setup_secrets.sh
   ```
2. **Initialize PostgreSQL 18 (`umami` DB)**:
   Execute [`db-init.sql`](db-init.sql) (after replacing the placeholder password) or the generated `create_umami_db.sql` against the default `postgres` database (`docker exec -i postgres psql -U postgres_admin -d postgres < create_umami_db.sql`, or via Adminer). Because `CREATE DATABASE umami OWNER umami_app;` assigns database ownership to `umami_app` (`pg_database_owner` on PostgreSQL 15–18), `umami_app` owns `umami`'s `public` schema automatically so Umami's Prisma migrations run out of the box. Remove `create_umami_db.sql` afterward.
3. **Configure DNS**:
   - **Cloudflare (Public):** Proxied record for `analytics.205hlab.com` (do **not** publish `umami.internal.205hlab.com`).
   - **Technitium (Split-Horizon LAN):** Ensure `analytics.205hlab.com` and `umami.internal.205hlab.com` resolve to Traefik's LAN IP.
4. **Deploy via Dockhand (or Manual Fallback)**:
   ```bash
   cp example.env .env
   nano .env # Populate POSTGRES_PASSWORD & UMAMI_APP_SECRET
   docker compose up -d
   ```
5. **First Login & Password Rotation**:
   Open `https://umami.internal.205hlab.com` (after Authentik SSO), sign in with default `admin` / `umami`, and **change the password immediately**. Then add your websites (`me.205hlab.com`, `status.205hlab.com`, etc.) to generate their Website UUIDs.
6. **Wire Up `traefik-umami-feeder` (Optional)**:
   Copy [`../traefik/dynamic/umami.example.yml`](../traefik/dynamic/umami.example.yml) to `${DYNAMIC_PATH}/umami.yml` with your real Website UUIDs **before** attaching `umami-feeder@file` to any Traefik router labels.

---

## 💾 Backup & Data Persistence

- **Zero Local Container Volumes:** All analytics events, website definitions, and user accounts live inside PostgreSQL 18 (`umami` database).
- **Automated Backups (`Databasus`):** Register the `umami` database in `databasus.internal.205hlab.com` so nightly `pg_dump` archives are written to `BinPool` and restore-verified by `databasus-verifier`.

---

## 🩺 Healthcheck & Verification

- **Container Healthcheck:** Evaluated every 30s via `curl -fsS http://127.0.0.1:3000/api/heartbeat || exit 1`.
- **Live Edge & Stealth Verification:**
  ```bash
  # Expect 200 OK serving the renamed tracker script
  curl -I https://analytics.205hlab.com/pulse.js

  # Expect 404 Not Found (admin/login routes hidden on public collector domain)
  curl -I https://analytics.205hlab.com/login
  ```
