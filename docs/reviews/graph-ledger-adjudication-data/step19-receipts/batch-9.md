# Step 19 — batch 9

Four pins, all `NO-RECEIPT` in the census, so every OLD fence carries the absent-directive line.

Corpus pin re-derived before reading any entry: `sed -n 1,4356p` of the consumer ledger is
`2fd444dcf406cdff728fe3c0c4352267`; the 4355-line control is `d4e39a96a33c5c92adfe4c8457020064`,
which differs, so the pin is the pin and not an artefact of a truncating read.

Two of the four are `manual`, and neither is `manual` because a predicate was hard. Pin 687's
subject was fixed upstream **before** `BASE`, so no predicate over the `BASE..THEIRS` window can
ever flip; pin 776's subject has never existed upstream at all. Pin 687 is a finding against this
batch's own premise and is flagged as such below.

## Pin 687 — `PC-S296-SNAPSHOT-BUDGET-UNENFORCED-AT-GATES`

**Re-derivation.** The entry's claim is that Check 14 refreshes the snapshot and Check 15 verifies
it and *neither reads its size*. Tested against the spans themselves, not against a whole-file
grep: `core/skills/ai-dlc/steps/gate-validation.md:870` reads `**Snapshot budget (Rule 25(d)) —
this check FAILS if the snapshot is over it.**` and `:873` runs `scripts/ai-dlc/verdict.sh
validate-artifact-budget --only pipeline-snapshot.md` inside Check 14 (span 760-930, 170 lines);
`:951` runs `scripts/ai-dlc/verdict.sh validate-artifact-budget --check-evidence` inside Check 15
(span 931-975, 44 lines), whose own text requires the Check 14 row's `evidence` cell to carry the
validator's measured token count and FAILS the gate on exit 1. Both halves therefore read the
size, which is exactly the fix the entry proposed ("the size read belongs there, at zero marginal
cost"). Control in the same invocation: the token `ZZQQ-NOT-PRESENT` returns 0 against the same
extracted spans while each real anchor returns 1, so the greps discriminate rather than matching
everything. **And the fix predates the corpus base**: counted at `adec9ae` (BASE) and at
`2db4035` (THEIRS), the budget-run line and the `--check-evidence` line are each present 1/1 at
BOTH revisions, and `git log -S'--check-evidence' -- core` resolves the introduction to `f491d64`
at `VERSION` `0.123.0`. The independent refuter reached the same place from the other side — its
verdict text says the entry is "closable as ALREADY-FIXED at v0.118.0 + v0.123.0, NEVER as
FALSIFIED" — so what the refutation withdrew was the *close reason*, not the close.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: manual already fixed upstream BEFORE the corpus base, so no machine predicate over the BASE..THEIRS window can ever flip. Check 14 reads the snapshot's size at gate-validation.md:870-873 (verdict.sh validate-artifact-budget --only pipeline-snapshot.md, and the check FAILS on over-budget) and Check 15 verifies the measured token count at :951 (--check-evidence); both lines are present at BASE adec9ae and at THEIRS, 1/1 each, and --check-evidence entered core at f491d64 (v0.123.0). An sh receipt exiting 0 here would assert a STILL-LIVE that is false; one exiting non-zero would credit an absorption to a release inside the window that did not produce it. Adjudicate by hand as ALREADY-FIXED (pre-base), not as FALSIFIED and not as a filer error.
```

**Measured today: rc=n/a (`manual` is not executed; the engine reports HAND-REVIEW).**

**Two-sided probe.** Not applicable to a `manual` receipt — the engine never executes it. The
underlying measurement was two-sided in the axis that matters: the same three anchors were counted
at BASE and at THEIRS and agreed 1/1 at both (so the window contains no change to attribute),
against a control token measured 0 at both. Both directions of the control were read, not just the
one that agreed with the verdict.

**Anchor shapes checked.** Quote-back: this is the shape that nearly ate this pin — core's Check 14
prose now *contains* the entry's own reasoning ("A snapshot over budget means the schema stopped
being enforced at gate passages", and the sentence about the artifact still growing being the whole
reason the budget is enforced at gates), so any prose-anchored receipt would return 0 forever and
read as STILL-LIVE against a subject that is fixed. Invented phrasing: the filing's word was
"size", which appears nowhere in the mechanism; the code's tokens are `--only
pipeline-snapshot.md` and `--check-evidence`. Fix's own clause: not reached, no `sh` receipt is
proposed.

**Hesitation.** This pin was handed to me as LIVE and I am returning it as fixed-before-base, which
is a disagreement with the batch premise rather than a receipt. If the operator's intent is that
the refutation's withdrawal restores liveness *as a matter of register bookkeeping* regardless of
the tree, then the honest engine output is still not rc=0 — it is a non-zero CLOSE-CANDIDATE that
the extractor refuses by design, which is why this is `manual` and not `sh`. `manual` is also the
only direction that cannot lose data here: HAND-REVIEW neither retires a live defect nor asserts a
fixed one is live.

## Pin 701 — `PC-S296-PIPELINE-POSITION-MUST-BE-EDITED-IN-PLACE`

**Re-derivation.** The entry's own stated fix is "one clause in the Check-14 schema", so the
receipt is scoped to that clause's absence in the schema span rather than to the hook's behaviour.
`core/skills/ai-dlc/steps/gate-validation.md:773-800` is the **Pipeline Position** bullet of Check
14's canonical seven-section schema; it says `update current_step_file (just completed)` and
carries no statement that the field is single-valued or must be overwritten where it sits. The
control is a sibling clause **inside the same extracted span**: the routing record is described as
"written once by `route.md` Step 6 and never rewritten after" (`:780-781`), which proves both that
the extraction landed on the right bullet and that core's schema prose *can* express a write
discipline for a field in this section — it simply does not do so for the position fields. A second
instance of the same vocabulary sits one bullet later at `:826-828`, where **In-Flight Teammates**
is bound to "**Rows only. No prose, no struck-through history**" with `validate-artifact-budget.sh`
failing on a struck row. So the absence is a gap in this bullet, not a house style.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md") || exit 127; s=$(LC_ALL=C awk '/^- \*\*Pipeline Position\*\*/{f=1} f&&/^- \*\*Sprint Context\*\*/{exit} f' <<<"$f"); [ -n "$s" ] || exit 127; LC_ALL=C grep -qF 'never rewritten after' <<<"$s" || exit 127; LC_ALL=C grep -qF 'current_step_file' <<<"$s" || exit 127; ! LC_ALL=C grep -qiE 'in place|in-place|overwrit|single-valued|single value|rather than append|not append|never append|replaces? the (existing|previous|prior|older)' <<<"$s"
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 against the real tree at `$THEIRS`, and rc=0 again against a scratch
`mktemp -d` git repo holding the same blob (so the harness reproduces the real answer before it is
trusted). Mutant: the clause the entry asks for, inserted into the Pipeline Position bullet — "This
section is SINGLE-VALUED: overwrite these fields in place at every gate rather than appending a
newer state block above the previous one." — rc=1. The two trees were `cmp`'d before the outputs
were compared and the harness aborts with `PROBE BROKEN` if the mutator changed nothing; `cmp`
returned non-zero, so the sides genuinely differ. Every extraction step is 127-guarded: a missing
file, an empty span, a reshaped bullet that loses either control token all exit 127, never a bare
non-zero.

**Anchor shapes checked.** Quote-back: this receipt is inverted against the quote-back hazard — it
matches on the fix's *presence* to close, so a fix that documents what it added cannot keep the
receipt at 0; the risk runs the other way and is covered in the hesitation. Invented phrasing: the
filing's own words ("append-ordered log", "single-valued field") were grepped against core and
`single-valued` appears nowhere, so the receipt does not depend on them — the alternation is a set
of forms a fix could plausibly use, and it measured 0 hits against today's span. Fix's own clause:
the closing arm cannot be satisfied by a comment recording a removal, because it reads only the
extracted bullet span and not the whole file.

**Hesitation.** The verdict on this pin is `HOLDS-MECHANISM-WRONG`, and the wrong mechanism is not
incidental: both readers take the FIRST match — `core/hooks/ai-dlc-continue.sh:559` pipes through
`head -1` and `core/hooks/ai-dlc-recover.sh:71` uses `grep -m1` — so a correction appended *above*
the live bullet is the one that gets read, which is the opposite of the staleness the filing
describes. My receipt deliberately does not depend on that story; it tests the schema clause the
entry asks for. But that means a fix delivered on the *reader* side instead of the schema side
would leave this receipt reporting STILL-LIVE, and the alternation is a guess at wording rather
than a token the code emits.

## Pin 715 — `PC-S296-DEPLOY-VALIDATE-NA-RITUAL`

**Re-derivation.** The close was refuted and NARROWED, not falsified, so the receipt is anchored on
the half that survived: per the refutation, `deploy-validate.md:292` mandates a disposition "an N/A
disposition owed for Step 4 EVEN WHEN STEP 4'S POPULATION IS EMPTY". Re-derived at `$THEIRS`:
`core/skills/ai-dlc/steps/deploy-validate.md:243` guards Step 4 itself with `If is_ui_epic ==
true:`, yet the Step 5 Production Validation Checkpoint template (span `:275-309`) lists `- Visual
verification: PASSED / N/A` unconditionally at `:292`, with no clause permitting its omission — so
a non-UI sprint still owes the line. Control in the same invocation: the sibling `- Smoke tests:
PASSED / FAILED` is present in the same extracted span (and its absence is a 127, not a close),
while a scan of that span for any omission clause returns 0. The refutation's own control is
reproduced too — the filer's word "determination" returns 0 against core, which is why the original
absence-shaped close was wrong; the artefact is spelled `N/A`, and it is there.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh f=$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/deploy-validate.md") || exit 127; s=$(LC_ALL=C awk '/^### 5\. Production Validation Checkpoint/{f=1} f&&/^### 6\. Wait for Human/{exit} f' <<<"$f"); [ -n "$s" ] || exit 127; LC_ALL=C grep -qFe '- Smoke tests: PASSED / FAILED' <<<"$s" || exit 127; LC_ALL=C grep -qxFe '- Visual verification: PASSED / N/A' <<<"$s" || exit 1; ! LC_ALL=C grep -qiE 'omit|only if|only when|if is_ui_epic|is_ui_epic == false|non-UI|skip this line|leave (it|this line) out' <<<"$s"
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 against the real tree and rc=0 again against the scratch git repo
holding the same blob. Two mutants, because the fix has two plausible shapes and a receipt that
only survives one of them is half a receipt: (a) delete the unconditional line — rc=1; (b) keep it
but condition it, `- Visual verification: PASSED / N/A  (omit this line when is_ui_epic == false)`
— rc=1. Both trees `cmp`'d against the original and asserted to differ before the exit codes were
compared, with the harness failing loudly if a mutator is a no-op. 127 guards on the file read, on
an empty span, and on the sibling control line.

**Anchor shapes checked.** Quote-back: the presence arm is on a template line the fix must *remove
or qualify*, so a fix that documents its removal in a comment still flips it — the comment sits
outside the extracted `### 5.` span. Invented phrasing: the filing's "determination" and "nothing
to check" are the filer's words, measured 0 against this file, and are not used; the receipt uses
the bytes the template actually emits. Fix's own clause: mutant (b) is exactly that case — a fix
whose closing wording contains `N/A` — and it returns non-zero because the omission arm fires on
the qualifier.

**Hesitation.** The receipt covers only the narrowed Step 4 half. The entry's headline claims four
N/A steps and the refutation put its population overstatement at roughly 4:1, so a fix that removes
the other three ritual dispositions and leaves `:292` untouched will keep this reading STILL-LIVE
on the strength of the one instance that survived scrutiny. The `omit` alternation is also broad
enough to be tripped by unrelated future prose in that span; it measured 0 today, but that is a
false-positive set of one measurement on one revision.

## Pin 776 — `PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD`

**Re-derivation.** `NOT-UPSTREAM`, and the subject is absent from the distribution in the strong
sense. At `$THEIRS`, `git grep -c normalize-backlog-status -- core` exits 1 with no output, and the
control in the same invocation — `git grep -c 'count OPEN' --
core/skills/ai-dlc/steps/carry-over-evaluation.md` — returns 1 and exits 0, so the search ran
against a corpus that can answer. Widening the same grep to the whole tree returns exactly one
path, `docs/reviews/graph-goal2-triage-worksheet.md`, which is this repo's own review notes *about*
the consumer and is not part of the distribution. It has never been in core at all:
`git log -S'normalize-backlog-status' -- core` returns 0 commits over the whole history, so this is
not a relocation. And the premise's other half fails on its own text — `carry-over-evaluation.md:73`
reads "**Backlog health check.** Before per-item evaluation, count OPEN items and flag any older
than 10 sprints", naming **no** method, canonical or manual, so there is no "two standing methods"
for a fix to collapse. The ledger's own relocation preamble reaches the same conclusion for the
same reason ("there is nothing upstream to re-verify against"), which is corroboration and not the
evidence.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: manual no upstream subject exists, so no anchor can ever flip. The script the premise names, normalize-backlog-status, has never been in core: git grep at THEIRS over core exits 1 with no output while the control 'count OPEN' in core/skills/ai-dlc/steps/carry-over-evaluation.md returns 1, and git log -S over the whole history returns 0 commits under core; its only occurrence anywhere in this repo is docs/reviews/graph-goal2-triage-worksheet.md, which is review notes about the consumer and not part of the distribution. The premise's other half is false at carry-over-evaluation.md:73, which says only to count OPEN items and flag any older than 10 sprints and names NO method, so there are not two standing methods upstream to collapse. Both standing methods, the 68-vs-70 disagreement and CO-S292-BACKLOG-STATUS-RESIDUAL-FORMS are consumer-local; route to the consumer's own backlog and keep the sound underlying observation there.
```

**Measured today: rc=n/a (`manual` is not executed; the engine reports HAND-REVIEW).**

**Two-sided probe.** Not applicable to a `manual` receipt. The absence claim underneath it is
nevertheless two-sided in the same invocation: the target grep exits 1 with no output while the
control grep over the same corpus returns 1 and exits 0, and the history probe distinguishes "never
present" from "moved" — without that second arm a relocation would read as an absence, which is the
exact failure the 127 guard exists to prevent for `sh` receipts.

**Anchor shapes checked.** Quote-back: no `sh` anchor is proposed, so the hazard does not arise;
had one been written on the filer's phrase "standing methods" it would have matched the ledger's
own wording and nothing in core. Invented phrasing: this is the pin where that failure is total —
the entire premise is a phrasing the filing invented about a file that says something else. Fix's
own clause: not reached.

**Hesitation.** `manual` for a `NOT-UPSTREAM` entry is a HAND-REVIEW row that a human must still
dispose of, and the entry already sits in the ledger's "Not push candidates" relocated section, so
the risk is that it is re-adjudicated forever without anyone acting. The narrow factual soft spot
is the whole-tree grep: it is scoped to this repo, and I did not check whether some *other*
distribution artefact refers to the counting method under a different name — a rename would defeat
the history probe, though `carry-over-evaluation.md:73` naming no method at all makes that mostly
moot.
