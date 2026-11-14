# Technitium DNS — Authoritative, Recursive & Split-Horizon DNS Engine

[![Technitium](https://img.shields.io/badge/Technitium-15.6.2-205493?style=for-the-badge&logo=cloudflare&logoColor=white)](https://technitium.com/dns/)
[![DNSSEC](https://img.shields.io/badge/Security-DNSSEC%20Signed-success?style=for-the-badge)](https://technitium.com/dns/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20OIDC-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Telemetry](https://img.shields.io/badge/Metrics-Prometheus%20Exporter-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)

> **Ingress URL:** `https://technitium.internal.205hlab.com` *(Internal LAN only)*  
> **Direct Admin Ports:** `${MNGT_IP}:5380` (HTTP) / `${MNGT_IP}:53443` (HTTPS)  
> **DNS Service Ports:** `53:53/udp`, `53:53/tcp`  
> **Category:** Core Network Infrastructure

Technitium DNS Server is the primary internal nameserver for the `205hlab` infrastructure. It provides split-horizon DNS resolution, ad and malware domain blocking, DNSSEC signing on internal records, recursive upstream forwarding with DNS-over-HTTPS fallback, and automated catalog-driven zone replication to an auxiliary Technitium DNS instance running on the secondary Home Assistant OS (HAOS) appliance.

---

## 🏗️ Architecture & Dual-Instance High Availability

```
[ LAN & IoT Clients ]
         │ DNS Queries (53/udp, 53/tcp)
         ▼
[ Primary Technitium Server ] (Ubuntu Server Docker)
  • Authoritative for 8 zones
  • Internal Split-Horizon: *.internal.205hlab.com
  • Forwarders: 1.1.1.1, 9.9.9.9
  • Prometheus Exporter (:9105)
         │
         │ Catalog Zone Auto-Replication (cluster-catalog.dns.205hlab.com)
         ▼
[ Auxiliary Technitium Replica ] (HAOS on ASUS X540SA)
  • Passive zone replica
  • High-availability DNS continuity during host maintenance
```

- **Authoritative Zones (8 Zones Hosted)**:
  1. `205hlab.com` (Forwarder zone with internal overrides)
  2. `internal.205hlab.com` (Primary — resolves all private management hostnames)
  3. `dns.205hlab.com` (Primary — signed with **DNSSEC**)
  4. `lan.205hlab.com` (Primary — local client dynamic DHCP records)
  5. `mngt.205hlab.com` (Primary — out-of-band management interfaces)
  6. `cluster-catalog.dns.205hlab.com` (Catalog zone driving automated replication)
  7. `0.10.10.in-addr.arpa` (Primary — reverse PTR lookup for `10.10.0.0/24`)
  8. `0.14.10.in-addr.arpa` (Primary — reverse PTR lookup for `10.14.0.0/24`)
- **Resource Constraints:** Governed with `limits: cpus: '1.0'`, `memory: 1G`.
- **Ephemeral Port Range:** Configured via `sysctls: net.ipv4.ip_local_port_range=1024 65535` for high-concurrency recursive query throughput.

---

## 🔐 Authentik Integration (Method 1: Native OIDC with Role Mapping)

Technitium DNS v15+ supports native OpenID Connect authentication with local group mapping via the `roles` token claim.

### 1. Authentik Scope Property Mapping
Technitium evaluates group membership via the `roles` claim.
1. In Authentik, navigate to **Customization** > **Property Mappings** > **Create** > **Scope Mapping**:
   - **Name:** `Technitium DNS roles`
   - **Scope name:** `profile`
   - **Expression:**
     ```python
     return {
         "roles": [
             entitlement.name
             for entitlement in request.user.app_entitlements(provider.application)
         ],
     }
     ```

### 2. Authentik Provider & Application Setup
1. Create an **OAuth2/OpenID Connect Provider**:
   - **Name:** `Technitium Provider`
   - **Client Type:** `Confidential`
   - **Redirect URI (Strict):** `https://technitium.internal.205hlab.com/sso/callback`
   - **Selected Scopes:** `openid`, `profile`, `email`, and the newly created `Technitium DNS roles` scope.
2. Create Application `Technitium DNS` (slug: `technitium-dns`).
3. Under **Application entitlements**, create entitlement `Technitium Admins` and bind it to group `technitium_admins`.

### 3. Technitium In-App SSO Configuration
1. Log in to the Technitium console (`https://technitium.internal.205hlab.com`).
2. Navigate to **Administration** > **Single Sign-On (SSO)**:
   - Check **Enable Single Sign-On (SSO)**.
   - **Authority (Issuer):** `https://authentik.205hlab.com/application/o/technitium-dns/`
   - **Client ID:** `<Client ID from Authentik>`
   - **Client Secret:** `<Client Secret from Authentik>`
   - **Allow New User Sign Up:** Enabled
   - **Allow Sign Up Only For Mapped Users:** Enabled
3. In **Group Map**, add:
   - **Remote Group:** `Technitium Admins`
   - **Local Group:** `Administrators`
4. Click **Save Config**.

> [!WARNING]
> Always retain the local fallback administrator password in `.env` (`DNS_SERVER_ADMIN_PASSWORD`). If upstream DNS or Authentik becomes temporarily unavailable during a network partition, the emergency local admin credentials allow direct recovery via `${MNGT_IP}:5380`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `MNGT_IP` | Out-of-band management IP address | `10.14.0.x` |
| `DNS_SERVER_DOMAIN` | Primary nameserver domain | `technitium.dns.205hlab.com` |
| `DNS_SERVER_ADMIN_PASSWORD` | Fallback emergency console password | *(generated via `setup_secrets.sh`)* |

---

## 🚀 Deployment & Operations

1. **Initialize Secrets & Environment**:
   ```bash
   cd compose/technitium
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN, MNGT_IP, and DNS_SERVER_DOMAIN
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Verify Resolution**:
   ```bash
   # Test local authoritative resolution
   dig @127.0.0.1 internal.205hlab.com
   # Test recursive upstream forwarding
   dig @127.0.0.1 cloudflare.com
   ```

---

## 💾 Backup & Data Persistence

- **Zones & Configuration**: Stored in Docker named volume `technitium_config` (`/etc/dns`).
- **Query Logs**: Stored in Docker named volume `technitium_logs` (`/var/log/technitium/dns`).
- **Catalog Replication**: Automatically synchronizes zone additions, deletions, and records to the auxiliary HAOS server.

---

## 🩺 Healthcheck & Monitoring

- **Container Health**: Built-in HTTP probe checking `http://localhost:5380/` every 30s.
- **Prometheus Telemetry**: Scraped continuously by `technitium_exporter` on port `:9105`, feeding query volume, cache hit ratios, and ad-blocking rate metrics into the [Technitium Grafana Dashboard](../../grafana-dashboards/core/technitium-dns-dashbaord.json).
