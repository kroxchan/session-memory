#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../skill/scripts" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export MEMORY_ROOT="$TEST_DIR/memory"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "creates sessions/YYYY-MM-DD-<topic>.md" {
  KEY="testproj@abcdef12"
  SUMMARY="This session covered the API redesign." \
  bash "$SCRIPT_DIR/sm-compress.sh" \
    --project-key "$KEY" \
    --topic "API redesign discussion" \
    --summary - <<< "$SUMMARY" > /dev/null
  ls_out="$(ls "$MEMORY_ROOT/sessions/projects/$KEY/sessions/" | grep -E 'api-redesign-discussion')"
  [[ -n "$ls_out" ]]
}

@test "entry appears in INDEX" {
  KEY="testproj@abcdef12"
  SUMMARY="Use Redis for sessions." \
  bash "$SCRIPT_DIR/sm-compress.sh" \
    --project-key "$KEY" \
    --topic "Session store decision" \
    --summary - <<< "$SUMMARY" > /dev/null
  index="$(cat "$MEMORY_ROOT/sessions/projects/$KEY/INDEX.md")"
  [[ "$index" == *"sessions/"*"-session-store-decision"* ]]
}

@test "fails if project-key is missing" {
  run bash "$SCRIPT_DIR/sm-compress.sh" --topic "test" --summary - <<< "body" 2>&1
  [[ $status -ne 0 ]]
}

@test "fails if topic is missing" {
  run bash "$SCRIPT_DIR/sm-compress.sh" --project-key "x@12345678" --summary - <<< "body" 2>&1
  [[ $status -ne 0 ]]
}

@test "slugifies topic into lowercase-hyphen filename" {
  bash "$SCRIPT_DIR/sm-compress.sh" \
    --project-key "testproj@abcdef12" \
    --topic "My API Discussion" \
    --summary - <<< "Content here." > /dev/null
  ls_out="$(ls "$MEMORY_ROOT/sessions/projects/testproj@abcdef12/sessions/" | grep 'my-api-discussion')"
  [[ -n "$ls_out" ]]
}
