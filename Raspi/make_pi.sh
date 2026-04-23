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
#		   Version 1.1 - Abfrage der Größe des Sticks, um nicht zufällig eine Platte zu überschreiben (<128GB)			   #
#																														   #
#		   Das Script lädt die zum Ausführungszeitpunkt aktuellste Debian-raspi minimal und schreibt sie auf eine SD-Karte #
#																							   							   #
#		   OBACHT: dem Script ist egal, was und wieviele Partitionen auf der Karte sind! Es reisst alles ein und 		   #
#		   erstellt einen frischen Installationsstick!!!																   #
#																														   #
############################################################################################################################

apt update && apt upgrade -y
apt-get install coreutils usbutils xz-utils curl jq -y
USB=$(lsblk -b -dpno NAME,SIZE,TRAN | awk '$3=="usb" && $2 < 128*1024*1024*1024 {print $1}' || true | tail -n1)
if [ -z $USB ]; then
	echo "############################################################################"
    echo "keine geeignete SD-Karte gefunden: bitte prüfen und Script erneut ausführen!"
	echo "############################################################################"
	exit 1
fi
#USB=$(lsblk -o TYPE,NAME,HOTPLUG | grep "$i" | grep "sd" | cut -d' ' -f2 | tail -n2 | head -n 1)
IMG=$(curl -s https://downloads.raspberrypi.com/os_list_imagingutility_v4.json | jq -r '.os_list[] | select(.name == "Raspberry Pi OS (32-bit)") | .url')
curl -L $IMG -o raspios_full.img.xz 2>&1

STICK=$(lsusb | grep -v "root hub" | awk '{for(i=7; i<=NF; i++) printf "%s ", $i; print ""}')

echo "################################################################################"
read -p "!!! OBACHT !!! SD-Karte -$STICK- wird unwiderruflich gelöscht!!! Are u sure??: " CHOICE
if [ "$CHOICE" == "j" ]; then
    echo "Wird fortgesetzt..."
	/usr/sbin/fdisk $USB << EOF
	o
	n
	
	
	
	w
EOF
echo "Please hold the line: Image wird entpackt ..."
unxz raspios_full.img.xz 2>&1
dd if=raspios_full.img of=$USB bs=4M status=progress conv=fsync
else
    echo "Abbruch: Datei bitte selbst brennen ..."
fi
mkdir -p /mnt

sleep 5

root=$(lsblk | tail -n 2 | head -n 1 | awk '{ print $1}')
mount /dev/${root:2:4} /mnt
touch /mnt/ssh
PW=$(echo 'vksuser' | openssl passwd -6 -stdin)
echo "vksuser:$PW" > /mnt/userconf.txt
cat <<EOF | tee /mnt/firstrun.sh
#!/bin/bash


sudo raspi-config nonint do_locale de_DE.UTF-8

sudo raspi-config nonint do_configure_keyboard de

sudo raspi-config nonint do_timezone Europe/Berlin

sudo /boot/firmware/make_vks.sh
rm -f /boot/firmware/firstrun.sh
EOF

touch /mnt/meta-data
cat <<EOF | tee /mnt/user-data
#cloud-config
runcmd:
  - [ bash, /boot/firmware/firstrun.sh ]
EOF
chmod +x /mnt/firstrun.sh
cp make_vks.sh /mnt
cp overlay.py /mnt
umount /mnt 2>&1
echo "Done. SD-Karte ausgeworfen ..."