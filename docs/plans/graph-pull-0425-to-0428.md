# Pull the graph consumer from 0.425.0 to 0.428.0

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/graph-pull-0425-to-0428.md`.**
This block is the whole of your entry point and the only current status record in this file.

**Status: NOT STARTED.** Nothing below has been executed.

### Start here

**Your session's PROJECT ROOT must be `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd`, so a session rooted in the distribution cannot invoke `/ai-dlc-update` at
all. If you are rooted anywhere else, stop and say so.

**The read/write boundary, and it is absolute.** `/Users/n8/git/graph` — the operator's consumer
repo — is the only tree this run WRITES, and the pull itself is what writes it.
`/Users/n8/git/ai-dlc` is the distribution and is **READ ONLY** for this run: read it, never write
it. You are pulling FROM it, and nothing in this runbook edits it. If you find yourself wanting to
change a distribution file to make the pull succeed, stop and ping — that is a defect to file
upstream, not a step here.

**The consumer's tree is dirty and that is EXPECTED.** `_bmad-output/` carries live pipeline
state, and the set of dirty files grows while the pipeline runs, so it is deliberately not
enumerated here. **Do not commit, revert, stash or clean it.** Committing makes the branch ahead
of its remote and the update preflight then auto-pushes in-flight pipeline state on what you
intended as a dry run.

**Do not run `git checkout --`, `git restore`, `git clean`, `git stash` or `git reset --hard`.**

### What this range carries, and what is special about it

**Three releases, `0.426.0`, `0.427.0` and `0.428.0`, and the third one is most of the range.**
Twenty-three changed core paths in all: fourteen modified and three added by `0.428.0` alone.

**`0.428.0` DISCHARGES THE WHOLE SPRINT-306 CANDIDATE SET — SIX CANDIDATES THIS CONSUMER FILED
ITSELF, AGAINST DEFECTS IT HIT LIVE.** They are the reason this pull is worth running, and each
one changes something this consumer touches every sprint:

- `core/skills/ai-dlc/steps/gate-validation.md` — **Check 2's blocking clause is now scoped by
  sprint.** A `HARD_BLOCK` filed by an EARLIER sprint is surfaced at an `implementation`, `story`
  or `retro` gate rather than blocking it, and still blocks at every `planning` and
  `sprint-review` gate. An entry whose header names no sprint blocks everywhere. This is the one
  that cost a live-incident gate an operator round-trip on a nine-day-old sprint-303 entry.
- `core/scripts/validate-suppression-lifetime.sh` — an entry carrying `**Suppresses:**` or
  `**Expires after:**` while its `**Status:**` classifies as anything other than `SUPPRESSED` is
  now REPORTED rather than silently skipped, and the verdict line carries `malformed_attempt=`.
  **Expect this to FAIL on your first gate if any such entry is still in `pending.md`** — that is
  the fix working, not a regression. Set the status to `SUPPRESSED` or remove the fields.
- `core/scripts/validate-gate-adjudication.sh` — `--series` accepts
  `gate-<type>-resolution-p<M>.md` alongside the remediator's repair-record name, so a FAIL closed
  by a lead-authored escalation resolution no longer reads as `MISSING REPAIR RECORD`. The
  structure requirement is unchanged: `disposition:`, `edit:` and `derivation:`, read literally.
  **Your existing `gate-implementation-resolution-p1.md` states all three in prose and labels
  none, so it will score UNSTRUCTURED.** Label the three fields and it closes.
- `core/scripts/report-propagation-fanout.sh` — the corpus is tracked plus
  `--others --exclude-standard`, so artifacts written mid-sprint and not yet `git add`ed are
  visible. The `SCOPING FAILURE` you were getting on a correct tree should stop. The untracked
  share is printed in band.
- `core/scripts/validate-stub-audit.sh` — `Phase [0-9]` counts as a stub marker only inside a
  statement of absence. The docstring reword that cleared your last Check 16 was not necessary
  and would not be necessary now.
- `core/skills/ai-dlc/steps/bug-investigation.md` and `steps/implementation.md` — a FAIL on a
  check the next step does not consume repairs in PARALLEL with the routing, and Section 7's
  completion condition names the entering gate so nothing lands over a FAIL.

`0.426.0` and `0.427.0` carry the re-stamp withholding and its finisher, and they are what the
rest of this file is about:

- `core/skills/ai-dlc-update/reconcile/apply.sh` — the re-stamp is now WITHHELD while any
  `WORKLIST` or `DECISION` row is outstanding, and a new `--finish` mode advances it once the
  rows are disposed. `--finish` also refuses an unresolvable `<theirs>` or `<dist>` rather than
  writing the literal argument into `commit:`. This is the behaviour change that matters to you.
- `core/skills/ai-dlc-update/SKILL.md` — step 7 instructs `--finish` in two places.
- `core/git-hooks/pre-push` — `applying_guard()`'s message now separates the two reasons a
  re-stamp is withheld and names `--finish` for the one a re-run cannot resolve.
- `core/skills/ai-dlc/core-manifest.md` and
  `core/skills/ai-dlc-update/reconcile/setup-sites.md` — one manifest row each for the new
  fixture.
- `core/fixtures/apply-restamp-worklist/` — new, shipping.

Between them these three releases discharge **seven** candidates:
`PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` and the sprint-306 six —
`PC-S306-CHECK-2-HAS-NO-SPRINT-SCOPE`,
`PC-S306-SUPPRESSED-STATUS-FIRST-TOKEN-SILENT-NO-OP`,
`PC-S306-SERIES-VALIDATOR-NO-LEAD-RESOLUTION-PATH`,
`PC-S306-FANOUT-UNTRACKED-FILES-INVISIBLE`,
`PC-S306-GATE-REMEDIATION-BLOCKS-INDEPENDENT-DEV-DISPATCH` and
`PC-S306-STUB-AUDIT-PHASE-N-MATCHES-WORD-BOUNDED-PROSE`.

**THE CORRECTED `pre-push` MESSAGE ARRIVES ONE PULL BEHIND ITSELF, AND THAT IS NOT FIXABLE IN
CODE.** `core/git-hooks/pre-push` is a consumer file this pull WRITES, so during this pull the
consumer is still running the OLD guard text — the one that says "re-run; it resumes and
re-stamps when the tree is consistent" and never mentions `--finish`. If this pull withholds and
you then hit that message, **ignore its first remedy and use `--finish`.** The rehearsal below
predicts the copy that actually runs this pull will stamp without withholding, so this stays a
contingency — but it is a nearer one than it was, because the same rehearsal shows the INCOMING
copy withholding on eight outstanding rows.

The guard this release changes is `core/skills/ai-dlc-update/reconcile/apply.sh:1199` in the
distribution, and the refusal that makes a withheld stamp consequential is
`core/git-hooks/pre-push:767`, dispatching `applying_guard()` at `:717` — it REFUSES the fixture
suite rather than skipping it while `.claude/.ai-dlc-applying` exists. (Both re-derived at
`0.427.0`; the guard moved when its message was rewritten, so a figure copied from the `0.426.0`
draft of this file would not resolve.)

**A BOOTSTRAPPING STEP IS IN THE RANGE, AND THE HAZARD IS MEASURED RATHER THAN WARNED ABOUT.**
`apply.sh` IS the program this pull runs, so the consumer's INSTALLED copy applies the release
that repairs it. Re-measured for the widened range on a `file://` clone of the distribution
against a scratch copy of this consumer's committed `HEAD`, with the two `apply.sh` copies
asserted to differ before any reading was taken: the installed copy carries `--finish` **0**
times and `handback` **0** times; the incoming copy carries `--finish` **22** times and
`handback` **5**. **So the withholding still takes effect on the pull AFTER this one.** This pull
is classified and applied by the OLD program throughout.

**THE MODE-ONLY HAZARD IS MEASURED AND ABSENT.** `git diff --raw` over the whole range across
**23** changed core paths reports **0** mode-only changes — modes differing with blobs equal. The
three mode transitions in the range are all `000000 -> 100755` file ADDS, which take the `A`
branch and not the `M` branch the defect lives in.

**That is the good case for the STAMP. It is not the good case for the WORKLIST, and that has
changed since this file was first written — read the rehearsal.**

### The rehearsal, and what to do when the real run disagrees

Rehearsed on a `file://` clone of the distribution against a scratch copy of this consumer's
committed `HEAD` — never against this tree in place. **These are an EXPECTATION, not a
guarantee.** The consumer has moved since the rehearsal, and every figure here is a hypothesis
about a tree that changes.

`preclassify.sh` produced **23 rows**:

| bucket | count |
|---|---|
| `UPSTREAM-ONLY` | 19 |
| `UPSTREAM-ONLY-ADD` | 2 |
| `DIST-ONLY-SKIP` | 2 |
| `->CLASSIFY` | **0** |

The two `DIST-ONLY-SKIP` rows are `core/fixtures/gate-repair-record-mutants/`, a mutation battery
that carries a `.dist-only` marker and is correctly not shipped.

`apply.sh` was then driven for real, twice — once with the consumer's installed copy and once
with the incoming one. **They no longer agree, and the disagreement is the point:**

```
installed apply.sh   21 RESOLVED pure-apply, 1 RESOLVED driver-self-update,
                     1 RESOLVED restamp, 1 RESOLVED consistent, 1 NOTE override-adjudicated,
                     8 WORKLIST extension-reread
                     stamp -> 0.428.0        .ai-dlc-applying -> ABSENT
incoming  apply.sh   21 RESOLVED pure-apply, 1 NOTE override-adjudicated,
                     8 WORKLIST extension-reread, 1 DECISION restamp-withheld
                     stamp -> 0.425.0        .ai-dlc-applying -> PRESENT
```

`RESOLVED driver-self-update` appears only under the installed copy: that row IS the old driver
replacing itself mid-run, which is the bootstrapping event named above. **The installed copy is
what actually runs this pull, so the STAMP is expected to advance and the marker to clear.**

**EXPECT EIGHT `WORKLIST extension-reread` ROWS, AND THEY ARE REAL WORK RATHER THAN NOISE.** This
range changes `steps/gate-validation.md`, `steps/bug-investigation.md` and `steps/implementation.md`
— three core files this consumer's own extensions hook into. The eight entries are
`extensions/checks/attribution-provenance.md`, `extensions/checks/gate-validation-domain.md`,
`extensions/checks/gate-validation-push.md`, `extensions/checks/validator-honesty.md`,
`extensions/steps-domain/bug-investigation-domain.md`,
`extensions/steps-domain/bug-investigation-push.md`,
`extensions/steps-domain/implementation-domain.md` and
`extensions/steps-domain/implementation-push.md`. Each has to be re-read against the new core text
and given a verdict — still-additive, contradicts-core, or retire. **Check 2's new sprint scoping
is the change most likely to make an extension entry contradict core**, so read the two
`gate-validation-*` entries against it first.

**THE PREVIOUS REVISION OF THIS FILE PREDICTED ZERO `WORKLIST` ROWS AND THAT PREDICTION IS
WITHDRAWN.** It was taken over the `0.425.0 → 0.427.0` range, which touched no step file. Do not
read a `WORKLIST` row here as a disagreement.

**STOP AND PING THE OPERATOR if the real run disagrees with the table above** — specifically if
the stamp does NOT reach `0.428.0`, if `.claude/.ai-dlc-applying` is still on disk when the run
ends, if any `DECISION restamp-withheld` appears, if any row buckets `->CLASSIFY`, or if the
`WORKLIST` count is not 8. A disagreement is information and is worth more than a clean report.
It does not mean the pull is broken; it means the consumer moved and the rehearsal's premise
expired.

**THE CONSUMER WAS BEING WRITTEN WHILE THIS REHEARSAL RAN.** Its ledger's md5 moved three times
during the release that produced this range, and a seventh sprint-306 candidate was filed
uncommitted while the rehearsal was in progress. The scratch copy was taken from committed
`HEAD`, so anything filed after that is not in these figures.

**If the run DOES withhold**, it is not a defect and there is nothing to debug: dispose of every
`WORKLIST` and `DECISION` row it printed, then run the finisher. The withheld row prints the
exact command, machinery flag already resolved. Do not hand-edit the stamp.

**COPY THAT COMMAND CAREFULLY.** It prints `<dist>` and `<consumer>` as literal placeholders and
passes `<theirs>` through verbatim, so you are substituting three arguments by hand into the one
invocation that writes the next pull's merge base. `0.427.0` makes a wrong one REFUSE — you get
`DECISION restamp-unresolvable` and nothing is written — but the copy the consumer runs during
THIS pull is the `0.425.0` one, which has no such refusal. Check the substitutions before you
press return.

**A re-run of `/ai-dlc-update` does NOT clear a hand-back row.** Those rows are derived from the
upstream range against your extensions, not from the tree, so an ordinary re-run re-emits them
and withholds again. `--finish` is the only exit for that case. Measured on a consumer with an
empty adjudication register: three consecutive ordinary applies, 11 rows each time.

### Numbered actions

1. **Confirm your project root is `/Users/n8/git/graph`.** If it is not, stop and ping.

2. **Run `/ai-dlc-update`.** Do NOT re-describe or re-implement the pull here — the skill owns
   resolving the ref, gating its self-update, carrying the machinery slice and emitting the
   worklist, and its own report is the authority. Write no ref and no sha into this file.

3. **Compare the run's manifest against the rehearsal table above.** Report both. If they agree,
   say so; if they do not, stop and ping before applying.

4. **If and only if the run emitted `DECISION restamp-withheld`:** dispose of every `WORKLIST`
   and `DECISION` row, then run the finishing command exactly as that row printed it. Confirm
   afterwards that `.claude/.ai-dlc-version` reads `0.428.0` on all four fields and that
   `.claude/.ai-dlc-applying` is gone. This is a CONDITIONAL action and the rehearsal predicts it
   will not fire.

5. **Close the candidate, by id.** Run `ledger-reverify` **from the consumer root** — a run from
   the distribution root has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false
   close retires a live entry. Then report which of these closed and which did not:

   - `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE`

   The pull is not the point; the ledger closing is.

6. **AFTER THE RUN, BEFORE YOU STOP: re-derive this file's own RESUME block and fill in
   `## Discharge`.** The moment the pull lands is the moment this handoff goes stale — the block
   you just followed becomes a description of finished work, and a session that stops there hands
   the next one an instruction to redo the pull. Change `Status: NOT STARTED` to what actually
   happened, replace the rehearsal table with the run's real numbers, retitle the file
   `DISCHARGED — DO NOT EXECUTE`, and commit it. Fix the COMMANDS, not only the prose.

7. **Report to the operator**, including an early stop.

### Ping the operator

**On any question, on any decision, on completion, and on any early stop.** From outside, a
session that is thinking and a session that is waiting on a human look identical. Merges are
preapproved — do not stop to ask for one.

### Done when

1. `.claude/.ai-dlc-version` reads `0.428.0` on `version`, `commit`, `skill_version` and
   `skill_commit`. **Observation point: after action 4, or after action 2 if action 4 did not
   fire.** Reachable today: the rehearsal reached exactly this state under both drivers.
2. `.claude/.ai-dlc-applying` is absent. Same observation point.
3. `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` is reported closed or the reason it
   is not is stated. **This one may legitimately come back NOT closed** — the ledger entry is
   `verify: manual`, so `ledger-reverify` cannot adjudicate it mechanically and will say so.
   That is a PASS for this criterion provided you report which it was; it is a FAIL only if
   nobody looked.

## Discharge

*Left empty for the executor. Fill it in when the run is done, then retitle this file
`DISCHARGED — DO NOT EXECUTE`. A spent runbook still reading as instructions is this
directory's recurring hazard — measured once at 5 of 6 files.*
