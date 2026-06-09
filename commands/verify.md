# /verify

Treat this as a hard gate, not a suggestion. If any step below fails, the answer to "is this done?" is **no** — even if the change looks correct.

## What "done" means

A change is done when:

1. The project compiles cleanly.
2. The tests covering the changed files pass.
3. The linter is clean on the changed files.

Anything less is a hypothesis, not a result.

## Run order

Stop at the first failure and report it back to the user. Do not skip ahead.

### 1. Discover the project's compile / test / lint commands

The harness ships a single source of truth at `.claude/hooks/lib/project-type.sh` that GATE-3 in the pre-commit hook *also* reads from. Use it directly so this command and the gate never disagree:

```bash
source .claude/hooks/lib/project-type.sh
COMPILE_CMD="$(project_compile_cmd)"
TEST_CMD="$(project_test_cmd)"
LINT_CMD="$(project_lint_cmd)"
PRIMARY="$(project_primary_type)"
ALL_TYPES="$(project_types | tr '\n' ' ')"
echo "Project type: $PRIMARY  (all detected: $ALL_TYPES)"
```

The current detection ladder (in priority order):

```
go.mod | go.work          → go     → go build ./...        | go test ./...   | go vet ./...
pom.xml                   → maven  → mvn -q -DskipTests compile | mvn -q test | (none)
build.gradle{,.kts}       → gradle → ./gradlew -q compileJava   | ./gradlew -q test | (none)
pyproject.toml | setup.py | requirements.txt
                          → python → python3 -m compileall -q . | pytest -q   | ruff check .
package.json + tsconfig.json
                          → typescript → npx --no-install tsc --noEmit | npm test --silent | npx --no-install eslint .
package.json (no tsconfig)
                          → javascript → (no compile)               | npm test --silent | npx --no-install eslint .
Cargo.toml                → rust   → cargo build --quiet        | cargo test --quiet | cargo clippy --quiet
```

If `project_types` returns multiple values (polyglot repo), run the workflow once per type.

### 2. Run the commands

```bash
[ -n "$COMPILE_CMD" ] && eval "$COMPILE_CMD" || true   # skip if empty (e.g., plain JS)
eval "$TEST_CMD"
[ -n "$LINT_CMD"    ] && eval "$LINT_CMD"
```

### 3. Narrow tests to changed files when possible

Running the full suite is fine but slow. Prefer:

- Go: `go test ./<package-with-changes>/...`
- Pytest: `pytest -q <changed-test-file-or-dir>`
- npm: `npm test -- <changed-test-file>`

If you can't tell which tests cover the change, run the whole suite. Slow is fine; wrong is not.

### 4. Report

Tell the user, in this exact shape:

```
/verify result:
- compile: PASS|FAIL  (<seconds>s)
- tests:   PASS|FAIL  (<n> passed / <m> failed, <seconds>s)
- lint:    PASS|FAIL  (<warnings>)
```

If everything passes, say "Verified" — and only then.

## What this command refuses

- It refuses to skip steps because "the change is small".
- It refuses to declare success based on "looks right".
- It refuses to mark `fix:` commits done without a regression test (GATE-4 will reject the commit anyway; this just gets you there sooner).

## When `/verify` is too heavy

If the change is comment-only, doc-only, or pure config (no code path affected), say so and skip the test step. Compile and lint are still cheap; run them.

## Adding a new project type

Edit `hooks/lib/project-type.sh` in the central harness. Both this command and the GATE-3 pre-commit hook pick up the change automatically — there is exactly one place to update.
