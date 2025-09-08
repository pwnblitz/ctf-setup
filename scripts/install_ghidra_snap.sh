#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

if ! command -v snap >/dev/null 2>&1; then
  warn "snapd not found; installing…"; apt_install snapd
fi
log "Installing Ghidra (snap)…"
sudo snap install ghidra --classic || warn "Ghidra snap install failed."
