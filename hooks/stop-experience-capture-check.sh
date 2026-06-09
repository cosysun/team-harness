#!/usr/bin/env bash
# stop-experience-capture-check.sh — Claude Code Stop-hook gate.
#
# Wired via .claude/settings.json (hooks.Stop). Reads Claude Code's Stop-hook
# JSON payload from stdin. Inspects the conversation transcript JSONL for the
# canonical "EC-SCAN executed: N findings" marker.
#
# Why JSONL parsing (not raw grep): the transcript file is one JSON object per
# line, with assistant text living inside escaped string fields. A naïve
# `grep "EC-SCAN executed"` against the raw file may miss matches when the
# marker is split across newlines, contains special characters that JSON
# escaped differently, or is part of a thinking block. We use jq to extract
# every assistant message text and search it as plain decoded text.
#
# If the turn touched code (any Edit/Write/MultiEdit/Bash invocation) but the
# marker is missing, exit 2 to block the turn ending and surface the
# seven-perspective checklist to the assistant.

set -u
log() { printf '[stop-ec-check] %s\n' "$*" >&2; }

PAYLOAD="$(cat 2>/dev/null || true)"
if [[ -z "$PAYLOAD" ]]; then
  exit 0
fi

# Extract transcript_path. jq preferred; fall back to grep.
TRANSCRIPT_PATH=""
if command -v jq >/dev/null 2>&1; then
  TRANSCRIPT_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
fi
if [[ -z "$TRANSCRIPT_PATH" ]]; then
  TRANSCRIPT_PATH="$(printf '%s' "$PAYLOAD" \
                     | grep -oE '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
                     | head -1 \
                     | sed -E 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
fi

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  log "no transcript path; skipping"
  exit 0
fi

# Did this turn touch code? jq is the right tool — examine the structured
# `type` and `message.role`/`tool_use_id`/`name` fields rather than greping
# tool names, which can falsely match if a user writes "Edit" in a message.
TOUCHED_CODE="no"
if command -v jq >/dev/null 2>&1; then
  if jq -r '
      select(.type=="assistant")
      | .message.content // []
      | .[]?
      | select(.type=="tool_use")
      | .name
    ' "$TRANSCRIPT_PATH" 2>/dev/null \
      | grep -qE '^(Edit|Write|MultiEdit|Bash|NotebookEdit)$'; then
    TOUCHED_CODE="yes"
  fi
else
  # No jq: best-effort raw scan.
  if grep -qE '"type"[[:space:]]*:[[:space:]]*"tool_use".*"name"[[:space:]]*:[[:space:]]*"(Edit|Write|MultiEdit|Bash|NotebookEdit)"' "$TRANSCRIPT_PATH"; then
    TOUCHED_CODE="yes"
  fi
fi

if [[ "$TOUCHED_CODE" != "yes" ]]; then
  log "no code-touching tools in turn; skipping EC-SCAN check"
  exit 0
fi

# Look for the canonical marker. We extract every assistant text block and
# scan the *decoded* string, which sidesteps JSON escaping entirely.
MARKER_FOUND="no"
if command -v jq >/dev/null 2>&1; then
  if jq -r '
      select(.type=="assistant")
      | .message.content // []
      | .[]?
      | (.text // .input.text // empty)
    ' "$TRANSCRIPT_PATH" 2>/dev/null \
      | grep -qE 'EC-SCAN executed: [0-9]+ findings'; then
    MARKER_FOUND="yes"
  fi
fi
# Fallback: even after JSON escaping, the literal substring usually survives
# because the phrase is plain ASCII. Use this as a second chance.
if [[ "$MARKER_FOUND" != "yes" ]]; then
  if grep -qE 'EC-SCAN executed: [0-9]+ findings' "$TRANSCRIPT_PATH"; then
    MARKER_FOUND="yes"
  fi
fi

if [[ "$MARKER_FOUND" == "yes" ]]; then
  log "EC-SCAN marker found; ok"
  exit 0
fi

# Block the turn end and instruct the assistant to run /ec-scan.
cat >&2 <<'MSG'
BLOCKED: this turn touched code but did not run /ec-scan.

Run the seven-perspective experience-capture audit before ending the turn:

  1. correction      — Did the user correct me?
  2. knowledge       — Did I learn a project fact not in knowledge/?
  3. repetition      — Have I done this before?
  4. pitfall         — What broke or almost broke?
  5. field-mapping   — Where does a value come from / go to?
  6. code-pattern    — What would I flag in code review?
  7. process         — What end-to-end flow did I touch?

Append findings to <business-repo>/experiences.jsonl per the
experience-capture skill schema, then emit the marker as a single line:

  EC-SCAN executed: N findings

Zero findings is valid; you must still emit the marker.
MSG
exit 2
