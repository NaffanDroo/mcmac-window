#!/bin/bash
# Verifies the DMG produced by make_dmg.sh.
#
# Checks:
#   1. Required files are present (app bundle, Applications alias, volume icon)
#   2. App is named "McMac Window.app"
#   3. Icon positions: app ~(140,160) on the left, Applications ~(400,160) on the right
#   4. No custom background picture is set — Finder's native appearance is used,
#      which gives white icon labels in dark mode without any overrides
#   5. Volume has the kHasCustomIcon flag set (so the DMG uses our icon)
#   6. DMG file itself has the kHasCustomIcon flag set (file icon in Finder)
#
# Usage: ./scripts/test_dmg.sh [path/to/mcmac-window.dmg]
# Exit code: 0 = all pass, 1 = one or more failures.

set -uo pipefail

DMG="${1:-mcmac-window.dmg}"
MOUNT_PT="/tmp/mcmac-window-dmg-verify"
PASS=0
FAIL=0

_pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

cleanup() { hdiutil detach "$MOUNT_PT" -force 2>/dev/null || true; }
trap cleanup EXIT

if [[ ! -f "$DMG" ]]; then
    echo "✗ ${DMG} not found — run ./scripts/make_dmg.sh first" >&2
    exit 1
fi

echo "→ Mounting ${DMG}…"
hdiutil attach "$DMG" -mountpoint "$MOUNT_PT" -quiet
DISK_NAME=$(basename "$MOUNT_PT")   # Finder sees the disk by mount-point basename

# ── 1. Contents ──────────────────────────────────────────────────────────────
echo ""
echo "── Contents ─────────────────────────────────────"

if [[ -d "$MOUNT_PT/McMac Window.app" ]]; then
    _pass "app bundle 'McMac Window.app' present"
else
    _fail "app bundle 'McMac Window.app' missing (expected renamed display name)"
fi

if [[ -e "$MOUNT_PT/Applications" ]]; then
    _pass "Applications alias present"
else
    _fail "Applications alias missing"
fi

if [[ -f "$MOUNT_PT/.VolumeIcon.icns" ]]; then
    _pass ".VolumeIcon.icns present"
else
    _fail ".VolumeIcon.icns missing"
fi

# ── 2. Volume custom-icon flag ────────────────────────────────────────────────
echo ""
echo "── Volume icon flag ─────────────────────────────"

FINDER_INFO=$(xattr -px com.apple.FinderInfo "$MOUNT_PT" 2>/dev/null | tr -d ' \n' || echo "")
if [[ ${#FINDER_INFO} -ge 20 ]]; then
    FLAGS_HEX="${FINDER_INFO:16:4}"
    FLAGS_DEC=$((16#$FLAGS_HEX))
    if [[ $((FLAGS_DEC & 0x0400)) -eq 1024 ]]; then
        _pass "kHasCustomIcon flag set in FinderInfo (flags=0x${FLAGS_HEX})"
    else
        _fail "kHasCustomIcon flag NOT set (flags=0x${FLAGS_HEX} — DMG will show default icon)"
    fi
else
    _fail "Could not read com.apple.FinderInfo xattr on volume"
fi

# ── 6. DMG file custom-icon flag ─────────────────────────────────────────────
# NSWorkspace.setIcon_forFile_options_ sets kHasCustomIcon in the file's
# FinderInfo xattr (byte offset 8, same position as frFlags in directory info).
echo ""
echo "── DMG file icon flag ───────────────────────────"

DMG_FINDER_INFO=$(xattr -px com.apple.FinderInfo "$DMG" 2>/dev/null | tr -d ' \n' || echo "")
if [[ ${#DMG_FINDER_INFO} -ge 20 ]]; then
    DMG_FLAGS_HEX="${DMG_FINDER_INFO:16:4}"
    DMG_FLAGS_DEC=$((16#$DMG_FLAGS_HEX))
    if [[ $((DMG_FLAGS_DEC & 0x0400)) -eq 1024 ]]; then
        _pass "kHasCustomIcon flag set on .dmg file (flags=0x${DMG_FLAGS_HEX})"
    else
        _fail "kHasCustomIcon flag NOT set on .dmg file (flags=0x${DMG_FLAGS_HEX})"
    fi
else
    _fail "Could not read com.apple.FinderInfo xattr on .dmg file"
fi

# ── 3. Icon positions ─────────────────────────────────────────────────────────
echo ""
echo "── Icon positions ───────────────────────────────"

POSITIONS=$(osascript - "$DISK_NAME" 2>/dev/null << 'APPLESCRIPT' || echo "error"
on run argv
    set diskName to item 1 of argv
    tell application "Finder"
        tell disk diskName
            open
            delay 1
            set appPos  to position of item "McMac Window.app" of container window
            set appsPos to position of item "Applications"     of container window
            close
            return ((item 1 of appPos) as text) & "," & ¬
                   ((item 2 of appPos) as text) & "," & ¬
                   ((item 1 of appsPos) as text) & "," & ¬
                   ((item 2 of appsPos) as text)
        end tell
    end tell
end run
APPLESCRIPT
)

if [[ "$POSITIONS" == "error" || -z "$POSITIONS" ]]; then
    _fail "Could not read icon positions via Finder (AppleScript error)"
else
    APP_X=$(echo  "$POSITIONS" | cut -d',' -f1 | tr -d ' ')
    APP_Y=$(echo  "$POSITIONS" | cut -d',' -f2 | tr -d ' ')
    APPS_X=$(echo "$POSITIONS" | cut -d',' -f3 | tr -d ' ')
    APPS_Y=$(echo "$POSITIONS" | cut -d',' -f4 | tr -d ' ')

    if [[ "$APP_X" -ge 105 && "$APP_X" -le 175 ]]; then
        _pass "app x=${APP_X} (expected 105–175, centred on 140)"
    else
        _fail "app x=${APP_X} out of range (expected 105–175)"
    fi

    if [[ "$APPS_X" -ge 365 && "$APPS_X" -le 435 ]]; then
        _pass "Applications x=${APPS_X} (expected 365–435, centred on 400)"
    else
        _fail "Applications x=${APPS_X} out of range (expected 365–435)"
    fi

    if [[ "$APP_Y" -ge 125 && "$APP_Y" -le 195 ]]; then
        _pass "app y=${APP_Y} (expected 125–195)"
    else
        _fail "app y=${APP_Y} out of range (expected 125–195)"
    fi

    if [[ "$APPS_Y" -ge 125 && "$APPS_Y" -le 195 ]]; then
        _pass "Applications y=${APPS_Y} (expected 125–195)"
    else
        _fail "Applications y=${APPS_Y} out of range (expected 125–195)"
    fi
fi

# ── 4. No custom background picture ──────────────────────────────────────────
# A custom background picture forces Finder into light-mode label rendering,
# producing black labels regardless of system appearance. Without a background
# picture, Finder uses its native appearance — white labels in dark mode.
echo ""
echo "── Label colour (no custom background) ─────────"

ICVP_CHECK=$(python3 - "$MOUNT_PT/.DS_Store" 2>/dev/null << 'PY' || echo "error"
import sys, struct, plistlib
data = open(sys.argv[1], 'rb').read()
pos = 0
while True:
    idx = data.find(b'icvp', pos)
    if idx == -1:
        print("no-icvp")
        break
    if data[idx+4:idx+8] == b'blob':
        length = struct.unpack('>I', data[idx+8:idx+12])[0]
        d = plistlib.loads(data[idx+12:idx+12+length])
        bg_type = d.get('backgroundType', 0)
        print(f"backgroundType:{bg_type}")
        break
    pos = idx + 1
PY
)

if [[ "$ICVP_CHECK" == "error" ]]; then
    _fail "Could not read DS_Store icvp"
elif [[ "$ICVP_CHECK" == "no-icvp" || "$ICVP_CHECK" == "backgroundType:0" || "$ICVP_CHECK" == "backgroundType:1" ]]; then
    _pass "no background picture set — Finder uses native appearance (white labels in dark mode)"
elif [[ "$ICVP_CHECK" == "backgroundType:2" ]]; then
    _fail "custom background picture is set (backgroundType=2) — this forces black labels regardless of dark mode"
else
    _fail "unexpected icvp state: ${ICVP_CHECK}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
    echo "✓ All ${PASS} checks passed"
    exit 0
else
    echo "✗ ${FAIL} check(s) failed, ${PASS} passed"
    exit 1
fi
