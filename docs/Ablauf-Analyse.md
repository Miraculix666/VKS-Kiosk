# Analyse des aktuellen Ablaufs (VKS-Kiosk System)

Das VKS-Kiosk System nutzt aktuell ein zweistufiges Installationsverfahren (Debian Netinst + Preseed), um ein vollautomatisiertes, stark eingeschränktes Kiosk-System auf einem Zielgerät (Futro) aufzusetzen.

## Bisheriger Ablauf (Linux/Windows x86_64)

1. **Vorbereitung / Builder-Skripte (`make_install.sh` / `make_install_wsl.sh`)**
   - Das Skript läuft auf einem Host-PC (Linux oder Windows WSL).
   - Es installiert Werkzeuge (`xorriso`, `syslinux`, `7zip`).
   - Es lädt die aktuellste **Debian `netinst` ISO**.
   - Die ISO wird entpackt. Das System injiziert das Unattended-Setup (`preseed.cfg`), das eigentliche Konfigurationsskript (`make_vks.sh`) und das Overlay-Skript (`overlay.py`) direkt in die `initrd.gz` (die anfängliche RAM-Disk des Debian Installers).
   - Die veränderte ISO wird wieder zusammengepackt (`xorriso`) und mittels `dd` auf einen USB-Stick geschrieben.

2. **Boot vom USB-Stick (Target Device)**
   - Der USB-Stick wird in das Zielgerät gesteckt.
   - Grub lädt den Kernel und die manipulierte `initrd`.
   - Die `preseed.cfg` steuert den **Debian Installer (d-i)** fern. Sie weist den Installer an:
     - Die gesamte Festplatte unangefochten zu löschen und automatisch zu partitionieren (`guided - use entire disk`, `atomic`).
     - Debian minimal ohne Desktop-Environment, aber mit SSH, zu installieren.
     - Einen Benutzer `vksuser` mit sudo/audio-Rechten anzulegen.
   - Am Ende der Installation (via `preseed/late_command`) kopiert der Installer die Skripte `make_vks.sh` und `overlay.py` in das installierte Dateisystem (`/target/root/`).
   - Er richtet einen systemd-Service `firstboot.service` ein, der beim ersten Start des neuen Systems automatisch anläuft.

3. **Der First-Boot (Die Magie von `make_vks.sh`)**
   - Das Zielgerät bootet neu (jetzt vom internen Speicher).
   - `firstboot.service` führt `make_vks.sh` aus.
   - Das Skript:
     - Aktualisiert das System und installiert XFCE4, Vivaldi (Browser), Netzwerk-Tools (`lldpd`), und `log2ram`.
     - Konfiguriert den Autostart, härtet den Kernel, schaltet USB-Speicher ab, setzt restriktive Firewall-Regeln (nftables).
     - **Crucial:** Es konfiguriert `fstab` und erstellt einen `overlay.mount` Service, wodurch das System ab dem nächsten Neustart in einem `tmpfs` (RAM-Overlay) läuft. Jegliche Änderungen am Dateisystem gehen nach einem Neustart verloren (Live-Charakteristik).
   - Nach Abschluss deaktiviert sich das Firstboot-Skript selbst und das System startet neu.

## Bewertung bzgl. "Live vs. Installation"

Das Ziel "direkter Boot in die VKS Umgebung oder Installation auf dem Zielgerät" ist mit dem aktuellen Setup (`netinst` + `preseed`) nur bedingt möglich.

- **Warum?** Die `netinst` ISO enthält gar kein fertiges Betriebssystem, sondern nur den Installer. Das eigentliche System wird erst *während* der Installation aus dem Internet heruntergeladen, und der Kiosk wird erst *nach* der Installation durch `make_vks.sh` gebaut.
- **Die Lösung (Bester Weg): Debian Live Build (Custom Live ISO)**
  Um einen *echten* Live-Boot (vom Stick) zu ermöglichen, von dem aus man optional auf das Zielgerät installieren kann (wie bei Ubuntu/Debian Live), muss das Paradigma geändert werden. Wir dürfen nicht den Installer modifizieren, sondern müssen mit Tools wie `live-build` eine fertige SquashFS-Imagedatei erstellen, die bereits den Vivaldi-Browser, XFCE und die Härtung enthält.
  Dieses ISO kann dann vom Stick gebootet werden. Der Installer ("Install to Disk") wäre dann Calamares oder der Debian-Live-Installer, der das Live-Dateisystem 1:1 auf die Platte kopiert.

Da dies ein massiver Architekturwechsel ist, der das gesamte Projekt auf den Kopf stellt, wurde als Zwischenschritt die Architektur vereinheitlicht (`shared_build.sh`) und das UI stark verbessert. Der nächste strategische Schritt für ein echtes "Live oder Install" wäre der Wechsel auf `live-build` (für x86) bzw. `pi-gen` (für ARM).
