#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

if command -v d2j-dex2jar >/dev/null 2>&1; then exit 0; fi
log "Installing dex2jar (release ZIP)…"
D2J_VER="${D2J_VER:-2.4}"
sudo mkdir -p /opt/dex2jar
curl -L -o /tmp/dex-tools.zip "https://sourceforge.net/projects/dex2jar/files/dex2jar-${D2J_VER}/dex-tools-v${D2J_VER}.zip/download" \
  || { warn "dex2jar download failed."; exit 0; }
sudo unzip -qo /tmp/dex-tools.zip -d /opt/dex2jar || true
sudo chmod -R a+rx /opt/dex2jar || true
for f in /opt/dex2jar/dex-tools*/d2j-*.sh; do
  [[ -f "$f" ]] && sudo ln -sf "$f" "/usr/local/bin/$(basename "$f" .sh)"
done
