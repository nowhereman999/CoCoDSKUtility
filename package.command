#!/bin/zsh
set -e

cd "$(dirname "$0")"
./build.command

APP="build/CoCoDSKUtility.app"
ZIP="build/CoCoDSKUtility-arm.zip"
STAGE="/private/tmp/CoCoDSKUtility-arm-package"
STAGED_APP="$STAGE/CoCoDSKUtility.app"

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto --noextattr --norsrc "$APP" "$STAGED_APP"
xattr -cr "$STAGED_APP"
xattr -d com.apple.FinderInfo "$STAGED_APP" 2>/dev/null || true
codesign --force --deep --sign - "$STAGED_APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$STAGED_APP" "$ZIP"

echo "Packaged $ZIP"
