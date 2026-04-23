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
#																														   #
#		   Das Script lädt die zum Ausführungszeitpunkt aktuellste Debian-netinst.iso, entpackt diese, injiziert		   #
#		   die benötigten Datein für die unattended Installation, baut die .iso wieder zusammen und schreibt sie		   #
#		   auf einen USB-Stick.																							   #
#		   OBACHT: dem Script ist egal, was und wieviele Partitionen auf dem Stick sind! Es reisst alles ein und 		   #
#		   erstellt einen frischen Installationsstick!!!																   #
#																														   #
############################################################################################################################

apt update && apt upgrade
apt-get install syslinux syslinux-utils cpio coreutils usbutils xorriso 7zip -y
USB=$(lsblk -b -dpno NAME,SIZE,TRAN | awk '$3=="usb" && $2 < 128*1024*1024*1024 {print $1}' | tail -n1)
if [ -z $USB ]; then
	echo "############################################################################"
    echo "keine geeignete SD-Karte gefunden: bitte prüfen und Script erneut ausführen!"
	echo "############################################################################"
	exit 1
fi
#USB=$(lsblk -o TYPE,NAME,HOTPLUG | grep "$i" | grep "sd" | cut -d' ' -f2 | tail -n2 | head -n 1)
BASE_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
ISO=$( wget -qO - $BASE_URL/SHA512SUMS | grep netinst | grep -v mac | head -n 1 | awk '{ print $2 }' )
VERSION=$(echo $ISO | cut -d'-' -f2)
if [ ! -f "$ISO" ]; then
	wget "$BASE_URL/$ISO" -O "$ISO"
fi
STICK=$(lsusb | grep -v "root hub")
CURRDIR=$(pwd)
WORKDIR=/workdir
DAT=$(ls -c /home/$USER/make_vks* | head - n1)
rm -Rf $WORKDIR
mkdir $WORKDIR
7z x -o$WORKDIR $ISO
cd $WORKDIR
gunzip install.amd/initrd.gz
cp $CURRDIR/preseed.cfg .
cp $CURRDIR/overlay.py ./install
cp $CURRDIR/$DAT ./install/make_vks.sh
cp $CURRDIR/grub.cfg ./boot/grub/
echo preseed.cfg | cpio -o -H newc -A -F install.amd/initrd
rm ../preseed.cfg
gzip install.amd/initrd
find -follow -type f -print0 | xargs --null md5sum > md5sum.txt
xorriso -as mkisofs -o $ISO \
-c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
-boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
-isohybrid-gpt-basdat $WORKDIR
echo "################################################################################"
read -p "!!! OBACHT !!! USB Stick -$STICK- wird unwiderruflich gelöscht!!! Are u sure??: " CHOICE
if [ "$CHOICE" == "j" ]; then
    echo "Wird fortgesetzt..."
	/usr/sbin/fdisk /dev/${USB:0:3} << EOF
	g
	n
	
	
	
	w
EOF
dd if=$WORKDIR/$ISO of=/dev/${USB:0:3} bs=4M status=progress &&sync && echo "USB-Stick erfolgreich erstellt ..."
else
    echo "Abbruch: .iso bitte selbst brennen ..."
fi
