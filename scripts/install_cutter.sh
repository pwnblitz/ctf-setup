#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing Cutter (AppImage)…"
CUTTER_DIR="$HOME/tools/cutter"; mkdir -p "$CUTTER_DIR"
if ! command -v cutter >/dev/null 2>&1; then
  CUTTER_URL="$(curl -fsSL https://api.github.com/repos/rizinorg/cutter/releases/latest \
    | jq -r '.assets[] | select(.name | test("AppImage$")) | .browser_download_url' | head -n1 || true)"
  if [[ -z "$CUTTER_URL" ]]:
    CUTTER_URL="$(curl -fsSL https://github.com/rizinorg/cutter/releases/latest \
      | grep -Eo 'https://github.com/rizinorg/cutter/releases/download/[^"]+AppImage' | head -n1 || true)"
  fi
  if [[ -n "$CUTTER_URL" ]]; then
    wget -O "$CUTTER_DIR/Cutter.AppImage" "$CUTTER_URL" || warn "Cutter download failed."
    chmod +x "$CUTTER_DIR/Cutter.AppImage" || true
    sudo ln -sf "$CUTTER_DIR/Cutter.AppImage" /usr/local/bin/cutter || true
  else
    warn "Could not determine Cutter AppImage URL."
  fi
fi
