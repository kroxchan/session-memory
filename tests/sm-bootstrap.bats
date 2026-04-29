#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../skill/scripts" && pwd)"
SKILL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../skill" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export MEMORY_ROOT="$TEST_DIR/memory"
  WORKSPACE_DIR="$TEST_DIR/workspace"
  mkdir -p "$WORKSPACE_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "creates _global/INDEX.md if missing" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  [[ -f "$MEMORY_ROOT/sessions/_global/INDEX.md" ]]
}

@test "creates _global/CORE.md if missing" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  [[ -f "$MEMORY_ROOT/sessions/_global/CORE.md" ]]
}

@test "creates project/INDEX.md if missing" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  key="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  [[ -f "$MEMORY_ROOT/sessions/projects/$key/INDEX.md" ]]
}

@test "creates project/CORE.md if missing" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  key="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  [[ -f "$MEMORY_ROOT/sessions/projects/$key/CORE.md" ]]
}

@test "creates requirements.md and decisions.md" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  key="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  [[ -f "$MEMORY_ROOT/sessions/projects/$key/requirements.md" ]]
  [[ -f "$MEMORY_ROOT/sessions/projects/$key/decisions.md" ]]
}

@test "prints bootstrap output to stdout" {
  output="$(bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR")"
  [[ "$output" == *"SESSION MEMORY BOOTSTRAP"* ]]
  [[ "$output" == *"END BOOTSTRAP"* ]]
}

@test "prints project_key in output" {
  key="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  output="$(bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR")"
  [[ "$output" == *"$key"* ]]
}

@test "skips existing files on re-run (not overwritten)" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  key="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  before_mtime="$(stat -f %m "$MEMORY_ROOT/sessions/projects/$key/CORE.md")"
  sleep 1
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  after_mtime="$(stat -f %m "$MEMORY_ROOT/sessions/projects/$key/CORE.md")"
  [[ "$before_mtime" -eq "$after_mtime" ]]
}

@test "fills workspace placeholder in templates" {
  bash "$SCRIPT_DIR/sm-bootstrap.sh" "$WORKSPACE_DIR" > /dev/null
  key="$(bash "$SCRIPT_DIR/sm-project-key.sh" "$WORKSPACE_DIR")"
  index_content="$(cat "$MEMORY_ROOT/sessions/projects/$key/INDEX.md")"
  [[ "$index_content" == *"$WORKSPACE_DIR"* ]]
}
