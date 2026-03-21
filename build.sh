#!/bin/bash
set -euo pipefail

BUNDLE="mcmac-window.app"
BINARY_NAME="mcmac-window"
SOURCES=(
    Sources/WindowAction.swift
    Sources/Geometry.swift
    Sources/main.swift
    Sources/AppDelegate.swift
    Sources/HotkeyManager.swift
    Sources/WindowMover.swift
)
FRAMEWORKS=(-framework AppKit -framework ApplicationServices -framework Carbon)

OPT_FLAG="-O"
EXTRA_FLAGS=()
for arg in "$@"; do
    case "$arg" in
        --debug)            OPT_FLAG="-Onone -g"; echo "→ Debug build" ;;
        --warnings-as-errors) EXTRA_FLAGS+=("-warnings-as-errors"); echo "→ Warnings as errors" ;;
        *) echo "Unknown flag: $arg" >&2; exit 1 ;;
    esac
done
if [[ ${#EXTRA_FLAGS[@]} -eq 0 && "$OPT_FLAG" == "-O" ]]; then
    echo "→ Release build"
fi

CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
mkdir -p "$MACOS" "$RESOURCES"

echo "→ Compiling…"
swiftc "${SOURCES[@]}" "${FRAMEWORKS[@]}" "$OPT_FLAG" ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} -o "$MACOS/$BINARY_NAME"

echo "→ Copying Info.plist…"
cp Info.plist "$CONTENTS/Info.plist"

echo "→ Copying icon…"
cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"

echo "→ Signing bundle…"
# Sign the whole bundle so the code-signing identifier matches the bundle ID
# (org.nathandrew.mcmac-window). Without this the linker assigns the bare binary
# name as the identifier, which mismatches the TCC entry macOS creates when
# the user enables Accessibility in System Settings → Privacy & Security.
codesign --force --sign - "$BUNDLE"

echo ""
echo "✓ Built: $BUNDLE"
echo "  Run:   open $BUNDLE"
