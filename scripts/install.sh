#!/bin/bash
# Installs the latest Buffer release into /Applications and launches it.
set -euo pipefail

URL="https://github.com/limboSeeker/buffer/releases/latest/download/Buffer.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Buffer..."
curl -fsSL "$URL" -o "$TMP/Buffer.zip"
ditto -x -k "$TMP/Buffer.zip" "$TMP"

pkill -x Buffer 2>/dev/null || true
rm -rf /Applications/Buffer.app
mv "$TMP/Buffer.app" /Applications/
# The app is not notarized; drop the quarantine flag so Gatekeeper lets it start.
xattr -dr com.apple.quarantine /Applications/Buffer.app 2>/dev/null || true
# A permission granted to a previous build no longer matches this one; clear it so Buffer asks cleanly.
tccutil reset Accessibility local.buffer.clipboard >/dev/null 2>&1 || true

open /Applications/Buffer.app
echo "Done. Buffer is in the menu bar, press ⌥V to open it."
