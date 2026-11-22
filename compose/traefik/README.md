# Traefik v3 — Edge Reverse Proxy & Automated TLS Ingress

[![Traefik](https://img.shields.io/badge/Traefik-v3.7.18-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)
[![TLS](https://img.shields.io/badge/TLS-Let's%20Encrypt%20(DNS--01)-success?style=for-the-badge&logo=letsencrypt&logoColor=white)](https://letsencrypt.org/)
[![Cloudflare](https://img.shields.io/badge/DNS-Cloudflare%20API-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)](https://www.cloudflare.com/)
[![Observability](https://img.shields.io/badge/Metrics-Prometheus%20Export-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)

> **Public Ingress Ports:** `80:80` (HTTP → HTTPS Redirect), `443:443` (HTTPS)  
> **Management Dashboard:** `${MNGT_IP}:8080` *(Management VLAN only)*  
> **Metrics Port:** `:9090` *(Internal monitoring_network)*  
> **Health Probe:** `:8082` (`/ping`)  
> **Category:** Core Ingress & Edge Security

Traefik v3 is the primary edge reverse proxy for the entire `205hlab` infrastructure. It handles all inbound HTTP/HTTPS traffic, terminates TLS with automated Let's Encrypt wildcard certificates via Cloudflare DNS-01 ACME challenges, chains security and ForwardAuth middlewares, routes internal and public subdomains dynamically from Docker labels, and exports live traffic telemetry into Prometheus and Grafana.

---

## 🏗️ Architecture & Ingress Flow

```
[ Client Traffic (WAN / LAN) ]
              │
              ▼
    [ Traefik Proxy (:80 / :443) ]
    • Global HTTP -> HTTPS Redirection
    • Cloudflare DNS-01 Automated TLS (acme.json)
    • Trusted Proxy CIDRs: ${TRAEFIK_TRUSTED_IPS}
    • Docker Socket Mount: /var/run/docker.sock:ro
              │
     ┌────────┴──────────────────────────┐
     │ 1. ForwardAuth Middleware Check   │ 2. Direct HTTPS Route
     ▼                                   ▼
[ Authentik SSO (:9000) ]       [ Native OIDC & Direct Apps ]
(Validates Session / Injects    (Jellyfin, Technitium, etc.)
 X-authentik-* Headers)
     │
     ▼
[ Upstream Backend Stacks ]
(Sonarr, Mealie, Paperless, Web Tools, etc.)
```

- **Zero Direct Exposure:** Docker services are hidden by default (`--providers.docker.exposedByDefault=false`). Containers must explicitly declare `traefik.enable=true` to receive traffic.
- **Dynamic Configuration:** Supports file-based dynamic routing from `${DYNAMIC_PATH}` (`/etc/traefik/dynamic`) with hot-reloading (`--providers.file.watch=true`).
- **Security Hardening:** Launched with `security_opt: no-new-privileges:true` and read-only Docker socket binding (`/var/run/docker.sock:ro`).

---

## 🔐 TLS Automation via Cloudflare DNS-01 ACME

All SSL/TLS certificates are acquired and renewed automatically using Cloudflare DNS-01 challenges. **No inbound port 80 validation is required**, meaning the server never needs to open unauthenticated HTTP verification endpoints to the public internet:

```yaml
command:
  - "--certificatesresolvers.cloudflare.acme.email=${ACME_EMAIL}"
  - "--certificatesresolvers.cloudflare.acme.caServer=https://acme-v02.api.letsencrypt.org/directory"
  - "--certificatesresolvers.cloudflare.acme.storage=/var/traefik/certs/acme.json"
  - "--certificatesresolvers.cloudflare.acme.dnsChallenge.provider=cloudflare"
  - "--certificatesresolvers.cloudflare.acme.dnsChallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
```

### Trusted Proxy Headers
Traefik trusts forwarded headers strictly from verified Cloudflare IP blocks and private homelab subnets (`${TRAEFIK_TRUSTED_IPS}`). Real client IP addresses are preserved and passed down to Authentik, logging daemons, and fail2ban filters.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `TZ` | Container timezone | `UTC` |
| `MNGT_IP` | Management VLAN interface IP | `MNGT_VLAN` |
| `ACME_EMAIL` | Let's Encrypt registration email | `admin@205hlab.com` |
| `CF_DNS_API_TOKEN` | Cloudflare API token (`Zone:DNS:Edit`) | *(secret Cloudflare token)* |
| `DYNAMIC_PATH` | Host path for dynamic file configs | `/srv/traefik/dynamic` |
| `TRAEFIK_TRUSTED_IPS`| Cloudflare CIDRs + LAN subnets | `173.245.48.0/20,10.0.0.0/8...` |
| `TRAEFIK_API_INSECURE`| Enable insecure dashboard (leave false) | `false` |

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/traefik
   cp example.env .env
   nano .env # Set ACME_EMAIL, CF_DNS_API_TOKEN, MNGT_IP, and TRAEFIK_TRUSTED_IPS
   ```

2. **Verify Network Exists**:
   ```bash
   docker network create traefik_network
   docker network create monitoring_network
   ```

3. **Start Traefik**:
   ```bash
   docker compose up -d
   ```

4. **Verify TLS Generation**:
   Inspect container logs to confirm ACME certificate acquisition:
   ```bash
   docker logs -f traefik
   ```

---

## 💾 Backup & Data Persistence

- **Certificate Storage:** SSL certificates and private keys are saved in named volume `traefik_certs` (`/var/traefik/certs/acme.json`).
- **Permissions:** `acme.json` strictly enforces file permissions `600`.

---

## 📊 Server-Side Analytics Middleware (`traefik-umami-feeder`)

Traefik loads [`github.com/astappiev/traefik-umami-feeder`](https://github.com/astappiev/traefik-umami-feeder) (`v1.5.0`) via static `--experimental.plugins.umami-feeder.*` flags in [`compose.yaml`](compose.yaml) so non-portfolio services can stream server-side pageviews to the internal Umami collector (`http://umami:3000`) without altering upstream HTML or CSP policies. See [`../umami/README.md`](../umami/README.md) for the full hybrid telemetry topology.

1. **Provision the Host Dynamic File First:**  
   Copy [`dynamic/umami.example.yml`](dynamic/umami.example.yml) to `${DYNAMIC_PATH}/umami.yml` on the Ubuntu Server and populate the `websites:` hostname-to-UUID map after creating each site in Umami.
   > [!IMPORTANT]
   > Ensure `${DYNAMIC_PATH}/umami.yml` exists on the host **before** attaching `umami-feeder@file` to any router label; otherwise Traefik marks that router invalid until the file middleware is defined.
2. **Middleware Chaining Rules:**
   - **Public apps (non-portfolio):** `traefik.http.routers.<service>_https.middlewares=umami-feeder@file` (e.g., `status.205hlab.com`).
   - **Authentik-protected apps:** Chain Authentik **first** (`authentik@docker,umami-feeder@file`) so unauthenticated probes bounced by SSO are never recorded.
   - **Exclusions (never attach):** Do not attach `umami-feeder@file` to `me.205hlab.com` (uses client-side `pulse.js` — avoids double-counting), `analytics.205hlab.com`, `umami.internal.205hlab.com`, or `authentik.205hlab.com`.

---

## 🩺 Healthcheck & Monitoring

- **Ping Healthcheck:** Evaluated every 30s via `wget --spider -q http://127.0.0.1:8082/ping`.
- **Prometheus Telemetry:** Live request throughput, HTTP response codes (2xx, 4xx, 5xx), and backend response latencies are exported on `:9090` and graphed in the [Traefik Grafana Dashboard](../../grafana-dashboards/core/traefik.json).
