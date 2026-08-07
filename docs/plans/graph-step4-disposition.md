# PR #872 disposition, and step 4 — EXECUTE THIS

## Start here

**You are working in `/Users/n8/git/graph`.** This file lives in the ai-dlc distribution: read
`/Users/n8/git/ai-dlc`, and do not write to it.

**Disposition of PR #872: the finding is CORRECT, it is fixed upstream in v0.290.0, and step 4
is NOT blocked. It never was.** Refusing to burn the set to zero was the right call and it
prevented a real deletion. But the premise underneath both of us — that the 13 rows gate
anything — is false, and that is my error, not yours.

**`EXTENSION-TITLE-MATCHES-CORE` cannot block. Proven, not asserted:**

```
LC-E19                          level: WARN
hard-blockers.sh:48             awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
  fed EXTENSION-TITLE-MATCHES-CORE, HARD-OVERRIDE-DRIFT-SECTION, EXTENSION-OK
  -> selects HARD-OVERRIDE-DRIFT-SECTION only        (control: a HARD- row IS selected)
audit-layer-debt.sh             REPORT-ONLY, exit 0 on findings
```

The status has no `HARD-` prefix, and the blocking list is a prefix match. **The 13 rows are a
triage queue, not a gate.** Nothing in the pipeline, the pull, or s302 waits on them.

**What v0.290.0 changed.** The row's remedy text told you to declare `extends:` and promised the
row would stop firing. The suppression that would have honoured it was deliberately removed
upstream — the comment ten lines above the emit says so and names
`retro-push-sprint-ship-verification` as the true finding it had been hiding. The reasoning was
right; the remedy text was never updated. It now says what actually clears a row, and that
`extends:` is still worth declaring for the drift-narrowing it genuinely does.


**PING THE OPERATOR — on any question, on any decision, and when this plan completes.** The
operator cannot see this session. From outside, "still working" and "stopped, waiting on you"
look identical, so silence is not a neutral state: it is a stall the operator can only find by
polling. Say something when you need a decision, when you hit a premise that does not hold, and
when you are done — including when "done" means you stopped early. **This instruction is carried
forward into every plan in this repo and is enforced by `scripts/validate-plan-shape.sh`; a new
plan that omits it fails the build.**

## Next actions

1. **Unblock step 4 and mark PR #872 as dispositioned upstream** — fixed in ai-dlc v0.290.0, no
   consumer change required by it.
2. Run §*Step A — pull to current `main`*.
3. Run §*Step B — work the 13 as a queue*, at whatever pace suits. **It gates nothing.**
4. Confirm §*Done when*.
5. **Do not start s302.** Item 10 of the parent plan still has to land and be pulled.

## Step A — pull to current `main`

**A HELD 0.291.0 SELF-UPDATE BRANCH MUST BE DISCARDED, NOT LANDED.** If the previous attempt
left one, delete it and re-run. v0.291.0 shipped a fixture whose seed resolved only the
DISTRIBUTION layout, so on a consumer it died in its seed and blocked the push. Landing 0.291.0
puts that broken fixture in your tree and needs a second pull to clear it; re-running goes
straight to a `main` where **v0.292.0 has already fixed it**, and the covering fixture is green
on arrival. Verified upstream against a consumer built by running `install.sh`, not simulated.

**Do not file a push-candidate for it.** Already closed upstream as v0.292.0.

Releases in this slice, whatever `main` is when you run it:

- **v0.289.0** — three snapshot fixtures inherited ambient `AI_DLC_*` from `settings.json` and
  tested the CONFIG instead of the CODE. **This is what lets you keep
  `AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid` with no `--no-verify` and no local fixture edits.**
- **v0.290.0** — the LC-E19 remedy correction.
- **v0.291.0** — the row now publishes `subject_digest`, which is what makes Step B executable
  at all, and a recorded verdict silences it until the entry or the core section moves.
- **v0.292.0** — the seed-layout fix above.

**This is an ordinary single hop, not another two-hop split.** The split was needed because the
`0.274.0` engine had to be replaced before it classified; you are past that.

```
/ai-dlc-update apply
```

Then confirm the three fixtures pass with your `forbid` key still set.

## Step B — work the 13 as a queue

Per entry, read the body against core's section and pick one:

- **Body DUPLICATES core's section** → retire it per Rule 27(b). An absorbed-but-kept entry
  starts as an exact copy and diverges from there.
- **Body AUGMENTS core's section** → record a `still-additive` verdict in
  `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`. Required fields: `clause`
  (`LC-E19`), `entry`, `subject_digest` (**copied verbatim from the row**), `verdict`,
  `recorded_utc`, `reason`. The verdict enum is `still-additive | contradicts-core | retire`.
  Optionally also declare `extends:` — it narrows the drift subject to that span, which is a
  real benefit, and it is not what clears the row.

**Do not retire an entry that states its own additivity.** That was the trap in the old remedy
text and you were right to stop at it.

`retro-push-sprint-ship-verification` is worth doing first: the upstream comment names it as the
case where core absorbed the section wholesale, so it is the most likely genuine retirement in
the set — but read the body and decide, do not take that as the verdict.

## Done when

```
graph stamp                                    whatever `main` was at pull time (>= 0.292.0)
inflight-row-shape, snapshot-supersession-marker, snapshot-section-schema
  with AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid    all green, no --no-verify
PR #872                                        closed as dispositioned upstream
step 4                                         unblocked and proceeding
the 13 rows                                    a queue with progress, NOT required to be zero
```

## What I still owe you

**Your step-7 finding is recorded as plan item 13 and credited to you, not restated as mine.**
The mechanism is plausible on its face — `layer-drift.sh:1296` keys on `${BASE}..${THEIRS}`, so a
base equal to theirs compares a range to itself — but I have not reproduced it here, and a gate
that prints zero is exactly the shape this repo keeps shipping. I will reproduce it against a
scratch consumer before writing a fix, because one aimed at the wrong layer would leave it.
