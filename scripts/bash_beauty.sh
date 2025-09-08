#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

log "Installing bash beauty (fzf/eza/bat/vivid/direnv/fonts + starship)…"
apt_install bash-completion fzf eza bat vivid direnv fonts-firacode fonts-powerline fonts-noto-color-emoji
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat; fi
if ! command -v starship >/dev/null 2>&1; then
  apt_install starship
  if ! command -v starship >/dev/null 2>&1; then
    curl -fsSL https://starship.rs/install.sh | sudo sh -s -- -y -b /usr/local/bin || warn "starship install failed."
  fi
fi

mkdir -p "$HOME/.config"
cat > "$HOME/.config/starship.toml" <<'TOML'
add_newline = true
command_timeout = 1200

format = """$all
$cmd_duration$character"""

[character]
success_symbol = "[➜](bold green) "
error_symbol  = "[➜](bold red) "

[username]
show_always = true
style_user = "bold blue"
style_root = "bold red"
format = "[$user]($style) "

[hostname]
disabled = false
ssh_only = false
format = "@ [$hostname](bold purple) "

[directory]
truncation_length = 3
truncate_to_repo = false
style = "bold cyan"

[git_branch]
symbol = " "
style = "bold yellow"

[git_status]
conflicted = "↯"
ahead = "⇡"
behind = "⇣"
staged = "+$count"
modified = "!$count"
untracked = "?$count"
stashed = "💾"
format = "([$all_status$ahead_behind]($style)) "

[cmd_duration]
min_time = 750
format = "took [$duration]($style) "

[time]
disabled = false
format = "[$time]($style) "
time_format = "%H:%M:%S"
style = "dimmed white"

[status]
disabled = false
format = "[$symbol$status]($style) "
map_symbol = true
style = "bold red"
TOML

BASHRC_FILE="$HOME/.bashrc"
sed -i '/# >>> CTF Bash bling >>>/,/# <<< CTF Bash bling <<</d' "$BASHRC_FILE" || true
cat >> "$BASHRC_FILE" <<'EOF'

# >>> CTF Bash bling >>> 
case $- in *i*) ;; *) return;; esac
[ -f /etc/bash_completion ] && . /etc/bash_completion
for FZFRC in /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/doc/fzf/examples/completion.bash /usr/share/fzf/key-bindings.bash /usr/share/fzf/completion.bash; do [ -f "$FZFRC" ] && . "$FZFRC"; done
if command -v vivid >/dev/null 2>&1; then export LS_COLORS="$(vivid generate molokai)"; fi
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto --color=auto'
  alias ll='eza -alh --group-directories-first --icons=auto --git'
  alias la='eza -a --icons=auto'
  alias lt='eza -aT --level=2 --icons=auto'
else
  alias ls='ls --color=auto'; alias ll='ls -alF --color=auto'
fi
alias grep='grep --color=auto'
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never --style=plain'
alias ..='cd ..'; alias ...='cd ../..'
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
# <<< CTF Bash bling <<<
EOF
