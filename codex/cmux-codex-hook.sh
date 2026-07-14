#!/bin/sh

emit_empty() {
  printf '{}\n'
}

resolve_cmux_cli() {
  cmux_cli="${CMUX_BUNDLED_CLI_PATH:-}"
  if [ -z "$cmux_cli" ] || [ ! -x "$cmux_cli" ]; then
    cmux_cli="$(command -v cmux 2>/dev/null || true)"
  fi
  printf '%s\n' "$cmux_cli"
}

run_cmux() {
  if [ -n "${CMUX_SOCKET_PATH:-}" ]; then
    "$cmux_cli" --socket "$CMUX_SOCKET_PATH" "$@"
  else
    "$cmux_cli" "$@"
  fi
}

if [ -z "${CMUX_SURFACE_ID:-}" ] || [ "${CMUX_CODEX_HOOKS_DISABLED:-}" = "1" ]; then
  emit_empty
  exit 0
fi

cmux_cli="$(resolve_cmux_cli)"
if [ -z "$cmux_cli" ]; then
  emit_empty
  exit 0
fi

case "${1:-}" in
  feed)
    case "${2:-}" in
      PermissionRequest|PreToolUse)
        run_cmux hooks feed --source codex --event "$2" || emit_empty
        ;;
      *)
        emit_empty
        ;;
    esac
    ;;
  codex)
    case "${2:-}" in
      session-start|stop|prompt-submit)
        run_cmux hooks codex "$2" || emit_empty
        ;;
      *)
        emit_empty
        ;;
    esac
    ;;
  *)
    emit_empty
    ;;
esac
