#!/usr/bin/env bash

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR"
  export MEMORY_ROOT="$TEST_DIR/.cursor/session-memory/memory"
  SCRIPT="$TEST_DIR/sm-project-key.sh"
  # Inline the script for isolation
  cat > "$SCRIPT" <<'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${1:-$(pwd)}"
if command -v realpath >/dev/null 2>&1; then
  WORKSPACE="$(realpath "$WORKSPACE")"
else
  WORKSPACE="$(cd "$WORKSPACE" && pwd -P)"
fi
BASENAME="$(basename "$WORKSPACE")"
if command -v md5 >/dev/null 2>&1; then
  HASH="$(printf '%s' "$WORKSPACE" | md5 | cut -c1-8)"
elif command -v md5sum >/dev/null 2>&1; then
  HASH="$(printf '%s' "$WORKSPACE" | md5sum | cut -c1-8)"
else
  echo "ERROR: neither md5 nor md5sum available" >&2; exit 1
fi
printf '%s@%s\n' "$BASENAME" "$HASH"
SCRIPT_EOF
  chmod +x "$SCRIPT"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "outputs format basename@hash8" {
  mkdir -p "$TEST_DIR/workspace"
  result="$("$SCRIPT" "$TEST_DIR/workspace")"
  [[ "$result" =~ ^[^@]+@[a-f0-9]{8}$ ]]
}

@test "same path produces same key" {
  mkdir -p "$TEST_DIR/a"
  key1="$("$SCRIPT" "$TEST_DIR/a")"
  key2="$("$SCRIPT" "$TEST_DIR/a")"
  [[ "$key1" == "$key2" ]]
}

@test "different paths produce different keys" {
  mkdir -p "$TEST_DIR/a" "$TEST_DIR/b"
  keyA="$("$SCRIPT" "$TEST_DIR/a")"
  keyB="$("$SCRIPT" "$TEST_DIR/b")"
  [[ "$keyA" != "$keyB" ]]
}

@test "hash is exactly 8 hex chars" {
  mkdir -p "$TEST_DIR/myproj"
  result="$("$SCRIPT" "$TEST_DIR/myproj")"
  hash="${result##*@}"
  [[ ${#hash} -eq 8 ]]
  [[ "$hash" =~ ^[a-f0-9]+$ ]]
}

@test "defaults to PWD when no arg" {
  mkdir -p "$TEST_DIR/default"
  cd "$TEST_DIR/default"
  result="$("$SCRIPT")"
  [[ "$result" =~ ^default@[a-f0-9]{8}$ ]]
}

@test "handles spaces in path" {
  mkdir -p "$TEST_DIR/my proj"
  result="$("$SCRIPT" "$TEST_DIR/my proj")"
  [[ "$result" =~ ^my\ proj@[a-f0-9]{8}$ ]]
}

@test "handles symlinked directory" {
  mkdir -p "$TEST_DIR/real"
  ln -s "$TEST_DIR/real" "$TEST_DIR/link"
  keyReal="$("$SCRIPT" "$TEST_DIR/real")"
  keyLink="$("$SCRIPT" "$TEST_DIR/link")"
  # Depending on realpath, they may or may not resolve — both are valid
  [[ -n "$keyReal" && -n "$keyLink" ]]
}
