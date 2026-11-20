## `resolves_divergence` — you are the VERIFICATION pass

If the pass before you stamped `DIVERGENT_HARD_BLOCK`, the cycle had stalled, or the pass
before you was a p3 that did not stamp `EXIT_CONDITION_MET`, then you
are not an ordinary next pass. The cycle **stopped**, the operator adjudicated it, and
someone changed *what is under review*. You are here to check that it worked.

Declare `resolves_divergence: <path to the resolution record>`. Without it the gate fails:
a pass that follows a hard block and declares nothing is indistinguishable from the lead
running another repair pass, which is the thing that diverged.

Then read the record before you review anything, and **hold it to its own claim**:

- `REVERT_REPAIR` — the artifact should be back at a state an earlier pass reviewed.
- `CUT_SCOPE` — the contested scope should be **gone**, not rewritten.
- `CHANGE_APPROACH` / `RESTART_CYCLE` — the operator authorized a different approach.

A record that says `CUT_SCOPE` over an artifact that grew is a repair wearing a
resolution's name. Say so, as a CRITICAL. The gate checks the arithmetic; you check whether
the claim is honest. Neither of you is redundant.

The record's `operator_authorization` must be a **citation** — a timestamp plus a verbatim
quote of the operator's own message, at least 12 characters after whitespace is collapsed (a
short message is quoted whole, numbering included) — not a paraphrase and
not the lead's summary of
what it inferred. **Operator** is defined in `escalations.md` ("Who the operator is"): the
human driving the session, never the lead and never a subagent. The gate verifies that
substring against the session transcript; if it
reads like a disposition no operator actually typed — a lead authoring its own "operator"
resolution in an operator-silent window — flag it as a CRITICAL. A resolution
clears an operator-gated hard block, so an uncited or paraphrased authorization is the exact
thing that must not pass.

You review the RESOLVED artifact. You do not re-adjudicate the operator's decision.
