#!/usr/bin/env bash
# scripts/install_nerdfont.sh
# Ubuntu용 Nerd Font 설치 + (옵션) WSL에서 Windows에 설치 + (옵션) GNOME Terminal 폰트 자동 적용
# 기본 폰트: FiraCode Nerd Font
#
# Usage:
#   bash scripts/install_nerdfont.sh
#
# Env:
#   FONTS="FiraCode JetBrainsMono Hack"   # 설치할 폰트 ZIP 이름들(기본: FiraCode)
#   SCOPE="user" | "system"               # 리눅스 설치 범위(기본: user)
#   APPLY_GNOME=1|0                       # GNOME Terminal 폰트 자동 적용(기본: 1)
#   GNOME_FONT_FAMILY="FiraCode Nerd Font Mono"  # GNOME에 적용할 폰트명
#   GNOME_FONT_SIZE=12                    # GNOME 폰트 크기
#   APPLY_WSL_WINDOWS=1|0                 # WSL이면 Windows에 폰트 자동 설치 시도(기본: 1)

set -euo pipefail

FONTS="${FONTS:-FiraCode}"
SCOPE="${SCOPE:-user}"
APPLY_GNOME="${APPLY_GNOME:-1}"
GNOME_FONT_FAMILY="${GNOME_FONT_FAMILY:-FiraCode Nerd Font Mono}"
GNOME_FONT_SIZE="${GNOME_FONT_SIZE:-12}"
APPLY_WSL_WINDOWS="${APPLY_WSL_WINDOWS:-1}"

say()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null
}

DL() {
  local url="$1" out="$2"
  if need curl; then
    curl -LfsS "$url" -o "$out"
  elif need wget; then
    wget -q "$url" -O "$out"
  else
    warn "curl/wget이 필요합니다. 설치 후 다시 시도하세요."
    return 1
  fi
}

# --- 의존성 ---
if ! need unzip || ! need fc-cache; then
  say "의존성 설치(unzip, fontconfig)…"
  sudo apt-get update -y
  sudo apt-get install -y unzip fontconfig
fi

# --- 설치 경로 결정 ---
if [ "$SCOPE" = "system" ]; then
  DEST="/usr/local/share/fonts/NerdFonts"
  SUDO="sudo"
else
  DEST="$HOME/.local/share/fonts/NerdFonts"
  SUDO=""
fi
$SUDO mkdir -p "$DEST"

# --- 리눅스(Nerd Font) 설치 ---
install_font_linux() {
  local name="$1"
  local tmpdir zip url
  tmpdir="$(mktemp -d)"
  zip="$tmpdir/${name}.zip"
  url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"

  say "다운로드: $name"
  if ! DL "$url" "$zip"; then
    warn "$name: 다운로드 실패"
    rm -rf "$tmpdir"; return 1
  fi

  say "압축 해제: $zip"
  if ! unzip -oq "$zip" -d "$tmpdir/${name}"; then
    warn "$name: unzip 실패"
    rm -rf "$tmpdir"; return 1
  fi

  shopt -s nullglob
  local files=( "$tmpdir/${name}"/*.{ttf,otf} )
  if [ ${#files[@]} -eq 0 ]; then
    warn "$name: 글꼴 파일(.ttf/.otf) 없음"
    rm -rf "$tmpdir"; return 1
  fi

  say "설치 경로: $DEST"
  $SUDO cp -v "${files[@]}" "$DEST/" >/dev/null || true
  rm -rf "$tmpdir"
  return 0
}

for f in $FONTS; do
  install_font_linux "$f" || warn "$f 설치 중 문제 발생(계속 진행)"
done

say "fc-cache 갱신…"
$SUDO fc-cache -fv >/dev/null || true

# --- GNOME Terminal 자동 적용 (옵션) ---
apply_gnome_terminal_font() {
  # gsettings / D-Bus 세션 필요
  if ! need gsettings; then
    warn "gsettings가 없어 GNOME 적용을 건너뜁니다."
    return 0
  fi

  # 기본 프로필 UUID 읽기
  local def uuid list schema
  def="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null || true)"

  # 정상 값은 보통:  'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
  uuid="$(printf '%s\n' "$def" | sed -E "s/^'([0-9a-f-]+)'$/\1/")"

  # 비어있거나 @ms nothing이면 list에서 첫 번째를 가져온다
  if [ -z "${uuid:-}" ] || [ "$uuid" = "@ms nothing" ]; then
    list="$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null || true)"
    uuid="$(printf '%s\n' "$list" | sed -E "s/.*'([0-9a-f-]+)'.*/\1/")"
  fi

  if [ -z "${uuid:-}" ]; then
    warn "GNOME Terminal 프로필을 찾지 못했습니다. 수동으로 폰트를 선택하세요."
    return 0
  fi

  schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${uuid}/"
  say "GNOME Terminal 폰트 적용 → ${GNOME_FONT_FAMILY} ${GNOME_FONT_SIZE}"
  gsettings set "$schema" use-system-font false || warn "use-system-font 설정 실패"
  gsettings set "$schema" font "${GNOME_FONT_FAMILY} ${GNOME_FONT_SIZE}" || warn "font 설정 실패"
}

if [ "$APPLY_GNOME" = "1" ]; then
  apply_gnome_terminal_font
else
  say "GNOME Terminal 자동 적용을 건너뜁니다(APPLY_GNOME=0)."
fi

# --- WSL이면 Windows에 Nerd Font 설치 시도 (옵션) ---
install_fonts_windows_from_wsl() {
  if ! is_wsl; then
    return 0
  fi
  if ! command -v powershell.exe >/dev/null 2>&1; then
    warn "powershell.exe 를 찾지 못했습니다(WSL 환경 아님?). Windows 설치를 건너뜁니다."
    return 0
  fi

  local psfile="/mnt/c/Windows/Temp/install-nerdfonts.ps1"
  sudo mkdir -p /mnt/c/Windows/Temp || true

  cat | sudo tee "$psfile" >/dev/null <<'PS1'
Param(
  [string[]]$Fonts = @("FiraCode"),
  [switch]$Quiet
)
function Say([string]$m){ if(-not $Quiet){ Write-Host "[+] $m" -ForegroundColor Green } }
function Warn([string]$m){ if(-not $Quiet){ Write-Host "[!] $m" -ForegroundColor Yellow } }

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$fontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null
$tmp = Join-Path $env:TEMP "nerdfont-inst"

foreach($name in $Fonts){
  try{
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$name.zip"
    $zip = Join-Path $env:TEMP "$name.zip"
    Say "Download $name → $url"
    Invoke-WebRequest -Uri $url -OutFile $zip
    if(Test-Path $tmp){ Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp
    $files = Get-ChildItem $tmp -Recurse -Include *.ttf,*.otf
    if(-not $files){ Warn "$name: no font files"; continue }
    foreach($f in $files){
      Copy-Item $f.FullName -Destination $fontsDir -Force
      $fn = [System.IO.Path]::GetFileName($f.FullName)
      $disp = ($fn -replace '\.(ttf|otf)$','') + " (TrueType)"
      New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
        -Name $disp -PropertyType String -Value (Join-Path $fontsDir $fn) -Force | Out-Null
    }
  } catch {
    Warn "Failed: $name ($($_.Exception.Message))"
  }
}
Say "Done. 터미널/VS Code에서 Nerd Font로 폰트를 선택하세요."
PS1

  local psfonts
  psfonts="$(printf '%s' "$FONTS" | tr ' ' ',')"
  say "Windows 쪽 Nerd Fonts 설치 시도(WSL)… → $FONTS"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Windows\\Temp\\install-nerdfonts.ps1" -Fonts @($psfonts) || {
    warn "Windows 측 설치 중 문제가 발생했습니다. Windows에서 수동 설치를 권장합니다."
  }
}

if [ "$APPLY_WSL_WINDOWS" = "1" ]; then
  install_fonts_windows_from_wsl
else
  say "Windows 측 자동 설치를 건너뜁니다(APPLY_WSL_WINDOWS=0)."
fi

say "완료!  터미널/에디터에서 폰트를 '${GNOME_FONT_FAMILY}'(또는 Mono 변형)로 선택하세요."

