# /ec-scan

Run the seven-perspective experience-capture audit. This is the same audit the Stop-hook enforces at end-of-turn, exposed as an explicit slash command for the cases where you want to capture mid-conversation.

## What this command does

Use the `experience-capture` skill (under `.claude/skills/experience-capture/`). Specifically:

1. Load `references/seven-perspectives.md` if not already in context.
2. For each of the seven perspectives, ask its question against the current turn:
   - **correction** — Did the user correct me?
   - **knowledge** — Did I learn a project fact not in `knowledge/`?
   - **repetition** — Have I done this before?
   - **pitfall** — What broke / almost broke?
   - **field-mapping** — Where does a value come from / go to?
   - **code-pattern** — What would I flag in code review?
   - **process** — What end-to-end flow did I touch?
3. For each finding, append a JSON line to `<business-repo>/experiences.jsonl` per the schema in the skill.
4. Check promotion thresholds in `references/promotion-thresholds.md`. If any topic crossed a threshold, propose the promotion (or auto-create the draft for clear-cut knowledge entries).
5. Emit the canonical marker as the last line of your message:

   ```
   EC-SCAN executed: N findings
   ```

Where `N` is the number of JSONL lines you appended. Zero is valid.

## What counts as "the current turn"

The turn from the user's last message to right now. If multiple corrections happened in a long turn, capture each as its own finding.

## What this command does *not* do

- Does not edit `rules/` or `skills/` directly. Promotions go to `_draft/`.
- Does not invent findings. Zero findings is fine.
- Does not summarize the conversation. The seven perspectives are sharper than a summary.

## When to run

- Stop-hook will run it automatically at end-of-turn for any turn that touched code.
- Run it explicitly mid-conversation when you notice something worth capturing immediately, especially after a sharp correction or a "I didn't know that" moment.
- Run it once after a long debugging session even if no code changed — debugging itself yields knowledge findings.
