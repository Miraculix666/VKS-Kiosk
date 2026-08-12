#!/bin/bash
# ============================================================
# VKS-Kiosk ISO Builder (Linux-Version)
# Baut die Debian-netinst.iso mit injizierten Kiosk-Skripten
# und schreibt sie optional auf einen USB-Stick.
# ============================================================

echo "[0/4] Passwoerter für die VKS-Kiosk Installation festlegen"
echo "Wenn du die Eingabe leer laesst, wird ein sicheres, zufaelliges Passwort generiert."
echo ""

read -r -s -p "  Root-Passwort (für Debug-Modus) eingeben: " INPUT_ROOT_PW
echo ""
if [ -z "$INPUT_ROOT_PW" ]; then
    ROOT_PW="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)"
    echo "  -> Leere Eingabe. Generiertes Root-Passwort: $ROOT_PW"
else
    ROOT_PW="$INPUT_ROOT_PW"
    echo "  -> Root-Passwort wurde gesetzt."
fi
echo ""

read -r -s -p "  VKS-User-Passwort (vksuser) eingeben: " INPUT_USER_PW
echo ""
if [ -z "$INPUT_USER_PW" ]; then
    USER_PW="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)"
    echo "  -> Leere Eingabe. Generiertes User-Passwort: $USER_PW"
else
    USER_PW="$INPUT_USER_PW"
    echo "  -> User-Passwort wurde gesetzt."
fi
echo ""

CURRDIR=$(dirname "$(readlink -f "$0")")

apt-get install syslinux syslinux-utils cpio coreutils xorriso 7zip -y
USB=$(lsblk -b -dpno NAME,SIZE,TRAN | awk '$3=="usb" && $2 < 128*1024*1024*1024 {print $1}' | tail -n1)
if [ -z "$USB" ]; then
	echo "############################################################################"
    echo "keine geeignete SD-Karte gefunden: bitte prüfen und Script erneut ausführen!"
	echo "############################################################################"
	exit 1
fi
BASE_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
ISO=$( wget -qO - $BASE_URL/SHA512SUMS | grep netinst | grep -v mac | head -n 1 | awk '{ print $2 }' )
VERSION=$(echo "$ISO" | cut -d'-' -f2)
if [ ! -f "$ISO" ]; then
	wget "$BASE_URL/$ISO" -O "$ISO"
fi
STICK=$(lsusb | grep -v "root hub")
WORKDIR=/temp
DAT=$(ls -c /home/"$USER"/make_vks* | head - n1)
rm -Rf "$WORKDIR"
mkdir "$WORKDIR"
7z x -o"$WORKDIR" "$ISO"
cd "$WORKDIR" || exit
gunzip install.amd/initrd.gz
cp /home/"$USER"/preseed.cfg .
cp /home/"$USER"/"$DAT" ./install/make_vks.sh
cp /home/"$USER"/overlay.py ./install
cp /home/"$USER"/grub.cfg ./boot/grub/
echo preseed.cfg | cpio -o -H newc -A -F install.amd/initrd
rm preseed.cfg
gzip install.amd/initrd
find -follow -type f -print0 | xargs --null md5sum > md5sum.txt
xorriso -as mkisofs -o "$ISO" \
-c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
-boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
-isohybrid-gpt-basdat "$WORKDIR"
echo "################################################################################"
read -p "!!! OBACHT !!! USB Stick -$STICK- wird unwiderruflich gelöscht!!! Are u sure??: " CHOICE
if [ "$CHOICE" == "j" ]; then
    echo "Wird fortgesetzt..."
	/usr/sbin/fdisk /dev/"${USB:0:3}" << EOF
	g
	n
	
	
	
	w
EOF
dd if="$WORKDIR"/"$ISO" of=/dev/"${USB:0:3}" bs=4M status=progress &&sync && echo "USB-Stick erfolgreich erstellt ..."
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
cleanup_environment

echo ""
echo "Erfolgreich abgeschlossen."
