#!/usr/bin/env bash
# project-type.sh — single source of truth for "what kind of project is this"
# and "how do I compile / test / lint it". Used by:
#
#   - hooks/pre-commit-guard.sh GATE-3 (compile)
#   - commands/verify.md (read by the assistant; the assistant runs the same
#     commands manually)
#
# Source this file, then call:
#
#   project_compile_cmd     → prints the compile command, or empty
#   project_test_cmd        → prints the test command, or empty
#   project_lint_cmd        → prints the lint command, or empty
#   project_types           → prints space-separated detected types
#
# Order of detection matters when multiple markers exist. We pick the first
# match, but `project_types` returns ALL matches so callers can decide whether
# a polyglot repo needs multiple commands.

set -u

# Detect all applicable project types in deterministic order. Returns a
# newline-separated list of type tokens.
project_types() {
  local types=()
  [[ -f go.mod      || -f go.work ]] && types+=("go")
  [[ -f pom.xml ]]                   && types+=("maven")
  [[ -f build.gradle || -f build.gradle.kts ]] && types+=("gradle")
  [[ -f pyproject.toml || -f setup.py || -f requirements.txt ]] && types+=("python")
  if [[ -f package.json ]]; then
    if [[ -f tsconfig.json ]]; then types+=("typescript")
    else                            types+=("javascript")
    fi
  fi
  [[ -f Cargo.toml ]]                && types+=("rust")
  # `set -u` rejects "${types[@]}" on an empty array in older bash; the
  # `+` parameter expansion makes that case a no-op.
  printf '%s\n' "${types[@]+"${types[@]}"}"
}

# Pick the FIRST detected type (the "primary" one).
project_primary_type() {
  project_types | head -n 1
}

project_compile_cmd() {
  local t
  t="$(project_primary_type)"
  case "$t" in
    go)         echo "go build ./..." ;;
    maven)      echo "mvn -q -DskipTests compile" ;;
    gradle)     echo "./gradlew -q compileJava" ;;
    python)     echo "python3 -m compileall -q ." ;;
    typescript) echo "npx --no-install tsc --noEmit" ;;
    javascript) echo "" ;;  # JS has no compile step; keep empty by design
    rust)       echo "cargo build --quiet" ;;
    *)          echo "" ;;
  esac
}

project_test_cmd() {
  local t
  t="$(project_primary_type)"
  case "$t" in
    go)         echo "go test ./..." ;;
    maven)      echo "mvn -q test" ;;
    gradle)     echo "./gradlew -q test" ;;
    python)     echo "pytest -q" ;;
    typescript|javascript) echo "npm test --silent" ;;
    rust)       echo "cargo test --quiet" ;;
    *)          echo "" ;;
  esac
}

project_lint_cmd() {
  local t
  t="$(project_primary_type)"
  case "$t" in
    go)         echo "go vet ./..." ;;
    python)     echo "ruff check ." ;;
    typescript|javascript) echo "npx --no-install eslint ." ;;
    rust)       echo "cargo clippy --quiet" ;;
    *)          echo "" ;;
  esac
}

# Direct-invoke for debugging.
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
  echo "primary:  $(project_primary_type)"
  echo "compile:  $(project_compile_cmd)"
  echo "test:     $(project_test_cmd)"
  echo "lint:     $(project_lint_cmd)"
  echo "all:      $(project_types | tr '\n' ' ')"
fi
