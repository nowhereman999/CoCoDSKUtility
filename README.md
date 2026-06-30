# CoCo DSK Utility

Native macOS GUI for inspecting and moving files in CoCo `.DSK` images. It uses the bundled Toolshed `decb` executable internally.

## Install

Use the correct zip for the target Mac:

- arm64 Macs: `CoCoDSKUtility-arm.zip`
- Intel Macs: `CoCoDSKUtility-Intel.zip`

To install:

1. Unzip the package.
2. Drag `CoCoDSKUtility.app` into `/Applications`.
3. The first time you run it, right-click `CoCoDSKUtility.app` and choose `Open`.
4. Confirm the macOS security prompt.

The right-click `Open` step is only needed because the app is ad-hoc signed and not Apple-notarized.

## Opening `.DSK` Files

After `CoCoDSKUtility.app` is copied into `/Applications`, macOS Launch Services reads the app bundle's `Info.plist`. That file declares that CoCoDSKUtility can open `.dsk` and `.DSK` files.

From that point on:

- Right-click a `.DSK` file and choose `Open With` -> `CoCoDSKUtility`.
- Double-clicking a `.DSK` will open CoCoDSKUtility if macOS has selected it as the default app for `.DSK` files.

If double-clicking still opens another app, set CoCoDSKUtility as the default:

1. Click any `.DSK` file in Finder.
2. Press `Command-I` to open `Get Info`.
3. In `Open with`, choose `CoCoDSKUtility`.
4. Click `Change All...`.

Now double-clicking `.DSK` files should open them directly in CoCoDSKUtility and show the directory contents.

## Features

- Open a `.DSK` image and show its directory.
- Drag files from Finder into the window to copy them onto the disk image.
- Select files and click `Export` to copy them to a Mac folder.
- Drag selected rows from the table to Finder to export them through a temporary file.
- Delete selected disk files.
- Right-click selected files to change the CoCo file type or ASCII/Binary data type.
- Select one file and click `HexEdit` to open a scrollable read-only hex/ascii viewer.
- Double-click or `Open With` `.DSK` files from Finder.

Files copied into the disk image use `decb copy -2 -b -r`, so they are written as binary machine-language files by default.

## Packaging

`package.command` creates the arm64 package:

```sh
./package.command
```

It bundles the arm64 `decb` binary from:

```text
decb
```

`package-intel.command` creates an Intel package and bundles the x86_64 `decb` binary from:

```text
decb-x86_64
```
