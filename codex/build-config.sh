#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_CONFIG="$SCRIPT_DIR/config.common.toml"
LOCAL_CONFIG="$SCRIPT_DIR/config.local.toml"
OUTPUT_CONFIG="${HOME}/.codex/config.toml"

mkdir -p "$(dirname "$OUTPUT_CONFIG")"

if [ -L "$OUTPUT_CONFIG" ]; then
  rm "$OUTPUT_CONFIG"
fi

python3 - "$COMMON_CONFIG" "$LOCAL_CONFIG" "$OUTPUT_CONFIG" <<'PY'
import pathlib
import sys
import tomllib


def merge(base, override):
    if isinstance(base, dict) and isinstance(override, dict):
        merged = dict(base)
        for key, value in override.items():
            if key in merged:
                merged[key] = merge(merged[key], value)
            else:
                merged[key] = value
        return merged
    return override


def format_key(key):
    safe_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    if key and all(char in safe_chars for char in key):
        return key
    escaped = key.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def format_string(value):
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def format_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return format_string(value)
    if isinstance(value, list):
        return "[" + ", ".join(format_value(item) for item in value) + "]"
    raise TypeError(f"Unsupported TOML value type: {type(value)!r}")


def emit_table(lines, path, table):
    scalars = []
    nested = []
    for key, value in table.items():
        if isinstance(value, dict):
            nested.append((key, value))
        else:
            scalars.append((key, value))

    if path and scalars:
        if lines:
            lines.append("")
        lines.append("[" + ".".join(format_key(part) for part in path) + "]")

    for key, value in scalars:
        lines.append(f"{format_key(key)} = {format_value(value)}")

    for key, value in nested:
        emit_table(lines, path + [key], value)


common_path = pathlib.Path(sys.argv[1])
local_path = pathlib.Path(sys.argv[2])
output_path = pathlib.Path(sys.argv[3])

with common_path.open("rb") as f:
    config = tomllib.load(f)

if local_path.exists():
    with local_path.open("rb") as f:
        config = merge(config, tomllib.load(f))

lines = []
emit_table(lines, [], config)
output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
