#!/bin/sh
# Builds a universal Release Shoji.app and wraps it in build/Shoji-<version>.dmg.
# Ad-hoc signed, not notarized (no paid Apple Developer account). Usage: scripts/package.sh [version]
set -eu
cd "$(dirname "$0")/.."

VERSION="${1:-$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)}"
APP=build/Build/Products/Release/Shoji.app
STAGE=build/dmg
DMG="build/Shoji-$VERSION.dmg"

xcodegen generate --quiet
xcodebuild -scheme Shoji -configuration Release -derivedDataPath build \
  -destination 'generic/platform=macOS' -skipPackagePluginValidation \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  -quiet build

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Shoji -srcfolder "$STAGE" -format UDZO -quiet "$DMG"
echo "$DMG"
