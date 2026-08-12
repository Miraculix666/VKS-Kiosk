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

# ============================================================
# [0/4] Passwort festlegen
# ============================================================
echo "[0/4] Passwort fuer root und vksuser festlegen ..."
read -r -s -p "  Bitte Passwort eingeben (leer lassen fuer zufaelliges Passwort): " VKS_PASSWORD
echo ""

if [ -z "$VKS_PASSWORD" ]; then
    # Generate a random 16-character alphanumeric password
    VKS_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "  Kein Passwort eingegeben. Zufaelliges Passwort generiert: $VKS_PASSWORD"
    echo "  BITTE NOTIEREN! Es wird im Installations-Stick verwendet."
else
    echo "  Passwort gesetzt."
fi
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
sed -i "s/VKS_PASSWORD_PLACEHOLDER/$VKS_PASSWORD/g" preseed.cfg

# Escape special characters for sed
ESCAPED_ROOT_PW=$(printf '%s\n' "$ROOT_PW" | sed -e 's/[\/&]/\\&/g')
ESCAPED_USER_PW=$(printf '%s\n' "$USER_PW" | sed -e 's/[\/&]/\\&/g')

sed -i "s/ROOT_PASSWORD_PLACEHOLDER/$ESCAPED_ROOT_PW/g" ./preseed.cfg
sed -i "s/USER_PASSWORD_PLACEHOLDER/$ESCAPED_USER_PW/g" ./preseed.cfg

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
if [ -n "${OUTISO:-}" ]; then
    WINPATH="$(echo "$OUTISO" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|; s|/|\\|g')"
    echo "  Windows-Pfad: $WINPATH"
    echo ""
fi

select_and_flash_usb
cleanup_environment

echo ""
echo "Erfolgreich abgeschlossen."
