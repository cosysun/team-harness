---
description: Every fix commit must add a regression test. Enforced by GATE-4 in pre-commit-guard.sh.
globs: "**/*"
alwaysApply: true
---

# Test on Failure (吃一堑长一智的机械版)

Bugs reach production because no test exposed them. The fix without a regression test only proves the bug *can* be fixed; the regression test is what proves the bug *stays* fixed.

## The rule

If the commit type is `fix`, `bugfix`, or `hotfix` (per Conventional Commits), the commit must add at least one new file matching one of:

- `*_test.go`
- `*_test.py`, `test_*.py`
- `*.test.ts`, `*.spec.ts`, `*.test.tsx`, `*.spec.tsx`
- `*Test.java`, `*Tests.java`, `*Spec.java`
- `*_test.rb`, `*_spec.rb`

GATE-4 in `.claude/hooks/pre-commit-guard.sh` rejects fix-type commits with no new test file. The error message names the missing test.

## Shape of a good regression test

The test must **fail without the fix and pass with it**. To verify:

1. Stash the implementation change (`git stash --keep-index` after staging only the test).
2. Run the test — it must fail with the bug's error message.
3. Pop the stash. Run again — it must pass.

If the test passes both times, it's not testing the bug. Rewrite it.

## What goes in the test name

The test name should describe the bug, not the function. Future readers will search for the bug, not the function.

Bad: `TestOrderService_ProcessBatch_2`
Good: `TestOrderService_ProcessBatch_HandlesNullBatchPriceStatus`

## Exemptions

Pure documentation, comment-only, and configuration-only fixes are exempt — they cannot be regression-tested in code. The risk-tier classifier in `hooks/lib/risk-tier.sh` marks these as `minimal` and skips GATE-4. If you are uncertain whether a change is exempt, treat it as not exempt.
