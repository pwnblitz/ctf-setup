#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing Burp Suite Community… (flatpak-first)"
BURP_OK=0

if command -v flatpak >/dev/null 2>&1; then
  install_flatpak_if_needed
  if sudo flatpak install -y flathub net.portswigger.BurpSuite-Community; then
    BURP_OK=1
    if ! command -v burpsuite >/dev/null 2>&1; then
      sudo tee /usr/local/bin/burpsuite >/dev/null <<'WRAP'
#!/usr/bin/env bash
exec flatpak run net.portswigger.BurpSuite-Community "$@"
WRAP
      sudo chmod +x /usr/local/bin/burpsuite
    fi
    log "Burp (Flathub) installed. Try: burpsuite"
  else
    warn "Flathub install failed; falling back to official installer."
  fi
fi

if [[ "$BURP_OK" -eq 0 ]]; then
  log "Fetching official Burp Community installer page…"
  DL_PAGE="$(curl -fsSL https://portswigger.net/burp/communitydownload || true)"
  LINUX_URL="$(printf '%s' "$DL_PAGE" | grep -Eo 'https://[^"]+/burp/releases/download\?product=community[^"]*type=Linux[^"]*' | head -n1 || true)"
  if [[ -n "$LINUX_URL" ]]; then
    INSTALLER="/tmp/burpsuite-community-installer.sh"
    curl -fsSL -o "$INSTALLER" "$LINUX_URL" || { warn "Burp download failed."; exit 0; }
    chmod +x "$INSTALLER" || true
    if [[ -n "${DISPLAY:-}" ]]; then
      log "Launching GUI installer…"
      bash "$INSTALLER" || warn "GUI installer exited with error."
    else
      log "No DISPLAY; running console installer (with xvfb if available)…"
      if command -v xvfb-run >/dev/null 2>&1; then
        xvfb-run -a bash "$INSTALLER" -c >>"${LOGFILE:-/tmp/ctf_setup.log}" 2>&1 || warn "Console install failed."
      else
        bash "$INSTALLER" -c >>"${LOGFILE:-/tmp/ctf_setup.log}" 2>&1 || warn "Console install failed."
      fi
    fi
    if ! command -v burpsuite >/dev/null 2>&1; then
      for c in "$HOME"/BurpSuiteCommunity/BurpSuiteCommunity /opt/BurpSuiteCommunity/BurpSuiteCommunity; do
        [[ -x "$c" ]] && { sudo ln -sf "$c" /usr/local/bin/burpsuite; break; }
      done
    fi
  else
    warn "Could not parse Burp download URL; opening the official page…"
    command -v xdg-open >/dev/null 2>&1 && xdg-open "https://portswigger.net/burp/communitydownload" >/dev/null 2>&1 || true
    echo "[!] Please download the Linux installer manually from the opened page."
  fi
fi
