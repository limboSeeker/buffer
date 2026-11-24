#!/bin/bash
# Builds build/Buffer.app (universal: Apple Silicon + Intel).
#   --install  copy to /Applications and launch
#   --zip      also pack build/Buffer.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release --product Buffer "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Buffer"

APP=build/Buffer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Buffer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Buffer"))"

for arg in "$@"; do
    case "$arg" in
        --zip)
            rm -f build/Buffer.zip
            ditto -c -k --keepParent "$APP" build/Buffer.zip
            echo "Packed build/Buffer.zip"
            ;;
        --install)
            pkill -x Buffer || true
            rm -rf /Applications/Buffer.app
            cp -R "$APP" /Applications/
            open /Applications/Buffer.app
            echo "Installed and launched /Applications/Buffer.app"
            ;;
    esac
done
