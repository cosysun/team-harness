---
description: Mandatory checklist run before, during, and after every code change. Pairs with must-not-do.md and the hooks/ gates.
globs: "**/*"
alwaysApply: true
---

# Must Do (守则)

Three checklists, one per phase of work. Each item is a thing that, if skipped, has historically caused rework.

## Before writing code

1. **Read `.claude/knowledge/constraints/` first.** That folder lists "改代码前必须查" rules — things that are easy to miss but cheap to check up front.
2. **Search `.claude/knowledge/reference/` for terms you're unsure about.** Field maps and glossary live there. Do not infer meaning from field names.
3. **Trace the main flow end-to-end before assuming where data comes from.** Especially for internal-back-filled values (price, status flags, computed IDs).
4. **State your plan before changing >2 files.** A one-paragraph plan in chat is enough; it lets the user redirect cheaply.

## While writing code

5. **Reuse before building.** Per `reuse-first.md`: search for existing utilities, then open-source options, then write new code.
6. **Keep the diff minimal and one-purpose.** Mixing a refactor into a fix is how regressions hide.
7. **Match the project's existing style.** Do not introduce new patterns mid-file; if a different pattern is genuinely better, do it as a separate commit.

## Before claiming done

8. **Run `/verify`.** It runs compile + relevant tests + lint and refuses to claim "done" without those artifacts.
9. **For any `fix:` / `bugfix:` / `hotfix:` commit, add a regression test that fails without the fix.** GATE-4 enforces this. The test is the only proof the fix works.
10. **For changes to Feign clients / SDK DTOs / Kafka topics / shared SQL tables, tag the commit `[cross-repo-impact]` and list the consumers.** GATE-2 enforces tagging; you supply the consumer list.
11. **Run `/ec-scan` (seven-perspective experience capture) before ending the turn.** The Stop-hook enforces this; the rule is here so you know what it's checking.

## When stuck

12. **Ask the user. Do not guess.** Inventing a field name, an ID format, or a missing import is the single most common cause of silent breakage. Asking is cheap; guessing is expensive.
