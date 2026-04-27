# VKS-Kiosk 📺

VKS-Kiosk ist ein sicheres, minimalistisches und stark eingeschränktes Linux-Live-System (Debian-basiert), das speziell für den Einsatz als Video Conferencing System (VKS) auf Thin Clients (z.B. Fujitsu Futro) entwickelt wurde. Es bootet als Live-Medium von einem USB-Stick und startet einen vorkonfigurierten Browser im Kiosk-Modus ohne Adressleiste und Navigation.

## 🌟 Features

- **Live-Medium:** Bootet direkt vom USB-Stick. Keine Installation auf der internen Festplatte notwendig. Änderungen sind nach einem Neustart verworfen (flüchtig).
- **Kiosk-Modus:** Der Browser startet bildschirmfüllend und ausbruchssicher.
- **Auto-Zulassung (Policies):** Mikrofon und Kamera werden durch Unternehmensrichtlinien (Policies) automatisch für festgelegte Konferenz-URLs freigegeben – keine störenden Popups.
- **Härtung:** Extrem reduzierter Fenstermanager (Openbox), keine TTY-Konsolen für den Standardnutzer, keine Shell.
- **Debug-Modus:** Ein spezieller Boot-Eintrag ermöglicht Administratoren den Zugriff als `root` für Wartungs- und Netzwerkanalyse-Aufgaben.

---

## 🛠️ Erstellung des USB-Sticks (Build-Prozess)

Du kannst den Kiosk-Installations-Stick entweder direkt unter **Linux** oder unter **Windows 10/11 (mit WSL)** erstellen. Das Skript lädt automatisch die aktuellste Debian-`netinst.iso` herunter, injiziert die Kiosk-Skripte und brennt sie auf deinen USB-Stick.

> [!CAUTION]
> **ACHTUNG:** Das Skript formatiert den angeschlossenen USB-Stick unwiderruflich! Stelle sicher, dass du den richtigen Stick angeschlossen hast und keine wichtigen Daten darauf sind. Sticks **über 128 GB** werden zur Sicherheit ignoriert.

### Methode A: Windows (via WSL2 & PowerShell)

Für die Erstellung unter Windows wurde eine automatisierte Strecke mittels Windows Subsystem for Linux (WSL) und `usbipd` entwickelt, welche den USB-Stick an die Linux-Umgebung durchreicht.

**Voraussetzungen:**
- Windows 10/11
- Ein USB-Stick (max. 128 GB)

**Schritt-für-Schritt Anleitung:**

1. **PowerShell als Administrator öffnen!**
   Rechtsklick auf das Startmenü -> *Windows PowerShell (Administrator)* oder *Terminal (Administrator)*. Dies ist zwingend notwendig, da das Tool `usbipd` tiefe Systemrechte benötigt, um den USB-Stick zu entkoppeln.

2. **In das Windows-Verzeichnis des Repositories wechseln:**
   ```powershell
   cd C:\GitHub\VKS-Kiosk\Windows
   ```

3. **Das PowerShell-Vorbereitungsskript ausführen:**
   ```powershell
   .\ichwillaberwindows.ps1
   ```
   *Was passiert hier?*
   - Das Skript installiert (falls nötig) WSL und das Tool `usbipd-win`.
   - Es sucht nach deinem USB-Stick (Massenspeicher) und reicht diesen an WSL durch.
   - Es erstellt einen Junction-Link (Ordner-Verknüpfung) in deinem Windows-Benutzerprofil, damit WSL direkt auf die Dateien zugreifen kann.
   - Es öffnet anschließend automatisch die Linux-Shell (Debian).

4. **In der Linux-Shell (WSL) den Build starten:**
   Sobald du das Linux-Terminal siehst (`VKS@...$`), starte das ISO-Build-Skript:
   ```bash
   sudo ./make_install_wsl.sh
   ```
   *(Tipp: Wenn du nach dem `sudo` Passwort für den Benutzer gefragt wirst und dieses nicht kennst, starte WSL alternativ direkt mit `wsl -d Debian -u root` aus der PowerShell).*

5. **Bestätigen und Warten:**
   Das Skript lädt Debian herunter, entpackt es, injiziert das Kiosk-Setup und flasht alles auf den Stick. Wenn der Vorgang abgeschlossen ist, kannst du den Stick abziehen und den Futro damit booten.

#### 💡 Fehlerbehebung (Windows/WSL)
- **Fehler: "keine geeignete SD-Karte gefunden"**
  WSL konnte deinen USB-Stick nicht sehen. Breche ab (`exit`) und stelle sicher, dass du das PowerShell-Skript *als Administrator* ausgeführt hast. Manchmal hilft es, den Stick kurz abzuziehen, neu einzustecken und das `.ps1` Skript erneut zu starten.
- **Fehler: "Permission denied / Unable to acquire the dpkg frontend lock"**
  Du hast in der Linux-Konsole das Wort `sudo` vor `./make_install_wsl.sh` vergessen.
- **Fehler: Rote Fehlermeldungen über Berechtigungen und `sysctl.d`**
  Du hast versehentlich `make_vks_*.sh` auf deinem Host-Computer ausgeführt! Dieses Skript darf **nur** vom fertigen USB-Stick auf dem Thin-Client (Futro) ausgeführt werden.

---

### Methode B: Natives Linux

Wenn du ein natives Ubuntu oder Debian nutzt, ist der Prozess noch einfacher.

1. **Abhängigkeiten installieren:**
   Das Skript installiert benötigte Tools (`syslinux`, `xorriso`, `7zip`, etc.) automatisch per `apt`.

2. **Build-Skript starten:**
   Wechsle in den Ordner `Linux` und starte das Skript:
   ```bash
   cd C:\GitHub\VKS-Kiosk\Linux
   sudo ./make_install.sh
   ```

3. Das Skript identifiziert deinen USB-Stick, baut die ISO zusammen und brennt diese.

---

## 📂 Datei- & Skript-Übersicht

- `Windows/ichwillaberwindows.ps1`: Bereitet die Windows-Umgebung vor, reicht den USB-Stick via `usbipd` durch und startet WSL im korrekten Kontext.
- `Windows/make_install_wsl.sh` / `Linux/make_install.sh`: Das **Builder-Skript**. Es modifiziert die originale Debian ISO und macht daraus den bootfähigen VKS-Installations-Stick.
- `make_vks_v*.sh`: Das **Payload-Skript**. Dies ist die tatsächliche Magie, die auf dem Thin-Client ausgeführt wird. Es installiert den Kiosk-Browser, härtet das System und richtet `log2ram` ein.
- `preseed.cfg`: Die Auto-Antwort-Datei (Unattended Setup) für den Debian-Installer, damit während der Installation keine Benutzereingaben notwendig sind.
- `overlay.py`: Python-Skript (wird vom preseed aufgerufen), welches das finale Kiosk-Setup nach der Grundinstallation orchestriert.
- `grub.cfg`: Konfiguriert den Bootloader auf dem USB-Stick (Normaler Boot vs. Debug Boot).

---
*Created with 💙 by Antigravity AI*
