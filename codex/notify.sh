#!/bin/bash

set -euo pipefail

payload="${1-}"
if [ -z "$payload" ]; then
  payload="$(cat || true)"
fi

if [ -z "$payload" ]; then
  exit 0
fi

mkdir -p "$HOME/.codex" 2>/dev/null || true
{
  printf '%s\n' "$payload" >> "$HOME/.codex/notify.log"
} 2>/dev/null || true

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

title=$(printf '%s' "$payload" | jq -r '
  if type != "object" then
    "Codex"
  elif ((.event? // .type? // "") | test("error|fail"; "i")) or (.error? != null) then
    "Codex Error"
  else
    "Codex"
  end
')

message=$(printf '%s' "$payload" | jq -r '
  if type != "object" then
    tostring
  else
    (
      .message?
      // .last_agent_message?
      // .summary?
      // .event?
      // .type?
      // "Task completed"
    ) | tostring
  end
')

sound=$(printf '%s' "$payload" | jq -r '
  if type == "object" and (((.event? // .type? // "") | test("error|fail"; "i")) or (.error? != null)) then
    "Bottle"
  else
    "Glass"
  end
')

escaped_message=${message//\\/\\\\}
escaped_message=${escaped_message//\"/\\\"}
escaped_title=${title//\\/\\\\}
escaped_title=${escaped_title//\"/\\\"}

osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\" sound name \"$sound\"" || true

if [ -n "${DISCORD_WEBHOOK_URL_FOR_CC:-}" ]; then
  discord_message=$(printf '%s' "$payload" | jq -r '
    if type == "object" and (((.event? // .type? // "") | test("error|fail"; "i")) or (.error? != null)) then
      "❌ Codex エラー: " + ((.message? // .event? // .type? // "Error") | tostring)
    else
      "✅ Codex タスクが完了しました: " + ((.message? // .last_agent_message? // .summary? // .event? // .type? // "Task completed") | tostring)
    end
  ')
  curl -s -X POST "$DISCORD_WEBHOOK_URL_FOR_CC" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(printf '%s' "$discord_message" | jq -Rs .)}" > /dev/null 2>&1 || true
fi
