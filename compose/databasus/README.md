# Databasus & Automated Restore Verification — PostgreSQL Backups & Sanity Checks

[![Databasus](https://img.shields.io/badge/Databasus-v3.65.0-336791?style=for-the-badge)](https://github.com/databasus/databasus)
[![Verifier](https://img.shields.io/badge/Verifier-verification--agent%20run-4169E1?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/databasus/databasus)
[![Checksums](https://img.shields.io/badge/Data%20Integrity-Automated%20Restore%20Check-success?style=for-the-badge)](../../docs/runbooks/disaster-recovery.md)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Internal Ingress URL (LAN Only):** `https://databasus.internal.205hlab.com`  
> **Verification Agent Container:** `databasus-verifier` / `205hlab-databasus-verifier` *(foreground `./verification-agent run`)*  
> **Category:** Backup & Disaster Recovery Infrastructure  
> **Architecture Decision Record:** See [**ADR-001**](../../docs/adr/ADR-001-centralized-postgresql-18.md) and the [**Disaster Recovery & Restore Drill Runbook**](../../docs/runbooks/disaster-recovery.md).

This stack deliberately decouples **Databasus** (the automated PostgreSQL backup coordinator) and **`databasus-verifier`** (Databasus's official `verification-agent` worker) from the primary [`compose/postgres/`](../postgres/) database stack.

---

## 🏗️ Why Decoupled & Official Verification Architecture

```
                [ Traefik Proxy (Internal Ingress) ]
                              │
                              │ Authentik ForwardAuth (pgdb_admins)
                              ▼
                   [ Databasus (:4005) ]
                     • Volume: databasus-data
                     • Backups: ${DATABASUS_BACKUP}
                              │
         ┌────────────────────┴────────────────────────┐
         │ (postgres_network)                          │ (databasus_internal · HTTP internal)
         ▼                                             ▼
[ Primary PostgreSQL 18 ]                   [ databasus-verifier ]
(compose/postgres/stack)                    • Docker CLI + /tmp/verification-agent run
• Scheduled daily pg_dump                   • Spins up ephemeral postgres:18 container
• Remains independent of Databasus          • Restores backup -> counts per-table rows
                                            • Destroys throwaway container when finished
```

- **Failure Independence:** If the primary `postgres` container in `compose/postgres/` goes down or is stopped for major maintenance/recovery, **Databasus stays online** so you still have full UI access to backup snapshots and restore workflows.
- **Native Automated Restore Verification (`databasus-verifier`):** Rather than wasting idle DDR3 RAM on a permanently running second PostgreSQL container or trusting archive checksums alone, `databasus-verifier` downloads the exact matching `verification-agent` Go binary directly from `http://databasus:4005/api/v1/system/verification-agent?arch=amd64` on startup and executes `./verification-agent run` as `PID 1`.
  - Uses **`--allow-insecure-http` over the private `databasus_internal` Docker bridge** (`http://databasus:4005`), keeping `https://databasus.internal.205hlab.com` 100% locked behind Authentik `ForwardAuth` with zero auth bypass rules.
  - Uses **`./verification-agent run`** (foreground process) instead of `start` (background daemon fork) so Docker monitors `PID 1`, streams live verification logs to Dockhand, and avoids restart loops.
  - Allocates **`--max-cpu=2`**, **`--max-ram-mb=2048`**, **`--max-disk-gb=25`**, and **`--max-concurrent-jobs=1`** so sequential *"After backup"* jobs run at full speed within Databasus's 1 CPU / 512 MB floor + 5 GB disk headroom requirement.
  - Note on least-privilege boundary: Only `databasus-verifier` mounts `/var/run/docker.sock` to spawn and tear down throwaway PostgreSQL containers; the core `databasus` backup server has zero Docker socket access.
- **Seamless Volume Preservation:** Retains the exact external volume name (`databasus-data`) so migrating from `compose/postgres/` preserves existing backup schedules and Databasus configuration.

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

Databasus is strictly internal (`databasus.internal.205hlab.com`) and guarded by Traefik ForwardAuth:

```yaml
labels:
  - "traefik.http.routers.databasus_https.middlewares=authentik@docker"
```

* **Domain Restriction:** Exists solely inside Technitium's private `internal.205hlab.com` zone ([ADR-003](../../docs/adr/ADR-003-split-horizon-technitium-dns.md)).
* **Access Control:** Bound to `pgdb_admins` or `authentik Admins`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |
| `DATABASUS_BACKUP` | Host path containing PostgreSQL backup archives | `/mnt/storage/backups/postgres` |
| `DATABASUS_AGENT_ID` | Verification Agent UUID generated in Databasus UI | *(UI: Settings -> Verification agents)* |
| `DATABASUS_AGENT_TOKEN` | One-time verification agent auth token | *(Injected via Dockhand encrypted vault)* |
| `DATABASUS_MAX_CPU` | CPU budget advertised to Databasus across concurrent jobs | `2` |
| `DATABASUS_MAX_RAM_MB` | Memory budget in MB advertised to Databasus | `2048` |
| `DATABASUS_MAX_DISK_GB` | Temporary disk budget in GB (archive + raw DB + 5 GB gap) | `25` |
| `DATABASUS_MAX_CONCURRENT_JOBS` | Max parallel restore verification containers | `1` |

---

## 🚀 First-Time Setup & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**  
> In daily operations, this stack is deployed and maintained via **Dockhand** on the Ubuntu Server. Commits pushed to this repository are pulled automatically on a scheduled interval by Dockhand, injecting `DATABASUS_AGENT_ID` and `DATABASUS_AGENT_TOKEN` from its encrypted vault at deploy time (zero plain-text `.env` on disk).

### Bootstrapping a Fresh Stack (Chicken-and-Egg Agent Registration)

1. **Bring up `databasus` first** to generate your agent credentials:
   ```bash
   cd compose/databasus
   docker compose up -d databasus
   ```
   *(Or deploy `databasus` in Dockhand with placeholder values first, then update secrets.)*

2. **Create the Verification Agent in Databasus UI:**
   - Open `https://databasus.internal.205hlab.com` -> **Settings** -> **Verification agents** -> **Create verification agent** (e.g., `205hlab-prod-verifier`).
   - Copy the **`Agent ID`** and one-time **`Token`** before closing the dialog.

3. **Save Secrets & Bring Up the Full Stack:**
   - Save `DATABASUS_AGENT_ID` and `DATABASUS_AGENT_TOKEN` inside Dockhand's encrypted vault (or in `.env` for manual CLI recovery) and deploy the full stack:
     ```bash
     docker compose up -d
     ```

4. **Enable Automated Schedule per Database:**
   - In Databasus, open each production database -> **Restore verifications** -> enable **Scheduled verification** -> select **After backup** (or Cron), and optionally enable **Verification failed** notifications only to avoid alert fatigue.

5. **Runbooks & Manual Verification:**
   Follow automated monitoring and on-demand CLI restore procedures in [**`docs/runbooks/disaster-recovery.md`**](../../docs/runbooks/disaster-recovery.md).

---

## 🩺 Healthcheck & Monitoring

- **Databasus Health:** Probed every 30s via HTTP spider on `http://localhost:4005/`.
- **Verifier Health:** Probed every 30s confirming `/tmp/verification-agent run` stays alive as foreground `PID 1`.
