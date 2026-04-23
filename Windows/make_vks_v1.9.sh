#!/bin/bash
export PATH=$PATH:/usr/sbin/
####################################################################################################################
#                                                                                                                  #
#                                           		VKS-Futro Script                                               #
#                                                      14.04.2026                                                  #
#                                                                                                                  #
# Ersteller: Markus Hertes                                                                                         #
#                              				                                                                       #
# Version 1.0 - macht was es soll                                                                                  #
# Version 1.1 - Dynamisches Scannen der Hardware                                                                   #
# Version 1.2 - Abfrage Standalone/Voice VLAN                                                                      #
# Version 1.3 - Script ist vollständig autark und erfordert keinerlei Benutzerinteraktion mehr                     #
# Version 1.4 - Shutdownscript zum resetteten der Netzwerkeinstellungen										       #
# Version 1.5 - Netzwerkzugriff beschränken																	       #
# Version 1.6 - statische Scriptversion für full unattended Installation										   #
# Version 1.7 - Schreibzugriffe auf SSD/SD minimieren und abschliessende Härtung								   #
# Version 1.8 - Anzeige Scriptversion und Tuning Vivaldi														   #
# Version 1.9 - DP-Audio, overlay fs && tmpfs	   											                       #	
#																												   #
# Das Script lädt auf ein rein textbasiertes Debian ausschliesslich mit Standardsystemwerkzeugen und einem         #
# SSH-Server einen schlanken XFCE4 Desktop, ein paar kleine Tools und den Vivaldi Webbrowser. Danach erzeugt es    #
# weitere Scripte und nimmt Anpassungen an Diensten und Configdateien vor und startet den Client neu.	           #
# 			                                                                                                       #
# Nach dem Reboot läuft das System direkt in die Anmeldung zur Hipos VKS Seite. Es identifiziert sich als Telefon  #
# und sendet DSCP 34 tags (dezimal 34 ~ AF41). Durch die dynamische Voice VLAN Auswahl kann so der traffic	       #
# als Videotelefonie priorisiert werden. 																  		   #
# LLDP ist ein SAU-Protokoll!!! Es sendet standardmäßig alle 30 sek stumpf seine Statusinformationen: 			   #
# der Timer sollte auf max. 10 sek eingestellt werden, damit das Script zuverlässig funktioniert ...			   #
#                                                                                                                  #
# Das Skript ist hardwareunabhängig: es liest die benötigten Informationen selbständig aus und passt sich seiner   #
# Umgebung an.		               																				   #
#                                                                                                                  #
####################################################################################################################


#          Installation Grundsystem, benötigte Dienste und Browser

sleep 15
apt update && apt upgrade -y
apt install xfce4 net-tools xdotool lldpd snmpd curl gnupg ca-certificates original-awk firmware-linux isc-dhcp-client rsync python3 python3-tk -y
curl -fsSL https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/vivaldi.gpg


cat <<EOF | tee /etc/apt/sources.list.d/vivaldi.sources
Types: deb
URIs: https://repo.vivaldi.com/stable/deb/
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /usr/share/keyrings/vivaldi.gpg
EOF


apt update && apt-cache policy vivaldi-stable && apt install vivaldi-stable -y


cat <<EOF | tee /home/vksuser/start.sh
#!/bin/bash
xset s off &
xset s noblank &
xset -dpms &
sleep 5
rm -Rf /home/vksuser/.config/vivaldi/Default/Sessions/*
/usr/bin/vivaldi-stable --app=https://join.hipos-vks.polizei.nrw --enable-gpu --ignore-gpu-blocklist --gpu-rasterization --enable-oop-rasterization --no-first-run &
sleep 5
TOKEN=0
while true; do
PID=\$(pgrep -f "vivaldi-stable|vivaldi")
WIN_ID=\$(xdotool search --pid "$PID" 2>/dev/null | head -n 1)
if [ -n "\$PID" ]; then
    if [ "\$TOKEN" -eq 0 ]; then
	    xdotool windowactivate "\$WIN_ID"
		sleep 2
        xdotool key --window "\$WIN_ID" F11
	    ((TOKEN++))
	fi
elif [ -z "\$PID" ]; then
        echo "Kein Vivaldi-Fenster gefunden!"
	    rm -Rf /home/vksuser/.config/vivaldi/Default/Sessions/*
	    /usr/bin/vivaldi-stable --app=https://join.hipos-vks.polizei.nrw --enable-gpu --ignore-gpu-blocklist --gpu-rasterization --enable-oop-rasterization --no-first-run &
	    PID=\$(pgrep -f "vivaldi-stable|vivaldi")
	    WIN_ID=\$(xdotool search --pid "\$PID" 2>/dev/null | head -n 1)
	    xdotool windowactivate "\$WIN_ID"
		sleep 2
        xdotool key --window "\$WIN_ID" F11
	    ((TOKEN++))
fi
HDMI="\$(pactl list short sinks | awk '/hdmi/ {print \$2; exit}')"   
ANALOG="\$(pactl list short sinks | awk '/analog/ {print \$2; exit}')"
DP="\$(pactl list short sinks | awk '/dsp_generic.HiFi__Speaker/ {print \$2; exit}')"
CURRENT=\$(pactl get-default-sink 2>/dev/null)
	if [ -n "\$HDMI" ]; then  
		if [ "\$CURRENT" != "\$HDMI" ]; then
    		pactl set-default-sink "\$HDMI"
    		pactl move-sink-input @DEFAULT_SINK@ "\$HDMI" 2>/dev/null
  		fi
	elif [ -n "\$ANALOG" ]; then
		 if [ "\$CURRENT" != "\$ANALOG" ]; then

			pactl set-default-sink "\$ANALOG"
            pactl move-sink-input @DEFAULT_SINK@ "\$ANALOG" 2>/dev/null
		fi
	elif [ -n "\$DP" ]; then
        if [ "\$CURRENT" != "\$DP" ]; then
			pactl set-default-sink "\$DP"
            pactl move-sink-input @DEFAULT_SINK@ "\$DP" 2>/dev/null
        fi
	fi
  sleep 2
((TOKEN++))
done
EOF

chmod a+x /home/vksuser/start.sh
sed -i 's/load-module module-switch-on-port-available/#load-module module-switch-on-port-available/g' /etc/pulse/default.pa


cat <<EOF | tee /etc/systemd/system/apply_vlan.service
[Unit]
Description=Apply LLDP VLAN
After=ssh.service lldpd.service
[Service]
Type=simple
ExecStart=/bin/bash /scripts/apply-lldp-vlan.sh
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable apply_vlan.service


cat <<EOF | tee /etc/systemd/system/overlay.mount
[Unit]
Description=Overlay tmpfs

[Mount]
What=tmpfs
Where=/overlay
Type=tmpfs
Options=size=500m

[Install]
WantedBy=local-fs.target
EOF

systemctl daemon-reexec
systemctl enable overlay.mount


#          Hardware auslesen abspeichern für später

sleep 2
IFACE=$(ip -4 route ls default | grep -Po '(?<=dev )(\S+)')
sleep 1
SOUND=$(pactl list short sinks | awk '/hdmi/ {print $2; exit}')


#          Netzwerkeinstellungen setzen und Firewall abdichten

echo "DAEMON_ARGS=\"-c -C \$IFACE -M 3\"">> /etc/default/lldpd

cat <<EOF | tee /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
        set ssh_rate_limit {
        type ipv4_addr
        flags dynamic, timeout
        timeout 10m
        }
        chain input {
            type filter hook input priority 0; policy drop;

            iifname "lo" accept
            ct state established,related accept
            ct state invalid drop
            ip saddr @ssh_rate_limit tcp dport 22 ct state new counter drop
            	# machst du gute Guck hier!!	
			ip saddr 192.168.200.0/24 tcp dport 22 ct state new \
                limit rate 3/minute \
                add @ssh_rate_limit { ip saddr timeout 5m } \
                counter log prefix "SSH-rate-limit-blocked: " drop
		        ip saddr 192.168.200.0/24 tcp dport 22 ct state new accept
			}
        chain forward {
                type filter hook forward priority filter;
				policy drop;
        }
        chain output {
                type filter hook output priority filter;
				ct state established, related accept;
				policy accept;
        }
}
table inet qos {
chain output {
type filter hook output priority 0;
udp dport 100-20000 ip dscp set 34
udp dport 5060 ip dscp set 34
}
}
EOF

/usr/sbin/nft -f /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables


#          Bauen der Start- und Shutdownscripte

mkdir -p /scripts
mkdir -p /overlay
mkdir -p /overlay/var-upper
mkdir -p /overlay/var-work
mkdir -p /overlay/home
mkdir -p /overlay/home/upper
mkdir -p /overlay/home/work


cat <<EOF | tee /scripts/show_version.sh
#!/bin/bash
python3 /scripts/overlay.py
EOF

chmod a+x /scripts/show_version.sh



cat <<EOF | tee /scripts/apply-lldp-vlan.sh
#!/bin/bash
export PATH=\$PATH:/usr/sbin/
LAST=""
while true; do
for i in \$(seq 1 11)
	do
		IFACE=\$(ip -4 route ls default | grep -Po '(?<=dev )(\S+)')
		echo \$IFACE>/root/iface.txt
		IF=\$(cat /root/iface.txt)
		VOICE=\$(/usr/sbin/lldpcli show neighbors details | grep -A1 "Voice," | grep VLAN | cut -d':' -f2 | sed -e 's/^[ \t]*//;s/[ \t]*$//')
		if [ "\$VOICE" != "\$LAST" ] && [ -n "\$VOICE" ]; then
			ip route del default    	
			# verarschen lass mer uns net!!!
			echo "Ui!: \$VOICE"
			ip link delete \$IF.\$LAST 2>/dev/null
			ip link add link \$IF name \$IF.\$VOICE type vlan id \$VOICE
			ip link set \$IF.\$VOICE up
    		dhclient \$IF.\$VOICE
    		LAST="\$VOICE"
			sleep 10
		elif [ "\$VOICE" = "\$LAST" ]; then
			# des passt scho ...
			echo "do nothing"
		elif [ -z "\$VOICE" ]; then
			# ja dann halt nicht ...
			ip route del default
			ip link delete \$IF.\$LAST 2>/dev/null
	        ip link add link \$IF name \$IF type local
	        ip link set \$IF up
            dhclient \$IF
		fi
	done
dhclient
sleep 2
done
EOF


chmod a+x /scripts/apply-lldp-vlan.sh

cat <<EOF | tee /scripts/move_mouse.sh
#!/bin/bash
set -e
LENGTH=1
DELAY=60
while true
do
    for ANGLE in 0 90 180 270
    do
        xdotool mousemove_relative --polar \$ANGLE \$LENGTH
        sleep \$DELAY
    done
done
EOF

chmod a+x /scripts/move_mouse.sh


cat <<EOF | tee /scripts/reset-home.sh
#!/bin/bash
set -e
USER="vksuser"
SRC="/home_template/\$USER/"
DST="/home/\$USER/"
if [ ! -d "\$SRC" ]; then
    echo "Template fehlt!"
    exit 1
fi
rsync -a --delete "\$SRC" "\$DST"
chown -R \$USER:\$USER "\$DST"
EOF

chmod +x /scripts/reset-home.sh


#          Dienste enablen und Starten

mkdir -p /etc/systemd/system/system.network.d

cat <<EOF | tee /etc/systemd/system/system.network.d/override.conf
[Unit]
After=systemd-udev-settle.service
Wants= systemd-udev-settle.service
EOF

systemctl daemon-reexec
systemctl enable systemd-networkd-wait-online.service
systemctl enable snmpd
systemctl start snmpd

cat <<EOF | tee /etc/systemd/system/reset-home.service
[Unit]
Description=Reset home directory for vksuser
After=local-fs.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/scripts/reset-home.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable reset-home.service


#          Loginoptionen setzen

sed -i '/^\[LightDM\]/axserver-command = X -s 0 dpms' /etc/lightdm/lightdm.conf
sed -i '/^\[Seat\:\*\]/aautologin-user-timeout=0' /etc/lightdm/lightdm.conf
sed -i '/^\[Seat\:\*\]/aautologin-user='vksuser'' /etc/lightdm/lightdm.conf


#          Autostarter erstellen

mkdir -p /home/vksuser/.config/autostart

cat <<EOF | tee /home/vksuser/.config/autostart/vivaldi.desktop
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=Vivaldi
Hidden=false
Exec=/home/vksuser/start.sh
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
EOF

cat <<EOF | tee /home/vksuser/.config/autostart/show_version.desktop
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=Vivaldi
Hidden=false
Exec=/scripts/show_version.sh
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
EOF

cat <<EOF | tee /home/vksuser/.config/autostart/move_mouse.desktop
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=Mouse_Move
Hidden=false
Exec=/scripts/move_mouse.sh
StartupNotify=false
Terminal=false
EOF


chown -R vksuser:vksuser /home/vksuser/.config
chmod -R 755 /home/vksuser/.config
mv /usr/bin/light-locker /usr/bin/light-locker.nn
mkdir -p /home_template/vksuser
chown -R vksuser:vksuser /home_template/vksuser
rsync -a --delete /home/vksuser/ /home_template/vksuser/


# 		Kernel härten und Dumps deaktivieren

cat <<EOF > /etc/sysctl.d/99-kiosk-hardening.conf
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
kernel.unprivileged_userns_clone = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

echo "* hard core 0" >> /etc/security/limits.conf


# 		USB-Storage deaktivieren

cat <<EOF > /etc/modprobe.d/blacklist-usb.conf
blacklist usb_storage
blacklist uas
EOF

update-initramfs -u


#		sudo verbieten

deluser vksuser sudo

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "LoginGraceTime 30" >> /etc/ssh/sshd_config
systemctl restart ssh

# 		Schreibzugriffe minimieren

swapoff -a
grep -v swap /etc/fstab >/etc/fsnew
mv /etc/fsnew /etc/fstab
curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zxf -
cd log2ram-master
chmod +x install.sh && ./install.sh
cd ..
rm -r log2ram-master


# tempfs für Verzeichnisse setzen

echo "tmpfs /tmp tmpfs defaults,nosuid,nodev,size=100m 0 0">>/etc/fstab
echo "tmpfs /run tmpfs defaults,nosuid,nodev,size=20m 0 0">>/etc/fstab
echo "tmpfs /var/tmp tmpfs defaults,nosuid,nodev,size=50m 0 0">>/etc/fstab
echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,size=100m 0 0">>/etc/fstab


#          disable Script

systemctl disable firstboot.service
rm /etc/systemd/system/firstboot.service

sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
update-grub
update-initramfs -u


# 		aufräumen und apt sperren

mv /root/overlay.py /scripts/
cp /root/make_vks.sh /scripts
printf "Scriptversion - ">/scripts/version.txt
printf $(grep "# Version" /scripts/make_vks.sh | grep -v printf | tail -n 1 | cut -d ' ' -f3)>>/scripts/version.txt
apt clean
chmod 000 /usr/bin/apt
chmod 000 /usr/bin/apt-get

/sbin/init 6