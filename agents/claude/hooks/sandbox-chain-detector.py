#!/usr/bin/env python3
"""excludedCommands を連結実行していないか検知して指摘する。

excludedCommands のコマンドは、`cd app && ...` のように他のコマンドと連結すると
除外パターンに一致せずサンドボックス内で実行され、権限エラーになる。
検知の基準は「連結コマンドに excludedCommands 相当のセグメントが含まれる」こと。
ただし成功時のノイズを避けるため、次のいずれかを満たすときだけ発火する。
- PostToolUseFailure イベントである
- 出力にサンドボックス由来、または一般的なエラーの文言がある
  (`make ... | tail` のようにパイプで終了コードが 0 になり、
  PostToolUse として届くケースを拾うため)
"""

import fnmatch
import json
import os
import re
import sys

SANDBOX_ERROR = re.compile(
    r"Operation not permitted|sandbox_violations|sandbox-exec|deny\(\d+\)|"
    r"Sandbox:|blocked by (the )?sandbox",
    re.IGNORECASE,
)
# サンドボックス以外も含む一般的なエラー文言(補助条件)
GENERIC_ERROR = re.compile(
    r"\berror\b|\bfailed\b|\bfailure\b|could not|cannot|permission denied|"
    r"\*\*\* \[|exit code [1-9]|エラー|失敗",
    re.IGNORECASE,
)
# リダイレクト(2>&1, >file, 2>/dev/null, &>file, <file など)
REDIRECT = re.compile(r"\s*(?:\d*|&)(?:>>?|<)&?\s*[^\s;|&]+")
# 連結演算子: && || ; | 改行
CHAIN_SPLIT = re.compile(r"&&|\|\||;|\||\n")


def settings_paths(project_dir: str) -> list[str]:
    """excludedCommands を持ちうる全スコープの settings ファイル。"""
    return [
        # managed
        "/Library/Application Support/ClaudeCode/managed-settings.json",
        # user
        os.path.expanduser("~/.claude/settings.json"),
        os.path.expanduser("~/.claude/settings.local.json"),
        # project (workspace)
        os.path.join(project_dir, ".claude", "settings.json"),
        # local
        os.path.join(project_dir, ".claude", "settings.local.json"),
    ]


def load_excluded(project_dir: str) -> list[str]:
    """全スコープの excludedCommands をマージして返す(重複は除く)。"""
    merged: list[str] = []
    for path in settings_paths(project_dir):
        try:
            with open(path, encoding="utf-8") as f:
                patterns = json.load(f).get("sandbox", {}).get("excludedCommands", [])
        except (OSError, ValueError, AttributeError):
            continue
        for p in patterns:
            if isinstance(p, str) and p not in merged:
                merged.append(p)
    return merged


def normalize(segment: str) -> str:
    """照合用にリダイレクトを除去し、空白を整える。"""
    return " ".join(REDIRECT.sub("", segment).split())


def matches(segment: str, pattern: str) -> bool:
    if pattern.endswith(":*"):
        prefix = pattern[:-2]
        return segment == prefix or segment.startswith(prefix + " ")
    return fnmatch.fnmatch(segment, pattern)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if data.get("tool_name") != "Bash":
        return

    command = (data.get("tool_input") or {}).get("command", "")
    output = json.dumps(
        [data.get("error"), data.get("tool_response")], ensure_ascii=False
    )
    event = data.get("hook_event_name", "PostToolUseFailure")
    if not (
        event == "PostToolUseFailure"
        or SANDBOX_ERROR.search(output)
        or GENERIC_ERROR.search(output)
    ):
        return

    segments = [normalize(s) for s in CHAIN_SPLIT.split(command)]
    segments = [s for s in segments if s]
    if len(segments) < 2:
        return

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    excluded = load_excluded(project_dir)
    hit = [s for s in segments if any(matches(s, p) for p in excluded)]
    if not hit:
        return

    message = (
        "サンドボックスエラーの原因は、excludedCommands のコマンドを他のコマンドと連結して"
        "実行したことの可能性が高い(連結すると除外パターンに一致せずサンドボックス内で動く)。"
        f"連結せず単体で実行し直すこと。対象: {hit}。"
        "cd が必要な場合は cd を付けず、リポジトリルートからのパス"
        "(例: bash app/tool/web_headless.sh all)で実行する。"
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": event,
                    "additionalContext": message,
                }
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
