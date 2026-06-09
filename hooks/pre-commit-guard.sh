#!/usr/bin/env bash
# pre-commit-guard.sh — the L3+L4 commit gate.
#
# Wired into Claude Code via .claude/settings.json (PreToolUse on Bash:git commit*),
# and optionally as .git/hooks/pre-commit for non-Claude commits.
#
# Four gates, all reject with exit 2 (Claude Code's "block" code):
#   GATE-1   experience capture must have a new line this commit (经验闸)
#   GATE-2   cross-repo touches must tag [cross-repo-impact] (跨仓闸)
#   GATE-3   compile must pass (编译闸)
#   GATE-4   fix-type commits must add a regression test (测试闸)
#
# Risk-tier (minimal/low/high/critical) decides which gates run. See lib/risk-tier.sh.

set -u

# Resolve the script's real path (following symlinks) so that sibling lib/
# scripts can be sourced regardless of how this hook was invoked. Without this,
# .git/hooks/pre-commit (which is a symlink to this file) sees SCRIPT_DIR as
# <biz>/.git/hooks/, and `source lib/risk-tier.sh` fails.
_resolve_self() {
  local src="${BASH_SOURCE[0]}"
  if   command -v greadlink >/dev/null 2>&1; then greadlink -f "$src"
  elif readlink -f / >/dev/null 2>&1;          then readlink -f  "$src"
  elif command -v perl     >/dev/null 2>&1;   then perl -MCwd=abs_path -e 'print abs_path(shift)' "$src"
  elif command -v python3  >/dev/null 2>&1;   then python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$src"
  else
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

_SELF="$(_resolve_self)"
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
# shellcheck source=lib/risk-tier.sh
source "$SCRIPT_DIR/lib/risk-tier.sh"
# shellcheck source=lib/project-type.sh
source "$SCRIPT_DIR/lib/project-type.sh"

# ----- Helpers ------------------------------------------------------------
log()  { printf '[pre-commit-guard] %s\n' "$*" >&2; }
die()  { log "BLOCKED: $*"; exit 2; }
note() { log "$*"; }

# Read the staged file list once.
STAGED="$(git diff --name-only --cached 2>/dev/null || true)"
ALL_CHANGED="$(git diff --name-only HEAD 2>/dev/null || true)"

# Decide the tier.
TIER="$(risk_tier_classify)"
note "risk tier: $TIER"

# Read the commit subject if present (when invoked by .git/hooks/pre-commit
# the subject lives in COMMIT_EDITMSG; from Claude Code we don't see it).
COMMIT_MSG_FILE="${1:-${GIT_DIR:-.git}/COMMIT_EDITMSG}"
COMMIT_SUBJECT=""
COMMIT_BODY=""
if [[ -f "$COMMIT_MSG_FILE" ]]; then
  COMMIT_SUBJECT="$(sed -n '1p' "$COMMIT_MSG_FILE" 2>/dev/null || true)"
  COMMIT_BODY="$(cat "$COMMIT_MSG_FILE" 2>/dev/null || true)"
fi

# ----- GATE-1: experience capture ----------------------------------------
# If any source file is staged, experiences.jsonl must have at least one
# new line in this commit. We accept the ledger at any depth (monorepo with
# per-service ledgers like services/foo/experiences.jsonl is supported).
gate1_experience() {
  local has_source="no"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      *.go|*.py|*.ts|*.tsx|*.js|*.jsx|*.java|*.kt|*.rs|*.rb|*.cs|*.scala|*.swift|*.cpp|*.c|*.h|*.hpp)
        has_source="yes"; break ;;
    esac
  done <<< "$STAGED"
  if [[ "$has_source" != "yes" ]]; then
    note "GATE-1 skip: no source files staged"
    return 0
  fi

  # Find any staged path whose basename is experiences.jsonl.
  local ledger_paths
  ledger_paths="$(printf '%s\n' "$STAGED" | grep -E '(^|/)experiences\.jsonl$' || true)"
  if [[ -z "$ledger_paths" ]]; then
    die "GATE-1 (experience): source files changed but experiences.jsonl is not staged.
        Run /ec-scan (or invoke the experience-capture skill) and stage experiences.jsonl,
        then commit."
  fi

  # Confirm at least one staged ledger adds a new JSON line.
  local added="no"
  while IFS= read -r ledger; do
    [[ -z "$ledger" ]] && continue
    if git diff --cached -- "$ledger" 2>/dev/null | grep -E '^\+\{' >/dev/null 2>&1; then
      added="yes"
      break
    fi
  done <<< "$ledger_paths"
  if [[ "$added" != "yes" ]]; then
    die "GATE-1 (experience): experiences.jsonl is staged but adds no new JSON line.
        Append a finding (see skills/experience-capture/SKILL.md schema), stage, then commit."
  fi

  note "GATE-1 ok"
}

# ----- GATE-2: cross-repo impact -----------------------------------------
gate2_cross_repo() {
  local crossy="no"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      *Feign*|*/feign/*|*/sdk/*|*/dto/*|*Dto.*|*DTO.*|*/kafka/*|*Topic*|*/contracts/*|*/shared/*|*.proto|*.thrift|*.avsc|*.sql|*/migrations/*)
        crossy="yes"; break ;;
    esac
  done <<< "$STAGED"

  if [[ "$crossy" != "yes" ]]; then
    note "GATE-2 skip: no cross-repo surfaces touched"
    return 0
  fi

  if ! echo "$COMMIT_BODY" | grep -qF '[cross-repo-impact]'; then
    die "GATE-2 (cross-repo): wire-format / schema / shared surface touched, but the
        commit message does not include [cross-repo-impact].
        Add the tag to the commit body and list the affected consumers."
  fi
  note "GATE-2 ok"
}

# ----- GATE-3: compile ---------------------------------------------------
gate3_compile() {
  case "$TIER" in
    minimal)
      note "GATE-3 skip (tier=minimal)"
      return 0 ;;
  esac

  # Single source of truth for project-type → compile command.
  # Both /verify and GATE-3 read from hooks/lib/project-type.sh.
  local cmd=""
  cmd="$(project_compile_cmd)"

  if [[ -z "$cmd" ]]; then
    local detected_type
    detected_type="$(project_primary_type)"
    note "GATE-3 skip: no compile target detected (project type: ${detected_type:-unknown})"
    return 0
  fi

  # /tmp log path is per-pid to avoid two concurrent commits clobbering each other.
  local log_file="/tmp/precommit-compile.$$.log"
  note "GATE-3 running: $cmd"
  if ! eval "$cmd" >"$log_file" 2>&1; then
    log "compile output (first 40 lines):"
    sed -n '1,40p' "$log_file" >&2
    die "GATE-3 (compile): the project does not compile. See $log_file."
  fi
  rm -f "$log_file"
  note "GATE-3 ok"
}

# ----- GATE-4: regression test on fix-type commits -----------------------
gate4_test_on_failure() {
  case "$TIER" in
    minimal)
      note "GATE-4 skip (tier=minimal)"
      return 0 ;;
  esac

  # Determine commit type from subject; fall back to checking $COMMIT_BODY.
  local subject="${COMMIT_SUBJECT:-}"
  if [[ -z "$subject" ]]; then
    note "GATE-4 skip: no commit subject available"
    return 0
  fi
  case "$subject" in
    fix:*|fix\(*|bugfix:*|bugfix\(*|hotfix:*|hotfix\(*) ;;
    *)
      note "GATE-4 skip (commit type is not fix/bugfix/hotfix)"
      return 0 ;;
  esac

  # Look for a NEW test file in the staged diff (Added status).
  local new_tests
  new_tests="$(git diff --cached --name-status \
                | awk '$1=="A" {print $2}' \
                | grep -E '(_test\.(go|py)|test_.*\.py|\.test\.(t|j)sx?$|\.spec\.(t|j)sx?$|Test\.java$|Tests\.java$|Spec\.java$|_test\.rb$|_spec\.rb$)' \
                || true)"

  if [[ -z "$new_tests" ]]; then
    die "GATE-4 (test-on-failure): a fix-type commit must add at least one new
        regression test file. None found in the staged diff.
        See rules/global/test-on-failure.md for naming conventions."
  fi
  note "GATE-4 ok (new test: $(echo "$new_tests" | head -1))"
}

# ----- Run ---------------------------------------------------------------
gate1_experience
gate2_cross_repo
gate3_compile
gate4_test_on_failure
note "all gates passed (tier=$TIER)"
exit 0
