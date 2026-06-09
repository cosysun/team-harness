# `domain/` — 🗺️ Read once when entering a new module

This tier helps the assistant build a **global mental model** of how the system fits together. It loads once per "session-on-this-module" — not every turn.

## What goes here

- **`system-landscape.md`** — the 30-second tour of services, queues, databases, who calls whom. One file per business unit.
- **`data-flows.md`** — how a request becomes data at rest. Flowcharts in markdown (Mermaid OK), a paragraph each on the surprising hops.
- **`processes/`** — per-business-stage walkthroughs. One file per `stage-N-<name>.md`. These are the "what actually happens between A and B" docs.

## What does *not* go here

- Field-level minutiae — that's `../reference/`.
- Hard "do not do this" rules — that's `../constraints/`.
- "How to set up your laptop" — that's developer onboarding, not domain knowledge.

## Tone

Write these like you're explaining the system to a new hire over coffee. Not "the system uses event sourcing"; rather, "when an order is placed we write the request to `order_request_log`, then the matcher reads from that and writes a `match_attempt` row, which then..."

## Seed file

`system-landscape.template.md` is the starter. Replace the example content with your own.

## Why "load once per module" not "always-load"

Domain docs are long. Loading them on every turn burns context the assistant could have spent on the actual task. The protocol is: when the assistant is starting work on a new module, it reads the relevant `domain/` files once, then proceeds without re-reading until the conversation ends or the module changes.
