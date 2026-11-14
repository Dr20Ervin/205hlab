# Downloaderr — VPN Tunnel, BitTorrent & Media Acquisition Subsystem

[![Gluetun](https://img.shields.io/badge/VPN-Gluetun%20WireGuard-008080?style=for-the-badge&logo=wireguard&logoColor=white)](https://github.com/qdm12/gluetun)
[![qBittorrent](https://img.shields.io/badge/BitTorrent-qBittorrent-2F6792?style=for-the-badge&logo=qbittorrent&logoColor=white)](https://www.qbittorrent.org/)
[![qui](https://img.shields.io/badge/WebUI-qui-FF6B6B?style=for-the-badge)](https://github.com/autobrr/qui)
[![MeTube](https://img.shields.io/badge/YouTube-MeTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://github.com/alexta69/metube)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC%20%2B%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Ingress URLs:**  
> - **qui (qBittorrent WebUI):** `https://qui.205hlab.com`  
> - **MeTube Downloader:** `https://metube.205hlab.com`  
> - **Native qBittorrent WebUI:** `https://qbittorrent.205hlab.com`  
> **Category:** Network & Download Automation

This stack manages encrypted network egress, torrent client execution, and YouTube video downloading. **Gluetun** establishes a dedicated WireGuard VPN tunnel (AirVPN) with automated port forwarding and a hardware kill-switch. **qBittorrent** and **MeTube** share Gluetun's network namespace (`network_mode: service:gluetun`), ensuring zero packet leaks outside the VPN tunnel. **qui** provides a modern, responsive web UI for qBittorrent backed by PostgreSQL 18 and native Authentik OIDC authentication.

---

## 🏗️ Architecture & Network Namespace Sharing

```
                        [ Traefik Reverse Proxy ]
                                   │
       ┌───────────────────────────┼───────────────────────────┐
       │ OIDC SSO                  │ ForwardAuth               │ ForwardAuth
       ▼                           ▼                           ▼
  [ qui WebUI (:7476) ]    [ MeTube (:8081) ]         [ qBittorrent (:8080) ]
       │                           │                           │
       │ API Connection            └─────────────┬─────────────┘
       ▼                                         │
[ PostgreSQL 18 (qui DB) ]                       ▼
                             ┌────────────────────────────────────────┐
                             │       Gluetun WireGuard Container      │
                             │  • AirVPN Tunnel (Kill-Switch)         │
                             │  • Input Port: ${TORRENTING_PORT}      │
                             │  • /dev/net/tun (NET_ADMIN)            │
                             └───────────────────┬────────────────────┘
                                                 │ WireGuard Egress
                                                 ▼
                                     [ Public Internet / Swarm ]
```

- **Zero-Leak Design:** Both `qbittorrent` and `metube` bind directly to Gluetun via `network_mode: service:gluetun`. If the WireGuard connection drops, Gluetun's built-in firewall immediately blocks all outbound packets.
- **Port Forwarding:** Gluetun forwards incoming peer connections on `${TORRENTING_PORT}` directly into qBittorrent, maximizing swarm connectivity and upload ratios.
- **Database Backend:** `qui` stores torrent session state, tags, and client connections in a dedicated `qui` database on PostgreSQL 18.

---

## 🔐 Authentik Integration

This stack implements both **Method 1 (Native OIDC)** and **Method 2 (Traefik ForwardAuth)**:

### 1. qui — Native OpenID Connect (Method 1)
qui natively delegates authentication to Authentik with PKCE support:
1. In Authentik, create an **OAuth2/OpenID Connect Provider**:
   - **Name:** `qui Provider`
   - **Client Type:** `Confidential`
   - **Redirect URI (Strict):** `https://qui.205hlab.com/api/auth/oidc/callback`
   - **Selected Scopes:** `openid`, `profile`, `email`.
2. Create application `Qui` (slug: `qui`) and bind group `qui_users`.
3. In `compose.yaml`, qui is pre-configured with:
   ```yaml
   environment:
     - QUI__OIDC_ENABLED=true
     - QUI__OIDC_ISSUER=https://authentik.205hlab.com/application/o/qui/
     - QUI__OIDC_CLIENT_ID=${QUI_OIDC_CLIENT_ID}
     - QUI__OIDC_CLIENT_SECRET=${QUI_OIDC_CLIENT_SECRET}
     - QUI__OIDC_REDIRECT_URL=https://qui.205hlab.com/api/auth/oidc/callback
     - QUI__OIDC_DISABLE_BUILT_IN_LOGIN=true
   ```

### 2. MeTube & Native qBittorrent — Traefik ForwardAuth (Method 2)
Both `metube.205hlab.com` and `qbittorrent.205hlab.com` are gated at Traefik with the `authentik@docker` middleware.
- **Allowed Groups:** `metube_users` and `qui_users`.
- Unauthenticated requests are intercepted at the proxy before reaching the containers.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root media permission ownership | `1000` / `1000` |
| `DOWNLOADS_DIR` | Host path for active & completed torrents | `/srv/downloads` |
| `METUBE_DOWNLOADS_DIR`| Host path for YouTube video downloads | `/srv/downloads/youtube` |
| `AIRVPN_WIREGUARD_PRIVATE_KEY` | AirVPN WireGuard private key | *(from AirVPN config generator)* |
| `AIRVPN_WIREGUARD_PRESHARED_KEY` | AirVPN preshared key | *(from AirVPN config generator)* |
| `AIRVPN_WIREGUARD_ADDRESSES` | Assigned WireGuard client IP | *(e.g. `10.x.x.x/32`)* |
| `AIRVPN_SERVER_COUNTRIES` | Preferred VPN exit country | `Romania` |
| `TORRENTING_PORT` | AirVPN forwarded port for peer listening | *(from AirVPN port management)* |
| `QUI_DATABASE_PASSWORD`| PostgreSQL password for `qui_app` | *(generated via `setup_secrets.sh`)* |
| `QUI_SESSION_SECRET` | Session cookie encryption key | *(generated via `setup_secrets.sh`)* |
| `QUI_OIDC_CLIENT_ID` | Authentik OAuth2 Client ID | *(from Authentik provider)* |
| `QUI_OIDC_CLIENT_SECRET` | Authentik OAuth2 Client Secret | *(from Authentik provider)* |

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Provision PostgreSQL Database**:
   Execute `db-init.sql` against the central PostgreSQL instance:
   ```bash
   docker exec -i postgres psql -U postgres < compose/downloaderr/db-init.sql
   ```

2. **Generate Secrets & Configure VPN**:
   ```bash
   cd compose/downloaderr
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Paste AirVPN WireGuard keys, assigned port, and Authentik credentials
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify VPN Egress & Kill-Switch**:
   Verify that outbound traffic is masked by your VPN provider:
   ```bash
   docker exec -it gluetun curl https://ipinfo.io
   ```

---

## 💾 Backup & Data Persistence

- **qBittorrent Fastresume & State**: Stored in named volume `qbittorrent_config`.
- **qui Client & Tag State**: Stored in PostgreSQL database `qui` and named volume `qui_config`.
- **Downloaded Media Files**: Reside on the host at `${DOWNLOADS_DIR}`. The Servarr suite imports files into final library locations via hardlinks, avoiding duplicate disk consumption.

---

## 🩺 Healthcheck & Monitoring

- **VPN Tunnel Health**: Gluetun executes `/gluetun-entrypoint healthcheck` every 10s. If the tunnel disconnects, dependent containers pause traffic.
- **qBittorrent Health**: Checked every 30s via HTTP ping to local WebUI.
- **Prometheus Metrics**: `qui` exports live torrent download speeds, active torrent counts, and ratio metrics at `:9074/metrics`, visualized on the pre-configured [qui Grafana dashboard](../../grafana-dashboards/saas/qui-overview.json).
