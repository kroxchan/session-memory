#!/usr/bin/env bash
# sm-status.sh — Show memory status for current project.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${MEMORY_ROOT:=$HOME/.cursor/session-memory/memory}"

WORKSPACE="${1:-$PWD}"
PROJECT_KEY="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE")"
PROJECT_DIR="$MEMORY_ROOT/sessions/projects/$PROJECT_KEY"

echo "project_key: $PROJECT_KEY"
echo "workspace:   $WORKSPACE"
echo "memory_dir:  $PROJECT_DIR"
echo

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "(not initialized — run sm-bootstrap.sh to create)"
  exit 0
fi

echo "=== files ==="
find "$PROJECT_DIR" -type f -name '*.md' | while read -r f; do
  LINES="$(wc -l < "$f")"
  REL="${f#$PROJECT_DIR/}"
  MTIME="$(date -r "$f" +%Y-%m-%d' '%H:%M 2>/dev/null || stat -c %y "$f" | cut -c1-16)"
  printf '%-40s %4s lines  %s\n' "$REL" "$LINES" "$MTIME"
done
