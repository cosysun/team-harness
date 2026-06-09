# Claude Code — `art-server`

> Symlinked from the central `team-harness` repo. To edit this file, edit `contexts/art-server/CLAUDE.md` in the central repo, not here. Local edits will affect the central repo (the symlink resolves there) and will silently propagate to every business repo that shares this slug.

## I want to… → here's how

| I want to… | How to find it |
|---|---|
| **Check red lines before changing code** | Read `.claude/rules/global/must-not-do.md`. Every entry there has caused a real incident. |
| **Look up project knowledge** (terms / fields / flows) | Search `.claude/knowledge/`: `reference/` for terms and field maps, `domain/` for flows and stages, `constraints/` for "改代码前必须查". |
| **Check behavioral rules** (must-do / engineering / git) | Browse `.claude/rules/global/` and `.claude/rules/stacks/`. |
| **Trigger a capability workflow** | Type a slash command — `/verify`, `/ec-scan` — or invoke a skill from `.claude/skills/`. |
| **Capture what I learned this turn** | Run `/ec-scan` (the Stop-hook will require this anyway if you touched code). |
| **Check if my change is "done"** | Run `/verify`. "Done" is not a claim, it's compile + tests + lint passing. |
| **Find the answer when nothing above helps** | **Ask the user. Do not guess.** Inventing a field name or assumption is the single most common cause of silent breakage. |

## Project self-portrait

**Name:** `art-server`
**Path:** `/Users/andysun/work/python/art-server`

> Replace this section with a real project description: what this repo does in one paragraph, the top-level services it talks to, and 3-5 surprising things to know. See `.claude/knowledge/domain/system-landscape.template.md` for a starter.

### What this repo does

(one paragraph, plain language)

### Tech stack

(language, framework, runtime versions)

### Cross-service dependency matrix

| This repo | Calls | Listens to | Emits |
|---|---|---|---|
| `art-server` | (services) | (topics) | (topics) |

### Surprising things to know

- (the 3-5 things that bite new contributors)

## Workflow conventions

- **Before any change**: read the red lines (`must-not-do.md`) and check `knowledge/constraints/` for the area you're touching.
- **Cross-repo touches** (Feign / SDK / Kafka / shared SQL): tag the commit `[cross-repo-impact]` and list affected consumers in the body. GATE-2 enforces this.
- **Fix commits** (`fix:` / `bugfix:` / `hotfix:`): must add a regression test that fails without the fix. GATE-4 enforces this.
- **End of every code-touching turn**: run `/ec-scan`. The Stop-hook enforces this.
- **Before claiming done**: run `/verify`.

## Hooks that will reject your work (and why)

| Hook | Trigger | Why |
|---|---|---|
| GATE-1 | `git commit` after source edits, no `experiences.jsonl` line | Every code change must yield captured experience |
| GATE-2 | Wire-format / schema / shared-table touch without `[cross-repo-impact]` tag | Cross-repo changes must be visible in commit history |
| GATE-3 | Compile fails | Don't commit broken code, even temporarily |
| GATE-4 | `fix:`-type commit with no new test file | Regression tests are the only proof a fix sticks |
| Stop-hook | Turn ended without `EC-SCAN executed: N findings` marker | One-off corrections must compound into knowledge |

The hook source is at `.claude/hooks/`. The settings binding is `.claude/settings.json`.
