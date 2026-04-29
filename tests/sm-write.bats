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

@test "creates target file if missing" {
  KEY="testproj@abcdef12"
  bash "$SCRIPT_DIR/sm-write.sh" \
    --project-key "$KEY" \
    --file "requirements.md" \
    --title "TraceID logging" \
    --summary "traceid" \
    --body "All handlers log traceID."
  [[ -f "$MEMORY_ROOT/sessions/projects/$KEY/requirements.md" ]]
}

@test "appends to existing file" {
  KEY="testproj@abcdef12"
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "req.md" --title "First" --summary "f" --body "First entry."
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "req.md" --title "Second" --summary "s" --body "Second entry."
  content="$(cat "$MEMORY_ROOT/sessions/projects/$KEY/req.md")"
  [[ "$content" == *"First entry."* ]]
  [[ "$content" == *"Second entry."* ]]
}

@test "creates INDEX.md if missing" {
  KEY="testproj@abcdef12"
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "req.md" --title "T" --summary "t" --body "Body."
  [[ -f "$MEMORY_ROOT/sessions/projects/$KEY/INDEX.md" ]]
}

@test "INDEX entry contains file path and summary" {
  KEY="testproj@abcdef12"
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "req.md" --title "T" --summary "每个 handler 记录 traceID" --body "Body."
  index="$(cat "$MEMORY_ROOT/sessions/projects/$KEY/INDEX.md")"
  [[ "$index" == *"- req.md —"* ]]
}

@test "INDEX entry has 4-char cksum hash for uniqueness" {
  KEY="testproj@abcdef12"
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "req.md" --title "MyTitle" --summary "sum" --body "Body."
  index="$(cat "$MEMORY_ROOT/sessions/projects/$KEY/INDEX.md")"
  [[ "$index" =~ \[....\]$ ]]
}

@test "body-stdin reads from pipe (recommended usage)" {
  KEY="testproj@abcdef12"
  echo "Multi-line body here." | bash "$SCRIPT_DIR/sm-write.sh" \
    --project-key "$KEY" --file "dec.md" --title "Decision" --summary "decision" --body-stdin
  content="$(cat "$MEMORY_ROOT/sessions/projects/$KEY/dec.md")"
  [[ "$content" == *"Multi-line body here."* ]]
}

@test "--current strikes previous CURRENT entries" {
  KEY="testproj@abcdef12"
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "dec.md" --title "Use Redis" --summary "redis" --body "Old body." --current
  bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "dec.md" --title "Use Postgres" --summary "postgres" --body "New body." --current
  content="$(cat "$MEMORY_ROOT/sessions/projects/$KEY/dec.md")"
  [[ "$content" == *"~~Use Redis~~"* ]]
  [[ "$content" == *"★ CURRENT Use Postgres"* ]]
  [[ "$content" == *"superseded @"* ]]
}

@test "--body and --body-stdin are mutually exclusive" {
  KEY="testproj@abcdef12"
  run bash "$SCRIPT_DIR/sm-write.sh" \
    --project-key "$KEY" --file "req.md" --title "T" --summary "s" \
    --body "x" --body-stdin 2>&1
  [[ $status -ne 0 ]]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "exits with error if body is empty" {
  KEY="testproj@abcdef12"
  run bash "$SCRIPT_DIR/sm-write.sh" --project-key "$KEY" --file "req.md" --title "T" --summary "s" --body "" 2>&1
  [[ $status -ne 0 ]]
}
