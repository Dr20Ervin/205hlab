# Mealie — Recipe Manager & Household Meal Planner

[![Mealie](https://img.shields.io/badge/Mealie-latest-E5533A?style=for-the-badge&logo=mealie&logoColor=white)](https://mealie.io/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://mealie.205hlab.com`  
> **Upstream Project:** [mealie-recipes/mealie](https://github.com/mealie-recipes/mealie)  
> **Category:** Household SaaS / Productivity

Mealie is a self-hosted recipe manager and meal planning platform for the household. It enables automated recipe scraping from URLs, family cookbook management, interactive meal planning, and dynamic grocery shopping lists. In this homelab, Mealie runs with a dedicated PostgreSQL 18 database and native Authentik OpenID Connect (OIDC) authentication with group-based RBAC.

---

## 🏗️ Architecture & Dependencies

```
[ Client Browser ]
        │ HTTPS (Cloudflare ACME TLS)
        ▼
[ Traefik Proxy (:443) ]
        │ Internal Docker Bridge (traefik_network)
        ▼
[ Mealie Container (:9000) ]
   ├── OIDC Auth Exchange ──► Authentik Server (https://authentik.205hlab.com)
   ├── Database Persistence ──► PostgreSQL 18 (postgres_network)
   └── Recipe Data Mount ──► Named Volume: mealie-data (/app/data/)
```

- **Networks:**
  - `traefik_network` (external bridge): Receives routed HTTPS traffic from Traefik.
  - `postgres_network` (external bridge): Isolated communication with the central PostgreSQL 18 instance.
- **Database:** Dedicated database `mealie` on PostgreSQL 18, isolated user `mealie_app`.
- **Resource Constraints:** Governed with `limits: cpus: '1.0'`, `memory: 1G`.
- **Storage:** Named volume `mealie_data` mapped to `/app/data/` for uploaded recipe images and assets.

---

## 🔐 Authentik Integration (Method 1: Native OIDC)

Mealie integrates natively with Authentik via OpenID Connect (OIDC) using application entitlements for role mapping (`OIDC_GROUPS_CLAIM=entitlements`).

### 1. Authentik Provider Setup
1. In the Authentik Admin Interface, navigate to **Applications** > **Providers** > **Create**.
2. Select **OAuth2/OpenID Connect Provider**:
   - **Name:** `Mealie Provider`
   - **Client Type:** `Confidential`
   - **Redirect URIs (Strict):**
     - `https://mealie.205hlab.com/login`
     - `https://mealie.205hlab.com/login?direct=1`
   - **Signing Key:** Select your default certificate/signing key.
   - **Selected Scopes:**
     - `openid`
     - `email`
     - `profile`
     - `authentik default OAuth Mapping: Application Entitlements`
3. Click **Submit** and copy the generated **Client ID** and **Client Secret**.

### 2. Authentik Application & Entitlements
1. Navigate to **Applications** > **Applications** > **Create**.
   - **Name:** `Mealie`
   - **Slug:** `mealie`
   - **Provider:** Select `Mealie Provider`.
2. Open the created `Mealie` application, click the **Application entitlements** tab, and create two entitlements:
   - `mealie-users` → Bind to group `mealie_users`
   - `mealie-admins` → Bind to group `mealie_admins`
   *(Users in `mealie_admins` are automatically granted Administrator privileges inside Mealie; standard members in `mealie_users` receive standard household access.)*

### 3. Container OIDC Parameters
These environment variables are pre-configured in `compose.yaml`:
```yaml
environment:
  - OIDC_AUTH_ENABLED=true
  - OIDC_PROVIDER_NAME=authentik
  - OIDC_CONFIGURATION_URL=https://authentik.205hlab.com/application/o/mealie/.well-known/openid-configuration
  - OIDC_CLIENT_ID=${OIDC_CLIENT_ID}
  - OIDC_CLIENT_SECRET=${OIDC_CLIENT_SECRET}
  - OIDC_GROUPS_CLAIM=entitlements
  - OIDC_USER_GROUP=mealie-users
  - OIDC_ADMIN_GROUP=mealie-admins
  - ALLOW_PASSWORD_LOGIN=false
  - OIDC_AUTO_REDIRECT=true
  - OIDC_REMEMBER_ME=true
```

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root user/group ID | `1000` / `1000` |
| `DEFAULT_GROUP` | Default recipe sharing group | `Home` |
| `DEFAULT_HOUSEHOLD` | Default household context | `Home` |
| `POSTGRES_HOST` | Central database hostname | `postgres` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_DB` | Database name | `mealie` |
| `POSTGRES_USER` | Database username | `mealie_app` |
| `POSTGRES_PASSWORD` | Database password | *(generated via `setup_secrets.sh`)* |
| `SMTP_HOST` | Outbound mail server | `mail.example.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USER` / `SMTP_PASSWORD` | Mail credentials | *(smtp credentials)* |
| `OIDC_CLIENT_ID` | Authentik OAuth2 Client ID | *(from Authentik provider)* |
| `OIDC_CLIENT_SECRET` | Authentik OAuth2 Client Secret | *(from Authentik provider)* |

---

## 🚀 Deployment & First-Time Setup

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Provision Database & User**:
   Execute `db-init.sql` against the central PostgreSQL instance (or ensure the database and user exist):
   ```sql
   CREATE DATABASE mealie;
   CREATE USER mealie_app WITH ENCRYPTED PASSWORD '...';
   GRANT ALL PRIVILEGES ON DATABASE mealie TO mealie_app;
   ```

2. **Initialize Secrets & Environment**:
   ```bash
   cd compose/mealie
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Populate FQDN, OIDC_CLIENT_ID, OIDC_CLIENT_SECRET, and SMTP credentials
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify First Login**:
   Navigate to `https://mealie.205hlab.com`. You should be seamlessly redirected to Authentik for single sign-on. Users belonging to `mealie_admins` will immediately have the **Admin** badge in Mealie settings.

---

## 💾 Backup & Data Persistence

- **Database**: All recipes, meal plans, timelines, and user links reside in PostgreSQL (`mealie` database). Included in automated `pg_dump` schedules.
- **Images & Files**: Recipe photos and assets are stored in Docker volume `mealie_data` (`/app/data/`).
- **Backup Command**:
  ```bash
  # Backup Database
  docker exec -t postgres pg_dump -U mealie_app -d mealie > mealie_backup.sql
  ```

---

## 🩺 Healthcheck & Monitoring

- **Container Health**: Built-in HTTP healthcheck querying `http://localhost:9000/api/app/about` every 30s.
- **Traefik Ingress**: Health and uptime metrics tracked via Traefik's Prometheus endpoint.
