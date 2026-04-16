#!/bin/bash
# WorktreeCreate hook
# --worktree <branch> で指定したブランチ名が origin に存在すればそれをチェックアウト、
# 存在しなければ origin/HEAD から新規ブランチを作成する

set -e

INPUT=$(cat)
echo "$INPUT" > /tmp/claude-worktree-hook-debug.json

WORKTREE_NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

if [ -z "$WORKTREE_NAME" ] || [ "$WORKTREE_NAME" = "null" ]; then
  echo "ERROR: name not found in input" >&2
  exit 1
fi

if [ -z "$CWD" ] || [ "$CWD" = "null" ]; then
  echo "ERROR: cwd not found in input" >&2
  exit 1
fi

WORKTREE_DIR_NAME="${WORKTREE_NAME//\//+}"
WORKTREE_PATH="$CWD/.claude/worktrees/$WORKTREE_DIR_NAME"
mkdir -p "$CWD/.claude/worktrees"

cd "$CWD"

# 既存のworktreeが残っている場合はクリーンアップ（ロック済みの場合も対応）
git worktree unlock "$WORKTREE_PATH" 2>/dev/null || true
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
rm -rf "$WORKTREE_PATH" 2>/dev/null || true
git worktree prune 2>/dev/null || true

if git show-ref --verify --quiet "refs/heads/$WORKTREE_NAME"; then
  # ローカルブランチが既に存在する場合はそのままチェックアウト
  git worktree add "$WORKTREE_PATH" "$WORKTREE_NAME" >/dev/null 2>&1
elif git show-ref --verify --quiet "refs/remotes/origin/$WORKTREE_NAME"; then
  # リモートブランチのみ存在する場合は新規ローカルブランチを作成してトラッキング
  git worktree add "$WORKTREE_PATH" -b "$WORKTREE_NAME" --track "origin/$WORKTREE_NAME" >/dev/null 2>&1
else
  # 存在しない場合は origin/HEAD から新規作成
  git worktree add "$WORKTREE_PATH" -b "$WORKTREE_NAME" "origin/HEAD" >/dev/null 2>&1
fi

echo "$WORKTREE_PATH"
exit 0
