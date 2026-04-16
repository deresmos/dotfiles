#!/bin/bash

send_discord() {
  local message="$1"
  if [ -n "$DISCORD_WEBHOOK_URL_FOR_CC" ]; then
    curl -s -X POST "$DISCORD_WEBHOOK_URL_FOR_CC" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$message\"}" > /dev/null 2>&1 || true
  fi
}

input=$(cat)
if [ -z "$input" ]; then
  echo "[Error] No input data provided."
  exit 1
fi

event_name=$(echo "$input" | jq -r '.hook_event_name')

echo $input | jq -c -r '.' >> ~/.claude/log.txt

if [ "$event_name" == "Stop" ]; then
  if [ -z "${CMUX_SURFACE_ID:-}" ]; then
    osascript -e 'display notification "✅ Task completed" with title "Claude Code" sound name "Glass"'
  fi
  send_discord "✅ タスクが完了しました"
elif [ "$event_name" == "Notification" ]; then
  message=$(echo "$input" | jq -r '.message')
  if [ -z "${CMUX_SURFACE_ID:-}" ]; then
    osascript -e "display notification \"⚠️ $message\" with title \"Claude Code\" sound name \"Bottle\""
  fi
  send_discord "⚠️ 操作が必要です: $message"
else
  exit 1
fi
