#!/bin/bash
# Builds build/Buffer.app. With --install copies it to /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Buffer
BIN="$(swift build -c release --show-bin-path)/Buffer"

APP=build/Buffer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Buffer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Buffer || true
    rm -rf /Applications/Buffer.app
    cp -R "$APP" /Applications/
    open /Applications/Buffer.app
    echo "Installed and launched /Applications/Buffer.app"
fi
