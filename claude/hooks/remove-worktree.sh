#!/bin/bash
# WorktreeRemove hook
# セッション終了時にworktreeをクリーンアップする

INPUT=$(cat)

WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path')
CWD=$(echo "$INPUT" | jq -r '.cwd')

if [ -z "$WORKTREE_PATH" ] || [ "$WORKTREE_PATH" = "null" ]; then
  exit 0
fi

if [ -z "$CWD" ] || [ "$CWD" = "null" ]; then
  exit 0
fi

cd "$CWD"

git worktree unlock "$WORKTREE_PATH" 2>/dev/null || true
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
rm -rf "$WORKTREE_PATH" 2>/dev/null || true
git worktree prune 2>/dev/null || true

exit 0
