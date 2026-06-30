#!/bin/zsh
set -e

cd "$(dirname "$0")"
./build.command

APP="build/CoCoDSKUtility.app"
ZIP="build/CoCoDSKUtility-arm.zip"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packaged $ZIP"
