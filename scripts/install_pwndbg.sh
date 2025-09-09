#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing pwndbg…"
PWNDBG_DIR="$HOME/.pwndbg"
if [[ -d "$PWNDBG_DIR" ]]; then
  (cd "$PWNDBG_DIR" && git pull && ./setup.sh) | tee -a "${LOGFILE:-/tmp/ctf_setup.log}"
else
  git clone https://github.com/pwndbg/pwndbg.git "$PWNDBG_DIR"
  (cd "$PWNDBG_DIR" && ./setup.sh) | tee -a "${LOGFILE:-/tmp/ctf_setup.log}"
fi
