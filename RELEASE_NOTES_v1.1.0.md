# EdgeSafariSync v1.1.0 Release Notes

**Release date**: 2026-09-30
**Build**: 2
**Compatibility**: macOS 13.0+

## 📥 Download

| File | Size | SHA256 |
|------|------|--------|
| [`EdgeSafariSync_Installer_v1.1.0.dmg`](../../releases/tag/v1.1.0) | 2.1 MB | `dc992c0bbf98796134e9b06fa1bcf40b31d4614070cd03f68014d946e69d05ab` |

## 🎯 What's Fixed

v1.1.0 is primarily a **bug-fix release** that resolves critical sync failures on macOS 14+ (Sonoma) and macOS 26 (Tahoe), which is the recommended upgrade for all users who have experienced sync failures.

### 🔴 Critical: Sync no longer fails silently on macOS 14+/Tahoe

In v1.0.0, users running macOS 14+ or later with iCloud Safari sync enabled reported that:
- The sync button reported "Success" (green status) but Safari bookmarks were not actually updated
- After manually disabling iCloud Safari sync, sync still failed or corrupted the bookmarks file
- Some users lost their Safari bookmarks entirely (the .bak file was the only recovery option)

**Root cause**: Apple introduced an NSKeyedArchiver-encoded format for `~/Library/Safari/Bookmarks.plist` whenever iCloud sync is active. v1.0.0 read this format as a regular dictionary and re-wrote it as a plain plist, which Safari refused to load. The "success" status was actually a silent write failure.

**v1.1.0 fix**:
- New `isSafariPlistKeyedArchive(data:)` detects the NSKeyedArchiver format by probing for `$archiver` / `$objects` keys
- If detected, the app **aborts the sync** and presents a clear, actionable error message in English and Chinese, walking users through the temporary iCloud sync disable + format conversion procedure
- A new `ensureSafariPlistTopLevel()` function guarantees `WebBookmarkFileVersion`, `WebBookmarkType`, `WebBookmarkUUID`, and `Children` keys are present, preventing Safari from rebuilding the file from scratch (which would destroy all bookmarks)

### 🔴 Critical: Safari → Edge no longer destroys existing Edge bookmarks

In v1.0.0, "Safari → Edge" sync was documented as "non-destructive import" but the code actually **replaced** all of Edge's bookmark_bar children. This destroyed carefully organized Edge bookmarks every time the user ran the sync.

**v1.1.0 fix**:
- Safari → Edge now creates an `"Imported from Safari"` folder at the end of Edge's bookmark bar
- If such a folder already exists from a previous sync, new bookmarks are appended (deduplicated by URL)
- Edge's original bookmarks are **never modified or removed**

### 🟠 Bug: Edge would silently drop bookmarks with timestamp "0"

In v1.0.0, Safari → Edge sync wrote `date_added = "0"` and `date_modified = "0"` for every imported bookmark. Chrome/Edge treats these as "never" and silently drops the entries in some configurations.

**v1.1.0 fix**:
- New `webkitTimestamp(now:)` function generates proper Chrome/Edge timestamps (microseconds since the 1601-01-01 Windows epoch)
- All imported bookmarks now have valid timestamps and are guaranteed to display in Edge

### 🟠 Bug: Repeated syncs changed every bookmark's UUID

In v1.0.0, every bookmark's UUID was regenerated as a new random UUID on each sync. Safari treated this as "delete all old bookmarks + add new ones", losing user sort/grouping and filling the bookmarks UI with duplicates.

**v1.1.0 fix**:
- New `stableSafariUUID(from:)` generates a **deterministic UUID v5** from the source UUID + a fixed namespace
- Re-syncing the same bookmark produces the same UUID, so Safari recognizes it as the same entry and preserves sort/grouping

### 🟠 Improvement: More accurate permission error classification

In v1.0.0, ANY file-not-readable error was reported as "Permission denied", making it hard to distinguish actual TCC permission failures from other problems (file not found, locked by another process, etc.).

**v1.1.0 fix**:
- `FileValidator.swift` now performs an actual `open()` syscall and includes the `errno` in error messages
- `SyncEngine.swift` only classifies `EACCES`/`EPERM` as permission errors; other errors are reported as validation failures with the real cause visible

### 🟠 Improvement: Edge detection covers Beta / Dev / Canary / Insider

In v1.0.0, the detector only recognized `com.microsoft.edgemac` and "Microsoft Edge". Users on Beta / Dev / Canary channels were not detected and could corrupt their bookmarks by syncing while Edge was open.

**v1.1.0 fix**:
- `BrowserProcessDetector.swift` now recognizes all `com.microsoft.edgemac.*` bundle IDs and any "Microsoft Edge *" localized name

### 🟠 Improvement: Backup directory moved out of SIP/TCC-protected paths

In v1.0.0, backups were created next to the source file (`~/Library/Safari/Bookmarks.plist.bak`). On macOS 14+/Tahoe, writing to this directory requires Full Disk Access and sometimes fails silently.

**v1.1.0 fix**:
- Backups now go to `~/Library/Application Support/EdgeSafariSync/backups/<source-filename>.bak[.timestamp]`
- This directory is not SIP-protected and never requires additional permissions

## 📦 Installation

1. Download `EdgeSafariSync_Installer_v1.1.0.dmg` from the link above
2. Open the DMG and drag `EdgeSafariSync.app` into `/Applications`
3. Launch the app from `/Applications` (not from the DMG)
5. Grant Full Disk Access when prompted: **System Settings → Privacy & Security → Full Disk Access → EdgeSafariSync** (must check the box)
6. Click the ↔️ icon in the menu bar and follow the [Usage Guide](../../#使用指南)

## 🔄 Upgrade from v1.0.0

- Your existing bookmarks are **not** affected by the upgrade
- If you previously lost bookmarks due to v1.0.0 bugs, restore from your `.bak` file (created automatically by v1.0.0 in `~/Library/Application Support/EdgeSafariSync/backups/` if you ran a successful sync before, or `~/Library/Safari/Bookmarks.plist.bak` for older versions)
- After upgrading, **temporarily disable iCloud Safari sync** before running any sync (see [README](../../#同步前提))

## 🐛 Known Issues

- The app cannot sync when iCloud Safari sync is enabled (Apple's NSKeyedArchiver format is not editable by external tools). The app now detects this and provides clear instructions.
- ad-hoc signed installer (no Apple Developer ID). First launch may require right-click → Open to bypass Gatekeeper.
- Requires Full Disk Access on every fresh install.

## 🙏 Acknowledgements

Thanks to early users who reported the macOS 14+/Tahoe sync failures and provided detailed error reproduction steps.

## 📝 License

GPLv3 - see [LICENSE](../../blob/main/LICENSE).