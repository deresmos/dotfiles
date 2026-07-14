#!/bin/bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: agent-with-worktree <codex|claude> <worktree-name> [-- agent-args...]

Options:
  -h, --help  Show this help.

Examples:
  agent-with-worktree codex feature/foo "Implement the requested change"
  agent-with-worktree claude feature/foo "Review this repository"
  agent-with-worktree codex feature/foo -- --model gpt-5 "Work on feature/foo"
EOF
  exit "${1:-1}"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

normalize_path() {
  local target=$1

  if [ -d "$target" ]; then
    (cd "$target" && pwd -P)
    return 0
  fi

  local target_dir
  target_dir=$(dirname "$target")
  local target_base
  target_base=$(basename "$target")
  mkdir -p "$target_dir"
  printf '%s/%s\n' "$(cd "$target_dir" && pwd -P)" "$target_base"
}

worktree_locked_for_name_or_path() {
  git worktree list --porcelain | awk -v target_path="$WORKTREE_PATH" -v target_branch="refs/heads/$WORKTREE_NAME" '
    BEGIN {
      worktree = ""
      branch = ""
      locked = 0
    }
    function flush_entry() {
      if (!found && (worktree == target_path || branch == target_branch) && locked == 1) {
        print worktree
        found = 1
      }
      worktree = ""
      branch = ""
      locked = 0
    }
    /^worktree / {
      flush_entry()
      worktree = substr($0, 10)
      next
    }
    /^branch / {
      branch = substr($0, 8)
      next
    }
    /^locked([[:space:]]|$)/ {
      locked = 1
      next
    }
    /^$/ {
      flush_entry()
      next
    }
    END {
      flush_entry()
      exit(found ? 0 : 1)
    }
  '
}

worktree_exists_for_name_or_path() {
  git worktree list --porcelain | awk -v target_path="$WORKTREE_PATH" -v target_branch="refs/heads/$WORKTREE_NAME" '
    BEGIN {
      worktree = ""
      branch = ""
      found = 0
    }
    function flush_entry() {
      if (!found && (worktree == target_path || branch == target_branch)) {
        found = 1
      }
      worktree = ""
      branch = ""
    }
    /^worktree / {
      flush_entry()
      worktree = substr($0, 10)
      next
    }
    /^branch / {
      branch = substr($0, 8)
      next
    }
    /^$/ {
      flush_entry()
      next
    }
    END {
      flush_entry()
      exit(found ? 0 : 1)
    }
  '
}

fetch_remote_if_available() {
  local remote=$1

  if [ -n "$remote" ] && git remote get-url "$remote" >/dev/null 2>&1; then
    git fetch --prune "$remote"
  fi

  return 0
}

update_ref_for_local_branch() {
  local remote
  local merge_ref
  local update_ref

  remote=$(git config "branch.$WORKTREE_NAME.remote" || true)
  merge_ref=$(git config "branch.$WORKTREE_NAME.merge" || true)
  if [ -n "$remote" ] && [ -n "$merge_ref" ]; then
    fetch_remote_if_available "$remote"
    update_ref="refs/remotes/$remote/${merge_ref#refs/heads/}"
    if git show-ref --verify --quiet "$update_ref"; then
      printf '%s\n' "$update_ref"
      return 0
    fi
  fi

  fetch_remote_if_available origin
  update_ref="refs/remotes/origin/$WORKTREE_NAME"
  if git show-ref --verify --quiet "$update_ref"; then
    printf '%s\n' "$update_ref"
    return 0
  fi

  return 0
}

fast_forward_worktree() {
  local update_ref=$1

  [ -n "$update_ref" ] || return 0
  (cd "$WORKTREE_PATH" && git merge --ff-only "$update_ref")
}

create_worktree() {
  mkdir -p "$WORKTREE_BASE"

  cd "$REPO_ROOT"

  local locked_path
  if locked_path=$(worktree_locked_for_name_or_path); then
    [ -d "$locked_path" ] || die "locked worktree for $WORKTREE_NAME does not exist at $locked_path"
    WORKTREE_PATH=$locked_path
    echo "INFO: using locked worktree at $WORKTREE_PATH" >&2
    return 0
  fi

  if worktree_exists_for_name_or_path >/dev/null; then
    die "worktree for $WORKTREE_NAME already exists at $WORKTREE_PATH"
  fi

  local update_ref=

  if git show-ref --verify --quiet "refs/heads/$WORKTREE_NAME"; then
    update_ref=$(update_ref_for_local_branch)
    git worktree add "$WORKTREE_PATH" "$WORKTREE_NAME" >/dev/null
    if ! fast_forward_worktree "$update_ref"; then
      git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
      rm -rf "$WORKTREE_PATH" 2>/dev/null || true
      die "failed to fast-forward $WORKTREE_NAME to $update_ref"
    fi
  elif git show-ref --verify --quiet "refs/remotes/origin/$WORKTREE_NAME"; then
    git worktree add "$WORKTREE_PATH" -b "$WORKTREE_NAME" --track "origin/$WORKTREE_NAME" >/dev/null
  else
    local base_ref=HEAD
    if git show-ref --verify --quiet "refs/remotes/origin/HEAD"; then
      base_ref=origin/HEAD
    fi
    git worktree add "$WORKTREE_PATH" -b "$WORKTREE_NAME" "$base_ref" >/dev/null
  fi

  git worktree lock "$WORKTREE_PATH" --reason "agent-with-worktree session" >/dev/null
}

remove_worktree() {
  cd "$REPO_ROOT"
  git worktree unlock "$WORKTREE_PATH" 2>/dev/null || true
  git worktree remove --force "$WORKTREE_PATH"
  rm -rf "$WORKTREE_PATH" 2>/dev/null || true
  git worktree prune
}

run_agent() {
  local agent=$1
  local worktree_path=$2
  shift 2

  case "$agent" in
    codex)
      codex -C "$worktree_path" "$@"
      ;;
    claude)
      (cd "$worktree_path" && claude "$@")
      ;;
    *)
      die "unsupported agent: $agent"
      ;;
  esac
}

if [ $# -gt 0 ]; then
  case "$1" in
    -h|--help)
      usage 0
      ;;
  esac
fi

[ $# -ge 2 ] || usage 1

AGENT=$1
shift
WORKTREE_NAME=$1
shift

case "$AGENT" in
  codex|claude)
    ;;
  *)
    die "unsupported agent: $AGENT (expected codex or claude)"
    ;;
esac

if [ $# -gt 0 ] && [ "$1" = "--" ]; then
  shift
fi

command -v "$AGENT" >/dev/null 2>&1 || die "$AGENT command not found in PATH"

git check-ref-format --branch "$WORKTREE_NAME" >/dev/null 2>&1 \
  || die "invalid worktree branch name: $WORKTREE_NAME"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$REPO_ROOT" ] || die "run this command inside a git repository"

REPO_ROOT=$(normalize_path "$REPO_ROOT")
WORKTREE_DIR_NAME=${WORKTREE_NAME//\//+}
WORKTREE_BASE="$REPO_ROOT/.agents/worktrees"
WORKTREE_PATH=$(normalize_path "$WORKTREE_BASE/$WORKTREE_DIR_NAME")

create_worktree

cleanup() {
  local command_status=$?

  if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "INFO: non-interactive session; worktree kept at $WORKTREE_PATH" >&2
    exit "$command_status"
  fi

  printf 'Delete worktree %s? [y/N] ' "$WORKTREE_PATH" >&2

  local reply
  if ! IFS= read -r reply; then
    echo >&2
    echo "INFO: worktree kept at $WORKTREE_PATH" >&2
    exit "$command_status"
  fi

  case "$reply" in
    y|Y|yes|YES)
      if ! remove_worktree; then
        echo "ERROR: failed to remove worktree at $WORKTREE_PATH" >&2
        exit 1
      fi
      ;;
    *)
      echo "INFO: worktree kept at $WORKTREE_PATH" >&2
      ;;
  esac

  exit "$command_status"
}

trap cleanup EXIT

run_agent "$AGENT" "$WORKTREE_PATH" "$@"
