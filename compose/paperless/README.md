# Paperless-ngx — Document Archiving & OCR Pipeline

[![Paperless-ngx](https://img.shields.io/badge/Paperless--ngx-latest-00838F?style=for-the-badge&logo=googledocs&logoColor=white)](https://docs.paperless-ngx.com/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Broker](https://img.shields.io/badge/Broker-Valkey%209-CC342D?style=for-the-badge&logo=redis&logoColor=white)](https://valkey.io)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://paperless.205hlab.com`  
> **Upstream Project:** [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx)  
> **Category:** Household SaaS / Document Management

Paperless-ngx is an enterprise-grade document management and archiving system that indexes, tags, and transforms physical paper and digital files into a searchable archive. In this homelab, Paperless-ngx runs a decoupled multi-container pipeline powered by Apache Tika, Gotenberg, Valkey 9, PostgreSQL 18, and native Authentik OpenID Connect (OIDC) authentication with automatic group-to-superuser synchronization.

---

## 🏗️ Architecture & Decoupled Subsystems

```
[ Client Browser ] ──────────► [ Traefik Proxy (:443) ]
                                      │ HTTPS
                                      ▼
                        [ Paperless Server (:8000) ]
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            ▼                         ▼                         ▼
   [ Valkey 9 Broker ]       [ Gotenberg 8.37 ]         [ Apache Tika 3.3.1 ]
    (Async Task Queue)       (Sandboxed PDF Engine)     (Content Extraction)
            │                         │                         │
            └─────────────────────────┼─────────────────────────┘
                                      ▼
                        [ PostgreSQL 18 Database ]
```

- **Core Server (`paperless-server`)**: Runs the Django web application, OCR workers, indexers, and the consuming engine.
- **Message Broker (`paperless-valkey`)**: Valkey 9 (open-source Redis fork) queues asynchronous OCR tasks, document parsing, and full-text indexing.
- **Office & PDF Rendering Engine (`paperless-gotenberg`)**: Gotenberg 8.37 converts DOCX, XLSX, PPTX, and HTML into standardized PDF/A documents with strict security options (`--chromium-disable-javascript=true`).
- **Metadata & Text Extraction (`paperless-tika`)**: Apache Tika 3.3.1 parses text and metadata from arbitrary binary formats.
- **Database Engine**: Central PostgreSQL 18 instance with dedicated schema and database `paperless`.

---

## 🔐 Authentik Integration (Method 1: Native OIDC via Django Allauth)

Paperless-ngx integrates natively with Authentik through `allauth.socialaccount.providers.openid_connect` with PKCE security and automatic group mapping.

### 1. Authentik Provider Setup
1. In the Authentik Admin Interface, navigate to **Applications** > **Providers** > **Create**.
2. Select **OAuth2/OpenID Connect Provider**:
   - **Name:** `Paperless Provider`
   - **Client Type:** `Confidential`
   - **Redirect URI (Strict):** `https://paperless.205hlab.com/accounts/oidc/authentik/login/callback/`
   - **Logout URI:** `https://paperless.205hlab.com/accounts/logout/`
   - **Signing Key:** Select your default certificate/signing key.
   - **Selected Scopes:** `openid`, `profile`, `email`.
3. Click **Submit** and note the **Client ID** and **Client Secret**.

### 2. Authentik Application & Policy
1. Navigate to **Applications** > **Applications** > **Create**:
   - **Name:** `Paperless-ngx`
   - **Slug:** `paperless-ngx`
   - **Provider:** Select `Paperless Provider`.
2. Under **Application** > **Policy / Group Bindings**, bind the groups:
   - `paperless_admins` → Synchronized as Superusers in Paperless.
   - `paperless_users` → Standard household archive access.

### 3. Container Configuration
These environment variables are pre-configured in `compose.yaml`:
```yaml
environment:
  - PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect
  - >-
    PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authentik","name":"authentik","client_id":"${AUTHENTIK_CLIENT_ID}","secret":"${AUTHENTIK_CLIENT_SECRET}","settings":{"server_url":"https://authentik.205hlab.com/application/o/paperless-ngx/.well-known/openid-configuration","fetch_userinfo":true}}],"SCOPE":["openid","profile","email"]}}
  - PAPERLESS_LOGOUT_REDIRECT_URL=https://authentik.205hlab.com/application/o/paperless-ngx/end-session/
  - PAPERLESS_SOCIAL_AUTO_SIGNUP=true
  - PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS=true
  - PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP=paperless_admins
  - PAPERLESS_SOCIAL_ACCOUNT_SYNC_STAFF_GROUP=paperless_staff
```

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `DOCS_PATH` | Host path for documents storage | `/srv/documents` |
| `POSTGRES_HOST` | Database host | `postgres` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_DB` | Database name | `paperless` |
| `POSTGRES_USER` | Database username | `paperless_app` |
| `POSTGRES_PASSWORD` | Database password | *(generated via `setup_secrets.sh`)* |
| `PAPERLESS_SECRET_KEY` | Django cryptographic secret | *(generated via `setup_secrets.sh`)* |
| `AUTHENTIK_CLIENT_ID` | Authentik OAuth2 Client ID | *(from Authentik provider)* |
| `AUTHENTIK_CLIENT_SECRET` | Authentik OAuth2 Client Secret | *(from Authentik provider)* |

---

## 🚀 Deployment & First-Time Setup

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Provision Database & User**:
   Execute `db-init.sql` against PostgreSQL:
   ```sql
   CREATE DATABASE paperless;
   CREATE USER paperless_app WITH ENCRYPTED PASSWORD '...';
   GRANT ALL PRIVILEGES ON DATABASE paperless TO paperless_app;
   ```

2. **Initialize Secrets & Environment**:
   ```bash
   cd compose/paperless
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN, DOCS_PATH, AUTHENTIK_CLIENT_ID, and AUTHENTIK_CLIENT_SECRET
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify Single Sign-On**:
   Navigate to `https://paperless.205hlab.com`. Click the **authentik** button to authenticate. Members of `paperless_admins` will automatically be elevated to Superuser status with full administrative rights over the document catalog.

---

## 💾 Backup & Data Persistence

- **Document Archive**: Bound from host `${DOCS_PATH}/media` (original and archive PDFs) and `${DOCS_PATH}/export`.
- **Database Metadata**: Tags, correspondents, document types, and OCR text reside in PostgreSQL (`paperless` database).
- **Consuming Ingest Directory**: Bound to named volume `paperless_consume` (or network share) for dropping scanned invoices.
- **Application State**: Stored in `paperless_data` and Valkey queue volume `redis_data`.

---

## 🩺 Healthcheck & Monitoring

- **Web Server Health**: Probed every 30s via `curl -fs -S --max-time 2 http://localhost:8000/`.
- **Gotenberg Health**: Evaluated every 30s via `curl -fs -S --max-time 2 http://localhost:3000/health`.
- **Broker Health**: Valkey responds to `valkey-cli ping` every 10s.
