# Skills

This folder ships **agent skills** that all business repos consume via the symlink at `.claude/skills/`.

## What's here

| Skill | Purpose | Trigger |
|---|---|---|
| `experience-capture/` | Seven-perspective audit at end of turn; appends to `experiences.jsonl`; proposes `_draft/` promotions | `/ec-scan` or Stop-hook |
| `find-skills/` | Discover and install community skills | "find a skill for X" |
| `skill-creator/` | Guide for authoring new skills | "create a skill" |

## How a skill reaches a business repo

The central harness's `skills/` directory is symlinked into each onboarded business repo by `scripts/init-business-repo.sh` step 3:

```
<business-repo>/.claude/skills  ──symlink──>  <central-harness>/skills
```

Drop a new skill under `skills/<name>/` in the central repo. Push. Every onboarded business repo sees it on the next session — no init re-run, no copy.

## Skill anatomy

```
<skill-name>/
├── SKILL.md          # Required. YAML frontmatter (name, description) + body.
├── _meta.json        # Optional. Versioning, category, permanent flag.
└── references/       # Optional. Detail pages loaded lazily.
```

Frontmatter schema (the assistant reads this eagerly to decide whether to invoke):

```yaml
---
name: <skill-name>
description: When to use, including trigger phrases. The body is loaded only after this triggers.
---
```

Detailed authoring guide: see `skill-creator/SKILL.md`.

## Adding a draft skill

`skills/_draft/` holds skills auto-promoted by `experience-capture` after ≥3 occurrences of the same multi-step pattern. A maintainer reviews and `git mv`'s them out of `_draft/` when they're ready.

Drafts do not auto-load — they're invisible to the assistant until the maintainer promotes them. See `rules/global/decay.md` and `experience-capture/references/promotion-thresholds.md`.

## Decay

Skills go stale. Run `bash scripts/scan-decay.sh` from the central repo quarterly to list candidates. Skills with `permanent: true` in `_meta.json` are excluded.
