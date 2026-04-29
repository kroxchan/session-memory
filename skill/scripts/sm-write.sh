#!/usr/bin/env bash
# sm-write.sh — Atomic append to a memory file + sync INDEX.md entry.
#
# Usage:
#   sm-write.sh --project-key <key> --file <name> \
#               --title <short> --summary <≤30 chars> \
#               [--current] [--global] \
#               [--body <text>] [--body-stdin]
#
# Body: use --body-stdin to read from stdin (recommended for multi-line content).
#       --body <text> for single-line content.
#
# Flags:
#   --current : mark this entry as ★ CURRENT (supersedes previous in same file)
#   --global  : write to _global/ instead of projects/<key>/
#   --body-stdin : read body from stdin (mutually exclusive with --body)

set -euo pipefail

MEMORY_ROOT="${MEMORY_ROOT:-$HOME/.cursor/session-memory/memory}"

PROJECT_KEY=""
FILE=""
TITLE=""
SUMMARY=""
BODY=""
CURRENT=0
GLOBAL=0
BODY_STDIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-key) PROJECT_KEY="$2"; shift 2;;
    --file)        FILE="$2"; shift 2;;
    --title)       TITLE="$2"; shift 2;;
    --summary)      SUMMARY="$2"; shift 2;;
    --body)        BODY="$2"; shift 2;;
    --body-stdin)  BODY_STDIN=1; shift;;
    --current)     CURRENT=1; shift;;
    --global)      GLOBAL=1; shift;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ $BODY_STDIN -eq 1 && -n "$BODY" ]]; then
  echo "ERROR: --body and --body-stdin are mutually exclusive" >&2; exit 1
fi

if [[ $BODY_STDIN -eq 1 ]]; then
  BODY="$(cat)"
fi

[[ -z "$FILE" || -z "$TITLE" || -z "$BODY" ]] && {
  echo "ERROR: --file, --title, and body (--body or --body-stdin) are required" >&2; exit 1;
}

if [[ $GLOBAL -eq 1 ]]; then
  BASE_DIR="$MEMORY_ROOT/sessions/_global"
else
  [[ -z "$PROJECT_KEY" ]] && { echo "ERROR: --project-key required unless --global" >&2; exit 1; }
  BASE_DIR="$MEMORY_ROOT/sessions/projects/$PROJECT_KEY"
fi

TARGET="$BASE_DIR/$FILE"
INDEX="$BASE_DIR/INDEX.md"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"
ID="mem-$(date +%s)"

mkdir -p "$(dirname "$TARGET")"
[[ ! -f "$TARGET" ]] && echo "# $(basename "$FILE" .md)" > "$TARGET"
[[ ! -f "$INDEX" ]] && echo "# INDEX" > "$INDEX"

# ---- 1. Write entry atomically to target file -------------------------------
TMP_TARGET="$(mktemp "${TARGET}.XXXXXX")"
trap 'rm -f "$TMP_TARGET"' EXIT

cat "$TARGET" > "$TMP_TARGET"

# If --current, strike previous CURRENT entries (pure bash, no Python)
if [[ $CURRENT -eq 1 ]]; then
  _tmp2="$(mktemp)"
  while IFS= read -r line; do
    if [[ "$line" == "## ★ CURRENT "* ]]; then
      # Strip the marker, wrap in ~~ ~~, append supersession comment on next line
      stripped="${line##"## ★ CURRENT "}"
      printf '%s\n' "## ~~${stripped}~~" >> "$_tmp2"
      printf '%s\n' "<!-- superseded @ $TS -->" >> "$_tmp2"
    else
      printf '%s\n' "$line" >> "$_tmp2"
    fi
  done < "$TMP_TARGET"
  cat "$_tmp2" > "$TMP_TARGET"
  rm -f "$_tmp2"
fi

MARKER=""
[[ $CURRENT -eq 1 ]] && MARKER="★ CURRENT "

{
  echo
  echo "## ${MARKER}${TITLE}"
  echo "<!-- id: $ID | ts: $TS -->"
  echo
  echo "$BODY"
} >> "$TMP_TARGET"

mv "$TMP_TARGET" "$TARGET"
trap - EXIT

# ---- 2. Sync INDEX.md entry atomically --------------------------------------
TMP_INDEX="$(mktemp "${INDEX}.XXXXXX")"
trap 'rm -f "$TMP_INDEX"' EXIT

# Remove any existing line referencing this file (prevent dupes when title changes)
grep -v "^\\- $FILE " "$INDEX" > "$TMP_INDEX" 2>/dev/null || true

# Truncate summary to 30 chars; append short hash of title for uniqueness
SHORT_HASH="$(printf '%s' "$TITLE" | cksum | cut -c1-4)"
SUM="${SUMMARY:-$TITLE}"
SUM_SHORT="${SUM:0:30}"
printf '%s\n' "- $FILE — ${SUM_SHORT}[$SHORT_HASH]" >> "$TMP_INDEX"

mv "$TMP_INDEX" "$INDEX"
trap - EXIT

echo "wrote: $TARGET"
echo "index: $INDEX"
echo "id:    $ID"
