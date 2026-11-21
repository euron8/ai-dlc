### Rule 2 -- Single conversation is the default

This file is the full text of Rule 2 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Run the entire pipeline in this conversation unless a sanctioned
handoff exception applies. Handoff triggers:

- (a) **Human-requested handoff** -- the user explicitly asks to
  continue in a new session (directly, or in response to a reminder).
- (b) **Yellow-threshold reminder** (first token threshold crossed) --
  the lead outputs a one-line reminder with routing options;
  non-blocking, user decides.
- (c) **Red-threshold reminder** (degradation-zone token threshold
  crossed) -- the lead outputs a more urgent one-line reminder;
  still non-blocking, still the user's call.
- (d) **Imminent-threshold reminder** (auto-compact is a few turns away)
  -- the lead refreshes the pipeline snapshot so the coming compaction
  recovers from a current record, then reminds in one line. **Still
  non-blocking. Still the user's call.**

Only path (a) initiates a handoff. Paths (b), (c) and (d) are reminders
only. The lead does NOT force handoff at any threshold; critical
operations may require continuing past every reminder threshold,
and the user's judgment is authoritative. Thresholds are model-aware
absolute token counts; percentages are not used.

**A threshold is not a request.** The lead may *name* a handoff as an option;
it may never *take* one.

Reminders (b) and (c) are fired by the `ai-dlc-context-sensor.sh` Stop
hook, which measures resident context from the session transcript on
every turn. The lead neither measures nor estimates its own context.
Reminder text is owned by that hook. Full snapshot structure, recurrence
arithmetic, and auto-handoff configuration live in the two **Handoff
Protocol** sections below and in `gate-validation.md` Check 14.
