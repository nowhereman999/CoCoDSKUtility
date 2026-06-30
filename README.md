# CoCo DSK Utility

Native macOS GUI for inspecting and moving files in CoCo `.DSK` images using the local `decb` executable.

## Run

Double-click `run.command`, or from Terminal:

```sh
DiskUtility/run.command
```

## Features

- Open a `.DSK` image and show its directory.
- Drag files from Finder into the window to copy them onto the disk image.
- Select files and click `Export` to copy them to a Mac folder.
- Drag selected rows from the table to Finder to export them through a temporary file.
- Delete selected disk files.
- Right-click selected files to change the CoCo file type or ASCII/Binary data type.
- Select one file and click `HexEdit` to open a scrollable read-only hex/ascii viewer.

Files copied into the disk image use `decb copy -2 -b -r`, so they are written as binary machine-language files by default.

## Packaging

`package.command` creates the Apple Silicon package:

```sh
DiskUtility/package.command
```

It bundles the arm64 `decb` binary from:

```text
DiskUtility/decb
```

`package-intel.command` creates an Intel package and bundles the x86_64 `decb` binary from:

```text
DiskUtility/decb-x86_64
```
