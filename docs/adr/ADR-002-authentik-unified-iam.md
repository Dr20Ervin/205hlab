# ADR-002: Enforce Unified Zero-Trust IAM with Authentik (Native OIDC & Traefik ForwardAuth)

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-10` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | Security & Identity Access Management (IAM) |
| **Related Stacks** | [`compose/authentik/`](../../compose/authentik/), [`compose/traefik/`](../../compose/traefik/), [`iam-and-ingress-recovery.md`](../runbooks/iam-and-ingress-recovery.md) |

---

## Context and Problem Statement

`205hlab` exposes household productivity tools, media libraries, and observability dashboards over the public internet (`*.205hlab.com`) behind Cloudflare and Traefik v3. Many self-hosted containers either lack built-in authentication altogether, offer only basic single-user passwords without MFA/WebAuthn, or maintain fragmented local user tables.

**Evolutionary Context (Ingress, Directories & Web SSO):** The `205hlab` security architecture distills several previous homelab generations:
- **Edge & Reverse Proxy Progression (`NPM + Cloudflare Tunnels` → `Strictly Cloudflare Tunnels` → `Traefik v3 + WAF + iptables`):** Initial labs paired **Nginx Proxy Manager (NPM)** for internal services with **Cloudflare Tunnels (`cloudflared`)** for WAN exposure, later moving exclusively to Cloudflare Tunnels. In designing `205hlab`, Cloudflare Tunnels were retired in favor of enterprise-grade perimeter engineering: **Traefik Proxy v3** with DNS-01 ACME, **Cloudflare Proxy/WAF**, and strict OpenWrt/Ubuntu **`iptables` Cloudflare origin IP allowlisting**.
- **Directory & POSIX Identity Evolution (`Windows Server AD DS` → `OpenLDAP` → `FreeIPA`):** Previous labs deployed **Windows Server AD DS** in a VM, migrated to **OpenLDAP**, and later adopted **Red Hat FreeIPA** primarily to govern centralized POSIX UID/GID permissions across **OpenZFS datasets and NFS shares**. Because `205hlab` currently consolidates compute onto a single bare-metal Ubuntu host without multi-node NFS user mapping requirements, **FreeIPA** was intentionally left out of single-node production (and remains ready to re-implement whenever scaling out to multiple compute nodes).
- **Mandatory SSO Enforcement (`Selective Authentik` → `100% Zero-Trust Coverage`):** **Authentik** served as the web IdP in previous setups, but covered only select applications. The new `205hlab` baseline makes Authentik **mandatory across every WAN-exposed endpoint** with centralized RBAC.

## Decision Drivers

- **Zero Unauthenticated WAN Surface:** No anonymous HTTP request from the internet may ever reach an internal application backend (`*.205hlab.com`).
- **Fine-Grained RBAC & Entitlements:** Map centralized user groups (e.g., `grafana_admins` vs. `grafana_viewers`, `mealie_admins` vs. `mealie_users`, `jellyfin-kids` vs. `jellyfin-admins`) directly to downstream application permissions.
- **Dual Protocol Coverage:** Support native **OAuth2 / OIDC** where applications offer it, while transparently protecting legacy or stateless web apps (Servarr suite, Web Tools, internal admin UIs) at the reverse-proxy layer.
- **Self-Hosted Sovereignty:** Retain full control over identity flows, MFA/passkeys, user directory, and authentication availability without third-party SaaS dependency limits or external policy changes.
- **Observability & Resource Budget:** Fit cleanly inside the 32 GB host alongside core workloads without JVM-scale RAM consumption.

## Considered Options

1. **Option 1 (Chosen):** Self-Hosted **Authentik** (`server` + `worker` + Embedded Outpost) with a Two-Tier OIDC + Traefik ForwardAuth Hierarchy
2. **Option 2:** **Cloudflare Access** (Cloudflare Zero Trust SaaS Edge)
3. **Option 3:** **Authelia** (Lightweight YAML-Configured Authentication Proxy)
4. **Option 4:** **Keycloak** (Enterprise Java IAM Server)

### Options Analysis

#### Option 1 — Authentik (`ghcr.io/goauthentik/server:2026.8.5`)
- **Pros:**
  - Full-featured GUI-driven identity flows, WebAuthn/Passkeys, TOTP, and LDAP/OIDC/SAML/Proxy providers in a single unified stack.
  - Built-in **Embedded Outpost** seamlessly powers Traefik ForwardAuth (`authentik@docker`) while injecting identity headers (`X-authentik-username`, `X-authentik-groups`, `X-authentik-entitlements`).
  - Integrates cleanly with centralized PostgreSQL 18 (`authentik` database) and exports native Prometheus telemetry metrics.
- **Cons:**
  - Higher RAM footprint (`2G` server limit + `1G` worker limit) and operational complexity than static YAML proxies like Authelia.
  - Because Authentik protects every WAN route, an Authentik outage locks out external logins until recovered.

#### Option 2 — Cloudflare Access (Zero Trust SaaS)
- **Pros:**
  - Blocks unauthenticated traffic at Cloudflare's global edge before a single packet reaches the residential WAN connection.
  - Zero local CPU/RAM overhead on the Fujitsu server.
- **Cons:**
  - Hard dependency on an external SaaS provider for homelab authentication, subject to free-tier seat caps (50 users) and policy limits.
  - Does not easily replace rich in-app OIDC group/role mapping across self-hosted apps (Grafana, Paperless, Mealie, Kavita) or function as cleanly on internal LAN-only zones without complex edge-tunnel dependencies.

#### Option 3 — Authelia
- **Pros:**
  - Very small memory footprint and rapid startup; excellent Traefik ForwardAuth integration.
- **Cons:**
  - Configuration (users, ACL rules, OIDC clients) relies heavily on static YAML files and container restarts rather than a rich dynamic admin UI with visual authentication flows and self-service user enrollment/MFA portals.

#### Option 4 — Keycloak
- **Pros:**
  - Battle-tested OIDC/SAML compliance widely adopted in enterprise environments.
- **Cons:**
  - Heavy JVM memory footprint; lacks a built-in lightweight reverse-proxy ForwardAuth outpost equivalent without deploying an external `oauth2-proxy` layer for every non-OIDC app.

## Decision Outcome

**Chosen Option:** **Option 1 — Self-Hosted Authentik with a Mandatory Two-Tier Enforcement Hierarchy**

Authentik (`compose/authentik/`) acts as the mandatory security perimeter for **all 31 protected services** across `205hlab`, governed by ~30 structured RBAC groups (`authentik Admins`, `pgdb_admins`, `dockhand_admins`, `technitium_admins`, `grafana_admins`/`editors`/`viewers`, `mealie_admins`/`users`, `jellyfin-admins`/`users`/`kids`/`users-hun`, etc.):

1. **Tier 1 — Native OAuth2 / OIDC (11 Services):**  
   Preferred wherever supported — **Dockhand, FreshRSS, Grafana 13, Jellyfin (via SSO Plugin), Kavita, Mealie, Paperless-ngx, Profilarr, qui, Reactive Resume, and Technitium DNS**. Authentik supplies `/application/o/<slug>/` discovery endpoints and maps group/entitlement claims directly to downstream roles.
2. **Tier 2 — Traefik ForwardAuth Middleware (20 Services):**  
   Enforced via the `authentik@docker` middleware label declared on [`authentik-server`](../../compose/authentik/compose.yaml#L44-L59) for all applications without native OIDC (the Servarr suite, Seerr, SearXNG, MeTube, Speedtest Tracker, Tracearr, ChangeDetection, Web Tools, Adminer, Databasus, MyIP). Traefik intercepts requests at `/outpost.goauthentik.io/auth/traefik` before proxying any traffic to upstream containers.

## Consequences

### Positive Consequences
- **Uniform Zero-Trust Perimeter:** Zero public routes bypass Authentik; even zero-day vulnerabilities in unauthenticated `*arr` or utility web UIs cannot be exploited directly from WAN without clearing Authentik's MFA/Passkey flow.
- **Single Source of Truth for Permissions:** Promoting or revoking a household member's admin rights in Grafana, Mealie, or Paperless happens centrally in Authentik Groups.
- **Clean LAN & WAN UX:** Users authenticate once per browser session across 30+ independent applications.

### Negative Consequences & Mitigations
- **Trade-off (Critical-Path Availability Dependency):** If `authentik-server` or its `authentik` PostgreSQL database is down, all ForwardAuth-gated routes and OIDC logins fail closed (HTTP `401`/`502`).  
  **Mitigation:** Isolated server/worker containers with explicit cgroup caps (`2.0` CPUs / `2G` RAM for server, `1.0` CPU / `1G` RAM for worker), automated PostgreSQL backups via Databasus, and direct LAN/management subnet fallback on critical infrastructure where required (`openspeed`, `${MNGT_IP}:5380`).
- **Trade-off (Docker Socket Exposure on Worker):** `authentik-worker` mounts `/run/docker.sock` for embedded outpost management.  
  **Mitigation:** Only the internal worker mounts the socket, separated onto `authentik_backend` and monitored closely; public Traefik ingress only talks to `authentik-server:9000`.

## Compliance & Verification (Fitness Functions)

- **Compose Middleware Audit:** Every WAN-exposed router in `compose/*/` lacking native OIDC must declare `traefik.http.routers.<service>_https.middlewares=authentik@docker`.
- **RBAC Documentation Sync:** [`compose/authentik/README.md`](../../compose/authentik/README.md) maintains the complete 31-service integration matrix and Authentik group taxonomy.
- **Monitoring:** Authentik metrics are scraped over `monitoring_network` into Prometheus and visualized on the `authentik` Grafana dashboard (`205hlab - Core`).
