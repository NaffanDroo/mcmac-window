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
if [[ "${1:-}" == "--debug" ]]; then
    OPT_FLAG="-Onone -g"
    echo "→ Debug build"
else
    echo "→ Release build"
fi

CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
mkdir -p "$MACOS"

echo "→ Compiling…"
swiftc "${SOURCES[@]}" "${FRAMEWORKS[@]}" $OPT_FLAG -o "$MACOS/$BINARY_NAME"

echo "→ Copying Info.plist…"
cp Info.plist "$CONTENTS/Info.plist"

echo ""
echo "✓ Built: $BUNDLE"
echo "  Run:   open $BUNDLE"
