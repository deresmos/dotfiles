#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml", "tomlkit"]
# ///
"""プロジェクトの Claude Code / Codex の設定へ、YAML 定義を追記する。

- 既に同じ設定があれば SKIP、無いものだけ追加 (既存の値は変更しない)
- 先に書き込み先と差分を表示し、確認 (y) を取ってから書き込む
- 複数のプリセット (settings/<name>.yaml) は 1 つにまとめる。省略時は設定ディレクトリのうち、
  最上位に `agent_settings: true` を書いた YAML すべて (無関係な YAML を巻き込まないための印)
- settings/common.yaml は常に含まれる共通設定 (プリセット名を指定しても自動追加。除外は --no-common)

YAML は Claude Code の settings.json と同じ構造で書く:
  agent_settings: true     # プリセットの印 (ディレクトリ走査の対象にする。設定には出力されない)
  sandbox:
    filesystem:
      allowWrite: [~/.config/tool_state]
  permissions:
    allow: ["Bash(git status *)", "WebFetch(domain:github.com)"]
  hooks:
    PostToolUse:
      - matcher: Edit
        hooks: [{type: command, command: "make fmt"}]
  env: {FOO: bar}          # その他のキーも settings.json へそのままマージ
  codex:                   # Codex 専用 (config.toml へそのままマージ)
    model: gpt-5
    hooks:                 # codex.hooks だけは config.toml ではなく hooks.json へ (共通 hooks に重ねる)
      Stop:
        - hooks: [{type: command, command: "~/.codex/x.sh", timeout: 3000}]
  claude:                  # Claude 専用 (settings.json へトップレベルとしてマージ。Codex には渡らない)
    hooks:
      PostToolUse:
        - matcher: Edit
          hooks: [{type: command, command: "make fmt"}]

マージ規則: dict は再帰、list は和集合 (hooks は matcher+command 単位)、scalar は未設定時のみ設定
(既存値と異なる場合は上書きせず警告)。permissions は allow/ask/deny 間の競合もスキップする。

Codex への変換:
  sandbox.filesystem.allowWrite -> config.toml [sandbox_workspace_write].writable_roots (~ は展開)
  permissions の Bash(...)      -> rules/default.rules の prefix_rule (Bash 以外は無視)
  hooks / codex.hooks           -> hooks.json (構造は同じ。イベント名の違いは確認すること)
  codex:                        -> config.toml
  上記以外のキーは Claude のみ (無視した内容は表示)

逆方向 (適用先にあって YAML に無い設定の抽出, Claude のみ):
  agent_settings.py -x -s user           # ~/.claude/settings.json のうち settings/ に無いものを YAML で表示

usage:
  agent_settings.py                      # settings/ 内の全 YAML を cwd へ
  agent_settings.py flutter go -n        # 指定分だけ、dry-run
  agent_settings.py -y                   # 確認なしで書き込み
  agent_settings.py -d ./                # カレントの YAML のうち `agent_settings: true` があるものだけ
  agent_settings.py -d ./podman.yml      # ディレクトリではなく YAML ファイル 1 つだけを適用 (マーカー不要)
  agent_settings.py -d ~/x/settings -w ~/proj -s local -t claude
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import shlex
import sys
from dataclasses import dataclass, field
from pathlib import Path

import tomlkit
import yaml

SCOPES = ("workspace", "local", "user")
TARGETS = ("claude", "codex")
DECISIONS = ("allow", "ask", "deny")
CODEX_DECISION = {"allow": "allow", "ask": "prompt", "deny": "forbidden"}
DEFAULT_DIR = Path(__file__).resolve().parent / "settings"
# プリセット YAML の最上位に `agent_settings: true` を書いたものだけをディレクトリ走査の対象にする
# (compose.yaml など無関係な YAML を巻き込まないため)。マージ時にこのキーは取り除く。
MARKER = "agent_settings"
# 設定ディレクトリ直下のこのサブディレクトリは、このマシン専用(git管理外)のプリセット置き場
LOCAL_DIRNAME = "local"


# ---------- 入力 ----------
def is_preset(path: Path) -> bool:
    try:
        raw = yaml.safe_load(path.read_text())
    except (yaml.YAMLError, UnicodeDecodeError):
        return False
    return isinstance(raw, dict) and raw.get(MARKER) is True


def collect_presets(base: Path) -> list[Path]:
    """base がファイルならそれ 1 つ (マーカー不要)、ディレクトリなら直下でマーカーのある YAML だけ。"""
    if base.is_file():
        return [base]
    if not base.is_dir():
        sys.exit(f"error: {base} が見つかりません (ディレクトリまたは YAML ファイルを指定してください)")
    files = []
    # base/local/ はこのマシン専用 (git管理外) のプリセット置き場。直下の後に読み込む
    candidates = sorted([*base.glob("*.yaml"), *base.glob("*.yml")])
    candidates += sorted([*(base / LOCAL_DIRNAME).glob("*.yaml"), *(base / LOCAL_DIRNAME).glob("*.yml")])
    for f in candidates:
        if is_preset(f):
            files.append(f)
        else:
            print(f"skip: {f} (最上位に `{MARKER}: true` が無いためプリセット対象外)")
    return files



def find_preset(name: str, base: Path) -> Path:
    p = Path(name).expanduser()
    if p.suffix in (".yaml", ".yml") and p.is_file():
        return p
    for d in (base, base / LOCAL_DIRNAME):
        for ext in (".yaml", ".yml"):
            c = d / f"{name}{ext}"
            if c.is_file():
                return c
    sys.exit(f"error: {name} が {base} (または {base / LOCAL_DIRNAME}) に見つかりません (.yaml/.yml)")


def load_preset(path: Path) -> dict:
    raw = yaml.safe_load(path.read_text()) or {}
    if not isinstance(raw, dict):
        sys.exit(f"error: {path}: 最上位は mapping にしてください")
    raw.pop(MARKER, None)  # 識別用のキーは設定として出力しない
    return raw


def norm(v):
    """比較用の正規化: ~ 展開・末尾 / 除去 (文字列以外はそのまま)。"""
    if isinstance(v, str):
        if v.startswith("Bash("):  # 旧形式 Bash(cmd:*) と Bash(cmd *) は同義
            return re.sub(r":\*\)$", " *)", v)
        return str(Path(v).expanduser()).rstrip("/") or "/"
    return v


def contains(lst, item) -> bool:
    n = norm(item)
    return any(norm(x) == n for x in lst)


def same_hook(a: dict, b: dict) -> bool:
    if "command" in a or "command" in b:
        return a.get("type") == b.get("type") and a.get("command") == b.get("command")
    return a == b


# ---------- 計画 ----------
@dataclass
class Plan:
    target: str
    path: Path
    added: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    new_text: str | None = None  # 追加があるときだけ書き込み内容が入る


def merge_into(cur, want: dict, plan: Plan, prefix: str = "") -> None:
    """want を cur へ追記マージする。既存値は変更しない。"""
    for k, v in want.items():
        key = f"{prefix}.{k}" if prefix else str(k)
        handler = HANDLERS.get(key)
        if handler:
            handler(cur, k, v, plan, key)
        elif isinstance(v, dict):
            if k not in cur:
                cur[k] = {}
            if not isinstance(cur[k], dict):
                plan.notes.append(f"{key} は mapping ではないためスキップ")
                continue
            merge_into(cur[k], v, plan, key)  # cur[k] を再取得 (tomlkit は代入時にコピーするため)
        elif isinstance(v, list):
            if k not in cur:
                cur[k] = []
            if not isinstance(cur[k], list):
                plan.notes.append(f"{key} は list ではないためスキップ")
                continue
            for item in v:
                if contains(cur[k], item):
                    plan.skipped.append(f"{key}: {item}")
                else:
                    cur[k].append(copy.deepcopy(item))
                    plan.added.append(f"{key}: {item}")
        elif k not in cur:
            cur[k] = v
            plan.added.append(f"{key} = {v!r}")
        elif cur[k] == v:
            plan.skipped.append(f"{key} = {v!r}")
        else:
            plan.notes.append(f"競合のためスキップ: {key} = {v!r} (既存: {cur[k]!r})")


def merge_hooks(cur, k, groups, plan: Plan, key: str) -> None:
    """hooks: {Event: [{matcher?, hooks: [{type, command}]}]} を matcher + command 単位でマージ。"""
    if not isinstance(groups, dict):
        sys.exit(f"error: {key} は mapping (イベント名 → list) にしてください")
    if k not in cur:
        cur[k] = {}
    events = cur[k]
    for event, want_groups in groups.items():
        if event not in events:
            events[event] = []
        lst = events[event]
        for g in want_groups or []:
            label = f"{key}.{event}" + (f"[{g['matcher']}]" if g.get("matcher") else "")
            match = next((x for x in lst if x.get("matcher") == g.get("matcher")), None)
            if match is None:
                lst.append(copy.deepcopy(g))
                for h in g.get("hooks", []):
                    plan.added.append(f"{label}: {h.get('command', h)}")
                continue
            if "hooks" not in match:
                match["hooks"] = []
            for h in g.get("hooks", []):
                if any(same_hook(h, x) for x in match["hooks"]):
                    plan.skipped.append(f"{label}: {h.get('command', h)}")
                else:
                    match["hooks"].append(copy.deepcopy(h))
                    plan.added.append(f"{label}: {h.get('command', h)}")


def merge_permissions(cur, k, perms, plan: Plan, key: str) -> None:
    """permissions.{allow,ask,deny} は decision 間の競合もスキップ。他のキーは通常マージ。"""
    if k not in cur:
        cur[k] = {}
    cp = cur[k]
    rest = {}
    for name, rules in perms.items():
        if name not in DECISIONS:
            rest[name] = rules
            continue
        if name not in cp:
            cp[name] = []
        for rule in rules or []:
            other = next((d for d in DECISIONS if d != name and contains(cp.get(d, []), rule)), None)
            if contains(cp[name], rule):
                plan.skipped.append(f"{key}.{name}: {rule}")
            elif other:
                plan.notes.append(f"競合のためスキップ: {key}.{name}: {rule} (既に {other} にある)")
            else:
                cp[name].append(rule)
                plan.added.append(f"{key}.{name}: {rule}")
    if rest:
        merge_into(cp, rest, plan, key)


HANDLERS = {"hooks": merge_hooks, "permissions": merge_permissions,
            "claude.hooks": merge_hooks, "claude.permissions": merge_permissions,
            "codex.hooks": merge_hooks}


def read_json(path: Path) -> dict:
    if not path.exists() or not path.read_text().strip():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        sys.exit(f"error: {path} が不正な JSON です ({e})")
    if not isinstance(data, dict):
        sys.exit(f"error: {path} の最上位が object ではありません")
    return data


def dump_json(data: dict) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


# ---------- Claude ----------
def claude_view(want: dict) -> dict:
    """Claude に適用する内容: 共通部分 (codex / claude 以外) に claude: の中身を重ねたもの。"""
    out: dict = {}
    tmp = Plan("claude", Path())
    merge_into(out, {k: v for k, v in want.items() if k not in ("codex", "claude")}, tmp)
    merge_into(out, copy.deepcopy(want.get("claude") or {}), tmp)
    return out


def plan_claude(path: Path, want: dict) -> Plan:
    plan = Plan("claude", path)
    data = read_json(path)
    merge_into(data, claude_view(want), plan)
    if plan.added:
        plan.new_text = dump_json(data)
    return plan


# ---------- Codex ----------
def codex_unsupported(want: dict) -> list[str]:
    out = []
    for k, v in want.items():
        if k in ("codex", "claude", "hooks"):
            continue
        if k == "sandbox":
            out += [f"sandbox.{s}" + (f".{t}" if isinstance(sv, dict) else "")
                    for s, sv in (v or {}).items() for t in (sv if isinstance(sv, dict) else [None])
                    if not (s == "filesystem" and t == "allowWrite")]
        elif k == "permissions":
            out += [f"permissions.{s}" for s in (v or {}) if s not in DECISIONS]
        else:
            out.append(k)
    return out


def plan_codex_config(path: Path, want: dict) -> Plan:
    plan = Plan("codex", path)
    cw = copy.deepcopy(want.get("codex") or {})
    cw.pop("hooks", None)  # codex.hooks は hooks.json 側 (plan_codex_hooks) で扱う
    roots = ((want.get("sandbox") or {}).get("filesystem") or {}).get("allowWrite") or []
    if roots:  # Codex は ~ を展開しないので絶対パスにする
        cw.setdefault("sandbox_workspace_write", {}).setdefault("writable_roots", []).extend(
            str(Path(r).expanduser()).rstrip("/") or "/" for r in roots)
    if not cw:
        return plan
    text = path.read_text() if path.exists() else ""
    try:
        doc = tomlkit.parse(text)
    except Exception as e:
        sys.exit(f"error: {path} が不正な TOML です ({e})")
    if roots:  # 新規作成時に複数行配列で書くため先に作っておく
        t = doc.setdefault("sandbox_workspace_write", tomlkit.table())
        if "writable_roots" not in t:
            arr = tomlkit.array()
            arr.multiline(True)
            t["writable_roots"] = arr
    merge_into(doc, cw, plan)
    if plan.added:
        plan.new_text = tomlkit.dumps(doc)
    return plan


def plan_codex_hooks(path: Path, want: dict) -> Plan | None:
    shared, only = want.get("hooks"), (want.get("codex") or {}).get("hooks")
    if not shared and not only:
        return None
    plan = Plan("codex", path)
    data = read_json(path)
    for h in (shared, only):  # 共通 hooks の後に codex 専用 hooks を重ねる
        if h:
            merge_into(data, {"hooks": h}, plan)
    if plan.added:
        plan.new_text = dump_json(data)
    return plan


RULE_RE = re.compile(r'prefix_rule\(\s*pattern\s*=\s*(\[.*?\])\s*,\s*decision\s*=\s*"(\w+)"', re.DOTALL)
BASH_RE = re.compile(r"^Bash\((.*)\)$")


def bash_tokens(rule: str) -> list[str] | None:
    """Claude の Bash(git status *) / Bash(git status:*) / Bash(git status) -> ["git","status"]。"""
    m = BASH_RE.match(rule.strip())
    if not m:
        return None
    body = re.sub(r"(:\*|\s\*)$", "", m.group(1).strip())
    if "*" in body or not body:
        return None
    return shlex.split(body)


def plan_codex_rules(path: Path, want: dict) -> Plan | None:
    perms = want.get("permissions") or {}
    if not any(perms.get(d) for d in DECISIONS):
        return None
    plan = Plan("codex", path)
    text = path.read_text() if path.exists() else ""
    existing = {}
    body = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
    for m in RULE_RE.finditer(body):
        try:
            existing[tuple(json.loads(m.group(1)))] = m.group(2)
        except (json.JSONDecodeError, TypeError):
            pass
    lines = []
    for d in DECISIONS:
        for rule in perms.get(d) or []:
            toks = bash_tokens(rule)
            if toks is None:
                plan.notes.append(f"Codex 未対応のため無視: permissions.{d}: {rule}")
                continue
            cd, key = CODEX_DECISION[d], tuple(toks)
            if key in existing:
                if existing[key] != cd:
                    plan.notes.append(f"競合のためスキップ: {' '.join(toks)} ({cd} だが既に {existing[key]})")
                else:
                    plan.skipped.append(f"{cd}: {' '.join(toks)}")
                continue
            existing[key] = cd
            lines.append(f'prefix_rule(pattern={json.dumps(toks, ensure_ascii=False)}, decision="{cd}")')
            plan.added.append(f"{cd}: {' '.join(toks)}")
    if lines:
        sep = "" if not text or text.endswith("\n") else "\n"
        plan.new_text = text + sep + "\n".join(lines) + "\n"
    return plan


def plans_codex(scope: str, ws: Path, want: dict) -> list[Plan]:
    root = {"user": Path.home(), "workspace": ws}[scope] / ".codex"
    plans = [plan_codex_config(root / "config.toml", want),
             plan_codex_hooks(root / "hooks.json", want),
             plan_codex_rules(root / "rules" / "default.rules", want)]
    plans = [p for p in plans if p is not None]
    un = codex_unsupported(want)
    if un and plans:
        plans[0].notes.append("Codex 未対応 (Claude のみ適用): " + ", ".join(un))
    return plans


def claude_path(scope: str, ws: Path) -> Path:
    return {
        "user": Path.home() / ".claude" / "settings.json",
        "workspace": ws / ".claude" / "settings.json",
        "local": ws / ".claude" / "settings.local.json",
    }[scope]


# ---------- 表示 / 実行 ----------
def show(plans: list[Plan]) -> None:
    for p in plans:
        print(f"[{p.target}] {p.path}  ({'変更あり' if p.new_text else '変更なし'})")
        for a in p.added:
            print(f"  + {a}")
        for s in p.skipped:
            print(f"  = SKIP (既存) {s}")
        for n in p.notes:
            print(f"  ! {n}")


def merge_presets(files: list[Path]) -> dict:
    """複数 YAML を 1 つにまとめる (重複・食い違いの検出に merge_into を再利用)。"""
    want: dict = {}
    for f in files:
        print(f"preset: {f}")
        tmp = Plan("preset", f)
        merge_into(want, load_preset(f), tmp)
        for n in tmp.notes:
            print(f"  ! {f.name}: {n}")
    return want


# ---------- 逆方向: 適用先にあって YAML に無いものを抽出 ----------
def extract_extra(cur, want, key: str = ""):
    """cur のうち want に含まれない部分を返す (無ければ None)。マージ規則は merge_into と対応させている。"""
    if key == "hooks":
        out = {}
        for event, groups in (cur or {}).items():
            wgroups = (want or {}).get(event) or []
            res = []
            for g in groups:
                wm = next((x for x in wgroups if x.get("matcher") == g.get("matcher")), None)
                hs = [h for h in g.get("hooks", [])
                      if wm is None or not any(same_hook(h, x) for x in wm.get("hooks", []))]
                if hs:
                    res.append({**{k: v for k, v in g.items() if k != "hooks"}, "hooks": hs})
            if res:
                out[event] = res
        return out or None
    if isinstance(cur, dict):
        out = {}
        for k, v in cur.items():
            sub = extract_extra(v, (want or {}).get(k) if isinstance(want, dict) else None,
                                f"{key}.{k}" if key else str(k))
            if sub is not None:
                out[k] = sub
        return out or None
    if isinstance(cur, list):
        w = want if isinstance(want, list) else []
        out: list = []
        for x in cur:
            if not contains(w, x) and not contains(out, x):  # 重複も除く
                out.append(x)
        return out or None
    return None if (isinstance(want, (str, int, float, bool)) and want == cur) else cur


def run_extract(scopes: list[str], ws: Path, want: dict) -> None:
    want = claude_view(want)
    for scope in scopes:
        path = claude_path(scope, ws)
        extra = extract_extra(read_json(path), want)
        print(f"# [claude] {path}")
        if extra:
            print(yaml.safe_dump(extra, allow_unicode=True, sort_keys=False, default_flow_style=False))
        else:
            print("# (YAML に無い設定はありません)\n")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("presets", nargs="*",
                    help="プリセット名 (settings/<name>.yaml) または YAML のパス。省略時は設定ディレクトリの全 YAML")
    ap.add_argument("-d", "--settings-dir", type=Path, default=DEFAULT_DIR,
                    help=f"プリセットのあるディレクトリ、または YAML ファイル (default: {DEFAULT_DIR})\n"
                         f"ディレクトリは最上位に `{MARKER}: true` のある YAML だけが対象。\n"
                         "ファイルを指定した場合はマーカー不要でそのファイルだけを適用する (common.yaml の自動追加も無効)")
    ap.add_argument("-w", "--workspace-dir", type=Path, default=Path.cwd(), help="対象プロジェクト (default: cwd)")
    ap.add_argument("-s", "--scope", choices=SCOPES, action="append",
                    help="workspace(.claude/settings.json) / local(settings.local.json, Claude のみ) / user。"
                         "複数指定可 (default: workspace)")
    ap.add_argument("-t", "--target", choices=(*TARGETS, "all"), default="all")
    ap.add_argument("--no-common", action="store_true", help="common.yaml を自動追加しない")
    ap.add_argument("-x", "--extract", action="store_true",
                    help="逆方向: 適用先 (Claude の settings.json) にあって YAML に無い設定を YAML 形式で表示する (書き込みなし)")
    ap.add_argument("-n", "--dry-run", action="store_true", help="表示のみで書き込まない")
    ap.add_argument("-y", "--yes", action="store_true", help="確認なしで書き込む")
    a = ap.parse_args()

    base = a.settings_dir.expanduser()
    if base.is_file():
        if a.presets:
            sys.exit("error: -d にファイルを指定した場合、プリセット名は指定できません")
        files = [base]
    elif a.presets:
        files = [find_preset(n, base) for n in a.presets]
        common = next((c for e in (".yaml", ".yml") if (c := base / f"common{e}").is_file()), None)
        if common and not a.no_common and common not in files:
            files.insert(0, common)
    else:
        files = collect_presets(base)
        if not files:
            sys.exit(f"error: {base} に `{MARKER}: true` のある YAML がありません")
    want = merge_presets(files)
    if not want:
        sys.exit("error: 追加する設定がありません")

    ws = a.workspace_dir.expanduser().resolve()
    if a.extract:
        if a.target == "codex":
            sys.exit("error: --extract は Claude のみ対応です")
        run_extract(list(dict.fromkeys(a.scope or ["workspace"])), ws, want)
        return
    targets = TARGETS if a.target == "all" else (a.target,)
    plans: list[Plan] = []
    for scope in dict.fromkeys(a.scope or ["workspace"]):
        for t in targets:
            if t == "claude":
                plans.append(plan_claude(claude_path(scope, ws), want))
            elif scope == "local":
                print("[codex] scope=local は未対応のためスキップ")
            else:
                plans += plans_codex(scope, ws, want)

    print()
    show(plans)
    todo = [p for p in plans if p.new_text is not None]
    if not todo:
        print("\n追加する設定はありません")
        return
    if a.dry_run:
        print("\n(dry-run) 書き込みは行いません")
        return
    if not a.yes:
        if not sys.stdin.isatty():
            sys.exit("\nerror: 非対話環境です。-y で書き込むか -n で確認だけにしてください")
        if input(f"\n上記 {len(todo)} ファイルへ書き込みますか? [y/N] ").strip().lower() not in ("y", "yes"):
            print("中止しました")
            return
    for p in todo:
        p.path.parent.mkdir(parents=True, exist_ok=True)
        p.path.write_text(p.new_text)
        print(f"wrote {p.path}")


if __name__ == "__main__":
    main()
