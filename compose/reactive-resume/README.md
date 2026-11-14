# Reactive Resume — Privacy-First CV & Resume Builder

[![Reactive Resume](https://img.shields.io/badge/Reactive%20Resume-latest-00B4D8?style=for-the-badge&logo=googledocs&logoColor=white)](https://rxresu.me/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Broker](https://img.shields.io/badge/Broker-Valkey%209-CC342D?style=for-the-badge&logo=redis&logoColor=white)](https://valkey.io)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://resume.205hlab.com`  
> **Upstream Project:** [AmruthPillai/Reactive-Resume](https://github.com/AmruthPillai/Reactive-Resume)  
> **Category:** Household SaaS / Career Utilities

Reactive Resume is a free, open-source, privacy-respecting resume builder. It enables building structured, multi-page resumes, tailoring dynamic versions for specific job postings, exporting print-ready PDFs, and sharing public portfolio links without user tracking or telemetry. In this homelab, Reactive Resume runs alongside a dedicated Valkey 9 broker, central PostgreSQL 18 persistence, and native Authentik OpenID Connect (OIDC) authentication.

---

## 🏗️ Architecture & Dependencies

```
[ Client Browser ]
        │ HTTPS (Cloudflare ACME TLS)
        ▼
[ Traefik Proxy (:443) ]
        │ Internal Docker Bridge (traefik_network)
        ▼
[ Reactive Resume (:3000) ]
   ├── OIDC Authentication ──► Authentik Server (https://authentik.205hlab.com)
   ├── Session & Task Caching ──► Valkey 9 Broker (reactive-resume-valkey:6379)
   ├── Relational Persistence ──► PostgreSQL 18 (postgres_network)
   └── Document & Asset Mount ──► Named Volume: app_data (/app/data)
```

- **Networks:**
  - `traefik_network` (external bridge): Ingress routing from Traefik.
  - `postgres_network` (external bridge): Direct database communication.
  - `reactive-resume_backend` (internal bridge): Isolated communication between Reactive Resume and its Valkey 9 broker.
- **Resource Constraints:**
  - `reactive-resume`: Governed with `limits: cpus: '1.0'`, `memory: 1G`.
  - `valkey`: Governed with `limits: cpus: '0.5'`, `memory: 512M`.

---

## 🔐 Authentik Integration (Method 1: Native OIDC)

Reactive Resume natively integrates with Authentik via OIDC authorization code flow.

### 1. Authentik Provider Setup
1. In the Authentik Admin Interface, navigate to **Applications** > **Providers** > **Create**.
2. Select **OAuth2/OpenID Connect Provider**:
   - **Name:** `Reactive Resume Provider`
   - **Client Type:** `Confidential`
   - **Redirect URI (Strict):** `https://resume.205hlab.com/api/auth/callback/custom`
   - **Signing Key:** Select your default certificate/signing key.
   - **Selected Scopes:** `openid`, `profile`, `email`.
3. Click **Submit** and copy the **Client ID** and **Client Secret**.

### 2. Authentik Application & Policy
1. Navigate to **Applications** > **Applications** > **Create**:
   - **Name:** `Reactive Resume`
   - **Slug:** `reactive-resume`
   - **Provider:** Select `Reactive Resume Provider`.
2. Under **Application** > **Policy / Group Bindings**, bind the group `reactive-resume_users` to restrict access to authorized household accounts.

### 3. Container Configuration
These environment variables are pre-configured in `compose.yaml`:
```yaml
environment:
  - APP_URL=https://resume.205hlab.com
  - OAUTH_PROVIDER_NAME=Authentik
  - OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID}
  - OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET}
  - OAUTH_DISCOVERY_URL=https://authentik.205hlab.com/application/o/reactive-resume/.well-known/openid-configuration
  - OAUTH_SCOPES=openid profile email
  - FLAG_DISABLE_SIGNUPS=false
  - FLAG_DISABLE_EMAIL_AUTH=false
```

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `POSTGRES_HOST` | Central database hostname | `postgres` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_DB` | Database name | `reactive-resume` |
| `POSTGRES_USER` | Database username | `reactive-resume_app` |
| `POSTGRES_PASSWORD` | Database password | *(generated via `setup_secrets.sh`)* |
| `AUTH_SECRET` | Application session encryption secret | *(generated via `setup_secrets.sh`)* |
| `OAUTH_CLIENT_ID` | Authentik OAuth2 Client ID | *(from Authentik provider)* |
| `OAUTH_CLIENT_SECRET` | Authentik OAuth2 Client Secret | *(from Authentik provider)* |

---

## 🚀 Deployment & Operations

1. **Provision PostgreSQL Database**:
   Execute `db-init.sql` against the PostgreSQL container:
   ```bash
   docker exec -i postgres psql -U postgres < compose/reactive-resume/db-init.sql
   ```

2. **Initialize Secrets & Environment**:
   ```bash
   cd compose/reactive-resume
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN, OAUTH_CLIENT_ID, and OAUTH_CLIENT_SECRET
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify Login**:
   Navigate to `https://resume.205hlab.com`. Click **Sign in with Authentik** to initialize your resume library.

---

## 💾 Backup & Data Persistence

- **Resume Content & Sections**: Persisted in PostgreSQL database `reactive-resume`.
- **Uploaded Assets & Profile Photos**: Stored in Docker named volume `app_data` (`/app/data`).
- **Broker State**: Ephemeral cache and rate-limiting counters stored in `valkey_data`.

---

## 🩺 Healthcheck & Monitoring

- **Broker Health**: Evaluated every 10s via `valkey-cli ping`.
- **Application Health**: Probed every 30s via `wget --spider http://127.0.0.1:3000/`.
- **Ingress Telemetry**: Traefik exports response times and status codes to Prometheus.
