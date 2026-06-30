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
STAGE="/private/tmp/CoCoDSKUtility-intel-package"
STAGED_APP="$STAGE/CoCoDSKUtility.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE"
swiftc -target x86_64-apple-macosx13.0 -module-cache-path "$CACHE" DiskUtility.swift -o "$APP/Contents/MacOS/CoCoDSKUtility"
cp Info.plist "$APP/Contents/Info.plist"
cp "$DECB_X86" "$APP/Contents/Resources/decb"
chmod +x "$APP/Contents/Resources/decb"

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto --noextattr --norsrc "$APP" "$STAGED_APP"
xattr -cr "$STAGED_APP"
xattr -d com.apple.FinderInfo "$STAGED_APP" 2>/dev/null || true
codesign --force --deep --sign - "$STAGED_APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$STAGED_APP" "$ZIP"

echo "Packaged $ZIP"
