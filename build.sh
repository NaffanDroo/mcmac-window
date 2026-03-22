#!/bin/bash
set -euo pipefail

BUNDLE="McMac Window.app"
BINARY_NAME="McMac Window"

CONFIG="release"
EXTRA_FLAGS=()
for arg in "$@"; do
    case "$arg" in
        --debug)              CONFIG="debug"; echo "→ Debug build" ;;
        --warnings-as-errors) EXTRA_FLAGS+=(-Xswiftc -warnings-as-errors); echo "→ Warnings as errors" ;;
        *) echo "Unknown flag: $arg" >&2; exit 1 ;;
    esac
done
if [[ ${#EXTRA_FLAGS[@]} -eq 0 && "$CONFIG" == "release" ]]; then
    echo "→ Release build"
fi

echo "→ Compiling…"
swift build -c "$CONFIG" ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}

CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
mkdir -p "$MACOS" "$RESOURCES"

echo "→ Assembling bundle…"
cp "$(swift build -c "$CONFIG" --show-bin-path)/McMacWindow" "$MACOS/$BINARY_NAME"
cp Info.plist "$CONTENTS/Info.plist"
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
