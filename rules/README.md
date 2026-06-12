# Rules — global 红线 + per-stack 风格守则

This folder is all rules map. 

| Bucket | Scope | Load pattern |
|---|---|---|
| `global/` | Applies to every repo, every file | Always-on (`alwaysApply: true`) |
| `stacks/<x>/` | Applies only when the repo touches files matching the stack's `globs:` | Activated when relevant files are edited |

## Layout

```
rules/
├── global/
│   ├── must-do.md            ← 守则 — checklist run before/during/after every change
│   ├── must-not-do.md        ← 红线 — things that have caused real incidents
│   ├── engineering.md        ← general engineering posture
│   ├── git.md                ← commit / branch / PR workflow
│   ├── reuse-first.md        ← search → reuse → write, in that order
│   ├── test-on-failure.md    ← every fix gets a regression test
│   └── decay.md              ← lifecycle for rules/ skills/ knowledge entries
└── stacks/
    ├── python/               ← *.py — PEP 8, pytest, FastAPI conventions
    ├── golang/               ← *.go — Google style, project architecture
    ├── frontend/             ← *.ts, *.tsx — TypeScript conventions
    ├── docker/               ← Dockerfile, docker-compose.yaml
    └── zsh/                  ← *.zsh, *.sh
```

## Frontmatter schema

Every rule file starts with YAML frontmatter:

```yaml
---
description: One-line summary. Shown in tooling / decay reports.
globs: "**/*"            # Or e.g. "**/*.py" — when this rule activates.
alwaysApply: true        # Optional. true = global red-line; default = activated by globs.
---
```

`globs` and `alwaysApply` follow the Cursor convention. The harness uses them for two things:

1. **Decay scans** (`scripts/scan-decay.sh`) read the frontmatter to decide what to age-out.
2. **Documentation contracts** — you write `globs:` so a future reader (human or assistant) knows when this rule is meant to be in scope.

> ⚠️ **Loading is not automatic in Claude Code.** Unlike Cursor, CC does not natively read `globs:` / `alwaysApply:` to inject rules into context. Today, rules reach the assistant through one of:
> - The business repo's `CLAUDE.md` `@`-importing specific rule files, OR
> - A `SessionStart` / `UserPromptSubmit` hook that cats the relevant files into stdout.
>
> If you add a new always-on rule under `global/`, also wire it into whichever mechanism the repo uses, or it will silently never run. See `docs/architecture.md` for the canonical loading flow.

## How a rule reaches a business repo

The central harness's `rules/` directory is symlinked into each onboarded business repo by `scripts/init-business-repo.sh` step 3:

```
<business-repo>/.claude/rules  ──symlink──>  <central-harness>/rules
```

Drop a new `.md` file in the appropriate sub-folder of the central repo. Push. Every onboarded business repo sees it on the next session — no init re-run, no copy.

This is the article's 零拷贝 / 中央仓改完即生效 property — but see the loading caveat above before assuming the new rule is actually in context.

## Adding a new rule

1. **Decide the bucket.**
   - Cross-stack red line that applies to every repo? → `global/`.
   - Stack-specific style or framework convention? → `stacks/<x>/<rule>.md`. New stack? Make a new directory.
2. **Write the frontmatter.** `description` is mandatory; `globs` should be specific (`**/*.py`, not `**/*`); `alwaysApply: true` only for global red-lines.
3. **Wire it in.** If global / always-on, ensure the business repos' `CLAUDE.md` template (or the loading hook) picks it up. If stack-specific, the per-stack loader (TBD or repo-local) handles it.
4. **Push.** The symlink does the rest.

### Review bar

| Bucket | Review bar |
|---|---|
| `global/must-do.md`, `global/must-not-do.md` | Same as a hook — these are tripwires; a wrong line silently affects every repo. Two reviewers minimum. |
| Other `global/*.md` | One reviewer who works in a different stack from the author (catches accidental specificity). |
| `stacks/<x>/*.md` | One reviewer who actually writes that stack daily. |

### What does **not** belong here

- **Field maps, glossary entries, enum tables** → `knowledge/reference/`.
- **System landscape, data flows** → `knowledge/domain/`.
- **"Don't change X without checking Y" pre-flight checks** → `knowledge/constraints/`.
- **Reusable workflows the assistant can invoke on demand** → `skills/`.

Rules are imperative ("do this", "don't do that"). Anything descriptive belongs in `knowledge/`. Anything procedural-and-skippable belongs in `skills/`.

## Editing existing rules

Per `global/must-not-do.md` rule #11: **do not edit files under `.claude/rules/` from inside a business repo.** Those paths are symlinks to the central harness; direct edits silently apply to every business repo without review. The `guard-symlinked-paths.sh` PreToolUse hook refuses Edit/Write tool calls that target symlinked paths, but use the right edit point (this central repo) to begin with.

## Decay

Per `global/decay.md`, untouched rules archive after 90 days, hard-delete after 180 days. `scripts/scan-decay.sh` lists candidates by reading frontmatter timestamps and last-modified mtimes. Rules with no obvious owner or no recent activity get flagged first.

The intent: a rule exists to fix a problem the model actually has. As models improve, some rules become dead weight in the context window. Decay is the pressure valve.
