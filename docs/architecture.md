# Architecture

`team-harness` is a **central content repo with a bash bootstrap**. There is no runtime, no service, no compiled CLI. Business repos consume it via filesystem symlinks. A single shell script (`scripts/init-business-repo.sh`) wires those symlinks and merges a hooks fragment into `.claude/settings.json`.

The design follows the article https://km.woa.com/articles/show/662361 — "central仓改完, 业务仓下次会话立即生效".

## Three-pillar / four-layer model

| Pillar (article) | Layer | Implementation |
|---|---|---|
| **Context (上下文)** | L1 看得懂 | `rules/`, `knowledge/`, `contexts/` |
| **Feedback (反馈)** | L2 学得会 | `skills/experience-capture/`, business repo `experiences.jsonl` |
| **Constraint (约束)** | L3 拦得住 | `hooks/{pre-commit-guard,stop-experience-capture-check,post-edit-format}.sh` + `hooks/settings.fragment.json` |
| **Constraint (约束)** | L4 验得了 | `commands/verify.md` + `hooks/pre-commit-guard.sh` GATE-3 / GATE-4 |

The two `Constraint` layers split into:

- **L3** is preventive — refuses to let bad commits start.
- **L4** is verifying — refuses to let claims of "done" stand without artifacts.

## Data flow at onboarding

```
central team-harness repo                    business repo
─────────────────────────                    ─────────────
                                             ./<source code>
rules/global/*.md        ← symlink ←        .claude/rules/
skills/experience-capture/← symlink ←        .claude/skills/
hooks/*.sh                ← symlink ←        .claude/hooks/
commands/*.md             ← symlink ←        .claude/commands/
knowledge/{r,d,c}/        ← symlink ←        .claude/knowledge/
contexts/<slug>/CLAUDE.md ← symlink ←        ./CLAUDE.md
hooks/settings.fragment.json    →    jq-merge   →    .claude/settings.json
templates/.mcp.json.template    →    cp-once    →    .mcp.json
scripts/post-merge.sh      ← symlink ←       .git/hooks/post-merge
                                             experiences.jsonl  ← created on first /ec-scan
```

After onboarding, business repos do **not** edit anything under `.claude/` (those are the symlinks). They only edit `experiences.jsonl` (their own ledger), `.mcp.json` (their own tokens), and their actual source.

## Data flow at runtime (an editing turn)

```
1. User opens a Claude Code session in a business repo.
2. Claude reads .claude/settings.json → reads hooks bindings.
3. User asks for a code change.
4. Claude reads (transitively, through symlinks):
       .claude/rules/global/must-not-do.md     (always-on)
       .claude/rules/global/must-do.md         (always-on)
       .claude/knowledge/constraints/...       (when about to edit X)
   ...and any per-stack rules under .claude/rules/stacks/.
5. Claude proposes a change.
6. PostToolUse hook fires on Edit/Write → post-edit-format.sh autoformats.
7. Claude attempts `git commit` via Bash tool.
8. PreToolUse hook fires (matcher = Bash, command starts with `git commit`) →
       pre-commit-guard.sh runs:
       GATE-1 experience capture        (was experiences.jsonl appended?)
       GATE-2 cross-repo tag            (Feign/SDK/Kafka/SQL touched? tagged?)
       GATE-3 compile                   (project-type-aware)
       GATE-4 fix-test                  (fix-type commit has new test?)
   exit 2 from any gate → Claude Code blocks the commit.
9. Claude attempts to end the turn.
10. Stop hook fires → stop-experience-capture-check.sh inspects transcript:
        if turn touched code AND no "EC-SCAN executed: N findings" marker,
        exit 2 to force the assistant to run /ec-scan first.
```

## Data flow when a rule changes upstream

```
Developer A pushes a new must-do.md entry to the central repo.
Developer B in business repo X runs `git pull` on X.
  → .git/hooks/post-merge fires (symlinked to central post-merge.sh)
  → central post-merge.sh runs `git -C $HARNESS_ROOT pull --ff-only`
  → central repo is now at A's new commit.
Developer B opens a new Claude Code session in X.
  → Claude reads .claude/rules/global/must-do.md
  → Through the symlink, this resolves to the central repo's now-updated file.
  → A's new rule is live, with no init re-run, no business-repo commit.
```

This is the article's 零拷贝 / 中央仓改完即生效 property.

## Idempotency

Every step in `init-business-repo.sh` is **guard-then-act**:

- A symlink that already points to the right target is left alone.
- A `.mcp.json` that exists is not overwritten.
- A pre-existing `.claude/settings.json` is jq-merged, never clobbered (existing keys preserved; arrays appended).
- A pre-existing `CLAUDE.md` is backed up to `CLAUDE.md.bak` before symlinking.

Re-running the script on a healthy repo does nothing visible. Re-running on a partially-initialized repo completes the missing legs.

## Risk-tier classifier

`hooks/lib/risk-tier.sh` classifies a staged diff into `minimal | low | high | critical` based on file globs (the article's 风险自适应 idea):

- `minimal` — docs, comments → GATE-3 and GATE-4 are skipped.
- `low` — config / resource → GATE-3 runs, GATE-4 may be skipped.
- `high` — service / mapper / repository / general source → GATE-3 + GATE-4 run.
- `critical` — Feign / SDK / Kafka / SQL / shared contracts → all gates + cross-repo tag explicitly required.

## Where there is *no* abstraction

There's deliberately no "feature catalog", no "stack registry", no manifest, no upgrade command. Every piece of the system is plain text or shell script, in a place where you'd expect it. Adding something means dropping a file in the right folder.
