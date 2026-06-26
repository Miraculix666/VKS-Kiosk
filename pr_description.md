🎯 **What:**
Removed hardcoded plaintext root and user passwords (`mussuändern` and `vksuser`) from `Linux/preseed.cfg` and `Windows/preseed.cfg`. Replaced the static entries with `passwd-crypted` directives containing placeholders. The build script (`shared_build.sh`) now interactively prompts for passwords during execution, or automatically generates secure, random base64 passwords if running headlessly. The passwords are then hashed securely (SHA-512) and injected dynamically into the `preseed.cfg` artifact.

⚠️ **Risk:**
By hardcoding the credentials in plaintext inside the repository's configuration files, any attacker with access to the codebase (or the generated ISO) could easily extract the default root and user passwords. This allowed unauthorized root access to any system installed using this ISO configuration.

🛡️ **Solution:**
- Modified `.env` to include commented-out password template variables instead of hardcoded fallbacks.
- Updated both `preseed.cfg` files to use `passwd/root-password-crypted` and `passwd/user-password-crypted` with placeholder values (`ROOT_PW_PLACEHOLDER`, `USER_PW_PLACEHOLDER`) and removed the plaintext `*-again` fields.
- Added `openssl` to all package manager installation lists in `shared_build.sh`.
- Added logic in `shared_build.sh` to prompt the user or generate random passwords via `openssl rand -base64 12`, ensuring passwords are securely gathered.
- Hashed the gathered passwords using `openssl passwd -6` and injected them dynamically into the `preseed.cfg` using `sed`.

Rationale for testing: Since this patch strictly modifies shell scripts and configuration injection used during the ISO build process, traditional Python unit testing is not applicable. The fixes were validated using `bash -n` syntax checks and mocked bash scripts to ensure the `openssl` random generation and hash injection logic behave correctly and securely.
