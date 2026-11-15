# ADR-003: Deploy Split-Horizon Technitium DNS with RFC Catalog Zone HA Replication

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-10` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | Networking & DNS |
| **Related Stacks** | [`compose/technitium/`](../../compose/technitium/), [`compose/prom-exporters/`](../../compose/prom-exporters/), [`dns-failover-and-sync.md`](../runbooks/dns-failover-and-sync.md) |

---

## Context and Problem Statement

`205hlab` operates two distinct categories of FQDNs: public-facing services (`*.205hlab.com`) routed through Cloudflare WAF, and strictly private infrastructure interfaces (`*.internal.205hlab.com` — Adminer, Databasus, Dockhand, Prometheus, Technitium UI, ChangeDetection, OpenSpeedTest, MyIP) plus dedicated LAN/management reverse-DNS subnets (`10.10.0.0/24`, `10.14.0.0/24`).

Internal management hostnames must **never exist in public DNS**, while LAN clients accessing public `*.205hlab.com` domains should resolve locally to Traefik to avoid hairpinning traffic out through the WAN gateway. Furthermore, because DNS is a foundational dependency for every device in the apartment, rebooting or maintaining the primary Ubuntu Server must not take down household internet resolution.

**Evolutionary Context (`Pi-hole` → `AdGuard Home` → `BIND9` → `Technitium DNS`):** This choice is the direct culmination of operating four distinct DNS stacks in earlier homelab iterations: starting with **Pi-hole** (paired with external Pi-hole sync across hosts), upgrading to **AdGuard Home** (paired with AdGuard sync), graduating to raw **BIND9** for proper authoritative zones and transfers, and finally converging on **Technitium DNS** for `205hlab`. Each step exposed concrete limits — sinkholes lacked native multi-zone/Catalog replication without brittle third-party sync scripts, while BIND9 required manual text zonefile edits without integrated blocklists or a modern web/OIDC admin UI.

## Decision Drivers

- **Split-Horizon Isolation:** Guarantee that `*.internal.205hlab.com`, `*.lan.205hlab.com`, and `*.mngt.205hlab.com` resolve solely inside private VLANs and remain invisible on Cloudflare/public DNS.
- **Full Authoritative DNS Capabilities:** Host 8 distinct zones (forwarder, primary forward zones, RFC 1918 reverse PTR zones, and DNSSEC-signed `dns.205hlab.com`) in one cohesive engine without manually editing BIND text zonefiles.
- **Automated Primary-to-Secondary Replication:** Synchronize zones automatically across two physical hosts without fragile third-party SSH/rsync scripts or API-scraping workarounds.
- **Integrated Ad & Tracker Sinkholing:** Block ads and telemetry network-wide at the resolver layer alongside split-horizon authoritative resolution.
- **Native Observability:** Export DNS query latency, block rates, and zone health to Prometheus and Grafana.

## Considered Options

1. **Option 1 (Chosen):** Dual-Node **Technitium DNS Server** with RFC-Compliant **Catalog Zone Replication** (Primary on Ubuntu Server + Auxiliary on HAOS)
2. **Option 2:** **Pi-hole** + **Unbound** + External Sync Scripts (`nebula-sync` / `gravity-sync`)
3. **Option 3:** **AdGuard Home** + External Sync Tooling
4. **Option 4:** **ISC BIND9** Authoritative / Recursive Server

### Options Analysis

#### Option 1 — Technitium DNS Server (`technitium/dns-server:15.6.2` + Catalog Zone HA)
- **Pros:**
  - Combines BIND9-grade RFC-compliant authoritative + recursive DNS features (Primary, Secondary, Forwarder, DNSSEC, and native **Catalog Zones** via `cluster-catalog.dns.205hlab.com`) with a modern web UI and built-in **OIDC SSO** compatibility.
  - Native **DNSSEC** signing (enabled on `dns.205hlab.com`) with zero raw zonefile syntax errors.
  - Adding, editing, or deleting a zone or record on the Primary Ubuntu node automatically propagates via standard AXFR/IXFR to the Auxiliary node on HAOS (`technitium-aux`).
  - Integrated DNS blocklists (`DNS_SERVER_ENABLE_BLOCKING=true`) match Pi-hole/AdGuard sinkholing in the same binary.
- **Cons:**
  - Slightly steeper initial learning curve when configuring Catalog Zone TSIG/transfer relationships compared to a consumer DNS sinkhole.
  - Smaller mainstream homelab community footprint than Pi-hole (requiring explicit documentation in this repository).

#### Option 2 — Pi-hole + Unbound + External Sync Scripts
- **Pros:**
  - Familiar entry-level setup (used in the author's earliest DNS labs), lightweight resource usage, and rich ecosystem of ad-blocking lists.
- **Cons:**
  - Relies on `dnsmasq` under the hood and lacks native multi-zone authoritative DNS management, reverse PTR zone UIs, DNSSEC zone signing, and RFC Catalog Zones.
  - Primary/secondary redundancy depends on third-party sync utilities (`nebula-sync`, `gravity-sync`), introducing version coupling and sync drift over time.

#### Option 3 — AdGuard Home + Sync Tooling
- **Pros:**
  - Clean single-binary deployment with DoH/DoT/DoQ support and modern UI (served as the author's second DNS stage after Pi-hole).
- **Cons:**
  - Limited authoritative zone management: DNS rewrites handle basic A/CNAME overrides, but lack true Primary/Secondary AXFR transfers, Catalog Zone HA clustering, and full PTR/DNSSEC zone workflows, still requiring external sync tooling between hosts.

#### Option 4 — ISC BIND9
- **Pros:**
  - Industry gold standard for RFC-compliant authoritative zones, AXFR/IXFR primary-secondary replication, DNSSEC signing, and split-horizon ACL views (proven in the author's pre-Technitium DNS stage).
- **Cons:**
  - High day-to-day operational friction from maintaining raw text zonefiles and incrementing serial numbers manually for routine homelab record updates.
  - No native web admin GUI, OIDC integration, or integrated DNS ad/malware sinkholing without chaining separate filtering proxies.

## Decision Outcome

**Chosen Option:** **Option 1 — Dual-Node Technitium DNS Server with RFC Catalog Zone Replication**

DNS infrastructure is split across two physically independent hosts:

1. **Primary Authoritative Server (`compose/technitium/`):**  
   Runs `docker.io/technitium/dns-server:15.6.2` on the Ubuntu Server (`cpus: '1.0'`, `memory: 1G`), binding `53/tcp` & `53/udp` for LAN queries and restricting admin ports (`:5380`, `:53443`) to `${MNGT_IP}` plus Traefik (`technitium.internal.205hlab.com`). Recursion is strictly locked (`DNS_SERVER_RECURSION=AllowOnlyForPrivateNetworks`) and upstream non-local queries forward to Cloudflare (`1.1.1.1`) and Quad9 (`9.9.9.9`).
2. **8-Zone Authoritative Layout + DNSSEC:**  
   Manages `205hlab.com` (Forwarder with split-horizon LAN overrides), `internal.205hlab.com`, `lan.205hlab.com`, `mngt.205hlab.com`, `dns.205hlab.com` (**DNSSEC-signed**), `0.10.10.in-addr.arpa`, `0.14.10.in-addr.arpa`, and `cluster-catalog.dns.205hlab.com` (**Catalog Zone**).
3. **Zero-Touch Auxiliary Failover (`technitium-aux` on HAOS):**  
   Runs natively on the separate **ASUS X540SA** appliance ([ADR-005](ADR-005-decouple-smart-home-haos-appliance.md)), subscribed as a Secondary member to `cluster-catalog.dns.205hlab.com`. Any zone change on the Ubuntu Server replicates automatically to HAOS without manual duplication.

## Consequences

### Positive Consequences
- **Resilient Household DNS:** Rebooting the Fujitsu ESPRIMO P710 for kernel updates or Docker maintenance leaves LAN clients seamlessly served by `technitium-aux` on the ASUS X540SA.
- **Zero Public Exposure of Internal Topology:** `*.internal.205hlab.com` and `*.mngt.205hlab.com` never touch Cloudflare DNS APIs — external attackers cannot enumerate internal management UIs even if DNS records are queried externally.
- **No Hairpin NAT:** LAN devices access `*.205hlab.com` over direct gigabit switching to Traefik.
- **Unified Telemetry:** `technitium-exporter` in [`compose/prom-exporters/`](../../compose/prom-exporters/) exports query throughput, NXDOMAIN spikes, and blocked request metrics to Grafana (`205hlab - Core`).

### Negative Consequences & Mitigations
- **Trade-off (Catalog Zone Setup Complexity):** Incorrect catalog member permissions or firewall rules between LAN/Management VLANs can stall replication.  
  **Mitigation:** Documented zone inventory in root [`README.md`](../../README.md#-technitium-dns--dual-instance-architecture) and [`compose/technitium/README.md`](../../compose/technitium/README.md), with health monitoring via `technitium-exporter` and HAOS integration.

## Compliance & Verification (Fitness Functions)

- **Recursion Guard:** [`compose/technitium/compose.yaml`](../../compose/technitium/compose.yaml) enforces `DNS_SERVER_RECURSION=AllowOnlyForPrivateNetworks` so the server can never become an open DNS amplifier.
- **Management Port Binding:** Admin ports `5380` and `53443` bind explicitly to `${MNGT_IP}` rather than `0.0.0.0`.
- **Internal Zone Segregation:** None of the `*.internal.205hlab.com` routes appear in external Cloudflare DNS records.
