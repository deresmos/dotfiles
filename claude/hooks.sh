#!/bin/bash

input=$(cat)
if [ -z "$input" ]; then
  echo "[Error] No input data provided."
  exit 1
fi

event_name=$(echo "$input" | jq -r '.hook_event_name')

echo $input | jq -c -r '.' >> ~/.claude/log.txt
if [ "$event_name" == "Stop" ]; then
  osascript -e 'display notification "✅ Task completed" with title "Claude Code" sound name "Glass"'
elif [ "$event_name" == "Notification" ]; then
  message=$(echo "$input" | jq -r '.message')
  # messageを変数展開したい
  osascript -e "display notification \"⚠️ $message\" with title \"Claude Code\" sound name \"Bottle\""
else
  exit 1
fi

