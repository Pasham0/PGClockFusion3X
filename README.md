<div align="center">
  <img src="Preview.png" alt="PGClock Fusion 3X Preview" width="900">
</div>

<h1 align="center">PGClock Fusion 3X</h1>

<p align="center">
  Fusion template for <b>3x-ui</b> (Sanaei panel) — three-tab dashboard with live clock, traffic breakdown and custom branding
</p>

<p align="center">
  <a href="#quick-install">Quick Install</a> ·
  <a href="#manual-install">Manual Install</a> ·
  <a href="#brand-customization">Brand Customization</a> ·
  <a href="#panel-settings">Panel Settings</a> ·
  <a href="#other-versions">Other Versions</a>
</p>

---

## Features

- Three tabs: **Account** · **Servers** · **Apps**
- Live Jalali / Gregorian clock and date (calendar auto-detected from panel `Calendar Type` setting)
- **Days remaining** and **Data remaining** rings with status colour
- **Traffic breakdown** card: upload, download and remaining share
- Detail cards: last connection, online status, subscription ID, client email
- Copy and QR for every config + circular SVG country flags (renders correctly on Windows too)
- One-click copy for **subscription / JSON / Clash** links
- Direct-import buttons for v2rayNG, Hiddify, Streisand, Shadowrocket, Happ, FlClash, sing-box and more
- Live status refresh every 30 seconds via `?format=info` (silently disabled on older panels)
- **FA / EN** with automatic RTL/LTR and **dark / light** theme
- Custom brand name, subtitle, logo and support link (install script compatible)
- Automatic performance-lite mode on low-end devices
- Single HTML file — no Node.js, no build step

> **Requirement:** 3x-ui **v3.3.0** or later. Custom subscription page template support was added in that release.

---

## Quick Install

On the server running 3x-ui:

```bash
curl -fsSL https://raw.githubusercontent.com/Pasham0/PGClockFusion3X/main/install.sh -o /tmp/pgclock3x-install.sh && sudo bash /tmp/pgclock3x-install.sh
```

or:

```bash
wget -qO /tmp/pgclock3x-install.sh https://raw.githubusercontent.com/Pasham0/PGClockFusion3X/main/install.sh && sudo bash /tmp/pgclock3x-install.sh
```

The installer asks whether you want to customise the brand; press Enter to keep the defaults.

### What the script does

1. Checks that 3x-ui is installed, locates the panel database, and warns if the panel version is older than v3.3.0
2. (Optional) Prompts for brand name, subtitle, support link and logo URL and patches `index.html` automatically
3. Saves the template to:

```text
/etc/x-ui/sub_templates/pgclock-fusion/index.html
```

4. (With your confirmation) Backs up `x-ui.db`, writes the template path into the `subThemeDir` setting, then runs `x-ui restart`.  
   If you answer no, it just prints the path so you can enter it in the panel yourself.

> **Requirements:** `wget`, `curl`, `python3`

---

## Manual Install

### 1. Download the template

```bash
sudo mkdir -p /etc/x-ui/sub_templates/pgclock-fusion/
sudo wget -N -O /etc/x-ui/sub_templates/pgclock-fusion/index.html \
  https://raw.githubusercontent.com/Pasham0/PGClockFusion3X/main/index.html
sudo chmod 755 /etc/x-ui/sub_templates /etc/x-ui/sub_templates/pgclock-fusion
sudo chmod 644 /etc/x-ui/sub_templates/pgclock-fusion/index.html
```

### 2. Configure the panel

Panel → **Settings → Subscription → Sub Theme Directory**, enter:

```text
/etc/x-ui/sub_templates/pgclock-fusion/
```

### 3. Restart

```bash
sudo x-ui restart
```

### 4. Preview

Open your subscription link in a browser:

```text
https://your-domain:2096/sub/SUB_ID?html=1
```

Browsers automatically request the HTML version; `?html=1` is just for safety. Client apps still receive the plain-text subscription — nothing changes for them.

---

## Brand Customization

The install script handles this automatically. For manual edits, find this object near the top of `index.html`:

```javascript
var DEFAULT_BRAND = {
  name: "PGClock Fusion",
  subtitle: { fa: "پنل اشتراک", en: "Subscription panel" },
  logoUrl: "",
  supportUrl: ""
};
```

- `name` — brand name shown in the header
- `subtitle.fa` / `subtitle.en` — subtitle for each language
- `logoUrl` — `https://` URL of the logo; leave empty for the default icon
- `supportUrl` — support link; the panel's own `subSupportUrl` takes precedence if set

**Template contract (keep these keys stable):** the install script looks for `DEFAULT_BRAND` with the fields `name`, `subtitle`, `logoUrl` and `supportUrl`.

### App list

3x-ui has no built-in app list, so the app catalogue is defined inside the template itself (the `APPS` array at the top of the script). The following placeholders are substituted in `import_url` values:

| Placeholder | Value |
|---|---|
| `{sub}` | Subscription link (`subUrl`) |
| `{clash}` | Clash link (`subClashUrl`) |
| `{json}` | JSON link (`subJsonUrl`) |

---

## Panel Settings

- **Settings → Subscription → Sub Theme Directory** — template path
- **Settings → Subscription → Sub Title / Support URL** — name and support link shown on the page
- **Settings → Subscription → Announce** — announcement text at the top of the page
- **Settings → Calendar Type** — choose `jalali` or `gregorian` (the page default language is read from this)

If the template causes an error, the panel silently falls back to its default page and logs the error:

```bash
x-ui log | grep -i "sub:"
```

---

## Other Versions

- [PGClock Fusion](https://github.com/Salarlotfi1381/PGClockFusion) — same template for **Pasarguard** panel
- [PGClock Lite](https://github.com/Mrclocks/PGClockLite) — lighter and faster
- [PGClock](https://github.com/Mrclocks/PGClock) — standard version
- [PGClock Pro](https://github.com/Mrclocks/PGClockPRO) — custom brand, subtitle and logo

---

## Changelog

### v1.1.0

- **Desktop CSS cleanup**: leftover bar-chart rules (`.bars`, `.bar-wrap`, `.bar b`) removed from the `@media (min-width: 860px)` block and replaced with `.split { min-height: 230px }` — the 3x-ui variant has no bar chart so those rules were dead code

### v1.0.0

- Initial release for 3x-ui: page data read from the panel's Go html/template (`sId`, `enabled`, `isOnline`, `upload/download/total/used/remained`, `expire`, `lastOnline`, `links`, `emails`, `announce`, `datepicker` and subscription links)
- Traffic breakdown card instead of daily usage chart (3x-ui has no time-series data)
- App catalogue with direct-import subscription support
- Compatible with v3.3.0 and later; keys absent in older panel versions are silently ignored

---

## Other Languages

- [فارسی](README.fa.md)
