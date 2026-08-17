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

**PHASE 4 IS COMPLETE. THE BRANCH IS MERGED INTO LOCAL `main` AT `3217cde` AND CANNOT BE PUSHED.**
The full gate was run the way the hook runs it and is GREEN — **157 fixtures, 157 ok, 0 FAIL,
`pre-push: all gates green`** — with all six fixtures changed on the branch read BY NAME in the
full output against an impossible-name control returning 0 and a present-name control returning
non-zero, in the same invocation. `validate-release-version.sh` PASSes over the 58-commit range.
The merge precondition held: local `main` was at `origin/main` with zero commits ahead.

**`git push` returns 403 and the reason is an identity, not a protection rule.** The credential
helper authenticates as `ats0012_amway`, which has no write access to `euron8/ai-dlc`:
`remote: Permission to euron8/ai-dlc.git denied to ats0012_amway`, exit **128**. Nothing can be
pushed from that session — not `main`, not the branch. **Read the exit code without a pipe**: a
`git push … | tail` reports `tail`'s status and prints `exit=0` over a failed push, because this
shell has no `PIPESTATUS`.

**EVERYTHING IS PUSHED. `origin/main` carries v0.373.0 and the finished brief, and the consumer is
pulling it.** Phase 5 step 21 is RUN and its evidence is promoted — see action 4. **Phase 3 is not
started and is now HELD by operator ruling until the pull is adjudicated**, not merely unscheduled;
a fresh session stands by and adjudicates rather than cutting a release branch. See action zero,
which overrides the numbered sequence.

**Two claims elsewhere in this file are WRONG and both would cost a fresh session real work.**

**`named_absorbed()`'s `tail -1` is not always the correct answer, and the paragraph under "Start
here" says it is.** That paragraph reasons that re-naming an id already named by an earlier release
"still reports the release that first named it, which is the correct answer". For pin 4216,
`PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION`, it is the WRONG answer. v0.372.0
named it first, at `1537e4c`, and that close was REFUTED — the gate did not arm on the reference
consumer at all. The actual fix is `9cbb77f`, which `git merge-base --is-ancestor` puts INSIDE
v0.373.0 (0 one way, 1 the other, against a self-comparison control of 0). Both commits now match
the grep, oldest wins, so the mechanical channel will report absorption at the release that did not
fix it and no amount of re-citing can move it. That entry therefore carries `verify: manual` and
needs an operator-chosen version. **A first naming that was a false close makes "the release that
first named it" the one answer you must not report.**

**"Still owed as FIXES, not filings" under Phase 2 is STALE — both landed in v0.373.0.** The
recovery gate not arming on a bare-basename step file, and the gate treating a partial read as a
full one, are both fixed and guarded: `core/hooks/ai-dlc-recover-gate.sh:118` distinguishes a
partial read from a full one, and `core/fixtures/postcompact-rulebook-recovery/run.sh` carries
eight bare-basename references, two mutant arms over exactly that case, and a near-miss arm at
`:527-528` establishing that an `offset:1` Read IS a full read and must be allowed. The fixture
PASSes. A session following that line literally would rebuild two fixes that already exist.

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

**The pin HOLDS, and graph `HEAD` HAS MOVED PAST `510e4d9f5`. Those are not in tension, and a
session that treats the second as breaking the first will re-derive this from scratch.** The
`HEAD` row in the pin table above is the sha the pin was TAKEN at, not a quantity that stays
true; graph commits on its own schedule and has done so repeatedly since. What is pinned is the
ledger's first 4356 lines, and that reconstruction is verified rather than assumed: `sed -n
'1,4356p'` reproduces `2fd444dcf406cdff728fe3c0c4352267`, with the 4355-line control producing a
different digest.

**The delta is a pure APPEND and that is why the pin survived a moved `HEAD`.** The ledger blob at
`510e4d9f5` is **4312** lines because the pin was taken against graph's WORKING TREE while those
lines were still uncommitted; `8ad601f87` then committed them as a 191-line append at line 4311
with **zero deletions**, and `4312 + 191 = 4503`. Its four entries are all already adjudicated —
pin 4313 as `BL-062`, and 4357 / 4392 / 4435 as `BL-063`–`BL-065`. **No new graph filings**, so the
post-pin adjudication still covers everything.

**Re-derive the delta, do not re-derive the pin.** `git diff --numstat <pinned-HEAD>..HEAD --` the
ledger path answers in one command whether a `HEAD` move touched the pinned region; a non-zero
deletion count or a hunk starting below 4356 is the only state that breaks the reconstruction, and
the md5 says so independently. Consumer dirty count observed at 3 here and at 113 earlier in the
program; that is an observation and never a gate, per done-when 4.

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

**THE PULL IS DONE AND ADJUDICATED. graph MERGED v0.373.0 AT PR #935, `0 HARD blockers`.** Sections
A and B of the brief are NOT yet applied and are the only step outstanding on the consumer side.
What the pull produced, all of it adjudicated live:

- **Two upstream defects, both real, both now filed.** graph filed `PC-S334-ABSORBED-AT-READS-THE-`
  `VERSION-BLOB-AT-THE-FIX-COMMIT` — verdict **HOLDS-WIDER**. `absorbed_at()` reads `VERSION` at the
  commit that introduced the substring, but a fix lands while `VERSION` still holds the previous
  number, so it reports one release early: 40 of the 68 commits in `b1ee196..858f4f5` carry the
  pre-bump value. **The filing's scope was wrong in both directions** — `absorbed_at` has TWO
  invocations (`:905`, `:934`), not three, and the cited lines 271/427/455 are not call sites at all
  but the three instances of the `git show "${_c}:VERSION"` IDIOM, in `absorbed_at`,
  `named_absorbed` and `named_ambiguous`. The filing named the true scope while mislabelling it.
- **The widest instance is `named_absorbed()`, filed separately**, because the fault is the JOIN and
  not the version read, so the forward-walk remedy does not reach it. `_c` is the OLDEST commit
  whose MESSAGE contains the id, and `$na_v` from it is interpolated into a paste-ready PERMANENT
  annotation at `:848`. Measured over the 29 ids in `e939a92`'s message against
  `final-disposition.tsv`: **28 of 29 disagree with the adjudicated version**, 20 resolving to
  `e939a92` itself. Four of the nine older resolutions are THIS PROGRAM's own `docs(plan)` and
  `docs(reviews)` commits, which merely MENTION the id — the same reads-vs-mentions class as
  `receipt_absent_subjects`. **And this plan CAUSED the 20-row case**: the correction requiring every
  closed id in the release commit MESSAGE is what makes the join resolve there.
- **`closes_when` is free prose that nothing parses**, found by graph. Read at
  `audit-layer-debt.sh:108` and printed at `:215-216`; `migrate-artifact-paths.sh` has zero hits for
  it against a `strip_token` control of 3. Six layer debts came due the instant graph ran that
  migration and nothing announced it.

**A BLOCKER WAS FOUND IN THIS PROGRAM'S OWN BRIEF, ONE STEP BEFORE IT WAS APPLIED, AND IS FIXED.**
`render-brief.sh` rendered ONE annotation string from the pulled version and instructed it into all
57 entries of sections A and B — while 34 section-A rows are adjudicated `ALREADY-FIXED-v<X>` across
29 distinct versions from v0.21.0 to v0.372.0, and **not one** is adjudicated at 0.373.0. A literal
application stamped v0.373.0 as permanent provenance onto an entry the same brief adjudicates as
fixed in v0.21.0 — precisely the failure `absorbed_at()`'s header was written about, re-introduced
at the human layer. **Arm 1 could not see it**: both enforcers check only the FORM, bold and a digit
after the `v`, so it proved the string well-formed and nothing proved it TRUE. Each row now carries
its own paste-ready string, and **ARM 4** reads the RENDERED artifact — not the map, which would be
a tautology — and refuses when an annotation contradicts its own row's verdict. Proven both
directions: the one-version-for-all mutant refuses at exit 8 naming the pins, the clean render
passes, and 7 version-less rows correctly do not trip it.

**START HERE ON A FRESH SESSION — the numbered next actions.**

**ACTION ZERO: THE PULL IS ADJUDICATED. PHASE 3 REMAINS HELD UNTIL THE OPERATOR LIFTS IT — DO NOT
CUT A RELEASE BRANCH ON YOUR OWN AUTHORITY.** The hold's original reason (do not move `origin/main`
under a consumer mid-pull) has EXPIRED: graph merged at PR #935 and step 21 is banked. The hold is
now a sequencing decision only the operator can take, per `operator-rulings.md` — scope is theirs to
change, never yours. Ask; do not infer that an expired reason lifts a standing ruling.

Do these three things, in this order, and then hold:

1. **Read `docs/reviews/graph-ledger-adjudication-brief.md` and the EXPECTED-OUTCOMES list below
   before looking at any output from the pull.** Most of what the pull reports is already known and
   already measured. A session that reads the output first will file expected results as regressions.
2. **Re-establish the pin** (see "Re-establish the pin"). One command, and every line number in the
   register and the brief depends on it.
3. **Confirm the read/write boundary still holds.** `/Users/n8/git/graph` is READ ONLY even while
   adjudicating its pull. Record the ledger md5 before your first action and assert it after every
   phase; assert by CONTENT, never by the dirty count, which measures graph's activity and not your
   restraint.

**Then adjudicate on request. Report on any question, any decision, and any early stop.**

**THE EXPECTED-OUTCOMES LIST. Every row here is a MEASURED prediction, not a reassurance — if the
pull produces one of these, it is the design working and not a defect to file.** The whole point is
that this program's own instruments produce several results that read like regressions.

| what the pull or a reverify reports | why it is EXPECTED |
|---|---|
| 10 entries report `NEEDS-REVIEW` where a `CLOSE-CANDIDATE` was earned | `receipt_absent_subjects` harvests a distribution path from the receipt text. Pins 654, 673, 798, 1069, 1093, 1136, 1240, 1381, 4184, 4313. See action 3b. |
| `RECEIPTS-UNDECIDED  28 of 28` still present | The replacement receipts are in the BRIEF. That line closes only once graph pastes section E. |
| 7 `NAMED-UPSTREAM-AMBIGUOUS` rows | Sprint-prefix labels, pre-existing, resolved per entry at step 11. |
| pin 4216 has no version to annotate | Its close was refuted, `9cbb77f` fixed it inside v0.373.0, and `named_absorbed()`'s oldest-wins reports the refuted 0.372.0 forever. Operator picks 0.373.0 by hand. See action 3b. |
| an annotated entry vanishes from the report entirely | Correct: *any* occurrence of `ADOPTED UPSTREAM` makes `ledger-reverify.sh` skip the entry. That is also why the strict form matters — see the next row. |
| an annotated entry is skipped **and** never archives | **This one IS a defect and the annotation is the cause.** `ledger-rotate.sh` archives only on `/\*\*ADOPTED UPSTREAM \(v[0-9]/`. A versionless paste makes the entry invisible AND unarchivable. Check the paste before hunting the rotator. |

**AND ONE THING THAT IS NOT ON THAT LIST, SO A FAILURE THERE IS A REAL FINDING.** The consumer's
engine runs an `sh` receipt with the cwd at `$CONSUMER` — `ledger-reverify.sh:954` is
`bash -c "cd \"$CONSUMER\" && { $rest; }"` — while `extract-receipts.sh` measured every receipt with
the cwd at `$DIST`. Those are two different harnesses and the receipts were only ever proven under
one. **Re-measured under BOTH before this file was written: all 37 `sh` receipts report `rc=0` at the
consumer cwd, 0 diverging, with the two cwds asserted to differ before the comparison was read.** So
the receipts are cwd-invariant, and a receipt misbehaving on the consumer is a genuine signal rather
than a harness artefact. That is the discriminator; do not spend the session on the harness.

0. **THE MERGE AND THE PUSH ARE DONE, AND SO IS STEP 21. Nothing in this action is owed** — it is
   kept because the credential mechanism below is not recorded anywhere else, and a session that has
   to push will need it.
   `main` carries the v0.373.0 release and all of Phase 4. The gate was run the way the hook runs it
   twice, green both times — **157 fixtures, 157 ok, 0 FAIL** — with all six fixtures changed on the
   branch read BY NAME against an impossible-name control returning 0 and a present-name control
   returning non-zero, in the same invocation. `validate-release-version.sh` PASSes over the range.

   **The push identity is project-scoped now, and the mechanism is worth knowing before you touch
   it.** `git push` used to fail **403 as `ats0012_amway`**, which has no write access to this
   remote; `gh api repos/euron8/ai-dlc` reports `push: false` for that account against `push: true`
   for `euron8`, control in the same invocation. `.git/config` now sets
   `credential.helper` to `~/.gh-credential-euron8` — a helper that shells out to
   `gh auth token --user euron8` at each use, so it stores no secret and picks up a rotation
   automatically — plus `credential.https://github.com.username euron8`, and an empty
   `credential.helper` entry ahead of it to reset the inherited global `osxkeychain` helper. That
   config is LOCAL, so other repos keep their own default.

   **Two ways this bites, both measured here.** A `core.askpass` script that calls `gh` hangs git
   indefinitely, and `GIT_TERMINAL_PROMPT=0` does NOT make it fail fast — if git wedges with no
   output, that is the shape; use the credential helper, not askpass. And
   `git push --dry-run | tail` printed `exit=0` over a push that really exited **128**, because this
   shell has no `PIPESTATUS`. **Read a push's status without a pipe.**

1. **Re-establish the pin** (see "Re-establish the pin", below). It held across this entire session:
   graph `HEAD` is still `510e4d9f5`, the live ledger is 4503 lines, and `sed -n '1,4356p'` reproduces
   `2fd444dcf406cdff728fe3c0c4352267` with the 4355-line control differing. Verify anyway; it is one
   command and every line number in the register depends on it.

2. **PHASE 4 IS DONE. Nothing is owed here. Read this only to know what changed under you.**

   **Step 19's real population was 42 receipts, not the 14 this action used to describe.** The step
   covers "each of the 28 undecided `theirs_has` receipts" AND "every open entry the Phase 0
   residual showed carries no directive at all", and only 14 had been drafted. Joining
   `adjudicable-entries.tsv` against `final-disposition.tsv` over the LIVE rows: **18** carry
   `theirs_has`, **22 carry NO DIRECTIVE AT ALL**, and 2 of the 3 post-pin entries carry none
   either. The no-directive class is the quieter half and the worse one — `flush()` gates on
   `has_verify &&`, so those entries emit no row in any reverify report: not open, not closed, not
   needing review, invisible to the closer. A zero CLOSE-CANDIDATE count over a corpus holding 22
   of them means nothing, which is the same shape as the finding that started this program.

   All 42 exist, and coverage is JOINED rather than asserted: the 42 receipt pins against the 42
   owed pins have symmetric difference **EMPTY**, with a control confirming the comparison fires on
   a one-line mutant. 37 measure `rc=0`; 5 are `verify: manual`, each naming the structural fact
   that blocks a predicate rather than the difficulty of writing one; every `sh` receipt carries the
   `exit 127` guard.

   **`extract-receipts.sh` is new and is the ONLY parser of the batch markdown.** Eight arms, each
   probed both directions. Two of its rules were learned from the corpus and matter to anyone
   adding a batch: the `rc` column is MEASURED by running the receipt, never parsed out of the
   prose — `step19-receipts/batch-3.md:123` states "measured rc=1 today" about an ABSENCE arm inside
   a section whose receipt measures 0 — and the `label` column comes from the census, never from the
   batch heading, because `batch-3.md:186` abbreviates its own label by five words. Its probe found
   its own arm-ordering bug: a tab inside a receipt was caught by the verb arm rather than the tab
   arm, so the tab arm now runs first and the file says why.

   **`run-receipts.sh` no longer parses the markdown.** It reads the TSV, re-runs every receipt
   independently, and asserts both that each measures zero and that it AGREES with the recorded rc.
   Its coverage arm is a COUNT of pin headings rather than a parse, so a batch file that gained a
   section the TSV does not carry cannot pass.

   **Three defects were in the promoted Phase 4 machinery, all found by running it:**

   `render-brief.sh` derived the step-12 population from the AUTHORING SESSION'S SCRATCHPAD under
   `/private/tmp/…/<uuid>/scratchpad`. It still existed, so it still worked. When it stops existing
   nothing errors: the script sets `-u` but not `-e`, so a glob matching nothing feeds `awk` no
   files, the population derives to ZERO pins, and sections B, C and D all mis-partition while the
   arithmetic line still prints a sum. It now reads the promoted `filing-population.tsv`, verified
   symmetric-difference EMPTY on field 2 against the scratchpad copy while that still existed, with
   fields 1 and 3 differing by 67 and 118 as the control that the comparison discriminates.

   **Section E's polarity prose was INVERTED for its own subject.** It read "Every one was RUN and
   exits non-zero today … a receipt exiting 0 now is already broken" — `backlog-reverify.sh`'s
   sense, in a section whose receipts are read by `ledger-reverify.sh`. The brief would have told
   graph that all fourteen working receipts were broken and that a false close was the correct
   state. Section C's identical wording is CORRECT and stays, because C is about upstream's own
   `docs/backlog.md`. **The two engines' senses sit four hundred lines apart in one generated file;
   check which engine a paragraph is about before trusting its polarity.**

   **A new arm, ARM 4b, refuses when two batch sections claim the same pin.** Added when three
   authoring agents looked silent and replacements were about to be written to different filenames.
   Two files covering one pin emits two rows for one entry, the brief renders the pin twice with
   different receipts and no statement of which is current, and the coverage count still balances
   because it counts headings.

   **Section F is new** — the three post-pin entries, outside the 115-row partition by construction,
   joined to `BL-063`–`BL-065`. The join FLATTENS the entry body first, because `line 4357, past the
   4356-line pin` wraps in this hard-wrapped file; control in the same invocation, an impossible
   line number joins to nothing.

   The brief renders at **A=39 B=18 C=41 rows/42 entries D=17 E=42 F=3** and the A–D partition
   closes at 115. `render-brief.sh --check` and `extract-receipts.sh --check` both pass.

   The superseded sub-actions, kept only because their evidence is cited above:

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

3b. **A DEFECT in the shipped engine that costs 10 of the 42 receipts their mechanical close, and a
   RE-DISPOSITION owed on pin 4216. Both were found by the authoring agents, after their batches
   landed, and neither is in the safe-to-ignore category.**

   **`receipt_absent_subjects` CANNOT DISTINGUISH A PATH THE RECEIPT READS FROM ONE IT MERELY
   MENTIONS. That is the general form, and it is wider than the unanchored-regex framing below.**
   The harvest is a `grep -oE` over the receipt's RAW TEXT, so it collects a `mktemp` scratch root, a
   git exclude pathspec, or any incidental literal exactly as it collects a real subject. Measured
   over all 37 `sh` receipts, the class splits three ways and only two are defects:

   - **10 WITHHELD today** — the distribution-path case detailed below.
   - **2 FALSE-COUPLED**, passing only because the harvested path happens to exist. Pin 334 embeds a
     `mktemp` scratch root spelled `.claude/skills/ai-dlc/extensions`; **pin 267 carries
     `':(exclude).claude/worktrees'`, a git PATHSPEC it is asserting should be IGNORED.** Excluding a
     nonexistent directory is a no-op by construction, so that receipt stays perfectly decisive while
     its close is withheld anyway.
   - **4 that LOOK contingent and are the guard working correctly** — pins 226, 252, 255, 259 spell
     `$CONSUMER/.claude/skills/…` where the path IS the entry's subject, and each receipt's own
     `exit 127` agrees with the engine. The function's header records that a `$CONSUMER/`-prefixed
     spelling is normalised precisely so the two forms cannot disagree about one file.

   **Split the class before calling it a defect** — doing so took this from 6 affected to 2, and the
   sharpest instance came from an authoring agent RETRACTING its own earlier all-clear. A delegate's
   correction is where the finding is.

   **The narrow case, which is the 10:** at
   `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:502-515` the
   extraction is `grep -oE '(\$CONSUMER/)?(docs|_bmad-output|scripts|\.claude)/[A-Za-z0-9_./-]+'` —
   **unanchored** — so a receipt naming `core/scripts/x.sh` yields the match `scripts/x.sh`, which is
   absent under the consumer root, and the caller then withholds the CLOSE-CANDIDATE as
   NEEDS-REVIEW. Measured by lifting that function verbatim and running it over every `sh` receipt
   in `replacement-receipts.tsv`: **10 of 37 affected** — pins 654, 673, 798, 1069, 1093, 1136, 1240,
   1381, 4184, 4313. Controls both directions in the same invocation: a genuinely present consumer
   path (`scripts/ai-dlc/artifact-path-config.sh`) is NOT withheld, and `core/scripts/`
   `validate-locked-anchor.sh` IS.

   **The direction is SAFE and that is why this is a DEFECT rather than a BLOCKER.** The function's
   own header says its caller uses it "to WITHHOLD a CLOSE-CANDIDATE, never to produce one", so the
   cost is that those ten entries need a hand review they should not have needed. No false close.

   **The remedy is one character of indirection, in the receipt and not in the engine**: write
   `S="$DIST/core/scripts"; V="$S/validate-x.sh"` so no literal `core/scripts/…` substring exists for
   the guard to extract. Verified to extract zero paths. Fixing the engine's regex would be the
   better repair but it cannot reach graph until graph pulls, and the brief must be actionable under
   the engine graph has installed TODAY.

   **Pin 4216 wants re-dispositioning to the ADOPTED UPSTREAM channel, cited at 0.373.0.**
   `final-disposition.tsv` still reads `LIVE (close withdrawn) / brief-annotation / no-receipt`,
   written before `9cbb77f` landed. All three surviving sub-claims are now closed and the fixture
   PASSes with by-name arms for each. **The version cannot be 0.372.0**: that is the release whose
   close the refuter overturned, and it is the id's only CHANGELOG cite (`CHANGELOG.md:485`).
   `9cbb77f` wrote NO CHANGELOG entry at all — four files, none of them `CHANGELOG.md` — so the
   0.373.0 section does not name this id and a hand-chosen annotation is the only correct channel.
   Its receipt is already `verify: manual` carrying that reasoning, which is a safe holding state,
   so this is an accuracy improvement to the brief and not a live hazard.

3a. **Two NOTES from the post-pin filing, neither blocking, both worth seeing before writing another
   receipt.**

   **A receipt's own sanity failure is INVISIBLE.** `scripts/backlog-reverify.sh` maps any non-zero
   exit to `STILL-LIVE`, so a receipt that dies at its own `exit 9` guard — subject missing,
   extraction empty, harness broken — reports identically to one that measured a live defect. The
   direction is safe and the silence is not: a receipt can rot into permanent uselessness and every
   run will keep saying "still reproduces here". The consumer's engine distinguishes this (126/127 ->
   NEEDS-REVIEW); ours does not. Filing a distinct status is a candidate for a later pass.

   **`BL-064`'s receipt has a stated dependency**: its diff leg needs `git diff HEAD~1` to be
   non-empty. True today and while `HEAD~1` differs from the tree, but if that ever went empty the
   diff signature would read 0 for a reason unrelated to any fix. Its corpus leg is unaffected, so
   the receipt degrades to half-strength rather than false-closing. Recorded in the entry.

4. **PHASE 5 STEP 21 IS RUN AND DONE-WHEN 5's MECHANICAL HALF IS SATISFIED: 25 of 25.** Run from the
   graph root against the pushed `origin/main` — `bash .claude/skills/ai-dlc-update/reconcile/`
   `ledger-reverify.sh /Users/n8/git/ai-dlc adec9ae /Users/n8/git/graph 5c96500`, exit 0, cwd asserted
   to be the CONSUMER root and never the distribution root. The full output is promoted at
   `docs/reviews/graph-ledger-adjudication-data/step21-reverify-at-0.373.0.log`, byte-identical to the
   run, **because this measurement is PERISHABLE** — an annotated entry emits no row, so once graph
   applies the brief it can never be taken again.

   Every one of the 25 closes whose `final-disposition.tsv` channel is `changelog-cite` — the set
   DERIVED from the channel column, not hand-listed — emits a `NAMED-UPSTREAM` row: **25
   NAMED-UPSTREAM, 0 degraded to NAMED-UPSTREAM-AMBIGUOUS, 0 with no row**, against an impossible-id
   control at 0 and a known id at 2 in the same invocation. **Before the release commit named the ids
   in its MESSAGE, 21 of these 25 produced no row at all.** The run's histogram: 58 STILL-LIVE, 33
   NAMED-UPSTREAM, 25 HAND-REVIEW, 7 NAMED-UPSTREAM-AMBIGUOUS, 1 RECEIPTS-UNDECIDED, 1
   CLOSE-CANDIDATE. The consumer was untouched — ledger md5 identical either side of the run, graph
   `HEAD` still `510e4d9f5`.

   **The other half of done-when 5 — the 14 `brief-annotation` closes — is carried by the renderer's
   own arms, not by this run, and correctly so:** a `NAMED-UPSTREAM` row cannot exist for them
   (`flush()` gates on `has_verify &&` and `named_absorbed()` rejects a non-id-shaped label), so the
   criterion is that the brief renders the exact strict string and the rotator would archive it.
   `render-brief.sh` arm 1 tests the string it generates against BOTH enforcers and refuses if the
   versionless near-miss also passes the strict form.

   **`RECEIPTS-UNDECIDED` still reads 28 of 28**, and that is expected rather than a regression: the
   replacement receipts live in the BRIEF and graph has not applied them. That line is what closes
   when graph pastes section E.

   **Step 22 is DONE.** Step 22 is
   DONE and was re-verified again at wind-down: the pin reproduces, graph `HEAD` is unchanged, and
   the 147 post-pin lines are the three entries above plus one `RETRACTED` banner — **no new consumer
   filings during this run**. Step 21 re-runs `ledger-reverify.sh` from the graph root against the
   new ai-dlc `origin/main`, which now carries the release. Run it BEFORE anything else.

   **Its observation point is BEFORE graph applies any annotation from the brief** — an annotated
   entry is skipped and emits no row, so once graph pastes the section A and B annotations the
   criterion is permanently unreachable and no rerun recovers it. The brief is written and sitting in
   `docs/reviews/graph-ledger-adjudication-brief.md`; the moment it is delivered, this window closes.

   **Do not substitute the local `main` for `origin/main` in that run.** The criterion exists to
   observe what the CONSUMER's engine will see, and the consumer fetches `origin`. A run against a
   local ref no consumer can reach reproduces the shape this plan spent a phase removing.

6. **OWED, AND IT IS THE OPERATOR'S CALL: THREE general rules have no durable carrier, and all three
   are blocked on the same 40 bytes.**

   **The third is that AN UNTRACKED FILE IS NOT A MISSING FILE.** A check built on a committed
   corpus — `git ls-files`, `git show HEAD:`, anything greping a tree — cannot see an uncommitted
   file, and its clean run reads exactly like a real absence. Measured here: three delegated batch
   files were declared missing while sitting on disk as `??`, one of them recorded in a commit
   message as "never written". Before declaring a delegated deliverable missing: `ls` the path,
   `git status --porcelain` for a `??` row, and ask the agent by name. **`grep -rniE`
   `"uncommitted|untracked|ls-files"` over the durable channel returns 0** — established with
   POSITIVE controls in the same invocation, `PIPESTATUS` at 1 and `compaction` at 12, because a
   zero checked only against another zero establishes nothing. It is the same class as `CLAUDE.md`'s
   measured false-zero list and belongs beside it.

   **The second one is a tool hazard and it has cost real work twice.** `sleep` under the Bash
   tool's `run_in_background` **returns immediately**, so a chain of backgrounded "waits" is rapid
   polling that grants a delegated agent no wall clock at all. Measured here: several apparent
   ten-minute waits spanned about one minute of real time, four authoring agents were described as
   silent when they had barely started, and one agent's work was redone inline as a result. Wait with
   a blocking `until` loop on the condition instead. **`grep -c "sleep"` over the durable channel
   returns 0**, against a control of 1 for `PIPESTATUS` — present — and 0 for an impossible token, so
   the gap is measured rather than assumed. Its evidence is in the memory corpus under
   `ai_dlc_v0372_four_push_candidates` and `ai_dlc_v0373_phase4_42_receipts`, which is EVIDENCE and
   not a carrier: a compacted session has not read it.

   **Its natural home is `.claude/rules/tool-hazards.md`**, whose subject is exactly "behaviours
   that return a WRONG answer rather than an error" and which already carries the `PIPESTATUS` and
   `grep -q`-from-a-pipe cases. It cannot be mechanized — nothing in a tracked file expresses it,
   because it happens in a tool call — so by `resident-context.md` it must NOT be scoped, and the
   unconditional channel is the only option.

   **The first one**, unchanged from when it was recorded: this session
   found that **a coverage proof over a derived population cannot see outside it** — step 12's
   census came from the corpus pin, so the check confirming all 59 rows were accounted for was
   CORRECT and structurally blind to the three entries filed after the pin. That is a sharpening of
   `verification-discipline.md`'s existing "Ask what SET a number was taken over", and it belongs
   beside it.

   **None of the three is there, because the durable channel has 40 bytes of headroom** — arm A6
   reports 40920/40960 across 7 files, re-derived at wind-down. Between them the three rules need
   roughly **1300 bytes**. Adding either requires TRADING OUT existing prose, and `resident-context.md`
   forbids trimming for cost and requires grepping for inbound references before any cut. That is a
   deliberate decision, not a mechanical one.

   Today rule one is carried by action 3 of this file, rule two by action 0's hazard note, and rule
   three by the paragraph above — adequate for this program and for nothing else. **A rule whose only
   carrier is a plan file dies with the plan.** The three options, none of which a session may take on
   its own authority: trade out ~1300 bytes of prose that meets the VESTIGIAL test (mechanism
   nameable, instruction authoritative elsewhere, inbound references grepped); raise A6's 40960
   ceiling, which is a budget decision; or accept that all three stay uncarried and will be relearned.

   **All three were learned the same way in one session, which is itself the argument for spending
   the bytes**: each cost real work, none is mechanizable — two happen inside a tool call and the
   third is a judgement about a population — and `resident-context.md` forbids scoping a prose-only
   rule, so the unconditional channel is the only place any of them can live.

5. **PHASE 3 IS HELD, BY OPERATOR RULING, UNTIL THE GRAPH PULL IS ADJUDICATED. DO NOT CUT A RELEASE
   BRANCH.** This action previously read "Phase 3 batch 1 is the operator's chosen next session"; that
   was superseded at the close of the same session, once the pull became imminent. Action zero is what
   a fresh session does instead.

   **The hold has a reason beyond sequencing.** A Phase 3 release moves `origin/main`, and the
   consumer is mid-pull against it. Cutting one while graph is applying the brief means the tree it
   pulled and the tree the brief was measured on are different, and every figure in the brief becomes
   a hypothesis again. Step 21 is already banked so nothing is LOST by cutting one — but the
   adjudication of the pull is the work that cannot be redone later, because the pull happens once.

   **Release it when the operator says the pull is adjudicated**, then: cut the first ≤4-remediation
   branch from `origin/main`, one version per branch.

   **Phase 3 is a program rather than a step.** The `HOLDS` set is 42
   backlog entries (`BL-021`..`BL-062`) plus `BL-063`–`BL-065`. Done-when 6 is ALREADY SATISFIED
   — "every entry is either remediated and cited, or filed as a `BL-` entry" — so this is the
   operator's call on sequencing, not a blocker on closing this plan. Batches of ≤4 remediations per
   release branch, one version per branch, cut from `origin/main`.

**AN UNTRACKED FILE IS NOT A MISSING FILE, AND I DECLARED THREE BATCHES MISSING THAT WERE ON DISK.**
The authoring agents wrote their batch files and left them untracked, as instructed. Two separate
mistakes compounded: a backgrounded `sleep` returns immediately here, so three "waits" spanned about
a minute of real time rather than the long silence they were reported as; and a check that cannot see
an uncommitted file reads exactly like one reporting a real absence. `batch-12.md` was recorded in a
commit message as "never written" — **that claim exceeded its evidence.** A direct `ls` returned
ENOENT when it ran, and the agent reports the file on disk at 08:50; the two cannot be reconciled
from here, so the record should say the file was absent WHEN CHECKED, not that it never existed.
Before declaring a delegated deliverable missing: `ls` the path, `git status --porcelain` for a `??`
row, and ask the agent by name.

**`run-receipts.sh` really did iterate `for i in 1 2 3 4`** — verified at `2db4035:24`, exactly as an
agent reported — so over a partial batch set it would have reported a clean run across four files
while ignoring the rest. The rewrite to a TSV-driven runner removed it, and the current runner
reports `42 receipt(s) from 12 batch file(s)`. Recorded because the finding was RIGHT about a version
that existed, and a reader comparing it against the current file would otherwise conclude the agent
was wrong.

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

**THE MIDDLE EDIT THIS SECTION WARNED ABOUT HAS HAPPENED. THE FIRST-4356-LINES RECONSTRUCTION IS
DEAD AND EVERY REGISTER PIN ABOVE 637 IS NOW OFF BY 28.** Do not run the old recipe; it is kept
below only so its failure is legible.

graph applied the brief's close for pin 610 and `ledger-rotate.sh` archived the entry, which is a
**deletion from the middle**, not an append. Derived against the last known-good ref, with the
hunk offsets read rather than guessed:

```
git -C <graph> diff --numstat 2c7935e5d..HEAD -- <ledger>     # 178 insertions, 28 DELETIONS
git -C <graph> diff -U0      2c7935e5d..HEAD -- <ledger> | grep '^@@'
  @@ -610,28 +609,0 @@      <- pin 610's entry, 28 lines, ARCHIVED
  @@ -4503,0 +4476,178 @@    <- graph's two new PC-S334 entries, appended
```

**The mapping, and it is exact:**

| pinned line | where it is now |
|---|---|
| 1 – 609 | unchanged |
| **610 – 637** | **GONE — archived to `push-candidate-ledger.archive.md`** |
| 638 – 4503 | **subtract 28** |
| — | new live lines 4476+ are graph's `PC-S334` filings, outside the pin |

Verified in both directions in one invocation: pin 4313 resolves at 4285 to
`PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG` while line 4313 now holds unrelated
prose; pin 4184 resolves at 4156; and pin 297, below the deletion, is unchanged. The archived entry
appears exactly once in the archive against an impossible-id control of 0, carrying the strict
`**ADOPTED UPSTREAM (v0.373.0, verified …)**` form. Its id still returns 2 hits in the LIVE file —
both are MENTIONS, at pin 177's cross-reference and inside graph's new entry, not the entry itself.
**Grep the id and you will conclude the rotation failed.**

**The superseded recipe, and the reason it worked until it did not:** every graph change had been a
pure append, so the pin was the live file's first 4356 lines, checked by
`sed -n '1,4356p' | md5` = `2fd444dcf406cdff728fe3c0c4352267` against a 4355-line control that must
differ. That held for the whole program and reproduced at `2c7935e5d`. **An append-only assumption
is not a property of the file; it is a property of what the consumer happened to be doing.** The
moment the consumer acted on this program's own output, it stopped being true — so the durable
instruction is the `--numstat` deletion count and the hunk offsets, never a line total.

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
