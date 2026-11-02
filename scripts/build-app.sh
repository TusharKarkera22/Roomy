#!/bin/bash
# Builds build/Roomy.app (ad-hoc signed, for this Mac's architecture).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin=$(swift build -c release --show-bin-path)
app=build/Roomy.app

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Roomy" "$app/Contents/MacOS/"
cp Sources/RoomyCore/rules.json "$app/Contents/Resources/"
cp scripts/Info.plist "$app/Contents/"

# The icon is drawn by the app itself from its pixel art.
rm -rf build/Roomy.iconset
"$bin/Roomy" --make-icon build/Roomy.iconset
iconutil -c icns build/Roomy.iconset -o "$app/Contents/Resources/AppIcon.icns"
mkdir -p assets
cp build/Roomy.iconset/icon_512x512@2x.png assets/icon.png

codesign --force --sign - "$app"
echo "Built $app"
