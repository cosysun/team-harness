# Getting started

This walks through onboarding a business repo onto the central harness in three minutes.

## Prerequisites

- macOS or Linux
- `bash` 3.2+ (mac default works), `git`, `jq`
- A Claude Code installation in the business repo's environment

```bash
# macOS
brew install jq

# Debian / Ubuntu
sudo apt-get install jq
```

## 1. Clone the central harness

Pick a persistent location. Symlinks will point here, so don't put it in a temp dir or a directory you might delete.

```bash
git clone <central-harness-url> ~/work/team-harness
```

## 2. Onboard your first business repo

```bash
cd /path/to/your-business-repo
bash ~/work/team-harness/scripts/init-business-repo.sh
```

You should see output ending with a verification block like:

```
[init] verification — /path/to/your-business-repo
  ✓ .claude/rules      -> /Users/you/work/team-harness/rules
  ✓ .claude/skills     -> /Users/you/work/team-harness/skills
  ✓ .claude/hooks      -> /Users/you/work/team-harness/hooks
  ✓ .claude/commands   -> /Users/you/work/team-harness/commands
  ✓ .claude/knowledge  -> /Users/you/work/team-harness/knowledge
  • CLAUDE.md absent — write your own per-repo project self-portrait
  ✓ .claude/settings.json has PreToolUse hooks
  ✓ .git/hooks/post-merge -> /Users/you/work/team-harness/scripts/post-merge.sh
  ✓ .git/hooks/pre-commit -> /Users/you/work/team-harness/hooks/pre-commit-guard.sh
  • .mcp.json absent (optional)
```

The `•` markers are informational, not failures. CLAUDE.md is yours to write (next step). If any line shows ✗, the script also exits non-zero. Address the failure and re-run; the script is idempotent.

## 3. Write your `CLAUDE.md`

This file is the project's self-portrait. It loads into Claude's context every turn, so keep it short — three things only:

```markdown
# <repo-name>

## What this repo does
(one paragraph, plain language — what does this codebase do, in user terms?)

## Tech stack
(language, framework, runtime versions — not the dependency list)

## Surprising things to know
- (3–5 things that bite new contributors — file naming traps, timezone
   conventions, fields that look upstream-sourced but are actually back-filled)
```

Things you should **not** put here, because they live elsewhere:

- Coding standards / git workflow → `.claude/rules/global/`
- Field-level definitions, glossary → `.claude/knowledge/reference/`
- "Don't change X here" rules → `.claude/knowledge/constraints/`
- Hook descriptions → don't duplicate; the source is `.claude/hooks/` and `.claude/settings.json`

If you have richer per-project knowledge worth sharing across repos (system landscape, data-flow walkthroughs, glossary), put it in `.claude/knowledge/` (which symlinks to the central repo). Project-private knowledge that should *not* leak to other repos belongs inside the business repo itself, e.g. `docs/knowledge/`, and you reference it from `CLAUDE.md`.

Other per-repo edits:

- **`.mcp.json`** — your per-repo MCP server tokens. This stays in the business repo (it's the only file `init` *copies*).

## 4. Verify the gates work

Try to commit a fake source change without running `/ec-scan`:

```bash
cd /path/to/your-business-repo
echo 'console.log("test")' >> some-source-file.ts
git add some-source-file.ts
git commit -m "test: gate-1"
```

Expected: rejection with `GATE-1 (experience): source files changed but experiences.jsonl is not staged.`

To pass:

```bash
echo '{"ts":"2026-06-09T15:00:00Z","perspective":"correction","summary":"test","evidence":"smoke","files":["some-source-file.ts"],"promotion_candidate":null,"session_id":"smoke"}' >> experiences.jsonl
git add experiences.jsonl
git commit -m "test: gate-1"
```

If this passes (or fails on a later gate, which is also fine — that means GATE-1 worked), the harness is wired correctly.

## 5. Onboard the rest of your repos

Two ways:

- **Per-repo**: `cd <repo> && bash ~/work/team-harness/scripts/init-business-repo.sh` for each.
- **Batch**: edit `~/work/team-harness/business-repos.conf` (copy from `business-repos.conf.example`), list paths, then:

  ```bash
  cd ~/work/team-harness
  bash scripts/init-business-repo.sh
  ```

The batch mode runs the same six steps for every listed repo and stops at the first failure.

## 6. Daily usage

Day-to-day there's nothing to do. The post-merge hook auto-pulls the central repo every time you `git pull` your business repo. Symlinks always resolve to the latest central content. The hooks run automatically through Claude Code's settings binding.

When something is wrong:

- **A new rule isn't picking up** → `cd ~/work/team-harness && git pull --ff-only` manually, or run `bash scripts/init-business-repo.sh` from your business repo to re-verify links.
- **A gate is misfiring** → the gate scripts are in `.claude/hooks/` (symlinked to `<central>/hooks/`). Read them; they're 200-line bash files.
- **Settings drift** → re-run init; the jq merge is non-destructive, so existing user keys survive.

## What to do next

- Read [`docs/contributing.md`](contributing.md) when you want to add a rule, skill, or hook upstream.
- Read [`docs/architecture.md`](architecture.md) for the data-flow diagrams.
