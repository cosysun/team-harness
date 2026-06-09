---
name: experience-capture
description: Auto-captures lessons learned during a coding session into the business repo's experiences.jsonl ledger using a seven-perspective self-audit. Use this skill at the end of any turn that involved writing, modifying, or debugging code, or that received a correction from the user. Also invokable explicitly via /ec-scan. Frequency thresholds promote captured experiences into knowledge/, rule drafts, or skill drafts. Triggered by user phrases like "capture this", "remember this", "log this experience", "what did we learn", or whenever the Stop hook demands an EC-SCAN before ending the turn.
---

# Experience Capture

This skill turns one-off corrections into compounding knowledge. The article calls it the "AI 自主进化河道". Without it, every fix you make today is a fresh fix tomorrow — the model never learns.

## When to run

Run **at the end of any turn that involved code or received a correction**. The Stop hook (`stop-experience-capture-check.sh`) enforces this — if you end the turn without writing the `EC-SCAN` marker into chat, the hook rejects.

You can also run it explicitly via `/ec-scan` when you notice mid-conversation that something worth capturing happened.

## What it does (sequence)

1. **Run the seven-perspective self-audit.** See `references/seven-perspectives.md`. For each perspective, ask the corresponding question; write down anything that surfaces.
2. **Write a JSONL line per finding** to `<business-repo>/experiences.jsonl`. One line per finding, append-only. Schema below.
3. **Check the frequency table.** See `references/promotion-thresholds.md`. If a finding crosses a threshold, propose a promotion (knowledge entry, rule draft, or skill draft).
4. **Emit the canonical marker** in the chat: a single line reading `EC-SCAN executed: N findings`. The Stop hook greps for this; without it, the turn is rejected.

## JSONL schema

One line per finding:

```json
{
  "ts": "2026-06-09T15:00:00Z",
  "perspective": "correction|knowledge|repetition|pitfall|field-mapping|code-pattern|process",
  "summary": "One-sentence description of what happened.",
  "evidence": "Brief excerpt or commit hash; never the full diff.",
  "files": ["path/to/file.ext"],
  "promotion_candidate": "knowledge|rule-draft|skill-draft|null",
  "session_id": "abbr"
}
```

Rules for the JSONL line:

- **`ts`** — ISO 8601 UTC. The assistant must use the host clock; do not invent times.
- **`perspective`** — exactly one of the seven values. Use the most specific one.
- **`summary`** — one sentence. If you can't say it in one sentence, you have two findings, not one.
- **`evidence`** — short. The point is to be findable later, not to recreate the diff.
- **`promotion_candidate`** — set to `knowledge` if this is a fact (≥1 occurrence is enough), `rule-draft` if a behavioral correction (need ≥2 to escalate), `skill-draft` if a multi-step procedure (need ≥3), or `null` if not promotable yet.

## Where to write the ledger

`<business-repo-root>/experiences.jsonl` — **always in the business repo**, never in the central harness repo. The ledger is per-project; the rules and skills it eventually produces are central.

If `experiences.jsonl` does not exist, create it. Append; never rewrite.

## Promotion (≥1 / ≥2 / ≥3 thresholds)

After writing JSONL lines, run a quick frequency check on the perspective + topic:

| Threshold | Action |
|---|---|
| ≥1 occurrence of a `knowledge` perspective finding | Suggest the user add a `knowledge/{reference,domain,constraints}/...` entry. (Knowledge is fact; one observation is enough.) |
| ≥2 occurrences of the same `correction` / `code-pattern` / `pitfall` finding | Open a draft rule under `rules/_draft/<short-name>.md`. The draft sits there until a human reviews and moves it out. |
| ≥3 occurrences of the same multi-step procedure | Open a draft skill under `skills/_draft/<short-name>/SKILL.md`. Same review gate. |

Drafts live in `_draft/` precisely because the tribe should see them before they go global. Auto-promotion past the draft folder is **not allowed**.

## What this skill does *not* do

- Does not edit `rules/` or `skills/` directly. Promotion is to `_draft/`.
- Does not rewrite `experiences.jsonl`. Append only.
- Does not run the model — it runs *the assistant* through a checklist.

## Self-test

A correctly executed EC-SCAN ends with:

1. New lines appended to `experiences.jsonl` (or zero, if nothing was found — that's also valid).
2. Optionally, new draft files under `rules/_draft/` or `skills/_draft/`.
3. The chat message `EC-SCAN executed: N findings` (where N can be 0).
