#!/bin/bash
# ============================================================
# VKS-Kiosk ISO Builder (WSL-Version)
# Baut die Debian-netinst.iso mit injizierten Kiosk-Skripten
# und schreibt sie optional auf einen USB-Stick.
# ============================================================

export PATH=$PATH:/usr/sbin:/usr/local/sbin
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "FEHLER: Dieses Skript muss als root ausgefuehrt werden (sudo ./make_install_wsl.sh)."
  exit 1
fi

CURRDIR="$(pwd)"

# Source shared builder logic
if [ -f "../shared_build.sh" ]; then
    source ../shared_build.sh
elif [ -f "shared_build.sh" ]; then
    source shared_build.sh
else
    echo "FEHLER: shared_build.sh konnte nicht gefunden werden!"
    exit 1
fi

echo ""
echo "=========================================="
echo "  VKS-Kiosk ISO Builder (WSL-Version)"
echo "=========================================="
echo ""

install_dependencies
download_iso
build_iso

# Windows-Pfad berechnen (WSL /mnt/c/... -> C:\...)
if [ -n "${OUTISO:-}" ]; then
    WINPATH="$(echo "$OUTISO" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|; s|/|\\|g')"
    echo "  Windows-Pfad: $WINPATH"
    echo ""
fi

select_and_flash_usb

echo ""
echo "Erfolgreich abgeschlossen."
