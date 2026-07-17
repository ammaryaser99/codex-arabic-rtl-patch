# Changelog

## 1.5.5 - 2026-07-16

- Migrates existing v1.4.2 auto-update users from `CodexArabicRTL` to `ChatGPTArabicRTL`.
- Keeps the automatic updater working after Windows restarts during the product-name transition.
- Restricts the update manifest to safe runtime filenames so legacy updaters accept the release.
- Adds a menu option to check GitHub for updates immediately.

## 1.5.4 - 2026-07-16

- Launches the Microsoft Store/MSIX build through Windows packaged-app activation.
- Fixes `Access is denied` failures when the updated package blocks direct `ChatGPT.exe` startup.
- Preserves the remote-debugging arguments required by the RTL watcher.

## 1.5.3 - 2026-07-16

- Refreshes the desktop shortcut after ChatGPT Microsoft Store updates.
- Prevents repeated shortcut clicks from racing and terminating the replacement app.
- Replaces slow proxy-aware localhost probes with fast direct debugging checks.
- Waits for the previous ChatGPT process tree to exit before starting the RTL instance.
- Records hidden launcher failures in `launcher.log` and opens ChatGPT normally as a fallback.

## 1.5.2 - 2026-07-12

- Suppresses internal PowerShell async return values so the hidden watcher stays completely silent.

## 1.5.1 - 2026-07-12

- Connects to the ChatGPT debugging endpoint through `localhost`, supporting releases that listen on IPv6 loopback (`::1`) instead of IPv4 (`127.0.0.1`).

## 1.5.0 - 2026-07-12

- Supports the renamed ChatGPT Windows app and its new `ChatGPT.exe` executable.
- Detects both the current ChatGPT executable and the legacy Codex executable.
- Creates a `ChatGPT Arabic RTL` desktop shortcut and migrates legacy startup entries and files.
- Keeps the existing GitHub release/update channel compatible.

## 1.4.2 - 2026-07-07

- Makes the `Codex Arabic RTL` launcher restart the watcher whenever it is missing.
- Restarts the auto-update loop when enabled but no longer running.
- Verifies that the DevTools endpoint belongs to a Codex renderer before treating it as ready.
- Fixes cases where Codex launched on port 9223 but the RTL style was never injected.

## 1.4.1 - 2026-07-01

- Adds cache-busting to GitHub release checks so newly published versions are detected immediately.

## 1.4.0 - 2026-07-01

- Classifies direction independently per message and per text block.
- Keeps English-heavy mixed blocks in automatic direction instead of forcing the whole block RTL.
- Isolates English runs and plain-text file paths as LTR inside Arabic content.
- Expands LTR protection for code, highlighted syntax, terminals, and Monaco editor content.
- Removes parent-message alignment rules that could override English child blocks.
- Processes new and changed DOM nodes incrementally to reduce repeated full-page scans.
- Inspired by community feedback and a comparison with [Codex RTL Toolkit](https://github.com/pawnsmaster/codex-rtl-toolkit).

## 1.3.1 - 2026-07-01

- Detects Arabic anywhere in mixed Arabic/English text instead of relying on the first strong character.
- Adds dynamic text-node detection for Codex content rendered outside the original selectors.
- Improves bidirectional isolation while keeping inline code, code blocks, and terminal output LTR.
- Explicitly restores left alignment for English-only content.
- Community contribution by [@omar6060](https://github.com/omar6060) in pull request #1.

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
