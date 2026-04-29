#!/usr/bin/env bash
# tests/run.sh — Run all tests.
#
# Requires bats-core: brew install bats-core (macOS) or apt-get install bats (Linux).
# Or install via: git clone https://github.com/bats-core/bats-core.git && ./bats-core/install.sh ~/local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../skill" && pwd)"

BATS="${BATS:-bats}"
export PATH="$SCRIPT_DIR/bin:$PATH"

echo "=== Session Memory — Test Suite ==="
echo

"$BATS" --formatter pretty "$SCRIPT_DIR/sm-project-key.bats"
"$BATS" --formatter pretty "$SCRIPT_DIR/sm-write.bats"
"$BATS" --formatter pretty "$SCRIPT_DIR/sm-bootstrap.bats"
"$BATS" --formatter pretty "$SCRIPT_DIR/sm-recall.bats"
"$BATS" --formatter pretty "$SCRIPT_DIR/sm-compress.bats"

echo
echo "All tests passed."
