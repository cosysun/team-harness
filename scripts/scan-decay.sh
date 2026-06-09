#!/usr/bin/env bash
# scan-decay.sh — list decay candidates (manual quarterly maintenance).
#
# Per rules/global/decay.md, the harness does NOT run automatic decay. This
# script supports a maintainer who runs it once a quarter:
#
#   1. Archive candidates: files under rules/, skills/, knowledge/ whose last
#      commit is older than ARCHIVE_DAYS days (default 90), excluding files
#      whose frontmatter declares `permanent: true`.
#
#   2. Hard-delete candidates: files already under _archive/ whose last commit
#      is older than DELETE_DAYS days (default 180).
#
# Pure listing — never edits anything.
#
# Usage:
#   bash scripts/scan-decay.sh                # default thresholds
#   ARCHIVE_DAYS=120 DELETE_DAYS=365 bash scripts/scan-decay.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

ARCHIVE_DAYS="${ARCHIVE_DAYS:-90}"
DELETE_DAYS="${DELETE_DAYS:-180}"

# Compute "X days ago" as an epoch (portable BSD/GNU date).
_epoch_n_days_ago() {
  local n="$1"
  if date -v -1d +%s >/dev/null 2>&1; then
    # BSD date
    date -v "-${n}d" +%s
  else
    # GNU date
    date -d "${n} days ago" +%s
  fi
}

ARCHIVE_CUTOFF="$(_epoch_n_days_ago "$ARCHIVE_DAYS")"
DELETE_CUTOFF="$(_epoch_n_days_ago "$DELETE_DAYS")"

is_permanent() {
  local f="$1"
  # Look at the frontmatter only (first ~20 lines).
  head -20 "$f" 2>/dev/null | grep -qE '^permanent:[[:space:]]*true[[:space:]]*$'
}

last_commit_epoch() {
  local f="$1"
  # %ct = committer-date as epoch. Fall back to file mtime if not in git.
  local epoch
  epoch="$(git log -1 --format='%ct' -- "$f" 2>/dev/null)"
  if [[ -z "$epoch" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      epoch="$(stat -f '%m' "$f" 2>/dev/null)"
    else
      epoch="$(stat -c '%Y' "$f" 2>/dev/null)"
    fi
  fi
  printf '%s\n' "${epoch:-0}"
}

# ---------------------------------------------------------------------------
echo "Archive candidates (untouched > $ARCHIVE_DAYS days, not permanent):"
echo "----------------------------------------------------------------"

archive_count=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # Skip files already in _archive/
  case "$f" in *"/_archive/"*) continue ;; esac
  # Skip the decay rule itself — meta.
  case "$f" in "rules/global/decay.md") continue ;; esac
  if is_permanent "$f"; then continue; fi
  local_epoch="$(last_commit_epoch "$f")"
  if (( local_epoch < ARCHIVE_CUTOFF )); then
    age_days=$(( (ARCHIVE_CUTOFF - local_epoch) / 86400 + ARCHIVE_DAYS ))
    printf '  %s  (last touched ~%d days ago)\n' "$f" "$age_days"
    archive_count=$(( archive_count + 1 ))
  fi
done < <(find rules skills knowledge -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null | sort)

echo
echo "  Total: $archive_count"
echo
echo "To archive any of these, move with git:"
echo "  git mv <path> <parent>/_archive/<basename>"
echo "  git commit -m 'chore(decay): archive <path>'"
echo

# ---------------------------------------------------------------------------
echo "Hard-delete candidates (in _archive/, untouched > $DELETE_DAYS days):"
echo "------------------------------------------------------------------"

delete_count=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  local_epoch="$(last_commit_epoch "$f")"
  if (( local_epoch < DELETE_CUTOFF )); then
    age_days=$(( (DELETE_CUTOFF - local_epoch) / 86400 + DELETE_DAYS ))
    printf '  %s  (in archive ~%d days)\n' "$f" "$age_days"
    delete_count=$(( delete_count + 1 ))
  fi
done < <(find rules skills knowledge -type f -path '*/_archive/*' 2>/dev/null | sort)

echo
echo "  Total: $delete_count"
echo
echo "To delete any of these:"
echo "  git rm <path> && git commit -m 'chore(decay): delete <path>'"
