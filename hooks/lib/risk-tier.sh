#!/usr/bin/env bash
# risk-tier.sh — classify the staged diff into one of: minimal | low | high | critical
#
# Source this script and call `risk_tier_classify` to print the tier to stdout.
# The classifier reads `git diff --name-only --cached` and bucketed file globs.
# Tiers come from the article's table:
#
#   minimal   docs / comments / javadoc only
#   low       config / resource files
#   high      service / mapper / utility logic
#   critical  Feign / SDK DTO / Kafka / SQL DDL / shared tables
#
# The caller decides which gates run per tier; this script just labels.

set -u

risk_tier_classify() {
  local files
  files="$(git diff --name-only --cached 2>/dev/null || true)"
  if [[ -z "$files" ]]; then
    # Fall back to working-tree diff if nothing staged (some tools call us pre-stage).
    files="$(git diff --name-only 2>/dev/null || true)"
  fi
  if [[ -z "$files" ]]; then
    echo "minimal"
    return 0
  fi

  local tier="minimal"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local file_tier
    file_tier="$(_risk_tier_for_file "$f")"
    tier="$(_risk_tier_max "$tier" "$file_tier")"
  done <<< "$files"

  echo "$tier"
}

_risk_tier_for_file() {
  local f="$1"

  # ----- per-repo overrides -------------------------------------------
  # If the business repo ships .harness/risk-tiers.conf, its rules are
  # checked FIRST and short-circuit the defaults. Format (one rule per line):
  #
  #     <glob> <tier>
  #
  # Globs use bash `case` semantics. Tier is one of minimal/low/high/critical.
  # Comments (`#`) and blank lines are ignored.
  #
  # Example:
  #     # Python team's critical surfaces
  #     */contracts/*.py        critical
  #     */api/v1_pb2.py         critical
  #     services/*/handlers/*   high
  #
  # The override file lives in the business repo (not the central harness),
  # so each project can name its own critical surfaces without forking the
  # central rules.
  local override_file=".harness/risk-tiers.conf"
  if [[ -f "$override_file" ]]; then
    local override_tier
    override_tier="$(_risk_tier_lookup_override "$f" "$override_file")"
    if [[ -n "$override_tier" ]]; then
      echo "$override_tier"
      return
    fi
  fi

  # ----- defaults (Java/Spring-flavored, but multi-language) ----------
  case "$f" in
    # critical — wire-format / schema / cross-repo surfaces
    *Feign*|*/feign/*) echo "critical"; return ;;
    */sdk/*|*/dto/*|*Dto.*|*DTO.*) echo "critical"; return ;;
    */kafka/*|*Topic*|*Producer*|*Consumer*) echo "critical"; return ;;
    *.sql|*/migrations/*|*Migration*|*/db/changelog/*) echo "critical"; return ;;
    */shared/*|*/contracts/*|*.proto|*.thrift|*.avsc) echo "critical"; return ;;

    # high — service / mapper / repository / utility logic
    *Service.java|*ServiceImpl.java|*Controller.java) echo "high"; return ;;
    *Mapper.java|*Mapper.xml|*Repository.java) echo "high"; return ;;
    *.go|*.py|*.ts|*.tsx|*.js|*.jsx|*.rs|*.kt|*.scala|*.rb|*.cs)
      # Source files default to high; tests included (a broken test is real).
      echo "high"; return ;;

    # low — config / resource files
    *.yaml|*.yml|*.toml|*.ini|*.cfg|*.conf|*.properties) echo "low"; return ;;
    *.json) echo "low"; return ;;
    Dockerfile|*.dockerfile|docker-compose*.yml) echo "low"; return ;;
    Makefile|*.mk|Rakefile|*.gradle|pom.xml|*.csproj) echo "low"; return ;;

    # minimal — docs / metadata / generated trash
    *.md|*.rst|*.txt|*.adoc) echo "minimal"; return ;;
    .gitignore|.gitattributes|LICENSE*|CHANGELOG*|README*) echo "minimal"; return ;;

    # default — treat unknowns as low (cautiously)
    *) echo "low"; return ;;
  esac
}

# Look up a per-file override in .harness/risk-tiers.conf. Prints the tier
# (one of minimal/low/high/critical) if any rule matches; empty otherwise.
# First match wins — file is read top-to-bottom.
_risk_tier_lookup_override() {
  local file="$1" conf="$2"
  local glob tier line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    # Split on whitespace into glob + tier.
    glob="${line%%[[:space:]]*}"
    tier="${line##*[[:space:]]}"
    [[ "$glob" == "$tier" ]] && continue   # malformed
    case "$tier" in
      minimal|low|high|critical) ;;
      *) continue ;;
    esac
    # shellcheck disable=SC2254
    case "$file" in
      $glob) printf '%s\n' "$tier"; return 0 ;;
    esac
  done < "$conf"
  return 0
}

# Print whichever of two tiers is more severe.
_risk_tier_max() {
  local a="$1" b="$2"
  local rank_a rank_b
  rank_a=$(_risk_tier_rank "$a")
  rank_b=$(_risk_tier_rank "$b")
  if (( rank_a >= rank_b )); then echo "$a"; else echo "$b"; fi
}

_risk_tier_rank() {
  case "$1" in
    minimal)  echo 0 ;;
    low)      echo 1 ;;
    high)     echo 2 ;;
    critical) echo 3 ;;
    *)        echo 0 ;;
  esac
}

# Allow running this directly for debugging: `bash risk-tier.sh`
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
  risk_tier_classify
fi
