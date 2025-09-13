#!/usr/bin/env bash
# scripts/install_one_gadget.sh
# Install one_gadget (Ruby gem) on Ubuntu 22.04/24.04
#
# Usage:
#   bash scripts/install_one_gadget.sh
#
# Env:
#   GEM_SCOPE="user"|"system"   # 설치 범위 (기본: user → sudo 불필요)
#   OG_VERSION="x.y.z"          # 특정 버전 고정 (기본: 최신)
#
# 설치 후 user 스코프일 때 PATH에 RubyGems user bin이 없으면 자동으로 추가(~/.bashrc, ~/.zshrc).

set -euo pipefail

GEM_SCOPE="${GEM_SCOPE:-user}"
OG_VERSION="${OG_VERSION:-}"

say()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

ensure_ruby() {
  if need ruby && need gem; then
    return 0
  fi
  say "ruby / rubygems 설치 (apt)…"
  sudo apt-get update -y
  # ruby-full 안 되면 ruby 로 폴백
  if ! sudo apt-get install -y ruby-full build-essential; then
    warn "ruby-full 설치 실패, ruby 최소 패키지로 폴백"
    sudo apt-get install -y ruby build-essential
  fi
}

install_one_gadget() {
  local args=(install one_gadget --no-document)
  if [[ -n "$OG_VERSION" ]]; then
    args=(install one_gadget -v "$OG_VERSION" --no-document)
  fi

  if [[ "$GEM_SCOPE" == "system" ]]; then
    say "system 스코프로 one_gadget 설치 (sudo gem ${args[*]})"
    sudo gem "${args[@]}"
  else
    say "user 스코프로 one_gadget 설치 (gem ${args[*]} --user-install)"
    gem "${args[@]}" --user-install
  fi
}

ensure_user_bin_on_path() {
  # user 스코프일 때만 PATH 보정
  [[ "$GEM_SCOPE" == "user" ]] || return 0

  # Ruby가 생각하는 user gem 디렉터리 → bin 경로
  local user_dir user_bin
  user_dir="$(ruby -e 'require "rubygems"; print Gem.user_dir' 2>/dev/null || true)"
  user_bin="${user_dir%/}/bin"

  # 일부 Debian/Ubuntu는 ~/.local/share/gem 경로를 사용할 수 있으니 보조 후보도 확인
  local fallback_bin="$HOME/.local/share/gem/ruby/$(ruby -e 'print RUBY_VERSION.split(".")[0,2].join(".")' 2>/dev/null || echo "3.0")/bin"

  # 실제 존재하는 bin 경로 선택
  local bin_to_add=""
  if [[ -d "$user_bin" ]]; then
    bin_to_add="$user_bin"
  elif [[ -d "$fallback_bin" ]]; then
    bin_to_add="$fallback_bin"
  fi

  # PATH에 없으면 bash/zsh에 스니펫 추가
  if [[ -n "$bin_to_add" ]] && ! grep -qF "$bin_to_add" <<<":$PATH:"; then
    say "PATH에 RubyGems user bin 추가: $bin_to_add"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      [[ -f "$rc" ]] || continue
      if ! grep -q "RubyGems user bin (one_gadget)" "$rc" 2>/dev/null; then
        {
          echo ''
          echo '# >>> RubyGems user bin (one_gadget) >>>'
          echo "export PATH=\"$bin_to_add:\$PATH\""
          echo '# <<< RubyGems user bin (one_gadget) <<<'
        } >> "$rc"
      fi
    done
    # 현재 세션에는 즉시 반영
    export PATH="$bin_to_add:$PATH"
  fi
}

verify_install() {
  if command -v one_gadget >/dev/null 2>&1; then
    say "설치 완료: $(one_gadget --version 2>/dev/null || echo one_gadget)"
    say "예) one_gadget /lib/x86_64-linux-gnu/libc.so.6"
  else
    warn "one_gadget 명령을 찾지 못했습니다. 새 셸을 열거나 PATH 설정을 확인하세요."
    warn "현재 PATH: $PATH"
  fi
}

main() {
  say "one_gadget 설치 시작 (GEM_SCOPE=${GEM_SCOPE}, OG_VERSION=${OG_VERSION:-latest})"
  ensure_ruby
  install_one_gadget
  ensure_user_bin_on_path
  verify_install
}

main "$@"

