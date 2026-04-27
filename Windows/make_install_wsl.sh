#!/bin/bash
export PATH=$PATH:/usr/sbin/
############################################################################################################################
#                                                                                                                          #
#                                           		VKS-Futro Script                                                       #
#                                                      16.04.2026                                                          #
#                                                                                                                          #
#          Ersteller: Markus Hertes                                                                                        #
#                                  				                                                                           #
#          Version 1.0 - macht was es soll                                                                                 #
#		   Version 1.1 - Script und Grub inject																			   #
#		   Version 1.2 - M$-Sklavenversion mit WSL und Powershell für Windows 11										   #
#		   Version 1.3 - Abfrage der Größe des Sticks, um nicht zufällig eine Platte zu überschreiben (<128GB)			   #
#		   Version 1.4 - wget fix, USB-Geräteauswahl, ISO-Build von USB-Write getrennt                                    #
#																														   #
#		   Das Script lädt die zum Ausführungszeitpunkt aktuellste Debian-netinst.iso, entpackt diese, injiziert		   #
#		   die benötigten Datein für die unattended Installation, baut die .iso wieder zusammen und schreibt sie		   #
#		   auf einen USB-Stick.																						   #
#		   OBACHT: dem Script ist egal, was und wieviele Partitionen auf dem Stick sind! Es reisst alles ein und 		   #
#		   erstellt einen frischen Installationsstick!!!																   #
#																														   #
############################################################################################################################

set -e

echo ""
echo "=========================================="
echo "  VKS-Kiosk ISO Builder (WSL-Version)"
echo "=========================================="
echo ""

# --- 1. Abhängigkeiten ---
echo "[1/4] Abhängigkeiten installieren ..."
apt-get update -qq
apt-get install -y syslinux syslinux-utils cpio coreutils usbutils xorriso 7zip wget -qq

# --- 2. ISO herunterladen ---
echo ""
echo "[2/4] Debian netinst ISO herunterladen ..."
CURRDIR=$(pwd)
WORKDIR=/workdir
BASE_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
ISO=$(wget -qO - "$BASE_URL/SHA512SUMS" | grep netinst | grep -v mac | head -n 1 | awk '{ print $2 }')

if [ -z "$ISO" ]; then
    echo "FEHLER: Konnte ISO-Dateinamen nicht ermitteln. Internetverbindung pruefen!"
    exit 1
fi

VERSION=$(echo "$ISO" | cut -d'-' -f2)
echo "  Aktuellste Version: Debian $VERSION"
echo "  Dateiname: $ISO"

if [ -f "$CURRDIR/$ISO" ]; then
    echo "  ISO bereits vorhanden, überspringe Download."
else
    echo "  Lade herunter ..."
    wget "$BASE_URL/$ISO" -O "$CURRDIR/$ISO"
fi

# --- 3. ISO modifizieren und neu bauen ---
echo ""
echo "[3/4] ISO entpacken und modifizieren ..."

# Payload-Skript finden (neuestes make_vks*)
DAT=$(ls -ct "$CURRDIR"/make_vks* 2>/dev/null | head -n 1)
if [ -z "$DAT" ]; then
    echo "FEHLER: Kein make_vks*.sh Skript im Verzeichnis gefunden!"
    exit 1
fi
DAT=$(basename "$DAT")
echo "  Payload-Skript: $DAT"

rm -Rf "$WORKDIR"
mkdir -p "$WORKDIR"
7z x -o"$WORKDIR" "$CURRDIR/$ISO" -y
cd "$WORKDIR"

gunzip install.amd/initrd.gz
cp "$CURRDIR/preseed.cfg" .
cp "$CURRDIR/overlay.py" ./install/
cp "$CURRDIR/$DAT" ./install/make_vks.sh
cp "$CURRDIR/grub.cfg" ./boot/grub/
echo preseed.cfg | cpio -o -H newc -A -F install.amd/initrd
rm -f preseed.cfg
gzip install.amd/initrd
find . -follow -type f -print0 | xargs --null md5sum > md5sum.txt

OUTISO="$CURRDIR/vks-kiosk-debian-${VERSION}.iso"
echo "  ISO zusammenbauen ..."
xorriso -as mkisofs -o "$OUTISO" \
    -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
    -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat "$WORKDIR"

echo ""
echo "=========================================="
echo "  ISO erfolgreich erstellt!"
echo "=========================================="
echo ""
echo "  Linux-Pfad:   $OUTISO"

# Windows-Pfad berechnen (WSL -> Windows)
WINPATH=$(echo "$OUTISO" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|; s|/|\\|g')
echo "  Windows-Pfad: $WINPATH"
echo ""

# --- 4. Auf USB-Stick schreiben (optional) ---
echo "[4/4] USB-Stick beschreiben ..."
echo ""

# Alle Blockgeräte anzeigen (keine Loop/ROM-Devices)
DEVICES=$(lsblk -dpno NAME,SIZE,TRAN,MODEL 2>/dev/null | grep -v "loop\|rom\|boot" | grep -v "^$")

if [ -z "$DEVICES" ]; then
    echo "Keine beschreibbaren Blockgeräte gefunden."
    echo "Die ISO-Datei wurde trotzdem erstellt. Du kannst sie manuell auf einen Stick schreiben:"
    echo "  dd if=$OUTISO of=/dev/sdX bs=4M status=progress && sync"
    exit 0
fi

echo "Verfuegbare Geräte:"
echo "-------------------------------------------"
i=1
declare -a DEV_ARRAY
while IFS= read -r line; do
    DEV_ARRAY[$i]=$(echo "$line" | awk '{print $1}')
    printf "  [%d] %s\n" "$i" "$line"
    i=$((i + 1))
done <<< "$DEVICES"
echo "  [0] Abbrechen (ISO nur erstellen, nicht auf Stick schreiben)"
echo "-------------------------------------------"
echo ""
read -p "Geraet auswaehlen [0-$((i-1))]: " DEVNUM

if [ "$DEVNUM" = "0" ] || [ -z "$DEVNUM" ]; then
    echo ""
    echo "Abbruch: ISO wurde erstellt, aber nicht auf einen Stick geschrieben."
    echo "Du kannst die ISO manuell brennen mit:"
    echo "  dd if=$OUTISO of=/dev/sdX bs=4M status=progress && sync"
    exit 0
fi

SELECTED="${DEV_ARRAY[$DEVNUM]}"
if [ -z "$SELECTED" ]; then
    echo "Ungueltige Auswahl!"
    exit 1
fi

# Sicherheitsabfrage
DEVINFO=$(lsblk -dpno NAME,SIZE,MODEL "$SELECTED" 2>/dev/null)
echo ""
echo "################################################################################"
echo "!!! OBACHT !!!"
echo "Das Geraet $DEVINFO wird UNWIDERRUFLICH geloescht!"
echo "################################################################################"
read -p "Bist du sicher? (j/n): " CHOICE

if [ "$CHOICE" = "j" ]; then
    echo ""
    echo "Partitionstabelle neu erstellen ..."
    /usr/sbin/fdisk "$SELECTED" << EOF
g
n



w
EOF
    echo ""
    echo "ISO auf $SELECTED schreiben ..."
    dd if="$OUTISO" of="$SELECTED" bs=4M status=progress && sync
    echo ""
    echo "=========================================="
    echo "  USB-Stick erfolgreich erstellt!"
    echo "=========================================="
else
    echo ""
    echo "Abbruch: ISO bitte selbst brennen mit:"
    echo "  dd if=$OUTISO of=$SELECTED bs=4M status=progress && sync"
fi
