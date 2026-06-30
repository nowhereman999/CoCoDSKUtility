#!/bin/zsh
set -e

cd "$(dirname "$0")/.."
DiskUtility/build.command

APP="DiskUtility/build/CoCoDSKUtility.app"
ZIP="DiskUtility/build/CoCoDSKUtility-M1.zip"

codesign --force --deep --sign - "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packaged $ZIP"
