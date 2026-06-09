# Contributing

Adding to the central harness is the same shape no matter what kind of thing you're adding: drop a file in the right folder, push to the central repo, every business repo sees it next session.

There's no review automation; we rely on PR review.

## Adding a global rule

```bash
$EDITOR rules/global/<rule-name>.md
```

`.md` frontmatter:

```yaml
---
description: One-sentence what-and-why. The frontmatter is loaded eagerly; keep it sharp.
globs: "**/*"        # or a more specific glob if it only applies to certain files
alwaysApply: true    # for must-do / must-not-do tier; false for opt-in rules
permanent: false     # set true ONLY for structural rules (security, workflow) — see decay.md
---

# <Title>

(body — what you should and shouldn't do, with examples)
```

Conventions:

- **Always-on rules belong in `rules/global/`.** Per-language stuff goes in `rules/stacks/<lang>/`.
- **Each rule should reflect a real failure mode.** If you can't describe the incident or the bug class, the rule is too speculative.
- **Pair with a hook if the rule is critical.** Rules that depend on the assistant's discipline rot. If the rule is "must X", consider whether `hooks/pre-commit-guard.sh` can enforce X mechanically.

## Adding a knowledge entry

Pick the right tier (see `knowledge/README.md`):

- **`knowledge/reference/`** — searched on demand. New entries here are cheap; add freely.
- **`knowledge/domain/`** — read once per module. Higher bar; review for accuracy.
- **`knowledge/constraints/`** — read before editing. Highest bar; a wrong constraint blocks correct work.

Format follows the templates in each subfolder.

## Adding a skill

```bash
mkdir -p skills/<skill-name>/references
$EDITOR skills/<skill-name>/SKILL.md
$EDITOR skills/<skill-name>/_meta.json
```

`SKILL.md` frontmatter:

```yaml
---
name: <skill-name>
description: When to use the skill. The description is the *only* thing the assistant reads to decide whether to invoke; make every word count.
---
```

Body: imperative-voice instructions. Aim for under 500 lines; split details into `references/*.md`.

`_meta.json`:

```json
{
  "name": "<skill-name>",
  "version": "0.1.0",
  "category": "harness",
  "description": "Same as SKILL.md frontmatter, copy here.",
  "permanent": false
}
```

`permanent: true` opts out of decay (see `rules/global/decay.md`).

## Adding a slash command

```bash
$EDITOR commands/<command-name>.md
```

Filename minus `.md` is the slash command. **Do not add YAML frontmatter** — Claude Code's slash commands are plain markdown. The body is the prompt that runs when the user types `/<command-name>`.

Conventions:

- **Imperative voice.** "Run X. If it fails, do Y."
- **Concrete steps.** Short list, not prose.
- **Refusal clauses.** Make the command's not-doable cases explicit (`/verify` refuses to skip steps; `/ec-scan` refuses to fabricate findings).

## Adding a hook

Two files to touch:

1. `hooks/<hook-name>.sh` — bash script. Read Claude Code's payload from stdin if applicable. Exit 0 to allow, exit 2 to block (per Claude Code conventions).
2. `hooks/settings.fragment.json` — add a binding under `hooks.PreToolUse`, `hooks.PostToolUse`, `hooks.Stop`, etc. Reference your script with `${HARNESS_ROOT}/hooks/<hook-name>.sh` — the init script substitutes the variable at merge time.

After editing the fragment, every business repo needs to re-run init to pick up the new binding:

```bash
# From the central repo, batch-merge:
bash scripts/init-business-repo.sh
```

(Symlinked dirs propagate automatically; only `settings.json` requires re-merge because it's a copy.)

## Adding a stack-specific rule

```bash
$EDITOR rules/stacks/<stack>/<rule-name>.md
```

The convention is one stack per directory under `rules/stacks/`. There's no catalog or registry — files in `rules/stacks/<x>/` are visible through the symlink as `.claude/rules/stacks/<x>/`. Whether the assistant reads them depends on the rule's own `globs:` and `alwaysApply:` frontmatter.

## Editing in a business repo (don't)

If you edit `.claude/rules/global/must-do.md` from inside a business repo, you are editing the central repo through the symlink. The change will silently apply to every business repo without review. Don't.

`rules/global/must-not-do.md` rule #11 is the long version of this warning.

## Testing changes

There's no formal test suite. The smoke test:

```bash
mkdir -p /tmp/scratch-biz && cd /tmp/scratch-biz && git init -q
bash ~/work/team-harness/scripts/init-business-repo.sh
# inspect symlinks and .claude/settings.json
```

For hook changes, test the gate manually:

```bash
cd /tmp/scratch-biz
# Trigger the failure mode you're trying to catch
echo 'syntax error' > broken.go
git add broken.go
git commit -m "test: gate-3"   # should be rejected by GATE-3
```

If the gate works in `/tmp/scratch-biz`, it works everywhere.

## Decay housekeeping

Periodically (quarterly is fine), search for `_archive/` candidates:

```bash
# Files in rules/, skills/, or knowledge/ untouched for 90+ days
find rules skills knowledge -type f -mtime +90 -name '*.md*' \
  | grep -v _archive
```

Move stale entries into `_archive/` mirror dirs, hard-delete after another 90 days. See `rules/global/decay.md` for the policy.
