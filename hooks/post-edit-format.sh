#!/usr/bin/env bash
# post-edit-format.sh — Claude Code PostToolUse gate (Edit|Write|MultiEdit).
#
# Best-effort auto-format on the file just edited. Never fails the hook
# (article: 不阻断,只补正). Reads Claude Code's hook payload from stdin and
# extracts the file path from tool_input.file_path.

set -u

PAYLOAD="$(cat 2>/dev/null || true)"
[[ -z "$PAYLOAD" ]] && exit 0

# Extract file_path. jq preferred; fall back to grep.
FILE=""
if command -v jq >/dev/null 2>&1; then
  FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
fi
if [[ -z "$FILE" ]]; then
  FILE="$(printf '%s' "$PAYLOAD" \
          | grep -oE '"(file_path|path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
          | head -1 \
          | sed -E 's/.*"(file_path|path)"[[:space:]]*:[[:space:]]*"([^"]*)".*/\2/')"
fi

# If we can't find a path, or the file no longer exists, exit 0 (best-effort).
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

# Map extension → formatter. Run if available; otherwise skip silently.
case "$FILE" in
  *.go)
    command -v gofmt   >/dev/null 2>&1 && gofmt -w "$FILE"   2>/dev/null || true
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$FILE" 2>/dev/null || true
    elif command -v black >/dev/null 2>&1; then
      black -q "$FILE" 2>/dev/null || true
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.yaml|*.yml|*.md)
    command -v prettier >/dev/null 2>&1 && prettier --write --log-level=warn "$FILE" 2>/dev/null || true
    ;;
  *.xml)
    if command -v xmllint >/dev/null 2>&1; then
      # Validate-then-replace: write formatted output to a tmp, validate it
      # parses, only then mv over the original. xmllint's `--format` can
      # produce partial output if the input has weird namespaces or includes,
      # so we never `mv` without a sanity check.
      tmp="$(mktemp)"
      if xmllint --format "$FILE" > "$tmp" 2>/dev/null \
         && [[ -s "$tmp" ]] \
         && xmllint --noout "$tmp" 2>/dev/null; then
        mv "$tmp" "$FILE"
      else
        rm -f "$tmp"
      fi
    fi
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt --quiet "$FILE" 2>/dev/null || true
    ;;
  *.java|*.kt)
    # Most teams use IDE-side formatting; no universal CLI default.
    :
    ;;
esac

# Always succeed.
exit 0
