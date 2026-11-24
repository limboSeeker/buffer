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

## Install

macOS 14 or newer, Apple Silicon or Intel. Paste into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/limboSeeker/buffer/main/scripts/install.sh | bash
```

Or by hand: download `Buffer.zip` from [Releases](https://github.com/limboSeeker/buffer/releases/latest), unzip, move `Buffer.app` to Applications. The app isn't notarized, so the first time right-click it → Open.

On first launch macOS asks for Accessibility access. Allow it: Buffer needs it to paste into the active field. Copying works without it.

## Build from source

Needs Xcode command line tools.

```bash
./scripts/build-app.sh --install   # build, copy to /Applications, launch
swift test
```

The app is ad-hoc signed, so after every rebuild or reinstall macOS forgets the Accessibility permission. Remove Buffer from System Settings → Privacy & Security → Accessibility and add it again.

## Files

- History: `~/Library/Application Support/Buffer/`
- Log: `~/Library/Logs/Buffer.log` (no clipboard contents)
