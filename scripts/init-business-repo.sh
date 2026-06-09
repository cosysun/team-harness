#!/usr/bin/env bash
# init-business-repo.sh — onboard a business repo onto the central harness.
#
# Mirrors the article's 一键接入脚本. Six steps, idempotent, zero-copy.
#
#   Mode A (run from central repo): batch onboard every path in business-repos.conf.
#       cd /path/to/team-harness
#       bash scripts/init-business-repo.sh
#
#   Mode B (run from inside a business repo): onboard just this one.
#       cd /path/to/business-repo
#       bash /path/to/team-harness/scripts/init-business-repo.sh
#
# Steps (each is guard-then-act so re-running is safe):
#   1. self-update central repo (git fetch + ff-only pull)
#   2. .mcp.json fallback (copy if missing — only step that copies anything)
#   3. five .claude/* directory symlinks (rules, skills, hooks, commands, knowledge)
#   4. jq-merge hooks/settings.fragment.json into .claude/settings.json
#   5. .git/hooks/post-merge symlink → scripts/post-merge.sh
#   6. CLAUDE.md symlink → contexts/<repo-slug>/CLAUDE.md (rendered from template if missing)
#
# Final step prints a verification table; non-zero exit if any leg failed.

set -euo pipefail

# --- locate harness root and detect mode --------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -d "$HARNESS_ROOT/rules" || ! -d "$HARNESS_ROOT/hooks" ]]; then
  echo "[init] FATAL: $HARNESS_ROOT does not look like the team-harness root" >&2
  exit 1
fi

# Resolve a portable real-path. macOS BSD readlink lacks -f; fall back to perl/python.
realpath_portable() {
  if command -v greadlink >/dev/null 2>&1; then greadlink -f "$1"
  elif readlink -f / >/dev/null 2>&1;     then readlink -f "$1"
  elif command -v perl >/dev/null 2>&1;   then perl -MCwd=abs_path -e 'print abs_path(shift)' "$1"
  elif command -v python3 >/dev/null 2>&1;then python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1"
  else
    # Fallback: cd into the dir and append the basename. Works for files and dirs that exist.
    local d b
    d="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || d="$(dirname "$1")"
    b="$(basename "$1")"
    printf '%s/%s\n' "$d" "$b"
  fi
}

log() { printf '[init] %s\n' "$*"; }
warn(){ printf '[init][warn] %s\n' "$*" >&2; }
die() { printf '[init][FATAL] %s\n' "$*" >&2; exit 1; }

CWD="$(pwd)"
BATCH_CONF="$HARNESS_ROOT/business-repos.conf"

is_business_repo() {
  [[ -d "$1/.git" ]] || return 1
  # Don't onboard the central repo onto itself
  [[ "$(realpath_portable "$1")" != "$(realpath_portable "$HARNESS_ROOT")" ]] || return 1
}

# --- step 1: self-update central repo -----------------------------------
step1_self_update() {
  log "step 1/6: self-update central harness repo"
  if ! git -C "$HARNESS_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    warn "central repo is not a git checkout; skipping self-update"
    return 0
  fi
  # fetch is best-effort; merge must be ff-only to be safe.
  git -C "$HARNESS_ROOT" fetch --quiet 2>/dev/null || warn "fetch failed (offline?); continuing"
  if git -C "$HARNESS_ROOT" status --porcelain | grep -q .; then
    warn "central repo has local changes; skipping pull"
  else
    if ! git -C "$HARNESS_ROOT" pull --ff-only --quiet 2>/dev/null; then
      warn "ff-only pull failed; staying on current commit"
    fi
  fi
}

# --- step 2: .mcp.json fallback -----------------------------------------
step2_mcp_template() {
  local repo="$1"
  log "step 2/6: .mcp.json fallback in $repo"
  if [[ -f "$repo/.mcp.json" ]]; then
    log "  exists; leaving alone"
    return 0
  fi
  if [[ ! -f "$HARNESS_ROOT/templates/.mcp.json.template" ]]; then
    warn "  template missing; skipping"
    return 0
  fi
  cp "$HARNESS_ROOT/templates/.mcp.json.template" "$repo/.mcp.json"
  log "  copied .mcp.json (edit token placeholders before use)"
}

# --- step 3: five .claude/* directory symlinks --------------------------
step3_claude_symlinks() {
  local repo="$1"
  log "step 3/6: .claude/* directory symlinks in $repo"
  mkdir -p "$repo/.claude"
  local entries=("rules:rules" "skills:skills" "hooks:hooks" "commands:commands" "knowledge:knowledge")
  for entry in "${entries[@]}"; do
    local link="${entry%:*}" target="${entry#*:}"
    local link_path="$repo/.claude/$link"
    local target_path="$HARNESS_ROOT/$target"
    if [[ -L "$link_path" ]]; then
      local cur
      cur="$(realpath_portable "$link_path")"
      if [[ "$cur" == "$(realpath_portable "$target_path")" ]]; then
        log "  ✓ .claude/$link already symlinks to $target_path"
        continue
      fi
      warn "  .claude/$link symlinks to $cur, expected $target_path; replacing"
      rm "$link_path"
    elif [[ -e "$link_path" ]]; then
      die "  .claude/$link exists and is NOT a symlink. Refusing to overwrite. Move or delete it and re-run."
    fi
    ln -s "$target_path" "$link_path"
    log "  + .claude/$link -> $target_path"
  done
}

# --- step 4: jq-merge settings.fragment.json ----------------------------
step4_settings_merge() {
  local repo="$1"
  log "step 4/6: jq-merge settings.fragment.json into $repo/.claude/settings.json"
  local fragment="$HARNESS_ROOT/hooks/settings.fragment.json"
  local settings="$repo/.claude/settings.json"
  if ! command -v jq >/dev/null 2>&1; then
    die "  jq is required for settings.json merge. Install with: brew install jq (macOS) or apt-get install jq (Linux)."
  fi
  mkdir -p "$repo/.claude"

  # Substitute $HARNESS_ROOT into the fragment first (Claude Code does NOT
  # expand env vars in hook commands). After substitution, validate the result
  # parses as JSON before going anywhere near the user's settings file.
  local resolved_fragment
  resolved_fragment="$(mktemp)"
  HARNESS_ROOT="$HARNESS_ROOT" envsubst '${HARNESS_ROOT}' < "$fragment" > "$resolved_fragment" 2>/dev/null \
    || sed "s|\${HARNESS_ROOT}|$HARNESS_ROOT|g" "$fragment" > "$resolved_fragment"
  if ! jq -e . "$resolved_fragment" >/dev/null 2>&1; then
    rm -f "$resolved_fragment"
    die "  resolved fragment is not valid JSON; refusing to merge.
       Check that \$HARNESS_ROOT ($HARNESS_ROOT) does not contain unescaped quotes."
  fi

  # Merge strategy:
  #   1. Deep-merge objects with fragment-wins on conflict (jq `*`).
  #   2. For each hooks.<event>, instead of letting the fragment replace the
  #      whole array, partition the existing array into "harness-owned" (the
  #      command references $HARNESS_ROOT) and "user-owned" (everything else).
  #      Drop the harness-owned entries (we re-supply them from the fragment),
  #      keep the user-owned ones, then concatenate fragment entries.
  #   3. Drop any top-level `_comment` keys from BOTH inputs so comments don't
  #      pollute the user's settings file.
  #
  # This is idempotent: re-running with an unchanged fragment produces the
  # same hooks.<event> arrays, and user-managed hooks are never deleted.
  if [[ -f "$settings" ]]; then
    local merged
    merged="$(jq -s --arg root "$HARNESS_ROOT" '
      def is_harness_owned($r): . as $entry
        | ((($entry.hooks // []) | map(.command // ""))
            + [($entry.command // "")])
          | any(. != "" and contains($r));

      def strip_comments: walk(if type=="object" then with_entries(select(.key != "_comment")) else . end);

      def merge_event($a; $b):
        ($a | map(select(is_harness_owned($root) | not))) + $b;

      (.[0] | strip_comments) as $a
      | (.[1] | strip_comments) as $b
      | $a * $b
      | (.hooks // {}) as $aha
      | ($a.hooks // {}) as $a_hooks
      | ($b.hooks // {}) as $b_hooks
      | .hooks = (
          ([$a_hooks, $b_hooks] | map(keys) | add | unique) as $events
          | reduce $events[] as $ev ({};
              .[$ev] = merge_event(($a_hooks[$ev] // []); ($b_hooks[$ev] // []))
            )
        )
    ' "$settings" "$resolved_fragment")"
    if [[ -z "$merged" ]]; then
      rm -f "$resolved_fragment"
      die "  jq merge produced empty output. Refusing to overwrite $settings."
    fi
    printf '%s\n' "$merged" > "$settings"
    log "  merged into existing $settings (preserved user-owned hooks)"
  else
    # Even on first install, strip _comment from the written output.
    jq 'walk(if type=="object" then with_entries(select(.key != "_comment")) else . end)' \
       "$resolved_fragment" > "$settings"
    log "  created $settings from fragment"
  fi
  rm -f "$resolved_fragment"
}

# --- step 5: .git/hooks/{post-merge,pre-commit} symlinks ----------------
# post-merge keeps the central harness in sync after `git pull`.
# pre-commit ensures the four GATEs run for terminal `git commit` too — not
# just commits made through Claude Code's Bash tool. Without it, the gates
# only fire when the assistant commits, which is a security gap.
step5_post_merge_hook() {
  local repo="$1"
  log "step 5/6: git hook symlinks in $repo (post-merge + pre-commit)"
  if [[ ! -d "$repo/.git/hooks" ]]; then
    warn "  $repo/.git/hooks missing; skipping (not a git repo?)"
    return 0
  fi

  _link_git_hook "$repo" "post-merge" "$HARNESS_ROOT/scripts/post-merge.sh"
  _link_git_hook "$repo" "pre-commit" "$HARNESS_ROOT/hooks/pre-commit-guard.sh"
}

_link_git_hook() {
  local repo="$1" name="$2" target="$3"
  local link="$repo/.git/hooks/$name"
  if [[ -L "$link" ]] && [[ "$(realpath_portable "$link")" == "$(realpath_portable "$target")" ]]; then
    log "  ✓ .git/hooks/$name already linked"
    return 0
  fi
  if [[ -e "$link" ]]; then
    warn "  $link exists; backing up to $link.bak"
    mv "$link" "$link.bak"
  fi
  ln -s "$target" "$link"
  log "  + .git/hooks/$name -> $target"
}

# --- step 6: CLAUDE.md per-repo context symlink -------------------------
detect_repo_slug() {
  local repo="$1" slug=""
  if [[ -f "$repo/package.json" ]] && command -v node >/dev/null 2>&1; then
    slug="$(node -e 'try{console.log(require(process.argv[1]).name||"")}catch{}' "$repo/package.json" 2>/dev/null || true)"
  fi
  if [[ -z "$slug" && -f "$repo/pyproject.toml" ]]; then
    slug="$(grep -E '^name\s*=' "$repo/pyproject.toml" | head -1 | sed -E 's/.*=\s*"([^"]+)".*/\1/')"
  fi
  if [[ -z "$slug" && -f "$repo/go.mod" ]]; then
    slug="$(awk '/^module / {print $2; exit}' "$repo/go.mod" | awk -F/ '{print $NF}')"
  fi
  if [[ -z "$slug" && -f "$repo/Cargo.toml" ]]; then
    slug="$(grep -E '^name\s*=' "$repo/Cargo.toml" | head -1 | sed -E 's/.*=\s*"([^"]+)".*/\1/')"
  fi
  if [[ -z "$slug" ]]; then
    slug="$(basename "$(realpath_portable "$repo")")"
  fi
  # Sanitize: lowercase, alphanumerics + dash + underscore only.
  slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
  printf '%s' "${slug:-unknown}"
}

step6_context_symlink() {
  local repo="$1"
  log "step 6/6: CLAUDE.md context symlink in $repo"
  local slug
  slug="$(detect_repo_slug "$repo")"
  local context_dir="$HARNESS_ROOT/contexts/$slug"
  local context_file="$context_dir/CLAUDE.md"
  local link_path="$repo/CLAUDE.md"

  if [[ ! -f "$context_file" ]]; then
    log "  rendering new context dir for slug '$slug'"
    mkdir -p "$context_dir"
    cp "$HARNESS_ROOT/contexts/_template/CLAUDE.md" "$context_file"
    # Light substitution: replace {{REPO_NAME}} and {{REPO_PATH}} placeholders.
    local repo_real
    repo_real="$(realpath_portable "$repo")"
    sed -i.bak \
      -e "s|{{REPO_NAME}}|$slug|g" \
      -e "s|{{REPO_PATH}}|$repo_real|g" \
      "$context_file"
    rm -f "$context_file.bak"
  fi

  if [[ -L "$link_path" ]] && [[ "$(realpath_portable "$link_path")" == "$(realpath_portable "$context_file")" ]]; then
    log "  ✓ CLAUDE.md already linked"
    return 0
  fi
  if [[ -e "$link_path" ]]; then
    warn "  CLAUDE.md exists in $repo; backing up to CLAUDE.md.bak"
    mv "$link_path" "$link_path.bak"
  fi
  ln -s "$context_file" "$link_path"
  log "  + CLAUDE.md -> $context_file"
}

# --- verification --------------------------------------------------------
verify_repo() {
  local repo="$1" failed=0
  echo
  log "verification — $repo"
  for d in rules skills hooks commands knowledge; do
    if [[ -L "$repo/.claude/$d" ]] && [[ -d "$repo/.claude/$d" ]]; then
      printf '  ✓ .claude/%-10s -> %s\n' "$d" "$(realpath_portable "$repo/.claude/$d")"
    else
      printf '  ✗ .claude/%-10s MISSING\n' "$d"; failed=1
    fi
  done
  if [[ -L "$repo/CLAUDE.md" ]] && [[ -f "$repo/CLAUDE.md" ]]; then
    printf '  ✓ CLAUDE.md       -> %s\n' "$(realpath_portable "$repo/CLAUDE.md")"
  else
    printf '  ✗ CLAUDE.md       MISSING\n'; failed=1
  fi
  if [[ -f "$repo/.claude/settings.json" ]] && jq -e '.hooks.PreToolUse' "$repo/.claude/settings.json" >/dev/null 2>&1; then
    printf '  ✓ .claude/settings.json has PreToolUse hooks\n'
  else
    printf '  ✗ .claude/settings.json MISSING or missing PreToolUse\n'; failed=1
  fi
  if [[ -L "$repo/.git/hooks/post-merge" ]]; then
    printf '  ✓ .git/hooks/post-merge -> %s\n' "$(realpath_portable "$repo/.git/hooks/post-merge")"
  else
    printf '  ✗ .git/hooks/post-merge MISSING\n'; failed=1
  fi
  if [[ -L "$repo/.git/hooks/pre-commit" ]]; then
    printf '  ✓ .git/hooks/pre-commit -> %s\n' "$(realpath_portable "$repo/.git/hooks/pre-commit")"
  else
    printf '  ✗ .git/hooks/pre-commit MISSING\n'; failed=1
  fi
  if [[ -f "$repo/.mcp.json" ]]; then
    printf '  ✓ .mcp.json present\n'
  else
    printf '  • .mcp.json absent (optional; template not present in central repo)\n'
  fi
  return $failed
}

# --- onboard one repo ---------------------------------------------------
onboard_one() {
  local repo
  repo="$(realpath_portable "$1")"
  if ! is_business_repo "$repo"; then
    warn "skipping $repo (not a git repo, or is the central harness itself)"
    return 0
  fi
  echo
  log "==================================================================="
  log "onboarding: $repo"
  log "==================================================================="
  step2_mcp_template "$repo"
  step3_claude_symlinks "$repo"
  step4_settings_merge "$repo"
  step5_post_merge_hook "$repo"
  step6_context_symlink "$repo"
  verify_repo "$repo"
}

# --- main ---------------------------------------------------------------
main() {
  step1_self_update

  # Mode detection:
  #   - If $CWD is the harness root and business-repos.conf exists, batch mode.
  #   - Otherwise, treat $CWD as the business repo (Mode B).
  if [[ "$(realpath_portable "$CWD")" == "$(realpath_portable "$HARNESS_ROOT")" ]]; then
    if [[ -f "$BATCH_CONF" ]]; then
      log "Mode A: batch onboard from $BATCH_CONF"
      local rc=0
      while IFS= read -r line; do
        line="${line%%#*}"        # strip comments
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        # Reject anything that looks like shell metacharacters — paths only.
        # No `eval`: a malicious or accidental conf entry like
        # "~/work/$(rm -rf /)/repo" would otherwise execute the substitution.
        case "$line" in
          *\$*|*\`*|*\;*|*\&*|*\|*|*\>*|*\<*)
            warn "skipping conf entry with shell metacharacter: $line"
            continue ;;
        esac
        # Safe tilde expansion: handle leading "~" and "~/" only.
        local expanded="$line"
        case "$expanded" in
          "~")    expanded="$HOME" ;;
          "~/"*)  expanded="$HOME/${expanded#~/}" ;;
        esac
        if ! onboard_one "$expanded"; then rc=1; fi
      done < "$BATCH_CONF"
      exit "$rc"
    else
      die "running from harness root but no $BATCH_CONF found.
       Either cd into a business repo and re-run (Mode B),
       or copy $HARNESS_ROOT/business-repos.conf.example -> business-repos.conf and list your repos."
    fi
  fi

  log "Mode B: single-repo onboard"
  onboard_one "$CWD"
}

main "$@"
