# 🖼️ Static Assets & Icons

This directory stores version-controlled static assets (application icons, logos, dashboard widgets, and branding images) used across **Authentik** and homelab dashboards without needing a dedicated container or file server.

---

## 📁 Directory Structure

```text
assets/
├── icons/       # Application icons & service logos (SVG / PNG)
├── images/      # Background wallpapers, banners & branding photos
└── README.md    # URL reference & usage guide
```

---

## 🔗 Direct URL Formats

Once files are committed and pushed to the `main` branch of this repository, you can reference them directly anywhere using either **GitHub Raw** or the accelerated **jsDelivr CDN**.

### 1. jsDelivr CDN (Recommended)
Fast, globally distributed, cached CDN with proper image MIME headers:

```text
https://cdn.jsdelivr.net/gh/Dr20Ervin/205hlab@main/assets/icons/<filename>
https://cdn.jsdelivr.net/gh/Dr20Ervin/205hlab@main/assets/images/<filename>
```

*Example:*
```text
https://cdn.jsdelivr.net/gh/Dr20Ervin/205hlab@main/assets/icons/bentopdf.png
```

### 2. GitHub Raw
Direct link from GitHub's raw storage servers:

```text
https://raw.githubusercontent.com/Dr20Ervin/205hlab/main/assets/icons/<filename>
https://raw.githubusercontent.com/Dr20Ervin/205hlab/main/assets/images/<filename>
```

*Example:*
```text
https://raw.githubusercontent.com/Dr20Ervin/205hlab/main/assets/icons/bentopdf.png
```

---

## 🛠️ Usage in Authentik

To set a custom icon for any application in Authentik:
1. Navigate to **Authentik Admin Interface** → **Applications** → **Applications**.
2. Select your application and click **Edit**.
3. In the **Icon** field, paste either the jsDelivr CDN or GitHub Raw link (e.g. `https://cdn.jsdelivr.net/gh/Dr20Ervin/205hlab@main/assets/icons/bentopdf.png`).
4. Click **Update**.

---

## 📊 Usage in Dashboards (Homepage, Dashy, Homarr, etc.)

Paste the direct CDN URL into your dashboard's YAML configuration or widget settings:

### Homepage (`services.yaml` example)
```yaml
- Tools:
    - BentoPDF:
        icon: https://cdn.jsdelivr.net/gh/Dr20Ervin/205hlab@main/assets/icons/bentopdf.png
        href: https://pdf.205hlab.com/
        description: Client-side WASM PDF manipulation
```

### Dashy (`conf.yml` example)
```yaml
sections:
  - name: Utilities
    items:
      - title: BentoPDF
        icon: https://cdn.jsdelivr.net/gh/Dr20Ervin/205hlab@main/assets/icons/bentopdf.png
        url: https://pdf.205hlab.com/
```

---

## 📐 Recommended Image Guidelines

- **Format**: SVG (vector, sharp at all resolutions) or PNG with transparent background.
- **Resolution**: 256×256 or 512×512 square ratio for raster images.
- **Naming**: Use lowercase kebab-case (e.g., `it-tools.png`, `bentopdf.svg`, `authentik-bg.jpg`).

---

## 🔍 Finding Missing Icons

If an icon for an application is not yet stored in [`assets/icons/`](icons/), you can find clean, high-quality homelab SVGs and PNGs here:
- **[Dashboard Icons](https://dashboardicons.com/)** (`https://dashboardicons.com/`) — Extensive open-source directory of icons for self-hosted apps, homelab services, and developer tools.
