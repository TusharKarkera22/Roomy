#!/bin/bash
# Builds build/Roomy-<version>.dmg: Roomy.app plus a shortcut to Applications to drag it onto.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)
dmg=build/Roomy-$version.dmg
stage=build/dmg

rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R build/Roomy.app "$stage/"
ln -s /Applications "$stage/Applications"
cat > "$stage/Opening Roomy the first time.txt" <<'EOF'
1. Drag Roomy onto Applications.
2. Open Roomy. macOS says it can't check Roomy for malware, because Roomy
   isn't notarized by Apple yet. Click Done (not Move to Trash).
3. Open System Settings > Privacy & Security, scroll down, and click
   "Open Anyway" next to Roomy. Confirm once.

You only do this once. Roomy works 100% offline and is open source:
https://github.com/TusharKarkera22/Roomy
EOF

hdiutil create -volname "Roomy $version" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null
echo "Built $dmg"
