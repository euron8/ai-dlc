# Drain the graph consumer's push-candidate ledger — full sweep

## Context

`/Users/n8/git/graph` is the reference consumer. Its
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` is the queue of consumer innovations
upstream lacks and consumer-filed upstream defects. Every prior cycle drained **four entries**
and stopped; the ledger has grown faster than it has been drained. The operator has asked for
the whole thing: adjudicate every open entry against ground truth, remediate what is real, and
give graph a legitimate way to close what is not.

**The instrument that would normally answer "what is still open" cannot answer it right now,
and it says so itself.** graph's own reconcile report for the 0.370.0 → 0.372.0 pull carries
this line, and the same run reproduces from this session:

> `RECEIPTS-UNDECIDED  (theirs_has receipts)  28 of 28 'theirs_has' receipt(s) reported
> STILL-LIVE on a substring present at BASE as well as at theirs (0.372.0) … Do not treat a
> zero CLOSE-CANDIDATE count from this run as evidence that nothing was absorbed.`

So the zero-close reading is not a floor, and the 59 `STILL-LIVE` rows are not findings. Every
entry has to be taken to the working tree by hand. The measured base rate of expired premises
in this corpus is roughly **one in two** — expect about half the ledger to be dead.

## Start here

**Two repos, and the boundary is absolute.**

- **`/Users/n8/git/ai-dlc`** — WRITE. This is where remediations, CHANGELOG citations,
  `docs/backlog.md` entries and the adjudication register land.
- **`/Users/n8/git/graph`** — **READ ONLY.** `.claude/rules/consumer-boundary.md` is
  unconditional: an ai-dlc session never writes to a consumer. Do not edit, commit, or push
  there. Record `git -C /Users/n8/git/graph status --porcelain | wc -l` before the first action
  and assert it after every phase; a change is a stop-and-ping condition.

**The only two channels that reach graph** are (a) a released version of `core/` that names the
entry's `PC-` id **verbatim**, and (b) a brief the operator carries into a graph session. Nothing
else.

**THIS FILE SAID THE CITATION GOES IN `CHANGELOG.md` AND THAT IS FALSE.** `named_absorbed()`
(`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402`) resolves the signal with
`git log -F --grep`, which reads **COMMIT MESSAGES**. A `###` section in `CHANGELOG.md` is in the
commit's DIFF, never its message, so it produces no `NAMED-UPSTREAM` row at all. Measured over the
25 citable closes against `origin/main`, both channels in the same invocation: 4 appear in a commit
message, 8 in the `CHANGELOG` blob, **16 in neither** — and the four that sit in the `CHANGELOG` and
not in a message are the decisive group, because they are cited exactly as this file prescribed and
`named_absorbed()` returns nothing for them. Control in the same invocation: an impossible id
returns 0 from both channels.

So **the id goes in the RELEASE COMMIT MESSAGE, verbatim, for every closed entry**, and in
`CHANGELOG.md` as well — the message is what the closer joins on, the `CHANGELOG` is what a human
and the brief read. Citing only one of the two is the failure this paragraph exists to prevent.

`named_absorbed` takes `tail -1`, the OLDEST matching commit, so re-naming an id already named by an
earlier release does not move the reported version — it still reports the release that first named
it, which is the correct answer.

**Never run `ledger-reverify.sh` with the process cwd at the ai-dlc root.** Measured and
recorded at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:927-948`: a distribution-root
run turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false CLOSE is the worst output
this tool has — it retires an entry that is still live. Always `cd /Users/n8/git/graph` first and
pass the **absolute** consumer root:

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc <base-sha> /Users/n8/git/graph <theirs-sha>
```

**Ping the operator** on any question, on any decision, on completion, and on any early stop.
This program runs for many releases; from outside, a session that is thinking and a session that
is waiting on a human look identical. Merges are preapproved — do not stop to ask for one.

## Status record

**This is the only status record in this file.**

**Phase 0 steps 0–1 are COMPLETE.** The corpus pin, taken on the branch
`ai-dlc/graph-ledger-drain` cut from `origin/main` at `b1ee196`:

| pinned quantity | value |
|---|---|
| graph `HEAD` | `510e4d9f50192e85df54b81df7ebc70d53bdb638` |
| graph `git status --porcelain \| wc -l` **baseline** | **35** |
| ledger `md5` | `2fd444dcf406cdff728fe3c0c4352267` (4356 lines) |
| ledger archive `md5` | `8989cb668a33c6c73be429b827d9797f` (4474 lines) |
| ai-dlc `theirs` | `b1ee196`, VERSION `0.372.0` |
| ai-dlc `base` for reverify | `adec9ae` (0.370.0) |

The pinned copies live in the session scratchpad. **Every step from Phase 0 step 3 onward reads
the pin, not the live file** — a graph session is filing into the live ledger concurrently.

**Phase 0 steps 2–4 are COMPLETE, and they replace the planning-session estimates below.** The
census was built by lifting `ledger-reverify.sh`'s own extraction program (lines 621–738)
verbatim and changing one thing: `flush()`'s `has_verify &&` conjunct was dropped so an entry
carrying no receipt is emitted too. **The control is that the receipt-carrying subset must equal
the tool's own label set** — 79 labels each way, symmetric difference EMPTY, and the comparison
demonstrably fires on a one-line mutant.

| derived, Phase 0 | value |
|---|---|
| **open entry starts** | **131** |
| section banners that are not entries | 16 |
| **adjudicable open entries** | **115** |
| carrying `theirs_has` | 25 |
| carrying `verify: manual` | 24 |
| carrying `verify: sh` | 19 |
| carrying `theirs_lacks` | 11 |
| **carrying no receipt at all — invisible to the closer** | **36** |

**The tool's ENTRY column is not a unique key, and that is a new finding.** Its own header calls
the label *"a join key back into the ledger"*, but the label is whatever precedes the first
` — `, so four `## Open — filed <date>` banners all label as `Open` and the two
`scripts/validate-provenance-block.sh` bullets at pin lines 297 and 302 collide outright. **That
path is the CONSUMER's spelling, quoted from the ledger's own bullet label — do not look for it
here.** In this tree the file is `core/scripts/validate-provenance-block.sh`; `install.sh` lands it
at `scripts/ai-dlc/`.
**Measured: no collision today involves a receipt-carrying entry**, so the defect is real but
currently emits no wrong report row. Tier it accordingly.

**Phase 1 is COMPLETE, and so is the refutation pass that verifies its closes.** The 115 entries
were adjudicated in 29 parallel batches of 4; all 48 proposed closes were then attacked by 12
independent verifiers briefed to break them.

**PHASE 2 IS COMPLETE. `v0.373.0` IS CUT AT `e939a92` ON `ai-dlc/graph-ledger-drain`, NOTHING
PUSHED AND NOTHING MERGED.** `VERSION` is `0.373.0`, the top CHANGELOG heading matches, and
`scripts/validate-release-version.sh` PASSes over 41 commits. The full gate was run the way the
hook runs it — `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` — and is GREEN: **157 fixtures,
157 ok, 0 FAIL**, with both changed fixtures read by name against an impossible-name control that
came back empty.

**Phase 4 is IN PROGRESS. Phase 3 is not started and is a multi-release program of its own.**

**THE PLAN WAS WRONG ABOUT THE `verify: sh` POLARITY AND SO WAS I, IN THE OPPOSITE DIRECTION —
THIS IS THE MOST IMPORTANT THING ON THIS PAGE.** The two reverify engines read a receipt's exit
code in OPPOSITE senses, and a receipt written for the wrong one proposes closing a live defect:

| engine | subject | `rc=0` | `rc≠0` |
|---|---|---|---|
| `scripts/backlog-reverify.sh` | ai-dlc's OWN `docs/backlog.md` | CLOSE-CANDIDATE, "the fix is present" | STILL-LIVE |
| `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh` | the CONSUMER's ledger | **STILL-LIVE** | **CLOSE-CANDIDATE** |

Read at the emitter, not the header: `ledger-reverify.sh:942`'s dispatch comment states *"`sh`
reads a non-zero exit as 'no longer reproduces' -> CLOSE-CANDIDATE."* `backlog-reverify.sh:184-186`
states the opposite for its own file.

**I briefed four agents with the ai-dlc polarity for receipts destined for the CONSUMER's ledger.**
One caught it unprompted and inverted; the rest were corrected mid-flight. All 14 drafted receipts
now measure `rc=0` (STILL-LIVE) — verified by RUNNING them, not reading them, under the engine's own
exported environment, with controls both ways. **A receipt for a consumer entry must exit 0 while the
defect is live.** The failure mode is a FALSE CLOSE, which this file's own Hazards section calls the
worst output in the system.

**And `126`/`127` are NOT a close.** A renamed subject also exits non-zero, so a relocation reads as
an absorption that never happened — measured on this consumer, one relocation commit moved five
receipt subjects and all five flipped to CLOSE-CANDIDATE in a single run, every one still
reproducing at its new path. Guard every `sh` receipt so an unresolvable subject exits 127
(`[ -n "$s" ] || exit 127`), which `ledger-reverify.sh` reports as NEEDS-REVIEW.

**The pin was re-established and HELD.** graph `HEAD` is still `510e4d9f5`, the live ledger is 4503
lines — the 4356-line pin plus the 147 already-adjudicated post-pin lines — and `sed -n '1,4356p'`
reproduces `2fd444dcf406cdff728fe3c0c4352267` exactly, with the 4355-line control producing a
different digest. **No new graph filings since the last pass**, so the post-pin adjudication still
covers everything. Consumer dirty count observed at 113; that is an observation and never a gate,
per done-when 4.

**Pin 1254's disposition is CORRECTED and its sub-claim is refuted**, so the split is now
**25 CLOSE / 14 CLOSE + file the sub-claim / 9 withdrawn / 67 live** — 39 closes, unchanged. The
claim was verified behaviourally rather than taken from this file: mutating
`core/scripts/validate-mandatory-rules.sh:233` to `if false` makes Check 4's PASS branch unreachable
and `mandatory-rules-skip-accounting` reports `FIXTURE ERROR` with arms A, B and D falling to `[]/1`,
against an unmutated control of `PASS (10 assertions)` in the same session. **A grep was the wrong
instrument twice over** — renaming the emitted `CHECK 4: PASS` string kills nothing, because the
fixture asserts the SUMMARY line rather than the per-check line.

**Correcting it exposed that two register sections were hand-written while `--check` passed**
(`c9a4500`). The gated list still said "The fifteen" and still listed 1254; the nine-withdrawn-closes
table held the last hand-typed id column in the file, and it had already decayed — pin 4216 was
written `…MANDATE-NO-STATED-EXCEPTION` against the ledger's `…MANDATE-HAS-NO-STATED-EXCEPTION`. Both
now render, and the gated list's heading COUNT is inside its region deliberately. Measured by joining
every `PC-` token in the register against every one in the pinned ledger: 93 resolve; of the 16 that
do not, 14 are deliberate prose shorthand and 2 sat in that id column.

**START HERE ON A FRESH SESSION — the numbered next actions.**

0. **Nothing is pushed and nothing is merged.** The branch `ai-dlc/graph-ledger-drain` carries
   `v0.373.0` at `e939a92`, plus `d6d34c6` and the promotion commit after it. Merges are preapproved
   — the gate was green at `d6d34c6`, so **re-run the gate and merge** unless you have changed
   something since. Do not cut anything new from a local `main` that may be ahead of `origin/main`.

1. **Re-establish the pin** (see "Re-establish the pin", below). It held across this entire session:
   graph `HEAD` is still `510e4d9f5`, the live ledger is 4503 lines, and `sed -n '1,4356p'` reproduces
   `2fd444dcf406cdff728fe3c0c4352267` with the 4355-line control differing. Verify anyway; it is one
   command and every line number in the register depends on it.

2. **FINISH PHASE 4 — the critical path, and the only channel that reaches graph.** Three pieces:

   **2a. Build `docs/reviews/graph-ledger-adjudication-data/replacement-receipts.tsv`.** The 14
   replacement receipts are DRAFTED, RUN and PROMOTED, but they are still prose in four per-batch
   files under `graph-ledger-adjudication-data/step19-receipts/batch-{1,2,3,4}.md`. The renderer needs
   them as a TSV with columns `pin / label / old / new / rc / note`. Extract them; do not retype them.
   **Re-run `step19-receipts/run-receipts.sh` after extracting** — it executes every receipt under the
   engine's own exported environment (`DIST`/`BASE`/`THEIRS`/`CONSUMER`) and every one must report
   `rc=0`, which is STILL-LIVE for the consumer engine. Its controls are built in, and it REFUSES
   with exit 2 if any batch file is absent rather than reporting a clean run over nothing.

   **All 14 are verified as of `a47233d`**: `rc=0` each, with `exit 127` guards throughout (6/5/5/5),
   controls firing both ways in the same invocation. **Two of the four batches were promoted in a
   pre-correction state and re-promoted at `92e8bed`** — I snapshotted them while their authors were
   still revising after the polarity correction reached their inboxes. If you touch these files,
   `cmp -s` the promoted copy against whatever you think is current before trusting either; batches 2
   and 4 were byte-identical then, which is what made the comparison believable.

   **2b. Render the brief.** `graph-ledger-adjudication-data/render-brief.sh` writes
   `docs/reviews/graph-ledger-adjudication-brief.md` and has a `--check` mode. It carries three arms,
   all proven able to fire: it tests the annotation string it generates against BOTH enforcers, it
   refuses if the versionless near-miss ALSO passes the strict form, and it refuses outright while
   `replacement-receipts.tsv` is absent rather than emitting a brief that promises a section it lacks.
   Sections A–D partition the 115 exactly — **39 CLOSE + 18 WITHDRAW + 41 LIVE-tracked + 17
   consumer-local**; section E cuts across C and D.

   **2c. Add the three post-pin entries to the brief.** They are NOT in `final-disposition.tsv`, so
   the renderer cannot see them; their verdicts are in `post-pin-verdicts.tsv`. See action 3.

3. **`BL-063`–`BL-065` ARE FILED (`b4e7f17`). This step is DONE.** The three post-pin entries were
   the last unfiled live entries in the program. They were missed for a STRUCTURAL reason: step 12's
   population came from the corpus pin — the ledger's first 4356 lines — and graph filed these after
   the pin was taken, so every derivation downstream inherited that boundary. The coverage check that
   confirmed all 59 population rows were accounted for was CORRECT and said nothing about these.

   Found by asking a different question: do any backlog entries cite a pin above 4356? Zero did,
   against a control confirming 42 cite pins below it. **When a population is derived from a pinned
   snapshot, ask separately what the pin excluded** — a complete-looking coverage proof over the
   population cannot see outside it.

   All three verified from the tree rather than from the authoring agent's account: 64 reverify rows
   for 64 entries, zero `unresolved`/`vacuous`/`INPUT-UNRESOLVED`/`ENTRY-SWALLOWED`, rotator ok, and
   each cites its own post-pin line (4357 / 4392 / 4435) so the join to the consumer resolves. They
   correctly exit NON-ZERO — the ai-dlc polarity, opposite to the fourteen consumer receipts.

4. **Then Phase 5.** Step 22 is ALREADY DONE and was re-verified at wind-down: the pin reproduces,
   graph `HEAD` is unchanged, and the 147 post-pin lines are the three entries above plus one
   `RETRACTED` banner — **no new consumer filings during this run**. Step 21 needs the merge from
   action 0 first, because it re-runs `ledger-reverify.sh` against the new ai-dlc `origin/main`. **Its
   observation point is BEFORE graph applies any annotation from the brief** — an annotated entry is
   skipped and emits no row, so the criterion is unreachable afterwards.

6. **OWED, AND IT IS THE OPERATOR'S CALL: one general rule has no durable carrier.** This session
   found that **a coverage proof over a derived population cannot see outside it** — step 12's
   census came from the corpus pin, so the check confirming all 59 rows were accounted for was
   CORRECT and structurally blind to the three entries filed after the pin. That is a sharpening of
   `verification-discipline.md`'s existing "Ask what SET a number was taken over", and it belongs
   beside it.

   **It is not there, because the durable channel has 40 bytes of headroom** — arm A6 reports
   40920/40960 across 7 files. Adding it requires TRADING OUT existing prose, and
   `resident-context.md` forbids trimming for cost and requires grepping for inbound references
   before any cut. That is a deliberate decision, not a mechanical one. Today the rule is carried
   by action 3 of this file, which is adequate for this program and for nothing else.

5. **Phase 3 is not started, and it is a program rather than a step.** The `HOLDS` set is now 42
   backlog entries (`BL-021`..`BL-062`) plus whatever action 3 adds. Done-when 6 is ALREADY SATISFIED
   — "every entry is either remediated and cited, or filed as a `BL-` entry" — so this is the
   operator's call on sequencing, not a blocker on closing this plan. Batches of ≤4 remediations per
   release branch, one version per branch, cut from `origin/main`.

**Three things this session learned that will cost a fresh session real time if forgotten.**

**A count with no join to anything else is a count nobody can falsify.** The step-12 commit reported
"17 withdrawn", derived as 59 rows minus 42 entries — a subtraction assuming one entry per row. Pin
262 drew two entries, and one entry cites a section banner before its own subject. It went unnoticed
until the brief, whose sections must partition 115 exactly, summed to 114. The real figure is 18, and
41 + 18 = 59 closes where the wrong one never did. Corrected in `d6d34c6`.

**Its mirror image, in the same hour: a probe reported that 18 of 42 entries stated no pin line, and
that was FALSE.** `pinned ledger line <N>` WRAPS across lines in a hard-wrapped file, and a
single-line `grep -oE` cannot see it. All 42 state their pin. Flatten the body before matching. Both
failures are one class from opposite sides — an instrument's shape deciding a number that then reads
as a finding about the corpus.

**An idle notification is still not a result, and this session re-confirmed both halves.** Yesterday's
`fix-bl009`/`fix-bl011`/`fix-bl012` fired idle notifications hours late; all three were UNREACHABLE
(`No agent named … is reachable`) because their session was gone, and the tree had been clean at
`95e421a`, so they had left nothing behind. But this session's own agents all delivered when ASKED,
and two of them delivered their most important finding only in the report, never in the file — the
`verify: sh` polarity inversion among them. Ask before concluding, and ask before redoing.

**An agent going quiet in this session did NOT mean it had died, and acting on that assumption cost a
full duplicate pass.** Six adjudicators reported hours late, in one burst, after their work had been
redone inline; two fixture authors never reported at all yet had written complete, passing fixtures to
disk. So: before redoing a delegated task, `git status` for its output and `SendMessage` the agent by
name. An idle notification is not a result, and silence is not death.

**What landed in the session that CUT THE RELEASE, and what each is worth:**

| commit | what | evidence state |
|---|---|---|
| `cb94a43` | BL-011's cross-hook legend arm + 5-mutant battery; the `I77` mode bit | fires on the REAL pre-fix hooks, one FAIL, differential sides asserted to differ |
| `74430c0` | BL-012's receipt could not tell the fix from the defect; DO-NOT-BUILD reasoned | FP set empty over 5 rewordings vs 2 offenders |
| `158d752` | step 12 — 42 backlog entries `BL-021`..`BL-062`, 18 withdrawals promoted | all 41 `sh` receipts RUN, evaluator controlled both ways |
| `953e39e` | BL-009's guard reduced to the half with a bounded FP set | FP set ENUMERATED at one member; unguarded half stated in the fixture |
| `e939a92` | **release v0.373.0**, 29 ids cited in the CHANGELOG *and* the commit message | commit-message join went 9/29 → 29/29, impossible-id control 0 |
| `d6d34c6` | corrected step 12's withdrawal count, 17 → 18 | partition now closes: 39+18+41+17 = 115 |

**A guard was NOT built for BL-009's procedure half, and that is a decision with a measurement
behind it rather than an omission.** Its arm keys on the token `quer` plus a closed list of send
verbs, and 3 of 5 legitimate rewordings fire — "request shape", "transmits", "introduces" all
preserve the instruction and all trip it. That false-positive set is an open class of legitimate
English, which `CLAUDE.md` forbids shipping. A future sweep could delete the query-shape step and
nothing would catch it; the fixture says so in its own header so its green line cannot be read as
covering it.

**The earlier session's table, kept because its findings still stand:**

| commit | what | evidence state |
|---|---|---|
| `40770c3` | 39 register ids repaired; verdict table now RENDERED with a `--check` | proven both directions |
| `b222017` | the naive fence fix would drop 47 entries; one entry carries the odd fence | measured |
| `16d93f4` | the three post-pin entries adjudicated | re-derived |
| `2c5d691` | six late agent reports reconciled; one overturned a verdict of mine | re-derived |
| `d50859d` + `a572e42` | `backlog-rotate.sh` refuses a ledger it would corrupt | FP set empty; 5 mutants, all killed |
| `b0e523b` + `6abef95` | `wait-for-deliverable` chained-sibling false NON-DELIVERY | end-to-end mutant kills; ONE over-broad mutant leaves the branch RED |
| `2951644` | short-id fallback anchored and archive-aware; 4 misattributions withdrawn | measured, fixture 78/78 |

**Two things a resuming session must not mistake for done.**

**Both fixtures now exist — this paragraph previously said they did not, and that was true for about
an hour.** `6abef95` gives `b0e523b` the deterministic end-to-end arm it was owed, from a different
hand, and its decisive mutant reads
`gating the SAMPLE on MAY_SLEEP declares a demonstrably working teammate non-delivered`. `a572e42`
gives `d50859d` a battery of five mutants, all killed, plus an eight-shape near-miss set.

What remains on those two is **only** the entangled mutant at action 0 above. In particular the
original worry — that `b0e523b` rested on a `bash -x` trace because the outcome harness printed the
same line for both builds and could not be made deterministic (pre-seeding the counter collides with
the grant path's rewrite at `wait-for-deliverable.sh:487` and the PENDING loop's re-read at `:586`) —
is **discharged**: the delegated fixture achieved determinism where the inline harness did not.

### Adjudication result — 115 entries

`ALREADY-FIXED` 41 · `HOLDS-MECHANISM-WRONG` 22 · `NOT-UPSTREAM` 16 · `HOLDS` 15 ·
`HOLDS-WIDER` 14 · `FALSIFIED` 4 · `DUPLICATE-OF` 3

### Refutation result — all 48 closes attacked

`CLOSE-CONFIRMED` 24 · `CLOSE-NARROWED` 15 · `REFUTED` 9

**Half the closes did not survive.** Final: **76 live** (67 plus 9 whose closes were withdrawn),
**24 close cleanly**, **15 close only once a named sub-claim is filed first**.

### Where the data lives — READ THESE FIRST ON RESUME

A session scratchpad is session-scoped and unreachable from a fresh session, so the per-entry
evidence was promoted into the repo:

- `docs/reviews/graph-ledger-full-adjudication.md` — the register: method, controls, cross-cutting
  findings, and the 115-row verdict table.
- `docs/reviews/graph-ledger-adjudication-data/phase1-verdicts.tsv` — 115 rows,
  `line / id / verdict / subsystem`.
- `.../refutation-verdicts.tsv` — 48 rows, `line / outcome / why`, one per attacked close.
- `.../final-disposition.tsv` — the merge, 115 rows.
- `.../merge-verdicts.sh` — recomputes it. **An unattacked close renders `CLOSE (UNVERIFIED)`,
  never `CLOSE`** — "nobody checked" and "checked and survived" must not read alike.
- `.../adjudicable-entries.tsv` — the Phase 0 census both passes are keyed on.

### Re-establish the pin before trusting any line number

Every line number in the register is an offset into graph's ledger as pinned at Phase 0. The live
file has ALREADY moved past the pin twice, so expect to reconstruct rather than to match:

```
md5 -q /Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md
```

**The pin is reconstructible, and this is how.** Every graph addition so far has been a pure APPEND
at end of file, and graph `HEAD` has stayed at `510e4d9f5`. So the pin is the live file's first
**4356** lines, and that reconstruction is verified by md5, not assumed:

```
sed -n '1,4356p' <ledger> | md5      # must be 2fd444dcf406cdff728fe3c0c4352267
sed -n '1,4355p' <ledger> | md5      # CONTROL: an off-by-one must NOT match
```

Confirmed on resume — the pin re-derived exactly and the control produced a different digest. Should
a future graph edit ever land in the MIDDLE of the file, this reconstruction breaks and the md5 will
say so; re-derive the delta from `git diff` hunk offsets before trusting any pin line.

**Everything after line 4356 is new work, and on resume it was ADJUDICATED.** 147 lines: three
entries plus one `## RETRACTED` banner in which graph withdrew its own `--brief` filing as a lead
invocation error — that one owes no upstream work and is not an entry. All three verdicts are
`HOLDS`-family, so all three are LIVE and none needed a refutation pass. Evidence is in the
register's "Three entries filed after the pin" section and
`graph-ledger-adjudication-data/post-pin-verdicts.tsv`:

| live line | entry | verdict |
|---|---|---|
| 4357 | `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX` | `HOLDS-MECHANISM-WRONG` |
| 4392 | `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` | `HOLDS-WIDER` |
| 4435 | `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR` | `HOLDS-WIDER` |

**So the live set is 79, not 76** — 76 from the pin plus these three. Two of the three carry no
receipt, so Phase 4 step 19 owes them one. All three are also `HOLDS-MECHANISM-WRONG`-or-`WIDER`,
which is 3 for 3 on the base rate.

**The subagent channel is UNRELIABLE here, in a way that reads as death.** Six agents across two
batches each ran, went idle, and delivered nothing at the time — so the three entries were adjudicated
inline. All six then delivered **hours late**, in one burst. Two of them overturned the inline verdict
on the third entry, correctly. The lessons a later session needs:

- **An idle notification is not a verdict.** Never let one stand in for a result, and never
  reconstruct what an agent "probably found".
- **Do not assume a silent agent is a dead agent.** Ask it for its report before redoing its work;
  a `SendMessage` to a named agent resumes it from its transcript.
- **A second hand is worth the delay.** The inline pass called
  `PC-S303-SCOPE-CONFIRMATION` a plain `HOLDS` "exactly as filed" and missed a harsher second
  grammar, a prescribed fix that does not work, and a BSD-`sed` no-op. Phase 1's own lesson —
  every close needs an independent hand — extends to `HOLDS` verdicts wherever the SCOPE decides the
  remediation.

### The four decisions are RULED. None is open.

1. **`PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` (pin 1069) — RETIRED ON RULING.** The exemption is
   correct by design: `core/scripts/validate-locked-anchor.sh:16-18` scopes the byte-match to a
   `full_text_source:` full-text claim, and `:20-26` records that a `requires_context:` load pointer
   **is** resolved for existence. Byte-matching a load pointer would fail honest cite-by-reference.
   No upstream work; the brief carries the reason so graph can retire it.
2. **Full sweep, unchanged — drain all 76.** Scope is not renegotiated by a measurement. Keep cutting
   ≤4-remediation release branches until the `HOLDS` set is empty, reporting after each.
3. **`BL-009`, `BL-011`, `BL-012` jump the queue and are fixed in the close release.** They are live
   defects in already-shipped code, not queued innovations, and two return a WRONG answer rather than
   a missing one. They are gated on no sub-claim, so they add no dependency.
4. **Done-when 5 is narrowed, and the 14 non-citable closes route through the brief.** See the
   amended criterion. The closes all still land; only the evidence differs.

### Two blockers were found on resume and are FIXED

Both were in the promoted register data, not in the adjudications.

- **39 of 115 register ids were abbreviations of the ledger's label, 17 on rows bound for the
  CHANGELOG.** A citation drafted from them would have named ids that exist nowhere and closed
  nothing, silently. Repaired by joining against the Phase 0 census; the verdict table is now
  RENDERED by `docs/reviews/graph-ledger-adjudication-data/render-register-tables.sh`, whose
  `--check` byte-compares and is proven to fail on an in-region edit, a deleted row, a changed TSV
  row and a misspelled marker.
- **`merge-verdicts.sh` exited 2 and recomputed nothing** — it named `refute-all.tsv` and
  `verdicts.tsv`; the committed files are `refutation-verdicts.tsv` and `phase1-verdicts.tsv`.
  Repaired, it reproduces the disposition table byte-identically. It now also derives the **close
  channel** from the census, so the two gates below cannot be forgotten.

**A close has two channels and only 25 of the 39 can use the mechanical one.** A `NAMED-UPSTREAM`
row needs a `verify:` receipt (`ledger-reverify.sh:647` gates on `has_verify &&`) AND an id-shaped
label (`named_absorbed()` rejects any label with a character outside `A-Z0-9-`). 14 closes fail one
or both. They close via the brief's strict `**ADOPTED UPSTREAM (v<digit>` annotation, which
`ledger-rotate.sh` archives with no receipt test anywhere in it.

The two tables that follow are the superseded planning-session estimates, kept because the
false finding in them is instructive. **Do not act on their numbers.**

**Two tiers, and only the first is trustworthy.** The upper block is what the shipping
`ledger-reverify.sh` emitted. The lower block comes from parsers written in the planning
session, and one of those parsers produced a finding that has already been shown false.

| from the shipping tool | value |
|---|---|
| distinct entries it emitted a row for | 89 |
| `STILL-LIVE` rows | 59 |
| `HAND-REVIEW` rows (`verify: manual`) | 25 |
| `NAMED-UPSTREAM` (upstream history already cites the id) | 13 |
| `NAMED-UPSTREAM-AMBIGUOUS` (sprint prefix, 2–17 entries each) | 9 |
| `theirs_has` receipts the tool itself calls undecided | **28 of 28** |
| `NEEDS-REVIEW` | 0 |
| `CLOSE-CANDIDATE` | 0 — **and the tool says not to read that as evidence** |

**Control:** these counts reproduce graph's own run, recorded at
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/reconcile-report.md:218-265`, which is the
evidence that the invocation was right and not merely that it ran.

| from a subagent census — **hypotheses until re-derived** | value |
|---|---|
| raw entry starts matched by the boundary rule | 142 |
| section scaffolding, not entries | 18 |
| already closed on the ledger's own annotation grammar | 19 |
| **OPEN** | **93** |
| open entries citing an ai-dlc path that does not exist at HEAD | ~14 |
| of those, `PC-S312-*` entries targeting the **consumer's own forked `scripts/`**, not core | 9 |

**A planning-session parser produced a false finding, and the failure is the useful part.** A
hand-rolled `awk` reported that two section headings had absorbed a `verify:` receipt belonging
to the entry below them. The shipping parser emits **no row for either heading** — control: a
known id returns 2 rows in the same invocation. The tokens that `awk` matched are
`verify: theirs_has` written inside ordinary prose, which reverify's directive parser correctly
ignores and which this ledger's own header already names as a known hazard. **A hand-written
probe is a second implementation whose bugs nobody finds.** Derive the census from the shipping
code, per Phase 0 step 3.

**The two parsers also disagree about the `push_candidate: true` extension bullets** — the
hand-rolled one counted the 12 `extensions/…-push.md` roster rows as entries, the subagent
classified them as scaffolding. The ledger's own header says that whole section was **"owed, not
done"** as of its last full pass, which argues they are entries. Resolve this at Phase 0 step 4
by reading the section, not by picking a parser.

**A live graph session is filing into this ledger while you work.** At planning time there was an
uncommitted 44-line addition (`PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG`) that
is not in graph's `HEAD`. Pin the corpus at Phase 0 and re-derive the delta at Phase 5.

## Verdict vocabulary

Two vocabularies exist and they are not the same. The **machine** statuses
(`STILL-LIVE`, `HAND-REVIEW`, `NEEDS-REVIEW`, `CLOSE-CANDIDATE`, `NAMED-UPSTREAM`,
`NAMED-UPSTREAM-AMBIGUOUS`, `RECEIPTS-UNDECIDED`) are inputs, never verdicts. The **adjudication**
verdict is what this program produces, and it follows the precedent in
`docs/plans/sprint-302-303-push-candidates.md:81-88`:

| verdict | evidence required | disposition |
|---|---|---|
| `HOLDS` | the defect re-derived against the working tree at a named sha, `path:line`, with a control in the same invocation | remediate upstream |
| `HOLDS-WIDER` | as above, plus what the filing understates | remediate at the true scope |
| `HOLDS-MECHANISM-WRONG` | as above, plus the filing's stated cause or consequence shown false | remediate the real defect; record the correction |
| `ALREADY-FIXED (vX.Y.Z)` | the release that fixed it, named, with the fix read in the tree — **not** from the CHANGELOG | close by CHANGELOG citation |
| `FALSIFIED` | the premise shown false in the tree, with a control | close by CHANGELOG refutation |
| `DUPLICATE-OF <id>` | both bodies read; the surviving id named | close by CHANGELOG citation of the dropped id |
| `NOT-UPSTREAM` | no upstream grain fits; consumer-local by nature | brief only, no upstream work |

**Adjudicate the MECHANISM, not the claim.** A defect can be real while the filing's stated cause
and consequence are both false, and the last cycle found three of four filings materially wrong
about why. **Do not trust the filing's prescribed fix** — one of them was itself broken.

## Phases

### Phase 0 — promote this file, then pin the corpus

0. ~~Promote this plan and commit it.~~ **DONE** — this file is the promoted copy.
1. ~~Pin the corpus and record the consumer baseline.~~ **DONE** — see the status record above.
2. Re-run `ledger-reverify.sh` from the graph root as shown in **Start here**, base `adec9ae`,
   theirs = current ai-dlc `origin/main`. **Control:** the row counts must reproduce graph's own
   `_bmad-output/ai-dlc-update/reconcile-report.md:218-265`. They did in planning; a divergence
   means the corpus moved and Phase 0 restarts.
3. Derive the open-entry census **from the shipping code, never from a fresh parser.** Source
   `ledger_entry_awk()` from `core/skills/ai-dlc-update/reconcile/lib.sh:274` for the boundary
   rule, and reuse `ledger-reverify.sh`'s own close predicate `entry_line_closes()`
   (`:629-631`) and its directive parser rather than restating either. The planning session
   restated them and produced a false finding within the hour. Run every `awk` under `LC_ALL=C`;
   the ledger is full of em-dashes and a byte-truncating `substr` aborts the program mid-file.
4. Reconcile the census against the tool's 89 emitted rows and **account for the difference by
   name**. The residual is the set of entries the closer cannot see at all — the ones with no
   directive — and that set is the real reason a zero-close reading means nothing. Section
   headings that are not entries belong in the residual too; classify them explicitly rather
   than letting them inflate the count.

### Phase 1 — adjudicate every open entry (subagent fan-out) — **COMPLETE**

**Steps 5–9 are DONE.** They are retained because the method is what a later pass reuses, not
because work remains in them. What the run added, and what a repeat must keep:

- **Every close needs a second, independent hand.** Half failed. Every place a first-pass agent
  wrote "I hesitated here", a verifier found the defect there — so instruct agents to record their
  hesitation, and aim the verifier at it.
- **`CLOSE-NARROWED` is the verdict a lazy confirmation misses.** Fifteen closes were right about
  their headline and would have buried a live finding no other entry owns. Ask for it by name.
- **Give the verifier the specific weak point**, not a generic "check this".


5. Partition the open entries by the ai-dlc subsystem they target. A planning-session census
   produced this split — **re-derive it, do not trust it**:

   | subsystem | entries |
   |---|---|
   | reconcile machinery (`core/skills/ai-dlc-update/reconcile/*`) | 26 |
   | `core/scripts` validators | 20 (+3 filed under pre-relocation paths) |
   | `core/skills/ai-dlc` rules and steps | 21 |
   | consumer-local `scripts/` — the `PC-S312-*` retirement probes | 9 |
   | `core/git-hooks` and `core/hooks` | 7 |
   | `ai-dlc-update` SKILL.md and steps | 5 |
   | `core/fixtures` | 2 |
   | role files and templates | 2 |

   Batch at **~4 entries per subagent**, one subsystem per batch so a subagent reads one area.

5a. **Take the cheap closes first.** ~14 open entries cite an ai-dlc path that does not exist at
   HEAD, and they split two ways. Nine `PC-S312-*` entries cite the **consumer's own forked**
   `scripts/check-*.sh`, `scripts/lib/pr-class.sh`, `scripts/tests/**` — none of which core has
   ever shipped — so they are `NOT-UPSTREAM` by construction. The rest are **stale path forms,
   not dead entries**: `core/.claude/skills/…/retro.md`, `core/scripts/ai-dlc/…`,
   `tests/fixtures/…` are all pre-relocation spellings of live files, and an entry whose subject
   moved needs a repoint, **not** a close. Do not conflate the two — a close on a repointable
   entry is the data-losing direction.

5b. **Two receipts are green for the wrong reason and must not be read as passes.**
   `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` and `PC-S297-FFCLUSTER-SHA-STALE` both
   carry `verify: sh ! git cat-file -e <path>`, and both paths are absent from core, so the
   receipt exits 0 on absence rather than on a fix. `PC-S296-H1-FIXTURE-CITATION-GAP` greps for
   the literal `tests/fixtures/check-3b-locked-anchor` in a tree that relocated to
   `core/fixtures/` — it can never match. Verify each against the tree before verdicting.

5c. **One open entry has no heading and no id** (around ledger line 2028): its title was absorbed
   into a fenced block that opens mid-entry, so `ledger-reverify.sh` cannot join it to anything.
   That is a live instance of the `ENTRY-SWALLOWED` class the ledger itself documents. Adjudicate
   its body like any other entry, and record the parser instance in the register.
6. **Spawn one adjudication subagent per batch, in parallel, in a single message.** Each returns
   one verdict row per entry: id, verdict, `path:line` evidence, the control run in the same
   invocation, and what the filing got wrong and in which direction. Give every subagent the
   verdict vocabulary above and the `consumer-boundary` prohibition verbatim.
7. **Every `ALREADY-FIXED`, `FALSIFIED` and `DUPLICATE-OF` verdict gets a second, independent
   verifier subagent whose brief is to REFUTE the close.** Those three are the data-losing
   direction: a false close retires a live defect and reads exactly like an ordinary absorption.
   `HOLDS` verdicts need no second pass — the cost of a false HOLDS is wasted work, not lost work.
8. Write the register to `docs/reviews/graph-ledger-full-adjudication.md`. One row per open
   entry, no exceptions — a missing row is indistinguishable from an entry nobody looked at.
9. The `push_candidate: true` extension blocks have **never been re-derived** since 2026-07-21.
   The ledger's own header says so — *"Owed, not done in this pass"* — and says why
   `layer-drift.sh` cannot answer the absorption question for them: its `EXTENSION-OK` arm
   compares only `base..theirs`, so a block absorbed several releases ago reports OK. Adjudicate
   them per block against core at HEAD like any other entry. **Do not use `layer-drift.sh` as the
   oracle** — that is the same check-cannot-fire trap this pass exists to find.

### Phase 2 — the close release — **PAUSED BY THE OPERATOR, one step in**

**RESUME HERE.** The next action is to finish drafting `BL-009`–`BL-033` and land them, because 15
of the closes are gated on their sub-claim being filed first.

**The backlog list is 22, not 25, and it must be DERIVED rather than recalled.** Three of the
original 25 were ruled fixes rather than filings (decision 3), and two of those three are already
fixed. **Do not work from a prose list** — derive the set from
`docs/reviews/graph-ledger-adjudication-data/final-disposition.tsv` (rows whose disposition contains
`sub-claim` are the 15 gated ones) plus `post-pin-verdicts.tsv` for 3 more. Each gated sub-claim
carries its measured evidence in `refutation-verdicts.tsv`, keyed on the pin line, so the work per
entry is a RECEIPT THAT FIRES rather than a fresh derivation of the defect.

**The 15 gated sub-claims, by pin line:** 273 the producer-surface evidence procedure; 281 two
template files the install glob cannot reach; 387 the divergent flow-log legends; 610 a merged
duplicate whose retirement would delete the only mechanical anchor either entry has; 1254 Check 4's
unreachable PASS; 1449 a bold bullet that splits an entry while `ENTRY-SWALLOWED` fires only on a
colon; 1543 a multi-line plain scalar rendered as one line that reads as a complete reason; 1862
`wait-for-deliverable`'s chained sibling — **FIXED in `b0e523b`**; 3190 three catalog entries outside
the detector with no `NOT-CHECKED` status; 3375 no detector deriving retired paths; 3464 the shipped
schema still naming the blocking row; 3507 the archive-blind short-id fallback — **FIXED in
`2951644`**; 3787 the wrapper discarding `CORE-AT-THEIRS`; 3828 `effort_bound` with no readers; 4153
the budget summary reading three of six channels.

**Plus the three post-pin entries**, all live, all needing a receipt — two carry none at all:
`PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX`,
`PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF`,
`PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR`.

**Still owed as FIXES, not filings:** the recovery gate not arming on a bare-basename step file, and
the gate treating a partial read as a full one.

**Each needs a receipt that can fire.** The two failures this program measured, both of which will
recur: an anchor on text **the fix quotes back** (fixes here document what they removed, so the
anchor survives inside the comment recording the change), and an anchor on a **phrasing the filing
invented** rather than one the code uses. Grep the anchor before committing to it, and run the
receipt — one that exits 0 today is already broken.

**Settle while drafting `BL-033`:** the consumer's rotator split an entry mid-fence and left the
archive permanently short five paragraphs. This repo's own `docs/backlog.md` is rotated by the
forked sibling `scripts/backlog-rotate.sh`. If the same boundary blindness is there, the file about
to grow fourfold carries the identical hazard.

**Then the release itself:**

10. One release. `VERSION` bump, matching commit subject, one `## [X.Y.Z]` CHANGELOG heading, and
    **one `###` section per closed id, each naming the `PC-` id verbatim.** Arm C of
    `scripts/validate-release-version.sh` limits a push range to one version *heading*, not one
    section, so every close in the program can ship in this single release.
11. Include the `NAMED-UPSTREAM` set. Read each named commit and decide absorbed vs. rejected vs.
    split vs. passing mention — the tool's own header records that the author of that status got
    all four wrong in the release that shipped it, so this is a reading, not a lookup. Re-cite the
    confirmed ones so graph gets a current, unambiguous row. Resolve the
    `NAMED-UPSTREAM-AMBIGUOUS` prefixes the same way, per entry.
12. Land the accepted-but-not-yet-shipped `HOLDS` entries into `docs/backlog.md` as `BL-` entries
    in the same release, so nothing is carried only in a plan. That file's grammar and receipt
    verbs (`sh` / `has` / `lacks`, never `theirs_*`) are stated in its own header at
    `docs/backlog.md:19-40`.

### Phase 3 — remediation releases

13. Group the `HOLDS` set by subsystem into batches of **≤4 remediations per release branch**.
    One version per branch, cut from `origin/main` — a squash of two takes the first version in
    the subject and breaks the release triple. Expect **many** branches; the operator has asked
    for the full sweep, so keep cutting them until the `HOLDS` set is empty.
14. Per batch: **one subagent drafts each remediation, and a different subagent authors its
    fixture.** `.claude/rules/fixture-mutants.md` requires the fixture's author be a different
    hand from the arm's — an arm and a battery from one hand encode one understanding twice and a
    false pass has an unreachable half nobody sees. The last cycle recorded a self-authored arm
    that passed against its own mutant; do not repeat it.

14a. **A `HOLDS` verdict gets an independent hand on its SCOPE before it is remediated.** Phase 1
    exempted `HOLDS` from second review on the grounds that a false `HOLDS` wastes work rather than
    losing it. That reasoning holds for whether the defect is real and fails for how WIDE it is: a
    `HOLDS` whose scope is wrong ships an incomplete fix, which is lost work wearing a green fixture.
    Measured on the three post-pin entries — all three were `HOLDS`-family, one was filed here as a
    plain `HOLDS` "exactly as filed", and two independent verifiers found a second failing grammar,
    a prescribed fix that does not work when run, and a BSD-`sed` no-op in it. **36 of the 76 live
    entries are already `HOLDS-MECHANISM-WRONG` or `HOLDS-WIDER`**, so scope error is the base case,
    not the exception. Aim the second hand at the scope question specifically — what else fails the
    same way, and does the prescribed fix actually work when executed — not at "is this real".

14b. **Run the filing's prescribed fix before adopting it.** Two of three post-pin filings prescribed
    a fix that provably does not work: one still returned the corrupt value when transcribed
    literally, the other named a channel that does not exist. Transcribe it, execute it against the
    case the filing itself reproduces, and record what it returned.

14c. **Read the guarding fixture before writing the remediation, and expect it to be blind.** All
    three post-pin entries were guarded by a fixture that was absent or seeded from what its reader
    already accepts — `core/fixtures/scope-confirmation/` seeds only the two grammars its parser
    accepts, and `core/fixtures/spec-join-integrity/seed.sh:200` claims "REAL bmad-spec SHAPE,
    captured from an actual headless run" while seeding only the form its regex matches. A fixture
    that cannot express the defect will stay green across the fix, so the remediation is not done
    when the code changes — it is done when an arm exists that fails without it.
15. Gate each branch with `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` and read every
    changed fixture **by name** in the full output, against an impossible-name control in the same
    invocation. `core/git-hooks/pre-push` is the consumer's hook and prints a green banner having
    run almost nothing; the content-key skip prints one too.
16. Each remediation gets its own `###` CHANGELOG section naming its `PC-` id verbatim.

### Phase 4 — the consumer brief

17. Write `docs/reviews/graph-ledger-adjudication-brief.md`. Per entry: the verdict, the evidence,
    and **either** the exact annotation string to paste —
    `**ADOPTED UPSTREAM (vX.Y.Z, verified <date>)**`, bolded, version immediately after the
    parenthesis — **or** the exact replacement `verify:` receipt.
18. The annotation form is load-bearing in two directions: *any* occurrence of the phrase makes
    `ledger-reverify.sh` skip the entry, but only the strict form lets `ledger-rotate.sh` archive
    it. A sloppy annotation makes an entry invisible **and** unarchivable. Render the exact string
    per entry; do not describe it.
19. For each of the 28 undecided `theirs_has` receipts, derive a replacement anchored on a token
    the fix **must remove** — a flag, a path, a function name — never prose describing the fix.
    Prefer converting to an `sh` predicate scoped to the span the claim is about; a file-wide
    substring cannot express "Check 5 does not consult the gate log". For every open entry the
    Phase 0 residual showed carries no directive at all, supply a receipt, or `verify: manual`
    with the reason it has no mechanical predicate.
20. Deliver the brief to the operator. **Do not apply it.** graph applies it in its own session.

### Phase 5 — close out

21. Re-run `ledger-reverify.sh` from the graph root against the new ai-dlc `origin/main`.
    **Observation point: before graph applies any annotation from the brief** — an annotated entry
    is skipped and emits no row, so this criterion is unreachable afterwards.
22. Re-derive the ledger delta against the Phase 0 pin. Entries graph filed during the run are new
    work; adjudicate them or hand them to the operator explicitly. Do not report completion over
    them silently.
23. Report to the operator: what shipped, what was closed and how, what graph must do, and
    anything left undone with the reason.

## Done when

Each of these is a command, and each was checked to be answerable at the point it is read.

1. `docs/reviews/graph-ledger-full-adjudication.md` carries one verdict row per open entry, and
   the row count equals the Phase 0 open-entry count **derived in the same invocation**.
2. Every id adjudicated `ALREADY-FIXED`, `FALSIFIED`, `DUPLICATE-OF`, or remediated appears
   **verbatim** in `CHANGELOG.md`. Control in the same invocation: an impossible id returns 0
   while a known-cited id returns non-zero.
3. `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` is green on every release branch, with each
   changed fixture read by name against an impossible-name control.
4. **No write by this program reached graph.** The Phase 0 baseline of **35** is NOT the criterion and
   cannot be: a live graph session is committing and editing there throughout, and it had already
   moved the count to **113** by the time Phase 2 resumed. An absolute count therefore measures
   graph's activity, not this program's restraint, and can never come back equal — it is the
   unreachable-criterion shape this plan is required to avoid. Assert instead that no path this
   program could write is dirty **by content**: the ledger's md5 is unchanged across the phase, and
   `git -C /Users/n8/git/graph diff --stat` names no file this program touched. Record the count as
   an observation, never as a gate.
5. **Split by channel, because one criterion over both sets is unreachable for half of it.** For the
   closes whose `final-disposition.tsv` channel is `changelog-cite` — 25 of 39 — the Phase 5
   `ledger-reverify.sh` run emits a `NAMED-UPSTREAM` row for every id cited, joining on the full
   slug so none degrades to `NAMED-UPSTREAM-AMBIGUOUS`. **That row comes from the RELEASE COMMIT
   MESSAGE, not from `CHANGELOG.md`** — see the correction under "Start here". A run of this
   criterion against a release that cited only in `CHANGELOG.md` returns zero rows and is the
   unreachable-criterion shape, measured: 21 of these 25 produce no row today. For the 14 whose
   channel is
   `brief-annotation`, that row **cannot exist** — `flush()` gates on `has_verify &&` and
   `named_absorbed()` rejects a non-id-shaped label — so the criterion is instead that the brief
   renders the exact strict `**ADOPTED UPSTREAM (vX.Y.Z, verified <date>)**` string for each, and
   that `ledger-rotate.sh --check` would archive it. Derive the two sets in the same invocation from
   the channel column; do not hand-list either.
6. The `HOLDS` set is empty — every entry is either remediated and cited, or filed as a `BL-`
   entry in `docs/backlog.md`.

## Hazards

- **A false CLOSE is the worst output in this system.** It retires a live defect and is
  indistinguishable from an ordinary absorption. That is why every close verdict carries a second
  refuting verifier.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, unquoted `$var` is not word-split, and `:c`/`:t`
  eat unbraced rev-path references — always `"${sha}:core/…"`. Force `bash -c` for any loop or
  heredoc. Never feed `grep -q` from a pipe: it exits at first match and `pipefail` turns the
  writer's EPIPE into a false NOT-FOUND on large files, which this ledger is.
- **Run `awk` over the ledger under `LC_ALL=C`.** Measured in planning: a multibyte em-dash aborted
  an `awk` mid-file with `towc: multibyte conversion failure`.
- **`bash` is 3.2.** No `mapfile`, `readarray`, `declare -A`, `setsid`; an empty array under `set -u`
  is an error.
- **A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
  that comes back non-zero, and both are reported.
- **The consumer runs its own installed engine.** Fixing `ledger-reverify.sh` here does not help
  graph until graph pulls. Run the fixed copy locally against graph's ledger for this program's
  own use, but the brief must be actionable under the engine graph has installed today.
