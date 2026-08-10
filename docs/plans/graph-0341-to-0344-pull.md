# SPENT — pull graph from `0.341.0` to `0.345.0`. IT RAN, IT MERGED. DO NOT EXECUTE THIS.

**DISCHARGED 2026-08-10.** Graph's #907 (machinery self-update) and #908 (gated reconcile) are on
their main and the pull is complete. **Verified from this side rather than accepted**: all four
stamp fields read `0.345.0 / 959caa8`, and 11 of 11 shipped files are byte-identical to the
distribution (control: an unrelated pair reports DIFF). Both new fixtures were driven against their
own installed copies and both `PASS`. Gate verdict on the run: `SELF-UPDATE-OK`.

**The executing session refused to retitle this file because it is read-only to them, which is
exactly right** — a discharged runbook is the upstream's to discharge, and one still titled EXECUTE
THIS is how a later session redoes a landed pull. Kept below as the record.

**THE ONE THING THIS FILE GOT WRONG, and it is a refinement of the rule it was written under.**
Done-when 5 asked that `ledger-reverify` move a receipt to `CLOSE-CANDIDATE`. That was checked
reachable before the file shipped — the token it anchors on goes 0 → 8 across the range — but the
criterion is only OBSERVABLE in a window the run itself closes: step 8 closes and rotates the
entry, and a rotated entry emits no row, so the live ledger correctly reads **0** afterwards. The
executor materialized the pre-close ledger from its own commit and read `CLOSE-CANDIDATE` there,
which is the right answer to a question this file asked at the wrong moment. **A done-when must be
reachable AT THE MOMENT IT IS CHECKED, not merely reachable** — state the observation point when
the run consumes its own subject.

**AND ONE CORRECTION THE RUN PRODUCED, in this file's favour.** The `adj_prefix` receipt token
landed in `layer-drift.sh` (0 → 5), not in `apply.sh` (0 at both refs), where the ledger entry's own
prose sited the defect. This file named the right path and the entry's analysis did not.

Original text follows, unedited.

**You are a session running in `/Users/n8/git/graph`.** Everything below is yours to do there.
This file lives in the distribution (`/Users/n8/git/ai-dlc`) and is **read-only to you**; do not
edit it, and do not edit anything else under that repo.

## Start here

**Repos and the boundary.** Work in `/Users/n8/git/graph` (the consumer). Read
`/Users/n8/git/ai-dlc` (the distribution) if you need to see what is incoming; write nothing
there. Every command below runs in the consumer unless it says otherwise.

**PING THE OPERATOR on any question, on any decision this file does not already make, and on
completion — including an early stop.** From outside, a session that is thinking and a session
that is waiting on you look identical, and every stall in this program's history ended with the
operator asking rather than the session reporting, including one that had already finished. If
you stop, say so and say why.

**EVERY FIGURE HERE IS A DATED MEASUREMENT, taken 2026-08-09 against `899411a` and `0e812a7`.**
Where a paragraph names a command, that command is the evidence and the number beside it is a
reading. Re-derive before acting on one.

**THE FILENAME SAYS `0344` AND THE RANGE NOW ENDS AT `0.345.0`. It is not renamed per
release** — a renamed handoff breaks every link to it mid-run, and the title and the status table
are the record. Read the range from the table, never from the filename.

**This runbook is SPENT once the pull merges.** Say so in its own title when it is; a discharged
runbook still titled EXECUTE THIS is how a later session redoes a landed pull.

## Current status — one record, and it is the only one in this file

| | |
|---|---|
| graph, all four stamp fields | `0.341.0 / 899411a`, re-read 2026-08-09 |
| distribution `VERSION` / HEAD | `0.345.0` / `0e812a7` |
| releases in range | v0.342.0 (#502), v0.343.0 (#503), v0.344.0 (#505), v0.345.0 (#508) |
| shipped files in range | **11**, derived; 13 under `core/` minus the 2 in a `.dist-only` dir |
| non-`core/` control | 7 (`VERSION`, `CHANGELOG.md`, `docs/plans/` files, `scripts/uninstall.sh`, `scripts/validate-enforcement-map.sh` — none shipped) |
| rulebook files in range | **0** |
| `contract_version` | **18 → 18**; `layer-contract.yaml` is not in the range at all |
| graph's pause flag | **PRESENT**, and the snapshot exists — see action 0 |

Read the stamp yourself rather than trusting the first row:

```
sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version
```

All four fields must agree. If they do not, a pull is mid-flight and the DIRECTION of the split
is the signal — skill fields BEHIND is a correctly-empty machinery slice, skill fields AHEAD is a
half-landed pull whose reconcile hop has not run.

**THE RANGE IS MACHINERY-ONLY, MEASURED.** Classified against `reconcile/setup-sites.md`'s own
`machinery:` list rather than by eye: 6 machinery files (`core/hooks/ai-dlc-acknowledge.sh`, the
four `reconcile/` files, `core/skills/ai-dlc/core-manifest.md`) and 5 fixtures, each of which
names one of the machinery paths this diff actually touched. Zero rulebook files — control: the
same classifier returns RULEBOOK for `steps/route.md`, `skills/ai-dlc/SKILL.md` and
`team-roles/adversary.md`.

**DO NOT PREDICT THE HOP COUNT FROM THAT.** This program has predicted hop counts from the
distribution side three times and been wrong three times, in both directions. The composition is
an input to the gate, not a substitute for it: run `reconcile/self-update-gate.sh` and read what
it says.

## IF YOU ARE RESUMING MID-RUN — read this before anything else

**You reported that `apply-drift-after-write/seed.sh` resolves its schema only in the
distribution layout and hard-fails on every consumer. You were right, it was reproduced here on
a tree built by running `install.sh` into an empty directory, and it is fixed upstream as
v0.345.0.**

**None of the three options you listed is the one to take**, and the reason is that all three
assumed upstream was fixed in place. It is not:

- **Do not patch your copy of `seed.sh`.** It is an upstream-owned file; the patch is drift
  reported on every pull until absorbed, and the absorption already happened.
- **Do not hold the fixture at `0.341.0`.** That trades one line of drift for two whole files
  and stops the fixture asserting the `apply.sh` behaviour this very range changed.
- **Do not stop the pull.** Stopping leaves you on the pre-fix acknowledge hook, which is the
  defect this whole pull exists to replace.

**Take the range to `0.345.0` instead.** Re-derive against the new HEAD and re-run; the shipped
set is unchanged at 11 files, because `seed.sh` was already in the range and its fix moves the
same file. `scripts/validate-enforcement-map.sh` also changed and is NOT shipped to you.

**Two things worth carrying back, because they are the reason your report was worth filing.** The
fixture was one file and not a class — all 122 shipped fixtures were run in the consumer layout
and 119 were green, the one red being yours. And the two invariants that exist to catch exactly
this both returned zero: I33 wants the `dirname` and the walk in one expression, I33b wants a
variable in between, and this form normalises through `cd`/`pwd`. **I33c now checks the half
neither did** — that a self-rooted walk names BOTH layouts, not merely that it is self-rooted.

## The numbered action list

**0. CLEAR THE PAUSE FIRST, OR THIS RUN DENIES ITSELF ON ITS FIRST DISPATCH. This is not a
precaution; it is the measured state of your tree.**

`_bmad-output/pipeline-paused.flag` exists on graph right now, and so does
`_bmad-output/pipeline-snapshot.md` — the two preconditions for the Rule 29 deny. Your INSTALLED
`.claude/hooks/ai-dlc-acknowledge.sh` is byte-identical to the distribution's `0.341.0` copy, and
that copy detects an `/ai-dlc-update` session **only** by a transcript marker the harness writes
when a human TYPES the slash command. When the agent invokes the skill through the `Skill` tool
the marker is never written, so the carve-out cannot fire. Measured by driving your own installed
hook against a scratch tree (nothing was written to graph): the agent-driven dispatch is DENIED,
and so is every `Agent` call after it.

**This is the last pull for which that is true — v0.344.0 is the fix, and it cannot help the run
that carries it.**

So, in order:

- Read the operator message the flag stands for. If one is genuinely outstanding, deal with it
  and stop here; the pull is not urgent enough to talk over a human.
- If the flag is residue from a handoff — which is the usual case, and the reason the carve-out
  exists at all — `rm -f _bmad-output/pipeline-paused.flag`, then proceed. Bash is allowed while
  paused precisely so this is always possible.
- If you are denied anyway, that is the reported defect and not a new one. The sanctioned move is
  the same `rm -f`; do not disable a hook, and do not write a marker file.

**1. Run the dry run.** `/ai-dlc-update` with no arguments. Read the report; do not apply yet.

**2. Run the self-update gate and DO WHAT IT SAYS.**
`reconcile/self-update-gate.sh <dist> <base> <theirs> <consumer>`, with `base` the `commit` field
of your stamp. Its DEFER arms fire only when the rulebook is also about to change, and this range
changes no rulebook file — but that is a reason to expect a particular answer, not a reason to
skip the question. **Quote its verdict in your report.**

**One thing it may now say that it could not before.** v0.342.0 taught it `SELF-UPDATE-SAFE-STOP`
against your own `skill_commit`: if your machinery is already at or past the ref it would name, a
split buys nothing and the row says so. That release is IN this range, so the gate you run at the
start is the OLD one; the new behaviour arrives with the pull, not before it.

**3. Apply.** `/ai-dlc-update apply`, then merge as usual. One version per branch does not apply
to you — this is a pull, not a release cut.

**4. Re-run every done-when below AGAINST MERGED MAIN, not against the branch.** The done-whens
are re-run rather than remembered because the adjudication digest covers the entry: editing an
entry after recording its verdict spends that verdict, and a run that looked clean on the branch
can be blocked on main.

**5. The push-candidate ledger — three of your live entries are answered by this range.**

**SPELL THE FULL SLUG. The `PC-S331` prefix names FOUR candidates on your ledger**, one of them
already archived, and a disposition written against the bare prefix is a disposition against the
wrong entry.

| slug | answered by | today's `verify:` |
|---|---|---|
| `PC-S331-SAFE-STOP-IGNORES-THE-CONSUMERS-OWN-SKILL-COMMIT` | v0.342.0 | `theirs_lacks …/self-update-gate.sh "skill_commit"` |
| `PC-S331-APPLY-SH-EXTENSION-REREAD-IGNORES-A-RECORDED-VERDICT` | v0.343.0 | `manual` |
| `PC-S331-ACKNOWLEDGE-HOOK-UPDATER-CARVE-OUT-IS-UNREACHABLE-VIA-THE-SKILL-TOOL` | v0.344.0 | `manual` |

The first is already mechanised and **will flip on its own**: `skill_commit` appears 0 times in
that script at your base and 8 times at `44450ea`, so `ledger-reverify` moves it to
`CLOSE-CANDIDATE` after the pull. Control: a fabricated token returns 0 at both ends.

**The other two are `verify: manual`, and both can be mechanised now that the fix exists** —
which is the thing that was not writable before it did. Both were measured to flip across this
exact range, against the same fabricated-token control:

```
verify: theirs_lacks core/hooks/ai-dlc-acknowledge.sh "tool_input.skill // empty"
verify: theirs_lacks core/skills/ai-dlc-update/reconcile/layer-drift.sh "adj_prefix"
```

The first token is deliberately the jq expression and not the bare field name: the bare name also
appears in a comment, and a `grep -F` over a whole file that a COMMENT satisfies is a receipt that
cannot fail. **Editing a ledger entry is yours, not this repo's** — take it or leave it, but if
you leave them `manual` say so, because a `manual` receipt is one nothing re-verifies.

## What this range carries

- **v0.342.0** — `SELF-UPDATE-SAFE-STOP` recommended a hop your machinery already had. The gate
  now reads your own `skill_commit` before naming a safe-stop ref.
- **v0.343.0** — a recorded verdict cleared the `HARD-` block and `apply.sh` still emitted
  `WORKLIST extension-reread` for the same entry, so a fully-adjudicated run read as a work item
  that could not be closed. Both sides now go through one `adj_prefix` helper.
- **v0.344.0** — the acknowledge hook's updater carve-out, action 0's subject. Three disjoint
  signals now: the `Skill` payload for the dispatch, the serialized tool_use for the fan-out after
  it (`core/hooks/ai-dlc-acknowledge.sh:151`), and the original typed marker, which stays because
  it is the only signal a typed invocation produces. The payload arm is at
  `core/hooks/ai-dlc-acknowledge.sh:161` and is applied AFTER the transcript scan, so an
  `/ai-dlc` resume overrides an updater call earlier in the same session.

## What to expect, and what would be a finding

- **NO new layer warnings.** `contract_version` stays 18 and `layer-contract.yaml` is not in the
  range. Your #906 run reported `0 error(s), 2 warning(s)` (`W6`, `W7`). **If that count moves,
  it is a finding — report it rather than absorbing it.**
- **No new `HARD-LAYER-ADJUDICATION-MISSING` rows are predicted, and that prediction has been
  wrong before**: the last pull predicted one adjudication and produced three, the two extras
  following from a file move. Predicting an adjudication count is the same class of error as
  predicting a hop count. Read what the run says.
- **`WORKLIST extension-reread` on an entry whose verdict is recorded should now be ABSENT.**
  That row was v0.343.0's whole subject. If you still see one, quote it — that is a live defect,
  not noise.
- **One new fixture arrives, `tests/fixtures/updater-session-signals`**, and it must be green on
  your tree. Its `.dist-only` mutation battery does NOT ship to you and must not appear.

## Done-when — every criterion below has been RUN, and both of its outcomes checked

1. **All four stamp fields read `0.345.0 / <the merged sha>`.**
   `sed -n '1,4p' .claude/.ai-dlc-version`. Reachable: the previous pull reached exactly this on
   all four fields through the tool's own subtraction, with no hand edit.

2. **`bash tests/fixtures/updater-session-signals/run.sh` → `PASS`, run from the project root.**
   **This one is a genuine before/after and both arms were run before this file was written.**
   Against the `0.341.0` hook — which is byte-identical to the one installed on graph today — it
   returns `2 assertion(s) FAILED`, and the two are exactly `AGENT DISPATCH` and `AGENT FAN-OUT`.
   Against `0.344.0` it returns `PASS`, verified on a tree built by running `install.sh` into an
   empty directory, so the consumer-layout path resolution is proven and not assumed.
   **Run it BEFORE the apply as well as after** — a criterion you have only seen green cannot tell
   a fix from a no-op.

3. **`bash tests/fixtures/apply-drift-after-write/run.sh` → `PASS` from your project root.**
   This is the one you reported. Checked reachable in both directions: it exits **2** with
   `FIXTURE BROKEN` on the `0.343.0`–`0.344.0` copy in the consumer layout, and `PASS` after
   v0.345.0, verified on a tree built by running `install.sh` into an empty directory. **Run it
   before the apply as well as after** — you have already seen its red, so its green is the half
   still owed.

4. **Your full pre-push suite is green**, driven by the hook rather than by a hand-rolled loop.
   `git push` is the cheapest way to run it. A `for d in tests/fixtures/*/` loop FABRICATES
   failures — several fixtures resolve the project root from the process working directory.

5. **`ledger-reverify` moves `PC-S331-SAFE-STOP-IGNORES-THE-CONSUMERS-OWN-SKILL-COMMIT` to
   `CLOSE-CANDIDATE`.** Run the SHIPPED reader, before the pull as well as after; a predicate you
   have reimplemented in order to measure it is not the predicate. Checked reachable: the token it
   anchors on goes 0 → 8 across this range.

6. **The layer report still reads `0 error(s), 2 warning(s)`** — an expected NO-CHANGE, stated as
   a criterion because a move is the finding. If it moved, report the delta and the row.

## Deliberately out of scope

- **The two open consumer-side migrations**, neither of which this range touches: `docs/qa/sprint-<N>/**`
  is unrepathed (5 `sprint-<N>` directories, 0 slotted), and `docs/reviews/` is partly migrated
  (126 slotted against 9 `sprint-*` directories and 2 files at the old spelling).
- **`pipeline-continuation-log.md` at 326% of its budget.** The remedy is `rotate`, which the
  consolidation step excludes by name-class. Growing, and named here so it is outstanding rather
  than noise.
- **The 48 refused artifact-path migrations** and the `921.`/`20.` retire-or-refile call, both
  unchanged and both yours whenever you choose.
