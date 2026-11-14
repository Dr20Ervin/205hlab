# ChangeDetection.io — Automated Web Page Change Monitoring

[![ChangeDetection](https://img.shields.io/badge/ChangeDetection.io-latest-4A90E2?style=for-the-badge&logo=googlechrome&logoColor=white)](https://changedetection.io/)
[![Playwright](https://img.shields.io/badge/Browser-Playwright%20Stealth-2EAD33?style=for-the-badge&logo=playwright&logoColor=white)](https://playwright.dev/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://changedetection.internal.205hlab.com` *(Internal LAN Only)*  
> **Upstream Project:** [dgtlmoon/changedetection.io](https://github.com/dgtlmoon/changedetection.io)  
> **Category:** Monitoring & Alerts

ChangeDetection.io provides automated website change monitoring, notification dispatch, and visual diff tracking. It periodically monitors target URLs for content alterations, price drops, software release updates, or legal terms revisions. It pairs with a headless, stealth-enabled Playwright Chromium browser to accurately render complex single-page JavaScript web applications and bypass basic anti-bot challenge scripts.

---

## 🏗️ Architecture & Decoupled Browser Scraping

```
[ Client Browser (Internal LAN) ]
               │ HTTPS (ACME TLS)
               ▼
[ Traefik Proxy (:443) ]
               │ ForwardAuth Gate (Authentik)
               ▼
[ ChangeDetection Server (:5000) ]
               │
               │ WebSocket / Stealth Driver (changedetection_network)
               ▼
[ Playwright Chrome Headless (:3000) ]
  • SockPuppetBrowser (Stealth = 1)
  • Resolution: 1920x1024x16
  • Max 3 Concurrent Chrome Processes
```

- **Headless Browser Decoupling:** Heavy browser rendering is offloaded to a dedicated `playwright-chrome` container (`dgtlmoon/sockpuppetbrowser:latest`) connected via WebSockets over the internal `changedetection_network`.
- **Resource Constraints:**
  - `changedetection`: Governed with `limits: cpus: '0.5'`, `memory: 1G`.
  - `playwright-chrome`: Governed with `limits: cpus: '1.0'`, `memory: 1G`.
- **Stealth Capabilities:** Launched with `cap_add: SYS_ADMIN` to manage Chromium sandbox lifecycles and `stealth=1` flag to prevent automated headless browser fingerprinting.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

ChangeDetection operates on the internal split-horizon domain (`changedetection.internal.205hlab.com`) and is protected by Authentik ForwardAuth:

```yaml
labels:
  - "traefik.http.routers.changedetection_https.middlewares=cd-headers,authentik@docker"
```

* **Access Control:** Bound to group `changedetection_admins` or `authentik Admins`.
* **Header Normalization:** Middleware `cd-headers` guarantees `X-Forwarded-Proto=https` is properly enforced behind the reverse proxy.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root file permissions | `1000` / `1000` |
| `MAX_CONCURRENT_CHROME_PROCESSES` | Max parallel headless tabs | `3` |

---

## 🚀 Deployment & Operations

1. **Initialize Environment**:
   ```bash
   cd compose/changedetection
   cp example.env .env
   nano .env # Set FQDN
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Verify Watch Setup**:
   Navigate to `https://changedetection.internal.205hlab.com`. Add a test URL and select **Request Method: Playwright Chromium** in the watch settings to confirm headless browser screenshot rendering.

---

## 💾 Backup & Data Persistence

- **Watch Lists & Diff History**: All monitored targets, snapshot history, visual diffs, and notification configurations are persisted in Docker named volume `changedetection_config` (`/config`).

---

## 🩺 Healthcheck & Monitoring

- **Application Health**: Queried every 30s via `curl -f http://localhost:5000/`.
- **Browser Health**: Playwright health evaluated every 30s via `curl -fsS http://localhost:3000/`.
