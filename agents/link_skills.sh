#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC_DIR="$SCRIPT_DIR/skills"
CLAUDE_SKILLS_DEST="$HOME/.claude/skills"
CODEX_SKILLS_DEST="$HOME/.agents/skills"
GEMINI_SKILLS_DEST="$HOME/.gemini/skills"

mkdir -p "$CLAUDE_SKILLS_DEST"
mkdir -p "$CODEX_SKILLS_DEST"
mkdir -p "$GEMINI_SKILLS_DEST"

# 既存のリンクをクリーンアップしたい場合はここで処理するが、
# 今回は単に link を更新する形にする

link_skills_from() {
    local src_dir="$1"
    [ -d "$src_dir" ] || return 0
    for skill in "$src_dir"/*; do
        [ -d "$skill" ] || continue
        skill_name=$(basename "$skill")
        # local/ はこのマシン専用skillsの置き場(git管理外)。skill自体としては扱わない
        [ "$skill_name" = "local" ] && continue

        echo "Linking skill: $skill_name"
        ln -sfn "$skill" "$CLAUDE_SKILLS_DEST/$skill_name"
        ln -sfn "$skill" "$CODEX_SKILLS_DEST/$skill_name"
        ln -sfn "$skill" "$GEMINI_SKILLS_DEST/$skill_name"
    done
}

link_skills_from "$SKILLS_SRC_DIR"
link_skills_from "$SKILLS_SRC_DIR/local"
