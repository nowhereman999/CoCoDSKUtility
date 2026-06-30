#!/bin/zsh
set -e

cd "$(dirname "$0")"

DECB_X86="decb-x86_64"
if [ ! -x "$DECB_X86" ]; then
    echo "Missing Intel decb binary: $DECB_X86"
    echo
    echo "Copy an x86_64 macOS Toolshed decb executable to:"
    echo "  $DECB_X86"
    echo
    echo "Then run this script again."
    exit 1
fi

APP="build/CoCoDSKUtility-Intel.app"
ZIP="build/CoCoDSKUtility-Intel.zip"
CACHE="/private/tmp/DiskUtilityModuleCache"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE"
swiftc -target x86_64-apple-macosx13.0 -module-cache-path "$CACHE" DiskUtility.swift -o "$APP/Contents/MacOS/CoCoDSKUtility"
cp Info.plist "$APP/Contents/Info.plist"
cp "$DECB_X86" "$APP/Contents/Resources/decb"
chmod +x "$APP/Contents/Resources/decb"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Packaged $ZIP"
