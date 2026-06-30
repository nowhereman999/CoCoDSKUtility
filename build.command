#!/bin/zsh
set -e

cd "$(dirname "$0")"
DECB_ARM="decb"
if [ ! -x "$DECB_ARM" ]; then
    echo "Missing Apple Silicon decb binary: $DECB_ARM"
    echo
    echo "Copy an arm64 macOS Toolshed decb executable to:"
    echo "  $DECB_ARM"
    echo
    echo "Then run this script again."
    exit 1
fi

mkdir -p build
APP="build/CoCoDSKUtility.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc DiskUtility.swift -o "$APP/Contents/MacOS/CoCoDSKUtility"
cp Info.plist "$APP/Contents/Info.plist"
cp "$DECB_ARM" "$APP/Contents/Resources/decb"
chmod +x "$APP/Contents/Resources/decb"
echo "Built $APP"
