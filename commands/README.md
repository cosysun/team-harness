# `commands/` — slash commands

This folder is the L4 "验得了" pillar plus the L2 trigger surface. Each `.md` file here is a slash command available in business repos via the symlinked `.claude/commands/`.

## Commands

| Command | Purpose | Linked gate |
|---|---|---|
| `/verify` | Run compile + tests + lint, refuse to claim done without artifacts | GATE-3, GATE-4 |
| `/ec-scan` | Run the seven-perspective experience-capture audit | Stop-hook scan gate |

## How a slash command file works

The file body is the prompt that gets injected when the user types the slash command. Keep it concise; the assistant runs the steps directly. Use imperative voice — "Run X. If it fails, do Y."

Do **not** add YAML frontmatter — Claude Code's slash commands are plain markdown, the filename (minus `.md`) is the command name.

## Adding a command

1. Drop a new `<name>.md` in this folder.
2. Push to the central repo.
3. Every business repo's symlink picks it up on the next session.

If the command needs to be enforced (not just available), pair it with a hook in `../hooks/` that requires the canonical "executed" marker.
