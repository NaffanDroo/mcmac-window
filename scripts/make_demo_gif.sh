#!/usr/bin/env bash
# make_demo_gif.sh — records an animated GIF of McMac Window snapping windows.
#
# Sequence:
#   1. VS Code maximised (pre-set before recording)
#   2. VS Code → left half, Brave → right half
#   3. VS Code → top-left, Brave → top-right, App Store → bottom-left, iTerm → bottom-right
#
# Usage: ./scripts/make_demo_gif.sh [output.gif]
#
# Requirements:
#   - ffmpeg (brew install ffmpeg)
#   - Brave Browser, Visual Studio Code, App Store, and iTerm2 must be open
#   - McMac Window must be running with Accessibility permission granted
#   - Your terminal app must have Accessibility access:
#       System Settings → Privacy & Security → Accessibility
set -euo pipefail

FRAMES_DIR=$(mktemp -d)
OUTPUT="${1:-demo.gif}"
SNAP_SETTLE=0.5   # seconds to wait after hotkey for the snap animation to settle
FOCUS_DELAY=0.4   # seconds after activating an app before sending a hotkey

cleanup() { rm -rf "$FRAMES_DIR"; }
trap cleanup EXIT

# ── Dependencies ──────────────────────────────────────────────────────────────
if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found. Install with: brew install ffmpeg" >&2
    exit 1
fi

for app in "Brave Browser" "Visual Studio Code" "App Store" "iTerm2"; do
    if ! osascript -e "tell application \"$app\" to get name" &>/dev/null; then
        echo "Error: $app is not open. Please open it before running this script." >&2
        exit 1
    fi
done

if ! pgrep -x "McMac Window" &>/dev/null; then
    echo "Error: McMac Window is not running." >&2
    exit 1
fi

if ! osascript -e 'tell application "System Events" to get name of first process' &>/dev/null; then
    echo "Error: Accessibility access required to send hotkeys." >&2
    echo "  System Settings → Privacy & Security → Accessibility → add your terminal app" >&2
    exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
FRAME_NUM=0
CONCAT="$FRAMES_DIR/concat.txt"

capture() {
    local duration="${1:-1.5}"
    FRAME_NUM=$((FRAME_NUM + 1))
    local path
    path="$FRAMES_DIR/frame_$(printf '%03d' $FRAME_NUM).png"
    screencapture -x -m "$path"
    printf "file '%s'\nduration %s\n" "$path" "$duration" >> "$CONCAT"
}

focus() {
    # Activate the app and wait for it to be frontmost before we send a hotkey
    osascript -e "tell application \"$1\" to activate"
    sleep "$FOCUS_DELAY"
}

hotkey() {
    # Send ⌃⌥ + keycode to trigger a McMac Window snap on the frontmost window
    local keycode="$1"
    osascript -e "tell application \"System Events\" to key code $keycode using {control down, option down}"
    sleep "$SNAP_SETTLE"
}

position() {
    # position <process-name> <x> <y> <width> <height>
    osascript -e "
tell application \"System Events\"
    tell process \"$1\"
        set position of front window to {$2, $3}
        set size of front window to {$4, $5}
    end tell
end tell"
}

# ── Pre-recording setup ───────────────────────────────────────────────────────
echo "Setting up..."

# Stack Brave, App Store, iTerm in the centre — they'll snap from there
focus "Brave Browser";      position "Brave Browser" 300 100 1000 680; sleep 0.2
focus "App Store";          position "App Store"     300 100 1000 680; sleep 0.2
focus "iTerm2";             position "iTerm2"        300 100 1000 680; sleep 0.2

# Maximise VS Code via the McMac Window hotkey so it's the hero starting frame
focus "Visual Studio Code"
hotkey 36   # ⌃⌥↩  maximize

sleep 0.3   # let the maximize animation finish before we start capturing

# ── Recording ─────────────────────────────────────────────────────────────────
echo "Recording..."

# 1. VS Code maximised
capture 2.0

# 2a. VS Code → left half (⌃⌥←)
focus "Visual Studio Code"
hotkey 123
capture 1.2

# 2b. Brave → right half (⌃⌥→)
focus "Brave Browser"
hotkey 124
capture 2.0   # hold on side-by-side

# 3a. VS Code → top-left (⌃⌥U)
focus "Visual Studio Code"
hotkey 32
capture 0.8

# 3b. Brave → top-right (⌃⌥I)
focus "Brave Browser"
hotkey 34
capture 0.8

# 3c. App Store → bottom-left (⌃⌥J)
focus "App Store"
hotkey 38
capture 0.8

# 3d. iTerm → bottom-right (⌃⌥K)
focus "iTerm2"
hotkey 40
capture 3.0   # hold on all four corners

# ffmpeg concat demuxer needs the last frame repeated without a duration line
printf "file '%s'\n" "$FRAMES_DIR/frame_$(printf '%03d' $FRAME_NUM).png" >> "$CONCAT"

# ── Assemble GIF (two-pass palette for quality) ───────────────────────────────
echo "Assembling GIF..."
PALETTE="$FRAMES_DIR/palette.png"

ffmpeg -y -f concat -safe 0 -i "$CONCAT" \
    -vf "scale=1280:-1:flags=lanczos,palettegen=max_colors=256" \
    "$PALETTE" -loglevel error

ffmpeg -y -f concat -safe 0 -i "$CONCAT" -i "$PALETTE" \
    -filter_complex "scale=1280:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
    "$OUTPUT" -loglevel error

SIZE=$(du -sh "$OUTPUT" | cut -f1)
echo "Done → $OUTPUT ($SIZE)"
