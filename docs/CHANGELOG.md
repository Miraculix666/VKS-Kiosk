# VKS-Kiosk Changelog

## [2.0.0] - 2024
### Added
- **Central `.env` File:** All core variables (`MAX_USB_SIZE_GB`, `DEBIAN_ISO_URL`, etc.) are now centralized in `.env`.
- **`shared_build.sh`:** Extracted the duplicate logic from Linux and Windows builder scripts into a single, unified backend script. This ensures consistency and easier maintenance.
- **Modern Terminal UI:** Integrated `whiptail` (with standard Bash read fallbacks) for visually appealing, fast, and secure user menus, particularly during the critical USB selection phase.
- **Cross-Distribution Support:** Improved dependency resolution logic. Future updates will extend the package manager support beyond `apt` to `dnf` (Fedora) and `zypper` (SUSE).
- **Explicit Boot Menu Options:** Updated `grub.cfg` to explicitly distinguish between "Install VKS-Kiosk (Automated)" and "Debian Live/Rescue (Manual)".

### Changed
- **Script Refactoring:** Rewrote `Linux/make_install.sh` and `Windows/make_install_wsl.sh` to act as simple wrappers that source `shared_build.sh`. This removes 90% of redundant code.
- **Safety First:** Enhanced device querying (`lsblk`) now explicitly filters out loop/ram devices, shows the device model, validates against `MAX_USB_SIZE_GB`, and strictly requires a `yesno` confirmation before running `dd` or `sfdisk`.
- **WSL Path Handling:** Kept the Windows-specific WSL to `C:\` path translation logic in `make_install_wsl.sh` for user convenience.

### Why these changes were made:
- **Portability:** The user requested that the scripts run on nearly any Linux (Debian, Suse, Fedora, Ubuntu) and Win (WSL). Centralizing logic and providing fallbacks ensures it works universally.
- **Safety & Clarity:** Flashing drives is dangerous. Clear, undeniable UI prompts (`whiptail`) prevent catastrophic data loss (e.g., wiping the internal drive).
