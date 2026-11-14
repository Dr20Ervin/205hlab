# Servarr Suite — Media Automation & Quality Profile Management

[![Sonarr](https://img.shields.io/badge/Sonarr-v4-00CCFF?style=for-the-badge&logo=sonarr&logoColor=white)](https://sonarr.tv/)
[![Radarr](https://img.shields.io/badge/Radarr-v5-FFC230?style=for-the-badge&logo=radarr&logoColor=white)](https://radarr.video/)
[![Lidarr](https://img.shields.io/badge/Lidarr-v2-159957?style=for-the-badge&logo=lidarr&logoColor=white)](https://lidarr.audio/)
[![Chaptarr](https://img.shields.io/badge/Chaptarr-latest-8E44AD?style=for-the-badge)](https://github.com/chaptarr/chaptarr)
[![Prowlarr](https://img.shields.io/badge/Prowlarr-v1-FF5500?style=for-the-badge&logo=prowlarr&logoColor=white)](https://prowlarr.com/)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth%20%2B%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Stack Scope:** Complete automated pipeline for television series, films, music, audiobooks, subtitles, indexer management, and custom quality profiles.

This compose stack houses the core automation engines that manage media acquisition, release parsing, quality profile matching, metadata enrichment, and filesystem organization across the homelab's OpenZFS storage pools.

---

## 🏗️ Architecture & Component Topology

```
                         [ Ingress Traffic (Traefik Proxy) ]
                                          │
            ┌─────────────────────────────┼─────────────────────────────┐
            │ Authentik ForwardAuth       │ Authentik ForwardAuth       │ Authentik OIDC
            ▼                             ▼                             ▼
   [ Sonarr / Radarr / Lidarr ]       [ Prowlarr Indexer ]        [ Profilarr (+ Parser) ]
            │                             │                             │
            │ Media Links                 │ Indexer Sync & Flaresolverr │ Profile Sync
            ▼                             ▼                             ▼
   [ Downloaderr Stack (VPN) ] ◄─── [ Usenet / Torrents ] ────────► [ Servarr APIs ]
            │
            ▼ (Post-Processing & Hardlinking)
   [ OpenZFS Storage Datasets ] (/movies, /shows, /music, /books)
            │
            ▼ (Direct /dev/dri Transcoding)
   [ Jellyfin & Kavita Streaming Engines ]
```

### Services Deployed:
1. **`sonarr`** (`https://sonarr.205hlab.com`): Automated TV series acquisition, season monitoring, and upgrade engine.
2. **`radarr`** (`https://radarr.205hlab.com`): Movie collection management, dynamic resolution scoring, and file renaming.
3. **`lidarr`** (`https://lidarr.205hlab.com`): Music album and discography manager with MusicBrainz integration.
4. **`chaptarr`** (`https://chaptarr.205hlab.com`): Audiobooks, podcasts, and digital books management.
5. **`bazarr`** (`https://bazarr.205hlab.com`): Automated multi-lingual subtitle synchronizer (OpenSubtitles, Subscene).
6. **`prowlarr`** (`https://prowlarr.205hlab.com`): Unified Torrent/Usenet indexer manager syncing indexers to all \*arr apps.
7. **`flaresolverr`** (`http://flaresolverr:8191`): Internal headless proxy to bypass Cloudflare and DDoS protection on public indexers.
8. **`profilarr`** (`https://profilarr.205hlab.com`): Centralized Trash Guides quality profile synchronizer.
9. **`profilarr-parser`** (`http://profilarr-parser:5000`): Internal high-performance parsing backend for Profilarr.

---

## 🔐 Authentik Integration

This stack implements **Method 2 (Traefik ForwardAuth)** for the \*arr suite and **Method 1 (Native OIDC)** for Profilarr:

### 1. The \*arr Applications (Method 2: Proxy Provider / ForwardAuth)
Because Sonarr, Radarr, Lidarr, Chaptarr, Bazarr, and Prowlarr do not natively support OIDC authorization, they are configured with:
```xml
<!-- In config.xml or container environment -->
<AuthenticationMethod>External</AuthenticationMethod>
```
Each service router attaches the Authentik ForwardAuth middleware in Traefik:
```yaml
labels:
  - "traefik.http.routers.<service>_https.middlewares=authentik@docker"
```
* **Authentik Provider Mode:** Proxy Provider (`Forward auth (single application)`).
* **Allowed Group:** `servarr_users` (or `authentik Admins`).
* **Header Trust:** Traefik strips and reinjects verified identity headers (`X-authentik-username`).

### 2. Profilarr (Method 1: Native OIDC)
Profilarr natively connects to Authentik via OpenID Connect:
* **Redirect URI:** `https://profilarr.205hlab.com/auth/oidc/callback`
* **Scopes:** `openid`, `email`, `profile`.
* **Token Endpoint Auth:** `client_secret_post`.
* **Compose Configuration:**
  ```yaml
  environment:
    - AUTH=oidc
    - OIDC_DISCOVERY_URL=https://authentik.205hlab.com/application/o/profilarr/.well-known/openid-configuration
    - OIDC_CLIENT_ID=${PROFILARR_OIDC_CLIENT_ID}
    - OIDC_CLIENT_SECRET=${PROFILARR_OIDC_CLIENT_SECRET}
    - ORIGIN=https://profilarr.205hlab.com
  ```

---

## 🗄️ Database Architecture (PostgreSQL 18)

Rather than using default embedded SQLite files which can suffer from database locks during concurrent I/O operations, all \*arr applications in this homelab are backed by **PostgreSQL 18**:

| Service | Host | User | Main Database | Log Database | Cache Database |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Sonarr** | `postgres` | `sonarr_app` | `sonarr-main` | `sonarr-log` | — |
| **Radarr** | `postgres` | `radarr_app` | `radarr-main` | `radarr-log` | — |
| **Lidarr** | `postgres` | `lidarr_app` | `lidarr-main` | `lidarr-log` | — |
| **Chaptarr** | `postgres` | `chaptarr_app` | `chaptarr-main` | `chaptarr-log` | `chaptarr-cache` |
| **Prowlarr** | `postgres` | `prowlarr_app` | `prowlarr-main` | `prowlarr-log` | — |

Each database and role is initialized cleanly via [`db-init.sql`](db-init.sql).

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root media permission ownership | `1000` / `1000` |
| `MEDIA_DIR` | Host base path for media storage | `/srv/media` (OpenZFS pool) |
| `DOWNLOADS_DIR` | Shared directory for torrent downloads | `/srv/downloads` |
| `POSTGRES_HOST` | Database host | `postgres` |
| `SONARR_DB_PASSWORD` | PostgreSQL password for Sonarr | *(generated via `setup_secrets.sh`)* |
| `RADARR_DB_PASSWORD` | PostgreSQL password for Radarr | *(generated via `setup_secrets.sh`)* |
| `LIDARR_DB_PASSWORD` | PostgreSQL password for Lidarr | *(generated via `setup_secrets.sh`)* |
| `CHAPTARR_DB_PASSWORD`| PostgreSQL password for Chaptarr | *(generated via `setup_secrets.sh`)* |
| `PROWLARR_DB_PASSWORD`| PostgreSQL password for Prowlarr | *(generated via `setup_secrets.sh`)* |
| `PROFILARR_OIDC_CLIENT_ID` | Authentik OIDC Client ID | *(from Authentik provider)* |
| `PROFILARR_OIDC_CLIENT_SECRET` | Authentik OIDC Client Secret | *(from Authentik provider)* |

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Provision Databases**:
   Ensure all isolated PostgreSQL databases exist by executing `db-init.sql`:
   ```bash
   docker exec -i postgres psql -U postgres < compose/servarr/db-init.sql
   ```

2. **Generate Passwords & Configure Environment**:
   ```bash
   cd compose/servarr
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN, MEDIA_DIR, DOWNLOADS_DIR, and Profilarr OIDC credentials
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify Connectivity**:
   - Access each service at `https://<service>.205hlab.com`.
   - In Prowlarr, configure Flaresolverr at `http://flaresolverr:8191`.
   - In Prowlarr, link your applications under **Settings** > **Apps** using internal Docker hostnames (`http://sonarr:8989`, `http://radarr:7878`, etc.).

---

## 💾 Backup & Data Persistence

- **State & Profiles**: Stored in persistent Docker named volumes (`sonarr_data`, `radarr_data`, `lidarr_data`, `chaptarr_data`, `bazarr_data`, `prowlarr_data`, `profilarr_config`).
- **Relational Databases**: Backed up via standard `pg_dump` schedules from the central PostgreSQL container.
- **Media Datasets**: Stored on the host's mirrored OpenZFS pool. The \*arr containers use hardlinks where possible to avoid file duplication between downloads and library targets.

---

## 🩺 Healthcheck & Monitoring

- **Container Health**: Every service implements strict Docker health probes checking local HTTP ping endpoints (e.g. `curl -f http://localhost:8989/ping`).
- **Traffic Telemetry**: Traefik exports request rates and response status codes for each \*arr router into Prometheus.
