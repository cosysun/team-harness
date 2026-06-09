#!/usr/bin/env bash
# dispatch-pre-commit.sh — Claude Code PreToolUse dispatcher for git commit.
#
# Wired via .claude/settings.json with matcher "Bash". Reads Claude Code's
# hook payload (JSON) on stdin, extracts tool_input.command, and invokes
# pre-commit-guard.sh ONLY when the command is a `git commit ...` invocation.
#
# Why a dispatcher: Claude Code does NOT set $CLAUDE_TOOL_INPUT — payload is
# delivered via stdin. The earlier inline grep on the env var silently no-op'd
# every commit. This script does the parse correctly.
#
# Exit codes follow Claude Code's hook protocol:
#   0  → allow the tool call
#   2  → block; stderr is shown to the assistant
#
# pre-commit-guard.sh's exit code is propagated unchanged when it runs.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read stdin once; tolerate empty (script still works when piped /dev/null).
PAYLOAD="$(cat 2>/dev/null || true)"
[[ -z "$PAYLOAD" ]] && exit 0

# Extract the Bash command. Try jq first (richer error tolerance), fall back
# to a small grep if jq is absent.
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
fi
if [[ -z "$CMD" ]]; then
  CMD="$(printf '%s' "$PAYLOAD" \
         | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
         | head -1 \
         | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
fi

# Only fire on `git commit ...`. Tolerate leading whitespace, env prefixes
# (`GIT_AUTHOR_NAME=foo git commit`), and `git -C path commit`.
if ! printf '%s' "$CMD" | grep -qE '(^|[[:space:]]|;|&&|\|\|)git([[:space:]]+-[A-Za-z]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Hand off. The guard reads the same staged state and decides per-gate.
exec bash "$SCRIPT_DIR/pre-commit-guard.sh"
