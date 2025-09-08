#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/scripts/common.sh"

KVER="${1:-6.6.36}"
log "Setting up kernel debugging helpers in ~/ctf-kernel (KVER=$KVER)…"
KDIR="$HOME/ctf-kernel"; mkdir -p "$KDIR"/{src,build,images,cloudinit}

cat > "$KDIR/fetch_kernel.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
KVER="${KVER:-6.6.36}"
WD="$(cd "$(dirname "$0")" && pwd)"
SRCDIR="${WD}/src"; mkdir -p "$SRCDIR"; cd "$SRCDIR"
TAR="linux-${KVER}.tar.xz"; URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${TAR}"
[ -f "$TAR" ] || wget -O "$TAR" "$URL"
[ -d "linux-${KVER}" ] || tar -xf "$TAR"
echo "[+] Source ready at: ${SRCDIR}/linux-${KVER}"
EOF
chmod +x "$KDIR/fetch_kernel.sh"

cat > "$KDIR/config_debug_kernel.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
KVER="${KVER:-6.6.36}"
WD="$(cd "$(dirname "$0")" && pwd)"
SRCDIR="${WD}/src/linux-${KVER}"; cd "$SRCDIR"
make defconfig
S=./scripts/config
$S --enable DEBUG_KERNEL
$S --enable GDB_SCRIPTS
$S --enable FRAME_POINTER
$S --enable KALLSYMS_ALL
$S --enable KPROBES
$S --enable KGDB
$S --enable KGDB_SERIAL_CONSOLE
$S --enable MAGIC_SYSRQ
$S --enable IKCONFIG
$S --enable IKCONFIG_PROC
$S --enable DEBUG_INFO
$S --enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
$S --enable DEBUG_INFO_COMPRESSED_ZLIB
echo "[+] Base debug config applied."
EOF
chmod +x "$KDIR/config_debug_kernel.sh"

cat > "$KDIR/build_kernel.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
KVER="${KVER:-6.6.36}"
WD="$(cd "$(dirname "$0")" && pwd)"
SRCDIR="${WD}/src/linux-${KVER}"; BUILDDIR="${WD}/build/${KVER}"
mkdir -p "$BUILDDIR"; cd "$SRCDIR"
make -j"$(nproc)"
cp -v arch/x86/boot/bzImage "${BUILDDIR}/bzImage"
cp -v vmlinux "${BUILDDIR}/vmlinux"
echo "[+] Built bzImage/vmlinux at: ${BUILDDIR}"
EOF
chmod +x "$KDIR/build_kernel.sh"

cat > "$KDIR/fetch_ubuntu_cloudimg.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
WD="$(cd "$(dirname "$0")" && pwd)"
IMAGEDIR="${WD}/images"; mkdir -p "$IMAGEDIR"; cd "$IMAGEDIR"
BASE="jammy-server-cloudimg-amd64.img"
[ -f "$BASE" ] || wget -O "$BASE" "https://cloud-images.ubuntu.com/jammy/current/${BASE}"
[ -f "work.qcow2" ] || qemu-img create -f qcow2 -b "$BASE" -F qcow2 work.qcow2 20G
echo "[+] Cloud image ready: ${IMAGEDIR}/work.qcow2"
EOF
chmod +x "$KDIR/fetch_ubuntu_cloudimg.sh"

cat > "$KDIR/make_cloudinit_seed.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
WD="$(cd "$(dirname "$0")" && pwd)"
CIDIR="${WD}/cloudinit"; mkdir -p "$CIDIR"
cat > "${CIDIR}/user-data" <<'UD'
#cloud-config
users:
  - name: ctf
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$ctf$WSiGTr.2VwO6L8qH0T3WlP8b2qXkYk8mC1B5XGq1xg1g9mVn8g9n0  # "ctf"
ssh_pwauth: true
chpasswd: { expire: False }
package_update: true
packages: [openssh-server]
UD
cat > "${CIDIR}/meta-data" <<'MD'
instance-id: iid-local01
local-hostname: qemu-jammy
MD
genisoimage -output "${CIDIR}/seed.iso" -volid cidata -joliet -rock "${CIDIR}/user-data" "${CIDIR}/meta-data" >/dev/null 2>&1 || mkisofs -output "${CIDIR}/seed.iso" -volid cidata -joliet -rock "${CIDIR}/user-data" "${CIDIR}/meta-data"
echo "[+] Seed ISO: ${CIDIR}/seed.iso"
EOF
chmod +x "$KDIR/make_cloudinit_seed.sh"

cat > "$KDIR/run_qemu_kernel.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
KVER="${KVER:-6.6.36}"
WD="$(cd "$(dirname "$0")" && pwd)"
BUILDDIR="${WD}/build/${KVER}"; IMAGEDIR="${WD}/images"; CIDIR="${WD}/cloudinit"
BZ="${BUILDDIR}/bzImage"; [[ -f "$BZ" ]] || { echo "[-] Build kernel first."; exit 1; }
DISK="${IMAGEDIR}/work.qcow2"; SEED="${CIDIR}/seed.iso"
[[ -f "$DISK" ]] || { echo "[-] Run fetch_ubuntu_cloudimg.sh first."; exit 1; }
[[ -f "$SEED" ]] || { echo "[-] Run make_cloudinit_seed.sh first."; exit 1; }
qemu-system-x86_64 -m 4096 -smp 2 -cpu qemu64 -kernel "${BZ}" \
  -drive file="${DISK}",if=virtio -cdrom "${SEED}" \
  -net nic -net user,hostfwd=tcp::2222-:22 \
  -append "root=/dev/vda console=ttyS0 nokaslr" -nographic -s -S
EOF
chmod +x "$KDIR/run_qemu_kernel.sh"

cat > "$KDIR/gdb_kernel_attach.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
KVER="${KVER:-6.6.36}"
WD="$(cd "$(dirname "$0")" && pwd)"
V="${WD}/build/${KVER}/vmlinux"
S="${WD}/src/linux-${KVER}/scripts/gdb/vmlinux-gdb.py"
[[ -f "$V" ]] || { echo "[-] vmlinux not found: ${V}"; exit 1; }
[[ -f "$S" ]] || { echo "[-] gdb script not found: ${S}"; exit 1; }
cat > "${WD}/.gdbinit-kernel" <<GDB
set disassemble-next-line on
set pagination off
add-auto-load-safe-path ${S}
file ${V}
source ${S}
target remote :1234
GDB
gdb -q -x "${WD}/.gdbinit-kernel"
EOF
chmod +x "$KDIR/gdb_kernel_attach.sh"
