# Consumer brief — the graph push-candidate ledger, fully adjudicated

**THIS FILE IS RENDERED. Do not hand-edit it.** Change the data under
`graph-ledger-adjudication-data/` and re-run the renderer; the annotation strings below are
generated and were tested against the two enforcers that read them, not transcribed.

## What this is, and who applies it

Upstream (`ai-dlc`) adjudicated all **115** open entries in
`_bmad-output/ai-dlc-update/push-candidate-ledger.md`, plus the 3 filed after the corpus pin,
against the working tree — entry by entry, with a control in the same invocation for every
absence-shaped claim. This brief is the result.

**graph applies it. The ai-dlc session that produced it did not write here and must not.**

Nothing below asks you to take upstream's word for it; every row names its evidence and where
it lives. Where upstream was wrong, that is stated in the row rather than quietly corrected.

## The annotation, rendered once

Paste this string, **byte for byte**, into each entry in sections A and B:

```
**ADOPTED UPSTREAM (v0.373.0, verified 2026-08-17)**
```

**The form is load-bearing in two directions and a sloppy paste breaks both.**
`ledger-reverify.sh` treats *any* occurrence of `ADOPTED UPSTREAM` in an entry as closed and
SKIPS it. But `ledger-rotate.sh:143` archives only on the strict `/\*\*ADOPTED UPSTREAM \(v[0-9]/`
— bold, with a digit immediately after the `v`. So an entry annotated
`**ADOPTED UPSTREAM (verified 2026-08-17)**`, carrying no version, becomes **invisible AND
unarchivable**: it stops being reported and never leaves the live file.

That exact near-miss is the control this renderer runs against itself. It refuses to emit if the
string it generated fails the strict form, and equally if the versionless near-miss PASSES —
an arm that accepts both is not discriminating between them.

## The five sections, and the arithmetic that closes over them

| section | what | rows |
|---|---|---|
| A | CLOSE — absorbed, falsified or duplicate | 39 |
| B | WITHDRAW — filed by graph, premise dead on re-derivation | 18 |
| C | LIVE, now tracked upstream as a `BL-` entry | 41 |
| D | LIVE, consumer-local — no upstream grain fits | 17 |
| E | replacement `verify:` receipts for undecidable and absent directives | 14 |
| F | filed after the corpus pin — LIVE, tracked upstream | 3 |

Sections A–D partition the 115 exactly: 39 + 18 + 41 + 17.
Section E cuts across C and D — those entries stay open AND get a working receipt.

**Section F sits OUTSIDE that partition, and the reason matters more than the three rows.** The
115 came from a corpus pinned at this ledger's first 4356 lines, so every derivation downstream
inherited that boundary — including the coverage proof that confirmed all 59 filing rows were
accounted for. That proof was correct and could not see these three, because they were filed above
the pin. A complete-looking coverage proof over a derived population cannot see outside it; the
question that found them was a different one — *do any upstream entries cite a pin above 4356?*

**Section C is 41 consumer rows but 42 upstream entries**, because one row
drew two. Do not read the counts as interchangeable; that conflation produced a wrong
withdrawal figure in this program once already, and it was caught only because 59 minus 42 did
not equal the number of rows actually left uncovered.

## A — CLOSE (39)

Adjudicated absorbed, falsified, or duplicate. Annotate each, and the rotator will archive them.

**Half the proposed closes did not survive refutation.** 48 were proposed; 24 confirmed, 15
narrowed to a headline plus a live sub-claim no other entry owns, and 9 refuted outright and
returned to the live set — they are in sections C and D, not here. A false close retires a live
defect and is indistinguishable from an ordinary absorption, which is why no close here rests on
a single reading.

Every one of the 15 narrowed closes was GATED: its surviving sub-claim had to be filed upstream
BEFORE the parent could close, so that closing it could not delete the only written record of a
live defect.

`changelog-cite` rows also appear verbatim in a release commit MESSAGE, so `named_absorbed()`
resolves them and your next reconcile emits a `NAMED-UPSTREAM` row independently of this brief.
`brief-annotation` rows CANNOT — `flush()` gates on `has_verify &&` and they carry no receipt —
so for those **this annotation is the only closing channel**.

| pin | entry | verdict | channel |
|---|---|---|---|
| 157 | `SKILL.md:665 cites the provenance-block schema at a path th...` | ALREADY-FIXED-v0.143.6 | brief-annotation |
| 271 | `extensions/steps-domain/artifact-consolidation-push.md` | ALREADY-FIXED-v0.33.2 | brief-annotation |
| 273 | `extensions/roles/code-reviewer-push.md` | ALREADY-FIXED-v0.277.0 | brief-annotation |
| 275 | `extensions/roles/qa-push.md` | ALREADY-FIXED-v0.277.0 | brief-annotation |
| 281 | `.claude/team-roles/tea.md` | ALREADY-FIXED-v0.21.0 | brief-annotation |
| 297 | `scripts/validate-provenance-block.sh` | ALREADY-FIXED-v0.128.0 | brief-annotation |
| 302 | `scripts/validate-provenance-block.sh` | ALREADY-FIXED-v0.60.0 | brief-annotation |
| 305 | `scripts/scan-stray-provenance.sh` | ALREADY-FIXED-v0.198.0 | brief-annotation |
| 351 | `PC-S295-RETRO-STEERING-AUDIT-SESSION-SCOPED` | ALREADY-FIXED-v0.117.0 | brief-annotation |
| 387 | `PC-S295-FLOWLOG-HEADER-LEGEND-IS-GREPPABLE-AS-DATA` | ALREADY-FIXED-v0.117.0 | brief-annotation |
| 553 | `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK` | FALSIFIED | changelog-cite |
| 610 | `PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS` | DUPLICATE-OF-pin177 | changelog-cite |
| 638 | `steps/gate-validation.md Check 25 has no remediation path f...` | ALREADY-FIXED-v0.111.0 | brief-annotation |
| 728 | `PC-S296-PAUSE-SKIP-ARM-MISSES-TASK-NOTIFICATIONS` | ALREADY-FIXED-v0.265.0 | brief-annotation |
| 821 | `PC-S296-H1-FIXTURE-CITATION-GAP` | ALREADY-FIXED-v0.146.0 | changelog-cite |
| 1125 | `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` | ALREADY-FIXED-93e05d3 | changelog-cite |
| 1254 | `PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD` | ALREADY-FIXED-v0.88.0 | changelog-cite |
| 1305 | `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION` | ALREADY-FIXED-v0.169.0 | changelog-cite |
| 1406 | `PC-S299-UNREGISTERED-DRIFT-SCAN-SKIPS-CORE-FIXTURES-AND-COR...` | DUPLICATE-OF-PC-S303-UNREG | changelog-cite |
| 1449 | `PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT` | ALREADY-FIXED-v0.147.1 | changelog-cite |
| 1543 | `PC-S299-READOPT-DOSSIER-RENDERS-REASON-EMPTY` | ALREADY-FIXED-v0.150.1 | changelog-cite |
| 1757 | `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES` | FALSIFIED | changelog-cite |
| 1862 | `PC-S298-WAIT-FOR-DELIVERABLE-NO-PROGRESS-EVIDENCE` | ALREADY-FIXED-v0.168.0 | changelog-cite |
| 2028 | `4b. Operator-steerability audit, then flow-log rotation (Ru...` | ALREADY-FIXED-v0.180.0 | brief-annotation |
| 2170 | `PC-S308-SELF-UPDATE-INSTALLS-THE-VALIDATOR-THAT-BLOCKS-ITS-...` | ALREADY-FIXED-v0.185.0 | changelog-cite |
| 2680 | `PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE-FOR-A-STALLED-TERM...` | ALREADY-FIXED-v0.247.0 | changelog-cite |
| 3145 | `PC-S316-LEDGER-REVERIFY-DOES-NOT-NORMALIZE-CONSUMER-TO-AN-A...` | ALREADY-FIXED-v0.301.0 | changelog-cite |
| 3190 | `PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS` | ALREADY-FIXED-v0.275.0 | changelog-cite |
| 3244 | `PC-S316-LEDGER-REVERIFY-EXITS-0-SILENTLY-ON-AN-UNREADABLE-L...` | ALREADY-FIXED-v0.301.0 | changelog-cite |
| 3287 | `PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1` | ALREADY-FIXED-v0.303.0 | changelog-cite |
| 3336 | `PC-S314-APPLY-SH-OVERWRITES-ITSELF-MID-RUN-UNDER-DEFER` | ALREADY-FIXED-v0.316.0 | changelog-cite |
| 3375 | `PC-S314-NO-DETECTOR-CLAIMS-A-LAYER-FILE-CITING-A-PATH-THE-P...` | ALREADY-FIXED-v0.333.0 | changelog-cite |
| 3464 | `PC-S319-SUBJECT-DIGEST-IS-UNREADABLE-ONCE-ITS-OWN-ROW-STOPS...` | ALREADY-FIXED-v0.331.0 | changelog-cite |
| 3507 | `PC-S328-NAMED-UPSTREAM-JOINS-ON-THE-FULL-SLUG-WHILE-UPSTREA...` | ALREADY-FIXED-v0.329.0 | changelog-cite |
| 3719 | `PC-S302-FIXTURE-SUITE-POOL-PRODUCES-AN-UNREPRODUCIBLE-FAIL-...` | ALREADY-FIXED-v0.367.0 | changelog-cite |
| 3749 | `PC-S302-RETIRED-LAYER-CONTRACT-READS-CLEAN-OVER-TWO-REAL-PO...` | ALREADY-FIXED-v0.359.0 | changelog-cite |
| 3787 | `PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD` | ALREADY-FIXED-v0.367.0 | changelog-cite |
| 3828 | `PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND-THAT-RESOLV...` | ALREADY-FIXED-v0.367.0 | changelog-cite |
| 4153 | `PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL` | ALREADY-FIXED-v0.372.0 | brief-annotation |

## B — WITHDRAW (18)

These were filed by graph and re-derived upstream against the working tree. Each is either
already fixed, or its premise is false, or its subject is a settled decision rather than a
defect. **Annotate them exactly as section A.**

The measured base rate of expired premises in this corpus is roughly one in two; this pass came
in lower. A filing that cannot be substantiated is worse than none, so these are a normal
outcome, not a failure of the original filings.

**The evidence is in `graph-ledger-adjudication-data/step12-withdrawals.md`**, in each
adjudicator's own words, with the controls each ran. Read it before retiring any row you disagree
with — one entry here was independently confirmed dead by a hand that did not know the operator
had already ruled it retired.

| pin | entry | verdict |
|---|---|---|
| 118 | `validate-retro-evidence.sh → resolve the retro branch via...` | HOLDS-MECHANISM-WRONG |
| 139 | `validate-mandatory-rules.sh → subset-mode flags and a sha...` | DUPLICATE-OF-pin1011 |
| 177 | `Rule 18 has no carve-out for terse traceability citations, ...` | HOLDS-MECHANISM-WRONG |
| 269 | `extensions/steps-domain/stories-test-strategy-push.md` | HOLDS |
| 334 | `layer-drift.sh EXTENSION-RESTATES-CORE matches on section n...` | HOLDS-MECHANISM-WRONG |
| 687 | `PC-S296-SNAPSHOT-BUDGET-UNENFORCED-AT-GATES` | FALSIFIED |
| 715 | `PC-S296-DEPLOY-VALIDATE-NA-RITUAL` | FALSIFIED |
| 798 | `PC-S295-RETRO-COLLAPSE-PAUSE-FLAG-AND-BOUNDED-JOIN` | HOLDS-MECHANISM-WRONG |
| 931 | `PC-S297-POOL-LOOP-SUBSHELL-TRAP-UNDOCUMENTED` | HOLDS-MECHANISM-WRONG |
| 1069 | `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` | ALREADY-FIXED-v0.280.0 |
| 1240 | `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE` | ALREADY-FIXED-v0.280.0 |
| 1269 | `PC-S297-CHECK16-SCOPE-AMBIGUITY` | HOLDS |
| 1346 | `PC-S297-RETRO-OVERRIDES-F1F2F3F6` | HOLDS-WIDER |
| 1597 | `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION` | ALREADY-FIXED-v0.152.0 |
| 1622 | `PC-S299-PREPUSH-NONREPRODUCING-FAIL` | HOLDS-MECHANISM-WRONG |
| 2341 | `PC-S312-SPRINT-STATUS-CHECK-STORIES-COVERS-ONE-FIELD-OF-FIVE` | HOLDS-MECHANISM-WRONG |
| 3980 | `PC-S330-A-CONTRADICTS-CORE-VERDICT-EXPIRES-LIKE-A-READING-A...` | ALREADY-FIXED-v0.369.0 |
| 4184 | `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS` | ALREADY-FIXED-v0.372.0 |

## C — LIVE, tracked upstream (41 rows, 42 entries)

These reproduced against the working tree. Upstream filed each as a `BL-` entry in its own
`docs/backlog.md`, carrying the re-derived measurement, the correction where the original filing
was wrong about its own mechanism, and a `verify:` receipt that was RUN and exits non-zero today.

**Leave these open in your ledger.** They close when upstream ships the fix and cites the id.

51 of these carried no promoted evidence, so each was a fresh derivation rather than a
transcription — and the filings were frequently wrong about their own mechanism in a way that
changed the remediation's SCOPE, not merely its wording.

| pin | entry | verdict | upstream |
|---|---|---|---|
| 226 | `extensions/checks/gate-validation-push.md` | HOLDS-MECHANISM-WRONG | `BL-021` |
| 252 | `extensions/steps-domain/deploy-validate-push.md` | HOLDS-MECHANISM-WRONG | `BL-022` |
| 255 | `extensions/steps-domain/retro-push.md` | HOLDS-MECHANISM-WRONG | `BL-023` |
| 259 | `extensions/steps-domain/implementation-push.md` | HOLDS-MECHANISM-WRONG | `BL-024` |
| 262 | `extensions/steps-domain/SKILL-push.md` | HOLDS-MECHANISM-WRONG | `BL-025, BL-026` |
| 265 | `extensions/steps-domain/route-push.md` | HOLDS | `BL-027` |
| 267 | `extensions/steps-domain/sprint-review-push.md` | HOLDS | `BL-028` |
| 276 | `extensions/roles/dev-push.md` | HOLDS-MECHANISM-WRONG | `BL-048` |
| 316 | `Decision-branch execution-coverage for sprint-review ...` | HOLDS-WIDER | `BL-038` |
| 436 | `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED` | HOLDS-WIDER | `BL-039` |
| 510 | `PC-S295-RETRO-CHECK5-SELF-REFERENTIAL` | HOLDS | `BL-040` |
| 577 | `PC-S295-RETRO-RED-SMOKE-CROSSING-SPRINT-BOUNDARY` | HOLDS-WIDER | `BL-041` |
| 654 | `PC-S296-ESCALATION-STATUS-APPENDS-INSTEAD-OF-REPLACING` | HOLDS-MECHANISM-WRONG | `BL-053` |
| 673 | `PC-S296-H2-ATTESTED-ANCHOR-DEFEATED-BY-BACKTICKS` | HOLDS-WIDER | `BL-054` |
| 701 | `PC-S296-PIPELINE-POSITION-MUST-BE-EDITED-IN-PLACE` | HOLDS-MECHANISM-WRONG | `BL-047` |
| 860 | `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS` | HOLDS | `BL-029` |
| 1093 | `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD` | HOLDS-MECHANISM-WRONG | `BL-055` |
| 1136 | `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` | HOLDS-WIDER | `BL-056` |
| 1165 | `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLA...` | HOLDS-WIDER | `BL-042` |
| 1215 | `PC-S297-LOCKED-FENCE-LAUNDERS-AGENT-PROSE` | HOLDS | `BL-057` |
| 1226 | `PC-S297-VALIDATOR-PASS-VS-NOTHING-TO-CHECK-CONVENTION` | HOLDS-WIDER | `BL-058` |
| 1361 | `PC-S297-GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND` | HOLDS-MECHANISM-WRONG | `BL-043` |
| 1381 | `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE` | HOLDS-WIDER | `BL-059` |
| 1571 | `PC-S299-UPSTREAM-SHIPS-TWO-REVIEW-VERDICT-VOCABULARIES` | HOLDS-MECHANISM-WRONG | `BL-044` |
| 1977 | `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` | HOLDS-MECHANISM-WRONG | `BL-030` |
| 2101 | `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-S...` | HOLDS | `BL-045` |
| 2231 | `PC-S311-ENTRY-SWALLOWED-DETAIL-EMITS-A-LITERAL-BACKSL...` | HOLDS | `BL-031` |
| 2492 | `PC-S312-STRAYS-DOES-NOT-NORMALIZE-AN-ABSOLUTE-PATH` | HOLDS | `BL-060` |
| 2785 | `PC-S300-RESOLUTION-RECORD-CITATION-CANNOT-OUTLIVE-ITS...` | HOLDS | `BL-061` |
| 2957 | `PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOT...` | HOLDS | `BL-032` |
| 3018 | `PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPS...` | HOLDS | `BL-033` |
| 3088 | `PC-S315-EMIT-REPORT-REGION-OMITS-THREE-MANDATED-DETEC...` | HOLDS-WIDER | `BL-034` |
| 3413 | `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FI...` | HOLDS | `BL-049` |
| 3595 | `PC-S329-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS...` | HOLDS-MECHANISM-WRONG | `BL-050` |
| 3647 | `PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-...` | HOLDS-MECHANISM-WRONG | `BL-035` |
| 3881 | `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` | HOLDS-WIDER | `BL-046` |
| 3918 | `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODI...` | HOLDS-MECHANISM-WRONG | `BL-051` |
| 4052 | `PC-S333-SETTINGS-MERGE-CHECK-READS-AN-EMPTY-TEMPLATE-...` | HOLDS-WIDER | `BL-036` |
| 4096 | `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH...` | HOLDS-WIDER | `BL-052` |
| 4258 | `PC-S331-APPLY-SH-CO-EMITS-READOPT-AND-RETIRE-FOR-ONE-...` | HOLDS | `BL-037` |
| 4313 | `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE...` | HOLDS-WIDER | `BL-062` |

## D — LIVE, consumer-local (17)

No upstream grain fits these: the subject is graph's own forked `scripts/`, or a retirement probe
over machinery core has never shipped. **There is no upstream work and none is coming.** Keep or
retire them on your own judgement — but they should not sit in a queue labelled "upstream owes
this", because upstream does not.

One entry here is a standing operator RULING rather than an adjudication:
`PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` is retired because the exemption is correct by design.
`validate-locked-anchor.sh:16-18` scopes the byte-match to a `full_text_source:` full-text claim,
and `:20-26` records that a `requires_context:` load pointer IS resolved for existence.
Byte-matching a load pointer would fail honest cite-by-reference.

| pin | entry | verdict |
|---|---|---|
| 78 | `validate-ci-gates.sh → repoint the dormant-gate scan at a...` | NOT-UPSTREAM |
| 349 | `S295 retro-batch closures (restructured 2026-07-22, story-2...` | NOT-UPSTREAM-scaffolding |
| 776 | `PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD` | NOT-UPSTREAM |
| 1030 | `validate-retro-prereq.sh → RETIRED (no stock equivalent).` | NOT-UPSTREAM |
| 1045 | `PC-S297-FFCLUSTER-SHA-STALE` | NOT-UPSTREAM |
| 1149 | `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` | NOT-UPSTREAM |
| 2306 | `PC-S312-RETRO-REPLAY-HARNESS-NOT-ABSORBED-BY-DRIVABILITY` | NOT-UPSTREAM |
| 2372 | `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK` | NOT-UPSTREAM |
| 2411 | `PC-S312-PROTECTED-CORE-PATHS-STAYS-RETIRED` | NOT-UPSTREAM |
| 2436 | `PC-S312-MUTATION-RED-ANCHOR-STAYS-RETIRED` | NOT-UPSTREAM |
| 2465 | `PC-S312-STRAY-SCAN-ARM-STAYS-RETIRED` | NOT-UPSTREAM |
| 2546 | `PC-S312-S239-1-HARDENING-CALLS-PRE-RELOCATION-PATHS` | NOT-UPSTREAM |
| 2576 | `PC-S312-FIXTURE-PROVENANCE-ARM-HAS-NO-LIVE-DRIVER` | NOT-UPSTREAM |
| 2598 | `PC-S312-EXPECTED-VALIDATORS-WORD-SPLIT-EXCLUDES-FLAGS` | NOT-UPSTREAM |
| 2630 | `PC-S312-PR-CLASS-TEST-A6-A7-ARE-UNREACHABLE` | NOT-UPSTREAM |
| 2655 | `PC-S312-FIX-FORWARD-CLASS-GATES-ON-NO-VALIDATOR` | NOT-UPSTREAM |
| 4216 | `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION` | ALREADY-FIXED-v0.372.0 |

## E — replacement `verify:` receipts (14)

**Two classes of entry are in here, and neither can ever be closed by the directive it carries
today.** Most carry a `verify: theirs_has <substring>` whose substring is present at BASE as well
as at theirs, so the reverifier reports:

> `RECEIPTS-UNDECIDED … reported STILL-LIVE on a substring present at BASE as well as at theirs`

A predicate that matches in both states distinguishes nothing. It will report "still open"
forever, whether or not the defect is ever fixed — and `ledger-reverify-unfalsifiable/README.md`
measures 13 such entries on this consumer already.

The rest carry **no directive at all**, which is worse and much quieter: `flush()` gates on
`has_verify &&`, so those entries produce no row in any reverify report. They are not reported as
open, or as closed, or as needing review. They are simply invisible to the closer, and a zero
CLOSE-CANDIDATE count over a corpus containing them means nothing.

Each replacement below is anchored on a token the fix MUST add or remove — a flag, a path, a
function name, an emitted string, an observable behaviour — never on prose describing the fix.

**Every one was RUN, and every `sh` receipt exits 0 today. Zero is the requirement, not the
failure.** Your engine's `sh` dispatch reads `rc=0` as **STILL-LIVE** and a non-zero as
**CLOSE-CANDIDATE** — read it at the emitter in `ledger-reverify.sh`, because its own file header
reads the other way and this program briefed four authors from the header before catching it.
So a receipt here that exits non-zero is proposing to retire a live defect. If you carry a habit
from a `docs/backlog.md`-shaped tool, note that those read the OPPOSITE sense.

**Every `sh` receipt below guards its own subject to exit 127** when a path, span or extraction
cannot be resolved, which your engine reports as NEEDS-REVIEW rather than as a close. That guard
is not decoration: measured on this consumer, ONE relocation commit moved five receipt subjects
and all five flipped to CLOSE-CANDIDATE in a single run, every one still reproducing at its new
path. Where a row's note says the guard is absent, treat any future non-zero from it as
unverified until you have confirmed the subject still resolves.

Three anchor failures this program measured, all of which recur, and which each replacement was
checked against: an anchor on text the FIX QUOTES BACK (fixes here document what they removed, so
the anchor survives in the comment recording the change); an anchor on a phrasing the FILING
INVENTED rather than one the code uses; and an anchor on a word the fix's own closing clause also
contains, which returns rc=0 against the defect itself.

**Replace the whole `verify:` line.** Paste each `new` verbatim — they were tested as written,
and the engine runs them through `eval`, so quoting is part of the predicate.

### pin 860 — `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc-update/reconcile/classify-block.md "assign ONE bucket"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh f=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc-update/reconcile/classify-block.md") || exit 127; k=$(LC_ALL=C awk "/^## Return/{r=1} r&&/^[[:space:]]+-?[[:space:]]*[a-z_]+:/{sub(/^[[:space:]-]+/,\"\");sub(/:.*/,\"\");print}" <<<"$f"); [ "$(LC_ALL=C grep -xcE "id|bucket|action|needs_operator_confirmation|note" <<<"$k")" -ge 5 ] || exit 127; [ "$(LC_ALL=C grep -vxcE "id|bucket|action|needs_operator_confirmation|note" <<<"$k")" -eq 0 ] || exit 1; s=$(LC_ALL=C awk "/^## For each block where/{p=1} /^## Whole-file case/{p=0} p" <<<"$f"); [ -n "$s" ] || exit 127; ! LC_ALL=C grep -qiE "depends|dependency|presuppos|push_candidate" <<<"$s"
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-1.md:74`.

### pin 1069 — `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/scripts/validate-locked-anchor.sh "is never byte-matched"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" archive "$THEIRS" core/scripts >"$t/a.tar" 2>/dev/null && tar -xf "$t/a.tar" -C "$t" || { rm -rf "$t"; exit 127; }; v="$t/core/scripts/validate-locked-anchor.sh"; [ -f "$v" ] || { rm -rf "$t"; exit 127; }; printf "# Brief\n\n## LR-S1-ALPHA\n\nReal brief text.\n\n## Other\n" >"$t/product-brief.md"; printf "# S\n\n\x3c!-- LOCKED_REQUIREMENTS -->\nrequires_context: product-brief.md#LR-S1-ALPHA\n- ZZQQ-FABRICATED-REQUIREMENT-NOT-IN-THE-BRIEF\n\x3c!-- END LOCKED_REQUIREMENTS -->\n" >"$t/story-rc.md"; printf "# S\n\n\x3c!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-ALPHA\n- ZZQQ-FABRICATED-REQUIREMENT-NOT-IN-THE-BRIEF\n\x3c!-- END LOCKED_REQUIREMENTS -->\n" >"$t/story-fts.md"; bash "$v" "$t/story-rc.md" >/dev/null 2>&1; a=$?; bash "$v" "$t/story-fts.md" >/dev/null 2>&1; c=$?; rm -rf "$t"; [ "$c" -eq 1 ] || exit 127; [ "$a" -eq 0 ]
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-1.md:147`.

### pin 1093 — `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/scripts/validate-stub-audit.sh "=~ ^-\ Item\ "
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" archive "$THEIRS" core/scripts >"$t/a.tar" 2>/dev/null && tar -xf "$t/a.tar" -C "$t" || { rm -rf "$t"; exit 127; }; v="$t/core/scripts/validate-stub-audit.sh"; b=_bmad-output/planning-artifacts/carry-over-backlog.md; mkdir -p "$t/r/_bmad-output/planning-artifacts"; { [ -f "$v" ] && cp "$CONSUMER/$b" "$t/r/$b"; } || { rm -rf "$t"; exit 127; }; it=$(LC_ALL=C sed -n "s/^- \*\*Item \([0-9][0-9]*\).*/\1/p" "$t/r/$b" | head -1); { [ -n "$it" ] && LC_ALL=C grep -qE "^- \*\*Item ${it}[^0-9]" "$t/r/$b"; } || { rm -rf "$t"; exit 127; }; printf "#!/usr/bin/env bash\n# deferred: carry-over Item %s is still open in the backlog\n# see scripts/ai-dlc/validate-stub-audit.sh:217 for the element grammar\n# deferral-reason: waiting on the upstream element-two grammar repair\n#\n#\necho placeholder-TODO\n" "$it" >"$t/r/probe.sh"; o=$( cd "$t/r" && bash "$v" --root "$t/r" probe.sh 2>&1 ); rm -rf "$t"; case "$o" in *element1-item-ref*) exit 127;; esac; case "$o" in *element2-item-open*) exit 0;; esac; exit 1
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-1.md:216`.

### pin 1136 — `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/scripts/validate-provenance-block.sh "[--require-skill <skill-name>]"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" archive "$THEIRS" core/scripts core/schemas >"$t/a.tar" 2>/dev/null && tar -xf "$t/a.tar" -C "$t" || { rm -rf "$t"; exit 127; }; v="$t/core/scripts/validate-provenance-block.sh"; [ -f "$v" ] || { rm -rf "$t"; exit 127; }; printf "no provenance block here\n" >"$t/probe.md"; AI_DLC_PROJECT_ROOT="$t" bash "$v" "$t/probe.md" >/dev/null 2>&1; a=$?; AI_DLC_PROJECT_ROOT="$t" bash "$v" "$t/probe.md" --require-skill bmad-review-adversarial-general >/dev/null 2>&1; c=$?; rm -rf "$t"; [ "$c" -eq 1 ] || exit 127; [ "$a" -eq 0 ]
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-1.md:280`.

### pin 1165 — `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLACEMENT`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc/steps/gate-validation.md "PRD gate (research-requirements phase)"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh g=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/steps/gate-validation.md") || exit 127; s=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/SKILL.md") || exit 127; r=$(LC_ALL=C awk "/^### Rule 20 /{f=1} f&&/^### Rule 21 /{exit} f" <<<"$s"); case "$r" in *bmad-prd*) ;; *) exit 127 ;; esac; case "$g" in *"planning-artifacts/prd.md"*) ;; *) exit 1 ;; esac; case "$r" in *prd.md*) exit 1 ;; esac; exit 0
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-2.md:62`.

### pin 1240 — `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/scripts/validate-locked-anchor.sh "claims_checked = 0"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh d=$(mktemp -d) || exit 127; git -C "$DIST" show "$THEIRS:core/scripts/validate-locked-anchor.sh" > "$d/v.sh" 2>/dev/null; [ -s "$d/v.sh" ] || { rm -rf "$d"; exit 127; }; printf "%s\n" "# L" "" "## A1" "- alpha requirement one" > "$d/locked-requirements.md"; printf "%s\n" "<!-- LOCKED_REQUIREMENTS -->" "<!-- Source: user input -->" "<!-- END LOCKED_REQUIREMENTS -->" > "$d/silent.md"; printf "%s\n" "<!-- LOCKED_REQUIREMENTS -->" "<!-- Source: user input -->" "requires_context: locked-requirements.md#A1" "- alpha requirement one" "<!-- END LOCKED_REQUIREMENTS -->" "" "<!-- LOCKED_REQUIREMENTS -->" "<!-- Source: user input -->" "<!-- END LOCKED_REQUIREMENTS -->" > "$d/mixed.md"; a=$(cd "$d" && bash "$d/v.sh" silent.md --sor locked-requirements.md 2>&1); b=$(cd "$d" && bash "$d/v.sh" mixed.md --sor locked-requirements.md 2>&1); rm -rf "$d"; case "$a" in *"carried no resolvable citation"*) ;; *) exit 127 ;; esac; [ "$a" != "$b" ] || exit 127; case "$b" in *"carried no resolvable citation"*) exit 1 ;; esac; exit 0
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-2.md:136`.

### pin 1361 — `PC-S297-GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc/steps/_gate-procedures.md "Execute the sub-skills back-to-back, with no pause for human input between them:"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh f=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/steps/_gate-procedures.md") || exit 127; c=$(LC_ALL=C awk "/^## Gate-adjudication dispatch/{f=1;next} f&&/^## /{exit} f" <<<"$f"); case "$c" in *run_in_background*) ;; *) exit 127 ;; esac; for s in "## Adversarial review dispatch" "## Adversarial repair dispatch"; do x=$(LC_ALL=C awk -v s="$s" "index(\$0,s)==1{f=1;next} f&&/^## /{exit} f" <<<"$f"); [ -n "$x" ] || exit 127; case "$x" in *run_in_background*) ;; *) exit 0 ;; esac; done; exit 1
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-2.md:197`.

### pin 1381 — `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/scripts/validate-steering-budget.sh "--transcript) TRANSCRIPT="
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh d=$(mktemp -d) || exit 127; git -C "$DIST" show "$THEIRS:core/scripts/validate-steering-budget.sh" > "$d/v.sh" 2>/dev/null; [ -s "$d/v.sh" ] || { rm -rf "$d"; exit 127; }; printf "%s\n" "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"probe\"}}" > "$d/probe-transcript.jsonl"; o=$(bash "$d/v.sh" --transcript "$d/probe-transcript.jsonl" 2>&1); rm -rf "$d"; case "$o" in *"transcripts scanned"*) ;; *) exit 127 ;; esac; case "$o" in *probe-transcript.jsonl*) exit 1 ;; esac; exit 0
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-2.md:251`.

### pin 1571 — `PC-S299-UPSTREAM-SHIPS-TWO-REVIEW-VERDICT-VOCABULARIES`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc/steps/gate-validation.md "CHANGES-REQUESTED"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh x=docs; git -C "$DIST" grep -qF EXIT_CONDITION_MET "$THEIRS" -- "$x/vocabulary-index.md" || exit 127; ! git -C "$DIST" grep -qF NEEDS_REWORK "$THEIRS" -- "$x/vocabulary-index.md"
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-3.md:95`.

### pin 1597 — `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "upstream absorbed this at"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh git -C "$DIST" grep -qE '^[[:space:]]*emit CLOSE-CANDIDATE' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/ || exit 127; git -C "$DIST" grep -qE '^[[:space:]]*emit CLOSE-CANDIDATE.*\(v\$TV,' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/ || git -C "$DIST" grep -qE '^[^#]*printf .%s. "\$TV"' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-3.md:143`.

### pin 2231 — `PC-S311-ENTRY-SWALLOWED-DETAIL-EMITS-A-LITERAL-BACKSLASH-U-ESCAPE-SO-A-VERBATIM-PASTE-FAILS-VERIFY`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "'- **…**' opens a NEW entry"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh git -C "$DIST" grep -qE '^[[:space:]]*emit ENTRY-SWALLOWED' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/ || exit 127; git -C "$DIST" grep -qE '^[[:space:]]*emit .*\\u2026' "$THEIRS" -- core/skills/ai-dlc-update/reconcile/
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-3.md:195`.

### pin 2372 — `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/scripts/validate-audit-anchors.sh "it does not police the trunk"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh s=core/scripts; git -C "$DIST" grep -qF 'if mode == "trunk-push":' "$THEIRS" -- "$s/validate-audit-anchors.sh" || exit 127; n=$(git -C "$DIST" show "$THEIRS:$s/validate-audit-anchors.sh" | LC_ALL=C grep -cE '^[^#]*findings[.]append[(]'); [ "$n" -gt 0 ] 2>/dev/null || exit 127; [ "$n" = 2 ]
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-3.md:247`.

### pin 3918 — `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc-update/SKILL.md "the consumer never edits them"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh s=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc-update/SKILL.md" 2>/dev/null | LC_ALL=C awk '/^2\. \*\*Self-update/,/^3\. \*\*Mechanical/'); [ -n "$s" ] || exit 127; p=$(LC_ALL=C grep -cF 'the consumer never edits them' <<<"$s"); d=$(LC_ALL=C grep -cE 'BOTH-CHANGED|semantic-merge|consumer-modified' <<<"$s"); [ "$p" -gt 0 ] && [ "$d" -eq 0 ]
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-4.md:108`.

### pin 4096 — `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT`

OLD (undecidable — the substring matches at BASE too):

```
verify: theirs_has core/skills/ai-dlc-update/SKILL.md "show <theirs>:templates/settings.json.template"
```

NEW (measured `rc=0` today, which is STILL-LIVE):

```
verify: sh s=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc-update/SKILL.md" 2>/dev/null); [ -n "$s" ] || exit 127; n=$(LC_ALL=C grep -cE 'show <theirs>:templates/settings\.json\.template.*> "\$t"' <<<"$s"); [ "$n" -gt 0 ]
```

Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close. Evidence, two-sided probe and the author's stated hesitation: `docs/reviews/graph-ledger-adjudication-data/step19-receipts/batch-4.md:224`.


## F — filed after the corpus pin (3)

These three were filed into this ledger AFTER upstream pinned the corpus, so they are not part of
the 115 and appear in no table above. All three were adjudicated against the working tree on the
same terms as the rest, all three are `HOLDS`-family — **3 for 3 on the base rate that a filing
understates or misstates its own mechanism** — and all three are now tracked upstream.

**Leave these open in your ledger.** They close when upstream ships the fix and cites the id.

Two of the three carried no `verify:` directive at all, so your closer emits no row for them; their
replacement receipts are in section E. One thing to note about the upstream receipts backing them:
they exit NON-zero while the defect is live, which is the opposite of the receipts in section E.
That is not an inconsistency — `docs/backlog.md` is read by a different engine
(`scripts/backlog-reverify.sh`) whose `sh` polarity is inverted relative to yours. Do not carry a
receipt across the boundary without re-reading its engine's dispatch.

| live line | entry | verdict | upstream |
|---|---|---|---|
| 4357 | `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX` | HOLDS-MECHANISM-WRONG | `BL-063` |
| 4392 | `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` | HOLDS-WIDER | `BL-064` |
| 4435 | `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKD...` | HOLDS-WIDER | `BL-065` |

## Evidence, and where to check any of it

- `graph-ledger-full-adjudication.md` — the register: method, controls, cross-cutting findings,
  and the 115-row verdict table.
- `graph-ledger-adjudication-data/phase1-verdicts.tsv` — 115 rows, one per open entry.
- `.../refutation-verdicts.tsv` — 48 rows, one per attacked close, with why it survived or fell.
- `.../final-disposition.tsv` — the merge. Sections A–D render from it.
- `.../step12-withdrawals.md` — section B's evidence, in each adjudicator's own words.
- `.../replacement-receipts.tsv` — section E's data.
- `CHANGELOG.md` — one `###` section per closed id.

## One thing upstream got wrong, stated plainly

The plan driving this work asserted for its entire life that citing a closed id in `CHANGELOG.md`
would produce a `NAMED-UPSTREAM` row. **It does not.** `named_absorbed()` resolves that signal
with `git log -F --grep`, which reads COMMIT MESSAGES; a CHANGELOG section is in the commit's
DIFF and never its message. Measured over the 29 citable ids, both channels in one invocation: 4
appeared in a message, 8 in the CHANGELOG blob, 16 in neither — and the four sitting in the
CHANGELOG and not in a message were cited exactly as prescribed and resolved to nothing.

Every id closed in this release is therefore in the release commit MESSAGE as well. Measured
before and after: 9 of 29 resolved before, 29 of 29 after, with an impossible-id control at 0
throughout.
