# Vikunja — Task Management, Kanban & Homelab Maintenance Reminders

[![Vikunja](https://img.shields.io/badge/Vikunja-latest-1976D2?style=for-the-badge&logo=vikunja&logoColor=white)](https://vikunja.io/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://vikunja.205hlab.com`  
> **Upstream Project:** [code.vikunja.io/vikunja](https://code.vikunja.io/vikunja) / [Docker Hub](https://hub.docker.com/r/vikunja/vikunja)  
> **Category:** Household SaaS / Productivity & Maintenance Automation  
> **Decisions & Runbooks:** [**ADR-001**](../../docs/adr/ADR-001-centralized-postgresql-18.md), [**ADR-002**](../../docs/adr/ADR-002-authentik-unified-iam.md), and [**Disaster Recovery Runbook**](../../docs/runbooks/disaster-recovery.md).

**Vikunja** is an open-source, full-featured task and project management application. In `205hlab`, it serves two primary operational roles:
1. **Personal & Household Productivity:** Managing general to-do lists, kanban boards, Gantt timelines, and project checklists.
2. **Homelab Operational Governance & Maintenance Reminders:** Serving as the definitive scheduling tool for recurring manual infrastructure maintenance tasks that cannot be fully automated headlessly (e.g., manual configuration backup exports from OpenWrt, Home Assistant OS, Technitium DNS, secondary offline copy synchronization of ZFS `BinPool` snapshots, and scheduled UPS battery runtime load tests).

---

## 🏗️ Architecture & Dependencies

```
[ Client Browser / CalDAV Client ]
             │ HTTPS (Cloudflare ACME TLS)
             ▼
   [ Traefik Proxy (:443) ]
             │ Internal Docker Bridge (traefik_network) [X-Forwarded-For: Client IP]
             ▼
    [ Vikunja Container (:3456) ]
       ├── OIDC Auth & End-Session ──► Authentik Server (https://authentik.205hlab.com)
       ├── Database Persistence ──► PostgreSQL 18 + unaccent (postgres_network)
       ├── Config Provider Map ──► Host Mount: ${VIKUNJA_CONFIG_DIR} (/etc/vikunja:ro)
       └── Task Attachments Mount ──► Named Volume: vikunja-data (/app/vikunja/files)
```

- **Networks:**
  - `traefik_network` (external bridge): Receives routed HTTPS traffic from Traefik. Client IPs are extracted via `X-Forwarded-For` with `VIKUNJA_SERVICE_IPEXTRACTIONMETHOD=xff` and `VIKUNJA_TRUSTED_PROXIES`.
  - `postgres_network` (external bridge): Isolated communication with the central PostgreSQL 18 instance.
- **Database:** Dedicated database `vikunja` on PostgreSQL 18, isolated user `vikunja_app`, with `unaccent` extension enabled for accent-insensitive search.
- **Resource Constraints:** Governed with `limits: cpus: '0.5'`, `memory: 512M`.
- **Storage:** Named volume `vikunja_data` mapped to `/app/vikunja/files` for uploaded task attachments and assets.

---

## 📋 Homelab Maintenance Workflow (The "Manual Backup & Drill" Schedule)

Vikunja is configured with a dedicated **"Homelab Operations & Disaster Recovery"** project tracking recurring tasks:

| Recurrence | Task Name | Operational Procedure & Target Location | Reference |
| :--- | :--- | :--- | :--- |
| **Weekly** | **Technitium DNS Backup Export** | Log in to primary (`technitium.internal.205hlab.com`) & auxiliary DNS admin consoles -> Export configuration `.zip` -> Store in `BinPool/backup-manual/technitium/`. | [ADR-003](../../docs/adr/ADR-003-split-horizon-technitium-dns.md) |
| **Bi-Weekly** | **Home Assistant OS Snapshot Export** | Log in to HAOS appliance web UI -> Create full backup -> Download `.tar` archive to `BinPool/backup-manual/haos/` & offsite copy. | [ADR-005](../../docs/adr/ADR-005-decouple-smart-home-haos-appliance.md) |
| **Monthly** | **OpenWrt Router Config Archive** | Navigate to LuCI -> *System* -> *Backup / Flash Firmware* -> *Generate archive* (`backup-OpenWrt-*.tar.gz`) -> Store in `BinPool/backup-manual/openwrt/`. | [Disaster Recovery](../../docs/runbooks/disaster-recovery.md) |
| **Monthly** | **BinPool Offline Cold Copy** | Manually sync Databasus PostgreSQL dumps from `/BinPool/backups/postgres` and `/BinPool/backup-manual/` to external cold storage / offsite drive. | [Disaster Recovery](../../docs/runbooks/disaster-recovery.md) |
| **Quarterly** | **ZFS Scrub Verification** | Check `zpool status -v BinPool` scrub results; schedule deep scrub if not auto-triggered. | [Power & Storage Runbook](../../docs/runbooks/power-outage-and-storage-health.md) |
| **Semi-Annual** | **NUT UPS Self-Test & Battery Calibration** | Initiate self-test on APC Back-UPS XS 950U (`apc-950va`); verify charge cutoff limits (`65%` / `300s`). | [Power & Storage Runbook](../../docs/runbooks/power-outage-and-storage-health.md) |

---

## 🔐 Authentik Integration (Native OIDC)

Vikunja integrates natively with Authentik via OpenID Connect (OIDC) for single sign-on, allowing both web and desktop client authentication.

### 1. Authentik Application & Provider Creation
1. Log in to the Authentik Admin Interface (`https://authentik.205hlab.com`) as an administrator.
2. Navigate to **Applications** > **Applications** and click **New Application** (or create a provider under **Applications** > **Providers** > **Create**).
3. Configure the **Application**:
   - **Name:** `Vikunja`
   - **Slug:** `vikunja`
   - **Group:** `Household SaaS`
   - **Launch URL:** `https://vikunja.205hlab.com/login?redirectToProvider=authentik` *(triggers seamless 1-click SSO redirect directly to Authentik)*
4. Choose **OAuth2/OpenID Connect** as the provider type and configure the **Provider**:
   - **Name:** `Vikunja Provider`
   - **Authorization flow:** Default authorization flow
   - **Client Type:** `Confidential`
   - **Signing Key:** Select your default certificate/signing key
   - **Redirect URIs:**
     - **Web Login (`Strict` · `Authorization`):**
       - `https://vikunja.205hlab.com/auth/openid/authentik`
     - **Desktop Client (`Regex` · `Authorization`):**
       - `^http://127\.0\.0\.1:[0-9]+/auth/openid/authentik$`
   - **Selected Scopes:** `openid`, `email`, `profile` *(optionally add `groups` if using standard OIDC group sync)*.
5. Click **Submit** and copy the generated **Client ID** and **Client Secret**.
6. Bind the application to group `vikunja_users` under **Application** > **Policy / Group Bindings**.

### 2. Vikunja Provider Map (`config.yml`)
Because Vikunja uses Viper for configuration loading, using environment variables for OIDC providers requires declaring the provider key in `config.yml` on the host under `${VIKUNJA_CONFIG_DIR}/config.yml` (mounted at `/etc/vikunja:ro`):

```bash
# Provision config directory and template on the host (e.g. in /srv/vikunja/config)
sudo mkdir -p /srv/vikunja/config
cat <<'EOF' | sudo tee /srv/vikunja/config/config.yml
auth:
  openid:
    providers:
      authentik: {}
EOF
```

The provider key `authentik` matches the final path segment of the redirect URI (`/auth/openid/authentik`).

### 3. Environment Variable Binding (`.env`)
Vikunja maps the Authentik credentials dynamically via environment variables:

```env
VIKUNJA_AUTH_OPENID_ENABLED=true
VIKUNJA_AUTH_OPENID_PROVIDERS_AUTHENTIK_NAME="authentik Login"
VIKUNJA_AUTH_OPENID_PROVIDERS_AUTHENTIK_AUTHURL=https://authentik.205hlab.com/application/o/vikunja/
VIKUNJA_AUTH_OPENID_PROVIDERS_AUTHENTIK_LOGOUTURL=https://authentik.205hlab.com/application/o/vikunja/end-session/
VIKUNJA_AUTH_OPENID_PROVIDERS_AUTHENTIK_CLIENTID=<Client ID from authentik>
VIKUNJA_AUTH_OPENID_PROVIDERS_AUTHENTIK_CLIENTSECRET=<Client Secret from authentik>
VIKUNJA_AUTH_OPENID_PROVIDERS_AUTHENTIK_SCOPE="openid email profile"
VIKUNJA_AUTH_LOCAL_ENABLED=false
```

- **Enforced SSO:** Setting `VIKUNJA_AUTH_LOCAL_ENABLED=false` disables local database authentication, mandating Authentik SSO.
- **Account Linking:** In Vikunja 2.8.0+, local accounts can be safely linked from **Settings > Linked accounts**. The legacy `emailfallback` and `usernamefallback` options are deprecated to prevent account takeover risks ([GHSA-8pm4-w983-mx58](https://github.com/go-vikunja/vikunja/security/advisories/GHSA-8pm4-w983-mx58)).
- **Mobile Apps:** Android and iOS apps use embedded webviews. Using the "Login with frontend" option in the mobile client is recommended to avoid webview session/cookie issues.

### 4. Automatic Team Synchronization (Optional)
Vikunja supports two methods for automatically provisioning teams from Authentik groups:
- **Standard `groups` Claim (Vikunja 2.8.0+):** Add `groups` to `VIKUNJA_OIDC_SCOPE="openid email profile groups"`. When Authentik delivers a `groups` claim list, Vikunja creates and syncs corresponding teams marked with `(OIDC)`.
- **Custom `vikunja_scope` Property Mapping:** In Authentik, create a scope property mapping named `vikunja_scope` with expression:
  ```python
  groupsDict = {"vikunja_groups": []}
  for group in request.user.ak_groups.all():
      groupsDict["vikunja_groups"].append({"name": group.name, "oidcID": group.num_pk})
  return groupsDict
  ```
  Then set `VIKUNJA_OIDC_SCOPE="openid email profile vikunja_scope"`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `VIKUNJA_CONFIG_DIR` | Host path for config directory containing `config.yml` | `/srv/vikunja/config` |
| `VIKUNJA_TRUSTED_PROXIES` | Trusted reverse proxy CIDR ranges for X-Forwarded-For | *(required, e.g. `127.0.0.1/32,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`)* |
| `POSTGRES_HOST` | Central database hostname | `postgres` |
| `POSTGRES_DB` | Database name | `vikunja` |
| `POSTGRES_USER` | Database username | `vikunja_app` |
| `POSTGRES_PASSWORD` | Database password | *(generated via `setup_secrets.sh`)* |
| `VIKUNJA_SERVICE_SECRET` | Secret key for JWT tokens and cryptographic operations | *(generated via `setup_secrets.sh`)* |
| `VIKUNJA_ENABLE_REGISTRATION` | Public self-registration | `false` |
| `VIKUNJA_AUTH_LOCAL_ENABLED` | Allow local password login | `false` *(forces Authentik SSO)* |
| `VIKUNJA_OIDC_ENABLED` | Enable OIDC provider | `true` |
| `VIKUNJA_OIDC_CLIENT_ID` | Authentik OAuth2 Client ID | *(from Authentik provider)* |
| `VIKUNJA_OIDC_CLIENT_SECRET` | Authentik OAuth2 Client Secret | *(from Authentik provider)* |
| `VIKUNJA_OIDC_SCOPE` | OIDC Scopes requested | `openid profile email` |
| `SMTP_ENABLED` | Outbound mail alerting | `false` |

---

## 🚀 Deployment & First-Time Setup

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates.

1. **Provision Database & User**:
   Execute `db-init.sql` against the central PostgreSQL instance via Adminer (`adminer.internal.205hlab.com`) or `psql` (or execute the output of `setup_secrets.sh`):
   ```sql
   CREATE USER vikunja_app WITH PASSWORD '...';
   CREATE DATABASE vikunja OWNER vikunja_app;
   GRANT ALL PRIVILEGES ON DATABASE vikunja TO vikunja_app;
   ```
   *(Optional for accent-insensitive search in Vikunja 2.8+: in Adminer, switch to database `vikunja` and run `CREATE EXTENSION IF NOT EXISTS unaccent;`)*.

2. **Initialize Host Config, Secrets & Environment**:
   ```bash
   # Create host config directory and copy config.yml template
   sudo mkdir -p /srv/vikunja/config
   sudo cp config.yml /srv/vikunja/config/config.yml

   cd compose/vikunja
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Populate FQDN, VIKUNJA_CONFIG_DIR (/srv/vikunja/config), VIKUNJA_TRUSTED_PROXIES, VIKUNJA_OIDC_CLIENT_ID, and VIKUNJA_OIDC_CLIENT_SECRET
   ```

3. **Ensure Attachment Volume Permissions (`uid=1000`)**:
   Docker initializes named volumes as `root:root` (`uid=0`), but Vikunja runs unprivileged as `uid=1000`. Grant user 1000 ownership to the volume:
   ```bash
   docker run --rm -v vikunja-data:/app/vikunja/files alpine chown -R 1000:1000 /app/vikunja/files
   ```

4. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

5. **Verify First Login**:
   Navigate to `https://vikunja.205hlab.com`. With `redirectToProvider=authentik` configured, you will be seamlessly redirected to Authentik for single sign-on. Log in once to create your user account in the database.

6. **Promote Your User to Instance Administrator**:
   Because Vikunja provisions users via OIDC without external admin claim mapping, promote your user to administrator using either method:
   - **Method A (CLI inside container):**
     ```bash
     docker exec -it vikunja /app/vikunja/vikunja user set-admin <username> --admin
     ```
     *(Or by user ID: `docker exec -it vikunja /app/vikunja/vikunja user set-admin 1 --admin`)*.
   - **Method B (Via Adminer `adminer.internal.205hlab.com`):**
     Connect to the `vikunja` database in Adminer, open **SQL command**, and execute:
     ```sql
     UPDATE users SET is_admin = true WHERE username = 'your_username';
     ```
   *(Log out and log back in to Vikunja to activate administrative permissions and the admin interface).*

---

## 🔄 CalDAV Client Synchronization

Vikunja exposes a native CalDAV interface allowing two-way synchronization with mobile and desktop task clients (Apple Reminders, Thunderbird, iOS, Android via DAVx⁵):

- **CalDAV Base URL:** `https://vikunja.205hlab.com/dav/`
- **Authentication:** Use an **API Token** generated inside Vikunja (*Settings* > *API Tokens* with read/write permissions for CalDAV).

---

## 💾 Backup & Data Persistence

- **Database**: All task lists, kanban cards, checklists, and user mappings reside in PostgreSQL (`vikunja` database). Included in automated daily `pg_dump` jobs by **Databasus** to `/BinPool/backups/postgres` and validated by `databasus-verifier`.
- **Files & Attachments**: Uploaded card attachments and avatars are stored in Docker volume `vikunja_data` (`/app/vikunja/files`).
- **30-Day Trash (Vikunja 2.8.0+)**: Soft-deleted tasks and projects are moved to the Trash and can be restored for 30 days before permanent purging.
- **Backup Command**:
  ```bash
  # Backup Database
  docker exec -t postgres pg_dump -U vikunja_app -d vikunja > vikunja_backup.sql
  ```

---

## 🩺 Healthcheck & Monitoring

- **Service Health**: Vikunja exposes native unauthenticated health endpoints at `/health` and `/api/v2/health`.
- **Prometheus Metrics**: Vikunja includes a built-in Prometheus metrics endpoint available at `/api/v1/metrics` (when enabled via `VIKUNJA_METRICS_ENABLED=true`).
- **Traefik Ingress**: Uptime, request volume, and latency metrics tracked via Traefik's Prometheus endpoint.

---

## 🛠️ Troubleshooting

### Volume Permission Denied (`mkdir /app/vikunja/files/.tmp: permission denied`)
Because Vikunja runs as an unprivileged user (`uid=1000`) while Docker initializes named volumes as `root` (`uid=0`), Vikunja may fail to initialize its storage backend on fresh deployments or volume recreations:
```
Could not init file handler: storage validation failed: failed to create test file: mkdir /app/vikunja/files/.tmp: permission denied
[process uid=1000 gid=0, dir owner uid=0 gid=0]
```

**Fix:** Re-apply ownership of user `1000` to the named volume using a one-off Alpine container:
```bash
docker run --rm -v vikunja-data:/app/vikunja/files alpine chown -R 1000:1000 /app/vikunja/files
docker compose restart vikunja
```
