#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SETTINGS="$SCRIPT_DIR/settings.common.json"
LOCAL_SETTINGS="$SCRIPT_DIR/settings.local.json"
OUTPUT_SETTINGS="${HOME}/.claude/settings.json"

mkdir -p "$(dirname "$OUTPUT_SETTINGS")"

if [ -L "$OUTPUT_SETTINGS" ]; then
  rm "$OUTPUT_SETTINGS"
fi

if [ -f "$LOCAL_SETTINGS" ]; then
  jq -s 'reduce .[] as $item ({}; . * $item)' \
    "$COMMON_SETTINGS" \
    "$LOCAL_SETTINGS" \
    > "$OUTPUT_SETTINGS"
else
  jq '.' "$COMMON_SETTINGS" > "$OUTPUT_SETTINGS"
fi
