# Jellyfin & Seerr — Media Streaming & Request Management

[![Jellyfin](https://img.shields.io/badge/Jellyfin-latest-00A4DC?style=for-the-badge&logo=jellyfin&logoColor=white)](https://jellyfin.org/)
[![Seerr](https://img.shields.io/badge/Seerr-latest-E5A00D?style=for-the-badge)](https://github.com/seerr-team/seerr)
[![HW Acceleration](https://img.shields.io/badge/Transcode-Intel%20VAAPI%20(/dev/dri)-blue?style=for-the-badge)](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20SSO%20%2B%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Ingress URLs:**  
> - **Jellyfin:** `https://jellyfin.205hlab.com`  
> - **Seerr:** `https://seer.205hlab.com`  
> **Category:** Media Streaming & Discovery

This stack powers personal media streaming and user discovery for the household. **Jellyfin** streams movies, TV shows, and music from the OpenZFS storage pool with hardware-accelerated transcoding via Intel Quick Sync Video / VAAPI (`/dev/dri`). **Seerr** provides an interactive request interface for household members to search, discover, and automatically request media, routing approvals directly to Sonarr and Radarr.

---

## 🏗️ Architecture & Dependencies

```
[ Client Streaming Devices (Smart TV / Mobile / Browser) ]
                           │
             ┌─────────────┴─────────────┐
             │ HTTPS (Traefik)           │ HTTPS (Traefik + ForwardAuth)
             ▼                           ▼
    [ Jellyfin (:8096) ]         [ Seerr (:5055) ]
             │                           │
             │                           │ (servarr_backend network)
             │                           ▼
             │                  [ Sonarr & Radarr ]
             ▼
    [ Intel HD 4000 iGPU ] (/dev/dri VAAPI hardware transcode)
    [ OpenZFS Storage Pool ] (${MEDIA_DIR} /movies, /shows, /music)
```

- **Networks:**
  - `traefik_network` (external bridge): Ingress routing for both Jellyfin and Seerr.
  - `servarr_backend` (external bridge): Allows Seerr to communicate directly with Sonarr, Radarr, and the download stack.
- **Hardware Acceleration:** Direct device passthrough of `/dev/dri` gives the Jellyfin container hardware access to the host's Intel HD Graphics 4000 iGPU for real-time VAAPI transcoding.
- **Resource Constraints:**
  - `jellyfin`: Governed with `limits: cpus: '3.0'`, `memory: 8G`.
  - `seerr`: Governed with `limits: cpus: '1.0'`, `memory: 1G`.
- **LAN Discovery Ports:** Binds ports `${LAN_IP}:8096`, `${LAN_IP}:1900/udp`, and `${LAN_IP}:7359/udp` for DLNA/UPnP and auto-discovery across local Apple TV and Roku devices.

---

## 🔐 Authentik Integration

This stack combines **Method 1 (In-App SSO Plugin)** for streaming clients with **Method 2 (Traefik ForwardAuth)** for the web request UI:

### 1. Jellyfin — In-App SSO Plugin (Method 1)
Because mobile and TV clients (Roku, Android TV, Infuse, Swiftfin) communicate directly with Jellyfin's API, Jellyfin cannot be gated behind an edge proxy forward-auth block without breaking native mobile apps.
Instead:
- Jellyfin exposes its web/API endpoint directly through Traefik with TLS.
- In-app authentication is handled using the **Jellyfin SSO Plugin** (OpenID Connect / LDAP provider) configured against Authentik:
  - **Redirect URI:** `https://jellyfin.205hlab.com/sso/OID/redirect/authentik`
  - **Scopes:** `openid`, `profile`, `email`.
  - **Groups Mapped:**
    - `jellyfin-admins` → Full Jellyfin server administration privileges.
    - `jellyfin-users` → General streaming access.
    - `jellyfin-kids` → Curated library restrictions (G/PG ratings).
    - `jellyfin-users-hun` → Hungarian localized audio/subtitle preference profile.

### 2. Seerr — Traefik ForwardAuth (Method 2)
Seerr is strictly protected at the edge by the Authentik ForwardAuth middleware:
```yaml
labels:
  - "traefik.http.routers.seerr_https.middlewares=authentik@docker"
```
Users must authenticate with an account belonging to `jellyfin-users` or `authentik Admins` to submit media requests.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root media file permissions | `1000` / `1000` |
| `LAN_IP` | Primary host LAN IP (for direct discovery) | `10.10.0.x` |
| `MEDIA_DIR` | Host base path for media storage | `/srv/media` (OpenZFS pool) |
| `JELLYFIN_CONFIG_DIR`| Host path for Jellyfin metadata & database | `/srv/jellyfin/config` |
| `LOG_LEVEL` | Seerr log verbosity | `debug` |

---

## 🚀 Deployment & First-Time Setup

1. **Initialize Environment**:
   ```bash
   cd compose/jelly
   cp example.env .env
   nano .env # Set FQDN, LAN_IP, MEDIA_DIR, and JELLYFIN_CONFIG_DIR
   ```

2. **Verify GPU Device Permissions**:
   Ensure the Docker user belongs to the host's `render` and `video` groups to access `/dev/dri`:
   ```bash
   ls -l /dev/dri
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Post-Installation Setup**:
   - **Jellyfin:** Navigate to `https://jellyfin.205hlab.com`. Follow the setup wizard, configure your `/data/movies`, `/data/shows`, and `/data/music` libraries, and enable **VAAPI** in **Dashboard** > **Playback** > **Transcoding**.
   - **Seerr:** Navigate to `https://seer.205hlab.com` (authenticated via Authentik). Connect Seerr to Jellyfin using internal hostname `http://jellyfin:8096`, then link your Sonarr and Radarr backends over `servarr_backend`.

---

## 💾 Backup & Data Persistence

- **Jellyfin State**: Stored on host at `${JELLYFIN_CONFIG_DIR}` (holds SQLite databases `jellyfin.db`, plugin settings, image cache, and trickplay bif files).
- **Seerr State**: Stored in named volume `seerr_config` (`/app/config`).
- **Media Content**: Bound read-only (`:ro`) directly from the host's OpenZFS datasets. Deletions or transcode errors cannot corrupt source files.

---

## 🩺 Healthcheck & Monitoring

- **Jellyfin Healthcheck**: Queried every 30s via `curl -f http://localhost:8096/health`.
- **Seerr Healthcheck**: Queried every 15s via `wget --spider http://localhost:5055/api/v1/settings/public`.
- **GPU Transcoding Metrics**: Monitored via Prometheus node-exporter GPU telemetry.
