#!/usr/bin/env bash
# sm-recall.sh — Keyword search across project + global memory.
#
# Usage:
#   sm-recall.sh <query> [--project-key <key>] [--context 2]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${MEMORY_ROOT:=$HOME/.cursor/session-memory/memory}"

QUERY=""
PROJECT_KEY=""
CONTEXT=2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-key) PROJECT_KEY="$2"; shift 2;;
    --context)     CONTEXT="$2"; shift 2;;
    --) shift; QUERY="$*"; break;;
    *) if [[ -z "$QUERY" ]]; then QUERY="$1"; else QUERY="$QUERY $1"; fi; shift;;
  esac
done

[[ -z "$QUERY" ]] && { echo "ERROR: query required" >&2; exit 1; }
[[ -z "$PROJECT_KEY" ]] && PROJECT_KEY="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$PWD")"

GLOBAL_DIR="$MEMORY_ROOT/sessions/_global"
PROJECT_DIR="$MEMORY_ROOT/sessions/projects/$PROJECT_KEY"

# Prefer ripgrep
if command -v rg >/dev/null 2>&1; then
  SEARCH=(rg --color=never -n -C "$CONTEXT" --no-heading --type md)
else
  SEARCH=(grep -rn -C "$CONTEXT" --include='*.md')
fi

echo "=== recall: $QUERY ==="
echo
for DIR in "$PROJECT_DIR" "$GLOBAL_DIR"; do
  [[ -d "$DIR" ]] || continue
  echo "--- ${DIR#$MEMORY_ROOT/} ---"
  "${SEARCH[@]}" -i "$QUERY" "$DIR" 2>/dev/null || echo "(no hits)"
  echo
done
