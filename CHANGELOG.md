# Changelog

All notable changes to team-harness are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-05-27

### Added

- **Workflow starters** (optional features): `commands` and `agents`
- Starter slash commands: `review`, `ship`, `debug` → `.cursor/commands/`, `.claude/commands/`, etc.
- Starter subagents: `explore`, `code-reviewer` → `.cursor/agents/`, `.claude/agents/`, etc.
- `init --commands`, `init --agents` (Codex is skipped — no native commands/agents dirs)
- Catalog fields `commandsDir` / `agentsDir` per IDE; manifest kinds `command` / `subagent`

### Changed

- Non-interactive `init` defaults CI to off unless `--ci` is passed
- `readManifest` normalizes missing `features.commands` / `features.agents` for older manifests

## [0.2.0] - 2026-05-27

### Added

- **Claude Code** support: `.claude/rules/*.md` (converted from `.mdc`), `CLAUDE.md`, `.claude/skills/`
- **Codex CLI** support: `AGENTS.md` instruction chain, `.codex/config.toml` scaffold
- `init --ide claude | codex | all | cursor,claude,codex` and manifest field `ides[]`
- `team-harness list` shows per-IDE context and config paths

## [0.1.0] - 2026-05-27

### Added

- **CLI** (`team-harness`): `init`, `doctor`, `list`, `upgrade`
- **Manifest** (`.harness.yaml`) with installed file tracking
- **Rule layers**: `rules/global/` (language-agnostic) + `rules/stacks/*`
- **Catalog** (`catalog/stacks.json`) for stack detection and feature packs
- **AGENTS templates** (Handlebars): golang, python, frontend, generic
- **Scaffold**: pre-commit, GitHub Actions CI, skills placeholder, docs/scripts skeleton
- **Docs**: getting-started, architecture, contributing
- **Schema**: `schema/harness.schema.json`

### Changed

- Migrated rules from `rules/golang|python|...` to `rules/stacks/`
- Replaced `rules/global/base.mdc` with `engineering.mdc` + `stacks/golang/architecture.mdc`

### Fixed

- Incorrect `globs` on former `base.mdc` (`**/**wq`)
- Go rule pack `globs` narrowed to `**/*.go`
