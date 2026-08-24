# ChatGPT Arabic RTL Patch

An unofficial, user-level Arabic right-to-left patch for the ChatGPT desktop app on Windows (formerly the Codex desktop app).

> **Testing status:** This project is currently in beta/testing. ChatGPT UI updates may expose edge cases. Please report problems through [GitHub Issues](https://github.com/ammaryaser99/codex-arabic-rtl-patch/issues).

It automatically detects Arabic-first content and fixes the direction and alignment of:

- ChatGPT replies and user messages
- The message composer
- Lists, headings, quotes, and tables
- Arabic and mixed Arabic/English sidebar titles
- Independent direction detection for each message and text block
- Automatic LTR isolation for English runs and file paths inside Arabic text

English-heavy text stays automatic/LTR, and code, terminal, file-path, and editor content remain LTR inside Arabic messages.

## Download and install

1. Open the [latest release](https://github.com/ammaryaser99/codex-arabic-rtl-patch/releases/latest).
2. Download `Codex-Arabic-RTL-Patch.zip`.
3. Extract the ZIP file.
4. Double-click `ChatGPT RTL Menu.cmd`.
5. Choose `1` to install the patch.
6. Choose `2` if you also want automatic patch updates.
7. Close ChatGPT and launch it from the new **ChatGPT Arabic RTL** desktop shortcut.

No administrator rights are required.

> **Important:** Use the `ChatGPT Arabic RTL` desktop shortcut. A normal ChatGPT shortcut may launch the app without the local debugging endpoint required by this user-level patch.

## PowerShell menu

```text
1. Install / repair patch
2. Enable automatic patch updates
3. Uninstall patch
0. Exit
```

## How automatic updates work

There are two separate protections:

1. The local watcher starts with Windows and reconnects whenever ChatGPT starts, restarts, or is updated by the Microsoft Store. It reapplies the installed RTL patch automatically.
2. When option `2` is enabled, a user-level background updater checks this GitHub repository every six hours. If a newer patch version is published, it downloads the new files and restarts the watcher.

Choose option `3` in the menu whenever you want to check GitHub immediately instead of waiting for the next six-hour check.

The `ChatGPT Arabic RTL` desktop shortcut also checks both background processes on every launch and restarts either one if Windows stopped it.

This matters because a future ChatGPT UI update may rename internal elements. The watcher handles normal app restarts automatically; the GitHub updater delivers compatibility fixes when the patch itself needs to change.

## Composer controls

- `Ctrl + Right Shift`: force RTL
- `Ctrl + Left Shift`: force LTR

Normally, direction is classified independently for each text block using its Arabic/English character balance.

## Safety and removal

- The signed Microsoft Store ChatGPT package is never modified.
- Files are installed only under `%LOCALAPPDATA%\ChatGPTArabicRTL`.
- Startup entries are stored under the current user's Windows Run key.
- Option `3` removes the installed files, watcher, updater, and startup entries.
- Option `3` also removes the `ChatGPT Arabic RTL` desktop shortcut.

After uninstalling, restart ChatGPT to clear the already-injected styles from the current window.

## Requirements

- Windows 10 or Windows 11
- ChatGPT desktop app with its local debugging endpoint enabled
- Internet access is required only for automatic patch updates

## Disclaimer

This is an unofficial community patch and is not affiliated with or supported by OpenAI. ChatGPT updates may require a newer patch release.

## Acknowledgements

Version 1.4.0 incorporates ideas from community feedback and [Codex RTL Toolkit](https://github.com/pawnsmaster/codex-rtl-toolkit). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution and license details.

## License

[MIT](LICENSE)
