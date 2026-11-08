# Security Policy

## Supported Versions

This repository reflects my personal production homelab infrastructure at a point-in-time snapshot. Configuration files are updated on a rolling basis as services are upgraded or hardened. Only the latest commit on the `main` branch is actively maintained.

| Branch / Tag | Supported |
| :--- | :--- |
| `main` (latest) | ✅ Actively maintained |
| Tagged releases | ⚠️ Snapshot only — not patched retroactively |

## Reporting a Vulnerability

If you discover a security issue in this repository — such as a misconfiguration that exposes sensitive data, a hardening gap, an insecure default, or a secret accidentally committed — **please do not open a public GitHub issue.**

### How to Report

Send a private email to:

> **dr20ervin@outlook.com**

Please include:

- A clear description of the vulnerability or concern.
- The specific file(s) and line number(s) involved.
- The potential impact (what could an attacker do with this?).
- Steps to reproduce or verify the issue, if applicable.

### What to Expect

- I will acknowledge receipt of your report within **72 hours**.
- If the issue is valid, I will work to remediate it promptly and push a fix to `main`.
- I will credit you in the commit message / release notes if you wish (or keep it anonymous).

## Scope

This policy covers the contents of this repository only — Docker Compose configurations, environment file templates, Grafana dashboards, and documentation. It does **not** cover:

- The live production infrastructure itself (not publicly accessible by design).
- Third-party upstream images or software (please report those to the respective projects).
- Cloudflare, AirVPN, or other vendor services.

## General Security Notes

For an overview of the security measures applied across this homelab, see the [Security Posture section of the README](README.md#-security-posture).

---

*© 2026 Vajda Ervin-Oliver — MIT License*
