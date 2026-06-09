# `constraints/` — 🚧 Read before changing code in this area

This tier is the "改代码前必须查" layer. The assistant must read entries here **before** making code changes in the affected area. These are short, sharp, blocker-flavored rules — not aspirations.

## What goes here

A single `constraints.md` file per business area. Each constraint is one bullet, in this format:

```markdown
- **<area or file glob>**: <what's forbidden / required>. <one-sentence reason>.
```

Example:

```markdown
- **OrderService.persist*(): Must use a fresh entity instance, not a re-used one. Re-used instances overwrite concurrent edits silently (incident 2024-03).
- **Any field on a Kafka payload type**: Adding a non-nullable field is a breaking change for old consumers. Use `Optional<>` or default values.
- **migrations/V*__*.sql**: One DDL operation per file. Multi-op migration files have failed mid-flight twice.
```

## What does *not* go here

- General coding standards (those go in `rules/global/engineering.md`).
- "Do not do X anywhere ever" — that's a global rule, not an area constraint.
- Tutorials (those go in `../domain/`).

## Tone

Each constraint should be readable in 5 seconds and reflect a real failure mode you've hit. If you can't name the incident or the failure mode, the constraint is too speculative.

## Seed file

`constraints.template.md` is the starter. Replace the examples with constraints from your own incident history.

## Why "read before editing" and not "always-load"

`constraints/` files can grow large. The protocol: when the assistant is about to modify code in area X, it greps `constraints.md` for area X first. The grep is cheap; loading the whole file every turn is not.
