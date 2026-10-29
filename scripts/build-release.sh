#!/bin/zsh
#
# Builds a Release copy of MyNotch for GitHub Releases and packages it as a zip and a dmg.
#
# MyNotch isn't in the Apple Developer Program, so the release is ad-hoc signed (no team, not
# notarized). Local development builds keep using the Personal Team set in the Xcode project;
# the overrides below only apply to this script's build.
#
# Usage: scripts/build-release.sh
# Output: dist/MyNotch-<version>.zip and dist/MyNotch-<version>.dmg
#
set -euo pipefail

ROOT="${0:A:h:h}"
PROJECT="$ROOT/boringnotch/boringNotch.xcodeproj"
DERIVED="${TMPDIR:-/tmp}/MyNotchRelease"
DIST="$ROOT/dist"

echo "› Building Release (ad-hoc signed)…"
xcodebuild build \
    -project "$PROJECT" \
    -scheme boringNotch \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM= \
    PROVISIONING_PROFILE_SPECIFIER= \
    > "$DERIVED.log" 2>&1 || {
        grep -E "error:" "$DERIVED.log" | sort -u
        echo "✗ Build failed. Full log: $DERIVED.log"
        exit 1
    }

APP="$DERIVED/Build/Products/Release/MyNotch.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
codesign --verify --deep --strict "$APP"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "› Packaging MyNotch $VERSION…"
ditto -c -k --keepParent "$APP" "$DIST/MyNotch-$VERSION.zip"

# The dmg shows MyNotch next to an Applications shortcut, so it can be dragged across.
STAGING="$DERIVED/dmg"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/MyNotch.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "MyNotch $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DIST/MyNotch-$VERSION.dmg" > /dev/null

echo "✓ Done:"
ls -lh "$DIST"
