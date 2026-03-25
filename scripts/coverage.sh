#!/bin/bash
# Generate an lcov coverage report at the repo root.
# Output: lcov.info  (consumed by VS Code "Coverage Gutters" and similar tools)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Running tests with coverage…"
if [[ -n "${CI:-}" ]]; then
    swift test --enable-code-coverage --skip WindowMoverTests
else
    swift test --enable-code-coverage
fi

PROF=$(find .build -name 'default.profdata' | head -1)
BIN=$(find .build -name 'McMacWindowPackageTests' -path '*/MacOS/*' -not -path '*.dSYM/*' -type f | head -1)

if [[ -z "$PROF" || -z "$BIN" ]]; then
    echo "error: could not locate profdata or test binary" >&2
    exit 1
fi

# Exclude test files, build artefacts, and UI/system code that requires
# a running app (AppDelegate, HotkeyManager, AppDelegatePanels).
EXCLUDE='Tests/|\.build/|AppDelegate|HotkeyManager|AppDelegatePanels'

echo "→ Generating lcov.info…"
xcrun llvm-cov export "$BIN" \
    -instr-profile "$PROF" \
    -format=lcov \
    -ignore-filename-regex="$EXCLUDE" \
    > lcov.info

echo "→ Coverage summary:"
xcrun llvm-cov report "$BIN" \
    -instr-profile "$PROF" \
    -ignore-filename-regex="$EXCLUDE"

echo ""
echo "✓ lcov.info written — open in VS Code with Coverage Gutters"
