#!/usr/bin/env bash
set -euo pipefail
sudo tee /usr/local/bin/ctf-help >/dev/null <<'EOF'
#!/usr/bin/env bash
set -e
echo "==================== CTF Quick Help ===================="
echo "[Python env]  source ~/ctfenv/bin/activate"
echo "[pwndbg]      gdb ./vuln   (start, break *0x..., ni/si, x/20gx \$rsp)"
echo "[ROP]         ROPgadget --binary ./a.out | head"
echo "[radare2]     r2 -A ./bin ; afl ; pdf @ main"
echo "[Cutter]      cutter (AppImage wrapper)"
echo "[Ghidra]      ghidra"
echo "[Burp]        burpsuite"
echo "[Android]     apktool d app.apk ; jadx-gui app.apk ; d2j-dex2jar app.apk ; objection -g <pkg> explore ; mitmproxy"
echo "[Firmware]    binwalk -e fw.bin ; jefferson -d jffs2.img -o out ; ubireader_extract_images ubi.img ; unsquashfs fs.squashfs ; cramfsck -v image.cramfs"
echo "[Wordlists]   ~/wordlists (SecLists,fuzzdb,rockyou,...)"
echo "[Kernel]      ~/ctf-kernel (fetch/build/run/gdb scripts)"
echo "========================================================"
EOF
sudo chmod +x /usr/local/bin/ctf-help
