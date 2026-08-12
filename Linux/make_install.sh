#!/bin/bash
export PATH=$PATH:/usr/sbin/

CURRDIR=$(dirname "$(readlink -f "$0")")
if [ -f "$CURRDIR/../.env" ]; then
	set -a
	source "$CURRDIR/../.env"
	set +a
else
	echo "FEHLER: .env Datei nicht gefunden! Bitte eine .env Datei im Root-Verzeichnis mit VKS_ROOT_PASSWORD und VKS_USER_PASSWORD erstellen."
	exit 1
fi

if [ -z "$VKS_ROOT_PASSWORD" ] || [ -z "$VKS_USER_PASSWORD" ]; then
	echo "FEHLER: VKS_ROOT_PASSWORD oder VKS_USER_PASSWORD in der .env Datei nicht gesetzt!"
	exit 1
fi

# Generate crypted passwords
ROOT_PW_CRYPTED=$(echo "$VKS_ROOT_PASSWORD" | openssl passwd -6 -stdin)
USER_PW_CRYPTED=$(echo "$VKS_USER_PASSWORD" | openssl passwd -6 -stdin)

############################################################################################################################
#                                                                                                                          #
#                                           		VKS-Futro Script                                                       #
#                                                      16.04.2026                                                          #
#                                                                                                                          #
#          Ersteller: Markus Hertes                                                                                        #
#                                  				                                                                           #
#          Version 1.0 - macht was es soll                                                                                 #
#		   Version 1.1 - Script und Grub inject																			   #
#		   Version 1.2 - Abfrage der Größe des Sticks, um nicht zufällig eine Platte zu überschreiben (<128GB)			   #
#						 																								   #
#																														   #
#		   Das Script lädt die zum Ausführungszeitpunkt aktuellste Debian-netinst.iso, entpackt diese, injiziert		   #
#		   die benötigten Datein für die unattended Installation, baut die .iso wieder zusammen und schreibt sie		   #
#		   auf einen USB-Stick.																							   #
#		   OBACHT: dem Script ist egal, was und wieviele Partitionen auf dem Stick sind! Es reisst alles ein und 		   #
#		   erstellt einen frischen Installationsstick!!!																   #
#																														   #
############################################################################################################################

apt-get install syslinux syslinux-utils cpio coreutils xorriso 7zip -y

echo "############################################################################"
echo "Passwort fuer root und vksuser festlegen ..."
read -r -s -p "Bitte Passwort eingeben (leer lassen fuer zufaelliges Passwort): " VKS_PASSWORD
echo ""

if [ -z "$VKS_PASSWORD" ]; then
    VKS_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "Kein Passwort eingegeben. Zufaelliges Passwort generiert: $VKS_PASSWORD"
    echo "BITTE NOTIEREN! Es wird im Installations-Stick verwendet."
else
    echo "Passwort gesetzt."
fi
echo "############################################################################"
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
DAT="$(ls -ct "${CURRDIR}"/make_vks*.sh 2>/dev/null | head -n 1 || true)"
DAT="$(basename "$DAT")"
rm -Rf $WORKDIR
mkdir $WORKDIR
7z x -o$WORKDIR $ISO
cd $WORKDIR
gunzip install.amd/initrd.gz
cp "$CURRDIR/preseed.cfg" .

# Replace placeholders with crypted passwords
sed -i "s|ROOT_PW_PLACEHOLDER|$ROOT_PW_CRYPTED|g" preseed.cfg
sed -i "s|USER_PW_PLACEHOLDER|$USER_PW_CRYPTED|g" preseed.cfg

cp "$CURRDIR/$DAT" ./install/make_vks.sh
cp "$CURRDIR/overlay.py" ./install
cp "$CURRDIR/grub.cfg" ./boot/grub/
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
