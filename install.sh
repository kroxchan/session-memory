#!/usr/bin/env bash
# install.sh — Install session-memory skill into ~/.cursor/skills/
#
# Usage:
#   bash install.sh           # install (default)
#   bash install.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/skill"
DEST="${HOME}/.cursor/skills/session-memory"
MEMORY_ROOT="${MEMORY_ROOT:-$HOME/.cursor/session-memory/memory}"

ACTION="install"
[[ "${1:-}" == "--uninstall" ]] && ACTION="uninstall"

if [[ "$ACTION" == "uninstall" ]]; then
  if [[ -L "$DEST" || -d "$DEST" ]]; then
    rm -rf "$DEST"
    echo "✓ removed $DEST"
  else
    echo "(not installed at $DEST)"
  fi
  echo "Note: memory data at $MEMORY_ROOT/ is NOT removed."
  echo "To purge memory: rm -rf \"$MEMORY_ROOT\""
  exit 0
fi

# ---- Install -----------------------------------------------------------------
mkdir -p "$(dirname "$DEST")"

if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "→ existing install found at $DEST, removing…"
  rm -rf "$DEST"
fi

# NOTE: Cursor's skill scanner does NOT follow symlinks, so we copy.
# Re-run install.sh after editing the source skill to sync changes.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SRC/" "$DEST/"
else
  cp -R "$SRC" "$DEST"
fi
echo "✓ copied $SRC → $DEST"

# Make scripts executable
chmod +x "$SRC"/scripts/*.sh
echo "✓ scripts made executable"

# Ensure memory root exists and add its own .gitignore
mkdir -p "$MEMORY_ROOT"
if [[ ! -f "$MEMORY_ROOT/.gitignore" ]]; then
  cat > "$MEMORY_ROOT/.gitignore" <<'EOF'
# Session Memory — never commit memory data
*/
*.md
EOF
  echo "✓ created $MEMORY_ROOT/.gitignore"
fi

mkdir -p "$MEMORY_ROOT/sessions"
echo "✓ memory root: $MEMORY_ROOT/sessions/"

# Smoke test
echo
echo "=== smoke test ==="
bash "$SRC/scripts/sm-project-key.sh" "$PWD"
echo
echo "Install complete. Restart Cursor to load the skill."

# Optional: run test suite if bats is available
if command -v bats >/dev/null 2>&1; then
  echo
  echo "=== bats found — running test suite ==="
  if bash "$SCRIPT_DIR/tests/run.sh" 2>&1; then
    echo "All tests passed."
  else
    echo "Tests failed. See above for details."
  fi
else
  echo
  echo "(bats not found — run 'brew install bats-core' or 'sudo apt-get install bats'"
  echo " to enable tests, then: bash tests/run.sh)"
fi
