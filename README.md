# team-harness

A **central Harness Engineering repo** for a team's AI coding workflow. Distributes rules, skills, hooks, and knowledge to many business repos via **symlinks**, so a change made here is live in every linked repo on the next session — no re-install, no projection, no CLI.

Inspired by the article *"我们没有重构那 20 万行代码，但问题解决了：供应链系统的 Harness Engineering 实践"* (https://km.woa.com/articles/show/662361).

## What's inside

```
rules/        global + per-stack .md rule packs (must-do, must-not-do, decay, …)
knowledge/    three-tier knowledge base: reference / domain / constraints
skills/       experience-capture (the L2 evolution river), find-skills, skill-creator
commands/     /verify and /ec-scan slash commands
hooks/        five-layer gate scripts + the settings.fragment.json that wires them
contexts/     per-business-repo CLAUDE.md (rendered on first onboard)
templates/    .mcp.json template
scripts/      init-business-repo.sh, post-merge.sh
```

## How a business repo onboards (60 seconds)

```bash
# 1. Clone this central repo somewhere persistent
git clone <this-repo> ~/work/team-harness

# 2. From any business repo:
cd /path/to/your-business-repo
bash ~/work/team-harness/scripts/init-business-repo.sh
```

That's the whole onboarding. The script creates six symlinks under `.claude/`, jq-merges a hooks fragment into `.claude/settings.json`, drops a post-merge git hook, and renders a per-repo `CLAUDE.md` from a template. Every step is idempotent — re-run anytime to repair.

## What you get after onboarding

In your business repo:

- `.claude/rules/`, `.claude/skills/`, `.claude/hooks/`, `.claude/commands/`, `.claude/knowledge/` → symlinks to this central repo
- `.claude/settings.json` → wired to the five-layer gates (PreToolUse on `git commit`, PostToolUse on `Edit/Write`, Stop)
- `CLAUDE.md` → symlink to a per-repo file in this central repo's `contexts/<slug>/`
- `.git/hooks/post-merge` → auto-pulls this central repo on every `git pull` of the business repo
- `experiences.jsonl` → starts empty in your business repo; `/ec-scan` appends to it

## The four layers

| Layer | What it does | Lives in |
|---|---|---|
| **L1 看得懂** | Make the codebase readable to AI (navigation table + 3-tier knowledge) | `contexts/`, `knowledge/`, `rules/` |
| **L2 学得会** | Turn corrections into compounding knowledge | `skills/experience-capture/`, business repo `experiences.jsonl` |
| **L3 拦得住** | Mechanical gates — sensitive files, missing experience capture, untagged cross-repo edits | `hooks/pre-commit-guard.sh`, `hooks/stop-experience-capture-check.sh` |
| **L4 验得了** | "Done" must compile + test + lint | `commands/verify.md`, `hooks/pre-commit-guard.sh` GATE-3/4 |

## Why symlinks, not copies

When a rule changes here, every business repo sees the change on its next session. No `npm install`, no `team-harness upgrade`, no manifest. The article calls this 零拷贝; it's the property that makes the system livable in a 2-person team.

## Compatibility

- macOS (primary) and Linux. macOS BSD `ln`/`readlink` quirks are handled in the init script's `realpath_portable`.
- Windows is not supported (symlinks require admin-mode in NTFS); WSL2 works.
- Requires `bash`, `git`, `jq`. No Node, no Python, no compile step.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — how the pieces fit together
- [`docs/getting-started.md`](docs/getting-started.md) — the full onboarding walkthrough
- [`docs/contributing.md`](docs/contributing.md) — adding rules, skills, hooks
- [`CLAUDE.md`](CLAUDE.md) — for working *on* this central repo

## License

(Add your license file before shipping externally. Internal use OK as-is.)
