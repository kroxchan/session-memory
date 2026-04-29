#!/usr/bin/env bash
# sm-project-key.sh — Compute deterministic project key from workspace path.
# Output format: <basename>@<md5-first-8>
#
# Usage:
#   sm-project-key.sh [workspace_path]
#
# If no arg given, uses current working directory.

set -euo pipefail

WORKSPACE="${1:-$PWD}"

# Resolve to absolute canonical path (handles ~, symlinks)
# Order of preference: realpath (Linux) → readlink -f (macOS+Linux) → cd+pwd
if command -v realpath >/dev/null 2>&1; then
  WORKSPACE="$(realpath "$WORKSPACE")"
elif command -v readlink >/dev/null 2>&1 && readlink -f "$WORKSPACE" >/dev/null 2>&1; then
  WORKSPACE="$(readlink -f "$WORKSPACE")"
else
  WORKSPACE="$(cd "$WORKSPACE" && pwd -L)"
fi

BASENAME="$(basename "$WORKSPACE")"

# MD5 first 8 chars — works on both macOS and Linux
if command -v md5 >/dev/null 2>&1; then
  HASH="$(printf '%s' "$WORKSPACE" | md5 | cut -c1-8)"
elif command -v md5sum >/dev/null 2>&1; then
  HASH="$(printf '%s' "$WORKSPACE" | md5sum | cut -c1-8)"
else
  echo "ERROR: neither md5 nor md5sum available" >&2
  exit 1
fi

printf '%s@%s\n' "$BASENAME" "$HASH"
