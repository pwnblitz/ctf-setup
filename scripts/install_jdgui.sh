#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing JD-GUI (flatpak → deb → jar)…"
install_flatpak_if_needed
if sudo flatpak install -y flathub io.github.java_decompiler.jd-gui; then
  if ! command -v jd-gui >/dev/null 2>&1; then
    sudo tee /usr/local/bin/jd-gui >/dev/null <<'WRAP'
#!/usr/bin/env bash
exec flatpak run io.github.java_decompiler.jd-gui "$@"
WRAP
    sudo chmod +x /usr/local/bin/jd-gui
  fi
  exit 0
fi

warn "Flathub failed; trying .deb…"
JD_DEB_URL="$(curl -fsSL https://api.github.com/repos/java-decompiler/jd-gui/releases/latest \
  | jq -r '.assets[] | select(.name | test("\.deb$")) | .browser_download_url' | head -n1 || true)"
if [[ -n "$JD_DEB_URL" ]]; then
  curl -fsSL -o /tmp/jd-gui.deb "$JD_DEB_URL" || warn "JD-GUI deb download failed."
  sudo apt-get install -y /tmp/jd-gui.deb || warn "JD-GUI deb install failed."
  exit 0
fi

warn "No .deb asset; falling back to .jar wrapper…"
sudo mkdir -p /opt/jd-gui
JD_JAR_URL="$(curl -fsSL https://api.github.com/repos/java-decompiler/jd-gui/releases/latest \
  | jq -r '.assets[] | select(.name | test("\.jar$")) | .browser_download_url' | head -n1 || true)"
if [[ -n "$JD_JAR_URL" ]]; then
  curl -fsSL -o /tmp/jd-gui.jar "$JD_JAR_URL" || warn "JD-GUI jar download failed."
  sudo mv /tmp/jd-gui.jar /opt/jd-gui/jd-gui.jar || true
  sudo tee /usr/local/bin/jd-gui >/dev/null <<'WRAP'
#!/usr/bin/env bash
exec java -jar /opt/jd-gui/jd-gui.jar "$@"
WRAP
  sudo chmod +x /usr/local/bin/jd-gui
else
  warn "Could not obtain JD-GUI jar."
fi
