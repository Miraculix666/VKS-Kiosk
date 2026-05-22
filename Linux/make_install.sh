#!/bin/bash
# ============================================================
# VKS-Kiosk ISO Builder (Linux-Version)
# Baut die Debian-netinst.iso mit injizierten Kiosk-Skripten
# und schreibt sie optional auf einen USB-Stick.
# ============================================================

export PATH=$PATH:/usr/sbin:/usr/local/sbin
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "FEHLER: Dieses Skript muss als root ausgefuehrt werden (sudo ./make_install.sh)."
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
echo "  VKS-Kiosk ISO Builder (Linux-Version)"
echo "=========================================="
echo ""

install_dependencies
download_iso
build_iso
select_and_flash_usb

echo ""
echo "Erfolgreich abgeschlossen."
