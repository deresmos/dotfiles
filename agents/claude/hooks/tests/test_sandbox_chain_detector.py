"""sandbox-chain-detector.py のテスト。

実行: python3 -m unittest discover -s agents/claude/hooks/tests -v
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "sandbox-chain-detector.py"

spec = importlib.util.spec_from_file_location("detector", SCRIPT)
detector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(detector)

SANDBOX_ERR = "Operation not permitted"


def write_settings(path: Path, excluded: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"sandbox": {"excludedCommands": excluded}}))


class MatchesTest(unittest.TestCase):
    def test_prefix_pattern(self):
        self.assertTrue(detector.matches("gh pr list", "gh:*"))
        self.assertTrue(detector.matches("gh", "gh:*"))
        self.assertFalse(detector.matches("ghost run", "gh:*"))

    def test_glob_pattern(self):
        self.assertTrue(detector.matches("codex exec foo", "codex *"))
        self.assertFalse(detector.matches("git status", "codex *"))


class LoadExcludedTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home"
        self.proj = Path(self.tmp.name) / "proj"
        self.home.mkdir()
        self.proj.mkdir()
        old_home = os.environ.get("HOME")
        os.environ["HOME"] = str(self.home)
        self.addCleanup(
            lambda: os.environ.__setitem__("HOME", old_home)
            if old_home is not None
            else os.environ.pop("HOME", None)
        )
        # 実機の managed-settings を読まないよう除外する
        orig = detector.settings_paths
        detector.settings_paths = lambda p: [
            x for x in orig(p) if not x.startswith("/Library")
        ]
        self.addCleanup(lambda: setattr(detector, "settings_paths", orig))

    def test_merges_all_scopes(self):
        write_settings(self.home / ".claude" / "settings.json", ["user *"])
        write_settings(self.home / ".claude" / "settings.local.json", ["userlocal *"])
        write_settings(self.proj / ".claude" / "settings.json", ["proj *"])
        write_settings(self.proj / ".claude" / "settings.local.json", ["local *"])
        got = detector.load_excluded(str(self.proj))
        self.assertEqual(
            sorted(got), ["local *", "proj *", "user *", "userlocal *"]
        )

    def test_dedupes(self):
        write_settings(self.home / ".claude" / "settings.json", ["gh *"])
        write_settings(self.proj / ".claude" / "settings.json", ["gh *"])
        self.assertEqual(detector.load_excluded(str(self.proj)), ["gh *"])

    def test_missing_files(self):
        self.assertEqual(detector.load_excluded(str(self.proj)), [])

    def test_broken_json_is_skipped(self):
        bad = self.proj / ".claude" / "settings.json"
        bad.parent.mkdir(parents=True)
        bad.write_text("{not json")
        write_settings(self.home / ".claude" / "settings.json", ["ok *"])
        self.assertEqual(detector.load_excluded(str(self.proj)), ["ok *"])

    def test_non_dict_json_is_skipped(self):
        p = self.proj / ".claude" / "settings.json"
        p.parent.mkdir(parents=True)
        p.write_text("[]")
        self.assertEqual(detector.load_excluded(str(self.proj)), [])

    def test_non_string_patterns_ignored(self):
        write_settings(self.proj / ".claude" / "settings.json", ["a *", 1, None])
        self.assertEqual(detector.load_excluded(str(self.proj)), ["a *"])


class EndToEndTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home"
        self.proj = Path(self.tmp.name) / "proj"
        self.home.mkdir()
        self.proj.mkdir()

    def run_hook(self, command, response=SANDBOX_ERR, tool="Bash"):
        payload = {
            "tool_name": tool,
            "tool_input": {"command": command},
            "tool_response": response,
            "hook_event_name": "PostToolUseFailure",
        }
        env = {
            **os.environ,
            "HOME": str(self.home),
            "CLAUDE_PROJECT_DIR": str(self.proj),
        }
        r = subprocess.run(
            [sys.executable, str(SCRIPT)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout) if r.stdout.strip() else None

    def test_detects_pipe_with_user_scope_pattern(self):
        write_settings(self.home / ".claude" / "settings.json", ["gh:*"])
        out = self.run_hook("gh pr list | head -300")
        self.assertIsNotNone(out)
        ctx = out["hookSpecificOutput"]["additionalContext"]
        self.assertIn("gh pr list", ctx)

    def test_detects_with_local_scope_pattern(self):
        write_settings(self.proj / ".claude" / "settings.local.json", ["gh:*"])
        self.assertIsNotNone(self.run_hook("cd x && gh pr list"))

    def test_detects_with_project_scope_pattern(self):
        write_settings(self.proj / ".claude" / "settings.json", ["codex *"])
        self.assertIsNotNone(self.run_hook("cd x; codex exec hi"))

    def test_pattern_not_registered(self):
        # gh が excludedCommands に無ければ検知されない
        write_settings(self.home / ".claude" / "settings.json", ["codex *"])
        self.assertIsNone(self.run_hook("gh pr list | head -300"))

    def test_single_command_not_flagged(self):
        write_settings(self.home / ".claude" / "settings.json", ["gh:*"])
        self.assertIsNone(self.run_hook("gh pr list"))

    def test_no_sandbox_error_not_flagged(self):
        write_settings(self.home / ".claude" / "settings.json", ["gh:*"])
        self.assertIsNone(self.run_hook("gh pr list | head", response="boom"))

    def test_non_bash_tool_ignored(self):
        write_settings(self.home / ".claude" / "settings.json", ["gh:*"])
        self.assertIsNone(self.run_hook("gh a | head", tool="Read"))

    def test_invalid_stdin(self):
        r = subprocess.run(
            [sys.executable, str(SCRIPT)],
            input="not json",
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
