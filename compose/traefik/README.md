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
| `MNGT_IP` | Management VLAN interface IP | `10.14.0.x` |
| `ACME_EMAIL` | Let's Encrypt registration email | `admin@205hlab.com` |
| `CF_DNS_API_TOKEN` | Cloudflare API token (`Zone:DNS:Edit`) | *(secret Cloudflare token)* |
| `DYNAMIC_PATH` | Host path for dynamic file configs | `/srv/traefik/dynamic` |
| `TRAEFIK_TRUSTED_IPS`| Cloudflare CIDRs + LAN subnets | `173.245.48.0/20,10.0.0.0/8...` |
| `TRAEFIK_API_INSECURE`| Enable insecure dashboard (leave false) | `false` |

---

## 🚀 Deployment & Operations

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

## 🩺 Healthcheck & Monitoring

- **Ping Healthcheck:** Evaluated every 30s via `wget --spider -q http://127.0.0.1:8082/ping`.
- **Prometheus Telemetry:** Live request throughput, HTTP response codes (2xx, 4xx, 5xx), and backend response latencies are exported on `:9090` and graphed in the [Traefik Grafana Dashboard](../../grafana-dashboards/core/traefik.json).
