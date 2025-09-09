#!/usr/bin/env bash
set -euo pipefail

INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_NODE="${INSTALL_NODE:-0}"
INSTALL_GHIDRA="${INSTALL_GHIDRA:-0}"
INSTALL_BURP="${INSTALL_BURP:-1}"
INSTALL_CUTTER="${INSTALL_CUTTER:-0}"
INSTALL_JADX="${INSTALL_JADX:-0}"
INSTALL_JDGUI="${INSTALL_JDGUI:-0}"
INSTALL_VISUALVM="${INSTALL_VISUALVM:-0}"
INSTALL_DEX2JAR="${INSTALL_DEX2JAR:-0}"
INSTALL_BUILD_CRAMFS="${INSTALL_BUILD_CRAMFS:-0}"
INSTALL_BASH_BEAUTY="${INSTALL_BASH_BEAUTY:-1}"
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_KERNEL_TOOLKIT="${INSTALL_KERNEL_TOOLKIT:-0}"
INSTALL_VIM="${INSTALL_VIM:-1}"

VISUALVM_METHOD="${VISUALVM_METHOD:-official}"

PY_VENV_NAME="${PY_VENV_NAME:-ctfenv}"
KVER="${KVER:-6.6.36}"
LOGFILE="${HOME}/ctf_setup_20250908_013918.log"

APT_LIST_FILES="${APT_LIST_FILES:-"$(dirname "$0")/apt-packages.txt"}"
PIP_REQUIREMENTS="${PIP_REQUIREMENTS:-"$(dirname "$0")/pip-requirements.txt"}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Log file: $LOGFILE"

log "Preparing APT…"
sudo apt-get update -y | tee -a "$LOGFILE"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common | tee -a "$LOGFILE"
sudo add-apt-repository -y universe   | tee -a "$LOGFILE" || true
sudo add-apt-repository -y multiverse | tee -a "$LOGFILE" || true
sudo apt-get update -y | tee -a "$LOGFILE"

log "Installing APT packages from: $APT_LIST_FILES"
mapfile -t __APT_PKGS < <(read_pkgs_from_files $APT_LIST_FILES)
apt_install "${__APT_PKGS[@]}"

if getent group wireshark >/dev/null; then sudo usermod -aG wireshark "$USER" || true; fi

if ! command -v checksec >/dev/null 2>&1; then
  log "Installing checksec (fallback)…"
  sudo curl -fsSL -o /usr/local/bin/checksec https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec || true
  sudo chmod +x /usr/local/bin/checksec || true
fi

log "Creating Python virtualenv: $PY_VENV_NAME"
python3 -m venv "$HOME/$PY_VENV_NAME"
source "$HOME/$PY_VENV_NAME/bin/activate"
pip install --upgrade pip wheel setuptools
log "Installing Python libs from: $PIP_REQUIREMENTS"
pip install --upgrade -r "$PIP_REQUIREMENTS" | tee -a "$LOGFILE" || warn "Some Python packages failed."

if [[ "$INSTALL_NODE" == "1" ]]; then
  log "Installing Node.js/npm (repo) + apk-mitm"
  apt_install nodejs npm
  if command -v npm >/dev/null 2>&1; then
    sudo npm install -g apk-mitm || warn "apk-mitm install failed."
  fi
fi

bash "$ROOT_DIR/scripts/install_pwndbg.sh" || true
bash "$ROOT_DIR/scripts/wordlists.sh" || true
bash "$ROOT_DIR/scripts/ctf_help.sh" || true

[[ "$INSTALL_BURP" == "1" ]] && bash "$ROOT_DIR/scripts/install_burp.sh" || true
[[ "$INSTALL_GHIDRA" == "1" ]] && bash "$ROOT_DIR/scripts/install_ghidra_snap.sh" || true
[[ "$INSTALL_CUTTER" == "1" ]] && bash "$ROOT_DIR/scripts/install_cutter.sh" || true
[[ "$INSTALL_JADX" == "1" ]] && bash "$ROOT_DIR/scripts/install_jadx.sh" || true
[[ "$INSTALL_JDGUI" == "1" ]] && bash "$ROOT_DIR/scripts/install_jdgui.sh" || true
[[ "$INSTALL_VISUALVM" == "1" ]] && bash "$ROOT_DIR/scripts/install_visualvm.sh" "$VISUALVM_METHOD" || true
[[ "$INSTALL_DEX2JAR" == "1" ]] && bash "$ROOT_DIR/scripts/install_dex2jar.sh" || true
[[ "$INSTALL_BUILD_CRAMFS" == "1" ]] && bash "$ROOT_DIR/scripts/build_cramfs.sh" || true
[[ "$INSTALL_KERNEL_TOOLKIT" == "1" ]] && bash "$ROOT_DIR/scripts/kernel_toolkit.sh" "$KVER" || true
[[ "$INSTALL_BASH_BEAUTY" == "1" ]] && bash "$ROOT_DIR/scripts/bash_beauty.sh" || true
[[ "$INSTALL_VSCODE" == "1" ]] && bash "$ROOT_DIR/scripts/install_vscode.sh" || true
[[ "$INSTALL_VIM" == "1" ]] && bash "$ROOT_DIR/scripts/install_vim.sh" || true

if [[ "$INSTALL_DOCKER" == "1" ]]; then
  log "Installing Docker…"
  apt_install docker.io docker-compose-plugin
  sudo usermod -aG docker "$USER" || true
fi

BASHRC_FILE="$HOME/.bashrc"
VENV_ACTIVATE="$HOME/$PY_VENV_NAME/bin/activate"
if [[ -f "$VENV_ACTIVATE" ]]; then
  log "Adding venv auto-activation to $BASHRC_FILE"
  sed -i '/# >>> CTF Python venv >>>/,/# <<< CTF Python venv <<</d' "$BASHRC_FILE" || true
  cat >> "$BASHRC_FILE" <<EOF

# >>> CTF Python venv >>>
if [ -f "$VENV_ACTIVATE" ]; then
  . "$VENV_ACTIVATE"
fi
# <<< CTF Python venv <<<
EOF
fi

log "All done!  Try: ctf-help"
