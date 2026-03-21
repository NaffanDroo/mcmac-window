#!/bin/bash
# Creates a polished DMG for distribution.
#
# Layout: McMac Window.app (left), Applications alias (right)
# Background: none — Finder's native dark-mode appearance gives white labels.
# Volume icon: app icon.
#
# Usage: ./scripts/make_dmg.sh   (run from repo root after ./build.sh)

set -euo pipefail

BUNDLE="mcmac-window.app"
APP_NAME="McMac Window.app"    # Display name used inside the DMG
VOL_NAME="mcmac-window"
DMG="${VOL_NAME}.dmg"
TMP_DMG="${VOL_NAME}-tmp.dmg"
STAGING_NAME="${VOL_NAME}-dmg-staging"
MOUNT_PT="/Volumes/${STAGING_NAME}"

if [[ ! -d "$BUNDLE" ]]; then
    echo "✗ ${BUNDLE} not found — run ./build.sh first" >&2
    exit 1
fi

# Remove stale artefacts and any leftover mount from a previous run
hdiutil detach "$MOUNT_PT" -force 2>/dev/null || true
rm -f "$DMG" "$TMP_DMG"

# ── 1. Temp read-write DMG ───────────────────────────────────────────────────
echo "→ Building staging DMG…"
hdiutil create \
    -size 30m \
    -fs HFS+ \
    -volname "$VOL_NAME" \
    -ov "$TMP_DMG" \
    -quiet

# ── 2. Mount ─────────────────────────────────────────────────────────────────
DEVICE=$(hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_PT" | awk '/Apple_HFS/{print $1}')

# ── 3. Populate ──────────────────────────────────────────────────────────────
# Rename bundle to the human-readable display name inside the DMG
cp -r "$BUNDLE" "$MOUNT_PT/$APP_NAME"
# Applications alias is created via AppleScript below (Mac alias, not Unix symlink)

# ── 4. Finder layout ─────────────────────────────────────────────────────────
echo "→ Setting Finder layout…"
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$STAGING_NAME"
        -- Create the Applications alias
        set appsAlias to make new alias to POSIX file "/Applications" at POSIX file "$MOUNT_PT/"
        set name of appsAlias to "Applications"

        -- Initial pass: window chrome + icon size
        open
        set win to container window
        set current view of win to icon view
        set toolbar visible of win to false
        set statusbar visible of win to false
        set bounds of win to {200, 120, 740, 440}
        set opts to icon view options of win
        set icon size of opts to 80
        set arrangement of opts to not arranged
        close

        -- Second pass: position icons
        open
        delay 2
        set position of item "$APP_NAME" of container window to {140, 160}
        try
            set position of item "Applications" of container window to {400, 160}
        on error
            try
                set position of alias file "Applications" of container window to {400, 160}
            end try
        end try
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# ── 5. Volume icon — set AFTER Finder layout so Finder doesn't remove the file
cp Resources/AppIcon.icns "$MOUNT_PT/.VolumeIcon.icns"
# Set the kHasCustomIcon flag (0x0400) in the volume's FinderInfo xattr so
# the DMG file uses our icon rather than the system default.
# Byte layout: 8-byte Rect, 2-byte frFlags (offset 8), rest zeroes — 32 bytes total.
xattr -wx com.apple.FinderInfo \
    "0000000000000000040000000000000000000000000000000000000000000000" \
    "$MOUNT_PT" 2>/dev/null || true
SetFile -a C "$MOUNT_PT" 2>/dev/null || true   # fallback for older CLT
sync

# ── 6. Finalise ──────────────────────────────────────────────────────────────
echo "→ Compressing…"
sync
sleep 2   # give Finder time to release the volume after window close
hdiutil detach "$DEVICE" -quiet 2>/dev/null \
    || hdiutil detach "$DEVICE" -force -quiet
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG" -quiet

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f "$TMP_DMG"

echo ""
echo "✓ Created: ${DMG}"
