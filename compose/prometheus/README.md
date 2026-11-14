# Prometheus — Time-Series Telemetry & Metrics Storage

[![Prometheus](https://img.shields.io/badge/Prometheus-v3.11.3-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io)
[![TSDB Retention](https://img.shields.io/badge/Retention-30d%20%2F%2050GB-blue?style=for-the-badge)](https://prometheus.io/docs/prometheus/latest/storage/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)
[![Reverse Proxy](https://img.shields.io/badge/Ingress-Traefik%20v3-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)](https://traefik.io)

> **Ingress URL:** `https://prometheus.internal.205hlab.com` *(Internal LAN Only)*  
> **Direct Management Port:** `${MNGT_IP}:9096`  
> **Category:** Core Observability Infrastructure

Prometheus v3 is the central time-series database (TSDB) and monitoring engine for the `205hlab` infrastructure. It periodically scrapes system, container, database, DNS, router, storage, and UPS telemetry across all homelab layers, providing high-resolution query capabilities via PromQL and supplying real-time metric streams to Grafana dashboards.

---

## 🏗️ Architecture & Metric Collection

```
                    [ Prometheus TSDB (:9090) ]
                    • 30-Day / 50GB Retention Cap
                    • Dynamic Config Lifecycle Enabled
                                 │
         ┌───────────────────────┴───────────────────────┐
         │ Scrapes over internal monitoring_network      │
         ▼                                               ▼
[ Host & Cgroup Exporters ]                    [ Application Exporters ]
• Node Exporter (:9100)                        • Postgres Exporter (:9187)
• cAdvisor (:8080)                             • Technitium Exporter (:9105)
• ZFS Exporter                                 • Traefik Ingress (:9090)
• Smartctl Exporter (:9633)                    • qui Exporter (:9074)
• OpenWrt Router Exporter                      • Speedtest Tracker
• APC UPS Exporter
```

- **Retention Quotas:** Governed with strict boundaries (`--storage.tsdb.retention.time=30d`, `--storage.tsdb.retention.size=50GB`) to prevent database bloat from impacting host disk health.
- **Dynamic Config Reloads:** Launched with `--web.enable-lifecycle`, allowing Prometheus to reload `prometheus.yaml` dynamically without container restarts via `POST /-/reload`.
- **Resource Constraints:** Governed with `limits: cpus: '1.0'`, `memory: 4G`.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

Prometheus is restricted to the internal split-horizon network (`prometheus.internal.205hlab.com`) and secured at the Traefik edge via Authentik ForwardAuth:

```yaml
labels:
  - "traefik.http.routers.prometheus_https.middlewares=authentik@docker"
```

* **Access Control:** Bound to group `grafana_admins` or `authentik Admins`.
* **Out-of-Band Access:** Port `${MNGT_IP}:9096` is bound strictly to the management VLAN interface for disaster recovery and automated scraper access.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `MNGT_IP` | Out-of-band management IP address | `10.14.0.x` |
| `RETENTION_TIME` | Time-series data retention duration | `30d` |
| `RETENTION_SIZE` | Maximum storage volume size | `50GB` |
| `PROMETHEUS_DATA` | Host path for TSDB data files | `/srv/prometheus/data` |
| `PROMETHEUS_CONFIG` | Host path containing `prometheus.yaml` | `/srv/prometheus/config` |

---

## 🚀 Deployment & Operations

1. **Initialize Environment**:
   ```bash
   cd compose/prometheus
   cp example.env .env
   nano .env # Set FQDN, MNGT_IP, and paths
   ```

2. **Start Prometheus**:
   ```bash
   docker compose up -d
   ```

3. **Reload Configuration Dynamically**:
   If you update `prometheus.yaml`, trigger a live reload without downtime:
   ```bash
   curl -X POST http://localhost:9096/-/reload
   ```

---

## 💾 Backup & Data Persistence

- **TSDB Blocks:** Stored at `${PROMETHEUS_DATA}` (WAL and compressed 2h chunk blocks).
- **Scrape Configuration:** Managed in [`prometheus.yaml`](prometheus.yaml) under version control.

---

## 🩺 Healthcheck & Monitoring

- **Engine Health**: Continuously queried every 30s via `wget --spider http://localhost:9090/-/healthy`.
- **Self-Monitoring**: Prometheus scrapes its own runtime performance metrics at `http://localhost:9090/metrics`.
