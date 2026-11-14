# Network Monitor — WAN & LAN Bandwidth, Latency & Leak Diagnostics

[![Speedtest Tracker](https://img.shields.io/badge/Speedtest-Tracker-4CAF50?style=for-the-badge&logo=speedtest&logoColor=white)](https://github.com/alexjustesen/speedtest-tracker)
[![OpenSpeedTest](https://img.shields.io/badge/OpenSpeedTest-LAN%20Benchmark-00A8FF?style=for-the-badge)](https://openspeedtest.com/)
[![MyIP](https://img.shields.io/badge/Diagnostics-MyIP%20Leak%20Test-FF9800?style=for-the-badge)](https://github.com/jason5ng32/MyIP)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2018-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Ingress URLs:**  
> - **Speedtest Tracker:** `https://speedtest.205hlab.com` *(WAN Analytics)*  
> - **OpenSpeedTest:** `https://openspeed.internal.205hlab.com` *(LAN Benchmark)*  
> - **MyIP Leak Test:** `https://myip.internal.205hlab.com` *(IP & DNS Diagnostics)*  
> **Category:** Network Telemetry & Auditing

This stack provides continuous performance auditing and diagnostics across both the public WAN connection and the local gigabit LAN infrastructure. It tracks ISP bandwidth delivery over time, benchmarks raw local switch throughput without consuming external data caps, and detects IP or DNS leaks on management interfaces.

---

## 🏗️ Architecture & Component Roles

```
[ Client Device ]
        │
        ├─► [ Speedtest Tracker (:80) ] ──► Ookla CLI ──► [ ISP WAN Throughput ]
        │          │                                        (Scheduled: 23 */3 * * *)
        │          └──► Relational State: PostgreSQL 18
        │
        ├─► [ OpenSpeedTest (:3000) ] ────► In-Memory ──► [ LAN Gigabit Benchmark ]
        │                                                  (${LAN_IP}:3000, No WAN cap)
        │
        └─► [ MyIP (:18966) ] ────────────► Diagnostics ─► [ IP/DNS/WebRTC Leak Test ]
```

1. **`speedtest-tracker`**: Automated Ookla Speedtest CLI runner. Executes every 3 hours (`23 */3 * * *`) to profile 24-hour ISP bandwidth, ping, and jitter trends without interfering with peak evening household streaming. Persists historical metrics to PostgreSQL 18 and feeds the pre-configured [Grafana Speedtest Dashboard](../../grafana-dashboards/core/speedtest-tracker.json).
2. **`openspeedtest`**: Pure HTML5 in-network speed test server. Binds directly to `${LAN_IP}:3000` and `${MNGT_IP}:3000`, enabling workstations, Wi-Fi clients, and OpenWrt routers to benchmark 1Gbps physical switch link saturation without incurring reverse proxy overhead or external internet usage.
3. **`myip`**: Comprehensive IP and network diagnostics toolbox. Checks public egress IP addresses, ISP BGP information, DNS resolver leakage, and WebRTC IP exposure.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

Network monitoring interfaces are secured at the Traefik perimeter by Authentik:

* **Speedtest Tracker (`speedtest.205hlab.com`)**:
  - Protected via `authentik@docker` middleware.
  - Bound to group `speedtest_users` or `authentik Admins`.
* **MyIP Diagnostics (`myip.internal.205hlab.com`)**:
  - Gated via `authentik@docker` middleware.
  - Bound to group `myip_users`.
* **OpenSpeedTest (`openspeed.internal.205hlab.com`)**:
  - Available on internal DNS (`internal.205hlab.com`) for lightweight LAN speed testing without auth overhead on direct IP port `${LAN_IP}:3000`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `PUID` / `PGID` | Non-root file permissions | `1000` / `1000` |
| `LAN_IP` | Primary server LAN IP | `10.10.0.x` |
| `MNGT_IP` | Management VLAN interface IP | `10.14.0.x` |
| `POSTGRES_HOST` | Database host | `postgres` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_DB` | Database name | `speedtest_tracker` |
| `POSTGRES_USER` | Database username | `speedtest_app` |
| `POSTGRES_PASSWORD` | Database password | *(generated via `setup_secrets.sh`)* |
| `APP_KEY` | Laravel encryption key | *(generated via `setup_secrets.sh`)* |
| `SPEEDTEST_SCHEDULE` | Cron schedule for automated speedtests | `23 */3 * * *` |

---

## 🚀 Deployment & Operations

1. **Provision PostgreSQL Database**:
   Execute `db-init.sql` against PostgreSQL:
   ```bash
   docker exec -i postgres psql -U postgres < compose/network-mon/db-init.sql
   ```

2. **Initialize Secrets & Environment**:
   ```bash
   cd compose/network-mon
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set FQDN, LAN_IP, and MNGT_IP
   ```

3. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify Telemetry**:
   - Access `https://speedtest.205hlab.com` and run an initial manual test.
   - Open Grafana at `https://grafana.205hlab.com` to confirm that the **Speedtest Tracker** dashboard is graphing latency and download/upload throughput.

---

## 💾 Backup & Data Persistence

- **Historical Test Records**: All bandwidth records, ping latency, and server locations reside in PostgreSQL (`speedtest_tracker` database).
- **Application Configuration**: Stored in Docker named volume `speedtest_config`.
- **Stateless Benchmarks**: `openspeedtest` and `myip` operate in-memory and retain zero persistent state.

---

## 🩺 Healthcheck & Monitoring

- **Speedtest Health**: Monitored every 30s via `curl -f http://127.0.0.1:80/api/healthcheck`.
- **OpenSpeedTest Health**: Probed every 30s via `wget --spider http://127.0.0.1:3000/`.
- **MyIP Health**: Probed every 30s via `wget --spider http://127.0.0.1:18966/`.
