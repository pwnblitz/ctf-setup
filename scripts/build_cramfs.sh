#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

if command -v mkcramfs >/dev/null 2>&1 && command -v cramfsck >/dev/null 2>&1; then
  exit 0
fi
log "Building & installing cramfs tools from source…"
TMPDIR="$(mktemp -d)"
if git clone https://github.com/npitre/cramfs-tools.git "${TMPDIR}/cramfs-tools"; then
  make -C "${TMPDIR}/cramfs-tools" >>"${LOGFILE:-/tmp/ctf_setup.log}" 2>&1 || warn "cramfs-tools build failed."
  sudo install -m 0755 "${TMPDIR}/cramfs-tools/mkcramfs" /usr/local/bin/mkcramfs || true
  sudo install -m 0755 "${TMPDIR}/cramfs-tools/cramfsck" /usr/local/bin/cramfsck || true
else
  warn "cramfs-tools clone failed."
fi
