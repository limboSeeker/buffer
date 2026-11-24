# Buffer

Clipboard history for macOS. Lives in the menu bar, opens with ⌥V.

## Features

- ⌥V opens the history next to the cursor. Type to search, ↑↓ to move, ↩ or click to pick.
- The picked item is pasted into the field you were typing in (can be turned off in the menu).
- Text and images, screenshots copied to the clipboard included.
- Up to 200 items. Pinned items are never pushed out.
- Items marked as concealed by password managers are skipped.
- Optional launch at login.

| Key | Action |
| --- | --- |
| ⌥V | open / close |
| ⌘1–9 | pick item 1–9 |
| ⌘P | pin / unpin |
| ⌘⌫ | delete |
| esc | close |

## Build

Requires macOS 14+ and Xcode command line tools.

```bash
./scripts/build-app.sh --install   # builds Buffer.app, copies to /Applications, launches it
swift test
```

Auto-paste needs Accessibility access: System Settings → Privacy & Security → Accessibility → Buffer. The app is ad-hoc signed, so macOS forgets this permission after every rebuild. Remove Buffer from the list and add it again.

## Files

- History: `~/Library/Application Support/Buffer/`
- Log: `~/Library/Logs/Buffer.log` (no clipboard contents)
