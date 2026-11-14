# Grafana — Metrics Visualization & Observability Platform

[![Grafana](https://img.shields.io/badge/Grafana-13.0.1-F46800?style=for-the-badge&logo=grafana&logoColor=white)](https://grafana.com)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Telemetry](https://img.shields.io/badge/Metrics-Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://grafana.205hlab.com`  
> **Upstream Project:** [grafana/grafana](https://github.com/grafana/grafana)  
> **Category:** Observability & Telemetry

Grafana is the operational dashboard and visualization platform for the `205hlab` production homelab. It aggregates metrics from Prometheus, host node exporters, container cAdvisor runtimes, PostgreSQL internals, Technitium DNS query statistics, OpenZFS pool storage, OpenWrt router throughput, and APC UPS power telemetry. It features automated single sign-on (SSO) with fine-grained Role-Based Access Control (RBAC) powered by Authentik application entitlements.

---

## 🏗️ Architecture & Dependencies

```
[ Client Browser ]
        │ HTTPS (Cloudflare ACME TLS)
        ▼
[ Traefik Proxy (:443) ]
        │ Internal Docker Bridge (traefik_network)
        ▼
[ Grafana Container (:3000) ]
   ├── Generic OAuth / OIDC ──► Authentik Server (https://authentik.205hlab.com)
   ├── Metrics Data Source ──► Prometheus (:9090 on monitoring_network)
   └── Persistent Storage ──► Named Volume: grafana-data (/var/lib/grafana)
```

- **Networks:**
  - `traefik_network` (external bridge): Receives routed HTTPS traffic from Traefik.
  - `monitoring_network` (external bridge): Direct communication with the Prometheus TSDB and internal exporters.
- **Resource Constraints:** Governed with `limits: cpus: '1.0'`, `memory: 2G`.
- **Storage:** Named volume `grafana_data` mapped to `/var/lib/grafana` for SQLite configuration state, users, and installed plugins.
- **Dashboard Backups & Version Control:** Version-controlled JSON dashboard exports organized by folder (`205hlab - Core`, `205hlab - Hardware`, `205hlab - SaaS`) are maintained in the repository root at [`grafana-dashboards/`](../../grafana-dashboards/).

---

## 🔐 Authentik Integration (Method 1: Native OAuth2/OIDC)

Grafana integrates natively via Generic OAuth with Authentik using application entitlements to dynamically determine user roles (`Admin`, `Editor`, or `Viewer`).

### 1. Authentik Provider Setup
1. In the Authentik Admin Interface, navigate to **Applications** > **Providers** > **Create**.
2. Select **OAuth2/OpenID Connect Provider**:
   - **Name:** `Grafana Provider`
   - **Client Type:** `Confidential`
   - **Redirect URIs (Strict):** `https://grafana.205hlab.com/login/generic_oauth`
   - **Logout URI:** `https://grafana.205hlab.com/logout` (Front-channel logout)
   - **Signing Key:** Select your default certificate/signing key.
   - **Selected Scopes:**
     - `openid`
     - `profile`
     - `email`
     - `authentik default OAuth Mapping: Application Entitlements`
3. Click **Submit** and note the **Client ID** and **Client Secret**.

### 2. Authentik Application & Entitlements
1. Navigate to **Applications** > **Applications** > **Create**:
   - **Name:** `Grafana`
   - **Slug:** `grafana`
   - **Provider:** Select `Grafana Provider`.
2. Open the `Grafana` application and click the **Application entitlements** tab. Create three entitlements:
   - `Grafana Admins` → Bind to group `grafana_admins`
   - `Grafana Editors` → Bind to group `grafana_editors`
   - `Grafana Viewers` → Bind to group `grafana_viewers`

### 3. Container RBAC & OAuth Settings
These environment variables are pre-configured in `compose.yaml`:
```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=authentik
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${GRAFANA_OAUTH_CLIENT_ID}
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email entitlements
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://authentik.205hlab.com/application/o/authorize/
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://authentik-server:9000/application/o/token/
  - GF_AUTH_GENERIC_OAUTH_API_URL=http://authentik-server:9000/application/o/userinfo/
  - GF_AUTH_SIGNOUT_REDIRECT_URL=https://authentik.205hlab.com/application/o/grafana/end-session/
  - GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(entitlements[*], 'Grafana Admins') && 'Admin' || contains(entitlements[*], 'Grafana Editors') && 'Editor' || 'Viewer'
  - GF_AUTH_OAUTH_AUTO_LOGIN=true
  - GF_SERVER_ROOT_URL=https://grafana.205hlab.com
```

> **RBAC Logic:** When a user logs in, Grafana evaluates the `entitlements` claim:
> - If the user has `Grafana Admins` → assigned **Admin** role.
> - If the user has `Grafana Editors` → assigned **Editor** role.
> - Otherwise → defaults safely to read-only **Viewer** role.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `GRAFANA_OAUTH_ENABLED` | Enable generic OAuth SSO | `true` |
| `GRAFANA_OAUTH_AUTO_LOGIN` | Bypass default login prompt | `true` |
| `GRAFANA_OAUTH_CLIENT_ID` | Authentik OAuth2 Client ID | *(from Authentik provider)* |
| `GRAFANA_OAUTH_CLIENT_SECRET` | Authentik OAuth2 Client Secret | *(from Authentik provider)* |

---

## 🚀 Deployment & First-Time Setup

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/grafana
   cp example.env .env
   nano .env # Set FQDN, GRAFANA_OAUTH_CLIENT_ID, and GRAFANA_OAUTH_CLIENT_SECRET
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Verify SSO & Permissions**:
   Navigate to `https://grafana.205hlab.com`. Since `GF_AUTH_OAUTH_AUTO_LOGIN=true` is enabled, you are immediately routed through Authentik.
   - Users belonging to `grafana_admins` will have full Server Administration rights.
   - Users belonging to `grafana_editors` can build and edit dashboards.
   - All other authenticated users can browse and view dashboards without write privileges.

---

## 💾 Backup & Data Persistence

- **State Storage**: User preferences, local dashboards, and alerting rules reside in the `grafana_data` named volume (`/var/lib/grafana/grafana.db`).
- **Dashboard Synchronization**: Custom dashboards should be exported as JSON and committed to [`grafana-dashboards/`](../../grafana-dashboards/) for version-controlled disaster recovery.

---

## 🩺 Healthcheck & Monitoring

- **Container Health**: Evaluated every 30s via `wget --spider http://localhost:3000/api/health`.
- **Prometheus Metrics**: Grafana internally exports runtime metrics at `:3000/metrics`.
