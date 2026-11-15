# ADR-004: Adopt Dockhand for GitOps Continuous Deployment and Zero-Plaintext Secret Injection

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-10` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | CI/CD, GitOps & Secrets Management |
| **Related Files** | [`.github/workflows/validate-compose.yml`](../../.github/workflows/validate-compose.yml), [`compose/README.md`](../../compose/README.md), [`stack-upgrade-and-rollback.md`](../runbooks/stack-upgrade-and-rollback.md) |

---

## Context and Problem Statement

`205hlab` comprises 22 modular Docker Compose stacks powering 30+ services on the primary Ubuntu Server, alongside container workloads running on the auxiliary HAOS appliance (ASUS X540SA). Deploying changes via manual SSH + `docker compose up -d` risks configuration drift between the Git repository and live containers, while traditional Compose workflows require keeping sensitive API keys, database passwords, and OIDC secrets in plain-text `.env` files on the host SSD.

**Evolutionary Context (`Plain CLI` → `Portainer` → `Dockge & Unraid` → `Dockhand on Ubuntu Server`):** Prior iterations progressed from managing containers purely over **plain terminal CLI**, to **Portainer**, and then to **Dockge running on Unraid** (alongside Beszel). While Unraid + Dockge made routine consumer-NAS management easy, Unraid proved overly abstracted and limiting for serious Linux systems administration — obscuring direct bare-metal control over Ubuntu Server, kernel tuning, OpenZFS, `iptables`, and network microsegmentation. Returning to **bare-metal Ubuntu Server LTS** created the opportunity to adopt **Dockhand** for scheduled GitOps and encrypted deploy-time secrets. Meanwhile, full enterprise orchestrators (**Kubernetes / K3s + ArgoCD + HashiCorp Vault**) continue to be evaluated in isolated dev VMs rather than imposing excessive control-plane overhead onto a single 4C/8T production tower.

## Decision Drivers

- **Automated GitOps Reconciliation:** Continuously sync validated Compose changes from `Dr20Ervin/205hlab` (`main`) without manual SSH sessions.
- **Zero-Plaintext Secrets on Disk:** Eliminate static plain-text `.env` files containing production credentials from `/srv` or host home directories; enforce encrypted storage and permanent UI masking (`***`).
- **Two-Stage CI/CD Safety:** Ensure broken YAML schemas or missing `${VAR:?error}` variables are rejected in GitHub Actions **before** any CD engine pulls changes to production.
- **Non-Intrusive Multi-Node Visibility:** Observe container health and logs across both physical machines (Ubuntu Server + HAOS) without syncing Git repositories onto Home Assistant OS or overriding its native Supervisor lifecycle.
- **Right-Sized Control Plane:** Keep orchestration memory/CPU usage near zero relative to application workloads.

## Considered Options

1. **Option 1 (Chosen):** **Dockhand** GitOps + Encrypted Secret Injection + Remote **Hawser Agent (`standard v0.2.52`)**
2. **Option 2:** **Portainer CE / Business Edition**
3. **Option 3:** **Dockge / Unraid** Stack Manager
4. **Option 4:** **Watchtower** + Manual CLI `docker compose` with Plain-Text `.env` Files
5. **Option 5:** **K3s (Kubernetes) + ArgoCD + HashiCorp Vault**

### Options Analysis

#### Option 1 — Dockhand + Encrypted Vault + Hawser Agent (`standard v0.2.52`)
- **Pros:**
  - Native GitOps scheduled polling of `205hlab` Compose stacks directly from GitHub (`main`), reconciling desired state automatically once CI passes.
  - Built-in encrypted secrets database injects environment variables directly into Docker Compose at deploy time — **zero `.env` files exist on disk**, and saved secrets are permanently masked (`***`) in the UI.
  - Pairs cleanly with the lightweight **Hawser agent (`standard v0.2.52`)** on HAOS to stream container status, logs, and remediation controls back into the single Dockhand console without deploying stacks to HAOS.
  - Lightweight footprint, clean native OIDC integration with Authentik (`dockhand_admins`), and restricted to LAN (`dockhand.internal.205hlab.com`).
- **Cons:**
  - Dockhand is a newer ecosystem platform compared to Portainer or ArgoCD, requiring documented manual CLI fallback procedures (`example.env` + `setup_secrets.sh`) for bare-metal cold bootstrap.

#### Option 2 — Portainer CE / Business Edition
- **Pros:**
  - Mature, widely documented Docker UI with Edge Agent multi-node support.
- **Cons:**
  - GitOps auto-polling/webhook flexibility and native encrypted per-secret injection workflows in CE are more limited without Business Edition licensing (node caps / feature gating), whereas Dockhand natively provides encrypted secret masking and scheduled Compose GitOps out of the box.

#### Option 3 — Dockge / Unraid Stack Manager
- **Pros:**
  - Clean, minimal Compose-focused web editor (`Dockge`) paired with an approachable consumer appliance OS (`Unraid`).
- **Cons:**
  - Dockge still leaves sensitive credentials stored in plain-text `.env` files on the host filesystem and lacks scheduled GitOps reconciliation from GitHub with encrypted deploy-time secret masking.
  - Operating inside Unraid abstracts away standard Linux sysadmin workflows (`ubuntu-server`, OpenZFS tooling, native `systemd`, and fine-grained host networking), prompting the deliberate move back to bare-metal Ubuntu Server for a true engineering playground.

#### Option 4 — Watchtower + Manual CLI Docker Compose
- **Pros:**
  - Simple to start; zero management UI to host.
- **Cons:**
  - Watchtower only updates container image tags (`:latest`) — it never reconciles `compose.yaml` structural edits (labels, resource limits, volumes, network rules) from Git.
  - Leaves plain-text `.env` secrets readable on the host filesystem, creating an avoidable local credential-harvesting surface.

#### Option 5 — K3s + ArgoCD + HashiCorp Vault
- **Pros:**
  - Industry-standard declarative reconciliation, RBAC, and dynamic lease-based secret management.
- **Cons:**
  - Over-engineered for a single bare-metal Docker host (`i7-3770`, 4C/8T). Vault unsealing workflows, etcd/K3s control planes, and CRD management add unnecessary cognitive and compute overhead for daily household apps — better reserved for dedicated dev VMs where enterprise patterns are tested.

## Decision Outcome

**Chosen Option:** **Option 1 — Dockhand GitOps + Encrypted Secret Injection + Remote Hawser Agent**

Production delivery operates as a strict **Two-Stage CI/CD Pipeline** (documented in root [`README.md`](../../README.md#-production-cicd-pipeline-github-actions--dockhand-gitops)):

1. **Stage 1 — Continuous Integration Gate (`.github/workflows/validate-compose.yml`):**  
   On every push or pull request touching `compose/**`, GitHub Actions dynamically discovers all 22 stack directories, bootstraps mock bridge networks, populates blank template keys via [`.github/scripts/prepare-test-env.py`](../../.github/scripts/prepare-test-env.py), and validates `docker compose config --quiet` against each `example.env`.
2. **Stage 2 — Continuous Deployment via Dockhand (`dockhand.internal.205hlab.com`):**  
   Once merged to `main`, Dockhand on the Ubuntu Server polls the repository on schedule, injects production secrets from its encrypted internal database at deploy time (**no `.env` files on disk**), and reconciles container state with zero manual SSH intervention.
3. **Remote Node Boundary via Hawser (`standard v0.2.52`):**  
   The auxiliary **ASUS X540SA (HAOS)** node runs the Hawser agent linked back to Dockhand **strictly for remote observability, health monitoring, log inspection, and remediation** — the Git repository is never synced onto or deployed to HAOS.

## Consequences

### Positive Consequences
- **Zero Plain-Text Credential Exposure on Host Storage:** Compromising read access to the host filesystem does not leak database passwords, Cloudflare API tokens, or Authentik signing keys via flat `.env` files.
- **Automated Drift Prevention:** Repository manifests in `compose/` are the single source of truth for running containers.
- **Unified Multi-Node Operations:** Operators can inspect logs across both the Ubuntu Server and HAOS from one Authentik-OIDC-protected dashboard (`dockhand.internal.205hlab.com`).

### Negative Consequences & Mitigations
- **Trade-off (Bootstrapping / Dockhand Outage Dependency):** If the primary host is rebuilt from bare metal or Dockhand itself fails, automated Git sync pauses.  
  **Mitigation:** Every stack maintains an `example.env` template with `${VAR:?error}` validation guards and `setup_secrets.sh` generators, enabling instant manual CLI disaster recovery (`cp example.env .env && bash setup_secrets.sh && docker compose up -d`).
- **Trade-off (Secret Backup Responsibility):** Because Dockhand's encrypted database holds runtime secrets, losing Dockhand's state without backups would require rotating/re-entering credentials.  
  **Mitigation:** Dockhand configuration and critical identity artifacts are included in manual multi-device redundancy while automated 3-2-1 encrypted cloud backups are finalized.

## Compliance & Verification (Fitness Functions)

- **Template-Only Configuration in Git:** Root [`.gitignore`](../../.gitignore) excludes `.env` / `*.env` files while keeping `example.env` templates tracked; every stack in [`compose/`](../../compose/) provides strictly an `example.env` template with `${VAR:?error}` parameter guards.
- **Automated CI Gate:** [`.github/workflows/validate-compose.yml`](../../.github/workflows/validate-compose.yml) enforces schema integrity and required variable contracts on all `compose/*/` stacks before Dockhand syncs `main`.
- **Internal Access Only:** `dockhand.internal.205hlab.com` exists solely in the internal Technitium zone ([ADR-003](ADR-003-split-horizon-technitium-dns.md)) and uses Authentik OIDC (`dockhand_admins`, [ADR-002](ADR-002-authentik-unified-iam.md)).
