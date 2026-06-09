# Seven Perspectives — the EC-SCAN checklist

Run these seven questions at the end of any turn that involved code or a correction. Each one is a different angle on "what did we learn". Findings get written to `experiences.jsonl` (one line per finding).

A turn that surfaces zero findings is fine — write zero lines and emit `EC-SCAN executed: 0 findings`. The point is the *scan*, not the count.

## 1. Correction (纠错)

> "Did the user correct me? On what?"

Look for any place the user said "no", "wrong", "actually", or rewrote what you produced. Each one is a correction. Capture it: what did you produce, what did the user change it to, why.

`perspective: "correction"`

## 2. Knowledge (知识)

> "Did I learn a project fact that wasn't in `knowledge/`?"

Field meanings, where data is back-filled, the actual semantics of an enum, who owns which table. If you discovered something true about the system that isn't yet documented, write it down.

`perspective: "knowledge"` — **promote to `knowledge/` after 1 occurrence**.

## 3. Repetition (重复)

> "How many times have I done this before? Should it be a script or a skill?"

If you wrote the same shape of code/glue/migration template more than once, it's a candidate for promotion to a skill. Note what the repeated procedure was.

`perspective: "repetition"`

## 4. Pitfall (踩坑)

> "What broke? What almost broke? What's a footgun here?"

Compile errors that surprised you, runtime failures that hit a corner, things you didn't expect. Each pitfall is a constraint candidate.

`perspective: "pitfall"` — promotion candidate is usually `knowledge` (constraints/) or `rule-draft`.

## 5. Field-mapping (字段映射)

> "Did I figure out where a value comes from / goes to?"

Specifically about data flow: `request.foo` -> back-filled by `XService.bar()` -> persisted to `table.baz`. These are the highest-leverage `reference/field-maps/` entries.

`perspective: "field-mapping"`.

## 6. Code-pattern (代码模式)

> "If I were code-reviewing this turn, what would I flag?"

Non-obvious anti-patterns, missing error handling, places where a future contributor will misuse the API. The hardest perspective because you have to look at your own work as a stranger.

`perspective: "code-pattern"`.

## 7. Process (流程)

> "What end-to-end flow did I just touch? Is it documented?"

If your turn touched stage 1 of order placement and your knowledge of that stage is now better than what's in `domain/processes/`, capture the gap.

`perspective: "process"`.

---

## Tips

- **One sentence per summary.** If you can't, split into two findings.
- **Don't capture noise.** "I made a typo and fixed it" is not a finding. "I assumed `tenant_id` came from the request but it's set by an interceptor" is.
- **Be honest about repetition.** If you did the same thing yesterday, capture it as `repetition` even if you don't remember exactly. The frequency counter will sort it out.
- **Zero findings is a valid outcome.** Don't fabricate to look thorough.
