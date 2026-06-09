# `reference/` — 📖 Look it up, then forget it

This tier is **searched on demand**. The assistant should read entries here when it hits an unfamiliar term, field, or enum value — not on every turn.

## What goes here

- **Glossary entries** — one term per line in `glossary.md`. Format: `term — short definition (link to longer treatment if needed)`.
- **Field maps** — one card per important table or DTO under `field-maps/`. Card schema:

  ```markdown
  # field-map: <table-or-dto-name>

  | Field | Type | Source | Notes |
  |---|---|---|---|
  | id | UUID | system-generated at insert | not from request |
  | batch_price_status | enum | back-filled by PricingService.applyPrice() | NOT from upstream |
  ```

- **Enum tables** — one card per enum where the values are not self-explanatory. Only add these when "the value 7 means active" is the kind of thing nobody remembers.

## What does *not* go here

- Anything that requires reading multiple files to use. That belongs in `../domain/`.
- Anything that says "do not change X". That belongs in `../constraints/`.

## Why search-on-demand and not always-load

A good `glossary.md` grows to thousands of lines. Loading it every turn drowns the actual task. Searching it on demand keeps the cost proportional to how many unknown terms the assistant hits.

## Seed file

Start with `glossary.template.md`. Copy it to `glossary.md` and fill in your project's terms.
