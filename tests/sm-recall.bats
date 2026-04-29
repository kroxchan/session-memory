#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../skill/scripts" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export MEMORY_ROOT="$TEST_DIR/memory"
  WORKSPACE_DIR="$TEST_DIR/workspace"
  mkdir -p "$WORKSPACE_DIR"

  KEY="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  PROJ_DIR="$MEMORY_ROOT/sessions/projects/$KEY"
  mkdir -p "$PROJ_DIR/facts" "$PROJ_DIR/sessions" "$PROJ_DIR/decisions"

  echo "# API conventions" > "$PROJ_DIR/facts/api-conventions.md"
  echo "Use Redis for session storage." >> "$PROJ_DIR/facts/api-conventions.md"
  echo "# Auth decisions" > "$PROJ_DIR/decisions.md"
  echo "Use JWT tokens." >> "$PROJ_DIR/decisions.md"
  mkdir -p "$MEMORY_ROOT/sessions/_global/facts"
  echo "# Global fact" > "$MEMORY_ROOT/sessions/_global/facts/pref.md"
  echo "I prefer TypeScript." >> "$MEMORY_ROOT/sessions/_global/facts/pref.md"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Use --project-key so we don't depend on PWD in subshell
KEY="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"

@test "finds keyword in project file" {
  output="$(bash "$SCRIPT_DIR/sm-recall.sh" "Redis" --project-key "$KEY")"
  [[ "$output" == *"Redis"* ]]
}

@test "finds keyword in global file" {
  output="$(bash "$SCRIPT_DIR/sm-recall.sh" "TypeScript" --project-key "$KEY")"
  [[ "$output" == *"TypeScript"* ]]
}

@test "shows no hits when query absent" {
  output="$(bash "$SCRIPT_DIR/sm-recall.sh" "NONEXISTENTKEYWORDXYZ123" --project-key "$KEY")"
  [[ "$output" == *"(no hits)"* ]]
}

@test "outputs project section when query matches" {
  output="$(bash "$SCRIPT_DIR/sm-recall.sh" "session" --project-key "$KEY")"
  [[ "$output" == *"projects/"* ]]
  [[ "$output" == *"Redis"* ]]
}

@test "searches are case-insensitive" {
  output_lower="$(bash "$SCRIPT_DIR/sm-recall.sh" "redis" --project-key "$KEY")"
  [[ "$output_lower" == *"Redis"* ]]
  output_upper="$(bash "$SCRIPT_DIR/sm-recall.sh" "REDIS" --project-key "$KEY")"
  [[ "$output_upper" == *"Redis"* ]]
}

@test "exits with error when query is empty" {
  run bash "$SCRIPT_DIR/sm-recall.sh" "" --project-key "$KEY" 2>&1
  [[ $status -ne 0 ]]
}
