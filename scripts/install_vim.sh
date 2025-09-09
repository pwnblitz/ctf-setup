#!/usr/bin/env bash
# scripts/setup_vim.sh
# Minimal Vim setup with vim-plug + lightweight, useful plugins.
# Usage: bash scripts/setup_vim.sh
# Env:
#   INSTALL_PLUGS=1   # run PlugInstall (default: 1)
#   CONFIGURE_NVIM=0  # also set up Neovim to mirror Vim config (default: 0)

set -euo pipefail

INSTALL_PLUGS="${INSTALL_PLUGS:-1}"
CONFIGURE_NVIM="${CONFIGURE_NVIM:-0}"

say()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }

# --- prerequisites notice (no apt installs to keep it lean) ---
command -v vim  >/dev/null 2>&1 || warn "vim 이 설치되어 있지 않습니다. (sudo apt-get install -y vim)"
command -v curl >/dev/null 2>&1 || warn "curl 이 필요합니다. (sudo apt-get install -y curl)"

# --- install vim-plug (Vim) ---
say "vim-plug 설치 (Vim)"
mkdir -p "$HOME/.vim/autoload" "$HOME/.vim/plugged"
if ! curl -fsSL -o "$HOME/.vim/autoload/plug.vim" \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
  warn "vim-plug 다운로드 실패 (계속 진행합니다)"
fi

# --- backup & write ~/.vimrc ---
say "~/.vimrc 생성(기존이 있으면 1회 백업 → ~/.vimrc.bak)"
if [ -f "$HOME/.vimrc" ] && [ ! -f "$HOME/.vimrc.bak" ]; then
  cp -f "$HOME/.vimrc" "$HOME/.vimrc.bak"
fi

cat > "$HOME/.vimrc" <<'VIMRC'
" ---------- Minimal, Fast, Useful ----------
set nocompatible
set encoding=utf-8
set number
set ruler
set cursorline
set wrap
set linebreak
set showmatch
set ignorecase smartcase
set incsearch hlsearch
set mouse=a
set hidden
set updatetime=300
set termguicolors
set clipboard+=unnamedplus

" Tabs/indent
set tabstop=4 shiftwidth=4 softtabstop=4 expandtab smartindent

" Navigation & UI
set scrolloff=3 sidescrolloff=5
set splitbelow splitright
set completeopt=menuone,noselect

" Better grep: use ripgrep if available
if executable('rg')
  set grepprg=rg\ --vimgrep\ --hidden\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

" Leader key & quick mappings
let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohlsearch<CR>

" ---------- Plugins ----------
call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-sensible'      " sane defaults
Plug 'tpope/vim-surround'      " surround text objects
Plug 'tpope/vim-commentary'    " gcc/gc comment toggles
Plug 'tpope/vim-fugitive'      " :Git
Plug 'tpope/vim-vinegar'       " better netrw (file explorer)
Plug 'airblade/vim-gitgutter'  " git signs (lightweight)
Plug 'vim-airline/vim-airline' " statusline
Plug 'vim-airline/vim-airline-themes'

" Optional syntax bundle (comment out if unnecessary)
Plug 'sheerun/vim-polyglot'

call plug#end()

" Airline minimal look
let g:airline_powerline_fonts = 1
let g:airline_theme = 'dark'

" netrw tweaks (used by vinegar)
let g:netrw_banner = 0
let g:netrw_browse_split = 4
let g:netrw_liststyle = 3

" Colors (fallback-safe)
syntax on
if has('termguicolors')
  set background=dark
endif
VIMRC

# --- optional: Neovim mirror config ---
if [ "${CONFIGURE_NVIM}" = "1" ]; then
  say "Neovim 설정 동기화 (~/.config/nvim/init.vim)"
  mkdir -p "$HOME/.config/nvim" "$HOME/.local/share/nvim/site/autoload"
  if [ ! -f "$HOME/.config/nvim/init.vim" ]; then
    printf 'set runtimepath^=~/.vim runtimepath+=~/.vim/after\nlet &packpath=&runtimepath\nsource ~/.vimrc\n' > "$HOME/.config/nvim/init.vim"
  fi
  if ! curl -fsSL -o "$HOME/.local/share/nvim/site/autoload/plug.vim" \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
    warn "nvim용 vim-plug 다운로드 실패 (계속 진행합니다)"
  fi
fi

# --- install plugins (non-interactive) ---
if [ "${INSTALL_PLUGS}" = "1" ] && command -v vim >/dev/null 2>&1; then
  say "플러그인 설치 (vim-plug)"
  # Use a minimal, non-interactive run; ignore failures to keep script lean
  vim +'silent! PlugInstall --sync' +qa || warn "플러그인 설치 중 일부 실패"
else
  warn "플러그인 설치 건너뜀 (INSTALL_PLUGS=${INSTALL_PLUGS})"
fi

say "완료!  새 터미널에서 vim 실행해 보세요."

