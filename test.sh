#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "→ Running tests…"
echo ""

# WindowMoverTests creates real NSWindows and uses the Accessibility API.
# Under XCTest's runner in headless CI (no window-server connection for the
# test process), these tests crash with signal 11 before XCTSkip can fire.
# Skip the entire suite in CI; it runs locally where AX is available.
if [[ -n "${CI:-}" ]]; then
    swift test --skip WindowMoverTests
else
    swift test
fi
