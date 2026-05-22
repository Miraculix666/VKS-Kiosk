1. **Enhance Vivaldi Startup Parameters:**
   - Modify the payload scripts (`make_vks_*.sh` in Linux/Windows/Raspi) to incorporate the recommended Vivaldi flags: `--kiosk`, `--incognito`, `--use-fake-ui-for-media-stream`, `--autoplay-policy=no-user-gesture-required`, and `--check-for-update-interval=31536000`. This ensures WebRTC media (mic/cam) starts without permission prompts and no user data is stored, which is critical for a public kiosk.

2. **Review Target Device Formatting Logic (USB Selection):**
   - The user states: "beachte das mehrere sticks gesteckt sin könnnen auswahl mit anzeige des typs grösse partitionen. so bauen das hinterher ein direkt nutzbares livelinux ISO entsteht mit button zum lokalen installieren".
   - Our `shared_build.sh` already handles multiple sticks (`lsblk`), shows sizes, type, and prompts with `whiptail`. I will review the `lsblk` command to ensure it shows partitions/model more clearly.
   - For "direkt nutzbares livelinux ISO entsteht mit button zum lokalen installieren" (directly usable live linux ISO with button for local install): we've already added `Linux/make_live_iso.sh` that builds a true live ISO. In the live system, we need a "Button" (e.g. desktop shortcut) to install the system locally. I will add an `install_to_hdd.desktop` to the `vksuser` desktop in the `make_live_iso.sh` configuration, invoking a simple installer (e.g. `calamares` or a custom `dd` script).
   - Note: Debian `live-build` provides `calamares-settings-debian` for graphical installs from the live ISO. I will include `calamares` in the `make_live_iso.sh` packages.

3. **Check xfce-kiosk configurations:**
   - Since the github repo `PhilGoud/xfce-kiosk` didn't resolve directly via raw curl, I will do a quick google search or check my knowledge base for standard xfce kiosk harding (e.g., locking panels, disabling right-click, disabling window manager hotkeys).
   - I'll add some basic XFCE kiosk hardening directly to the `make_vks_*.sh` scripts (e.g. `xfconf-query` to lock panels and remove desktop icons).

4. **Sync with github:**
   - Make sure no AI traces are left, clean up temp files, and finally push changes.
