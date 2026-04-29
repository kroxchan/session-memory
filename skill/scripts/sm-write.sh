#!/usr/bin/env bash
# sm-write.sh — Atomic append to a memory file + sync INDEX.md entry.
#
# Usage:
#   sm-write.sh --project-key <key> --file <name> \
#               --title <short> --summary <≤30 chars> \
#               --body <markdown body> [--current] [--global]
#
# Flags:
#   --current : mark this entry as ★ CURRENT (supersedes previous in same file)
#   --global  : write to _global/ instead of projects/<key>/

set -euo pipefail

: "${MEMORY_ROOT:=/Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory}"

PROJECT_KEY=""
FILE=""
TITLE=""
SUMMARY=""
BODY=""
CURRENT=0
GLOBAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-key) PROJECT_KEY="$2"; shift 2;;
    --file)        FILE="$2"; shift 2;;
    --title)       TITLE="$2"; shift 2;;
    --summary)     SUMMARY="$2"; shift 2;;
    --body)        BODY="$2"; shift 2;;
    --current)     CURRENT=1; shift;;
    --global)      GLOBAL=1; shift;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1;;
  esac
done

[[ -z "$FILE" || -z "$TITLE" || -z "$BODY" ]] && {
  echo "ERROR: --file, --title, --body are required" >&2; exit 1;
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

# If --current, strike previous CURRENT entries in same file
if [[ $CURRENT -eq 1 ]]; then
  # Replace lines starting with "## ★ CURRENT" with stricken version
  python3 - "$TMP_TARGET" "$TS" <<'PY'
import sys, re, pathlib
path, ts = sys.argv[1], sys.argv[2]
txt = pathlib.Path(path).read_text()
def strike(match):
    line = match.group(0)
    return line.replace("## ★ CURRENT ", "## ~~").rstrip() + f"~~\n<!-- superseded @ {ts} -->"
new = re.sub(r"^## ★ CURRENT .+$", strike, txt, flags=re.M)
pathlib.Path(path).write_text(new)
PY
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

# Remove any existing line referencing this file (to prevent dupes when title changes)
grep -v "^- $FILE " "$INDEX" > "$TMP_INDEX" || true

# Append new line — format: - <path> — <summary>
SUM="${SUMMARY:-$TITLE}"
# Truncate to 30 chars
SUM_SHORT="$(printf '%s' "$SUM" | cut -c1-30)"
printf '%s\n' "- $FILE — $SUM_SHORT" >> "$TMP_INDEX"

mv "$TMP_INDEX" "$INDEX"
trap - EXIT

echo "wrote: $TARGET"
echo "index: $INDEX"
echo "id:    $ID"
