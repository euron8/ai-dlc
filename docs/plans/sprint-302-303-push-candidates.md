# EXECUTE THIS — the graph consumer's sprint 302/303 push candidates, adjudicated and remediated

Six entries from the reference consumer's push-candidate ledger, each re-verified against
this repository rather than against its CHANGELOG. Four hold and ship as one release; two
were already fixed upstream and need only a report back.

## Start here

**Repos and the boundary.** Work in `/Users/n8/git/ai-dlc` (the distribution). The
consumer `/Users/n8/git/graph` is READ-ONLY for the whole of this program — read it to
derive a figure, **do not write it**, do not commit in it, do not push from it. Its
push-candidate ledger is the consumer's own record and is not ours to annotate. The
channel it reads on its next reconcile is this repo's `CHANGELOG.md`, which closes an
entry by naming its `PC-` id verbatim — the consumer's `NAMED-UPSTREAM` signal. That
citation is a required part of the release, not a courtesy.

**PING THE OPERATOR on any question, on any decision this file does not already make, and
on completion — including an early stop.** From outside, a session that is thinking and a
session that is waiting on a human look identical.

**Every figure here was derived against the working tree during the adjudication pass, at
distribution `f90e9e7` (v0.366.0) and consumer HEAD `acf3c2b37`, each with a control in
the same invocation.** They are hypotheses again the moment the tree moves. Re-derive
before acting on one.

**Go to the numbered action list.** Everything above it is evidence for why those actions
are the actions.

## Context

The graph consumer files defects it finds in the distribution into
`_bmad-output/ai-dlc-update/push-candidate-ledger.md`. The operator asked for the entries
filed during graph sprints **302 and 303** to be evaluated thoroughly, and for the valid
ones to be remediated here.

Every entry in that ledger is a HYPOTHESIS about a tree that has moved since it was
written. The ledger's own preamble measures the base rate of expired premises as high, and
this pass confirms it: **two of the six were already fixed upstream**, one of them on the
same day it was filed.

## The set, and how it was bounded

`PC-S302-*` and `PC-S303-*` ids across the live ledger and its archive.

- **Archive (7 ids, filed 2026-08-06..11): all `ADOPTED UPSTREAM` already.** No work.
- **Live ledger: 6 entries, filed 2026-08-07 .. 2026-08-13.** These are the subject.
- Two further ids carrying an `S302`/`S303` prefix were filed 2026-07-25/26 under the
  consumer's older numbering; both are closed (one `CLOSED AS REFUTED`). Out of scope.

Control on the "already fixed" claim: `CHANGELOG.md` carries **65** `PC-S` citations and
**zero** in the 0.361.0–0.366.0 band, so no live entry was absorbed in the six releases
since filing. The two closures below are older than the filings, not newer.

## Verdicts

| # | Entry | Verdict |
|---|---|---|
| 1 | `PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1` | **ALREADY FIXED** — v0.303.0, refined v0.314.0 |
| 2 | `PC-S302-RETIRED-LAYER-CONTRACT-READS-CLEAN-OVER-TWO-REAL-POSITIVES` | **ALREADY FIXED** — v0.359.0 + v0.360.0 |
| 3 | `PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD` | **HOLDS** — R1 |
| 4 | `PC-S302-AUDIT-LAYER-DEBT-SILENTLY-IGNORES-A-STRING-CLOSES-OWED` | **HOLDS** — R2 |
| 5 | `PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND-THAT-RESOLVES-TO-NOTHING` | **HOLDS**; its prescribed fix is broken — R3 |
| 6 | `PC-S302-FIXTURE-SUITE-POOL-...-EVIDENCE-IS-DELETED-WITH-THE-TEMP-DIR` | **HOLDS, and is worse than filed** — R4 |

### 1 — already fixed, and its receipt lies

v0.303.0 (`9799ad5`, PR #418) split step 7 per script; v0.314.0 de-listed the hard-coded
clause names. `SKILL.md` now says `unregistered-drift.sh` takes `theirs` and
`layer-drift.sh` takes the pull's base — exactly the remedy the entry proposed. The safety
net is `DRIFT-RANGE-DEGENERATE` at
`core/skills/ai-dlc-update/reconcile/layer-drift.sh:331`, fixture-asserted in
`core/fixtures/layer-adjudication-tier/run.sh:303`.

**The entry's own machine receipt reports a FALSE STILL-LIVE.** Its receipt is
`theirs_has core/skills/ai-dlc-update/SKILL.md "not the pull's base"`. That token occurs
exactly once at HEAD, inside the sentence *repudiating* the old wording. The fix quoted
the string it deleted, so a `theirs_has` receipt on it can never go quiet. This is the
mirror of the false-CLOSE hazard the ledger preamble already names, and it is worth
reporting back on its own: an entry can be anchored on a string a correct fix preserves.

### 2 — already fixed, and the consumer has already pulled it

v0.359.0 (`700031e`) qualified the empty-retired-set zero: `retired-layer-contract.sh` now
emits a NOTE naming both counts and stating "NO layer file was opened". v0.360.0
(`9bf63da`) closed the exclusion with a new sibling detector,
`core/skills/ai-dlc-update/reconcile/retired-layer-passage.sh`, plus
`core/fixtures/retired-layer-passage/`. The 0.360.0 CHANGELOG describes this entry's two
positives in almost its own words.

The consumer's last pull was **0.357.0 → 0.360.0 on 2026-08-12** — it already has both.
Nothing to ship; it needs to close the entry.

## R1 — `hard-blockers.sh` hands one base to two detectors that need different ones

`core/skills/ai-dlc-update/reconcile/hard-blockers.sh:38` takes one `BASE` and passes the
same variable to `unregistered-drift.sh` (`:47`) and `layer-drift.sh` (`:49`). Post-apply
there is no value that is right for both, and SKILL.md step 7 says so — for the scripts
run *directly*. The wrapper that runs *both* was left behind.

The sharpest part: `collect()`'s `$1 ~ /^HARD-/` filter discards `DRIFT-RANGE-DEGENERATE`,
which was deliberately given a non-`HARD-` prefix. So the wrapper is the one caller
structurally blind to the row built as the safety net for defect 1, and it prints an
unqualified `0 HARD blockers.` on a disarmed run.

`core/skills/ai-dlc-update/reconcile/layer-drift.sh:312` derives its false-positive set as
EMPTY on the premise that "every programmatic caller passes the pull's base — `apply.sh`,
`emit-report.sh`, `hard-blockers.sh`". That premise is load-bearing and unenforced.

**Fix, in two parts:**

- Add `--post-apply` (no arity change). It encodes the rule rather than asking the caller
  to remember it: `unregistered-drift.sh` gets `THEIRS` as its base, `layer-drift.sh`
  keeps the pull's base. Pre-apply behaviour is untouched, so the six existing fixture
  invocations and `core/skills/ai-dlc-update/reconcile/emit-report.sh:219` are unaffected.
- Surface `DRIFT-RANGE-DEGENERATE` so `0 HARD blockers.` can never stand alone on a run
  where an arm was structurally unable to fire. Do **not** widen the `^HARD-` filter — the
  prefix is scoped away from that vocabulary on purpose. Read the row separately and print
  it as a qualifier.

Also in this release, because they are the same subject and the same files:

- `core/skills/ai-dlc-update/reconcile/emit-report.sh:29` restates hard-blockers' calling
  contract in a comment; keep it accurate or it becomes a false claim in a file nothing
  joins.
- SKILL.md numbers **two different steps `3a-iv`** (`:451` retired-layer-passage, `:468`
  retired-fixtures). The v0.360.0 insertion did not renumber the follower, and the 0.360.0
  CHANGELOG calls the new detector "step 3a-iv". This is a collision in the shipped
  instruction an operator follows. Found during verification; not in the ledger.

**Verification.** New arms in `core/fixtures/reconcile-blocking-list/` (ships; already has
a SANITY arm and a `--check` battery at `core/fixtures/reconcile-blocking-list/run.sh:23`).
Both directions: a post-apply tree where the single-base call emits the spurious
`HARD-UNREGISTERED-CORE-DRIFT` and `--post-apply` does not, and a degenerate-range run
where the qualifier appears. Seed the probe under `mktemp`, never the real corpus. Prove
the arm can fail before trusting its silence.

## R2 — `audit-layer-debt.sh` iterates a string character by character

`core/scripts/audit-layer-debt.sh:105` reads the two halves of the debt contract with
different rigour — `owed` is `isinstance`-guarded, `closes_owed` is not:

```
105        o = r.get("owed")
106        if isinstance(o, dict) and o.get("id"):
...
111        for cid in r.get("closes_owed") or []:
112            closed.add(cid)
```

`closes_owed` is `{"type": "array"}` at
`core/schemas/layer-adjudication-register.json:78`, but a bare string is still valid JSON.
Reproduced against that exact expression: the string form yields a 16-element set of
single characters and matches nothing; the array form matches. The debt silently stays
OPEN — no error, no warning, no row.

The direction matters: the schema's `^OWED-` pattern means a single character can never be
a real id, so this is a **false OPEN, never a false close**. A reporting defect, not a
silent discharge. It still punishes the honest operator who records the close exactly as
much as the one who forgets.

**Correction to the ledger's own claim.** The entry says nothing validates the register on
the pull path and names two validators that do not read it — both true. But
`core/skills/ai-dlc-update/reconcile/layer-drift.sh:456` and `:622` **are** live readers of
the register on that path, and neither schema-validates either. The entry undersells its
own scope.

**Fix:** normalize a `str` to `[str]`, and count a non-list `closes_owed` into the file's
existing `malformed` accounting so it is reported rather than silently repaired. Not a
schema validator: there is no JSON-schema helper anywhere in `core/` — every consumer
hand-parses — so that route is net-new machinery plus a runtime dependency, and KISS says
take the reshaped form.

**Verification.** `core/fixtures/layer-debt-ledger/run.sh` cannot currently see this: its
`row()` helper builds the field with `json.loads(closes)` at
`core/fixtures/layer-debt-ledger/run.sh:45`, so it can only ever emit a well-formed array.
Add an arm that writes the string form as a raw line, bypassing `row()`, and bump
`EXPECTED_ASSERTIONS` at `core/fixtures/layer-debt-ledger/run.sh:33` — the file already
asserts its own assertion count at `core/fixtures/layer-debt-ledger/run.sh:150`.

## R3 — the effort binding commands a slash command that resolves to nothing

`core/hooks/ai-dlc-dispatch-guard.sh:354` builds an imperative to run `/effort <level>` as
the teammate's FIRST action, appended at `core/hooks/ai-dlc-dispatch-guard.sh:399`.

**No `/effort` exists.** Zero definitions in this repo (control: three `SKILL.md` files
found, `core/skills/` lists three skills; no `commands/` directory anywhere). Zero in the
operator's home (control: the same search finds the caveman files). The guard's
correctness rests on an assumption no file states or checks. The tree already reasons this
way about the invalid case — `core/fixtures/dispatch-model-guard/run.sh:219` says
injecting an unrecognised level "would instruct a teammate to run a slash command that
does not exist" — it simply assumes the *valid* levels resolve to something.

`effort_bound` at `core/hooks/ai-dlc-dispatch-guard.sh:326` records what the guard
APPENDED; **nothing reads it** (two hits tree-wide: that line and a CHANGELOG sentence).
Check 22's enforcer, `core/scripts/validate-spawn-ledger.sh`, does not reference it.

**The entry's prescribed fix is broken, and this is the substantive correction.** It says
a declarative rewrite "leaves the dedupe check unchanged". It does not. The dedupe at
`core/hooks/ai-dlc-dispatch-guard.sh:356` matches the literal substring `/effort <level>`
in the incoming prompt; a declarative line contains no such substring, so `NEEDS_EFFORT`
stays true forever and the guard emits a decision on **every** dispatch — precisely the
posture change the comment at `core/hooks/ai-dlc-dispatch-guard.sh:346` exists to prevent.

**Fix:** make the line declarative (state the configured effort as a fact) **and** move
the dedupe to key on the new line's stable prefix, in the same change. Update the reason
string at `core/hooks/ai-dlc-dispatch-guard.sh:406` and the header comment at
`core/hooks/ai-dlc-dispatch-guard.sh:85`, which still describe an appended directive.

**Verification.** `core/fixtures/dispatch-model-guard/run.sh` is coupled at three points
and one of them pins the literal: the extractor regex at
`core/fixtures/dispatch-model-guard/run.sh:65` and `:86`, and the idempotence arm at
`core/fixtures/dispatch-model-guard/run.sh:228` which hard-codes the full sentence. That
arm is the mechanical proof of the coupling — it goes red if the line moves without the
dedupe. Update all three; keep the role-file staleness arm at
`core/fixtures/dispatch-model-guard/run.sh:244`.

## R4 — the pre-push pool discards a red unit's evidence at the point of production

Filed as "the evidence is deleted with the temp dir". **It is worse than that.** The
worker at `.githooks/pre-push:452` (and `core/git-hooks/pre-push:516`) runs:

```
if bash "$d/run.sh" >/dev/null 2>&1; then printf ok   > "$AI_DLC_FX_OUT/$b"
```

Stdout *and* stderr go to `/dev/null` inside the worker. The per-fixture file holds four
bytes. There is nothing for the `rm -rf` at `.githooks/pre-push:509` to destroy, because
nothing was ever written. `$out/.order` — which would answer "what was it scheduled
beside" — does die with the temp dir. There is no `trap` in either hook (control: the only
two `trap` hits are the word "bootstrap" inside comments), so the removal is straight-line.

The `BLOCKED` line at `.githooks/pre-push:654` names no path and offers `--no-verify` as
its only remedy, which is exactly the indistinguishability the entry names.

**This repo is the evidence for the ask.** The `apply-drift-refile` intermittent has
survived at least three release cycles of hypothesis-and-refutation — the broken-pipe
hypothesis was refuted by 140 executions; the 0.31x-band CHANGELOG records "Tested, it
does not carry the explanation" and "§9 stays open"; and the v0.283.0-era measurement
records four different fixtures each going red once and green on every standalone re-run.
Every one of those investigations had to re-run the fixture out of band, because the gate
that observed the failure preserved nothing.

**Fix:** redirect each worker's output to `$AI_DLC_FX_OUT/.log/$b` — mirroring the
existing per-worker `.dur/$b` pattern at `.githooks/pre-push:454` — and copy only the RED
units' captures to a durable `.git/ai-dlc-*` path immediately beside the existing durations
publish at `.githooks/pre-push:499`, which already runs unconditionally on rc, nine lines
before the `rm -rf`. Name that path from inside `run_fixtures`, next to the `FAIL <name>`
at `.githooks/pre-push:469`.

**Two constraints that decide the design:**

- **I66** (`scripts/validate-enforcement-map.sh:3528`) binds every non-comment, non-blank
  line between the `FIXTURE_POOL_BEGIN/END` sentinels across both hooks, byte-for-byte,
  with one permitted transform: `core/fixtures/` → `tests/fixtures/`. So the change lands
  in both copies, and the durable path must not contain the string `core/fixtures/` or the
  mapping at `scripts/validate-enforcement-map.sh:3580` will silently rewrite it.
  `.git/ai-dlc-fixture-failures` maps to itself. Comments may and should differ per
  audience.
- **The `BLOCKED` line is OUTSIDE the pool block** (`.githooks/pre-push:654`,
  `core/git-hooks/pre-push:603`) and is bound by nothing. Naming the path there means two
  hand-edited copies with no invariant catching a divergence. Name it inside the block
  instead, where I66 protects it.

`install.sh` marks the consumer hook "always overwrite — upstream-owned", so a
consumer-side fix is impossible; this must land here.

**Verification, and it is not optional.** This changes the runner that gates every push,
and `CLAUDE.md` is explicit that a change the pole invokes is a change to the suite's wall
clock. Time the full suite before and after, **from inside the repo** — a copy run from
`/tmp` resolves its root elsewhere and exits in milliseconds, which reads as an enormous
speed-up and is a broken measurement. Watch the top of `.git/ai-dlc-fixture-durations`,
not the total: the suite is pole-bound. Add arms to `core/fixtures/consumer-suite-pool/`,
already the mutation-testing home for this runner.

## Sequencing — ONE release, v0.367.0

All four remediations ship as **v0.367.0** on a single branch cut from `origin/main`
(`main` was clean and level with it at `f90e9e7` when this was written). One version per
branch: a squash of two takes the first version in the subject and breaks the release
triple.

Commit subject, `VERSION` and the `CHANGELOG` heading are one claim. The `CHANGELOG`
release carries **four sections, one per remediation, each naming its `PC-` id verbatim** —
that citation is the consumer's `NAMED-UPSTREAM` close signal and all four ids must appear.

Build order inside the branch: **R4 first**, so the pool change is in the tree for every
subsequent gate run on this branch and any wall-clock cost surfaces early rather than at
the final push. Then R1, R2, R3.

## The numbered action list

1. Cut `feat/sprint-302-303-push-candidates` from `origin/main`.
2. **R4** — the pool capture, in both pre-push hooks, plus the `consumer-suite-pool` arms.
   Take a full-suite wall-clock reading from inside the repo before and after; record both
   in the CHANGELOG. If the pole moves materially, reshape before continuing rather than
   carrying the cost into the release, and ping the operator with the two numbers.
3. **R1** — `hard-blockers.sh` `--post-apply` and the degenerate-row qualifier, the
   `emit-report.sh` contract comment, the SKILL.md `3a-iv` renumber, and the
   `reconcile-blocking-list` arms.
4. **R2** — the `closes_owed` normalization with malformed accounting, and the
   `layer-debt-ledger` string-form arm.
5. **R3** — the declarative effort line and its dedupe, moved together, plus all three
   `dispatch-model-guard` coupling points.
6. `VERSION` → `0.367.0`, one `CHANGELOG` release with four sections, each naming its
   `PC-` id verbatim. Commit subject carries the same version.
7. Run the gate as the gate runs it: `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`,
   reading each new fixture by NAME in the full output.
8. Verify R1 and R4 on a tree built by running `scripts/install.sh` into an empty
   directory, in both layouts.
9. Merge it. Merges are preapproved — do not stop to ask.
10. Report back to the operator: the four fixes, the two entries already closed upstream,
    the false-STILL-LIVE receipt on entry 1, the two ledger claims this pass corrected, and
    anything in this file that did not survive contact with the tree. **Report-back is the
    only deliverable for the two closed entries** — no `docs/reviews/` file, no consumer
    write. The consumer closes its own ledger off the CHANGELOG.

## Verification of the whole program

- Every new arm carries a self-probe that runs BEFORE the corpus, fired in both
  directions: it reports a seeded offender and stays quiet on a seeded near-miss. Probe
  trees under `mktemp`, never the real corpus.
- A green banner from `core/git-hooks/pre-push` or from the content-key skip is not
  evidence that a change was exercised. Read the fixture by NAME.
- R1 and R4 both touch machinery a consumer runs, so the installed-tree check in action 8
  is where they are actually proven.

## Out of scope, recorded

- `PC-S314-NO-DETECTOR-CLAIMS-A-LAYER-FILE-CITING-A-PATH-THE-PULL-JUST-RETIRED` still
  holds at HEAD — no detector treats a retired PATH in a layer file as a retired shape.
  Filed under S314, outside the sprint 302/303 scope the operator set.
- `PC-S330` remains open and untouched, as the prior program directed.
