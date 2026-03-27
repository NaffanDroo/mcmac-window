#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "→ Running tests…"
echo ""

# WindowMoverTests creates real NSWindows and uses the Accessibility API.
# Under XCTest's runner without a window-server connection the test process
# crashes with signal 11 before XCTSkip can fire.  In CI we always skip the
# suite.  Locally we try first and fall back to --skip if we see signal 11,
# so the pre-push hook still passes on machines without a GUI session.
if [[ -n "${CI:-}" ]]; then
    swift test --skip WindowMoverTests
else
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    set +e
    swift test 2>&1 | tee "$tmp"
    rc=${PIPESTATUS[0]}
    set -e
    if [[ "$rc" -ne 0 ]] && grep -q "signal code 11" "$tmp"; then
        echo ""
        echo "→ WindowMoverTests crashed with signal 11 (no window-server connection)."
        echo "  Re-running without WindowMoverTests — matches CI behaviour."
        echo ""
        swift test --skip WindowMoverTests
    elif [[ "$rc" -ne 0 ]]; then
        exit $rc
    fi
fi
