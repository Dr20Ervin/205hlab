# Kavita — Digital Book, Comic & Manga Reading Server

[![Kavita](https://img.shields.io/badge/Kavita-latest-5C6BC0?style=for-the-badge&logo=bookmeter&logoColor=white)](https://www.kavitareader.com/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Storage](https://img.shields.io/badge/Storage-OpenZFS%20Pool-005C8A?style=for-the-badge)](https://openzfs.github.io/openzfs-docs/)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://kavita.205hlab.com`  
> **Upstream Project:** [Kareadita/Kavita](https://github.com/Kareadita/Kavita)  
> **Category:** Media & Reading

Kavita is a fast, responsive self-hosted digital library and reader designed for manga, comics, books (EPUB/PDF), and magazines. It provides a browser-based reading experience, OPDS feed support for external e-readers (such as Tachiyomi, Mihon, and Moon+ Reader), progress tracking, and collection management. In this homelab, Kavita serves curated media directly from read-only OpenZFS datasets and integrates natively with Authentik OpenID Connect (OIDC).

---

## 🏗️ Architecture & Dependencies

```
[ Client Browser / Tachiyomi / OPDS Reader ]
        │ HTTPS (Cloudflare ACME TLS)
        ▼
[ Traefik Proxy (:443) ]
        │ Internal Docker Bridge (traefik_network)
        ▼
[ Kavita Server (:5000) ]
   ├── OIDC Authority ──► Authentik Server (https://authentik.205hlab.com)
   ├── Configuration State ──► Named Volume: kavita_config (/config)
   └── Media Libraries (Read-Only)
        ├── eBooks ──► ${MEDIA_DIR}/books/ebooks (/data/ebooks:ro)
        ├── Comics ──► ${MEDIA_DIR}/books/comics (/data/comics:ro)
        └── Manga  ──► ${MEDIA_DIR}/books/manga  (/data/manga:ro)
```

- **Networks:**
  - `traefik_network` (external bridge): Receives incoming HTTPS traffic from Traefik.
- **Resource Constraints:** Governed with `limits: cpus: '1.5'`, `memory: 1.5G`.
- **Media Ingestion:** Mounts read-only (`:ro`) directories from the host's mirrored OpenZFS pool. Automated acquisition is handled upstream by Chaptarr.

---

## 🔐 Authentik Integration (Method 1: Native OIDC)

Kavita supports OpenID Connect out of the box through its internal authentication settings.

### 1. Authentik Provider Setup
1. In the Authentik Admin Interface, navigate to **Applications** > **Providers** > **Create**.
2. Select **OAuth2/OpenID Connect Provider**:
   - **Name:** `Kavita Provider`
   - **Client Type:** `Confidential`
   - **Redirect URIs (Strict):**
     - Authorization: `https://kavita.205hlab.com/signin-oidc`
     - Post Logout: `https://kavita.205hlab.com/signout-callback-oidc`
   - **Logout URI:** `https://kavita.205hlab.com/signout-oidc` (Front-channel logout)
   - **Signing Key:** Select your default certificate/signing key.
   - **Selected Scopes:** `openid`, `profile`, `email`.
3. Click **Submit** and note the **Client ID**, **Client Secret**, and **slug**.

### 2. Authentik Application & Policy
1. Navigate to **Applications** > **Applications** > **Create**:
   - **Name:** `Kavita`
   - **Slug:** `kavita`
   - **Provider:** Select `Kavita Provider`.
2. Under **Application** > **Policy / Group Bindings**, bind the group `kavita_users` so only authorized users can authenticate.

### 3. Kavita In-App Configuration
Once Kavita is deployed:
1. Log in to Kavita as an administrator.
2. Navigate to **Server Settings** > **Authentication** > **OpenID Connect**.
3. Configure the following parameters:
   - **Authority:** `https://authentik.205hlab.com/application/o/kavita/`
   - **Client Id:** `<Client ID from Authentik>`
   - **Secret:** `<Client Secret from Authentik>`
   - **Provision Accounts:** Enable (automatically creates local accounts upon first OIDC login)
   - **Require Verified Emails:** Disable
4. Save and restart Kavita.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root permissions mapping | `1000` / `1000` |
| `MEDIA_DIR` | Host base path for media storage | `/srv/media` (or ZFS pool mount) |

---

## 🚀 Deployment & First-Time Setup

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/kavita
   cp example.env .env
   nano .env # Set FQDN, PUID, PGID, and MEDIA_DIR
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Complete In-App Onboarding**:
   - Navigate to `https://kavita.205hlab.com`.
   - Complete initial admin registration.
   - Go to **Server Settings** > **OpenID Connect** and paste the Authentik credentials.
   - Go to **Libraries** and add library paths: `/data/ebooks`, `/data/comics`, and `/data/manga`.

---

## 💾 Backup & Data Persistence

- **Metadata & Progress**: Book metadata, bookmarks, reading progress, and local SQLite data are stored in named volume `kavita_config` (`/config`).
- **Media Files**: Actual EPUB, CBZ, CBR, and PDF files reside safely on the host's OpenZFS pool (`${MEDIA_DIR}/books/`).

---

## 🩺 Healthcheck & Monitoring

- **Container Health**: Built-in HTTP health probe querying `http://localhost:5000/api/Health` every 30s.
- **Ingress Telemetry**: Traefik metrics track request counts and response latency on port `:5000`.
