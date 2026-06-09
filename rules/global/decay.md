---
description: Lifecycle and decay rules for rules/ skills/ knowledge entries. Decay is a manual quarterly task supported by `scripts/scan-decay.sh`.
globs: "rules/**,skills/**,knowledge/**"
alwaysApply: false
---

# Decay (代谢)

Rules and skills exist to fix problems the model actually has. As models improve, some problems disappear — the rule that fixed them becomes dead weight in the context window. This file describes how entries age out.

**Important: decay is not automatic.** The harness does not run a background timer or recompute "last touched" stamps. Decay is a quarterly housekeeping task — see `scripts/scan-decay.sh` in the central repo, which lists candidates by `git log` mtime. A maintainer reviews the candidates and moves them.

## States

Every rule, skill, and knowledge entry has an implicit lifecycle:

| State | Where it lives | When it loads |
|---|---|---|
| `active` | `rules/` / `skills/` / `knowledge/` (top level) | Always (per its own loading rule) |
| `draft` | `rules/_draft/` / `skills/_draft/` | Only when explicitly read by the assistant |
| `archived` | `_archive/` mirror | Never auto-loads; kept for audit |
| `permanent` | tagged `permanent: true` in frontmatter | Excluded from decay |

## Promotion (entry into `active`)

Promotion thresholds match `experience-capture`:

- **knowledge entry**: ≥ 1 confirmed observation → goes straight to `knowledge/<tier>/`
- **rule**: ≥ 2 separate occurrences of the same correction → `rules/_draft/` for human review
- **skill**: ≥ 3 separate occurrences of the same multi-step correction → `skills/_draft/` for human review

A draft becomes active when a human moves it out of `_draft/`. There is no automatic promotion of drafts.

## Decay process (manual, quarterly)

From the central harness root, run:

```bash
bash scripts/scan-decay.sh
```

The script prints two lists:

1. **Archive candidates** — files under `rules/`, `skills/`, `knowledge/` whose last commit was >90 days ago and whose frontmatter does not include `permanent: true`. The maintainer reviews each, decides whether the rule is still useful, and `git mv`'s the dead ones into a sibling `_archive/` directory.
2. **Hard-delete candidates** — files already under `_archive/` whose last commit was >180 days ago. The maintainer reviews and `git rm`'s.

The script does not edit anything. Its only job is to surface the list. The thresholds are tunable: `ARCHIVE_DAYS=120 DELETE_DAYS=365 bash scripts/scan-decay.sh`.

## How to mark an entry permanent

In the frontmatter:

```yaml
---
description: ...
permanent: true
---
```

Use this only when the underlying problem is structural (workflow, security, compliance) and unlikely to be solved by a better model. `engineering.md`, `git.md`, and `must-not-do.md` are good candidates.

## Why decay matters

Without decay, every fix you ever wrote competes for context window space with every fix anyone else wrote, forever. The model improves; the rules don't go away on their own. Treat the rules pile like a kitchen — clean it once a quarter.
