# ADR-005: Decouple Smart Home Infrastructure (HAOS) and Auxiliary DNS onto a Dedicated Hardware Appliance

| Field | Value |
| :--- | :--- |
| **Status** | `Accepted` |
| **Date** | `2026-10` |
| **Deciders** | Vajda Ervin-Oliver |
| **Domain** | Hardware Topology & Physical Fault Isolation |
| **Related Documentation** | [`README.md#-physical-infrastructure`](../../README.md#-physical-infrastructure), [`ADR-003`](ADR-003-split-horizon-technitium-dns.md), [`ADR-004`](ADR-004-dockhand-gitops-continuous-deployment.md) |

---

## Context and Problem Statement

Home automation controls physical apartment infrastructure — Zigbee lighting, motion/climate sensors via a **SONOFF Zigbee 3.0 USB Dongle Plus**, and power telemetry from an **APC Back-UPS XS 950U**. Simultaneously, the apartment relies on internal DNS resolution ([ADR-003](ADR-003-split-horizon-technitium-dns.md)) for basic internet connectivity.

If Home Assistant and all DNS instances reside on the same primary compute tower (**Fujitsu ESPRIMO P710**) alongside 20 media, analytics, and database Docker stacks, then any Ubuntu kernel update, Docker daemon restart, ZFS pool maintenance, or storage bottleneck interrupts household lighting, automations, UPS monitoring, and DNS resolution simultaneously.

**Evolutionary Context (Years of Virtualized HAOS):** For years prior to `205hlab`, Home Assistant ran inside a **Virtual Machine on the main server**. That setup repeatedly exposed a fundamental flaw: whenever the primary host suffered an issue or underwent maintenance, apartment IoT lighting and sensors stopped working right alongside the server. Extracting Home Assistant onto a separate physical **ASUS X540SA** laptop (`Intel Celeron N3060` 2C/2T, `4 GB DDR3`, `240 GB Kingston A400 SSD`) salvaged from leftover hardware solved both smart-home fault isolation and created an always-on second machine capable of hosting the **auxiliary DNS replica** (originally running Pi-hole sync and AdGuard Home sync, now upgraded to native **Technitium DNS Catalog Zone replication** per [ADR-003](ADR-003-split-horizon-technitium-dns.md)).

## Decision Drivers

- **Zero Blast-Radius Overlap:** Decouple physical household utilities (Zigbee mesh, automations, UPS monitoring, backup DNS) from primary compute maintenance cycles.
- **Direct Hardware USB Stability:** Eliminate hypervisor/container USB passthrough quirks or ttyACM permission resets for the SONOFF Zigbee coordinator and APC UPS HID link.
- **Multi-Layer Power Resilience:** Leverage both the external **APC Back-UPS XS 950U** and the ASUS laptop's built-in internal battery so smart-home automation and auxiliary DNS outlast prolonged utility brownouts or power-cycling of the main tower.
- **Apartment Acoustics, Thermals & E-Waste Pragmatism:** Achieve ultra-low idle wattage and near-silent operation by repurposing discarded hardware rather than buying new appliances.
- **Physical Fault Domain for Auxiliary DNS:** Ensure `technitium-aux` survives a complete crash or shutdown of the Fujitsu ESPRIMO P710.

## Considered Options

1. **Option 1 (Chosen):** Dedicated Bare-Metal **Home Assistant OS (HAOS)** on Repurposed **ASUS X540SA** + Native **Auxiliary Technitium DNS**
2. **Option 2:** **Home Assistant Container** (`ghcr.io/home-assistant/home-assistant`) on Primary Ubuntu Server
3. **Option 3:** Virtualized **HAOS VM** (KVM / Proxmox VE) on Primary Compute Host with USB Passthrough

### Options Analysis

#### Option 1 — Dedicated Bare-Metal HAOS on Repurposed ASUS X540SA
- **Pros:**
  - Complete physical fault isolation from the primary Ubuntu Server; heavy container updates, storage work, or reboots on `205hlab` never touch Zigbee lighting or UPS monitoring.
  - Native **HAOS Supervisor** unlocks atomic OS updates, official add-ons (including `technitium-aux`), and rock-solid direct USB attachment for the SONOFF Zigbee dongle and APC UPS.
  - Repurposes existing e-waste (`ASUS X540SA`) at near-zero wattage and noise, with an integrated laptop battery providing extra runtime on top of the external UPS.
  - Hosts the secondary **Technitium DNS** replica on separate physical silicon, fulfilling HA requirements from [ADR-003](ADR-003-split-horizon-technitium-dns.md).
- **Cons:**
  - Introduces a second physical host on the LAN that requires hardware monitoring and remote troubleshooting access.
  - Limited CPU/RAM (`Celeron N3060` / `4 GB DDR3`) prohibits running heavy compute containers on this node.

#### Option 2 — Home Assistant Container on Primary Ubuntu Server
- **Pros:**
  - Zero extra physical device; managed purely within `compose/` alongside the 20 existing stacks.
- **Cons:**
  - Shares reboot and failure domains with Docker/Ubuntu maintenance: taking the server down kills apartment automations and UPS tracking during the outage itself.
  - Container mode lacks the official **HAOS Supervisor** add-on ecosystem, requiring manual sidecar wiring for Zigbee2MQTT/Matter/add-ons and leaving Auxiliary DNS coupled to the exact same host.

#### Option 3 — Virtualized HAOS VM on Primary Compute Host *(Prior Architecture)*
- **Pros:**
  - Provides full HAOS Supervisor support inside a snapshotable VM (used successfully by the author for several years prior to `205hlab`).
- **Cons:**
  - As confirmed over years of operation, couples HAOS uptime directly to the primary server — any host outage, kernel reboot, or storage maintenance takes down home IoT automations simultaneously.
  - Requires running a hypervisor or nested KVM/QEMU layer on the bare-metal Ubuntu Docker host and prevents hosting a truly independent Auxiliary DNS hardware fault domain.

## Decision Outcome

**Chosen Option:** **Option 1 — Dedicated Bare-Metal HAOS on Repurposed ASUS X540SA Appliance**

Smart-home infrastructure and auxiliary DNS are physically separated onto the dedicated **ASUS X540SA** node:

1. **Dedicated Physical Responsibilities:** Runs **Home Assistant OS (HAOS)** bare-metal, directly driving the **SONOFF Zigbee 3.0 USB Dongle Plus**, monitoring the **APC Back-UPS XS 950U**, and hosting **Auxiliary Technitium DNS (`technitium-aux`)** fed automatically via RFC Catalog Zone replication from the Ubuntu Server ([ADR-003](ADR-003-split-horizon-technitium-dns.md)).
2. **Strict GitOps & Lifecycle Boundary:** HAOS manages its own native add-on lifecycles (`no Git repo synced` to HAOS). Cross-node integration with the primary server is strictly limited to:
   - **Dockhand Hawser Agent (`standard v0.2.52`)** ([ADR-004](ADR-004-dockhand-gitops-continuous-deployment.md)) for remote container health inspection, log streaming, and troubleshooting from `dockhand.internal.205hlab.com`.
   - **Prometheus Telemetry** surfacing APC UPS load/runtime metrics on Grafana's `APC UPS Dashboard` (`205hlab - Hardware`).

## Consequences

### Positive Consequences
- **100% Maintenance Isolation:** Kernel upgrades, ZFS maintenance, or full Docker daemon restarts on the Fujitsu ESPRIMO P710 cause zero interruption to smart-home devices or household DNS queries.
- **Defense-in-Depth Power Monitoring:** Because the HAOS laptop has its own internal battery and sits behind the APC UPS, it stays online to log power events and ensure clean UPS shutdown coordination even if primary compute powers down.
- **Sustainable Hardware Utilization:** Converts an otherwise obsolete consumer laptop into an always-on low-power infrastructure appliance with zero additional hardware spend.

### Negative Consequences & Mitigations
- **Trade-off (Two-Host Management Surface):** Operating two distinct Linux/HAOS machines increases surface area slightly compared to an all-in-one server.  
  **Mitigation:** HAOS runs an appliance model with atomic updates, while the **Hawser agent (`standard v0.2.52`)** consolidates container log inspection and remediation directly into the primary Dockhand dashboard.
- **Trade-off (4 GB RAM / Celeron N3060 Ceiling):** Host capacity prevents colocation of heavy services on the auxiliary node.  
  **Mitigation:** Workload assignment is strictly capped at HAOS core, Zigbee/UPS integrations, `technitium-aux`, and the lightweight Hawser agent.

## Compliance & Verification (Fitness Functions)

- **Physical Inventory & Architecture Alignment:** Root [`README.md`](../../README.md#haos--smart-home--auxiliary-dns--asus-x540sa) documents the exact ASUS X540SA role and USB hardware attachments.
- **No Unintended Git Sync:** Dockhand GitOps auto-sync schedules target only the primary Ubuntu Server host; the HAOS endpoint connects solely via the read/observe/remediate Hawser agent boundary.
- **Observability:** UPS health and Technitium DNS availability across both physical hosts are actively tracked in Grafana (`APC UPS Dashboard`, `Technitium DNS Exporter`).
