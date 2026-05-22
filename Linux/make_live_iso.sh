#!/bin/bash
# ============================================================
# VKS-Kiosk Live-Build ISO Creator
# ============================================================
# Dieses Skript nutzt Debian live-build (lb), um ein echtes,
# natives Live-ISO mit injizierter VKS-Kiosk Logik zu erstellen.
# Dies beantwortet den Bedarf nach einem echten "Live-System"
# ohne Umwege ueber Netinst oder QEMU.
# ============================================================

export PATH=$PATH:/usr/sbin:/usr/local/sbin
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "FEHLER: Dieses Skript muss als root ausgefuehrt werden (sudo ./make_live_iso.sh)."
  exit 1
fi

CURRDIR="$(pwd)"
WORKDIR="${CURRDIR}/live_workdir"

echo "=========================================="
echo " [1/3] Abhaengigkeiten fuer Live-Build"
echo "=========================================="
apt-get update -qq || true
apt-get install -y live-build debootstrap || true
echo "  -> OK"

echo ""
echo "=========================================="
echo " [2/3] Konfiguriere Live-Umgebung"
echo "=========================================="
rm -Rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Grundkonfiguration (Debian Bookworm, amd64)
lb config \
    --distribution bookworm \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --linux-packages "linux-image" \
    --bootappend-live "boot=live components quiet splash" \
    --iso-application "VKS Kiosk Live" \
    --iso-volume "VKS-KIOSK" \
    --image-name "vks-kiosk-live"

# Hinzufuegen der benoetigten Pakete
mkdir -p config/package-lists
cat << 'PACKAGES' > config/package-lists/vks.list.chroot
xfce4
net-tools
xdotool
lldpd
snmpd
curl
gnupg
ca-certificates
nftables
isc-dhcp-client
rsync
python3
python3-tk
sudo
PACKAGES

# Injizieren des Payload-Skripts als First-Boot-Service im Live-System
mkdir -p config/includes.chroot/scripts
mkdir -p config/includes.chroot/etc/systemd/system

# Neuestes make_vks Skript suchen
DAT="$(ls -ct "${CURRDIR}"/make_vks*.sh 2>/dev/null | head -n 1 || true)"
if [ -n "$DAT" ]; then
    cp "$DAT" config/includes.chroot/scripts/make_vks.sh
    chmod +x config/includes.chroot/scripts/make_vks.sh
fi

if [ -f "${CURRDIR}/overlay.py" ]; then
    cp "${CURRDIR}/overlay.py" config/includes.chroot/scripts/
fi

cat << 'SERVICE' > config/includes.chroot/etc/systemd/system/firstboot.service
[Unit]
Description=VKS Kiosk Live Firstboot Setup
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /scripts/make_vks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

# Service im Live-System aktivieren
mkdir -p config/hooks/live
cat << 'HOOK' > config/hooks/live/0100-enable-services.hook.chroot
#!/bin/sh
systemctl enable firstboot.service
HOOK
chmod +x config/hooks/live/0100-enable-services.hook.chroot

echo "  -> Konfiguration abgeschlossen."
echo ""

echo "=========================================="
echo " [3/3] Erstelle Live-ISO (dies kann dauern!)"
echo "=========================================="
lb build

if [ -f "live-image-amd64.hybrid.iso" ]; then
    mv live-image-amd64.hybrid.iso "${CURRDIR}/vks-kiosk-true-live.iso"
    echo "=========================================="
    echo "  Live-ISO erfolgreich erstellt!"
    echo "  Pfad: ${CURRDIR}/vks-kiosk-true-live.iso"
    echo "=========================================="
else
    echo "FEHLER: ISO konnte nicht generiert werden."
    exit 1
fi
