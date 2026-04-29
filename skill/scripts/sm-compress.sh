#!/usr/bin/env bash
# sm-compress.sh — Save a conversation summary to sessions/ and update INDEX.
#
# Intended to be called when context usage hits ~50% (long-session compaction).
# The Agent generates the summary text; this script handles persistence.
#
# Usage:
#   sm-compress.sh --project-key <key> --topic <short-topic> --summary <path-or->
#
# If --summary is "-", reads summary body from stdin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_KEY=""
TOPIC=""
SUMMARY_SRC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-key) PROJECT_KEY="$2"; shift 2;;
    --topic)       TOPIC="$2"; shift 2;;
    --summary)     SUMMARY_SRC="$2"; shift 2;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1;;
  esac
done

[[ -z "$PROJECT_KEY" || -z "$TOPIC" || -z "$SUMMARY_SRC" ]] && {
  echo "ERROR: --project-key, --topic, --summary all required" >&2; exit 1;
}

if [[ "$SUMMARY_SRC" == "-" ]]; then
  SUMMARY_BODY="$(cat)"
else
  SUMMARY_BODY="$(cat "$SUMMARY_SRC")"
fi

DATE="$(date +%Y-%m-%d)"
# Sanitize topic to filename-safe
SLUG="$(printf '%s' "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//')"
FILENAME="sessions/${DATE}-${SLUG}.md"

# Extract first sentence for INDEX summary (≤30 chars)
FIRST_LINE="$(printf '%s' "$SUMMARY_BODY" | head -n1 | cut -c1-30)"

bash "$SCRIPT_DIR/sm-write.sh" \
  --project-key "$PROJECT_KEY" \
  --file "$FILENAME" \
  --title "$TOPIC" \
  --summary "$FIRST_LINE" \
  --body "$SUMMARY_BODY"
