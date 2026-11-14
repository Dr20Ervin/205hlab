# Web Tools — Hardened Client-Side Engineering & Document Utilities

[![IT-Tools](https://img.shields.io/badge/Utility-IT--Tools-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://it-tools.tech/)
[![Omni-Tools](https://img.shields.io/badge/Utility-Omni--Tools-7B1FA2?style=for-the-badge)](https://github.com/iib0011/omni-tools)
[![Draw.io](https://img.shields.io/badge/Diagram-Draw.io-F08705?style=for-the-badge&logo=diagramsdotnet&logoColor=white)](https://www.drawio.com/)
[![BentoPDF](https://img.shields.io/badge/PDF-BentoPDF%20WASM-E53935?style=for-the-badge&logo=adobeacrobatreader&logoColor=white)](https://github.com/alam00000/bentopdf)
[![Security](https://img.shields.io/badge/Security-Read--Only%20Filesystem-success?style=for-the-badge)](https://docs.docker.com/engine/security/)
[![Auth](https://img.shields.io/badge/Auth-Authentik%20ForwardAuth-fd4b2d?style=for-the-badge&logo=authentik&logoColor=white)](https://goauthentik.io)

> **Ingress URLs:**  
> - **IT-Tools:** `https://it-tools.205hlab.com`  
> - **Omni-Tools:** `https://omni.205hlab.com`  
> - **Draw.io:** `https://draw.205hlab.com`  
> - **BentoPDF:** `https://pdf.205hlab.com`  
> **Category:** Developer & Household Utilities

This compose stack hosts a hardened collection of client-side engineering, diagramming, and PDF utilities. Every application in this stack executes computation (token decoding, regex debugging, cryptographic hashing, vector diagramming, and PDF page merging) **purely client-side in the browser via JavaScript and WebAssembly (WASM)**. No user data, passwords, or document contents are ever transmitted to third-party public SaaS providers or retained on the homelab host.

---

## 🏗️ Architecture & Defense-in-Depth Container Hardening

Every container in this suite is strictly isolated to prevent lateral movement or persistence:
- **`read_only: true` Root Filesystem:** Prevents malware or hijacked processes from writing binaries or tampering with Nginx configurations.
- **`no-new-privileges:true`:** Drops all setuid/setgid privilege escalation vectors.
- **Volatile `tmpfs` Mounts:** In-memory `/tmp`, `/var/run`, and `/var/cache/nginx` mounts are wiped clean upon container termination.
- **Network Isolation:** Attached solely to `traefik_network`. None of these utilities possess access to the internal database or storage networks.

```
[ Client Browser ]
        │ HTTPS (Cloudflare ACME TLS)
        ▼
[ Traefik Proxy (:443) ]
        │ 1. ForwardAuth Gate: Authentik Embedded Outpost
        ▼
   ┌────────────────────────────────────────────────────────┐
   │                  traefik_network                       │
   │                                                        │
   │  ┌───────────────┐ ┌────────────────┐ ┌─────────────┐  │
   │  │   it-tools    │ │   omni-tools   │ │   drawio    │  │
   │  │ (read-only FS)│ │ (read-only FS) │ │ (tmpfs JVM) │  │
   │  └───────────────┘ └────────────────┘ └─────────────┘  │
   │  ┌───────────────┐                                     │
   │  │   bentopdf    │                                     │
   │  │ (WASM Client) │                                     │
   │  └───────────────┘                                     │
   └────────────────────────────────────────────────────────┘
```

---

## 🔐 Authentik Integration (Method 2: Traefik ForwardAuth)

Because these applications are purely static web frontends without built-in authentication systems, they are protected at the Traefik perimeter by the Authentik ForwardAuth middleware:

```yaml
labels:
  - "traefik.http.routers.<service>_https.middlewares=authentik@docker"
```

* **Authentik Provider Mode:** Proxy Provider (`Forward auth (single application)`).
* **Access Groups:** Bound to group `it-tools_users` or `web-tools_users`.
* **Zero-Leak Guarantee:** Unauthenticated requests are rejected at the edge before any static asset or WASM payload is loaded.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `FQDN` | Base domain name | `205hlab.com` |
| `TZ` | Container timezone | `UTC` |

*(This stack is completely stateless and requires zero database credentials or persistent storage volumes.)*

---

## 🚀 Deployment & Operations

1. **Initialize Environment**:
   ```bash
   cd compose/web-tools
   cp example.env .env
   nano .env # Set FQDN
   ```

2. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Verify Access**:
   Navigate to any tool:
   - `https://it-tools.205hlab.com` (developer utilities: base64, JWT, cron, regex)
   - `https://omni.205hlab.com` (multi-purpose utilities)
   - `https://draw.205hlab.com` (architecture & network diagramming)
   - `https://pdf.205hlab.com` (client-side PDF merge, split, compress, and rotate)

---

## 💾 Backup & Data Persistence

- **Stateless Infrastructure:** None of these services persist user data on disk. All documents and diagrams are created and saved directly to the user's local workstation or cloud storage (e.g. Draw.io export).
- **Disaster Recovery:** If the container or host dies, spinning up the compose file restores full functionality instantly.

---

## 🩺 Healthcheck & Monitoring

- **IT-Tools & Omni-Tools:** HTTP probe `wget --spider -q http://127.0.0.1:80/` evaluated every 30s.
- **Draw.io:** Probed every 30s via `curl -fsS http://127.0.0.1:8080/`.
- **BentoPDF:** Evaluated every 30s via `wget --spider -q http://127.0.0.1:8080/`.
