# Drafted CHANGELOG body for the close release — NOT YET RELEASED

The 25 sections below are the closes whose `final-disposition.tsv` channel is `changelog-cite`.
Each names its `PC-` id verbatim; verified 25 of 25 against an impossible-id control. They are
drafted, reviewed against the refutation evidence, and **not yet spliced into `CHANGELOG.md`** —
no `VERSION` bump and no `## [X.Y.Z]` heading exists for them.

**THE ID MUST ALSO GO IN THE RELEASE COMMIT MESSAGE, and that is the part a reader will skip.**
`named_absorbed()` at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402` resolves the
consumer's `NAMED-UPSTREAM` signal with `git log -F --grep`, which reads COMMIT MESSAGES. A
section in this file lands in the commit's DIFF, never its message, so on its own it produces no
row. Measured over these same 25 against `origin/main`, both channels in one invocation: 4 in a
commit message, 8 in the `CHANGELOG` blob, 16 in neither — and the four that sit in the
`CHANGELOG` and not in a message are the proof, because they are cited exactly as intended and
resolve to nothing. Control: an impossible id returns 0 from both.

Derive the set, never retype it:

```
awk -F'\t' '$5 ~ /^CLOSE/ && $7=="changelog-cite" {print $2}' final-disposition.tsv
```

Delete this file when the release lands; its content will live in `CHANGELOG.md`.

---

### `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK` — FALSIFIED, and false at the entry's own re-verification base

The sentence the entry reported missing was present at the tree the entry names as its own base:
`git show "f4845a9:core/skills/ai-dlc/steps/gate-validation.md"` carries it at `:146` and `:1530`,
control 43 `CHECK_LOADED` markers in the same blob. It landed in `b7112d7`, six days before the
filing. The re-verification missed it mechanically — its predicate anchors on `solo-evaluat`, a
hyphenation the filing invented, while core spells the concept `inline-evaluating`. The remaining
sliver stays falsified rather than narrowed: it is not the entry's observed subject (the observation
is the no-dispatch case, which Check 26 catches fail-closed), and it is the remedy the entry itself
refused as false-positive-prone.

### `PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS` — closed only as an APPLIED merge, never as a plain retirement

The duplicate relation and the survivor direction both hold, and the entry's clause (c) does not:
this entry carries four items absent from its survivor, including **the only mechanical verify anchor
either entry has**. The survivor is `verify: manual` and its own body says no mechanical anchor was
derivable. Retiring this one on the duplicate relation alone would delete that anchor permanently —
and the survivor carries a reciprocal duplicate declaration naming *this* entry as the survivor, so
an adjudicator reading either alone has textual grounds to close it into the other. The pair is one
careless pass from vanishing. The mechanical half is preserved as `BL-012` in `docs/backlog.md`, and
`core/skills/ai-dlc/rule-authoring.md` now grants the permitted identifier form the guide was missing.

### `PC-S296-H1-FIXTURE-CITATION-GAP` — the requirement was replaced, not deleted, and the entry's receipt now passes forever

`gate-validation.md:1746-1750` states "The map is the trace from check → fixture", and all five checks
the entry named resolve to fixtures in `enforcement-map.yaml` (control: checks 24 and 27, the entry's
two survivors, are bound there too). `I24` asserts both directions — it errors if the H1 span restates
a fixture path, and if a map-bound fixture is absent from disk. The recorded reason for the change is
that the old hand-list named 7 checks while the map bound 11, so four shipped fixtures H1 could not
see. **Do not inherit this entry's `verify:` one-liner**: it tests for prose upstream now explicitly
forbids, so it exits 0 permanently.

### `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` — both sites are conditional, by two different commits

The entry cites two sites and the earlier close credited one commit for work two did. Both are
conditional at HEAD: `:150-154` from `93e05d3`, and `:349-356` from `b7e0539e` — not `93e05d3` —
carrying `AI_DLC_CI_SURFACE` / `ALIAS_TABLE` and an explicit vacuous `exit 78`. Neither site asserts
the file exists. The attribution is corrected here rather than left as filed. The entry's own `verify:`
names a path absent at HEAD, so its agreement with the close was never independent evidence.

### `PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD` — the sub-claim was refuted by the wrong instrument, not by wrong evidence

Every figure in the entry reproduces: core ships no `validate-retro-prereq.sh`, and `CHECK 4: PASS`
appears exactly once, at the emitter. The conclusion does not follow.
`core/fixtures/mandatory-rules-skip-accounting/run.sh:144` stubs the prereq validator and its arm A
asserts `Sprint 900: all 6 checks passed` at rc 0, which Check 4 can reach only through its PASS
branch. Established behaviourally: mutating `core/scripts/validate-mandatory-rules.sh:233` to
`if false` makes that branch unreachable and the fixture reports `FIXTURE ERROR` with arms A, B and D
falling to `[]/1` and `Check4_DEPLOY_VALIDATE` named; the unmutated control in the same session is
`PASS (10 assertions)`. A grep for the emitted text is the wrong instrument twice over — renaming
`CHECK 4: PASS` to a mutant token kills nothing, because the fixture asserts the summary line rather
than the per-check line. Clean close; the receipt anchor is already present at
`validate-mandatory-rules.sh:55`.

### `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION` — a false zero pinned to the filing's choice of wording

Attacked at the entry's own cited sha and it held: `git show "46aa98a:core/team-roles/pm.md"` carries
the clause under Responsibilities, control `grep -ci acceptance` = 5 in the same invocation — **the
exact value the entry reports as its own positive control**. Introduced in `6dd9cff`, which
`merge-base --is-ancestor` confirms predates the entry's re-measurement, and present at HEAD and in
the consumer's installed copy. The secondary surface the entry names (`stories-test-strategy.md`,
0 hits, control 16) is not held as a survivor: the entry's own revision staked itself on `pm.md`
alone, and a second copy of a PM-lens rule in a step file is the restatement `mechanism-design.md`
forbids.

### `PC-S299-UNREGISTERED-DRIFT-SCAN-SKIPS-CORE-FIXTURES-AND-CORE-SCRIPTS` — the shared premise is refuted; the pointer resolves to a retained body

The fixtures exemption's falsifiable clause was tested in shipping code rather than taken from a
review: `preclassify.sh`'s `map_consumer()` maps `core/fixtures/*` and `core/scripts/*` regardless of
the drift-scan roots, and the M branch at `:309-312` files `BOTH-CHANGED→CLASSIFY` when
`ours != base` and `ours != theirs`. The silent-overwrite harm cannot occur. This entry's two roots
are a strict subset of `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES`'s five, so no
scope is lost by pointing at it. Recorded because it decided the method: `I12`'s own arm header
records that the fixtures exemption's *original* reason was false and was rewritten, which is why the
current reason was tested rather than cited.

### `PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT` — headline fixed; the entry-splitting half is filed as `BL-013`

`all_present()` is a here-string at `ledger-reverify.sh:441`, and a 145309-byte ledger now yields 6
identical verdicts in 6 runs against the three-verdicts-in-four-runs the entry measured. The
"first directive wins" parser defect is closed too — an entry with two receipts emits `[receipt 1/2]`
and `[receipt 2/2]`, nothing lost. **Defect (1) survives and is filed as `BL-013`**: a bold bullet
silently splits an entry and nothing reports it. Upstream deliberately did not re-key the entry-shape
rule (`:1035-1045`) and shipped `ENTRY-SWALLOWED`, which fires only when the bold span ends in a
colon. On a three-entry synthetic ledger a no-colon probe emitted no row under its own id — its
receipt was attributed to a neighbouring label, verbatim one of the two labels this entry records
being split under — and no `ENTRY-SWALLOWED` row. Controls in the same run: a clean entry emitted
under its own id, and the colon form did emit `ENTRY-SWALLOWED`.

### `PC-S299-READOPT-DOSSIER-RENDERS-REASON-EMPTY` — block scalars fixed, plain scalars not; filed as `BL-014`

`fm_block()` handles `|` and `>` only — it enters block mode on `/^[|>][0-9]*[-+]?$/` and everything
else takes `print v; exit`. Run against the consumer's four reason-carrying overrides: the two using
block scalars render many lines (the control proving the reader works) while a multi-line **plain**
scalar renders 1 line of 36, and another 1 of 19, cut mid-sentence after a trailing comma. The first
is the worse shape — its one surviving line reads as a complete reason. Separately `:422` pipes
through `head -20` with no ellipsis, so the two block-scalar overrides are silently clipped at 20 of
124 and 20 of 95. Filed as `BL-014`.

### `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES` — FALSIFIED, with probes and controls on both inferences

`I12` fires on a seeded unclassified subtree (`FAIL: core/newsubtree/ has no drift-scan policy row`;
control: 0 `I12` rows on the unmodified copy). `preclassify` buckets an edited fixture
`BOTH-CHANGED→CLASSIFY` (control: an untouched copy → `UPSTREAM-ONLY`), and `apply.sh:345` routes
`*CLASSIFY*` to a `WORKLIST` item with no write. The only writer, `overwrite_from_theirs`, is reached
solely on `UPSTREAM-ONLY`/`-ADD`, which require `ours == base`. The case the entry names — upstream
did not modify the file — produces no diff row at all. No destruction path exists.

### `PC-S298-WAIT-FOR-DELIVERABLE-NO-PROGRESS-EVIDENCE` — headline fixed; the chained-sibling recurrence is FIXED here, not filed

The headline survived three attempts to break it: the flag is repeatable, progress is sampled per
beat and said on stdout, the caller is instructed at `SKILL.md:1599`/`:1611`/`:1615` so it is not an
inert feature, and the bounded grant is deliberate with its own fixture case and a killed cap mutant.
The proposed refutation fails on the entry's own text — it asked for an opt-in flag, so an opt-in flag
cannot refute it. **Recurrence #2 reproduced through the new grant path and is fixed in this release**:
`wait-for-deliverable.sh:455` gated progress sampling on `MAY_SLEEP=1` while the exhaustion arm at
`:460` was ungated, so a chained sibling reached `:478` with `PROGRESSED` forced to 0. Natural repro,
sole variable being whether a prior invocation ran in the same shell: chained `rc=1 NON-DELIVERY 1
PROGRESS 0`; solo control on the identical seeded tree `rc=0 NON-DELIVERY 0 PROGRESS 1`. Rule 20 turns
that `rc=1` into a re-dispatch of a live teammate, the `GRANTSPENT` note also required `PROGRESSED=1`
so the lead got a bare non-delivery, and the re-arm advice was suppressed because the flag was already
set. The fixture had zero coverage of it — its beat helper runs each case in its own subshell, so no
case ever had a sibling.

### `PC-S308-SELF-UPDATE-INSTALLS-THE-VALIDATOR-THAT-BLOCKS-ITS-OWN-PUSH` — close MANUALLY; the entry's receipt can never fire

The attack fails on measurement: `self-update-gate.sh:325`'s regex over the shipped hook yields nine
basenames including `validate-layer-entries.sh` — the hook invokes it literally, not through a
variable — and the entry's measured `rc_cur=0`/`rc_new=1` lands on the defer arm at `:407-409`. The
fixture passes 26/26 including that exact defer case, with a mutant proving the differential is what
buys it. **Carry forward:** the entry's own `verify:` predicate returns exit 0 "STILL OPEN" at HEAD
and always will (count 1, control token `self-update` = 30), and its closing sentence is literally
still true — upstream took a stronger route than either shape the entry proposed, deriving the whole
blocking set rather than naming one script.

### `PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE-FOR-A-STALLED-TERMINAL-PASS` — the attack is unconstructible because the two conditions are one condition

`:958-960` and `:986` use the identical predicate, so below the threshold `STALL_LIVE` is 0, arm E
never fires, and the emit block's stall branch is never taken — there is no `STALLED` state for
`RESOLVED` to be unreachable from. The fixture passes 80/80 with `stalled-resolved` → `RESOLVED/0`,
an over-fire control (`stalled-record-invalid` → `STALLED/3`), and a killed mutant on the stall call
site. Closing buries nothing: the successor defect is filed separately and its arm is still red by
design.

### `PC-S316-LEDGER-REVERIFY-DOES-NOT-NORMALIZE-CONSUMER-TO-AN-ABSOLUTE-PATH` — the entry's own differential now reproduces zero

Ran it at HEAD: `.` versus the absolute root, same refs, same ledger → 107 rows each, **0 differing
lines**, against the 1 inverted row the entry reproduced. Normalization at `:176-177` is downstream of
every read of `$CONSUMER` — the only two occurrences at or above `:177` are the assignment and the
normalization, control 32 occurrences file-wide. The symlink attack fails: a symlinked root moves 22
lines but 0 status+entry keys (`STILL-LIVE` 53=53, `CLOSE-CANDIDATE` 3=3), and the 22 are the root
string rendered into detail text rather than a verdict flip, so `pwd` versus `pwd -P` does not reopen
it.

### `PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS` — headline fixed; three invisible entries filed as `BL-015`

The unnumbered arm at `:1502-1575` is a separate `if`, not gated by the `ext_anchors` guard, and the
weaker status does reach the report (`emit-report.sh:230`'s denylist has exactly one member,
`EXTENSION-OK`). A live run against the consumer emits 3 rows. Coverage measured with the shipping
harvesters lifted verbatim: 11 of 37 entries carry anchors, 26 carry none, and 23 of those 26 are now
reachable. **The surviving sub-claim is `BL-015`**: three registered entries remain outside the
detector entirely — `bug-investigation-domain.md`, `research-requirements-domain.md`, `pm-domain.md`,
each with 0 markdown headings (control: `gate-validation-push.md` has 10) — **and nothing says so**.
The status vocabulary has no `NOT-CHECKED` member (control: 21 emit sites, 14 statuses), so the
entry's own named remedy, making the silence legible, is unimplemented. Live instance found by hand:
`pm-domain.md`'s frontmatter records core v0.288.0 absorbing both its bullets near-verbatim, on a file
the detector still cannot see.

### `PC-S316-LEDGER-REVERIFY-EXITS-0-SILENTLY-ON-AN-UNREADABLE-LEDGER-PATH` — all four caller-error shapes exercised

Against a scratch consumer, control being a correct invocation at 107 rows: swapped arguments — the
entry's exact reproduction — now returns 1 `INPUT-UNRESOLVED` row instead of 0 rows of silence; arg-5
a directory, caught; arg-5 bogus, caught; consumer a file, caught. Two shapes still return 0 rows at
rc 0 (an empty arg-5 file, and a directory holding no ledger at the default path). Neither is the
entry's claim, and the second is enumerated as out of reach at `:223-227` and is by construction
indistinguishable from the genuine no-ledger case the entry itself says must stay silent.

### `PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1` — the LC-O15 half fails by measurement

`layer-drift.sh` run against the consumer twice on the same tree. Degenerate (`base==theirs`): 37
`EXTENSION-OK` + 1 `DRIFT-RANGE-DEGENERATE`, 0 `EXTENSION-HOOK-DRIFT`. Real range: 4
`EXTENSION-HOOK-DRIFT` + 1 `EXTENSION-ANCHOR-DRIFT` — the control that the differential can see the
range-keyed arms. `OVERRIDE-SUPERSEDED` emits 1 row in **both** runs, so it is not range-keyed, was
never disarmed, and needed no restoring. `--adjudicated-codes` returns the live set, so the reader
`SKILL.md` points at instead of a hand-list is real, and no other unqualified "pass theirs as the
base" instruction survives under `core/skills/ai-dlc-update/` (control: 127 `base` hits in `SKILL.md`
alone).

### `PC-S314-APPLY-SH-OVERWRITES-ITSELF-MID-RUN-UNDER-DEFER` — re-derived mechanically, because the obvious grep was wrong

Every redirect target in `apply.sh` was extracted with an `awk` pass rather than a grep shape — the
obvious grep dropped six real write sites, which was caught and redone. Six real targets, all
`.incoming`/`_tmp` plus `mv`; control in the same invocation, 11 `>&2` lines matched, so the extractor
was live. No `git merge-file` anywhere. `self_replaced` is set at `:251` inside
`overwrite_from_theirs` and reported at `:385`, after phase 1's two call sites and before the other
two, neither of which can carry `apply.sh`'s own path — so the report cannot be outrun. The `-ef`
inode compare rather than a string compare is the difference between this firing and being another
check that cannot fire.

### `PC-S314-NO-DETECTOR-CLAIMS-A-LAYER-FILE-CITING-A-PATH-THE-PULL-JUST-RETIRED` — headline closed; the retired-PATH half filed as `BL-016`

`W11`/`LC-R4` arm 2 fires on the entry's exact path and the arm's own header names the report that
produced it. **The surviving sub-claim, verbatim from the entry's body, is `BL-016`**:
`retired-layer-contract.sh` emitted zero rows for the whole run, so a retired *path* is not among the
shapes it treats as a retired contract. `shapes_of()`/`tokens_of()` at `:81-89` extract only labelled
directives and `{token}` placeholders, and the header declares what it does not catch. Nothing derives
retired paths from the `base..theirs` diff, and `W11`'s corpus is bounded to four declared scan roots,
so a core path retired outside them and cited in a consumer layer file is claimed by nothing. Upstream
built a grammar check with a hand-declared corpus, not a diff-derived one.

### `PC-S319-SUBJECT-DIGEST-IS-UNREADABLE-ONCE-ITS-OWN-ROW-STOPS-BLOCKING` — one of two carriers repaired; the schema half filed as `BL-017`

The attack answered decisively in upstream's favour: the site is `adj_digest`, not the `ADJUDICATED`
code set, so all 12 keyed subjects list, and upstream measured the exact 1-of-12 a code-set listing
would have produced. **The entry names two carriers of the bad instruction and only one was
repaired.** `SKILL.md`'s half is fixed at `:1270-1279`; the schema's half is not —
`layer-adjudication-register.json:29` still reads "Copied verbatim from the blocking row", and `:5`
likewise. `grep -c list-adjudications` on that file returns 0, control in the same invocation
`blocking row` = 3, and `git log 67b4b15..HEAD` on it is empty. It ships to `.claude/schemas/`, so the
artifact a consumer opens while writing a register record still names the blocking row as the only
source. Filed as `BL-017`.

### `PC-S328-NAMED-UPSTREAM-JOINS-ON-THE-FULL-SLUG-WHILE-UPSTREAM-CITES-THE-SHORT-ID` — headline fixed; the fallback's two defects are FIXED here, not filed

The headline is fixed with a positive control: the entry's own instance gets 0 slug hits, 3 prefix
hits, oldest being the release that fixed it. **Both surviving halves are fixed in this release
rather than carried.** First, verbatim from the entry's own prescribed fix — `(PC-S[0-9]+)` anchored
so it cannot match a longer unrelated number — `:387` was `git log -F --grep`, a fixed *substring*
search with no anchoring; measured on a live entry, the fallback attributed a commit containing zero
bare tokens of that id, control in the same invocation showing 2 slug tokens, both in **archived**
entries. Second, `prefix_entry_count` read `$ENTRIES` from `$LEDGER` alone, so the archive was
invisible to it: 3 of 10 live prefixes are `live==1` **and** `archive>=1`, so the guard passed and the
row asserted "unambiguous" against a measurement that refutes it. That guard was **anti-monotonic** —
every `ledger-rotate` run lowered the count and converted a correct `AMBIGUOUS` into a confidently
wrong single attribution.

### `PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-AND-THE-EVIDENCE-IS-DELETED-WITH-THE-TEMP-DIR` — capture landed in both hooks

`.githooks/pre-push:222` and `core/git-hooks/pre-push:272` both set `FAILLOG_RECORD`; both carry the
per-worker capture, the red-only copy plus dispatch order, and the path announcement. `bab5a61`
touched both hooks and `core/fixtures/consumer-suite-pool/run.sh` in one commit. `I66` holds at HEAD —
`validate-enforcement-map.sh` rc 0, no `I66` line emitted — and `consumer-suite-pool`, which drives the
**consumer's** hook, ran 18/18 green including the red-capture arm, the path-announcement arm, the
all-green control, and a mutant proving the verdict selector is what limits capture to red units.

### `PC-S302-RETIRED-LAYER-CONTRACT-READS-CLEAN-OVER-TWO-REAL-POSITIVES` — the shipping detector fires on the entry's own positive

`retired-layer-passage.sh` run against the real consumer over the entry's own range emitted
`RETIRED-LAYER-PASSAGE` on `bug-investigation-push.md:92` — the entry's own positive #2, at the exact
`path:line` it named. Positive #1 had already been repaired consumer-side before the pull. Both quiet
paths now carry their denominator, which is the entry's closing sentence. **A false `REFUTED` was
nearly filed here**: the first grep used the wrong path prefix and returned "No such file" for both
positives, a two-file false zero that only the control caught.

### `PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD` — headline fixed; the asymmetry half filed as `BL-018`

`--post-apply` exists, is named at the call site and in the operator step, and `reconcile-blocking-list`
ran 10/10 green including its own control. The entry was not refuted on optionality alone — its
suggested shape was disjunctive and the flag is the second disjunct. **The surviving sub-claim is the
asymmetry argument, filed as `BL-018`**, measured on the live trees: with the pull's base,
`unregistered-drift.sh` emits 5 `CORE-AT-THEIRS` rows — the tell `SKILL.md:1189` explicitly names — and
`hard-blockers.sh:97-98` filters to `^HARD-` only, discards all five, and prints a bare
`0 HARD blockers`. Control: 0 rows with theirs as base, all 5 becoming `CORE-OK`. It is the identical
shape to what the previous release fixed for `DRIFT-RANGE-DEGENERATE` — same wrapper, same filter, same
class, one half done.

### `PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND-THAT-RESOLVES-TO-NOTHING` — headline fixed; `effort_bound` filed as `BL-019`

`dispatch-guard.sh:369` is declarative, the dedupe moved with it, and it is fixture-guarded with a
mutant stripping the dedupe key. **The surviving sub-claim — "the recorded binding is a
self-declaration, not an observation" — is live and worse than filed.** `effort_bound` is written from
`PIN_EFFORT` at `:309-332`, **above** the `NEEDS_EFFORT` logic at `:356-381`, so it records the config
even on dispatches where the guard appends nothing, and it has zero readers (control: `model_bound` is
read by `validate-spawn-ledger.sh`, `check-22-spawn-ledger`, `enforcement-map.yaml` and
`gate-validation.md`). This file's own `:563` conceded the point and called it "a separate filing" —
**and that filing did not exist**: `effort_bound` appears in the consumer's pinned ledger and its
archive at exactly one line, inside this entry. It is now `BL-019`.
