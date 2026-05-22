#!/bin/bash
# ============================================================
# VKS-Kiosk Shared ISO Builder Logic
# ============================================================
set -euo pipefail

# Load environment variables
if [ -f "../.env" ]; then
    source ../.env
elif [ -f ".env" ]; then
    source .env
fi

# Fallbacks if not set in .env
MAX_USB_SIZE_GB=${MAX_USB_SIZE_GB:-128}
DEBIAN_ISO_URL=${DEBIAN_ISO_URL:-"https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"}
SCRIPT_VERSION=${SCRIPT_VERSION:-"2.0"}

install_dependencies() {
    echo "=========================================="
    echo " [1/4] Abhaengigkeiten installieren"
    echo "=========================================="
    apt-get update -qq || true
    apt-get install -y syslinux syslinux-utils cpio coreutils usbutils xorriso p7zip-full wget whiptail dialog 2>&1 | \
        grep -v "already the newest" | grep -v "^$" || true
    echo "  -> OK"
    echo ""
}

download_iso() {
    echo "=========================================="
    echo " [2/4] Debian ISO herunterladen"
    echo "=========================================="
    BASE_URL="$DEBIAN_ISO_URL"
    ISO="$(wget -qO - "${BASE_URL}/SHA512SUMS" | grep netinst | grep -v mac | head -n 1 | awk '{print $2}')"

    if [ -z "$ISO" ]; then
        echo "FEHLER: ISO-Dateiname konnte nicht ermittelt werden."
        echo "Internetverbindung pruefen!"
        return 1
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
    echo ""
}

build_iso() {
    echo "=========================================="
    echo " [3/4] ISO patchen und neu bauen"
    echo "=========================================="
    WORKDIR="${CURRDIR}/workdir"

    # Payload-Skript finden (neuestes make_vks*)
    DAT="$(ls -ct "${CURRDIR}"/make_vks*.sh 2>/dev/null | head -n 1 || true)"
    if [ -z "$DAT" ]; then
        echo "FEHLER: Kein make_vks*.sh Skript im aktuellen Verzeichnis gefunden!"
        return 1
    fi
    DAT="$(basename "$DAT")"
    echo "  Payload-Skript: $DAT"

    # Alle benoetigten Dateien pruefen
    for f in preseed.cfg overlay.py grub.cfg "$DAT"; do
        if [ ! -f "${CURRDIR}/${f}" ]; then
            echo "FEHLER: Benoetigte Datei fehlt: ${CURRDIR}/${f}"
            return 1
        fi
    done

    rm -Rf "$WORKDIR"
    mkdir -p "$WORKDIR"

    echo "  Entpacke ISO ..."
    if command -v 7z >/dev/null 2>&1; then
        7z x -o"${WORKDIR}" "${CURRDIR}/${ISO}" -y >/dev/null
    elif command -v 7za >/dev/null 2>&1; then
        7za x -o"${WORKDIR}" "${CURRDIR}/${ISO}" -y >/dev/null
    else
        echo "FEHLER: 7z / 7za nicht gefunden!"
        return 1
    fi

    cd "$WORKDIR"

    echo "  Injiziere Kiosk-Skripte ..."
    gunzip install.amd/initrd.gz
    cp "${CURRDIR}/preseed.cfg" .

    INSTALL_DIR=""
    for d in install install.amd; do
        if [ -d "${WORKDIR}/${d}" ]; then
            INSTALL_DIR="${WORKDIR}/${d}"
            break
        fi
    done
    if [ -z "$INSTALL_DIR" ]; then
        echo "FEHLER: Kein install/ oder install.amd/ Verzeichnis in der ISO gefunden!"
        return 1
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

    echo "  ISO erfolgreich erstellt: $OUTISO"
    echo ""
}

select_and_flash_usb() {
    echo "=========================================="
    echo " [4/4] USB-Stick beschreiben (optional)"
    echo "=========================================="

    DEVICES="$(lsblk -dpno NAME,SIZE,TRAN,MODEL 2>/dev/null | grep -vE 'loop|rom|boot|ram' | grep -v '^$' || true)"

    if [ -z "$DEVICES" ]; then
        echo "  Keine beschreibbaren Blockgeraete gefunden."
        echo "  ISO manuell flashen:"
        echo "    dd if=$OUTISO of=/dev/sdX bs=4M status=progress && sync"
        return 0
    fi

    declare -a WHIPTAIL_MENU
    WHIPTAIL_MENU+=("0" "Abbrechen (nur ISO erstellen)")

    i=1
    declare -a DEV_ARRAY
    while IFS= read -r line; do
        DEV_NAME="$(echo "$line" | awk '{print $1}')"
        DEV_DESC="$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')"
        DEV_ARRAY[$i]="$DEV_NAME"
        WHIPTAIL_MENU+=("$i" "$DEV_NAME ($DEV_DESC)")
        i=$((i + 1))
    done <<< "$DEVICES"

    if command -v whiptail >/dev/null 2>&1; then
        DEVNUM=$(whiptail --title "Ziel-Laufwerk auswaehlen" --menu "Auf welches Laufwerk soll das Image geschrieben werden?" 20 78 10 "${WHIPTAIL_MENU[@]}" 3>&1 1>&2 2>&3) || DEVNUM=0
    else
        echo "  Verfuegbare Geraete:"
        for ((j=0; j<${#WHIPTAIL_MENU[@]}; j+=2)); do
            echo "  [${WHIPTAIL_MENU[$j]}] ${WHIPTAIL_MENU[$j+1]}"
        done
        read -r -p "  Geraet auswaehlen [0-$((i-1))]: " DEVNUM
    fi

    if [ "${DEVNUM:-0}" = "0" ] || [ -z "${DEVNUM:-}" ]; then
        echo "  Abbruch. ISO wurde erstellt, aber nicht auf Stick geschrieben."
        echo "  Manuell flashen:"
        echo "    dd if=$OUTISO of=/dev/sdX bs=4M status=progress && sync"
        return 0
    fi

    SELECTED="${DEV_ARRAY[$DEVNUM]:-}"
    if [ -z "$SELECTED" ]; then
        echo "  Ungueltige Auswahl!"
        return 1
    fi

    SIZE_BYTES="$(lsblk -bdno SIZE "$SELECTED" 2>/dev/null || echo 0)"
    MAX_BYTES=$((MAX_USB_SIZE_GB * 1024 * 1024 * 1024))
    if [ "$SIZE_BYTES" -gt "$MAX_BYTES" ]; then
        echo "FEHLER: Geraet $SELECTED ist groesser als $MAX_USB_SIZE_GB GB!"
        echo "Sicherheitsabbruch."
        return 1
    fi

    DEVINFO="$(lsblk -dpno NAME,SIZE,MODEL "$SELECTED" 2>/dev/null || echo "$SELECTED")"
    WARN_MSG="!!! OBACHT !!!\nDas Geraet:\n$DEVINFO\nwird UNWIDERRUFLICH und VOLLSTAENDIG geloescht!\n\nBist du sicher?"

    if command -v whiptail >/dev/null 2>&1; then
        if ! whiptail --title "WARNUNG" --yesno "$WARN_MSG" 12 78; then
            echo "  Abbruch durch Benutzer."
            return 0
        fi
    else
        echo -e "$WARN_MSG"
        read -r -p "  Bist du sicher? (j/n): " CHOICE
        if [ "$CHOICE" != "j" ]; then
            echo "  Abbruch durch Benutzer."
            return 0
        fi
    fi

    echo "  Partitionstabelle neu erstellen ..."
    echo 'label: gpt' | sfdisk "$SELECTED" --no-reread -q 2>/dev/null || \
    printf 'g\nn\n\n\n\nw\n' | fdisk "$SELECTED" >/dev/null 2>&1 || true

    echo "  ISO schreiben auf $SELECTED ..."
    dd if="$OUTISO" of="$SELECTED" bs=4M status=progress conv=fsync
    sync
    echo "=========================================="
    echo "  USB-Stick erfolgreich erstellt!"
    echo "=========================================="
}
