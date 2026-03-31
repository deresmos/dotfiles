#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SETTINGS="$SCRIPT_DIR/settings.common.json"
LOCAL_SETTINGS="$SCRIPT_DIR/settings.local.json"
CURRENT_SETTINGS="${HOME}/.claude/settings.json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

normalized_common="$tmp_dir/common.json"
normalized_current="$tmp_dir/current.json"
expected_settings="$tmp_dir/expected.json"

jq '.' "$COMMON_SETTINGS" > "$normalized_common"

if [ -f "$LOCAL_SETTINGS" ]; then
  jq -s 'reduce .[] as $item ({}; . * $item)' \
    "$COMMON_SETTINGS" \
    "$LOCAL_SETTINGS" \
    > "$expected_settings"
else
  cp "$normalized_common" "$expected_settings"
fi

echo "== effective diff: merged common/local config vs ~/.claude/settings.json =="
if [ -f "$CURRENT_SETTINGS" ]; then
  jq '.' "$CURRENT_SETTINGS" > "$normalized_current"
  if diff -u "$normalized_current" "$expected_settings"; then
    echo "No differences."
  fi
else
  echo "~/.claude/settings.json does not exist."
fi
