# Promotion Thresholds and Decay

Findings move up the ladder by frequency. Decay moves them down by neglect.

## Promotion ladder

| From | To | Trigger | Mechanism |
|---|---|---|---|
| `experiences.jsonl` line | `knowledge/<tier>/...` | ≥1 occurrence, `perspective: knowledge` | Suggest the user create the entry. Auto-create when path is unambiguous. |
| `experiences.jsonl` line | `rules/_draft/<name>.md` | ≥2 occurrences of same `correction` / `code-pattern` / `pitfall` topic | Auto-create draft. Human moves it out of `_draft/` when ready. |
| `experiences.jsonl` line | `skills/_draft/<name>/SKILL.md` | ≥3 occurrences of same multi-step `repetition` topic | Auto-create draft. Human moves it out of `_draft/` when ready. |

### "Same topic" — how to count

Two findings are the same topic if they would resolve to the same rule or skill. Use a short topic key per finding (e.g., `tenant_id-auto-fill`, `feign-client-versioning`). If the topic key matches an existing draft, increment its count — do not create another draft.

Track topic keys in JSONL by adding a `topic_key` field:

```json
{ "ts": "...", "perspective": "pitfall", "topic_key": "tenant_id-auto-fill", "summary": "...", ... }
```

Counting is then a simple grep.

## Self-rewrite when a rule is wrong

If the same `correction` topic fires *against* an existing rule (i.e., the assistant followed the rule and got corrected anyway), the rule is wrong or stale. Mark the rule head with:

```markdown
🔄 v2: <one-line note about the new understanding>
```

— and capture an EC-SCAN finding about the rule revision. Do not silently overwrite the rule body; the v2 line is the audit trail.

## Decay

Per `rules/global/decay.md`, decay is a **manual quarterly task**, not automatic:

- A maintainer runs `bash scripts/scan-decay.sh` from the central repo to list candidates.
- **90 days untouched** — candidate to move to `_archive/`. Decision is human.
- **180 days untouched while in `_archive/`** — candidate for hard-delete. Decision is human.
- **`permanent: true`** in frontmatter — excluded from the candidate list.

"Untouched" is measured by `git log -1 --format=%ct -- <file>` — last commit time. The skill does **not** maintain its own `last_touched` timestamp; the git history is the source of truth.

## Why this layering exists

A flat "rules dump" rots fast. New rules pile on top of old, sometimes contradictory ones. The promotion ladder forces a moment of human review at every step, and decay forces a moment of housekeeping every quarter. Both are cheap individually; together they keep the harness alive without growing toxic.
