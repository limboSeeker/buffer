# Buffer

Lightweight clipboard history for macOS. Lives in the menu bar, opens with ⌥V.

[![License: MIT](https://img.shields.io/github/license/limboSeeker/buffer)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/limboSeeker/buffer)](https://github.com/limboSeeker/buffer/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)

<!-- ![⌥V opens the history at the cursor, search, pick, and the item is pasted](docs/images/demo.gif) -->

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

<!-- ![History window with text, an image and a pinned item](docs/images/picker.png) -->

The menu bar icon lists recent items and holds the settings.

<!-- ![Menu bar menu](docs/images/menubar.png) -->

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

## License

MIT, see [LICENSE](LICENSE).
