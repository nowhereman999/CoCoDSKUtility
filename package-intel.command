#!/bin/zsh
set -e

cd "$(dirname "$0")/.."

DECB_X86="DiskUtility/decb-x86_64"
if [ ! -x "$DECB_X86" ]; then
    echo "Missing Intel decb binary: $DECB_X86"
    echo
    echo "Copy an x86_64 macOS Toolshed decb executable to:"
    echo "  $DECB_X86"
    echo
    echo "Then run this script again."
    exit 1
fi

APP="DiskUtility/build/CoCoDSKUtility-Intel.app"
ZIP="DiskUtility/build/CoCoDSKUtility-Intel.zip"
CACHE="/private/tmp/DiskUtilityModuleCache"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE"
swiftc -target x86_64-apple-macosx13.0 -module-cache-path "$CACHE" DiskUtility/DiskUtility.swift -o "$APP/Contents/MacOS/CoCoDSKUtility"
cp DiskUtility/Info.plist "$APP/Contents/Info.plist"
cp "$DECB_X86" "$APP/Contents/Resources/decb"
chmod +x "$APP/Contents/Resources/decb"

codesign --force --deep --sign - "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packaged $ZIP"
