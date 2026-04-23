# FILE: README.md
# PURPOSE: Main project documentation
# LAST MODIFIED: 2026-04-23T11:41:00Z
# MODIFIED BY: Antigravity AI
# BRANCH: main

# VKS-Kiosk 📺

VKS-Kiosk is a lightweight, securely locked-down Linux environment designed exclusively for Video Conferencing System (VKS) usage. It runs as a live medium (e.g., from a USB drive) and provides a secure, single-purpose browser environment for WebRTC-based conferencing platforms.

## Features

- **Live Medium**: Boots directly from USB, minimizing persistent state and ensuring a clean environment every time.
- **Kiosk Mode**: Uses Chromium in strict kiosk mode without address bars or navigation controls.
- **Silent Hardware Access**: Chrome Enterprise Policies automatically grant camera and microphone access to predefined conferencing URLs, bypassing user prompts.
- **Locked-down Environment**: Minimal window manager (e.g., Openbox), restricted TTY switching, and no shell access for the standard user.
- **Debug Boot Entry**: A separate boot option allows system administrators to access a root shell, unrestricted network, and debugging tools.
- **Import/Dump**: Supports importing existing development states via the `dump/` directory.

## Architecture

This project follows the universal agent framework structure defined in `MASTER_INSTRUCTIONS.md`.

- `src/` - Contains the build scripts and policy configurations.
- `docs/` - Project documentation, changelogs, and dependency tracking.
- `memory/` - Agent context and architectural decision logs.
- `dump/` - Daily import/export folder for temporary states.

## Getting Started

*(Documentation to be expanded as the build scripts are finalized.)*

1.  Clone the repository.
2.  Review `docs/DEPENDENCIES.md` for required build tools.
3.  Run the primary build script located in `src/` to generate the ISO/Live USB image.

---
*Created with 💙 by Antigravity AI*
