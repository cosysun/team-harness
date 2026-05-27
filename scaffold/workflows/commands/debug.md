# Debug issue

Investigate the reported bug systematically before proposing a fix.

## Steps

1. Reproduce the issue with a minimal case.
2. Gather evidence: stack traces, logs, recent commits, related config.
3. Form a root-cause hypothesis — do not patch symptoms first.
4. Only implement a fix after the hypothesis is confirmed.
5. Add or update a test that would have caught the bug.

## Rules

- No fixes without a stated root cause.
- Prefer the smallest change that addresses the cause.
- Match existing project conventions (see engineering rules).
