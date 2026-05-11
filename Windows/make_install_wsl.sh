#!/bin/bash
# ============================================================
# VKS-Kiosk ISO Builder (WSL-Version)
# Baut die Debian-netinst.iso mit injizierten Kiosk-Skripten
# und schreibt sie optional auf einen USB-Stick.
#
# Version 1.4 - wget fix, USB-Geraeteauswahl, ISO-Build
#               von USB-Write getrennt
# Ausfuehren als: sudo ./make_install_wsl.sh
# ============================================================

export PATH=$PATH:/usr/sbin:/usr/local/sbin

# Fehler sofort abbrechen, AUSSER bei explizit toleriertem Code
set -euo pipefail

echo ""
echo "=========================================="
echo "  VKS-Kiosk ISO Builder (WSL-Version)"
echo "=========================================="
echo ""

# ============================================================
# [1/4] Abhaengigkeiten installieren
# ============================================================
echo "[1/4] Abhaengigkeiten pruefen und installieren ..."
apt-get update -qq
# Kein Fehler wenn einzelne Pakete schon da sind
apt-get install -y syslinux syslinux-utils cpio coreutils usbutils xorriso p7zip-full wget 2>&1 | \
    grep -v "already the newest" | grep -v "^$" || true
echo "  OK"

# ============================================================
# [2/4] Debian netinst ISO herunterladen
# ============================================================
echo ""
echo "[2/4] Debian netinst ISO herunterladen ..."

CURRDIR="$(pwd)"
WORKDIR=/workdir
BASE_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"

ISO="$(wget -qO - "${BASE_URL}/SHA512SUMS" | grep netinst | grep -v mac | head -n 1 | awk '{print $2}')"

if [ -z "$ISO" ]; then
    echo "FEHLER: ISO-Dateiname konnte nicht ermittelt werden."
    echo "       Internetverbindung pruefen! (ping cdimage.debian.org)"
    exit 1
fi

VERSION="$(echo "$ISO" | cut -d'-' -f2)"
echo "  Aktuellste Version: Debian $VERSION"
echo "  Dateiname:          $ISO"

if [ -f "${CURRDIR}/${ISO}" ]; then
    echo "  ISO bereits vorhanden, ueberspringe Download."
else
    echo "  Lade herunter ..."
    wget --progress=dot:giga "${BASE_URL}/${ISO}" -O "${CURRDIR}/${ISO}"
fi

# ============================================================
# [3/4] ISO modifizieren und neu bauen
# ============================================================
echo ""
echo "[3/4] ISO entpacken, modifizieren und neu bauen ..."

# Payload-Skript finden (neuestes make_vks*)
DAT="$(ls -ct "${CURRDIR}"/make_vks*.sh 2>/dev/null | head -n 1 || true)"
if [ -z "$DAT" ]; then
    echo "FEHLER: Kein make_vks*.sh Skript im aktuellen Verzeichnis gefunden!"
    echo "       Verzeichnis: $CURRDIR"
    exit 1
fi
DAT="$(basename "$DAT")"
echo "  Payload-Skript: $DAT"

# Alle benoetigten Dateien pruefen
for f in preseed.cfg overlay.py grub.cfg "$DAT"; do
    if [ ! -f "${CURRDIR}/${f}" ]; then
        echo "FEHLER: Benoettigte Datei fehlt: ${CURRDIR}/${f}"
        exit 1
    fi
done

# Workdir sauber aufbauen
rm -Rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "  Entpacke ISO ..."
# 7z (p7zip-full) statt 7zip
if command -v 7z >/dev/null 2>&1; then
    7z x -o"${WORKDIR}" "${CURRDIR}/${ISO}" -y >/dev/null
elif command -v 7za >/dev/null 2>&1; then
    7za x -o"${WORKDIR}" "${CURRDIR}/${ISO}" -y >/dev/null
else
    echo "FEHLER: 7z / 7za nicht gefunden!"
    exit 1
fi

cd "$WORKDIR"

echo "  Injiziere Kiosk-Skripte ..."

# initrd patchen
gunzip install.amd/initrd.gz
cp "${CURRDIR}/preseed.cfg" .

# Sicherstellen dass ./install ein Verzeichnis ist (in manchen ISO-Versionen heisst es anders)
INSTALL_DIR=""
for d in install install.amd; do
    if [ -d "${WORKDIR}/${d}" ]; then
        INSTALL_DIR="${WORKDIR}/${d}"
        break
    fi
done
if [ -z "$INSTALL_DIR" ]; then
    echo "FEHLER: Kein install/ oder install.amd/ Verzeichnis in der ISO gefunden!"
    ls -la "$WORKDIR"
    exit 1
fi

cp "${CURRDIR}/overlay.py"  "${INSTALL_DIR}/"
cp "${CURRDIR}/${DAT}"      "${INSTALL_DIR}/make_vks.sh"
cp "${CURRDIR}/grub.cfg"    ./boot/grub/

echo preseed.cfg | cpio -o -H newc -A -F install.amd/initrd
rm -f preseed.cfg
gzip install.amd/initrd

echo "  Aktualisiere Pruefsummen ..."
find . -follow -type f -print0 | xargs --null md5sum > md5sum.txt

OUTISO="${CURRDIR}/vks-kiosk-debian-${VERSION}.iso"
echo "  Baue ISO zusammen ..."
xorriso -as mkisofs -o "$OUTISO" \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$WORKDIR" 2>&1 | grep -v "^xorriso : UPDATE" || true

echo ""
echo "=========================================="
echo "  ISO erfolgreich erstellt!"
echo "=========================================="
echo ""
echo "  Linux-Pfad:   $OUTISO"

# Windows-Pfad berechnen (WSL /mnt/c/... -> C:\...)
WINPATH="$(echo "$OUTISO" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|; s|/|\\|g')"
echo "  Windows-Pfad: $WINPATH"
echo ""

# ============================================================
# [4/4] Auf USB-Stick schreiben (optional)
# ============================================================
echo "[4/4] USB-Stick beschreiben (optional) ..."
echo ""

# Nur echte, beschreibbare Blockgeraete anzeigen (kein loop, rom, boot, ram)
DEVICES="$(lsblk -dpno NAME,SIZE,TRAN,MODEL 2>/dev/null | grep -vE 'loop|rom|boot|ram' | grep -v '^$' || true)"

if [ -z "$DEVICES" ]; then
    echo "  Keine beschreibbaren Blockgeraete gefunden."
    echo "  (USB-Stick via usbipd evtl. noch nicht durchgereicht?)"
    echo ""
    echo "  ISO manuell flashen:"
    echo "    dd if=$OUTISO of=/dev/sdX bs=4M status=progress && sync"
    exit 0
fi

echo "  Verfuegbare Geraete:"
echo "  -------------------------------------------"
i=1
declare -a DEV_ARRAY
while IFS= read -r line; do
    DEV_ARRAY[$i]="$(echo "$line" | awk '{print $1}')"
    printf "  [%d] %s\n" "$i" "$line"
    i=$((i + 1))
done <<< "$DEVICES"
echo "  [0] Abbrechen (nur ISO erstellen)"
echo "  -------------------------------------------"
echo ""
read -r -p "  Geraet auswaehlen [0-$((i-1))]: " DEVNUM

if [ "${DEVNUM:-0}" = "0" ] || [ -z "${DEVNUM:-}" ]; then
    echo ""
    echo "  Abbruch. ISO wurde erstellt, aber nicht auf Stick geschrieben."
    echo "  Manuell flashen:"
    echo "    dd if=$OUTISO of=/dev/sdX bs=4M status=progress && sync"
    exit 0
fi

SELECTED="${DEV_ARRAY[$DEVNUM]:-}"
if [ -z "$SELECTED" ]; then
    echo "  Ungueltige Auswahl!"
    exit 1
fi

# Groesse pruefen (max 128 GB als Sicherheit)
SIZE_BYTES="$(lsblk -bdno SIZE "$SELECTED" 2>/dev/null || echo 0)"
MAX_BYTES=$((128 * 1024 * 1024 * 1024))
if [ "$SIZE_BYTES" -gt "$MAX_BYTES" ]; then
    echo ""
    echo "FEHLER: Geraet $SELECTED ist groesser als 128 GB!"
    echo "       Sicherheitsabbruch - bitte richtiges Geraet auswaehlen."
    exit 1
fi

DEVINFO="$(lsblk -dpno NAME,SIZE,MODEL "$SELECTED" 2>/dev/null || echo "$SELECTED")"
echo ""
echo "  ##################################################################"
echo "  !!! OBACHT !!!"
echo "  Das Geraet: $DEVINFO"
echo "  wird UNWIDERRUFLICH und VOLLSTAENDIG geloescht!"
echo "  ##################################################################"
read -r -p "  Bist du sicher? (j/n): " CHOICE

if [ "${CHOICE}" = "j" ]; then
    echo ""
    echo "  Partitionstabelle neu erstellen ..."
    # sfdisk ist zuverlaessiger als fdisk im Skript-Betrieb
    echo 'label: gpt' | sfdisk "$SELECTED" --no-reread -q 2>/dev/null || \
    printf 'g\nn\n\n\n\nw\n' | fdisk "$SELECTED" >/dev/null 2>&1 || true

    echo "  ISO schreiben auf $SELECTED ..."
    dd if="$OUTISO" of="$SELECTED" bs=4M status=progress conv=fsync
    sync
    echo ""
    echo "=========================================="
    echo "  USB-Stick erfolgreich erstellt!"
    echo "=========================================="
else
    echo ""
    echo "  Abbruch. ISO manuell flashen:"
    echo "    dd if=$OUTISO of=$SELECTED bs=4M status=progress && sync"
fi
