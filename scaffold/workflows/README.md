# Team Harness — workflow starters

Installed by `team-harness init` when `--commands` and/or `--agents` are enabled.

| Type | Purpose | Invoke |
|------|---------|--------|
| **commands/** | Slash-command prompts | Type `/` in chat (Cursor / Claude Code) |
| **agents/** | Delegated subagents | Agent picker or `@explore` style invocation per IDE |

Customize these files for your team. Prefer keeping commands thin and moving long SOPs into `.cursor/skills/` or `.claude/skills/`.
