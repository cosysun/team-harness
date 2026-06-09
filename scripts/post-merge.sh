#!/usr/bin/env bash
# post-merge.sh — installed as .git/hooks/post-merge in business repos via symlink.
#
# When a business repo runs `git pull` (or any merge), this hook fires and
# pulls the central harness repo, ensuring the symlinked rules/skills/hooks
# are at the latest version. Per the article, this gives "中央仓改完, 业务仓
# 下次会话立即生效" without anyone running init again.
#
# Symlink resolution: this file lives at <harness>/scripts/post-merge.sh but
# is invoked through <biz>/.git/hooks/post-merge → so BASH_SOURCE[0] is the
# *symlink* path, not the resolved one. We must resolve through the symlink
# BEFORE computing HARNESS_ROOT, otherwise we end up at <biz>/.git/.
#
# Best-effort. Never fails the business repo's merge.

set -u

# Resolve the script's real path (following the symlink).
_resolve_self() {
  local src="${BASH_SOURCE[0]}"
  if   command -v greadlink >/dev/null 2>&1; then greadlink -f "$src"
  elif readlink -f / >/dev/null 2>&1;          then readlink -f  "$src"
  elif command -v perl     >/dev/null 2>&1;   then perl -MCwd=abs_path -e 'print abs_path(shift)' "$src"
  elif command -v python3  >/dev/null 2>&1;   then python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$src"
  else
    # Manual symlink walk (BSD readlink without -f).
    local target="$src"
    while [[ -L "$target" ]]; do
      local link
      link="$(readlink "$target")"
      case "$link" in
        /*) target="$link" ;;
        *)  target="$(dirname "$target")/$link" ;;
      esac
    done
    (cd "$(dirname "$target")" && printf '%s/%s\n' "$(pwd)" "$(basename "$target")")
  fi
}

SELF="$(_resolve_self)"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sanity check.
if [[ ! -d "$HARNESS_ROOT/rules" ]]; then
  # Resolution failed — report once on stderr (visible during `git pull`) and bail.
  echo "[post-merge] cannot locate central harness root from $SELF; skipping auto-pull" >&2
  exit 0
fi

# Don't recurse: if we're being called by the harness pulling itself, bail.
if [[ "${HARNESS_POST_MERGE_RUNNING:-0}" == "1" ]]; then
  exit 0
fi
export HARNESS_POST_MERGE_RUNNING=1

# Pull only if we have a clean working tree on the central repo.
if git -C "$HARNESS_ROOT" status --porcelain 2>/dev/null | grep -q .; then
  echo "[post-merge] central harness has local changes; skipping ff-only pull" >&2
  exit 0
fi

git -C "$HARNESS_ROOT" fetch --quiet 2>/dev/null || true
if ! git -C "$HARNESS_ROOT" pull --ff-only --quiet 2>/dev/null; then
  echo "[post-merge] central harness ff-only pull failed; staying on current commit" >&2
fi

exit 0
