#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Setting up wordlists…"
WORDLIST_DIR="$HOME/wordlists"; mkdir -p "$WORDLIST_DIR"; pushd "$WORDLIST_DIR" >/dev/null
[[ -f rockyou.txt.gz ]] || wget -qO rockyou.txt.gz https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt.gz || warn "rockyou download failed."
[[ -d SecLists ]] || git clone --depth=1 https://github.com/danielmiessler/SecLists.git SecLists || warn "SecLists clone failed."
[[ -f directory-list-2.3-medium.txt ]] || wget -qO directory-list-2.3-medium.txt https://raw.githubusercontent.com/daviddias/node-dirbuster/master/lists/directory-list-2.3-medium.txt || warn "Dirbuster list failed."
[[ -d fuzzdb ]] || git clone --depth=1 https://github.com/fuzzdb-project/fuzzdb.git fuzzdb || warn "fuzzdb clone failed."
[[ -f common-usernames.txt ]] || wget -qO common-usernames.txt https://raw.githubusercontent.com/insidetrust/statistically-likely-usernames/master/js/resources/Names.txt || warn "usernames list failed."
[[ -f subdomains-top1million-110000.txt ]] || wget -qO subdomains-top1million-110000.txt https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-110000.txt || warn "subdomains list failed."
popd >/dev/null
