# SearXNG — Privacy-Respecting Metasearch Engine

[![SearXNG](https://img.shields.io/badge/SearXNG-latest-0080FF?style=for-the-badge&logo=search&logoColor=white)](https://searxng.org/)
[![VPN](https://img.shields.io/badge/VPN-Gluetun%20WireGuard%20(CH)-008080?style=for-the-badge&logo=wireguard&logoColor=white)](https://github.com/qdm12/gluetun)
[![Cache](https://img.shields.io/badge/Cache-Valkey%209%20(In--Memory)-CC342D?style=for-the-badge&logo=redis&logoColor=white)](https://valkey.io)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Ingress URL:** `https://search.205hlab.com`  
> **Upstream Project:** [searxng/searxng](https://github.com/searxng/searxng)  
> **Category:** Privacy & Information Retrieval

SearXNG is a free, privacy-respecting metasearch engine that aggregates search results from over 70 search engines (Google, Bing, DuckDuckGo, Brave, Wikipedia, Reddit, GitHub) without tracking user queries or profiling user identities. In this homelab, SearXNG routes all outbound search scraping requests through a dedicated **Gluetun WireGuard tunnel** (AirVPN / Switzerland exit) to prevent residential IP rate-limiting, paired with an in-memory **Valkey 9** broker for response caching and Authentik ForwardAuth protection.

---

## 🏗️ Architecture & VPN Isolation

```
[ Client Browser ]
        │ HTTPS (Cloudflare ACME TLS)
        ▼
[ Traefik Ingress (:443) ]
        │ Authentik ForwardAuth Gate
        ▼
┌────────────────────────────────────────────────────────┐
│             gluetun-search Network Namespace           │
│                                                        │
│  [ Gluetun WireGuard ] (AirVPN / Switzerland Exit)     │
│           ▲                                            │
│           │ Loopback Networking (127.0.0.1)            │
│           ▼                                            │
│  [ SearXNG Core (:8080) ] ◄──► [ Valkey 9 Cache ]      │
│  (Aggregates 70+ engines)      (In-memory, no disk I/O)│
└───────────────────────────┬────────────────────────────┘
                            │ Outbound WireGuard Tunnel
                            ▼
              [ Upstream Search Engines ]
```

- **Shared Network Namespace:** `searxng` and `valkey` operate inside `gluetun-search` via `network_mode: service:gluetun-search`. If the WireGuard VPN drops, the tunnel kill-switch halts scraping, ensuring zero residential IP leakage.
- **Privacy-Optimized Exit:** Outbound queries exit through Switzerland servers, avoiding localized tracking and residential CAPTCHAs.
- **In-Memory Caching:** Valkey runs without persistence (`--save ""` `--appendonly no`) purely as a volatile RAM cache (`128M` limit) to accelerate query deduplication and engine rate-limiting.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

SearXNG is protected at the Traefik edge via Authentik ForwardAuth to prevent public web crawlers, bots, or unauthorized visitors from abusing your VPN bandwidth or search engine quotas:

```yaml
labels:
  - "traefik.http.routers.searxng_https.middlewares=authentik@docker"
```

* **Authentik Provider Mode:** Proxy Provider (`Forward auth (single application)`).
* **Allowed Group:** `searxng_users` or `authentik Admins`.
* **Cookie Isolation:** The session cookie is scoped to `search.205hlab.com`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `AIRVPN_WIREGUARD_PRIVATE_KEY` | AirVPN WireGuard private key | *(from AirVPN config generator)* |
| `AIRVPN_WIREGUARD_PRESHARED_KEY` | AirVPN preshared key | *(optional)* |
| `AIRVPN_WIREGUARD_ADDRESSES` | Assigned WireGuard client IP | *(e.g. `10.x.x.x/32`)* |
| `AIRVPN_SERVER_COUNTRIES` | Preferred VPN exit country | `Switzerland` |
| `SEARXNG_SECRET` | Cryptographic session & token secret | *(generated via `setup_secrets.sh`)* |
| `SEARXNG_CONFIG_DIR` | Host path for custom `settings.yml` | `./core-config` |

---

## 🚀 Deployment & Operations

1. **Initialize Secrets & VPN Settings**:
   ```bash
   cd compose/searxng
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN, AirVPN WireGuard keys, and SEARXNG_SECRET
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Verify VPN Egress**:
   Confirm that SearXNG is routing out through Switzerland:
   ```bash
   docker exec -it gluetun-search curl https://ipinfo.io
   ```

4. **Browser Integration**:
   Navigate to `https://search.205hlab.com`. You can add SearXNG as your browser's default search engine:
   - Search URL: `https://search.205hlab.com/search?q=%s`

---

## 💾 Backup & Data Persistence

- **Zero-Logging Policy:** SearXNG is configured with zero query logging, zero tracking cookies, and zero search history retention.
- **Cache Volatility:** Named volume `valkey-data` is purely volatile.
- **Engine Settings:** Custom search engine preferences are stored in [`core-config/settings.yml`](core-config/settings.yml).

---

## 🩺 Healthcheck & Monitoring

- **VPN Health**: Gluetun tests tunnel connectivity every 15s.
- **Valkey Health**: Probed every 5s via `valkey-cli ping`.
- **SearXNG Health**: Probed every 30s via `wget --spider http://127.0.0.1:8080/`.
