---
description: Language-agnostic engineering standards for all team projects — collaboration, security, and change discipline.
globs: "**/*"
alwaysApply: true
---

# Team Engineering Standards

These rules apply to every project regardless of language or stack.

## Collaboration and change discipline

1. Analyze the existing codebase before adding features; reuse existing modules when possible.
2. Keep each change minimal; one PR should address one problem.
3. Every change must include a clear commit message (Conventional Commits).
4. New features must include appropriate automated tests for the stack in use.
5. Document non-obvious decisions in code comments or project docs.

## Security

1. Prefer migration scripts or reviewed DDL for database schema changes; do not apply destructive schema changes without explicit confirmation.
2. Never hardcode secrets (API keys, connection strings, tokens); use environment variables or a secrets manager.
3. Validate and sanitize all external input at system boundaries.

## Code quality

1. Functions and methods should have a brief comment or docstring explaining purpose when not self-evident.
2. Do not silently ignore errors; handle them explicitly or propagate with context.
3. Prefer small, focused functions; split when logic grows hard to follow.

## Documentation

1. Keep `AGENTS.md` (or equivalent AI context file) accurate when architecture or workflows change.
2. API or public interface changes must update the relevant API docs (OpenAPI, README, etc.).
