#!/bin/bash
set -euo pipefail

BUNDLE="mcmac-window.app"
BINARY="$BUNDLE/Contents/MacOS/mcmac-window"

if pgrep -x "mcmac-window" > /dev/null 2>&1; then
    echo "→ Stopping running instance…"
    pkill -x "mcmac-window" || true
    sleep 0.3
fi

NEEDS_BUILD=false
if [[ ! -f "$BINARY" ]]; then
    NEEDS_BUILD=true
else
    for src in Sources/*.swift Info.plist; do
        if [[ "$src" -nt "$BINARY" ]]; then NEEDS_BUILD=true; break; fi
    done
fi

if $NEEDS_BUILD; then ./build.sh; fi

echo "→ Launching ${BUNDLE}…"
open "$BUNDLE"
