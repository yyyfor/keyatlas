# KeyAtlas · 键览

[English](README.en.md) · [简体中文](README.md#简体中文) · [Download](https://github.com/yyyfor/keyatlas/releases/latest)

KeyAtlas is a native macOS shortcut viewer. It gathers system shortcuts and shortcuts from apps you authorize into a clean, searchable overview. Filter by app, modifier or status; save favorites; inspect shared combinations; add manual records; export JSON; and test whether Fn reaches the app.

## Install and choose a language

1. Open the [latest release](https://github.com/yyyfor/keyatlas/releases/latest) and download **KeyAtlas-1.2.0-macOS-arm64.zip** from **Assets**. The “Source code” archives do not contain a ready-to-run app.
2. Unzip it and drag **键览.app** to **Applications**, then open it.
3. Requires **Apple Silicon and macOS 14 or later**. Validated on macOS 15.6.1. An Intel build is not currently provided.
4. The app is ad-hoc signed and **has not been notarized by Apple**. If macOS blocks it because the developer cannot be verified, first confirm that you trust the download, then follow [Apple’s instructions](https://support.apple.com/en-us/102445) to use **System Settings → Privacy & Security → Open Anyway**. Do not disable system-wide security protections.

Select **English** or **简体中文** using the language picker at the bottom of the sidebar. The interface changes immediately and remembers your choice. On first launch, a Chinese preferred system language selects Simplified Chinese; other languages select English.

Navigation, known system actions, permission dialogs, instructions and messages are translated. User-authored records and menu labels read from other apps retain their original wording. macOS file dialogs follow the system language. JSON exports keep the existing canonical field values so language changes do not alter data identity, favorites or permissions.

Only system shortcuts, shared menu settings and system services are read automatically on first launch. Third-party apps start with no permission. Choose each app and read method in **App access**.

| Shortcut | Action |
| --- | --- |
| `⌘F` | Search |
| `⌘R` | Refresh preferences |
| `⌘N` | Add a manual record |
| `⌘⇧E` | Export the filtered list |

Search supports `cmd+shift+3`, `⌘⇧3`, app names, and system action names in Chinese or English.

## Doubao IME, Raycast and per-app access

1. Open **App access** in the sidebar, then click **Allow…** next to an app.
2. Select its read methods: **Shortcut preferences**, **App menus**, or **Open shortcut settings page**. The third option appears only for supported adapters. Each method is independent.
3. Menu and settings-page reads additionally require you to allow KeyAtlas in **System Settings → Privacy & Security → Accessibility**. Basic preference reads do not require this. Full Disk Access, media access and Screen Recording are not needed.
4. For **Doubao IME**, open its Settings → Voice input page, leave it open, return to KeyAtlas and click **Read current page**. The adapter recognizes assigned hold-to-talk and hands-free combinations; unassigned placeholders are ignored.
5. For **Raycast**, press `⌘,` in Raycast to open Settings. General exposes the launcher shortcut. Extensions / Shortcuts may expose assigned combinations, but collapsed, unloaded or unexposed items are not covered. Reading a new page replaces that app’s previous settings-page snapshot.

**Permission boundary:** macOS grants Accessibility access to KeyAtlas as a whole. The operating system does not restrict it to individual target apps; KeyAtlas enforces those per-app and per-method limits. There is no default “allow all.” Revoking access stops future reads, removes matching automatic results, and discards stale asynchronous results. An already-started system call may briefly finish, but its result is not added. Manual records and files you previously exported remain.

Settings-page reading happens only when you click the button. It is limited to the Doubao IME settings helper and Raycast windows explicitly titled Settings/Preferences. Chat windows and editable text fields are excluded. Accessible text is processed temporarily in memory, and only parsed shortcuts are retained. The app does not decrypt Raycast’s database or request a full export.

The parser fixtures were checked against accessible fields from **Doubao IME 1.0.3** and **Raycast 1.104.32**. The complete capture path after granting KeyAtlas Accessibility access still needs on-device verification. App updates may require adapter changes. **Doubao IME and the Doubao desktop chat client are different apps**; the chat client has no dedicated settings-page adapter.

## Coverage and limitations

- **System:** reads symbolic hotkey settings through dynamically loaded, read-only SkyLight interfaces, falling back to saved preferences when unavailable. Known action IDs receive names; unknown saved actions retain their IDs. Defaults are never presented as observed settings. Private interfaces can change across macOS versions.
- **Preferences:** reads shared `NSUserKeyEquivalents`, system services and recognized KeyboardShortcuts / ShortcutRecorder formats from allowed third-party apps. Protected Apple preference files are skipped. Missing saved entries do not imply that an app has no default shortcuts. System results appear first; optional app scanning stops waiting after eight seconds.
- **Menus:** scans only allowed running apps when requested, with per-app and overall time limits. A menu snapshot reflects the current app and selection. Refreshing clears it. Hidden global shortcuts and hold/double-press triggers may not appear in menus.
- **Settings pages:** limited Doubao IME and Raycast adapters, without a claim of complete coverage. These results are marked **Set; activation unconfirmed** and excluded from conflict checks. Use **Unconfirmed** to filter them. In JSON, an omitted `enabled` value means unknown activation; a Boolean represents the observed state.
- **Manual records:** useful for unsupported/private storage formats and hidden shortcuts. KeyAtlas does not automatically update or verify them, or modify actual bindings.
- **Shared combinations:** compares enabled entries with matching triggers and potentially overlapping scopes. Shortcuts confined to different apps do not trigger a warning; unknown scopes are excluded. A shared combination does not prove a conflict or identify a process intercepting Fn.
- **Key labels:** virtual keys use ANSI labels. The system’s `fn` flag is preserved, even though some keyboards do not require an extra Fn press for navigation or function keys.
- **Privacy:** no network requests or uploaded preferences. The Fn test shows only the latest key while KeyAtlas is in front; it does not save keystrokes or listen in the background. Menu scanning accesses only the menu tree.

Permissions are stored at `~/Library/Application Support/KeyAtlas/app-consent.json`; unreadable permissions fail closed. Automatic results stay in memory. Favorites and the interface language use KeyAtlas’s preferences. Manual records are stored in `~/Library/Application Support/KeyAtlas/manual-shortcuts.json`, using atomic writes. Unreadable records are preserved and reported rather than overwritten.

## Build and verify

No third-party dependencies. Use Xcode / Command Line Tools with Swift 5.9 or later:

```sh
bash scripts/build.sh
bash scripts/test.sh
bash scripts/package.sh
```

The app is written to `build/键览.app`. Packaging produces a versioned ZIP and SHA-256 checksum containing only the app, excluding local shortcut snapshots, grants, manual records and build caches.

Read-only diagnostics respect saved app permissions:

```sh
build/键览.app/Contents/MacOS/KeyAtlas --diagnose --output /tmp/keyatlas.json
build/键览.app/Contents/MacOS/KeyAtlas --render-preview /tmp/keyatlas.png --page access --language en
```

Diagnostic snapshots contain local app and shortcut information; do not publish them with source code. Tests cover key encoding, sided modifiers and triggers, scope-aware duplicate detection, search, JSON round trips, persistence, permission defaults and revocation races, settings-page parsing, language persistence and data stability across language switches. See [VALIDATION.md](VALIDATION.md) for verification details.

## References

- [Apple: Keyboard settings](https://support.apple.com/guide/mac-help/-kbdm162/mac)
- [Raycast: Settings](https://manual.raycast.com/settings)
- [Raycast: Import and export](https://manual.raycast.com/import-export)
- [Apple: Accessibility API](https://developer.apple.com/documentation/applicationservices/1462060-axuielementcopyattributevalues)
- [LinearMouse: SymbolicHotKey implementation](https://github.com/linearmouse/linearmouse/blob/main/Modules/KeyKit/Sources/KeyKit/SymbolicHotKey.swift)
- [System action ID reference](https://github.com/andyjakubowski/dotfiles/blob/main/AppleSymbolicHotKeys%20Mappings)

KeyAtlas does not link the private framework as a required dependency and does not register or change system hotkeys.
