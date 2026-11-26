# ADR-007: Replace FlareSolverr with Byparr (Camoufox) for Prowlarr Indexer Challenge Bypass

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-11` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | Media Automation & Acquisition |
| **Related Stacks & Docs** | [`compose/servarr/`](../../compose/servarr/), [`compose/freshrss/`](../../compose/freshrss/), [`ADR-004`](ADR-004-dockhand-gitops-continuous-deployment.md) |

---

## Context and Problem Statement

In `205hlab`, **Prowlarr** (`compose/servarr/`) aggregates public and private torrent/usenet indexers for Sonarr, Radarr, Lidarr, and Chaptarr. Several public indexers sit behind strict Cloudflare anti-bot and Turnstile interstitial challenges, requiring a headless browser proxy on port `8191` to solve challenges and return valid cookies/HTML.

Historically, `compose/servarr/` deployed **FlareSolverr** (`ghcr.io/flaresolverr/flaresolverr:latest`), which drives Chromium via Selenium (`undetected-chromedriver`). In practice, FlareSolverr began failing consistently against updated Cloudflare Turnstile checks while upstream fixes lagged, leaving Prowlarr unable to query protected indexers and breaking automated media searches.

## Decision Drivers

- **Reliable Cloudflare Turnstile Bypass**: Restore consistent challenge solving for Prowlarr indexers without manual intervention.
- **Drop-In Prowlarr API Compatibility**: Expose the standard FlareSolverr-compatible HTTP API on port `8191` so Prowlarr's native Indexer Proxy integration works without custom middleware.
- **Bounded Resource Footprint**: Operate reliably within the existing `cpus: '1.25'` and `memory: 2G` cgroup limit on the 32 GB Fujitsu ESPRIMO P710 host.
- **Stateless Design & Network Microsegmentation**: Keep the solver strictly internal to `servarr_backend` (zero host-published ports, zero Traefik exposure) and eliminate unnecessary persistent state volumes.

## Considered Options

1. **Option 1 (Chosen):** Replace FlareSolverr with **Byparr** (`ghcr.io/thephaseless/byparr:latest`) powered by **Camoufox** (C++-patched anti-detect Firefox) and FastAPI
2. **Option 2:** Retain **FlareSolverr** and integrate external third-party CAPTCHA solving services
3. **Option 3:** Remove challenge-bypass proxying and drop Cloudflare-protected indexers from Prowlarr

### Options Analysis

#### Option 1 — Replace FlareSolverr with Byparr (Camoufox + FastAPI)
- **Pros:**
  - **Camoufox Engine-Level Anti-Detection**: Uses a hardened Firefox build patched at the C++ layer rather than JavaScript-injected Chromium Selenium flags, restoring reliable Cloudflare Turnstile bypass.
  - **Drop-In API Compatibility**: Implements the FlareSolverr HTTP API contract on port `8191`, integrating directly with Prowlarr's existing FlareSolverr Indexer Proxy type.
  - **Stateless & Observable**: Requires no `/config` persistent volume (`flaresolverr_data` removed) and exposes a dedicated FastAPI `/health` endpoint for clean Docker healthchecks.
- **Cons:**
  - Tracks a rolling `:latest` upstream image from a newer community project (`ThePhaseless/Byparr`).
  - Renaming the Compose service from `flaresolverr` to `byparr` requires updating Prowlarr's configured proxy URL once.

#### Option 2 — Retain FlareSolverr with External CAPTCHA Solvers
- **Pros:**
  - Preserves the existing `flaresolverr` service definition and image.
- **Cons:**
  - Introduces paid external API dependencies, latency, and credential management for routine indexer queries.
  - Does not address underlying `undetected-chromedriver` detection regressions on non-CAPTCHA Turnstile challenges.

#### Option 3 — Drop Challenge-Bypass Proxying
- **Pros:**
  - Removes a 2 GB RAM-capped browser container from `compose/servarr/`.
- **Cons:**
  - Breaks access to key public indexers used by Sonarr, Radarr, Lidarr, and Chaptarr.

## Decision Outcome

**Chosen Option:** **Option 1 — Replace FlareSolverr with Byparr (`ghcr.io/thephaseless/byparr:latest`)**

The `compose/servarr/` stack is updated as follows:

1. **Service & Container Rename (`byparr`)**:
   - Rename the Compose service and `container_name` from `flaresolverr` to `byparr` using `ghcr.io/thephaseless/byparr:latest` ([ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr)), replacing [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr).
2. **Internal-Only Microsegmentation**:
   - Attach `byparr` exclusively to the `servarr_backend` bridge network with no host-published `ports:` mapping and no Traefik labels.
   - Update Prowlarr's FlareSolverr Indexer Proxy host from `http://flaresolverr:8191` to `http://byparr:8191`.
3. **Stateless Runtime & Configuration Cleanup**:
   - Remove the unused `flaresolverr_data` named volume and `/config` mount.
   - Remove FlareSolverr-specific environment variables (`LOG_FILE`, `LOG_HTML`, `CAPTCHA_SOLVER`), retaining `LOG_LEVEL=${LOG_LEVEL:-INFO}` and `TZ=${TZ:-UTC}`.
   - Enforce `deploy.resources.limits` (`cpus: '1.25'`, `memory: 2G`) and probe `http://localhost:8191/health` via Docker `healthcheck`.
4. **Release Tracking**:
   - Replace the FlareSolverr Atom feed in `compose/freshrss/rss-feeds/github-automatic-releases.opml` with `https://github.com/ThePhaseless/Byparr/releases.atom`.

## Consequences

### Positive Consequences
- **Restored Indexer Reliability**: Cloudflare-protected indexers resolve cleanly again in Prowlarr, keeping automated Sonarr/Radarr/Lidarr/Chaptarr pipelines operational.
- **Reduced Persistent Volume Footprint**: Eliminates an unused named volume (`flaresolverr-data`) since Byparr runs statelessly.
- **Clearer Operational Naming**: Container names, logs, cAdvisor metrics, and documentation match the actual running software (`byparr`).

### Negative Consequences & Mitigations
- **Trade-off (Rolling `:latest` Tag on a Younger Upstream)**: Upstream changes could introduce regressions.  
  *Mitigation:* Upstream releases are tracked via FreshRSS Release Sentinel (`github-automatic-releases.opml`), and Dockhand GitOps deployments ([ADR-004](ADR-004-dockhand-gitops-continuous-deployment.md)) allow rapid rollback via Git revert.
- **Trade-off (One-Time Consumer URL Update)**: Renaming the service breaks the legacy `http://flaresolverr:8191` DNS alias inside `servarr_backend`.  
  *Mitigation:* Update Prowlarr's Indexer Proxy Host to `http://byparr:8191` and update any corresponding Uptime Kuma container monitor.
- **Trade-off (Browser Burst Resource Usage)**: Concurrent Camoufox browser sessions can spike CPU and memory.  
  *Mitigation:* Hard cgroup limits (`cpus: '1.25'`, `memory: 2G`) prevent Byparr from starving co-located `*arr` services.

## Compliance & Verification (Fitness Functions)

- **Compose Validation**: `compose/servarr/compose.yaml` validates cleanly in CI (`validate-compose.yml`) with `byparr` cgroup limits (`cpus: '1.25'`, `memory: 2G`).
- **Healthcheck Probe**: Container healthcheck verifies `curl -f http://localhost:8191/health || exit 1` every `30s`.
- **Network Isolation**: `byparr` is attached strictly to `servarr_backend` with zero host-bound ports (`8191` is never exposed on the host).
- **End-to-End Proxy Check**: Prowlarr's FlareSolverr Indexer Proxy test succeeds against `http://byparr:8191` and protected indexers pass sync/search tests.
