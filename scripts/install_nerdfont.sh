#!/usr/bin/env bash
# scripts/install_nerdfont.sh
# Ubuntu Nerd Font 설치 + (옵션) GNOME Terminal 적용 + (옵션) WSL→Windows 설치
# 기본 폰트: FiraCode
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

# --- WSL 감지(강화) ---
is_wsl() {
  # 커널 문자열 + /mnt/c 존재 모두 확인
  if grep -qiE '(microsoft|wsl)' /proc/version /proc/sys/kernel/osrelease 2>/dev/null \
     && [ -d /mnt/c/Windows ]; then
    return 0
  fi
  return 1
}

# --- 다운로드 헬퍼 ---
DL() {
  local url="$1" out="$2"
  if need curl; then
    curl -LfsS "$url" -o "$out"
  elif need wget; then
    wget -q "$url" -O "$out"
  else
    warn "curl 또는 wget이 필요합니다."
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

# --- 리눅스에 Nerd Font 설치 ---
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

  say "압축 해제"
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

  say "설치 → $DEST"
  $SUDO cp -v "${files[@]}" "$DEST/" >/dev/null || true
  rm -rf "$tmpdir"
  return 0
}

for f in $FONTS; do
  install_font_linux "$f" || warn "$f 설치 중 일부 실패(계속)"
done

say "fc-cache 갱신…"
$SUDO fc-cache -fv >/dev/null || true

# --- GNOME Terminal 폰트 적용(옵션) ---
apply_gnome_terminal_font() {
  if ! need gsettings; then
    warn "gsettings 없음 → GNOME 적용 건너뜀"
    return 0
  fi

  local def uuid list schema
  def="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null || true)"
  # 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' 형태 추출
  uuid="$(printf '%s\n' "$def" | sed -E "s/^'([0-9a-f-]+)'$/\1/")"
  if [ -z "${uuid:-}" ] || [ "$uuid" = "@ms nothing" ]; then
    list="$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null || true)"
    uuid="$(printf '%s\n' "$list" | sed -E "s/.*'([0-9a-f-]+)'.*/\1/")"
  fi

  if [ -z "${uuid:-}" ]; then
    warn "GNOME Terminal 프로필 UUID를 찾지 못했습니다(수동 설정 요망)."
    return 0
  fi

  schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${uuid}/"
  say "GNOME Terminal 폰트 적용: ${GNOME_FONT_FAMILY} ${GNOME_FONT_SIZE}"
  gsettings set "$schema" use-system-font false || warn "use-system-font 설정 실패"
  gsettings set "$schema" font "${GNOME_FONT_FAMILY} ${GNOME_FONT_SIZE}" || warn "font 설정 실패"
}

[ "$APPLY_GNOME" = "1" ] && apply_gnome_terminal_font || say "GNOME 적용 건너뜀(APPLY_GNOME=0)"

# --- (WSL 전용) Windows에 Nerd Font 설치(옵션) ---
install_fonts_windows_from_wsl() {
  # 이중 안전판
  if ! is_wsl; then
    return 0
  fi
  if ! command -v powershell.exe >/dev/null 2>&1; then
    warn "powershell.exe 없음 → Windows 설치 건너뜀"
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
  say "Windows 쪽 Nerd Fonts 설치 시도(WSL) → $FONTS"
  # 실패해도 스크립트 중단되지 않도록 보호
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Windows\\Temp\\install-nerdfonts.ps1" -Fonts @($psfonts) || \
    warn "Windows 측 설치 실패(권한/네트워크 확인)"
}

# *** 여기서부터가 핵심 수정: WSL이 아닐 땐 아예 호출하지 않음 ***
if is_wsl && [ "$APPLY_WSL_WINDOWS" = "1" ]; then
  install_fonts_windows_from_wsl
else
  say "WSL 아님 또는 Windows 설치 비활성화(APPLY_WSL_WINDOWS=$APPLY_WSL_WINDOWS) → 건너뜀"
fi

say "완료!  터미널/에디터에서 '${GNOME_FONT_FAMILY}'(또는 Mono 변형)를 선택하세요."

