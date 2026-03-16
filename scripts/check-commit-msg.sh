#!/bin/bash
# Validates a commit message file against Conventional Commits format.
# Called by pre-commit as:  bash scripts/check-commit-msg.sh <msg-file>
# https://www.conventionalcommits.org/en/v1.0.0/

set -euo pipefail

MSG_FILE="$1"
MSG=$(cat "$MSG_FILE")

# Skip merge commits, reverts, and interactive-rebase fixup/squash lines
if echo "$MSG" | grep -qE "^(Merge|Revert|fixup!|squash!)"; then
    exit 0
fi

PATTERN="^(feat|fix|perf|refactor|docs|test|chore)(\(.+\))?!?: .+"

if ! echo "$MSG" | grep -qE "$PATTERN"; then
    echo ""
    echo "  ✗ Commit message does not follow Conventional Commits format."
    echo ""
    echo "  Expected:  <type>[optional scope]: <description>"
    echo "  Example:   feat: add top-right quarter snap action"
    echo "             fix(geometry): correct AX origin on retina displays"
    echo ""
    echo "  Allowed types: feat  fix  perf  refactor  docs  test  chore"
    echo ""
    echo "  Your message: $(echo "$MSG" | head -1)"
    echo ""
    exit 1
fi
