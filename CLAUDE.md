# Claude Code — `team-harness` (central repo)

This is the **central harness repo** described in https://km.woa.com/articles/show/662361. Business repos symlink to its top-level dirs; the only "engine" is `scripts/init-business-repo.sh`. There is no CLI, no npm, no projection.

## I want to… → here's how

| I want to… | How to find it |
|---|---|
| **Onboard a new business repo** | `cd /path/to/biz && bash $HARNESS/scripts/init-business-repo.sh` (Mode B), or list paths in `business-repos.conf` and run from the central repo (Mode A). |
| **Add a new global rule** | Drop a `.md` file in `rules/global/`. Push. Every business repo's symlink picks it up on the next session — no init re-run needed. |
| **Add a new skill** | Create `skills/<name>/{SKILL.md,_meta.json}` per the existing skills. |
| **Add a new slash command** | Drop a `.md` in `commands/`. The filename minus `.md` becomes the command. |
| **Add a new hook** | Drop a `.sh` in `hooks/` and add a binding to `hooks/settings.fragment.json`. Re-run init in each business repo to merge the new binding. |
| **Add a new knowledge tier** | Don't (only three tiers, by design). Add an entry to `reference/`, `domain/`, or `constraints/` instead. |
| **Edit a business repo's `CLAUDE.md`** | Don't do it from here — those files live in the business repos themselves now. The central harness used to symlink them via `contexts/<slug>/`; that indirection was removed. |
| **Find the answer when nothing above helps** | Ask in chat. The article spends two pages making the case for "do not guess"; do not be the counter-example. |

## Layout

```
team-harness/                       ← the central repo
├── rules/                          ← global + per-stack rule packs
├── knowledge/                      ← reference / domain / constraints
├── skills/                         ← experience-capture, find-skills, skill-creator
├── commands/                       ← /verify, /ec-scan
├── hooks/                          ← five-layer gates + settings.fragment.json
├── templates/                      ← .mcp.json.template
├── scripts/                        ← init-business-repo.sh, post-merge.sh
├── docs/                           ← architecture / getting-started / contributing
├── business-repos.conf.example     ← starter for batch-onboard
├── README.md
└── CLAUDE.md                       ← (this file — for working *on* the central repo)
```

`CLAUDE.md` files in business repos are **not** managed here. Each business repo owns its own as a real file. The init script will detect and clean up any legacy symlinks pointing at the (now-removed) `contexts/` directory.

## Working on this repo

When you edit something here, remember it propagates to every business repo via symlink:

- **Rules**: changes are live next session. There is no review process between editing `rules/global/must-do.md` and a developer 3 cubicles over reading it.
- **Hooks**: bash scripts run inside the business repo with the business repo as `cwd`. Test on `/tmp/scratch-biz` first.
- **Skills**: `SKILL.md` frontmatter is loaded eagerly; the body is loaded lazily. Keep `description` sharp.
- **Slash commands**: filename = command name. Don't add YAML frontmatter to command files.
- **Hook settings**: `hooks/settings.fragment.json` uses `${HARNESS_ROOT}` — `init-business-repo.sh` substitutes it at merge time. Don't reference env vars elsewhere; Claude Code does not expand them.

## Conventions to preserve

- **Idempotent init**: every step in `init-business-repo.sh` must be guard-then-act so re-running is safe. New steps must follow this rule.
- **Zero-copy except `.mcp.json`**: everything in a business repo is a symlink (or a settings.json merge); only `.mcp.json` is copied because it carries per-repo tokens.
- **macOS-portable bash**: the dev machines are macs. BSD `ln`, no `readlink -f`. Use `realpath_portable` from the init script when computing paths.
- **No silent overwrites**: `init-business-repo.sh` backs up to `.bak` if it finds an unexpected file in a target slot.

## Tests

There aren't formal tests yet — verification runs end-to-end in `/tmp/scratch-biz`:

```bash
mkdir -p /tmp/scratch-biz && cd /tmp/scratch-biz && git init -q
bash $HARNESS/scripts/init-business-repo.sh
# inspect the symlinks and the merged .claude/settings.json
```

See `docs/getting-started.md` for the full smoke-test recipe.
