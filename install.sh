#!/usr/bin/env bash
#
# PGClock Fusion 3X Installer for 3x-ui (Sanaei panel)
# https://github.com/Pasham0/PGClockFusion3X
#
set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly THEME_NAME="pgclock-fusion"
readonly TARGET_DIR="/etc/x-ui/sub_templates/${THEME_NAME}"
readonly TARGET_FILE="${TARGET_DIR}/index.html"
readonly INSTALLER_RAW="https://raw.githubusercontent.com/Pasham0/PGClockFusion3X/main/install.sh"
readonly URL_FUSION="https://raw.githubusercontent.com/Pasham0/PGClockFusion3X/main/index.html"
readonly MIN_PANEL_VERSION="3.3.0"

DB_FILE=""
PANEL_VERSION=""

# When run via "curl | bash", stdin is the pipe — re-download and re-run from a real file.
if [[ ! -t 0 ]] && [[ -z "${PGCLOCK_INSTALL_REEXEC:-}" ]]; then
  tmpfile="$(mktemp /tmp/pgclock3x-install-XXXXXX.sh)"
  cleanup() { rm -f "$tmpfile"; }
  trap cleanup EXIT
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$INSTALLER_RAW" -o "$tmpfile"
  else
    wget -qO "$tmpfile" "$INSTALLER_RAW"
  fi
  chmod 700 "$tmpfile"
  export PGCLOCK_INSTALL_REEXEC=1
  exec bash "$tmpfile" "$@"
fi

if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m'
  readonly C_BOLD='\033[1m'
  readonly C_DIM='\033[2m'
  readonly C_RED='\033[31m'
  readonly C_GREEN='\033[32m'
  readonly C_YELLOW='\033[33m'
  readonly C_BLUE='\033[34m'
  readonly C_CYAN='\033[36m'
  readonly C_WHITE='\033[97m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN='' C_WHITE=''
fi

log_line() { printf '%b\n' "$1"; }
log_blank() { printf '\n'; }

hr() {
  log_line "${C_CYAN}${C_BOLD}================================================================${C_RESET}"
}

read_tty() {
  local prompt=$1
  local __var=$2
  local input=""
  if [[ -r /dev/tty ]]; then
    IFS= read -r -p "$prompt" input </dev/tty || true
  else
    IFS= read -r -p "$prompt" input || true
  fi
  printf -v "$__var" '%s' "$input"
}

print_banner() {
  log_blank
  hr
  log_line "${C_WHITE}${C_BOLD}  PGClock Fusion 3X Installer for 3x-ui${C_RESET}"
  log_line "${C_DIM}  Version ${SCRIPT_VERSION}${C_RESET}"
  hr
  log_blank
}

ok()   { log_line "${C_GREEN}[OK]${C_RESET}  $*"; }
info() { log_line "${C_BLUE}[>>]${C_RESET}  $*"; }
warn() { log_line "${C_YELLOW}[!!]${C_RESET}  $*"; }
fail() { log_line "${C_RED}[ERR]${C_RESET} $*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1. Install it with: apt update && apt install -y $1"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "This script must run as root. Try again with sudo."
  fi
}

find_db() {
  local candidate
  for candidate in /etc/x-ui/x-ui.db /usr/local/x-ui/db/x-ui.db /usr/local/x-ui/x-ui.db; do
    if [[ -f "$candidate" ]]; then
      DB_FILE="$candidate"
      return 0
    fi
  done
  return 1
}

detect_version() {
  local raw=""
  if command -v x-ui >/dev/null 2>&1; then
    raw="$(x-ui -v 2>/dev/null || true)"
  fi
  if [[ -z "$raw" && -x /usr/local/x-ui/x-ui ]]; then
    raw="$(/usr/local/x-ui/x-ui -v 2>/dev/null || true)"
  fi
  PANEL_VERSION="$(printf '%s' "$raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
}

version_lt() {
  # version_lt A B -> true when A < B
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

check_system() {
  info "Checking prerequisites..."
  need_cmd wget
  need_cmd curl
  need_cmd python3
  need_cmd grep
  need_cmd sed
  need_cmd mktemp

  python3 -c 'import sqlite3' >/dev/null 2>&1 || warn "python3 has no sqlite3 module; the panel setting must be set by hand."

  if ! command -v x-ui >/dev/null 2>&1 && [[ ! -x /usr/local/x-ui/x-ui ]]; then
    warn "x-ui command not found. Is 3x-ui installed on this server?"
  fi

  if find_db; then
    ok "Panel database: ${DB_FILE}"
  else
    warn "x-ui.db not found. The template will still be installed, but you must set the theme path in the panel."
  fi

  detect_version
  if [[ -n "$PANEL_VERSION" ]]; then
    if version_lt "$PANEL_VERSION" "$MIN_PANEL_VERSION"; then
      warn "Panel version ${PANEL_VERSION} is older than ${MIN_PANEL_VERSION}; custom subscription themes are not supported there. Update 3x-ui first."
    else
      ok "Panel version ${PANEL_VERSION}"
    fi
  else
    warn "Could not detect the panel version. PGClock Fusion 3X needs 3x-ui ${MIN_PANEL_VERSION} or newer."
  fi

  ok "Prerequisites OK"
}

ensure_target_dir() {
  info "Creating theme directory..."
  mkdir -p "$TARGET_DIR"
  chmod 755 /etc/x-ui/sub_templates "$TARGET_DIR" 2>/dev/null || true
  ok "Directory ready: ${TARGET_DIR}"
}

validate_logo_url() {
  local url="$1"
  [[ -n "$url" ]] || return 0
  [[ "$url" =~ ^https?://[^[:space:]]+$ ]] || return 1
  curl -fsSIL --max-time 12 --retry 1 "$url" >/dev/null 2>&1
}

download_template() {
  local url="$1"
  local dest="$2"
  info "Downloading template from GitHub..."
  wget -N -O "$dest" "$url" || fail "Download failed. Check your internet connection and the URL."
  [[ -s "$dest" ]] || fail "Downloaded file is empty."
  chmod 644 "$dest"
  ok "index.html downloaded"
}

backup_existing() {
  local backup
  if [[ -f "$TARGET_FILE" ]]; then
    backup="${TARGET_FILE}.$(date +%Y%m%d-%H%M%S).bak"
    cp "$TARGET_FILE" "$backup"
    ok "Existing template backed up: ${backup}"
  fi
}

apply_brand() {
  local file="$1"

  info "Applying brand settings..."
  export BRAND_NAME="${BRAND_NAME:-}"
  export BRAND_SUBTITLE="${BRAND_SUBTITLE:-}"
  export BRAND_LOGO="${BRAND_LOGO:-}"
  export BRAND_SUPPORT="${BRAND_SUPPORT:-}"

  python3 - "$file" <<'PY' || return 1
import os
import re
import sys

path = sys.argv[1]
name = os.environ.get("BRAND_NAME", "").strip()
subtitle = os.environ.get("BRAND_SUBTITLE", "").strip()
logo = os.environ.get("BRAND_LOGO", "").strip()
support = os.environ.get("BRAND_SUPPORT", "").strip()

with open(path, "r", encoding="utf-8") as f:
    html = f.read()

original_len = len(html)

if original_len < 1000 or "</html>" not in html.lower():
    sys.stderr.write("Downloaded file does not look like a complete HTML template.\n")
    sys.exit(1)

BRAND_OBJECT_KEYS = ("DEFAULT_BRAND", "PANEL_DEFAULT_BRAND")
LOGO_KEYS = ("logoUrl", "logo", "logoURL", "logo_url")
SUPPORT_KEYS = ("supportUrl", "support_url", "support")

def js_quote(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "")
        .replace("\n", "\\n")
    )

def html_text(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def attr_quote(value: str) -> str:
    return value.replace("&", "&amp;").replace('"', "&quot;")

def extract_braced_object(text: str, open_index: int):
    depth = 0
    i = open_index
    in_str = None
    esc = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == in_str:
                in_str = None
        else:
            if ch in ('"', "'"):
                in_str = ch
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    while end < len(text) and text[end] in " \t\r\n":
                        end += 1
                    if end < len(text) and text[end] == ";":
                        end += 1
                    return open_index, end
        i += 1
    return None

def find_brand_object(text: str):
    for key in BRAND_OBJECT_KEYS:
        match = re.search(
            rf"(?:var|const|let)\s+{re.escape(key)}\s*=\s*(\{{)",
            text,
        )
        if not match:
            continue
        bounds = extract_braced_object(text, match.start(1))
        if bounds:
            return key, bounds
    return None, None

def replace_quoted_field(block: str, field: str, value: str):
    pattern = rf'({re.escape(field)}\s*:\s*")(?:[^"\\]|\\.)*(")'
    return re.subn(
        pattern,
        lambda m: m.group(1) + js_quote(value) + m.group(2),
        block,
        count=1,
    )

def patch_brand_object(block: str):
    updated = block

    if name:
        updated, count = replace_quoted_field(updated, "name", name)
        if count != 1:
            sys.stderr.write('Could not find brand field "name" in the template.\n')
            sys.exit(1)

    if subtitle:
        if re.search(r"subtitle\s*:\s*\{", updated):
            updated, fa_count = replace_quoted_field(updated, "fa", subtitle)
            updated, en_count = replace_quoted_field(updated, "en", subtitle)
            if fa_count != 1 or en_count != 1:
                sys.stderr.write('Could not find subtitle.fa / subtitle.en in the template.\n')
                sys.exit(1)
        else:
            updated, count = replace_quoted_field(updated, "subtitle", subtitle)
            if count != 1:
                sys.stderr.write('Could not find a subtitle field in the template.\n')
                sys.exit(1)

    if logo:
        for key in LOGO_KEYS:
            updated, count = replace_quoted_field(updated, key, logo)
            if count == 1:
                break
        else:
            sys.stderr.write('Could not find a logo URL field (logoUrl / logo) in the template.\n')
            sys.exit(1)

    if support:
        for key in SUPPORT_KEYS:
            updated, count = replace_quoted_field(updated, key, support)
            if count == 1:
                break
        else:
            sys.stderr.write('Could not find a support URL field (supportUrl) in the template.\n')
            sys.exit(1)

    return updated

def patch_html_fallback(text: str):
    if name:
        text, n = re.subn(
            rf'(<[^>]*\bid=["\']brand-title["\'][^>]*>)([^<]*)(</[^>]+>)',
            lambda m: m.group(1) + html_text(name) + m.group(3),
            text,
            count=1,
        )
        if n == 0:
            text, _ = re.subn(
                r"(<title>)([^<]*)(</title>)",
                lambda m: m.group(1) + html_text(name) + m.group(3),
                text,
                count=1,
            )

    if subtitle:
        text, _ = re.subn(
            rf'(<[^>]*\bid=["\']brand-subtitle["\'][^>]*>)([^<]*)(</[^>]+>)',
            lambda m: m.group(1) + html_text(subtitle) + m.group(3),
            text,
            count=1,
        )

    if logo:
        text, n = re.subn(
            rf'(<[^>]*\bid=["\']brand-img["\'][^>]*\ssrc=["\'])([^"\']*)(["\'])',
            lambda m: m.group(1) + attr_quote(logo) + m.group(3),
            text,
            count=1,
        )
        if n == 0:
            text, _ = re.subn(
                rf'(<[^>]*\bid=["\']brand-img["\'][^>]*)(>)',
                lambda m: m.group(1) + ' src="' + attr_quote(logo) + '"' + m.group(2),
                text,
                count=1,
            )

    return text

brand_key, bounds = find_brand_object(html)
if not brand_key:
    sys.stderr.write(
        "Brand config object not found. Expected one of: "
        + ", ".join(BRAND_OBJECT_KEYS)
        + "\n"
    )
    sys.exit(1)

start, end = bounds
block = html[start:end]
html = html[:start] + patch_brand_object(block) + html[end:]
html = patch_html_fallback(html)

if find_brand_object(html)[0] is None:
    sys.stderr.write("Brand config object missing after patch.\n")
    sys.exit(1)

if len(html) < original_len * 0.90:
    sys.stderr.write("Refusing to write: output looks truncated.\n")
    sys.exit(1)

with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(html)
PY

  ok "Brand settings applied to HTML"
}

manual_instructions() {
  log_blank
  log_line "${C_BOLD}Set the theme by hand:${C_RESET}"
  log_line "  Panel -> Settings -> Subscription -> Sub Theme Directory"
  log_line "  ${C_CYAN}${TARGET_DIR}/${C_RESET}"
  log_line "  Then save the settings and restart the panel: ${C_CYAN}x-ui restart${C_RESET}"
  log_blank
}

configure_theme_dir() {
  local answer backup

  if [[ -z "$DB_FILE" ]]; then
    warn "Panel database not found; skipping automatic configuration."
    manual_instructions
    return 0
  fi

  log_blank
  log_line "${C_BOLD}Point the panel at this theme automatically?${C_RESET}"
  log_line "${C_DIM}This writes subThemeDir into ${DB_FILE} (a backup is taken first).${C_RESET}"
  log_blank
  read_tty "$(printf '%b' "${C_BOLD}Configure now? [Y/n]: ${C_RESET}")" answer
  answer="${answer:-y}"

  case "${answer,,}" in
    y|yes) ;;
    *)
      info "Skipped automatic configuration."
      manual_instructions
      return 0
      ;;
  esac

  backup="${DB_FILE}.$(date +%Y%m%d-%H%M%S).bak"
  cp "$DB_FILE" "$backup"
  ok "Database backed up: ${backup}"

  if THEME_DIR="${TARGET_DIR}/" DB_PATH="$DB_FILE" python3 - <<'PY'
import os
import sqlite3
import sys

db = os.environ["DB_PATH"]
value = os.environ["THEME_DIR"]

con = sqlite3.connect(db)
try:
    cur = con.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='settings'")
    if not cur.fetchone():
        sys.stderr.write("No settings table in the database.\n")
        sys.exit(1)
    cur.execute("SELECT id FROM settings WHERE key = 'subThemeDir'")
    row = cur.fetchone()
    if row:
        cur.execute("UPDATE settings SET value = ? WHERE id = ?", (value, row[0]))
    else:
        cur.execute("INSERT INTO settings (key, value) VALUES ('subThemeDir', ?)", (value,))
    con.commit()
    cur.execute("SELECT value FROM settings WHERE key = 'subThemeDir'")
    stored = cur.fetchone()
    if not stored or stored[0] != value:
        sys.stderr.write("Verification failed after writing subThemeDir.\n")
        sys.exit(1)
finally:
    con.close()
PY
  then
    ok "subThemeDir set to ${TARGET_DIR}/"
  else
    warn "Could not write the setting. Your database is unchanged (backup: ${backup})."
    manual_instructions
    return 0
  fi

  restart_panel
}

restart_panel() {
  info "Restarting the panel..."
  if command -v x-ui >/dev/null 2>&1; then
    if x-ui restart; then
      ok "3x-ui restarted successfully"
    else
      warn "Automatic restart failed. Run manually: x-ui restart"
    fi
  elif systemctl list-unit-files 2>/dev/null | grep -q '^x-ui'; then
    systemctl restart x-ui && ok "x-ui service restarted" || warn "Run manually: systemctl restart x-ui"
  else
    warn "x-ui command not available. Restart the panel manually."
  fi
}

prompt_branding() {
  local answer brand_name brand_subtitle brand_logo brand_support

  log_blank
  log_line "${C_BOLD}Customize brand? (name, tagline, logo, support link)${C_RESET}"
  log_line "${C_DIM}Press Enter to keep the default PGClock Fusion branding.${C_RESET}"
  log_blank
  read_tty "$(printf '%b' "${C_BOLD}Customize now? [y/N]: ${C_RESET}")" answer
  answer="${answer:-n}"

  case "${answer,,}" in
    y|yes) ;;
    *)
      export BRAND_NAME="" BRAND_SUBTITLE="" BRAND_LOGO="" BRAND_SUPPORT=""
      return 0
      ;;
  esac

  log_blank
  log_line "${C_YELLOW}${C_BOLD}--- Brand Setup ---${C_RESET}"
  log_blank
  log_line "${C_DIM}Press Enter to skip any field and keep the default value${C_RESET}"
  log_blank

  read_tty "$(printf '%b' "${C_BOLD}Brand name${C_RESET} (e.g. MrClock): ")" brand_name
  brand_name="${brand_name:-}"

  read_tty "$(printf '%b' "${C_BOLD}Tagline / caption${C_RESET} (e.g. Subscription panel): ")" brand_subtitle
  brand_subtitle="${brand_subtitle:-}"

  read_tty "$(printf '%b' "${C_BOLD}Support link${C_RESET} (e.g. @your_id or https://t.me/your_id): ")" brand_support
  brand_support="${brand_support:-}"

  while true; do
    read_tty "$(printf '%b' "${C_BOLD}Logo URL${C_RESET} (https://...): ")" brand_logo
    brand_logo="${brand_logo:-}"
    if [[ -z "$brand_logo" ]]; then
      break
    fi
    if validate_logo_url "$brand_logo"; then
      ok "Logo URL is valid"
      break
    fi
    warn "Invalid or unreachable logo URL. Enter a full https:// URL, or press Enter to skip."
  done

  export BRAND_NAME="$brand_name"
  export BRAND_SUBTITLE="$brand_subtitle"
  export BRAND_LOGO="$brand_logo"
  export BRAND_SUPPORT="$brand_support"
}

install_fusion() {
  local backup

  info "Installing ${C_BOLD}PGClock Fusion 3X${C_RESET}..."
  prompt_branding
  backup_existing

  download_template "$URL_FUSION" "$TARGET_FILE"

  if [[ -n "${BRAND_NAME:-}" || -n "${BRAND_SUBTITLE:-}" || -n "${BRAND_LOGO:-}" || -n "${BRAND_SUPPORT:-}" ]]; then
    backup="${TARGET_FILE}.patch.bak"
    cp "$TARGET_FILE" "$backup"
    if ! apply_brand "$TARGET_FILE"; then
      mv "$backup" "$TARGET_FILE"
      fail "Branding failed. Restored the downloaded template."
    fi
    rm -f "$backup"
  fi
}

print_success_box() {
  log_blank
  hr
  log_line "${C_GREEN}${C_BOLD}  Installation complete${C_RESET}"
  log_blank
  log_line "  ${C_BOLD}Template:${C_RESET} PGClock Fusion 3X"
  log_line "  ${C_BOLD}Path:${C_RESET}     ${TARGET_FILE}"
  log_line "  ${C_BOLD}Setting:${C_RESET}  Settings -> Subscription -> Sub Theme Directory"
  log_blank
  log_line "  Open a subscription link in a browser to see the page:"
  log_line "  ${C_CYAN}https://your-domain:2096/sub/SUB_ID?html=1${C_RESET}"
  hr
  log_blank
}

main() {
  print_banner
  require_root
  check_system
  ensure_target_dir
  install_fusion
  configure_theme_dir
  print_success_box
}

main "$@"
