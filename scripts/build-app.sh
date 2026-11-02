#!/bin/bash
# Builds build/Roomy.app: one universal binary for Apple Silicon and Intel Macs, ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."

arches=(--arch arm64 --arch x86_64)
swift build -c release "${arches[@]}"
bin=$(swift build -c release "${arches[@]}" --show-bin-path)
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
