# Knowledge — three tiers, three load patterns

This folder is the L1 "看得懂" pillar of the harness. Knowledge here is *organized by how it gets read*, not by what kind of content it is.

| Tier | Load pattern | Example content |
|---|---|---|
| `reference/` | 📖 Look it up, then forget it | Glossary entries, field maps, enum value tables |
| `domain/`    | 🗺️ Read once when entering a new module | System landscape, data flow, business stage walkthroughs |
| `constraints/` | 🚧 Read before changing code in this area | "Do not do X here because Y", lock-step migration checklists |

## Why three tiers and not one big folder

If everything loads on every turn, the context window fills with irrelevant text and the model gets dumber. If nothing auto-loads, the model never reads any of it. The split is the compromise:

- **`reference/` is searched on demand.** The model only reads `glossary.md` or a specific field-map card when it hits an unfamiliar term. Cheap to grow.
- **`domain/` loads once per session-on-this-module.** Read it as orientation; do not re-read it every turn. A `system-landscape.md` may be 500 lines, but it pays for itself once and amortizes from there.
- **`constraints/` loads before any code change in the affected area.** This is the "改代码前必须查" tier — short, sharp, blocker-flavored.

## Where each tier lives

```
knowledge/
├── reference/
│   ├── glossary.md              ← 术语词典 (one entry per term, sorted)
│   ├── field-maps/              ← one card per important table/DTO
│   └── enum-tables/             ← one card per enum (rare; only when values are surprising)
├── domain/
│   ├── system-landscape.md      ← who calls whom; the 30-second tour
│   ├── data-flows.md            ← how a request becomes data at rest
│   └── processes/               ← per-business-stage walkthroughs
└── constraints/
    └── constraints.md           ← single-file checklist; small enough to read in 30s
```

## How to add a new entry

- **`reference/`**: any developer can add. No review needed. New entries go straight live.
- **`domain/`**: add a draft, get a review from someone who knows the area, then merge. These shape global understanding; bad ones cause more damage than missing ones.
- **`constraints/`**: same review bar as a rule. Constraints are blockers; a wrong constraint blocks correct code.

## How decay works here

Per `rules/global/decay.md`, untouched entries archive after 90 days, hard-delete after 180 days. `experience-capture` flags candidates. `permanent: true` opt-out is allowed but used sparingly.
