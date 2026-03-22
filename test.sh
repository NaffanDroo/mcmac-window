#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "→ Running tests…"
echo ""
swift test
