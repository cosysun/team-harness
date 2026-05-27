# Pre-landing code review

Review the current branch diff against the base branch before merge.

## Steps

1. Run `git diff` against `main` or `develop` (whichever is the integration branch).
2. Check for: security issues, error handling gaps, missing tests, scope creep, and violations of project rules in `.cursor/rules/` or `.claude/rules/`.
3. Flag SQL safety, trust boundaries, and conditional side effects.
4. Summarize findings as: **blockers**, **should fix**, **nit**. Do not fix unless asked.

## Output

- Verdict: pass / pass with nits / fail
- Top 3 risks with file references
