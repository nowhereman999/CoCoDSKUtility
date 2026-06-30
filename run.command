#!/bin/zsh
set -e

cd "$(dirname "$0")"
./build.command
cd ..
open ./DiskUtility/build/CoCoDSKUtility.app
