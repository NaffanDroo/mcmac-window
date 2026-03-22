#!/bin/bash
set -euo pipefail

BUNDLE="McMac Window.app"
BINARY="$BUNDLE/Contents/MacOS/McMac Window"

if pgrep -x "McMac Window" > /dev/null 2>&1; then
    echo "→ Stopping running instance…"
    pkill -x "McMac Window" || true
    sleep 0.3
fi

NEEDS_BUILD=false
if [[ ! -f "$BINARY" ]]; then
    NEEDS_BUILD=true
else
    for src in Sources/McMacWindowCore/*.swift Sources/McMacWindow/*.swift Info.plist Package.swift; do
        if [[ "$src" -nt "$BINARY" ]]; then NEEDS_BUILD=true; break; fi
    done
fi

if $NEEDS_BUILD; then ./build.sh; fi

echo "→ Launching ${BUNDLE}…"
open "$BUNDLE"
