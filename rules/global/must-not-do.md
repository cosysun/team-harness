---
description: Hard "do not do this" rules — checked before every code change, enforced mechanically by hooks/ where possible.
globs: "**/*"
alwaysApply: true
---

# Must Not Do (红线)

These rules describe things that have caused real incidents. Each line is a tripwire. If you are about to do one of these, stop and ask the user instead.

The companion gates in `.claude/hooks/` enforce many of these mechanically; the rules here exist so you know **why** the gate fired.

## Sources of truth

1. **Do not guess where a field comes from.** If a value's source is not obvious from the function you're editing, search the main flow end-to-end before writing anything that produces or transforms that value. Do not assume "it must come from the request" — internal services often back-fill values mid-flow.
2. **Do not rely on field names to infer semantics.** Two columns named `status` in different tables almost never mean the same thing. Check `knowledge/reference/glossary.md` and the field-map cards before assuming.
3. **Do not invent IDs, types, or enum values.** If a value's domain is not documented, ask. Inventing a value to make code compile is the most common silent bug source.

## Concurrency and persistence

4. **Database updates must use a fresh entity instance, not a previously-loaded one.** Mutating an in-memory entity loaded earlier in the request and then saving it overwrites concurrent edits. Build a new object from the changed fields and write only those.
5. **Never apply destructive schema changes (`DROP`, `TRUNCATE`, column type narrowing) without an explicit migration script reviewed by a human.**
6. **Do not silently catch and discard errors.** Either handle them with a written reason or propagate with context.

## Cross-repo / external surface

7. **Do not change a Feign client, SDK DTO, Kafka message shape, or shared SQL table without tagging the commit `[cross-repo-impact]` in the message body.** GATE-2 in `pre-commit-guard.sh` will reject the commit otherwise.
8. **Do not assume the consumer of a public-facing change has been updated.** When you change a wire format, list the consumers in the commit body.

## Sensitive files (hooks block these outright; this rule is the explanation)

9. **Do not modify `.env`, `.env.*`, `*.production.*`, `.mcp.json`, `~/.aws/`, `~/.kube/`, secret files of any kind.** If a config genuinely needs changing, ask the user to do it manually.

## "Done" hygiene

10. **Do not say "done" / "fixed" / "tested" without artifacts.** "Done" is a claim, not evidence. GATE-3 (compile) and GATE-4 (regression test on `fix:` commits) are the mechanical version of this rule. Run `/verify` instead.

## Self-modification

11. **Do not edit files under `.claude/rules`, `.claude/hooks`, `.claude/knowledge` directly from a business repo.** Those paths are symlinks to the central harness repo — edit the central source and let the symlink propagate. Direct edits will silently apply to every business repo without review.
