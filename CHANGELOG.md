# Changelog

## 1.3.0 - 2026-06-30

- Added a `Codex Arabic RTL` desktop shortcut that launches Codex with its local debugging endpoint enabled.
- Fixed installations where the patch was running but could not reach a normally launched Codex window.
- Recreates the version-independent shortcut after patch and Microsoft Store updates.

## 1.2.3 - 2026-06-30

- Preserved both Windows startup entries when enabling automatic updates.
- Fixed option 2 replacing the patch watcher's startup value.

## 1.2.2 - 2026-06-30

- Changed automatic updates to download one atomic GitHub release ZIP.
- Prevented mixed-version files caused by raw-file CDN propagation delays.

## 1.2.1 - 2026-06-30

- Fixed automatic updater download URLs in Windows PowerShell.
- Validated a complete remote upgrade using the public GitHub repository.

## 1.2.0 - 2026-06-30

- Added Arabic RTL handling for full Codex reply containers.
- Added a PowerShell menu for install, automatic updates, and uninstall.
- Added a user-level GitHub update checker that runs every six hours when enabled.
- Replaced the Node.js watcher with a dependency-free PowerShell/.NET watcher.
- Added automatic reapplication after Codex restarts and Microsoft Store updates.
- Added public download documentation and beta/testing notices.
