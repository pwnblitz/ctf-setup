#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing VS Code (APT → Flatpak → Snap fallback)…"

# 1) APT(공식 저장소)
set +e
sudo install -d -m 0755 /etc/apt/keyrings
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
 | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
sudo chmod go+r /etc/apt/keyrings/packages.microsoft.gpg
echo 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' \
 | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
sudo apt-get update -y
if sudo apt-get install -y code; then
  log "VS Code installed via APT."
  exit 0
fi

# 2) Flatpak
install_flatpak_if_needed
if sudo flatpak install -y flathub com.visualstudio.code; then
  if ! command -v code >/dev/null 2>&1; then
    sudo tee /usr/local/bin/code >/dev/null <<'WRAP'
#!/usr/bin/env bash
exec flatpak run com.visualstudio.code "$@"
WRAP
    sudo chmod +x /usr/local/bin/code
  fi
  log "VS Code installed via Flathub."
  exit 0
fi

# 3) Snap
if apt_install snapd && sudo snap install code --classic; then
  log "VS Code installed via Snap."
  exit 0
fi

warn "VS Code installation failed on all methods. Check network/proxy and retry."

