# Constraints

> Replace examples below with your own once you have real ones. Each constraint should be tied to a real failure.

Format per entry:

```
- **<area or file glob>**: <what's forbidden / required>. <one-sentence reason or incident reference>.
```

## Examples

- **OrderService.persist*()**: Must build a new entity from changed fields, not mutate a previously-loaded entity. Reused entities overwrite concurrent edits silently (incident 2024-03).
- **Any field on a Kafka payload type**: Adding a non-nullable field is a breaking change for old consumers. Use `Optional<>` or default values, and tag the commit `[cross-repo-impact]`.
- **migrations/V*__*.sql**: One DDL operation per file. Multi-op migrations have failed mid-flight twice (incidents 2023-11, 2024-01).
- **PricingService.applyPrice()**: Do not call this from outside the order placement main flow. It mutates `OrderLine.batch_price_status` in place, and out-of-flow callers desync the order's status history.
- **`*Repository.findBy*` methods**: Always treat the result as `Optional`/`null`. Several incidents have come from assuming a record exists.

## Add your own here

(delete the examples above when you have your own)
