#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing JADX (release → flatpak)…"
if true; then
  sudo mkdir -p /opt/jadx
  JADX_URL="$(curl -fsSL https://api.github.com/repos/skylot/jadx/releases/latest \
    | jq -r '.assets[] | select(.name | test("\.zip$")) | .browser_download_url' | head -n1 || true)"
  if [[ -n "$JADX_URL" ]]; then
    curl -fsSL -o /tmp/jadx.zip "$JADX_URL" || warn "JADX download failed."
    sudo unzip -qo /tmp/jadx.zip -d /opt/jadx || true
    BIN_DIR="$(find /opt/jadx -maxdepth 2 -type d -name bin | head -n1 || true)"
    if [[ -n "$BIN_DIR" ]]; then
      sudo ln -sf "${BIN_DIR}/jadx"     /usr/local/bin/jadx
      sudo ln -sf "${BIN_DIR}/jadx-gui" /usr/local/bin/jadx-gui
      exit 0
    fi
  fi
fi
warn "Falling back to Flathub for JADX…"
install_flatpak_if_needed
sudo flatpak install -y flathub com.github.skylot.jadx || warn "Flathub jadx install failed."
if ! command -v jadx >/dev/null 2>&1; then
  sudo tee /usr/local/bin/jadx >/dev/null <<'WRAP'
#!/usr/bin/env bash
exec flatpak run com.github.skylot.jadx "$@"
WRAP
  sudo chmod +x /usr/local/bin/jadx
fi
if ! command -v jadx-gui >/dev/null 2>&1; then
  sudo tee /usr/local/bin/jadx-gui >/dev/null <<'WRAP'
#!/usr/bin/env bash
exec flatpak run com.github.skylot.jadx "$@"
WRAP
  sudo chmod +x /usr/local/bin/jadx-gui
fi
