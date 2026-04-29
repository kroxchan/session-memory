#!/usr/bin/env bash
# sm-bootstrap.sh — Ensure project memory dirs exist and print CORE + INDEX
# for injection at conversation start.
#
# Usage:
#   sm-bootstrap.sh [workspace_path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${MEMORY_ROOT:=/Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory}"

WORKSPACE="${1:-$PWD}"
PROJECT_KEY="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE")"

GLOBAL_DIR="$MEMORY_ROOT/sessions/_global"
PROJECT_DIR="$MEMORY_ROOT/sessions/projects/$PROJECT_KEY"

# ---- Ensure global dirs ------------------------------------------------------
mkdir -p "$GLOBAL_DIR/facts"
if [[ ! -f "$GLOBAL_DIR/INDEX.md" ]]; then
  cp "$SKILL_ROOT/references/templates/global-INDEX.md.tpl" "$GLOBAL_DIR/INDEX.md"
fi
if [[ ! -f "$GLOBAL_DIR/CORE.md" ]]; then
  cp "$SKILL_ROOT/references/templates/global-CORE.md.tpl" "$GLOBAL_DIR/CORE.md"
fi

# ---- Ensure project dirs -----------------------------------------------------
mkdir -p "$PROJECT_DIR/facts" "$PROJECT_DIR/sessions"
if [[ ! -f "$PROJECT_DIR/INDEX.md" ]]; then
  sed "s|{{PROJECT_KEY}}|$PROJECT_KEY|g; s|{{WORKSPACE}}|$WORKSPACE|g" \
    "$SKILL_ROOT/references/templates/INDEX.md.tpl" > "$PROJECT_DIR/INDEX.md"
fi
if [[ ! -f "$PROJECT_DIR/CORE.md" ]]; then
  sed "s|{{PROJECT_KEY}}|$PROJECT_KEY|g; s|{{WORKSPACE}}|$WORKSPACE|g; s|{{DATE}}|$(date +%Y-%m-%d)|g" \
    "$SKILL_ROOT/references/templates/CORE.md.tpl" > "$PROJECT_DIR/CORE.md"
fi
[[ ! -f "$PROJECT_DIR/requirements.md" ]] && echo "# Requirements — $PROJECT_KEY" > "$PROJECT_DIR/requirements.md"
[[ ! -f "$PROJECT_DIR/decisions.md" ]] && echo "# Decisions — $PROJECT_KEY" > "$PROJECT_DIR/decisions.md"

# ---- Print bootstrap content -------------------------------------------------
cat <<EOF
=== SESSION MEMORY BOOTSTRAP ===
project_key: $PROJECT_KEY
workspace:   $WORKSPACE
memory_root: $MEMORY_ROOT

--- _global/INDEX.md ---
$(cat "$GLOBAL_DIR/INDEX.md")

--- _global/CORE.md ---
$(cat "$GLOBAL_DIR/CORE.md")

--- projects/$PROJECT_KEY/INDEX.md ---
$(cat "$PROJECT_DIR/INDEX.md")

--- projects/$PROJECT_KEY/CORE.md ---
$(cat "$PROJECT_DIR/CORE.md")
=== END BOOTSTRAP ===
EOF
