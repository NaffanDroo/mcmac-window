#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

OUT="Tests/test_runner"

SOURCE_FILES=(
    Sources/WindowAction.swift
    Sources/Geometry.swift
    Sources/WindowMover.swift
    Tests/TestFramework.swift
    Tests/GeometryTests.swift
    Tests/WindowMoverTests.swift
    Tests/TestRunner.swift
)

echo "→ Compiling tests…"
swiftc "${SOURCE_FILES[@]}" \
    -framework AppKit -framework ApplicationServices \
    -Onone -o "$OUT"

echo "→ Running…"
echo ""
"$OUT"
