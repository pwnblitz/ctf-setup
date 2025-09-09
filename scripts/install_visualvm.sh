#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

METHOD="${1:-official}"

if command -v visualvm >/dev/null 2>&1; then
  exit 0
fi

if [[ "$METHOD" == "official" ]]; then
  log "Installing VisualVM (official zip)…"
  sudo mkdir -p /opt/visualvm
  VV_URL="$(curl -fsSL https://visualvm.github.io/download.html \
    | grep -Eo 'https://github.com/[^"]+/releases/download/[0-9.]+/visualvm_[0-9]+\.zip' | head -n1 || true)"
  if [[ -n "$VV_URL" ]]; then
    curl -fsSL -o /tmp/visualvm.zip "$VV_URL" || warn "VisualVM zip download failed."
    sudo unzip -qo /tmp/visualvm.zip -d /opt || true
    if [[ -x /opt/visualvm/bin/visualvm ]]; then
      sudo ln -sf /opt/visualvm/bin/visualvm /usr/local/bin/visualvm
    else
      VV_BIN="$(find /opt -maxdepth 2 -type f -path '*/visualvm/bin/visualvm' | head -n1 || true)"
      [[ -x "$VV_BIN" ]] && sudo ln -sf "$VV_BIN" /usr/local/bin/visualvm
    fi
    exit 0
  else
    warn "Could not parse VisualVM URL; trying APT."
    METHOD="apt"
  fi
fi

if [[ "$METHOD" == "apt" ]]; then
  log "Installing VisualVM (APT)…"
  apt_install visualvm
fi
