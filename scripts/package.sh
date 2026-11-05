#!/bin/sh
# Builds a universal Release Shoji.app and wraps it in build/Shoji-<version>.dmg. Not notarized.
# Signed with the "Shoji Local" self-signed certificate when it's in the keychain (macOS privacy grants then
# survive updates), ad-hoc otherwise (CI). SHOJI_SIGN_IDENTITY names another certificate.
# Usage: scripts/package.sh [--install] [version]
#   --install  puts the app in /Applications instead of a DMG, then removes the build's apps and DMGs
#              so Spotlight finds only the installed Shoji.
set -eu
cd "$(dirname "$0")/.."

INSTALL=
if [ "${1:-}" = "--install" ]; then INSTALL=1; shift; fi
VERSION="${1:-$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)}"
APP=build/Build/Products/Release/Shoji.app
DEBUG_APP=build/Build/Products/Debug/Shoji.app
STAGE=build/dmg
DMG="build/Shoji-$VERSION.dmg"
IDENTITY="${SHOJI_SIGN_IDENTITY:-Shoji Local}"

xcodegen generate --quiet
xcodebuild -scheme Shoji -configuration Release -derivedDataPath build \
  -destination 'generic/platform=macOS' -skipPackagePluginValidation \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  -quiet build

# Not -v: a self-signed certificate is "not trusted", which codesign doesn't mind.
if security find-identity -p codesigning | grep -qF "\"$IDENTITY\""; then
  codesign --force --sign "$IDENTITY" "$APP"
  codesign --verify --strict "$APP"
  echo "Signed with $IDENTITY" >&2
fi

if [ -n "$INSTALL" ]; then
  # Replaced, not overwritten: writing into a running signed app's bundle can crash it.
  rm -rf /Applications/Shoji.app
  ditto "$APP" /Applications/Shoji.app
  rm -rf "$APP" "$APP.dSYM" "$STAGE" build/Shoji-*.dmg
  if pgrep -qf "$PWD/$DEBUG_APP/"; then
    echo "Shoji Debug is running, so its build stays." >&2
  else
    rm -rf "$DEBUG_APP"
  fi
  echo /Applications/Shoji.app
  exit 0
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Shoji -srcfolder "$STAGE" -format UDZO -quiet "$DMG"
echo "$DMG"
