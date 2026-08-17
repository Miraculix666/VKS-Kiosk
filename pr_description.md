🎯 **What:**
Replaced the `--password-store=basic` flag with the secure `--password-store=gnome` flag for the Chromium browser in `Raspi/make_vks.sh`.

⚠️ **Risk:**
The Chromium browser was configured to use `--password-store=basic`. This stored any saved passwords in plaintext on the disk rather than leveraging a secure keyring or keychain manager. If a malicious user gained access to the local filesystem (even with a non-root user account), they could easily read all saved passwords from the browser profile.

🛡️ **Solution:**
- Modified `Raspi/make_vks.sh` to use `--password-store=gnome`.
- `gnome-keyring` is already listed in the package install line (`apt install ... gnome-keyring -y`), so the required system dependency for this secure password store is present.
- The `make_vks.sh` script installs and runs chromium as a kiosk, which previously used basic auth storage.
