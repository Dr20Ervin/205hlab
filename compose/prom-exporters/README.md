# Prometheus Exporters — Full-Stack Metric Collectors

[![Node Exporter](https://img.shields.io/badge/Collector-Node%20Exporter%20v1.8-blue?style=for-the-badge&logo=prometheus&logoColor=white)](https://github.com/prometheus/node_exporter)
[![cAdvisor](https://img.shields.io/badge/Collector-cAdvisor-green?style=for-the-badge&logo=google&logoColor=white)](https://github.com/google/cadvisor)
[![ZFS Exporter](https://img.shields.io/badge/Collector-OpenZFS%20Exporter-005C8A?style=for-the-badge)](https://github.com/pdf/zfs_exporter)
[![Smartctl](https://img.shields.io/badge/Collector-smartctl--exporter-orange?style=for-the-badge)](https://github.com/prometheus-community/smartctl_exporter)
[![PostgreSQL](https://img.shields.io/badge/Collector-Postgres%20Exporter-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://github.com/prometheus-community/postgres_exporter)

> **Network Scope:** Operates on isolated `monitoring_network` and `postgres_network`.  
> **Category:** Infrastructure Telemetry Collection

This stack houses the dedicated metric scrapers and agent daemons that extract raw hardware, kernel, container cgroup, storage, and database statistics across the bare-metal Ubuntu Server host, transforming them into Prometheus-formatted time-series data.

---

## 🏗️ Architecture & Metric Collector Catalog

All exporters communicate over the isolated `monitoring_network` and expose standardized `/metrics` HTTP endpoints for Prometheus:

```
[ Prometheus Scraper ]
         │ HTTP GET /metrics (monitoring_network)
         ▼
┌─────────────────────────────────────────────────────────────┐
│                 Prometheus Exporter Tier                    │
│                                                             │
│  • node-exporter (:9100)       ──► Host Kernel, CPU & RAM   │
│  • cadvisor (:8080)            ──► Docker Cgroups & I/O     │
│  • zfs-exporter                ──► OpenZFS Pool & ARC Stats │
│  • smartctl-exporter (:9633)   ──► Drive S.M.A.R.T. Health  │
│  • technitium-exporter (:9105) ──► DNS Query Statistics     │
│  • postgres-exporter (:9187)   ──► PostgreSQL Internal DBs  │
└─────────────────────────────────────────────────────────────┘
```

### 1. `node-exporter` (Port: `:9100`)
- **Image:** `docker.io/prom/node-exporter:v1.8.2`
- **Scope:** Host hardware telemetry (CPU states, RAM utilization, network interfaces, load averages, and thermal sensors).
- **Hardening:** Runs with `pid: host` and mounts `/host/proc`, `/host/sys`, and `/` (`:ro,rslave`).
- **Filtering:** Filters out virtual docker network interfaces (`veth.*`, `br-.*`, `docker.*`) and ephemeral filesystems to prevent metric bloat.

### 2. `cadvisor` (Port: `:8080`)
- **Image:** `gcr.io/cadvisor/cadvisor:latest`
- **Scope:** Container-level resource consumption (real-time CPU throttling, memory RSS/cache, network tx/rx, disk I/O, and OOM events).
- **Tuning:** Configured with `--docker_only=true`, `--store_container_labels=false`, and tuned housekeeping intervals (`30s`–`2m`) to minimize CPU profiling overhead.

### 3. `zfs-exporter`
- **Image:** `ghcr.io/pdf/zfs_exporter:latest`
- **Scope:** OpenZFS pool health, ARC (Adaptive Replacement Cache) hit ratios, dataset compression, and vdev read/write error counts.
- **Access:** Direct character device passthrough `/dev/zfs:/dev/zfs` and host rootfs mount with `SYS_CHROOT`, `SETUID`, `SETGID` capabilities.

### 4. `smartctl-exporter` (Port: `:9633`)
- **Image:** `prometheuscommunity/smartctl-exporter:latest`
- **Scope:** Physical hard drive S.M.A.R.T. health, reallocated sector counts, drive temperatures, and power-on hours across all physical disks (`/dev/sda`–`/dev/sdd`).
- **Privilege:** Runs as `root` with `privileged: true` to access raw storage controller commands without requiring bloated omnibus containers.

### 5. `technitium_exporter` (Port: `:9105`)
- **Image:** `ghcr.io/guycalledseven/technitium-dns-prometheus-exporter:latest`
- **Scope:** Query throughput, blocked malware/ad domains, cache hit ratios, and upstream resolver latencies across both primary and auxiliary Technitium instances.

### 6. `postgres-exporter` (Port: `:9187`)
- **Image:** `quay.io/prometheuscommunity/postgres-exporter:latest`
- **Scope:** Active connections, table locks, buffer cache hit rates, deadlocks, and transactions per second with `PG_EXPORTER_AUTO_DISCOVER_DATABASES=true`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `POSTGRES_HOST` | Database host | `postgres` |
| `POSTGRES_PORT` | Database port | `5432` |
| `POSTGRES_EXPORTER_USER` | Dedicated read-only exporter user | `postgres_exporter` |
| `POSTGRES_EXPORTER_PASSWORD` | Password for exporter user | *(generated via `setup_secrets.sh`)* |
| `TECHNITIUM_BASE_URL` | Technitium admin endpoint | `http://technitium:5380` |
| `TECHNITIUM_TOKEN` | Technitium API session token | *(from Technitium settings)* |
| `TECHNITIUM_NODES` | Cluster node names | `technitium.dns.205hlab.com,...` |

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, triggering zero-downtime stack updates. (The auxiliary ASUS X540SA node running Home Assistant OS is connected via a **Hawser agent standard v0.2.52** for health observation and troubleshooting only).


1. **Provision Database Exporter User**:
   Execute `db-init.sql` to grant `pg_monitor` rights to the exporter user:
   ```sql
   CREATE USER postgres_exporter WITH ENCRYPTED PASSWORD '...';
   GRANT pg_monitor TO postgres_exporter;
   ```

2. **Initialize Secrets & Environment**:
   ```bash
   cd compose/prom-exporters
   cp example.env .env
   chmod +x setup_secrets.sh && ./setup_secrets.sh
   nano .env # Set TECHNITIUM_TOKEN and database password
   ```

3. **Start Exporters**:
   ```bash
   docker compose up -d
   ```

---

## 🩺 Healthcheck & Monitoring

- Every exporter implements built-in HTTP healthchecks via `wget` (e.g. `http://localhost:9100/`, `http://localhost:9187/`, `http://localhost:9633/metrics`).
- Prometheus continuously scrapes all exporters on 15s intervals.
