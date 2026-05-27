# Team Harness — Skills

This folder documents how the team maintains **agent skills** alongside harness rules.

## In target projects

When `team-harness init --skills` is used, a project-local skills README is created under:

- `.cursor/skills/` (Cursor)
- `.codebuddy/skills/` (CodeBuddy)
- `.claude/skills/` (Claude Code)

Codex 使用 `AGENTS.md` 与可选 `.codex/config.toml`，不单独安装 skills 目录（除非同时选中 Cursor/CodeBuddy/Claude）。

## Example skill layout

```
my-skill/
  SKILL.md    # Required: description + when to use + steps
```

See [Cursor Agent Skills](https://cursor.com/docs) for format details.

## Repository skills

Add optional example skills under `skills/example/` for copy-paste; keep them small and redact secrets.
