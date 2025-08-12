#!/bin/bash
# 標準入力からJSONデータをすべて読み込む
input=$(cat)
if [ -z "$input" ]; then
  echo "[Error] No input data provided."
  exit 1
fi


#===============================================================
# 関数定義
#===============================================================

# JSON入力から値を抽出するための共通関数
# 使用例: get_json_value '.model.display_name'
get_json_value() {
  local key="$1"
  echo "$input" | jq -r "$key"
}

#===============================================================
# メイン処理
#===============================================================

# エラー時にフォールバックメッセージを出力するtrapを設定
trap 'echo "[Error]"' ERR

# 定数を定義
COMPACTION_THRESHOLD=180000
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
NC='\033[0m' # 色をリセット

# jqを使ってJSONから値を抽出
# MODEL_NAME=$(get_json_value '.model.display_name')
SESSION_ID=$(get_json_value '.session_id')

# 初期値を設定
TOTAL_TOKENS=0
PERCENTAGE=0
TOKEN_DISPLAY="0"

# セッションIDが存在する場合、コンテキスト残量を計算
if [ -n "$SESSION_ID" ]; then
  # findコマンドで該当するjsonlファイルを探す
  TRANSCRIPT_FILE=$(find "$HOME/.claude/projects/" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)

  # ファイルが見つかった場合
  if [ -n "$TRANSCRIPT_FILE" ] && [ -f "$TRANSCRIPT_FILE" ]; then
    # jqを使い、最後のassistantメッセージのトークン数を合計
    # '-s'オプションで複数のJSONオブジェクトを配列として読み込み、最後の要素を選択
    TOTAL_TOKENS=$(jq -s '
      map(select(.type == "assistant" and .message.usage != null)) | 
      last | 
      .message.usage.input_tokens + 
      .message.usage.output_tokens + 
      .message.usage.cache_creation_input_tokens + 
      .message.usage.cache_read_input_tokens
    ' "$TRANSCRIPT_FILE")
  fi
fi

# jqが'null'を返した場合に0に設定
if [ -z "$TOTAL_TOKENS" ] || [ "$TOTAL_TOKENS" = "null" ]; then
  TOTAL_TOKENS=0
fi

# トークン数をM（ミリオン）、K（キロ）形式に整形
# bcコマンドで浮動小数点演算を行う
if (( $(echo "$TOTAL_TOKENS >= 1000000" | bc -l) )); then
  TOKEN_DISPLAY=$(echo "scale=1; $TOTAL_TOKENS / 1000000" | bc | sed 's/^\./0./')M
elif (( $(echo "$TOTAL_TOKENS >= 1000" | bc -l) )); then
  TOKEN_DISPLAY=$(echo "scale=1; $TOTAL_TOKENS / 1000" | bc | sed 's/^\./0./')K
else
  TOKEN_DISPLAY=$TOTAL_TOKENS
fi

# パーセンテージを計算
PERCENTAGE=$(echo "scale=1; ($TOTAL_TOKENS / $COMPACTION_THRESHOLD) * 100 / 1" | bc)
# パーセンテージが100%を超える場合は100に丸める
if (( $(echo "$PERCENTAGE > 100" | bc -l) )); then
  PERCENTAGE=100
fi

# パーセンテージに応じた色を設定
PERCENTAGE_COLOR=$GREEN
if (( $(echo "$PERCENTAGE >= 70" | bc -l) )); then
  PERCENTAGE_COLOR=$YELLOW
fi
if (( $(echo "$PERCENTAGE >= 90" | bc -l) )); then
  PERCENTAGE_COLOR=$RED
fi


get_model_name() { echo "$input" | jq -r '.model.display_name'; }
get_current_dir() { get_json_value '.workspace.current_dir'; }
get_project_dir() { echo "$input" | jq -r '.workspace.project_dir'; }
get_version() { echo "$input" | jq -r '.version'; }
get_git_branch() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
      BRANCH=$(git branch --show-current 2>/dev/null)
      if [ -n "$BRANCH" ]; then
          echo "$BRANCH"
      fi
  fi
}

DIR=$(get_current_dir)
GIT_BRANCH=$(get_git_branch)

# 最終的なステータス行を構築して出力
echo -e "[~${DIR#$HOME}] [${GIT_BRANCH}] | ${TOKEN_DISPLAY} (${PERCENTAGE_COLOR}${PERCENTAGE}%${NC})"
