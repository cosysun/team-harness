# Glossary — project terms

Format per entry: `term` — short definition. Link to longer treatment if needed.

Sort alphabetically (case-insensitive). One blank line between letter sections.

## Examples (delete after filling in your own)

`batch_price_status` — back-filled enum field on `OrderLine` written by `PricingService.applyPrice()` after the price-lookup step in the main flow. **Not** sourced from the upstream request despite being on the request DTO. See `field-maps/order-line.md`.

`tenant_id` — system-wide tenant identifier; required on every persisted entity. Set automatically by the persistence layer's interceptor; do not pass through from request bodies.

## Sections (uncomment when you have entries)

<!--
## A
## B
## C
...
-->
