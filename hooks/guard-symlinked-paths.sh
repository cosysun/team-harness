#!/usr/bin/env bash
# guard-symlinked-paths.sh — Claude Code PreToolUse gate (Edit|Write|MultiEdit).
#
# Enforces rules/global/must-not-do.md rule #11: do not edit files under the
# central-harness symlinks (.claude/{rules,hooks,knowledge,commands,skills}) or
# the per-repo CLAUDE.md (which is also a symlink to the central context).
#
# Without this gate, "rule #11" was purely aspirational — any assistant could
# silently mutate the central repo through the symlink. With it, the user has
# to remove the symlink (or edit the central repo directly) before such edits
# are possible.
#
# Reads Claude Code's payload from stdin, extracts tool_input.file_path. If the
# path resolves under one of the symlinked dirs, exit 2 with an explanatory
# message; otherwise exit 0 to allow.

set -u

PAYLOAD="$(cat 2>/dev/null || true)"
[[ -z "$PAYLOAD" ]] && exit 0

# Extract file_path. Different Edit-family tools use slightly different keys.
FILE=""
if command -v jq >/dev/null 2>&1; then
  FILE="$(printf '%s' "$PAYLOAD" \
         | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.notebook_path // empty' \
         2>/dev/null || true)"
fi
if [[ -z "$FILE" ]]; then
  FILE="$(printf '%s' "$PAYLOAD" \
         | grep -oE '"(file_path|path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
         | head -1 \
         | sed -E 's/.*"(file_path|path|notebook_path)"[[:space:]]*:[[:space:]]*"([^"]*)".*/\2/')"
fi

[[ -z "$FILE" ]] && exit 0

# Walk up the path looking for a symlink ancestor that resolves into the
# central harness repo. We treat the location of THIS script as the central
# repo (the script lives at <harness>/hooks/guard-symlinked-paths.sh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve a path while it still exists on disk (it does — Edit can be against
# files that exist or that don't yet, but the parent dir typically exists).
realpath_portable() {
  if   command -v greadlink >/dev/null 2>&1; then greadlink -f "$1" 2>/dev/null
  elif readlink -f / >/dev/null 2>&1;          then readlink -f  "$1" 2>/dev/null
  elif command -v perl     >/dev/null 2>&1;   then perl -MCwd=abs_path -e 'print abs_path(shift) // ""' "$1" 2>/dev/null
  elif command -v python3  >/dev/null 2>&1;   then python3 -c 'import os,sys
try: print(os.path.realpath(sys.argv[1]))
except: pass' "$1" 2>/dev/null
  else
    # Best-effort fallback: parent realpath + basename.
    local d b
    d="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || d="$(dirname "$1")"
    b="$(basename "$1")"
    printf '%s/%s\n' "$d" "$b"
  fi
}

# If $FILE doesn't exist (Edit on a new file), check its parent's resolution.
TARGET="$FILE"
if [[ ! -e "$TARGET" ]]; then
  TARGET="$(dirname "$FILE")"
fi

REAL="$(realpath_portable "$TARGET" 2>/dev/null || echo "$TARGET")"

# Block if the resolved path is under the central harness root.
if [[ -n "$REAL" && "$REAL" == "$HARNESS_ROOT"/* ]]; then
  cat >&2 <<MSG
BLOCKED: $FILE resolves to $REAL inside the central harness repo
($HARNESS_ROOT). Editing it through the symlink would silently apply to every
business repo using this harness.

If you need to edit a harness rule, hook, skill, or knowledge entry, do it in
the central repo directly:

    cd $HARNESS_ROOT
    \$EDITOR $REAL

If you need a per-business-repo override, place it OUTSIDE the symlinked
\`.claude/\` paths — e.g. in your repo's \`docs/\` or a project-local \`.harness/\`
directory.

Rule reference: rules/global/must-not-do.md rule #11.
MSG
  exit 2
fi

exit 0
