# Wyoming Voice AI — Local Jarvis Assist Pipeline (Whisper, Piper & openWakeWord)

[![Wyoming Whisper](https://img.shields.io/badge/Wyoming-Whisper%20STT-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/rhasspy/wyoming-faster-whisper)
[![Wyoming Piper](https://img.shields.io/badge/Wyoming-Piper%20TTS-18BCF2?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/rhasspy/wyoming-piper)
[![Wyoming openWakeWord](https://img.shields.io/badge/Wyoming-openWakeWord-0288D1?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/rhasspy/wyoming-openwakeword)
[![Home Assistant](https://img.shields.io/badge/Integration-Wyoming%20Protocol-03A9F4?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/integrations/wyoming/)

> **Endpoints:** `${MNGT_IP}:10300` (Whisper STT) · `${MNGT_IP}:10200` (Piper Jarvis TTS) · `${MNGT_IP}:10400` (openWakeWord `hey_jarvis`)<br/>
> **Exposure:** Management VLAN (`MNGT_VLAN`) TCP only *(No household LAN, Traefik ingress, or WAN exposure)*<br/>
> **Category:** Smart Home Voice AI<br/>
> **Related Docs:** [**ADR-005**](../../docs/adr/ADR-005-decouple-smart-home-haos-appliance.md), [**ADR-004**](../../docs/adr/ADR-004-dockhand-gitops-continuous-deployment.md), and [**Compose Master Catalog**](../README.md)

This stack deploys a complete local voice assistant pipeline on the primary `205hlab` Ubuntu Server: Speech-to-Text (**`wyoming-whisper`**), a custom British-English **Jarvis** Text-to-Speech voice (**`wyoming-piper`** using [`jgkawell/jarvis`](https://huggingface.co/jgkawell/jarvis)), and wake-word detection (**`wyoming-openwakeword`** preloaded with `hey_jarvis`). Per [**ADR-005**](../../docs/adr/ADR-005-decouple-smart-home-haos-appliance.md), it offloads CPU-intensive Assist inference from the low-power ASUS X540SA Home Assistant OS appliance onto the primary server's Ivy Bridge CPU with AVX support.

---

## 🏗️ Overview & Architecture

```text
[ Home Assistant OS (ASUS X540SA) ]
         │
         │  Wyoming Protocol (Raw TCP, no Traefik / TLS)
         ▼
[ OpenWrt Router / VLAN Firewall (Xiaomi AX6S) ]
         │
         ├──► TCP :10400 ──► [ wyoming-openwakeword ] (hey_jarvis preloaded)
         │                         └── /data ◄──► wyoming-openwakeword-data (/srv SSD)
         │
         ├──► TCP :10300 ──► [ wyoming-whisper ]      (base-int8 · en · beam-size 1)
         │                         └── /data ◄──► wyoming-whisper-data (/srv SSD)
         │
         └──► TCP :10200 ──► [ wyoming-piper ]        (jarvis-medium · length-scale 1.08)
                                   └── /data ◄──► ${PIPER_DATA_DIR} (/srv/wyoming/piper)
```

- **Wake Word (`wyoming-openwakeword`):** Preloads `hey_jarvis` over TCP `:10400` so wake-word detection triggers immediately without cold-load delay.
- **Low-Latency STT (`wyoming-whisper`):** Configured with `--model base-int8`, `--language en`, and `--beam-size 1` for fast INT8 CPU inference on Ivy Bridge AVX instructions (swap `WHISPER_MODEL` to `tiny-int8` if even lower latency is preferred).
- **Custom Jarvis TTS (`wyoming-piper`):** Uses the `jarvis-medium` ONNX model from [`jgkawell/jarvis`](https://huggingface.co/jgkawell/jarvis) with `--length-scale 1.08` for a slightly calmer, natural cadence and sub-second CPU synthesis.
- **Microsegmentation:** All three containers attach strictly to the stack-internal `wyoming_network` bridge (never `traefik_network` or `postgres_network`), enforce `no-new-privileges:true`, and cap CPU/memory via `deploy.resources.limits`.

---

## ⚙️ Environment Configuration

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `TZ` | Container timezone | `UTC` |
| `MNGT_IP` | Primary server Management VLAN (`MNGT_VLAN`) IPv4 address reachable by HAOS | *(Required; injected via Dockhand or `.env`)* |
| `WYOMING_WHISPER_PORT` | Host TCP port mapped to Whisper (`:10300`) | `10300` |
| `WHISPER_MODEL` | Faster-Whisper model identifier (`base-int8` or `tiny-int8`) | `base-int8` |
| `WHISPER_LANGUAGE` | Forced ISO language code for STT | `en` |
| `WHISPER_BEAM_SIZE` | Beam search width (`1` for lowest latency) | `1` |
| `WYOMING_PIPER_PORT` | Host TCP port mapped to Piper (`:10200`) | `10200` |
| `PIPER_DATA_DIR` | Host directory bound to Piper `/data` holding custom `.onnx` files | `/srv/wyoming/piper` |
| `PIPER_VOICE` | Piper TTS voice model identifier | `jarvis-medium` |
| `PIPER_LENGTH_SCALE` | Speech pacing multiplier (`> 1.0` slows cadence slightly) | `1.08` |
| `WYOMING_OPENWAKEWORD_PORT` | Host TCP port mapped to openWakeWord (`:10400`) | `10400` |
| `OPENWAKEWORD_PRELOAD_MODEL` | Wake-word model preloaded into memory at startup | `hey_jarvis` |

---

## 🎙️ Custom Jarvis Voice Model Setup (Required Before First Start)

Because `jarvis-medium` is a custom community model rather than a built-in Piper catalog voice, download both `jarvis-medium.onnx` and its matching `jarvis-medium.onnx.json` directly into `${PIPER_DATA_DIR}` (`/srv/wyoming/piper`) on `205hlab-AIO` **before** starting `wyoming-piper`:

```bash
sudo mkdir -p /srv/wyoming/piper
sudo curl -fSL -o /srv/wyoming/piper/jarvis-medium.onnx \
  https://huggingface.co/jgkawell/jarvis/resolve/main/en/en_GB/jarvis/medium/jarvis-medium.onnx
sudo curl -fSL -o /srv/wyoming/piper/jarvis-medium.onnx.json \
  https://huggingface.co/jgkawell/jarvis/resolve/main/en/en_GB/jarvis/medium/jarvis-medium.onnx.json
```

Verify both files exist and are valid binaries/JSON rather than HTML error pages (`~60 MB` for `.onnx` and `~7 KB` for `.onnx.json`):

```bash
ls -lh /srv/wyoming/piper
```

> [!TIP]
> Once `jarvis-medium` is running cleanly, you can optionally test `jarvis-high` from [`jgkawell/jarvis`](https://huggingface.co/jgkawell/jarvis) for slightly cleaner vocal detail at a modest CPU latency increase by downloading `jarvis-high.onnx` + `jarvis-high.onnx.json` into `/srv/wyoming/piper` and setting `PIPER_VOICE=jarvis-high`.

---

## 🛡️ Network Exposure & Firewall Rules

Wyoming communicates over raw TCP rather than HTTP, so **no Traefik router labels or Cloudflare DNS records** are configured. All three ports bind explicitly to `${MNGT_IP}` (`MNGT_VLAN`) rather than `0.0.0.0` or the general household `LAN_IP`.

1. **OpenWrt Inter-VLAN Firewall (Xiaomi AX6S):**
   - Ensure an OpenWrt Traffic Rule (`Network -> Firewall -> Traffic Rules`) permits TCP traffic strictly from `<HAOS_IP>/32` to `${MNGT_IP}` on destination ports `10300` (Whisper), `10200` (Piper), and `10400` (openWakeWord).
   - Keep all three ports blocked from WAN ingress and unintended LAN/IoT clients.
2. **Ubuntu Host Firewall (`UFW` / `iptables` `DOCKER-USER`):**
   - Because Docker publishes mapped ports in the `DOCKER` netfilter chain (bypassing standard UFW `INPUT` rules), verify that any host `DOCKER-USER` or UFW rules allow TCP `10300`, `10200`, and `10400` from `<HAOS_IP>/32` to `${MNGT_IP}`.

---

## 🏠 Home Assistant Integration (Wyoming Protocol)

Connect (or reload) all three endpoints in Home Assistant (**Settings → Devices & Services → Wyoming Protocol**):

| Service | Role | Host | Port |
| :--- | :--- | :--- | :--- |
| **`wyoming-whisper`** | Speech-to-Text (STT) | `<MNGT_IP>` *(server `${MNGT_IP}`)* | `10300` |
| **`wyoming-piper`** | Text-to-Speech (Jarvis TTS) | `<MNGT_IP>` *(server `${MNGT_IP}`)* | `10200` |
| **`wyoming-openwakeword`** | Wake Word (`hey_jarvis`) | `<MNGT_IP>` *(server `${MNGT_IP}`)* | `10400` |

1. **Add or Reload Integrations:**
   - If not yet added, click **Add Integration → Wyoming Protocol** for each service (`<MNGT_IP>:10300`, `<MNGT_IP>:10200`, and `<MNGT_IP>:10400`).
   - If `piper` or `openWakeWord` were already registered, open **Settings → Devices & Services → Wyoming Protocol**, click the three-dots menu (`⋮`) next to **`piper`** and select **Reload**, then repeat **Reload** for **`openWakeWord`**. Confirm neither shows an error banner or "Failed setup".
2. **Configure the Assist Pipeline:**
   - Open **Settings → Voice assistants → Hybrid Assistant** (or your active Assist pipeline).
   - Under **Text-to-speech**, set **Language** to **`en_GB`**, pick **`jarvis (medium)`** under **Voice**, and click **Try voice** to verify sub-second Jarvis playback.
   - Under **Wake word**, select **`openWakeWord`**, choose **`hey jarvis`**, and click **Update**.

---

## 🚀 Deployment & Operations

> [!TIP]
> **Production GitOps CI/CD via Dockhand:**
> In daily operations, this stack is deployed via **Dockhand** on the primary Ubuntu Server ([**ADR-004**](../../docs/adr/ADR-004-dockhand-gitops-continuous-deployment.md)). Configure `MNGT_IP` and `PIPER_DATA_DIR` in Dockhand's stack environment vault so no plaintext `.env` file sits on disk.

### Manual CLI Fallback

```bash
cd compose/wyoming
cp example.env .env
nano .env # Set MNGT_IP (and verify PIPER_DATA_DIR=/srv/wyoming/piper)
docker compose up -d
```

---

## 💾 Data Persistence

- **Piper Custom Voice Models (`${PIPER_DATA_DIR}`):** Bind-mounted from `/srv/wyoming/piper` on the 480 GB `/srv` App SSD so manually downloaded custom models (`jarvis-medium.onnx` and `jarvis-medium.onnx.json`) persist cleanly outside container lifecycles.
- **Whisper & openWakeWord Volumes:** Stored in named volumes `wyoming-whisper-data` (`/data`) and `wyoming-openwakeword-data` (`/data`) on `/srv` so downloaded STT and wake-word models survive container recreations.
- **Optional `BinPool` Storage:** If you later switch to larger multi-gigabyte Whisper models (e.g., `medium` or `large-v3`), replace `wyoming_whisper_data` with a bind mount under `/BinPool/...`.

---

## 🩺 Healthcheck & Verification

- **Container Healthchecks:** All three containers run native Python TCP socket probes against `127.0.0.1:10300`, `127.0.0.1:10200`, and `127.0.0.1:10400` every `30s`.
- **CLI Verification:**
  ```bash
  docker compose ps
  docker logs --tail 50 wyoming-piper         # Confirm no VoiceNotFoundError and listening on tcp://0.0.0.0:10200
  docker logs --tail 50 wyoming-whisper
  docker logs --tail 50 wyoming-openwakeword
  nc -zv <MNGT_IP> 10300
  nc -zv <MNGT_IP> 10200
  nc -zv <MNGT_IP> 10400
  ```
