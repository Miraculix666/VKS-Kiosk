1. **Update Vivaldi Startup Parameters (Linux)**
   - Use a bash script to iterate over `Linux/make_vks_v*.sh` and `Windows/make_vks_v*.sh` and `Raspi/make_vks.sh` to update the Vivaldi command line.
   - Replace `--enable-gpu --ignore-gpu-blocklist --gpu-rasterization --enable-oop-rasterization --no-first-run` with `--kiosk --incognito --use-fake-ui-for-media-stream --autoplay-policy=no-user-gesture-required --check-for-update-interval=31536000 --enable-gpu --ignore-gpu-blocklist --gpu-rasterization --enable-oop-rasterization --no-first-run`.
   - Verify changes using `cat`.

2. **Enhance USB Selection Display in `shared_build.sh`**
   - Use `replace_with_git_merge_diff` on `shared_build.sh`.
   - Update `lsblk -dpno NAME,SIZE,TRAN,MODEL` to `lsblk -pno NAME,SIZE,TRAN,MODEL,FSTYPE` to also show partitions and filesystems.
   - Verify the update using `read_file`.

3. **Add Live-Build Installer Button (`make_live_iso.sh`)**
   - Use `replace_with_git_merge_diff` to add `calamares calamares-settings-debian` to the `lb config` package list in `Linux/make_live_iso.sh`.
   - Add bash logic to create `/home/vksuser/Desktop/Install.desktop` pointing to `sudo calamares` inside the chroot hook.
   - Verify using `read_file`.

4. **Add XFCE Kiosk Hardening**
   - Use a bash loop to append XFCE hardening commands to the first-boot scripts (e.g. `xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0`).
   - Actually, since `make_vks*.sh` runs as root, setting user configurations via `xfconf-query` requires `su - vksuser -c`.
   - I will append this logic just before the script finishes setting up the user.
   - Verify using `cat`.

5. **Test syntax**
   - Run `bash -n Linux/make_live_iso.sh`, `bash -n shared_build.sh`, and the modified payload scripts.

6. **Complete pre commit steps**
   - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.
