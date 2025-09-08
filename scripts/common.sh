#!/usr/bin/env bash
set -euo pipefail

log()  { echo -e "\033[1;32m[+] $*\033[0m" | tee -a "${LOGFILE:-/tmp/ctf_setup.log}"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m" | tee -a "${LOGFILE:-/tmp/ctf_setup.log}"; }
err()  { echo -e "\033[1;31m[-] $*\033[0m" | tee -a "${LOGFILE:-/tmp/ctf_setup.log}"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

read_pkgs_from_files() {
  local out=() f line tok
  for f in "$@"; do
    [[ -r "$f" ]] || { warn "package list not readable: $f"; continue; }
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"; line="$(echo "$line" | xargs -r)"; [[ -z "$line" ]] && continue
      for tok in $line; do out+=("$tok"); done
    done < "$f"
  done
  printf '%s\n' "${out[@]}"
}

apt_install() {
  local ok=() fail=()

  for p in "$@"; do
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >>"${LOGFILE:-/tmp/ctf_setup.log}" 2>&1; then
      ok+=("$p")
    else
      warn "APT failed for: $p"
      fail+=("$p")
    fi
  done

  if (( ${#ok[@]} )); then
    log "APT installed/kept: ${ok[*]}"
  fi
  if (( ${#fail[@]} )); then
    warn "APT missing/not installed: ${fail[*]}"
  fi

  sudo apt clean

  return 0   # <-- set -e로 스크립트가 죽지 않도록 항상 0으로 종료
}

install_flatpak_if_needed() {
  if ! need_cmd flatpak; then
    apt_install flatpak
  fi
  if ! flatpak remotes | grep -q '^flathub'; then
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
}
