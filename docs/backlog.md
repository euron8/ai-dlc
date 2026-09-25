# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:241-250` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:942` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.

## BL-275 — a shared detector's cost-saving flag is bound by NO fixture at any CALLER, so a second caller can silently stop passing it

**DEFECT.** Found while scoping `0.597.0`, by censusing `reconcile-emit-report` and then ablating
the detectors its renderer drives.

**THE FLAG IS COVERED AND THE CALLERS ARE NOT.** `unregistered-drift.sh` takes
`--bucket-rows <file>` so a caller already holding `preclassify.sh`'s output hands it down instead
of making the scan re-derive it in a second process. Two arms own its SEMANTICS:
`apply-drift-after-write/run.sh:430` asserts the flagged and standalone scans agree row-for-row,
and `:442` asserts an EMPTY rows file does not acquit. Both are statements about the SCAN. **Not
one arm anywhere asserted that any CALLER passes it.**

**THE GAP WAS LIVE AND COST THE SUITE MEASURABLY.** `apply.sh:504` has passed the flag since it
existed. `emit-report.sh` computed those exact rows at `:204` and then drove the scan at `:418`
with no flag, re-deriving them every render — measured on the fixture's own seeded tree, 5
interleaved reps with the outputs byte-compared every rep: **789-949ms without against 610-723ms
with**, disjoint ranges, in a detector that is 586-661ms of a 1456-1556ms render. Fixed at
`0.597.0`, and `B1`/`B2` in `reconcile-emit-report/run.sh` now bind THAT caller.

**THE REMAINING EXPOSURE IS THE GENERAL SHAPE, NOT THIS INSTANCE.** `apply.sh`'s own passing of
the flag is still bound by nothing: deleting `--bucket-rows` from `:504` restores the cost, changes
no verdict, and every arm stays green. Derived at this tip: **2** callers pass the flag at an
executing line, **1** of them (`emit-report.sh`) is bound by a fixture arm keyed on its emission
site, against an impossible-flag control of 0 in the same grammar.

**WHY AN EMISSION-SITE KEY AND NOT A FILE GREP.** Measured while building `B1`: a whole-file
`grep -cF -- '--bucket-rows'` reads **1** on a renderer that mentions the flag only in a COMMENT
and passes it nowhere — the header of `unregistered-drift.sh` documents the flag, and this entry's
own prose would satisfy it too. The arm has to grep the line that EXECUTES the scan.

**What is owed.** An arm binding `apply.sh:504`'s emission site the way `B1` binds
`emit-report.sh`'s, in whichever of `apply-drift-after-write` or its siblings already drives that
path — cheaper than a new fixture, and it closes the pair. The broader form (derive the caller set
and require each to be bound) is the stronger fix and needs a join key that does not exist yet.

**Tiered DEFECT, not BLOCKER.** No verdict is wrong in either direction: the flag changes who paid
and never what is answered, which is exactly why its absence was invisible for as long as it was.

verify: sh a=core/skills/ai-dlc-update/reconcile/apply.sh; ctl=$(grep -rchE -- '--bucket-rows-ZZQQ' core/fixtures 2>/dev/null | awk '{s+=$1} END{print s+0}'); [ "$ctl" -eq 0 ] || exit 1; grep -qE '^[[:blank:]]*UD_FLAG="--bucket-rows"' "$a" 2>/dev/null || exit 1; for g in core/fixtures/*/run.sh; do grep -qE 'grep [^|]*-c[^|]*UD_FLAG="--bucket-rows"|grep [^|]*-c[^|]*bucket-rows[^|]*"\$APPLY"|grep [^|]*-q[^|]*--bucket-rows[^|]*"\$APPLY"' "$g" 2>/dev/null && exit 0; done; exit 1

## BL-274 — `--arms <indented-id>` runs the whole enclosing unit, so timing one arm that way measures up to twelve, and nothing says so

**DEFECT.** Found while scoping `0.596.0` against the wall-clock plan's by-arm fork table, after
a release was very nearly scoped on the wrong arm twice.

**THE MECHANISM IS CORRECT AND THE MEASUREMENT BUILT ON IT IS NOT.** `ARMS_SELECT_AWK` merges an
INDENTED arm header upward into the enclosing column-0 unit — deliberate, documented at the
selector, and required, because an indented arm reads values the column-0 prologue computes. The
consequence nobody wrote down is that `--arms I61`, `--arms I64` and `--arms I41` all execute the
SAME twelve-arm layer-contract unit, so `/usr/bin/time -p bash …/validate-enforcement-map.sh
--arms <id>` is a reading of the UNIT and not of the arm named on the command line.

**IT READS AS AN ARM COST AND THERE IS NO TELL.** The run prints the ordinary OK line and exits
0; nothing in stdout, stderr or the exit code distinguishes "ran one arm" from "ran twelve". The
discriminating measurement is one line: **`I41`, an arm with FOUR forks, times at 4.29s.** Nine
arms of that unit timed 4.12–4.30s on one tree — identical by construction, which reads as nine
arms that happen to cost the same.

**MEASURED COST OF THE WRONG READING.** Subtracting a baseline taken from an arm OUTSIDE the
block scored `I61` at 4.75s and `I64` at 4.67s against `I75`'s 0.86s, which inverted the plan's
target, and a memo was built against `I64` on that basis. It was byte-identical in output and a
REGRESSION in the currency: I64 181 → 234 forks, file total 3203 → 3257. Reverted unshipped. The
real subject, found only by ABLATION with each run's exit code asserted, was `I65` at ~2.7s of
the unit's 4.5s.

**THE EXPOSURE IS NOT ONE UNIT.** Derived at this tip: **15** indented arm headers against 103
column-0 ones (control: an impossible `ZZQQ` header scores 0). Every one of them mis-times the
same way, and the layer-contract unit is merely the largest.

**What is owed.** Either `--arms` reports the unit it actually selected and its member ids on
stderr — cheap, and it makes the granularity visible at the moment a reader is about to time it
— or the plan's action 1 stops quoting per-arm seconds taken this way and says ablation is the
only per-arm instrument. The first is the stronger form: it fixes the instrument rather than
warning about it, and `fork-profile.sh --section by-arm` already attributes per arm correctly,
so only the TIMING path is blind.

**Tiered DEFECT, not BLOCKER.** No shipped verdict is wrong — the selector runs exactly the arms
it must, and every invariant still fires. What is broken is a measurement practice this repo's
own plan instructs sessions to use, and it has now produced two wrong scopings in one session.

verify: sh v=scripts/validate-enforcement-map.sh; r=scripts/render-invariant-index.sh; [ -f "$v" ] || exit 9; [ -f "$r" ] || exit 9; grep -q 'ARMS_SELECT_AWK' "$v" || exit 9; ind=$(awk '/^[[:blank:]]+#[[:blank:]]*---[[:blank:]]*I[0-9]/{n++} END{print n+0}' "$v"); ctl=$(awk '/^[[:blank:]]+#[[:blank:]]*---[[:blank:]]*ZZQQ/{n++} END{print n+0}' "$v"); [ "$ctl" -eq 0 ] || exit 9; [ "$ind" -gt 0 ] || exit 9; bash "$r" --arm-lines "$v" >/dev/null 2>&1 || exit 9; out="$(bash "$v" --arms I41 2>&1 >/dev/null)"; printf '%s' "$out" | grep -qiE 'unit|also runs|selected arms' && exit 0; exit 1

## BL-254 — the `sh` receipt's base control is new, and nothing here asserts a consumer's INSTALLED engine ever runs it

**DEFECT.** Filed against `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh` from the
consumer-filed candidate
`PC-S344-SH-RECEIPTS-GET-NO-BASE-CONTROL-SO-STILL-LIVE-CANNOT-BE-READ`, whose subject shipped in
this release. What is owed is the half the fix cannot deliver: a consumer executes the engine it
LAST INSTALLED, so the pull that carries this fix is classified by the engine WITHOUT it, and
every `RECEIPTS-UNDECIDED` row an operator reads before that pull lands is missing the `sh`
numerators entirely. The row is identical in shape either way — one line, same status token,
same entry column — so the state "this engine has no `sh` base control" and the state "this run
had no undecided `sh` receipts" are the same bytes on the operator's report.

**WHY IT IS A DEFECT AND NOT A NOTE.** The `sh` verb is what most receipts use, and the count the
row carries is the only thing separating a `STILL-LIVE` that measured something from one that
restated the previous run. Measured on the reference consumer across `0.576.0→0.577.0`
(`base..theirs` = 14 files): **20 of 20** eligible `sh` receipts undecided, **0** control-refused.
A row absent for the engine-version reason reads as "nothing to report" on a corpus where the
honest answer was twenty. `consumer-boundary.md` already states the general form — a core fixture
ships ahead of its subject — and the specific consequence here is that the first post-fix report
is the only one whose silence is trustworthy, and nothing tells the reader which report that is.

**WHAT THE SHIPPED FIX ESTABLISHES AND WHAT IT DOES NOT.** Three helpers (`refs_differ`,
`sh_base_eligible`, `sh_base_control`) resolve the base run three ways — exit 0 → undecided,
126/127 → control-refused and counted separately, otherwise decided — at BOTH the `STILL-LIVE`
site and the `CLOSE-CANDIDATE` site, folded into the existing `RECEIPTS-UNDECIDED` row with no
new status token. That is verified by execution here. What is NOT established is that any
consumer has an engine carrying it, and no predicate resolving against THIS tree can observe a
consumer's installed copy.

**Receipt limits, stated.** The receipt below drives the SHIPPED engine against a four-receipt
synthetic ledger in a throwaway distribution repo, and requires the emitted row to carry all
three `sh` clauses with their derived numerators — the still-live clause at `1 of 3`, the close
clause at `1 of 1`, and a refused count of `1`. It asserts the four per-entry verdicts first, so
a run whose corpus collapsed cannot satisfy it by emitting nothing. **It cannot score the
delivery half**, which is the entry's actual subject: it says the engine in THIS tree computes
the control, never that a consumer's installed engine does. Closing this needs a stated
measurement from a consumer that has pulled the fix — a `RECEIPTS-UNDECIDED` row carrying a `sh`
numerator, taken from that consumer's own run — and no `sh` predicate resolving here can observe
it. **SO THE RECEIPT READS `CLOSE-CANDIDATE` FROM THE DAY IT IS FILED, and a drain acting on
that row alone closes the delivery half unmeasured.** `validate-backlog-receipts.sh` classifies
it `ALREADY-PASSING`, which is not a finding in either direction, and `BL-236` sits in the same
class for the same reason — its receipt scores a prose half while its subject is an arm nobody
built. Read the row as "the engine in this tree computes the control", never as "the entry is
closable". **It also cannot score the ARITHMETIC against a real corpus.** The three numerators are
derived from a seeded ledger whose every case the receipt planted; an engine mis-classifying a
receipt shape this seed does not contain scores closed. Exit 9 if the engine file is absent or
the seeded differential cannot be built — the mover is asserted present at theirs and absent at
base BEFORE any comparison is read, because a differential whose two sides do not differ reports
every receipt undecided and reads as a working control.

**SCORED AGAINST FOUR BUILDS, each `cmp`-asserted to differ from the real fix and `bash -n`
asserted to parse.** Polarity checked at the emitter: `scripts/backlog-reverify.sh:244` reads
**exit 0 as CLOSE-CANDIDATE, the fix is present** — the OPPOSITE of the consumer engine this
entry is about, whose `:1913`/`:1949` sites read exit 0 as STILL-LIVE.

| build | receipt | which clause it loses |
|---|---|---|
| the real fix | **0 — present** | none; all three clauses satisfied |
| pre-fix engine + a comment naming `base_show`, `base_holds` and `THEIRS="$BASE"` | 1 — absent | no row at all |
| the fix with the `126\|127)` refusal arm deleted (two-arm, fails-open) | 1 — absent | the refused clause |
| the fix with the CLOSE-path `sh_base_control` call deleted | 1 — absent | the close clause |

Each non-fix loses a DIFFERENT clause, so none of the three fails for a reason it does not own.
The comment-only build is the one PC-S344's own proposed receipt closed on: a whole-arm
`grep -qE 'base_holds|base_show|THEIRS="\$BASE"'` is satisfied by that comment, which is why this
receipt keys on the emitted row's derived content rather than on the arm's text.

verify: sh E=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; [ -f "$E" ] || exit 9; d=$(mktemp -d) || exit 9; D="$d/dist"; C="$d/cons"; mkdir -p "$D/core/scripts" "$C/_bmad-output/ai-dlc-update" || exit 9; git -C "$D" init -q || exit 9; printf 'SAME_AT_BOTH\n' > "$D/core/scripts/same.sh"; printf 'OLD\n' > "$D/core/scripts/moved.sh"; git -C "$D" add -A && git -C "$D" -c user.email=p@p -c user.name=p commit -qm base || exit 9; B=$(git -C "$D" rev-parse HEAD) || exit 9; printf 'NEW_ONLY_AT_THEIRS\n' > "$D/core/scripts/moved.sh"; git -C "$D" add -A && git -C "$D" -c user.email=p@p -c user.name=p commit -qm theirs || exit 9; T=$(git -C "$D" rev-parse HEAD) || exit 9; git -C "$D" show "${T}:core/scripts/moved.sh" | grep -q NEW_ONLY_AT_THEIRS || exit 9; git -C "$D" show "${B}:core/scripts/moved.sh" | grep -q NEW_ONLY_AT_THEIRS && exit 9; git -C "$D" show "${B}:core/scripts/same.sh" | grep -q SAME_AT_BOTH || exit 9; mkdir -p "$d/bin" || exit 9; printf '#!/bin/sh\nexit 0\n' > "$d/bin/tool-$T"; chmod +x "$d/bin/tool-$T" || exit 9; [ -x "$d/bin/tool-$B" ] && exit 9; printf '%s\n' '# p' '' '## PC-R1' '' 'verify: sh git -C "$DIST" show "${THEIRS}:core/scripts/same.sh" | grep -q SAME_AT_BOTH' '' '## PC-R2' '' 'verify: sh git -C "$DIST" show "${THEIRS}:core/scripts/moved.sh" | grep -q NEW_ONLY_AT_THEIRS' '' '## PC-R3' '' 'verify: sh git -C "$DIST" show "${THEIRS}:core/scripts/same.sh" | grep -q ABSENT_AT_BOTH_REFS' '' '## PC-R4' '' "verify: sh $d/bin/tool-\$THEIRS" > "$C/_bmad-output/ai-dlc-update/push-candidate-ledger.md" || exit 9; o=$(bash "$E" "$D" "$B" "$C" "$T" 2>/dev/null); [ "$(printf '%s\n' "$o" | grep -c '^STILL-LIVE	PC-R1	')" -eq 1 ] || exit 9; [ "$(printf '%s\n' "$o" | grep -c '^STILL-LIVE	PC-R2	')" -eq 1 ] || exit 9; [ "$(printf '%s\n' "$o" | grep -c '^CLOSE-CANDIDATE	PC-R3	')" -eq 1 ] || exit 9; [ "$(printf '%s\n' "$o" | grep -c '^STILL-LIVE	PC-R4	')" -eq 1 ] || exit 9; u=$(printf '%s\n' "$o" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}'); [ -n "$u" ] || exit 1; case "$u" in *"1 of 3 'verify: sh' receipt(s) reported STILL-LIVE and exited 0"*) ;; *) exit 1 ;; esac; case "$u" in *"AND 1 of 1 'verify: sh' CLOSE-CANDIDATE(s) ALSO exited non-zero at BASE"*) ;; *) exit 1 ;; esac; case "$u" in *"1 'verify: sh' base control(s) REFUSED"*) ;; *) exit 1 ;; esac; exit 0

## BL-238 — the consumer ledger's `theirs`-ref receipt grammar cannot key on an ARM's body, so a receipt written to ask a behavioural question is satisfied by a comment

**Found 2026-09-11** while closing a consumer candidate whose own receipt was built to avoid an
unfalsifiable predicate and landed on a different unfalsifiable one. The subject is the RECEIPT
GRAMMAR, not that candidate — its fix has landed.

**THE MEASUREMENT.** The candidate's receipt asked the behavioural question *does an entry-keyed
subtraction appear anywhere inside this arm* by windowing the arm with `awk` and grepping the
window for a variable name:

```
git -C "$DIST" show "${THEIRS}:core/scripts/audit-layer-debt.sh" \
  | awk '/^undeclared = \[\]/,/^if undeclared:/' | grep -q 'owed_entries' && exit 1 || exit 0
```

Scored against five candidates built as copies, each asserted APPLIED by `cmp -s` before its
verdict was read, it **CLOSED on four things that are not the fix**: a one-line COMMENT naming
`owed_entries` inside the window (behaviour unchanged, 32 reported before and after); the arm
SUPPRESSED entirely, which reports `UNDECLARED (0)` forever and loses every real obligation; a
subtraction keyed on the `(clause, entry)` PAIR, which is what the filed remedy's wording
literally says and leaves the defect live on any row whose clause differs from the declaring
row's; and the variable name inside a STRING LITERAL in the report payload. It correctly stayed
open on a pure reflow. **And it did NOT close on the real fix as first written**, because the
derivation sat one line above the `awk` window — a correct fix reading as unlanded.

**THE GENERALISATION, AND IT IS WHY THIS IS FILED.** A consumer receipt resolves against a
`theirs` ref, so `git show | grep` is the only verb available to it: it cannot execute the
subject, because the subject at that ref is not installed anywhere. Every receipt asking a
BEHAVIOURAL question through that grammar is therefore a text search, and
`verification-discipline.md`'s "a whole-file `grep -qF` is satisfied by a comment" applies to a
WINDOWED grep exactly as it does to a whole file — narrowing the window shrinks the set of
satisfying comments without emptying it. `core/fixtures/ledger-reverify-unfalsifiable/` already
measures the mirror error (a predicate that can never go green); this is the direction that goes
green wrongly, and nothing measures it.

**What the fix is NOT.** Not a wider window — the comment lives inside any window containing the
line. Not a "no comment lines" filter either: two of the four non-fixes carry no comment at all.
The shape that discriminated all six candidates in this measurement is a receipt that RUNS the
subject against a two-row synthetic register and reads which rows it reports, which the ledger
grammar cannot express at a ref. So the candidate fix is upstream: either the ledger engine gains
a verb that can drive an installed subject at HEAD rather than reading a ref, or the grammar grows
a way to ask a structural question (an AST predicate over the extracted python) that a comment
cannot answer. Both are engine changes, which is why this is an entry and not an edit.

**Receipt limits, stated.** The receipt below scores the SUBJECT of the closed candidate, not the
grammar defect — it drives `audit-layer-debt.sh` against a synthetic register in which one entry
declares its `owed` on a LATER row and another declares none, and requires the first to be cleared
while the second is still reported. That is the discriminating pair, and it refuses (exit 9) if the
arm reports neither, so a disarmed subject cannot read as a fix. **It does not and cannot score the
grammar defect**, because the grammar's own limitation is that a receipt cannot execute a ref;
closing this needs a stated finding about what the ledger engine gained, and no `sh` predicate here
can observe that. Exit 9 if the subject is absent.

verify: sh s=core/scripts/audit-layer-debt.sh; [ -f "$s" ] || exit 9; d=$(mktemp -d) || exit 9; printf "%s\n" "{\"clause\":\"LC-E4\",\"entry\":\"e/x.md\",\"subject_digest\":\"0000000000000000000000000000000000000000\",\"verdict\":\"still-additive\",\"recorded_utc\":\"2026-01-01T00:00:00Z\",\"reason\":\"The split remains deferred to a later pull.\"}" "{\"clause\":\"LC-O15\",\"entry\":\"e/x.md\",\"subject_digest\":\"1111111111111111111111111111111111111111\",\"verdict\":\"still-additive\",\"recorded_utc\":\"2026-01-02T00:00:00Z\",\"reason\":\"declaring it\",\"owed\":{\"id\":\"OWED-1\",\"what\":\"w\"}}" "{\"clause\":\"LC-E4\",\"entry\":\"e/y.md\",\"subject_digest\":\"0000000000000000000000000000000000000000\",\"verdict\":\"still-additive\",\"recorded_utc\":\"2026-01-01T00:00:00Z\",\"reason\":\"The split remains deferred to a later pull.\"}" > "$d/r.jsonl" || exit 9; o=$(bash "$s" --register "$d/r.jsonl" --json 2>/dev/null) || { rm -rf "$d"; exit 9; }; rm -rf "$d"; u=$(printf "%s" "$o" | python3 -c "import json,sys; print(\" \".join(r[\"entry\"] for r in json.load(sys.stdin)[\"undeclared\"]))") || exit 9; case " $u " in *" e/y.md "*) : ;; *) exit 9 ;; esac; case " $u " in *" e/x.md "*) exit 1 ;; esac; exit 0

## BL-236 — the note that makes `ai-dlc-update`'s braced rev-paths survive a retype has no mechanism behind it, and arm S8 cannot see the form a reader actually mistypes

**Found 2026-09-11**, filed by the reference consumer as a candidate against
`core/skills/ai-dlc-update/SKILL.md`. The prose half landed with the entry; what is owed is the
enforcement, and the reason it is owed is that the arm which looks like the enforcer is not one.

**THE ARM DOES NOT COVER THE FORM.** `validate-shell-portability.sh`'s S8 already spells this
exact rule in its own `S8_WHY` — history modifiers, `:c`/`:t`, "QUOTING DOES NOT FIX IT; only the
braces do" — so the program exists and a second one must not be built. But its pattern is
`(show|cat-file -p|…)[[:space:]]+\\?"?<[^>]+>:`, which is keyed on an **angle-bracket
placeholder**. Derived by extracting `S8_PAT` from the shipping file and running it against four
renderings: `show <theirs>:<core-path>` scores **1**, and `show "$THEIRS:core/scripts/x.sh"`,
`show "${THEIRS}:core/scripts/x.sh"` and `show "${theirs}:<core-path>"` each score **0**. So the
`$VAR:` spelling — the one a reader produces by dropping the braces from a correct site, and the
one that is live in two shipped files today — is outside the arm's grammar by construction.

**THE PROSE IS THE ONLY CARRIER, AND ITS CHANNEL IS WRONG FOR THE JOB.** `resident-context.md`
requires a named carrier per rule. This one's carrier is a paragraph in a file the reader is
already skimming, and the failure it prevents is silent in the expensive direction: the ref
resolves, git answers about a different blob, and the answer looks like an answer. Measured on
this machine under `/bin/zsh` with the ref bound, bare against braced: `core/scripts/x.sh`,
`templates/x` and `tests/x` MANGLE, `docs/x` is SAFE (control, same invocation), and
`"$REF:$CP"` is also SAFE because the character after the colon is `$`, not a modifier letter.
That last row is why `reconcile/classify-block.md:15-16` is NOT a defect despite carrying the
bare form, and it is also why a naive `\$[A-Za-z_]+:` arm would have a non-empty false-positive
set on the shipped tree.

**WHAT THE MISSING ARM WOULD HAVE TO DISCRIMINATE**, and why it is not a one-liner. Three
populations share one shape and need three verdicts: the bare form in a `#!/usr/bin/env bash`
script is CORRECT (`reconcile/emit-report.sh:300`, `reconcile/ledger-reverify.sh:636` — both
shebangs verified), the bare form followed by `$` is correct in any shell, and the bare form in
instruction text a human retypes is the defect. Keying on the shebang was measured wrong for
S11's subject for a reason that applies here too — a line-oriented scan cannot see which shell
will run the text — and for a `.md` file there is no shebang to key on at all. So the arm's
population is "text that will be retyped", which no regex spells, and any candidate needs its
false-positive set measured over `git ls-files 'core/*'` before it ships.

**Why this is filed rather than built now.** The entry's own remedy was one sentence, and the
operator's instruction was explicitly not to build a mechanism. Widening S8 changes an arm whose
false-positive set is recorded EMPTY and whose corpus the fixture battery under
`core/fixtures/shell-portability/` necessarily seeds with every pattern it forbids — that
exclusion is derived from the validator's own name at `:316`, so a widened pattern interacts
with it. That is a measured change to a live arm, not an addition beside one.

**Receipt limits, stated.** The receipt scores the PROSE half only — that a `zsh` sentence about
braces stands above the first braced rev-path command, outside a fenced block and outside an HTML
comment. **It cannot score the missing arm**, because the arm does not exist and a receipt for an
absent mechanism has nothing to run; closing this entry needs S8 widened or a successor arm with
its own measured false-positive set, and that half is not receipt-enforceable. Exit 9 if the
subject file or every braced command site is gone — a truncated or deleted file is NEEDS-REVIEW,
never a close.

**AND IT CANNOT SCORE WHETHER THE SENTENCE IS TRUE.** Measured by the lead against seeds chosen
independently of the ones that produced the arm: a note reading *"the braces in a rev-path are
cosmetic; zsh needs no brace here"* — wrong in the one way that matters, and placed correctly
above the first command with both keywords in window — closes the receipt at exit 0, beside a
control of 0 for the real fix. Six other non-fixes were rejected (`zsh` as a command inside a
fence, a sentence denying the hazard, the correct note below the last command site, `zsh` inside
a URL) and the two degenerate trees exit 9, each mutant `cmp -s`-asserted applied before its
verdict was read. So the arm binds POSITION and VOCABULARY, never semantics; a reviewer reads the
sentence, and this receipt only establishes that there is one to read.

verify: sh f=core/skills/ai-dlc-update/SKILL.md; [ -r "$f" ] || exit 9; c=$(grep -nE 'show "\$\{[a-z]+\}:' "$f" | head -1 | cut -d: -f1); [ -n "$c" ] || exit 9; n=$(awk -v c="$c" 'BEGIN{bt=sprintf("%c%c%c",96,96,96)} { if (substr($0,1,3)==bt || substr($0,5,3)==bt) { fence=!fence; F[NR]=1 } else F[NR]=fence; L[NR]=tolower($0) } END { for (i=1;i<c;i++) { if (F[i] || L[i] !~ /zsh/ || L[i] ~ /<!--/) continue; lo=i-3; if (lo<1) lo=1; hi=i+5; if (hi>NR) hi=NR; for (j=lo;j<=hi;j++) if (!F[j] && L[j] ~ /brace/) { print i; exit } } }' "$f"); [ -n "$n" ] || exit 1; exit 0

## BL-230 — `reconcile-emit-report`'s kill-set arms fail intermittently under the pool — E1, E8 and E9 all measured, on three different worlds — and E1's success message describes a different assertion than the one it makes

**Found 2026-09-11** during batch 85, when E1 failed a gate run on a branch whose change cannot
reach it. Two separate defects in one arm; the second is what makes the first expensive.

**E8 IS THE THIRD ARM, MEASURED AT BATCH 138 UNDER A SIX-WIDE POOL.** `v_kill E8 "V-R V-U"`
(`run.sh:1596`) failed a gate run whose tree changes only `ai-dlc-handoff-pending.sh`,
`ai-dlc-continue.sh` and `pipeline-state-paths.json`. Attribution severed in one invocation: the
fixture names those three files **0**, **0** and **0** times against a control of **22** for
`emit-report.sh`. Solo from the repo root the same tree exits **0** at 83 assertions with 0
failures, and the very next pool run at the same width scored it `ok`. So the population is
arms scored under pool contention at ANY width, not a property of 12-way, and E8 sits between
the two arms already named — the entry's own reading of its subject reproduces at a third site.

**THE FLAKE.** `v_kill E1 "V-R V-U"` (`run.sh:1129`) asserts a mutant moves EXACTLY two worlds. On
one 12-way pool run it reported `[V-R V-U V-HC]` and failed; the same tree run solo from the repo
root passes with E1 green, and a second pool run passed. **It is not caused by the change that was
in flight**: `reconcile-emit-report` never executes `apply.sh` — `grep -cE 'bash .*apply\.sh|\$APPLY'`
returns **0** against a control of **24** in `apply-restamp-worklist` — and its scorer
(`v_render`, `:614`) calls `emit-report.sh` alone. The causal path from the branch's two new
`say WORKLIST` sites to the region V-HC edits is severed.

**WIDER THAN FILED: E9 FAILS THE SAME WAY, ON A DIFFERENT WORLD, AND SO DOES AN ARM THAT IS NOT A
KILL-SET AT ALL.** Measured at batch 114, which this arm charged for a second time. Gate run 1
PASSED the fixture suite and gate run 2 failed `v_kill E9` on a **byte-identical tree** — same tree
sha `b36117f5`, the two commits differing only in squash topology — and a third run passed. E9's
expected set is `[V-R V-N V-H V-HA V-S V-U V-HC]` and it reported `[V-R V-N V-B V-H V-HA V-S V-U
V-HC]`: the extra world was **V-B**, not the V-HC this entry predicts, though both arms score
through the same `v_kill`/`v_diffset` whole-world set difference. Separately, four copies of the
fixture run in parallel from **unmodified `origin/main`** put 1 of 4 red on a THIRD arm — the
docs-only-move `--verify` assertion, which is not a kill set — against 3 green in the same
invocation. So the population is "arms scored under pool contention", not "E1", and the entry's
own title understated it.

**THE ATTRIBUTION WAS MEASURED, NOT ASSUMED, AND IT COST THE BATCH A FULL GATE CYCLE.**
`reconcile-emit-report` seeds **0** `verify: theirs_has` and **0** `verify: sh` receipts — only
three `theirs_maybe`, which no arm of `ledger-reverify.sh` dispatches (control: an impossible verb
also 0) — so the batch-114 change to that engine's `sh` arm renders no row in this fixture in
either revision, and `unseen_rows()` keeps both spellings of the row it renames in any case. The
causal path is severed for the same KIND of reason it was severed at batch 85, by a different
mechanism.

**WHY V-HC IS THE PLAUSIBLE UNSTABLE MEMBER.** `v_kill` scores by whole-world set difference, so one
world with an unstable score pollutes the set. V-HC is built by deleting the first
`^HARD-UNREGISTERED-CORE-DRIFT` line from a rendered region, and the arm beside it at `:1102` exists
because *"the difference is being taken over RAW lines"* is its known failure mode. The fixture's own
`CONTROL(V)` arm already anticipates slot-dependent instability here, in as many words: the control
and shipped copies *"were computed in different parallel slots, so it is also the arm that would
catch the scoring racing with itself."*

**THE SECOND DEFECT, AND IT IS THE ONE WITH A RECEIPT.** E1's success message reads *"the THREE
worlds that read 3 go red and no other"* while its assertion passes `"V-R V-U"` — **two**. Derived:
the assertion set has 2 members, the message says three. One of them is wrong, and a reader
debugging a failure reads the message. This is `verification-discipline.md`'s "text about a program
is not the program", inside an arm whose whole subject is set membership.

**WHY THIS IS FILED RATHER THAN FIXED HERE.** The two defects have different owners. The message/
assertion mismatch is a one-line correction, but WHICH one is wrong is not derivable from the arm —
it needs whoever knows whether a third world should be in that set, and if one should, the arm has
been under-asserting since it was written. The flake needs the pool to reproduce and may be a
property of `v_diffset` rather than of E1.

**The cost is misattribution, and it was nearly paid.** A gate-green branch was blocked by this arm
and the first hypothesis was that the change caused it. Two measurements and an adversarial pass
were spent proving otherwise. **An intermittent arm on a shared fixture charges its cost to whichever
change happens to be in flight**, which is the failure this entry exists to stop repeating.

**Receipt limits, stated.** The receipt scores ONLY the message/assertion mismatch, because that is
the half that is mechanically checkable: it counts the worlds in E1's `v_kill` argument and refuses
while the adjacent `ok` line says "three". **It does not and cannot score the flake** — an
intermittent failure has no deterministic receipt, and a receipt that ran the fixture once would
report green on the common case. Closing this needs the mismatch fixed AND a stated finding about
the flake, and the second half is not receipt-enforceable. Exit 9 if the arm or its message is gone.

**WIDENED AT BATCH 116, AND THE WIDENING CARRIES A LEAD.** Two hands hit the flake independently
on a gate-green branch whose change cannot reach it, and one reproduced it at `49e5356d`
(`origin/main`, none of that batch's code): pooled over both hands, tip 0 of 48 red and base 1 of
48, with the other hand's separate rounds at roughly 2 in 60. At that rate 48 runs expects 0.5
events, so neither clean sweep discriminates and neither is reported as absence. Two surfaces, both
in the FALSE direction — assertion 1 (`--verify failed a correct report`, a sound report accused of
being stale) and the E9 mutant (`the kill is unattributed`) — two arms on two trees, which argues
one shared cause. Ruled out so nobody repeats it: 48 concurrent `--verify` runs against one stored
report went 0 red with a serial control at rc=0 in the same invocation, and 12 concurrent renders
gave one md5, so neither `render()` nor `--verify` alone is the moving part. The lead is already in
the tree: `ledger-reverify.sh:1089-1096` records this exact class as measured on a busy host and
fixed it by prefixing its own temp dirs, while `emit-report.sh:331` and `:373` still call bare
`mktemp`. Not folded into `v0.582.0`, whose subject was the step 3b section; the pre-existing
intermittent charged to whichever change is in flight is the shape this entry exists to stop.

**A FOURTH ARM AT BATCH 136, AND IT IS `E3` — AN ARM THIS ENTRY DOES NOT NAME.** Two full gate runs
on the same branch, minutes apart, differing only by one integer pair on a `.githooks/pre-push`
argument line: run 1 scored `reconcile-emit-report` **ok**, run 2 scored it **FAIL** on
`E3 moved the worlds [V-N V-HC] and had to move exactly [V-N]`. The same tree run SOLO from the
repo root exits **0** with **0** failing assertions. Attribution severed the same way as the three
before it, derived in one invocation: the fixture names `ai-dlc-update/SKILL.md` — the only engine
file this batch changed — **0** times, against a control of **22** for `emit-report.sh`, and
`classify-block.md` **0** times. The extra world is **V-HC** again, as E1 predicted and E9 did not,
which is a third distinct expected-set for one shared cause. The entry's own generalisation from
batch 114 — the population is "arms scored under pool contention", not any named arm — now has four
members across three arms, and **E1/E9 in the title remain an enumeration where the finding is a
class.**

**A FIFTH MEASURED ARM AT BATCH 144, AND IT IS `E2`.** Filed by the consumer as
`PC-S313-EMIT-REPORT-E2-IS-A-FOURTH-POOL-FLAKE-ARM` during its 0.623.0 → 0.624.0 self-update. Its id
says fourth; counted against this entry it is the fifth, after E1, E8, E9 and E3. The consumer's
pre-push under a **6-wide** pool failed `E2 moved the worlds [V-M V-HC] and had to move exactly
[V-M]`. On the same tree, 3 standalone runs, 6 concurrent standalone copies and a full 185-fixture
12-way pool all passed. The extra world is **V-HC** again, and it is the extra world in three of the
five arms.

**CPU LOAD DID NOT REPRODUCE IT, AND THAT ZERO CANNOT DISCRIMINATE.** Batch 144 ran 144 direct
`--verify` runs, 12 fixture runs and 3432 replayed score cells, and every one agreed. At the
observed rate of about 1 in 30, 12 fixture runs predict about 0.4 failures, so a clean sweep there
is what the hypothesis predicts and refutes nothing.

**A FORCED PROCESS CAP DID FLIP THE SHIPPED PROGRAM'S VERDICT.** Under `ulimit -u`, V-HC's verdict
changed in **4 of 12** rounds. The cause was a sibling fork failure (exit 128) that was rendered as
DETECTOR-REFUSED. In one of those rounds a RETIRE-CANDIDATE row was silently dropped. So the scorer
has a real failure mode in which resource exhaustion reads as a verdict. **This is not attributed
to the consumer's failure.** One fixture run peaks about 63 processes above a baseline of about 600,
against a limit of 10666, so the consumer's run was nowhere near the cap.

**RELEASE 0.625.0 SHIPS THE INSTRUMENT.** When a kill-set arm fails, it now prints the
score cells of each world that differs and a diff of that world's stderr, so the next pool failure
carries its own cause.

**ITS FIRST CATCH NAMED A MECHANISM, AND 0.625.0 FIXES IT.** An unforced E2 failure, in a scratch
copy with no `.git`, showed V-HC's `HARD-UNREGISTERED-CORE-DRIFT schemas/thing.json` rendered as
`CORE-TEMPLATE-SUBSTITUTED` with NO DETECTOR-REFUSED line. So that extra world was not the `ulimit`
refusal above. `unregistered-drift.sh`'s `is_unregistered()` fed `diff ... 2>/dev/null` into an
awk whose END printed "clean" on no hunk, and it is reached only after `cmp` shows the files differ.
Forced with a `diff` shim that exits 2: unshimmed HARD, shimmed CORE-TEMPLATE-SUBSTITUTED. A second
site, `closest_ancestor_blob()`, scored a failed diff as a perfect match: unshimmed HARD drift,
shimmed `HARD-CORE-BEHIND`. Both now fail closed, each with an arm and a mutant in
`setup-config-drift`. **This entry stays live**: the E2/V-HC shape matches this mechanism, but E9's
extra world was V-B, and E1/E8 are not yet shown to share it. Close only when the instrument has
recorded a pool failure's cause, or a pool run of the size that predicts at least 3 failures at
base comes back clean at tip.

**E1'S SECOND DEFECT IS SETTLED.** The assertion `"V-R V-U"` is right and the message "three" was
wrong. The message is corrected in 0.625.0.

**THE RECEIPT IS RETIRED TO `manual`.** The receipt above scored only the message/assertion
mismatch. Once the message was corrected it would have proposed CLOSE on a flake that is still
live, which is the one direction that loses the entry. The flake has no mechanical predicate until
the instrument catches a failure and names its cause.

**MEASURED AT BATCH 151: THE CLOSE CONDITION'S POOL WAS RUN, AND TIP WAS NOT CLEAN.** Base is
0.624.0 (`29291758`), the release before 0.625.0. The pooled batch-116 rate of 3 in 108 predicts
3.0 failures in 108 runs. The run used 108 tip runs (`937919e4`) and 48 base runs, interleaved
two tip to one base under `xargs -P 6`, each from its worktree root. Every one of the 156 logs
carries a verdict line. Tip scored **2 red of 108** (1.9%) and base **1 of 48** (2.1%), so the
0.625.0 fix did not move the rate. The box's load average ran from 27 to 78 throughout. None of
the three reds came from the window in which a 4-wide release gate ran beside the pool.

**THE LIVE CLASS IS NOT THE KILL SETS, AND THE INSTRUMENT CANNOT REACH IT.** No red was a
kill-set arm: 0 `moved the worlds` lines, against 156 `E2 … ok` and 1716 E-arm `ok` lines as the
control. So `v_diag`, which is called only from `v_kill`, printed nothing in any log. All three
reds are the `--verify` false positive this entry recorded at batch 116. It appears as `--verify
failed a correct report` in tip.3 and base.19, and as the docs-only `--verify` arm in tip.3 and
tip.18. tip.3 also reports `ORIENTATION INVERTED` with empty labels, and every region-reading arm
fails in it. The kill-set subclass scored 0 of 108 at tip, but also 0 of 48 at base, so its clean
tip is not evidence.

**AN UNMEASURED LEAD, STATED AS ONE.** An empty orientation block in tip.3 fits a seed-time render
whose `preclassify.sh` call failed under load. `emit-report.sh:204` takes that call's result as
`2>/dev/null || true`, which yields an empty `pc`, no CLASSIFY rows and no orientation block. That
is the same fail-open shape 0.625.0 fixed for `diff`. It was not confirmed, because the fixture's
EXIT trap deletes the seed's `WORK` directory. A DIAG path for the render arms, keeping the seed's
stderr on a red, is the next instrument.

verify: manual

## BL-099 — the exec-bit audit is one-directional, so a consumer file that upstream STOPPED shipping executable is never reported

**`apply.sh`'s EXEC-BIT AUDIT is LEVEL-triggered and covers exactly one of the two directions
it could.** It walks `git ls-tree -r "$THEIRS" -- core/`, keeps `$1=="100755"`, and reports every
one whose consumer copy is not executable. There is no mirror arm: a path upstream ships
`100644` whose consumer copy IS executable produces no finding anywhere, ever.

Measured, with a control in the same invocation: `100644` occurs three times in `apply.sh` and two
of those are comment prose — the only live one is the `chmod -x` inside `sync_mode_from_theirs()`,
which runs only on a file being APPLIED. `100755` occurs eight times, and both audit arms
(`apply.sh:878`, `apply.sh:1081`) test it alone.

**The asymmetry matters because the two directions have different backstops.** A file that should
be executable and is not gets caught on every subsequent pull, whatever earlier release left it
that way — that is what LEVEL buys. A file that should NOT be executable and is gets caught only
if some pull happens to APPLY it. `v0.423.0` closed the classifier half of that (a path whose
content matches theirs and whose bit does not now routes to a bucket that applies, so
`sync_mode_from_theirs` runs and `chmod -x` fires), but a bit left set by a pull that predates
that fix is still invisible, and nothing will look at it again.

The consequence is smaller than the `100755` direction — an over-permissive mode rather than an
inert validator — which is why this is filed rather than fixed inside `v0.423.0`. It is
nonetheless a hole in a check whose own header says "LEVEL, NOT EDGE ... an event-driven audit
would never look at it again".

**Candidate fix**: a second `awk` arm over the same `ls-tree` output keeping `$1=="100644"` and
reporting consumer copies that ARE executable. One walk, two filters — the enumeration is already
paid for. False-positive set NOT yet measured; that measurement is the first thing this entry
owes, because a consumer tree may hold executable copies for reasons this driver did not create.

**The receipt below is TEXT-KEYED, deliberately, and its weakness is stated rather than hidden.**
Driving `apply.sh` end-to-end needs the harness the `apply-*` fixtures carry and does not fit a
one-liner. It extracts the `NOEXEC` command substitution, STRIPS COMMENTS, and requires a
`100644` to survive — so the obvious prose close does not work: measured, a seeded
`# seeded: a 100644 arm` comment leaves it at exit 1, while a seeded `awk` arm takes it to 0.
It still cannot tell a real arm from any other live mention of the token in that block. The
proper proof belongs in a fixture that drives the audit.

Tiered **DEFECT**.

Found while closing `BL-033` at `v0.423.0`; not a `PC-` candidate, so it ranks below the
PC-backed set.

verify: sh P=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$P" ] || exit 9; B="$(awk '/^NOEXEC="\$\($/{f=1} f{ sub(/#.*/,""); print } f && /^\)"$/{exit}' "$P")"; grep -q '100755' <<<"$B" || exit 1; grep -q '\[ -x' <<<"$B" || exit 1; grep -q '100644' <<<"$B"

## BL-100 — `--untangle` gives a mode-drifted consumer copy the same verdict as a correct one

**`preclassify.sh`'s `--untangle` mode buckets on `ours_h = base_h` and that comparison is
content-only**, so a consumer file holding the right bytes with the wrong exec bit reads
`ALREADY-AT-THEIRS` — "consumer never touched it, nothing to untangle".

Driven through the shipping script against this distribution as `DIST` with `HEAD` as both base
and theirs, and a synthetic consumer. The subject the population itself selects first is
`core/git-hooks/pre-push`, which maps to the consumer's `.githooks/pre-push`:

```
consumer copy 755, right content   ALREADY-AT-THEIRS      <- control
consumer copy 644, right content   ALREADY-AT-THEIRS      <- the finding: same answer
```

**The control and the subject returning the SAME value is what the finding IS here**, and it is
worth saying plainly because a control that agrees with the verdict is normally the sign of a
broken probe. Not in this shape: the claim is that the arm cannot discriminate, so the two arms
of the probe agreeing is the positive result. The probe is shown to be live by its own `exit 9`
guards — an empty row set, an unresolvable blob, or a control that is not `ALREADY-AT-THEIRS`
all abort rather than pass.

**The consequence is bounded by a backstop, which is why this is not a BLOCKER.** `--untangle`
is a one-time Phase-2 migration, and any later ordinary pull runs the level-triggered EXEC-BIT
AUDIT, which does cover `core/git-hooks/pre-push` in the `100755` direction. So the wrong verdict
is `--untangle`'s own report rather than a permanent state. In the `100644` direction there is no
backstop at all — see `BL-099`.

**Remedy NOT decided, deliberately.** `--untangle`'s three buckets are `UPSTREAM-ONLY-ADD`,
`ALREADY-AT-THEIRS` and `BOTH-CHANGED->CLASSIFY`, and it is not established which a mode-drifted
copy should take: it is not a content tangle, so `BOTH-CHANGED->CLASSIFY` overstates it. The
receipt therefore asserts only that the bucket is NOT `ALREADY-AT-THEIRS`, which any of the
plausible remedies satisfies. Whoever takes this decides the bucket first.

Note the `v0.423.0` conjunct is NOT reusable as-is: `mode_at_theirs()` reads `$THEIRS`, and in
`--untangle` base and theirs are the same ref by construction, so the helper resolves but answers
a question about a ref the mode never came from. Re-derive rather than copying the call.

Tiered **DEFECT**.

Found while closing `BL-033` at `v0.423.0`; not a `PC-` candidate, so it ranks below the
PC-backed set.

verify: sh P=core/skills/ai-dlc-update/reconcile/preclassify.sh; [ -f "$P" ] || exit 9; H="$(git rev-parse HEAD)" || exit 9; C="$(mktemp -d)" || exit 9; u() { bash "$P" . "$H" "$H" "$C" --untangle 2>/dev/null; }; R="$(u | LC_ALL=C awk -F'\t' '$1=="U"{print $2 "\t" $3}' | while IFS="$(printf '\t')" read -r cp cons; do [ "$(git ls-tree "$H" -- "$cp" | cut -c1-6)" = 100755 ] && { printf '%s\t%s\n' "$cp" "$cons"; break; }; done)"; [ -n "$R" ] || { rm -rf "$C"; exit 9; }; CP="$(printf '%s' "$R" | cut -f1)"; CO="$(printf '%s' "$R" | cut -f2)"; mkdir -p "$C/$(dirname "$CO")" || { rm -rf "$C"; exit 9; }; git show "${H}:${CP}" > "$C/$CO" 2>/dev/null || { rm -rf "$C"; exit 9; }; b() { u | LC_ALL=C awk -F'\t' -v p="$CP" '$2==p{print $4}'; }; chmod 755 "$C/$CO"; [ "$(b)" = ALREADY-AT-THEIRS ] || { rm -rf "$C"; exit 9; }; chmod 644 "$C/$CO"; D="$(b)"; rm -rf "$C"; [ "$D" != ALREADY-AT-THEIRS ]

## BL-098 — two blocks may declare the same vocabulary NAME, and the index renders the row twice

**`BL-094` one level up: the contradiction is between two BLOCKS rather than two fields.**
`MARKER_AWK` tracks a declared field per block, and nothing tracks a declared NAME across the
file. Two `# vocabulary:` lines carrying one name therefore both render, and the exit code never
moves. Re-derived on the tree with `v0.421.0`'s field partition and orphan refusal both in place —
control in the same invocation: an orphan seed exits 1, so this is measured on the FIXED reader,
not on a stale copy.

```
CONTROL, unseeded:  exit 0 ; rows whose Vocabulary cell is 'push-candidate ledger statuses' = 1
SEEDED, block 3 renamed to block 2's name:
                    exit 0 ; rows with that same cell = 2
                    "OK: wrote docs/vocabulary-index.md — 8 cross-file vocabular(ies), 5 schema enum(s)."
```

**1 → 2 against an exit code that never moves.** A reader of `docs/vocabulary-index.md` looking up
a vocabulary finds two rows, each claiming to be the one set, with different owners and different
members. The file exists precisely so that a set has ONE home.

**Candidate fix and its measured false-positive set.** A file-scope `seenname[]` in `MARKER_AWK`,
refusing the second declaration and emitting a `#DUPNAME` diagnostic — the same partition shape
already there for fields, no new reader and no new grammar. It flips the receipt to 0 and leaves
the real 8 blocks green (`--check` exit 0).

Tiered **NOTE**, on the same grounds as `BL-094`: nothing emits a wrong verdict today and the
state requires an author to write it. It is the third member of the group with `BL-096` and
`BL-097` — one class, one subsystem pair, three one-arm fixes.

Found by the scope hand of batch 12; the numbers above are the lead's independent re-derivation,
not the hand's, because the renderer moved twice while that hand was measuring.

verify: sh R=scripts/render-vocabulary-index.sh; M=scripts/validate-enforcement-map.sh; [ -f "$R" ] && [ -f "$M" ] || exit 9; D="$(mktemp -d)" || exit 9; tar --exclude=.git -cf - . 2>/dev/null | tar -xf - -C "$D" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$R" --check >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; P="^[[:blank:]]*#[[:blank:]]*vocabulary:"; set -- $(grep -n "$P" "$D/$M" | head -2 | cut -d: -f1 | tr '\n' ' '); [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ "$2" -gt "$1" ] || { rm -rf "$D"; exit 9; }; N="$(sed -n "${1}p" "$D/$M" | sed "s/$P[[:blank:]]*//")"; [ -n "$N" ] || { rm -rf "$D"; exit 9; }; b0="$(grep -c "^| $N |" "$D/docs/vocabulary-index.md")"; [ "$b0" -eq 1 ] || { rm -rf "$D"; exit 9; }; awk -v n="$2" -v nm="$N" 'NR==n{print "# vocabulary: " nm; next} {print}' "$D/$M" > "$D/t" || { rm -rf "$D"; exit 9; }; mv "$D/t" "$D/$M"; [ "$(grep -c "^[[:blank:]]*#[[:blank:]]*vocabulary:[[:blank:]]*$N\$" "$D/$M")" -eq 2 ] || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$R" >/dev/null 2>&1 ); rc=$?; n2="$(grep -c "^| $N |" "$D/docs/vocabulary-index.md")"; rm -rf "$D"; [ "$rc" -eq 0 ] && [ "$n2" -eq 2 ] || exit 0; exit 1

## BL-097 — the vocabulary renderer declares TWO populations and only one of them refuses a repeated declaration

**In the file `v0.421.0` hardened, in the half that release did not reach.** `SCHEMA_PY` in
`scripts/render-vocabulary-index.sh` calls `json.load`, which resolves a duplicate mapping key by
keeping the LAST. So a `core/schemas/*.json` declaring one field's `enum` twice renders from the
second and discards the first, silently. Driven with the shipping renderer:

```
core/schemas/zzprobe.json = {"properties": {"zzprobe": {"enum": ["FIRSTDECL"], "enum": ["SECONDDECL"]}}}
  -> renderer exit 0, no parse error, rendered row: | `zzprobe.json` | `zzprobe` | `SECONDDECL` |
  CONTROL: FIRSTDECL anywhere in the rendered index = 0 ; SECONDDECL = 1 (so the row rendered)
```

**The file's own header calls this half total.** It says the schema walker is *"Total by
construction — the walker descends each whole document, so a schema cannot gain a vocabulary this
table does not show."* It can lose one. `MARKER_AWK`'s partition does not reach here and was never
going to: this is a different reader over a different corpus, and the two share only the header
that claims totality for both.

**Candidate fix and its measured false-positive set.** An `object_pairs_hook` that raises on a
repeated key flips the receipt to 0 and leaves the real 8 schemas green — `--check` exit 0. Live
occurrences today: **0** duplicate keys across those 8, which is why this has never fired.

Tiered **NOTE**, for the same reason `BL-094` was: nothing emits a wrong verdict on the live tree,
and the state requires an author to write it. The cost is that the header's totality claim is
false for one of its two halves.

Found by the scope hand of batch 12, asking whether `BL-094` was wider than filed.

verify: sh R=scripts/render-vocabulary-index.sh; [ -f "$R" ] || exit 9; [ -d core/schemas ] || exit 9; D="$(mktemp -d)" || exit 9; tar --exclude=.git -cf - . 2>/dev/null | tar -xf - -C "$D" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$R" --check >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; J="$D/core/schemas/zzprobe.json"; printf '%s\n' '{"properties": {"zzprobe": {"enum": ["FIRSTDECL"], "enum": ["SECONDDECL"]}}}' > "$J" || { rm -rf "$D"; exit 9; }; [ "$(grep -c FIRSTDECL "$J")" -eq 1 ] && [ "$(grep -c SECONDDECL "$J")" -eq 1 ] || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$R" >/dev/null 2>&1 ); rc=$?; f=0; s=0; grep -qF FIRSTDECL "$D/docs/vocabulary-index.md" 2>/dev/null && f=1; grep -qF SECONDDECL "$D/docs/vocabulary-index.md" 2>/dev/null && s=1; rm -rf "$D"; [ "$rc" -eq 0 ] && [ "$s" -eq 1 ] && [ "$f" -eq 0 ] || exit 0; exit 1

## BL-096 — the invariant renderer refuses a duplicate SOLO declaration and accepts a duplicate GROUP one

**`BL-094`'s defect in the sibling renderer, at mirror polarity.**
`scripts/render-invariant-index.sh`'s collision arm keys on `solo[id] > 1` — declarations by an arm
header naming ONE id. The group path is `if (!(id in gdesc)) gdesc[id] = armdesc[i]`, which is
FIRST-wins and reports nothing. Two arm headers that each declare a set of ids sharing one member
therefore resolve silently.

Driven, with the covered case as the control in the same construction:

```
CONTROL, two SOLO headers claiming I801:
  -> exit 1, "1 invariant ID(s) are claimed by more than one arm ... I801"
THE GAP, two GROUP headers both declaring I803:
  # --- I802 / I803: FIRSTDESC ---   /   # --- I803 / I804: SECONDDESC ---
  -> exit 0, index written, row: | I803 | FIRSTDESC |     <- SECONDDESC discarded
```

**The group path is live, not dead code**: 7 ids appear in at least one group header today, against
101 distinct ids total. Ids group-declared more than once with no solo arm: **0**, which is why this
has never fired.

**Candidate fix and its measured false-positive set.** Tracking a disagreement in `gdesc` and
widening the existing collision arm to `solo[id] > 1 || gcollide[id]` flips the receipt to 0 and
leaves the real corpus green — `--check` exit 0, 101 invariants across 98 arms. That is one
clause in the arm that already owns this question, which is the shape `mechanism-design.md`
prefers over a second arm.

Tiered **NOTE**. Latent, one-arm fix, and the consequence is a wrong DESCRIPTION on a row rather
than a wrong verdict — but `docs/invariant-index.md` is the file every bold citation in the
resident rulebooks resolves against.

**THE POPULATION BEHIND THIS ENTRY AND `BL-097` IS BOUNDED, NOT SAMPLED, AND THAT IS WORTH
STATING BECAUSE THE FIRST SWEEP COULD NOT SPELL ITS OWN SUBJECT.** Sweep 1 keyed on awk
PATTERN-ACTION rules and therefore missed `MARKER_AWK` itself, whose rules are `if (line ~ /…/)`
bodies — so its count was a floor of unknown depth and was discarded. Sweep 2 keyed instead on a
property invariant to how the assignment is written: a start-anchored regex literal matching a
comment line carrying a colon. **81 sites across 31 tracked files**, with a containment control
showing it strictly supersets sweep 1, and a control showing it reaches
`render-vocabulary-index.sh` (10 sites) — the construct sweep 1 missed. 45 sit in fixtures or in
the three already-adjudicated files. **Of the 36 shipping-reader sites outside those: 35 are
markdown-heading extractors** — a grammar that pulls an ID out of a heading and cannot express
this contradiction — **and 1 is `scripts/render-path-mapping.sh:102`, a `case`-arm matcher that
NEGATES `#`** and reads no marker at all. Zero further instances.

**The classifier behind that zero was controlled first, and its first version failed.** A
`[^:]*` fragment cannot cross the colons inside `[[:blank:]]`, so it scored all of `MARKER_AWK`'s
own sites as OTHER — a classifier that cannot classify its own subject cannot certify an absence,
and its zero was discarded rather than reported. The replacement was proven on 6 of 6 subject
sites plus a near-miss before its corpus was read.

**The one residual, narrow and named**: a reader that builds its marker pattern entirely at
runtime with NO literal fragment in source escapes this grammar. None of the three marker readers
in this tree is of that shape.

Found by the scope hand of batch 12, asking whether `BL-094` was wider than filed.

verify: sh R=scripts/render-invariant-index.sh; M=scripts/validate-enforcement-map.sh; [ -f "$R" ] && [ -f "$M" ] || exit 9; D="$(mktemp -d)" || exit 9; tar --exclude=.git -cf - . 2>/dev/null | tar -xf - -C "$D" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$R" --check >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; cp "$D/$M" "$D/m.orig" || { rm -rf "$D"; exit 9; }; printf '%s\n' '# --- I801: FIRSTCLAIM ------------------------------------------' '  err "I801 fired"' '# --- I801: SECONDCLAIM -----------------------------------------' '  err "I801 fired"' >> "$D/$M"; ( cd "$D" && bash "$R" >/dev/null 2>&1 ); solo=$?; cp "$D/m.orig" "$D/$M"; printf '%s\n' '# --- I802 / I803: FIRSTDESC ------------------------------------' '  err "I802 fired"; err "I803 fired"' '# --- I803 / I804: SECONDDESC -----------------------------------' '  err "I803 fired"; err "I804 fired"' >> "$D/$M"; ( cd "$D" && bash "$R" >/dev/null 2>&1 ); grp=$?; I="$D/docs/invariant-index.md"; f="$(grep -c '^| I803 | FIRSTDESC |' "$I" 2>/dev/null || true)"; s="$(grep -c '^| I803 | SECONDDESC |' "$I" 2>/dev/null || true)"; rm -rf "$D"; [ "$solo" -ne 0 ] || exit 9; [ "$grp" -eq 0 ] && [ "$f" -eq 1 ] && [ "$s" -eq 0 ] || exit 0; exit 1

## BL-092

**The rev-path defence is keyed on a `core/` PREFIX, so a distribution path that does not start
with `core/` is still read as a missing consumer subject.** `receipt_path_tokens()` at
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:611` splits on non-path bytes, and the
four `case` prefixes then reject the `core/…` half of a rev-spec. A rev-path whose right side is
`docs/…`, `.claude/…` or `_bmad-output/…` has no such half. Measured at HEAD: a receipt naming
`$THEIRS:docs/backlog.md` yields `[ docs/backlog.md]` and `$THEIRS:.claude/rules/tool-hazards.md`
yields `[ .claude/rules/tool-hazards.md]` — both reported as absent consumer subjects when both
are distribution paths at a ref. **The shipped comment at `:599-600` asserts the opposite** —
"its distribution half fails the prefix test" — which is false for exactly these spellings, so
the file documents a defence it does not have.

**ZERO INSTANCES REPRODUCE TODAY, AND THAT IS THE ENTRY'S POINT, NOT A REASON TO SKIP IT.** All
10 rev-path right-hand sides in the reference consumer's 25-receipt live corpus are `core/`
prefixed (control: 48 of 48 rev-specs across the 70-receipt live + archive corpus begin `core/`),
so the guard is correct on every receipt anyone has written. It fails on the first receipt that
names a distribution `docs/` path at a ref, and it fails silently, by downgrading a close that
receipt had earned. This is the latent half of `BL-081`, separated from it deliberately:
`BL-081`'s title, mechanism, evidence and receipt are all specific to the
`core/scripts/<x>` → `scripts/<x>` substring, and that half is dead.

**Why this receipt.** It drives the shipping function rather than grepping the comment that
states the claim, because the comment is the thing that is wrong. It asserts both directions in
one run — the `docs/` rev-path must stop being reported AND a genuinely absent consumer path
must still be reported — so a fix that deletes the guard fails it.

verify: sh S=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; [ -f "$S" ] || exit 9; D="$(mktemp -d)" || exit 9; trap 'rm -rf "$D"' EXIT; mkdir -p "$D/c/docs" || exit 9; printf 'x\n' > "$D/c/docs/present.md" || exit 9; f="$(awk '/^receipt_path_tokens\(\) \{/,/^\}/' "$S")"; [ -n "$f" ] || exit 9; printf '%s\n' "$f" > "$D/lib.sh"; grep -q 'receipt_path_tokens()' "$D/lib.sh" || exit 9; grep -q 'receipt_absent_subjects()' "$D/lib.sh" || exit 9; bash -n "$D/lib.sh" 2>/dev/null || exit 9; probe() { CONSUMER="$D/c" bash -c '. "$1"; receipt_absent_subjects "$2"' _ "$D/lib.sh" "$1" 2>/dev/null; }; ctl="$(probe 'grep -q x "$CONSUMER/docs/gone.md"')"; [ -n "$ctl" ] || exit 9; pres="$(probe 'grep -q x "$CONSUMER/docs/present.md"')"; [ -z "$pres" ] || exit 9; bad="$(probe 'git -C "$DIST" show "$THEIRS:docs/backlog.md" | diff - x')"; [ -z "$bad" ]

## BL-091

**52 of the 64 headings in this file carry no title, so an extractor keyed on `## BL-0NN ` gets
zero bytes — and an empty script exits 0, which this ledger reads as "the fix is present".**
The heading grammar is inconsistent: `docs/backlog.md` currently holds **52** headings matching
`^## BL-[0-9]+[ \t]*$` and **12** matching `^## BL-[0-9]+[ \t]+`, against a total of 64 (all
three derived in one invocation, so the partition is closed). An extractor written against a
titled entry and keyed on a trailing space therefore returns 4151 bytes for `BL-090` and **0
bytes** for `BL-066`, silently, for four-fifths of the corpus.

**The failure is a FALSE CLOSE, which is the direction that loses data.** A zero-byte extract
is a valid empty shell program; it parses, runs, and exits 0. Anything that pipes an extracted
entry into `sh` — which is what a receipt-repair or an audit pass does — reads that 0 as
CLOSE-CANDIDATE and proposes retiring a live entry. Measured during the batch-10 triage sweep:
one hand hit it and caught it only because it had run a byte-count control; a second hand
reproduced it independently and established the 52/12 split.

**The shipping readers are NOT affected, and that is what makes this latent rather than broken.**
`backlog-reverify.sh` extracts labels with `match(line, /^BL-[0-9]+/)` after stripping the
heading marker, and `backlog-rotate.sh` goes through `ledger_entry_shape()`; neither keys on a
trailing space. So no gate fails today and nothing will start failing on its own — the cost is
paid by the next ad-hoc extractor, which is exactly the reader no mechanism watches.

**The fix is to make the grammar uniform** by giving every entry a title, which removes the
ambiguity rather than documenting it, and is the `remove the affordance` form this repo prefers
over a check that looks for the mistake afterwards.

verify: sh L=docs/backlog.md; [ -f "$L" ] || exit 9; t="$(grep -cE '^## BL-[0-9]+' "$L")"; [ "$t" -gt 0 ] || exit 9; ttl="$(grep -cE '^## BL-[0-9]+[ \t]+[^ \t]' "$L")"; bare="$(grep -cE '^## BL-[0-9]+[ \t]*$' "$L")"; [ "$((ttl + bare))" -eq "$t" ] || exit 9; [ "$bare" -eq 0 ]

## BL-089 — an EXPIRED receipt and a live defect are the same row, so a receipt that can no longer measure anything reads as evidence that it did

**WIDER THAN FILED: the population is not the exit-9 receipts.** This entry was filed against
the exit-9 convention, and its cited population has since moved — `BL-076` is archived, leaving
one live exit-9 member. The batch-10 triage sweep measured the class directly and found the
larger and more dangerous half is receipts that exit **1** having measured nothing, which is
byte-indistinguishable from a genuine reproduction and does not even carry the 9 as a hint:

- **`BL-081`'s receipt** returned exit 1 from `v0.402.0` until this sweep retired it. `d983feb9`
  factored the token split into `receipt_path_tokens()` one line ABOVE the receipt's
  `sed -n "/^receipt_absent_subjects() {/,/^}/p"` range, so both arms died with
  `receipt_path_tokens: command not found` and the empty `b` failed the test. It had correctly
  earned a close for the 16 releases between `v0.386.0` and `v0.402.0`, then went silently
  wrong. Its sanity arm could not see it: the arm tests only that the extracted text CONTAINS
  the function name, which mangled text still does.
- **`BL-066`'s receipt** exits 9, but for the same structural reason rather than the documented
  one: the fix introduced a multi-line parameter expansion whose continuation line is a bare
  `}"`, which the `/^}/` range end matches, truncating the extraction to an unparseable
  fragment. It is also unsatisfiable even once repaired, because the fix changed the return
  shape from a version to a sha pair while the assertion still tests `$1 = "0.3.0"`.
- **`BL-006`'s receipt** fails in the opposite direction — it exits 0 on a comment. See that
  entry; it is currently the ledger's only CLOSE-CANDIDATE and it is false.

**The shape to take from this: single-sourcing a helper to prevent drift BREAKS every receipt
that extracts its caller by `sed`/`awk` range.** The two failures are the same edit seen from
opposite ends. A receipt that reconstructs a function body from the file is coupled to the
file's LAYOUT, and nothing declares that coupling. Any remedy for this entry should treat "the
receipt errored" as its own status rather than folding it into either verdict — the distinction
`backlog-reverify.sh` cannot currently draw is between *measured and reproduced* and *could not
measure*, and the exit code alone will never carry it.

**`backlog-reverify.sh` maps `sh` receipts on exit code alone — 0 is CLOSE-CANDIDATE and
EVERY non-zero is `STILL-LIVE  … "sh receipt exited non-zero -- still reproduces here"`
(`scripts/backlog-reverify.sh:198-203` as filed; the routing now sits at `:241-250`).** But this corpus's receipts use **exit 9** as their
own HAND-REVIEW convention: it is what a receipt returns when a PRECONDITION has moved and it
therefore measured nothing. The engine folds that into STILL-LIVE, so a receipt asserting *"I
could not tell"* is reported in the same words as one asserting *"the defect is still here"*.

**Driven through the shipping engine on a two-entry probe ledger, both verdicts byte-identical:**

```
STILL-LIVE	BL-901	sh receipt exited non-zero -- still reproduces here     (receipt: exit 1)
STILL-LIVE	BL-902	sh receipt exited non-zero -- still reproduces here     (receipt: exit 9)
```

**The population is 2 of the 56 live `verify: sh` entries, and it is derived twice.** Running
every live receipt directly: 0 exit 0, **2 exit 9**, 54 other non-zero, against a control of 5
entries declaring `verify: manual` which the engine does route to HAND-REVIEW. They are
**`BL-066`** and **`BL-076`**. Independently, a mutant of the engine that routes 9 to
NEEDS-REVIEW takes the real ledger from 54 STILL-LIVE to **52** — the same 2, arrived at from
the other side.

**`BL-066`'s receipt does not merely expire, it is BROKEN SHELL**: it dies with
`syntax error: unexpected end of file` and is reported as a defect that still reproduces. That
is the direction that matters — a receipt with no valid parse and a defect with no fix are one
row, and the row reads as the second.

**This is not hypothetical damage and the cost is measured in releases.** `BL-079`'s receipt
seeded a `SPEC.md` in a capability grammar the validator had since started DISARMing, so both
its arms returned 2 and its own guard `[ "$c" -eq 1 ] || exit 9` fired against **every**
implementation, a correct one included. It sat as STILL-LIVE from `v0.378.0` to `v0.415.0` and
was found only because a session re-derived the entry by hand rather than believing its row.
**A receipt that rejects all answers is the CLOSE side of the same coin the engine's own
comments already worry about**: its `has`/`lacks` arms carry a paragraph on a false CLOSE
retiring a live item, and this is a false STILL-LIVE keeping a dead one — cheaper per instance
and unbounded in duration, because nothing ever revisits a STILL-LIVE row.

**Why the receipt is the receipt.** It cannot assert on the engine's WORDING, since any fix is
free to phrase a new verdict differently, and it must not assert on the real ledger, whose
membership moves every batch. It seeds a two-entry ledger under `mktemp` — one receipt exiting
1, one exiting 9 — drives the shipping engine over it, and requires the two rows to receive
DIFFERENT verdicts. Its control runs FIRST and is that the exit-1 entry is reported STILL-LIVE:
without that, "the two differ" is equally satisfied by an engine that emitted nothing, and by
one that never ran. It exits 9 itself if either probe row is missing or either verdict is empty.
Proven both directions: **1** against this tree, **0** against a mutant routing exit 9 to
NEEDS-REVIEW, with the two sides asserted to differ and the mutant asserted to be valid shell
first. Tier: **DEFECT** — it silently disables the only instrument this backlog has.

**THE FILED RECEIPT ACCEPTED TWO FALSE-CLOSE ROUTES, AND IT IS REPLACED.** It required only
that the exit-9 row differ from STILL-LIVE, so an engine routing 9 to CLOSE-CANDIDATE satisfied
it, and so did one routing 9 to HAND-REVIEW — which `backlog-rotate.sh:431` accepts as
permission to move an annotated entry. Both turn "I could not measure" into a close. The
receipt below pins the route: 9 must read NEEDS-REVIEW with an `unresolved:` detail, beside 0
CLOSE-CANDIDATE and 1 and 127 STILL-LIVE in the same probe ledger. **The census premise was
re-measured, not carried:** 1 live receipt exits 9 today, `BL-130`'s (two runs, exit 9 both
times), and the same-root differential of the old and new engine over the real ledger moves
exactly that one row, STILL-LIVE to NEEDS-REVIEW. `scripts/backlog-reverify.sh:241-250` now
captures the exit; `core/fixtures/backlog-ledger` arm `exit-9-routing` holds it, with committed
mutants for both false-close routes.

**THIS DISCHARGES THE EXIT-9 SUBJECT ONLY.** The entry's second subject survives untouched:
receipts that exit **1** having measured nothing — `BL-081`'s shape above — are still
byte-indistinguishable from a genuine reproduction, and no exit-code routing can separate them.
The entry stays live for that subject, and its receipt below closes only the first.

verify: sh R=scripts/backlog-reverify.sh; [ -r "$R" ] || exit 9; D=$(mktemp -d) || exit 9; X(){ rm -rf "$D"; exit "$1"; }; printf '%s\n' '# probe ledger' '' '## BL-901' '' 'live' '' 'verify: sh exit 1' '' '## BL-902' '' 'cannot measure' '' 'verify: sh exit 9' '' '## BL-903' '' 'fixed' '' 'verify: sh exit 0' '' '## BL-904' '' 'command gone' '' 'verify: sh exit 127' > "$D/probe.md" || X 9; O=$(bash "$R" "$D/probe.md" 2>/dev/null); v(){ awk -F'\t' -v l="BL-$1" -v f="$2" '$2==l{print $f}' <<<"$O"; }; for i in 901 902 903 904; do [ "$(v $i 2 | grep -c .)" -eq 1 ] || X 9; done; [ "$(v 901 1)" = STILL-LIVE ] || X 9; [ "$(v 903 1)" = CLOSE-CANDIDATE ] || X 9; [ "$(v 904 1)" = STILL-LIVE ] || X 1; [ "$(v 902 1)" = NEEDS-REVIEW ] || X 1; case "$(v 902 3)" in unresolved:*) X 0 ;; esac; X 1

---

## BL-087 — ANSWERED: `PreToolUse` does NOT fire on a tool call that fails INPUT VALIDATION, so a guard whose predicate is the malformation is unbuildable

**THE ANSWER.** A tool call whose input fails the tool's own schema is rejected before any hook
sees it, and it is invisible to the hook system ENTIRELY — not merely to `PreToolUse`. Measured
on **Claude Code 2.1.266**; a refactor of the dispatch chain could move it, which is why the
build is named.

**The measurement, with its positive control in the SAME session.** A scratch project driving
real Claude Code as `claude -p --settings <scratch>/settings.json`, hook body three lines
(append stdin to a file, exit 0). The decisive arm put both calls in one session, so the control
cannot differ in registration, settings, model or session from the test:

```
Read {"path": "target.txt"}        schema-invalid   -> InputValidationError, NO hook payload
Read {"file_path": "target.txt"}   well-formed      -> executed, ONE hook line
```

With `PreToolUse`, `PostToolUse` and `PostToolUseFailure` all registered on `Read`
simultaneously, a schema-invalid call produced **zero lines across all three**. An
isolated malformed-only run wrote zero; an isolated well-formed-only run wrote one.

**The mechanism agrees and is the weaker source.** In the shipped bundle, dispatch is a hook
middleware chain whose INNERMOST step is the function carrying both `inputSchema.safeParse` and
the `InputValidationError` emission — so the chain's outer hook handlers are never entered for a
call that fails it. Controls on the extraction: `PreToolUse` 107 hits, `InputValidationError`
11, impossible token 0. That reading is what extends the result from `Read` to all tools, and it
is minified text ABOUT a program rather than the program; the measurement covers `Read` on
2.1.266 and nothing more.

**Subject substitution, stated because the entry prescribed `AskUserQuestion`.** That tool is
not offered under `claude -p`, so the model emitted no tool call at all — zero hook lines with
zero evidentiary value, which is the empty-file-without-a-control failure this repo names.
`Read` is valid because the validation site is shared by every tool. The literal 1-option
`AskUserQuestion` case needs an interactive run; nothing in the mechanism suggests it differs.

**"MALFORMED" IS TWO CLASSES AND ONLY ONE IS MEASURED.** `coerceInput` is an optional per-tool
hook that runs BEFORE `safeParse`, and its telemetry has a `coerced_still_invalid` outcome, so
it is permitted to fail. Hook-invisible: anything `safeParse` still refuses after coercion, or
with no `coerceInput` at all (measured: `Read` with `{"path": …}`), plus unparseable JSON
rejected upstream. Hook-visible: anything a tool's `coerceInput` repairs into a valid shape —
**existence follows from the mechanism; there is NO measured instance.** The nine `coerceInput`
implementations are **not enumerated**, so which malformations are visible cannot be predicted
from this entry. A candidate instance was measured and RETRACTED: re-reading the raw wire bytes
with `repr()` showed the input was a STRING containing brackets, schema-valid on arrival and
failing at the filesystem, not an array being coerced.

**THE DOCUMENTATION HAS MOVED SINCE THIS ENTRY WAS FILED, AND THE SENTENCE IT RESTED ON IS
GONE.** Re-checked: the hooks reference 301s to a new host, and `PreToolUse` now reads only
"Before a tool call executes. Can block it." The quoted "after Claude creates tool parameters
and before processing the tool call" is **deleted**. The ordering is still unstated, so the
entry's conclusion holds — but it no longer leans either way, and a session citing that sentence
is citing text that no longer exists.

**WHAT IS UNBUILDABLE, AND WHAT IS NOT AT RISK TODAY.** The unbuildable class is a `PreToolUse`
guard whose predicate is the malformation itself — the `<2`-option `AskUserQuestion` deny
dropped at v0.407.0, and any "refuse a call the schema will reject anyway" guard. **Nothing
shipped depends on it.** Derived over `templates/settings.json.template`: all five `PreToolUse`
groups (`ctx_*` MCP tools; `Edit|Write|MultiEdit`; `Agent|Task`; the acknowledge matcher; `*`)
read `.tool_input.<field>` on a call they assume is already valid — each decides on CONTENT,
none on VALIDITY. The only `AskUserQuestion` matcher in the template is under `PostToolUse`
(`ai-dlc-answer-capture.sh`), which records answers to SUCCESSFUL calls. A grep for
`tool_input.questions`/`.options` across `core/hooks/` returns 0 against a control of 9 files
containing `tool_input`. So this entry closes a question and forecloses a future design; it
fixes no live defect, and it ships as a recorded answer rather than as code.

**The rejections are real and reachable**, which is what makes the experiment cheap to validate:
parsing session transcripts finds `<2`-option `AskUserQuestion` calls that received an
`InputValidationError` tool_result with `is_error: true`. The reference consumer's sprint 305
carried three, one per session, each losing an operator decision to a compaction within minutes.

**Where it came from.** RC-3 of `docs/plans/graph-s305-triage.md` filed a `PreToolUse` deny on a
`<2`-option `AskUserQuestion`. It was DROPPED at v0.407.0 on the operator's decision, on the
grounds that it could not be shown able to fire AND would duplicate a rejection the lead already
sees in-band. The second ground is independent of this question; only the first depends on it.

**The experiment RAN and the answer is at the top of this entry.** The prescription was right
about method and wrong about one detail: `AskUserQuestion` cannot serve as the subject headless.
The general lesson is the one this repo already carries — an empty hook file is evidence only
beside a positive control that wrote to the same file, in the same session, through the same
registration.

**This entry stays LIVE and is not a fix.** There is nothing to ship: the answer is recorded,
no shipped guard depends on it, and the next author of a malformation-predicated guard needs to
meet this text before building. Its remaining unmeasured half is the coercion partition — nine
`coerceInput` implementations unread, and no measured instance of a repaired call.

  verify: manual

---

## BL-085 — `extends:` cannot express a multi-span dependency, so an additive entry falls back to file grain and nothing says so

`LC-E11` permits exactly one anchor, and the reasoning is sound: two anchors mean two spans and a
drift row could no longer say which one moved. The consequence is that an entry whose dependency
is genuinely multi-span has no way to declare it, falls back to whole-file drift, and is
indistinguishable from an entry whose author never thought about the grain.

**Measured on the reference consumer, twice, on consecutive pulls.** Four `kind: check` entries —
`attribution-provenance`, `gate-validation-domain`, `gate-validation-push`, `validator-honesty` —
report `HARD-LAYER-ADJUDICATION-MISSING` on every pull that touches `steps/gate-validation.md`,
because none declares `extends:` and each one's drift subject is therefore the whole file. Fresh
digests each pull spend the prior verdicts, so that consumer records four near-identical
adjudications per pull whose reasoning is always "core's change was confined to Check N and this
entry adds checks that do not restate it".

**The obvious anchor is worse than none, and that is the finding rather than the recurrence.**
`#Validation Checklist` is 2352 of core's 2560 lines, so declaring it narrows the subject by 6%
and silences `## Gate-type manifest` (94 lines, decides WHEN the entry's check loads) and
`## Consumer-catalog crosswalk` (49 lines, governs how it is numbered) — the two spans an additive
check entry most needs re-reading against. A consumer reaching for the anchor that looks right
would trade 6% fewer re-reads for the drift that would actually break them, and `LC-E11` accepts
it silently: its arms are structural, so a wrong anchor resolves and reports clean forever.

The prose half is landed with this entry — `extensions/README.md` now states that file grain is
correct for a multi-span entry rather than a mis-declaration, with the arithmetic. What is NOT
landed is the ability to say it: the declaration still cannot express the dependency, so the
worklist cost stands and the distinction between "correctly file-grained" and "never declared" is
still invisible to every reader.

Anchored on the count predicate every real fix must change, with a second conjunct so that
DELETING the arm does not satisfy it — the failure mode a removal-shaped receipt otherwise has.

verify: sh test "$(grep -c 'ext_n" -ne 1' core/scripts/validate-layer-entries.sh)" -eq 0 && test "$(grep -c 'err E11' core/scripts/validate-layer-entries.sh)" -ge 3

---

## BL-002 — `uninstall.sh` has no removal path for the machinery under `.claude/`

After `scripts/uninstall.sh --force` on a tree built by `scripts/install.sh`, **25 files
survive**: all 17 `.claude/hooks/ai-dlc-*.sh`, the 6 `.claude/schemas/*.json`,
`.claude/session-driver/ai-dlc-session-driver.sh`, `.claude/settings.json` and
`.claude/.ai-dlc-version`. The script names none of them; `grep -n "hooks\|schemas"` over it
returns only a comment about `core.hooksPath` and the `.githooks/pre-push` removal.

`settings.json` is genuinely shared with the consumer and must be un-merged rather than
deleted, so this is not one removal loop. The hooks are not shared — `.claude/hooks/ai-dlc-*.sh`
is the same prefix boundary `install.sh` already writes by, and v0.106.0 narrowed `hooks/*.sh`
to `hooks/ai-dlc-*.sh` for exactly this reason.

**RE-MEASURED AT BATCH 144, AND THE RECEIPT ABOVE COULD CLOSE THIS ON A COMMENT.** A contract
adversary on `BL-291` reported that `uninstall --force` on an installed 0.624.0 tree left all 24
`ai-dlc-*.sh` hooks and `settings.json` in place, still registered. Re-taken here with the
0.624.0 tree (`origin/main` `5376b309`), installed by its own `scripts/install.sh` into an empty
`mktemp` git repo holding an empty `_bmad/`, then `scripts/uninstall.sh . --force` (the project
root is the FIRST positional argument; `uninstall.sh --force` alone reads `--force` as the root and
exits 1 having removed nothing). Hooks **24** before and **24** after, uninstall rc **0**, and
**21** distinct `ai-dlc-*.sh` names still registered in the surviving `settings.json`. Control in
the same run: the `.claude/rules/ai-dlc-*.md` files, which `uninstall.sh` does remove by prefix,
went from present to **0**. At `b144-release`, after `BL-291`, it is 23 hooks before and 23 after,
with 20 registered. Also surviving: `.claude/.ai-dlc-version`, the session driver, the `schemas/`
files and `.claude/agents/*.md`.

`scripts/uninstall.sh:64` introduces the rule-file loop with *"the `ai-dlc-` prefix is the boundary,
as it is for hooks"*. No hook loop exists: `grep -c 'hooks/ai-dlc-' scripts/uninstall.sh` returns
**0**. The comment describes code nobody wrote.

**THE `has` RECEIPT WAS SATISFIABLE BY PROSE, SO IT IS REPLACED.** Appending the comment `# remove
.claude/hooks/ai-dlc-*.sh and un-merge settings.json` to `uninstall.sh` would have proposed CLOSE
while nothing changed. The receipt below drives the real programs. It installs a fresh consumer
under `mktemp`, requires at least one hook present and registered and one `ai-dlc-*.md` rule file
present, runs `uninstall.sh . --force`, and requires the rule file gone (the control, so an
uninstall that did not run cannot score). It then exits 1 if any `ai-dlc-*.sh` hook survives, or if
a surviving `settings.json` still registers one. Distribution engine: exit 0 is CLOSE-CANDIDATE.
About 5s, most of it the install; each run leaves one installed tree under `$TMPDIR`.

| tree | exit |
|---|---|
| `b144-release` | **1** |
| `origin/main` `5376b309` | **1** |
| `b144-release` with that comment appended to `uninstall.sh` | **1** |

A fix that passes it has not been built, so no passing score exists yet. `settings.json` still has
to be UN-MERGED rather than deleted, as the paragraph above says.

verify: sh [ -r scripts/install.sh ] && [ -r scripts/uninstall.sh ] || exit 9; command -v git >/dev/null || exit 9; R="$(pwd)"; T="$(mktemp -d)" || exit 9; ( cd "$T" && git init -q && mkdir _bmad && git -c user.name=r -c user.email=r@r commit -q --allow-empty -m init && bash "$R/scripts/install.sh" ) >/dev/null 2>&1 || exit 9; set -- "$T"/.claude/hooks/ai-dlc-*.sh; [ -f "$1" ] || exit 9; grep -q 'hooks/ai-dlc-[a-z0-9-]*\.sh' "$T/.claude/settings.json" 2>/dev/null || exit 9; set -- "$T"/.claude/rules/ai-dlc-*.md; [ -f "$1" ] || exit 9; ( cd "$T" && bash "$R/scripts/uninstall.sh" . --force ) >/dev/null 2>&1 || exit 9; set -- "$T"/.claude/rules/ai-dlc-*.md; [ -f "$1" ] && exit 9; set -- "$T"/.claude/hooks/ai-dlc-*.sh; [ -f "$1" ] && exit 1; [ -f "$T/.claude/settings.json" ] && grep -q 'hooks/ai-dlc-[a-z0-9-]*\.sh' "$T/.claude/settings.json" && exit 1; exit 0

---

## BL-003 — on a CONSUMER, `layer-contract-conformance-b`'s SKIP prints its sibling's name

Scope matters here and the first filing of this entry got it wrong. **In this repo the shard
names itself correctly** — it banners `layer-contract-conformance-b fixture` and closes with
`PASS: all 17 assertions correct in shard 'b' of 'a b'`. There is no collision.

The collision is consumer-only. On a tree where `validate-enforcement-map.sh` is absent, the
shard `exec`s the sibling (`core/fixtures/layer-contract-conformance-b/run.sh:42`) and the
sibling takes its SKIP path, whose message is a hardcoded literal naming itself
(`core/fixtures/layer-contract-conformance/run.sh:70`). Both directories then emit
`layer-contract-conformance: SKIP — ...` and a consumer's suite log cannot be read by name.

The runner keys verdicts on the directory, so nothing is broken. What it costs is the
verification step this repo requires of every release — read the fixture BY NAME in the full
output — which is unsatisfiable for this pair on the only tree where it fires.

Anchored on the hardcoded literal any fix must remove, not on a description of the fix.

verify: lacks core/fixtures/layer-contract-conformance/run.sh "layer-contract-conformance: SKIP"

---

## BL-006 — the PLANS corpus and the CONSUMER's own ledger are still unbounded

**NARROWED at v0.418.0. The original subject is discharged; two subjects are not, and this entry
is those two.** `docs/backlog.md` is now bounded by `scripts/validate-backlog-size.sh` (arm `B1`,
`AI_DLC_BACKLOG_MAX_ENTRIES`, default 100), registered as a `step` in `.githooks/pre-push`. What
follows is what that arm does NOT reach. **An entry with two subjects expires only when both do**,
and the receipt below is a conjunction for exactly that reason — it exits 0 only when both halves
are discharged, so no single-corpus fix can retire this entry.

**`docs/plans/` is unbounded and the ledger ceiling does not touch it.**
`scripts/validate-plan-shape.sh` has no size arm at all: its only `wc -l`, at `:131`, resolves a
cited line number, and it contains no `wc -c`. Re-derived on this tree —
`docs/plans/retire-graph-consumer-layer.md` is **384817 bytes** against a **17021-byte median
across 29 plans**, a 22.6x ratio, and no push has ever failed over it. (The figures this entry
was filed with, a 16726-byte median across 23 plans, have drifted; the ratio has not.) That
validator is already standalone and already runs at pre-push (`.githooks/pre-push:117`), so the
arm has a home that costs no suite-pole wall clock.

**The CONSUMER's own push-candidate ledger is unbounded, and the distribution-side arm reaches no
consumer by construction.** `core/skills/ai-dlc-update/SKILL.md:1723-1724` records the reference
consumer's ledger at **2830 lines / 220 KB / 50 entries, of which only 39 are still classified** —
the state this whole pattern was forked from. `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh`
carries no ceiling of any kind. `docs/backlog.md` does not ship: `install.sh` copies from
`core/scripts/`, never from top-level `scripts/`, so `validate-backlog-size.sh` is
distribution-only and a consumer inherits nothing from it.

**This entry previously cited `SKILL.md:1678` for those figures and that citation was WRONG-TARGET.**
`:1678` is prose about a checker obeying an over-wide declaration; `2830` occurs at `:1723`.
It is the `v0.390.0` class — the citation RESOLVES, so `validate-plan-shape.sh`'s resolvability
arm passes it, and a dangling-ref detector is blind to a wrong-target ref by construction.

**WHAT A `CLOSE-CANDIDATE` ON THIS ENTRY WOULD AND WOULD NOT MEAN.** The receipt's consumer half
drives shipped `reconcile/*.sh` against two synthetic ledgers inside a clone. It therefore
certifies that **the DISTRIBUTION ships a program that refuses an oversized ledger** — never that
any consumer's ledger is actually bounded, which no distribution-side receipt can observe. A
consumer runs its own installed engine, so the bound arrives only on the pull that carries it.
Read a green row here as "the refusal is shipped", and confirm the consumer separately. This
entry has already produced one false `CLOSE-CANDIDATE`; this paragraph exists so the next one is
not merely a misread.

**Put the consumer-side ceiling where a LEDGER PATH is the argument.** Measured over the 22
`reconcile/*.sh`: four accept a bare ledger path (`ledger-rotate.sh`, `adopt-extension-checks.sh`,
`lib.sh`, `relabel-extension-checks.sh`) and the other 18 exit non-zero on any ledger, being usage
errors. `ledger-reverify.sh` is one of the 18 — its argument order is a `<dist> <base> <consumer>
<theirs>` pull triple — so a remedy landing inside it would read STILL-LIVE against the receipt
below. `ledger-rotate.sh` is the natural home: it is the shipped program whose declared subject is
already this ledger's SIZE, and its default is dry-run.

**What the discharged half cost, recorded because the next author will propose it again.** A BYTE
clause was ruled, built and withdrawn on measurement: rotation is the only sanctioned lever and it
is denominated in ENTRIES; archived entries average 7193 bytes against a live mean of 3758, so
archiving one frees 1.9x the live mean; a byte ceiling admitting the same growth sat within 1.5% of
the entry ceiling and bound first, making the entry clause vacuous; and at all four states where
such a clause approached firing the count of rotatable entries was ZERO. A per-entry cap fails too
— 10 of 27 archived entries exceed 8000 bytes and the largest is 16137.

verify: sh D=$(mktemp -d) || exit 9; trap 'rm -rf "$D"' EXIT; git clone -q --local . "$D/r" 2>/dev/null || exit 9; (git ls-files -z -mo --exclude-standard | tar -cf - --null -T - 2>/dev/null) | (cd "$D/r" && tar -xf - 2>/dev/null); RC="$D/r/core/skills/ai-dlc-update/reconcile"; H="$D/r/.githooks/pre-push"; [ -d "$RC" ] && [ -f "$H" ] || exit 9; n=0; for f in "$RC"/*.sh; do [ -f "$f" ] && n=$((n+1)); done; [ "$n" -ge 2 ] || exit 9; awk '/^step /{s=1;next} s&&/^  bash /{print;s=0}' "$H" > "$D/cmds"; [ -s "$D/cmds" ] || exit 9; P=$( cd "$D/r" && wc -c docs/plans/*.md 2>/dev/null | awk '$2!="total" && $1>m {m=$1; f=$2} END{print f}' ); [ -n "$P" ] && [ -f "$D/r/$P" ] || exit 9; mkl() { mkdir -p "$(dirname "$1")"; { printf '# Push-candidate ledger\n\nPreamble prose that belongs to no entry.\n\n'; awk -v n="$2" 'BEGIN{for(i=1;i<=n;i++)printf "## PC-S900-%04d — an open push candidate\n\nBody text.\n\nverify: theirs_has core/scripts/thing.sh \"MARKER_A\"\n\n---\n\n", i}'; } > "$1"; }; mkl "$D/s/l.md" 10 && mkl "$D/b/l.md" 500 || exit 9; [ "$(grep -c '^## PC-' "$D/b/l.md")" -eq 500 ] && [ "$(grep -c '^## PC-' "$D/s/l.md")" -eq 10 ] || exit 9; C8=0; for f in "$RC"/*.sh; do bash "$f" "$D/s/l.md" >/dev/null 2>&1 || continue; bash "$f" "$D/b/l.md" >/dev/null 2>&1 || { C8=1; break; }; done; [ "$C8" = 1 ] || exit 1; cp "$D/r/$P" "$D/po" || exit 9; awk 'BEGIN{for(i=0;i<4000000;i++)print ""}' >> "$D/r/$P" || exit 9; cp "$D/r/$P" "$D/ps"; C6=0; while IFS= read -r c; do ( cd "$D/r" && eval "$c" ) >/dev/null 2>&1 && continue; cp "$D/po" "$D/r/$P"; ( cd "$D/r" && eval "$c" ) >/dev/null 2>&1 && C6=1; cp "$D/ps" "$D/r/$P"; [ "$C6" = 1 ] && break; done < "$D/cmds"; [ "$C6" = 1 ]

---

## BL-093 — the ledger ceiling bounds one member of a wider unbounded population

`scripts/validate-backlog-size.sh` bounds `docs/backlog.md`. Derived by ranking every tracked
file by `wc -c`, it is the **5th** largest and not the largest unbounded queue in the tree:
`CHANGELOG.md` is **2004483 bytes / 504 release headings**; `.ai-dlc-fixture-readsets.tsv` is a
**tracked, machine-appended 1638114-byte / 21107-line register**; `docs/plans/retire-graph-consumer-layer.md`
is **384817 bytes**; and `docs/context-hardening-notes.md` is **104394 bytes** and is the file
`.claude/rules/resident-context.md` directs every session to append stories to. The only other
ceiling in the repo is A6's `DURABLE_MAX` over `CLAUDE.md` + `.claude/rules/`.

Two of these are DEFENSIBLY unbounded — a CHANGELOG is a history and an archive is an archive —
and saying so in their own headers is the cheaper half of the fix, because an audit that has to
re-derive "is this a queue or a log" each time will keep re-filing this entry. The one that is
neither is `docs/context-hardening-notes.md`: it is a live read target with a standing instruction
to append to it and nothing bounding it.

Decide per file whether it is a QUEUE (bound it) or a LOG (say so, in its own header, so the next
audit stops). The plans corpus is NOT part of this entry — it is `BL-006`'s surviving half.

verify: manual — the disposition is a judgment per file, not a predicate.
## BL-004 — the nine inner pools are owed, and the hook records them as owed

66 workers sit on top of the outer pool. They cannot be swept with an environment variable —
`enforcement-map-sites` scrubs every ambient `AI_DLC_*` name for I10, and I87 binds any key a
shipped program dereferences — so sweeping them means editing the constants on a throwaway
branch that is never pushed.

The design to use: pin the dispatched set, reset the durations record from one golden copy
before every run, visit cells round-robin, and take a difference as real only where two cells'
readings do not overlap.

Carried over from `docs/plans/pre-push-wall-clock.md`, which is otherwise discharged.

verify: manual

---

## BL-005 — `validator-arm-selection` shard `b` has a ~47.8s solo floor set by three serial units; two routes below it were measured and neither taken

Its shard `b` has a measured floor of ~47.8s solo, set by three serial units: a seeded run at
16s, an attribution sweep at 11s, and a mutant's three parallel full runs at 18s. Going below
it needs either a third directory duplicating the 27s prerequisite, or overlapping the seeded
run with the attribution sweep. Both were measured; neither was taken.

**THIS ENTRY IS NOT ABOUT THE POLE, AND ITS HEADING SAID IT WAS UNTIL `v0.583.0`.** The pre-push
pole is `ledger-reverify` at **628s loaded** — pool 12, full suite under
`AI_DLC_FIXTURE_NO_SKIP=1`, taken as the MAX of three calibrated serial runs in a `file://`
clone of `origin/main` at `83747ef4`: **628s** (wall 743s, load average 50.56 at start), **563s**
(wall 629s, load 9.06), **562s** (wall 627s, load 5.30). Since `v0.583.0` that figure is watched
by `scripts/validate-suite-pole.sh` against the tracked baseline
`docs/suite-pole-baseline.tsv`, which is what `BL-257` built. The **166s / 217s** figures this
entry's heading carried were displaced at **v0.541.0** by `BL-088`, whose own landing paragraph
records the pole falling to `ledger-reverify` in the same change — four releases before
`BL-255` read the heading and found it still asserting them. A session scoping performance work
off this entry optimizes a fixture that is not the pole; shard `b`'s floor is a real and
separate subject, and it is the only subject this entry has.

Carried over from `docs/plans/pre-push-wall-clock.md`. This is a program, not a single fix.

verify: manual

---

## BL-007 — the audit-anchor chain is a 1-deep link, so an old gap is permanently invisible

`--prior-sprint-sha` computes `prior = current - 1` and exact-matches it
(`core/scripts/validate-audit-anchors.sh`). There is no contiguity assertion anywhere in the
anchor path — control: monotonicity language exists elsewhere in the corpus
(`core/scripts/validate-spec-join.sh` "non-monotonic; ids must ascend and never renumber"), so
the grep that found none in this path was working.

Consequence: a gap at sprint N−1 is fatal, and a gap at N−2 or older is undetectable. Two
sprints after a hole nothing revisits it, and `retro.md` Step 5b prunes the live file to the 3
most recent entries into an archive with, in its own words, "no rendered schema region, no
validator, no budget".

Scoped OUT of the v0.372.0 close-record work on the operator's decision: that release makes a
non-retro close RECORDABLE, which is what the consumer filed. Detecting historical holes is a
different check and would fire on every consumer whose chain already has one, so it needs a
PENDING/SKIP posture for pre-migration state before it could ship.

The receipt is BEHAVIOURAL and carries its own control. It builds a chain with sprints 10 and
12 and asks for sprint 13's prior: the resolver answers 12 happily and never sees that 11 is
missing, so a zero exit there IS the defect. Asking for 12's prior on the same file exits 1,
which is the control that the resolver does fire on an N−1 absence — the two together are what
distinguish "no contiguity check" from "no check ran". An anchor on the `current - 1` source
line would have closed itself on a reformat.

verify: sh t=$(mktemp -d); f="$t/a.md"; bash core/scripts/validate-audit-anchors.sh --render > "$f"; H=$(git rev-parse HEAD); printf '\n- sprint: 10\n  sha: %s\n\n- sprint: 12\n  sha: %s\n' "$H" "$H" >> "$f"; bash core/scripts/validate-audit-anchors.sh --prior-sprint-sha "$f" 13 >/dev/null 2>&1; r=$?; rm -rf "$t"; [ "$r" -eq 0 ] && exit 1 || exit 0

---

## BL-010

**`templates/pipeline/` survives its own retirement, holding one file nothing reads and nothing
installs.** `templates/pipeline/pvc-presentation-template.md` is the sole tracked file under that
directory and it has no reader and no copier. `git grep -nE 'templates/pipeline' -- core/ scripts/
.githooks/` returns exactly one hit and it is a COMMENT at `scripts/install.sh:198` recording the
retirement; control `templates/audit-anchors` over the same corpus returns rc=0 with six files.
`git grep -n 'pvc-presentation' -- core/` returns rc=1, against a control hit for
`templates/retro-finding-class-tracking` at `core/skills/ai-dlc/steps/retro.md:193`.

`scripts/install.sh:196-214` is the fix that created the residue: its copy loop globs
`core/skills/ai-dlc/templates/*.md`, and the migration moved what had a reader while leaving this
file at the retired path where the glob cannot see it. Either it has a reader and belongs under
`core/skills/ai-dlc/templates/` where the derived glob delivers it, or it does not and the directory
goes. What it must not stay is a third home for skill templates that `install.sh` documents as
retired.

Anchored on install.sh's `cp` LINES, never on the path — the path already appears in the comment
recording the retirement, so a path anchor would be satisfied by the text describing the defect.
Measured: `grep -E 'templates/pipeline/' scripts/install.sh` rc=0 (that comment), while
`grep -E '^[^#]*cp .*templates/pipeline/'` rc=1.

**Removal is a valid fix and the receipt allows it** — with no tracked file under the directory the
loop does not run and the predicate passes, verified by running it against an empty pathspec.

Discharges the consumer bullet at pinned ledger line 281
(`.claude/skills/ai-dlc/templates/`, no `PC-` id), whose section annotation says "Retire this
section on the next drain". That retirement is GATED on this entry.

**Its sibling claim was REFUSED, deliberately.** `templates/audit-anchors.md.template` is
*intentionally* unshipped and core says so in four places, including
`core/fixtures/audit-anchors-schema/README.md:9` ("never shipped to a consumer") and the two records
that its schema was single-sourced out into `core/schemas/audit-anchors.json` because it "used to
live in TWO places at once". Its absence from a consumer is the FIX. Filing it would file a settled
decision as a bug.

verify: sh bad=0; for f in $(git ls-files templates/pipeline/); do grep -qE "^[^#]*cp .*(${f}|templates/pipeline/)" scripts/install.sh || bad=1; done; [ "$bad" -eq 0 ]

## BL-020

**Two of the budget script's six finding channels set no flag, and the summary closes them with an
unqualified PASS.** `core/scripts/validate-artifact-budget.sh` has six finding channels — `:1025` over
budget, `:1084` off-schema section, `:1118` marked-superseded content, `:1149` struck In-Flight rows,
`:1178` unrecognised In-Flight status, `:1262` ungoverned artifacts. Four set a `SAW_*` flag; the two in
the middle, `:1118-1143` and `:1149-1170`, set none. The summary gate reads three at `:1309` and
`SAW_UNGOV` in the `elif` at `:1318`, so a run whose only finding came from either flagless channel
falls through to the `else` at `:1322` and prints, at `:1323`,
`PASS  every measured living artifact is within its Rule 25(d) budget.` — byte-identical to what a
genuinely clean run prints.

Measured on four seeded snapshots under the invocation `core/skills/ai-dlc/steps/retro.md:533` actually
prescribes, `--warn-only --fail-on pipeline-snapshot.md`. A struck In-Flight row gives exit 0, one
`WARN:` row, zero qualified summary lines, one unqualified PASS line. Controls in the same run: an
unrecognised status token — a covered channel — gives the qualified `WARN  this run reported ...` line
and no PASS line; a clean snapshot gives the PASS line and nothing else.

`retro.md:593` tells the reader "**Exit 0 is not by itself CLEAN under `--warn-only`** — the summary
line says which". On the struck-row channel that instruction is false, and it is the instruction the
operator uses to decide the row's verdict.

**Scope, measured rather than assumed, and narrower than filed.** Only the struck-row channel produces
the false PASS under retro's flags. The marked-superseded block is gated at `:1120` on
`! is_fail_on "pipeline-snapshot.md"`, so `--fail-on pipeline-snapshot.md` turns it into a FAIL, `RC=1`,
and the summary block at `:1307` is skipped — measured both ways: `a-struck` rc=0 bare_PASS=1,
`b-marker` rc=1 bare_PASS=0. Both blocks are owed the flag; only one is reachable as a false PASS from a
shipped invocation today.

`core/fixtures/budget-summary-verdict` owns this filing and covers neither channel. Its header at
`:79-82` records choosing `gate-log.md` over `pipeline-snapshot.md` so a breach-channel arm could not be
satisfied by another snapshot channel firing — correct for those arms, and why the two flagless channels
were never seeded.

Behavioural, under the step file's literal flags. The `WARN:` row is the control, so a seed that stops
working reports STILL-LIVE rather than closing. Proven able to fire: with one line added setting a flag
inside the struck-row block of a copy, the same predicate exits 0.

verify: sh d=$(mktemp -d); mkdir -p "$d/_bmad-output"; printf "## Pipeline Position\n- x\n## Sprint Context\n- x\n## Recent Activity\n- x\n## Open Items\n- x\n## Locked Decisions\n- x\n## In-Flight Teammates\n| teammate | deliverable | dispatched-at | note | status |\n| --- | --- | --- | --- | --- |\n| ~~a~~ | t | t | n | in-flight |\n## Context Reminders\n- x\n" > "$d/_bmad-output/pipeline-snapshot.md"; printf "tiny\n" > "$d/_bmad-output/gate-log.md"; o=$(bash core/scripts/validate-artifact-budget.sh --root "$d" --warn-only --fail-on pipeline-snapshot.md 2>&1); rm -rf "$d"; [ "$(grep -cF "WARN: In-Flight Teammates carries struck-through row(s)." <<<"$o")" -ge 1 ] || exit 1; [ "$(grep -cF "is NOT a clean result" <<<"$o")" -ge 1 ] || [ "$(grep -cxF "PASS  every measured living artifact is within its Rule 25(d) budget." <<<"$o")" -eq 0 ]

## BL-024

**This repo already adjudicated all five blocks of the `implementation-push` row, wrote
"recorded so the next reconciliation does not re-triage" beside the verdicts, and shipped no
reader — so the reconciliation re-triaged them.** `docs/v0.13.0-consumer-absorption-spec.md:385`
is "## 5. Explicitly NOT backported (graph-local — install would destroy these)", and `:393`
names **`done-pending-liveness`** and the **`story-status-consistency script`** inside it. `:344`
is "## 4. Tier-3 (weak / verify / heavy de-graph — likely leave)", `:346-348` reads "The 'likely
leave' assumption HELD for all five — none absorbed. Verdicts + evidence recorded so the next
reconciliation does not re-triage", and `:350-355` disposes of the mid-sprint scope re-check
trigger (`PI-S241-2`) as **LEAVE**, overlapping core's existing per-commit scope verification.
The remaining two are absorbed: `core/skills/ai-dlc/steps/implementation.md:86` is
"**Worktree-explicit dev dispatch.**" and `:225` is "**Dev-brief bug-class checklist.**", with
`:101`, `:113` and `:117` carrying the `git worktree add` base-ref and `git stash` ban verbatim.
Measured with a control in the same invocation: files under `core/` naming `done-pending-liveness`
= **0**, `validate-story-status-consistency` = **0**, `Mid-Sprint Scope Re-Check` = **0**;
`git worktree add` = **2**, `bug-class checklist` = **1**. **Nothing reads the record.** Across
the whole tracked tree, files naming `v0.13.0-consumer-absorption-spec` = **2**, and they are
`CHANGELOG.md` and `.ai-dlc-fixture-readsets.tsv` — a provenance note and a readset row, neither
a mechanism. Files under `core/` naming `consumer-absorption` = **0**, against a control of **29**
files under `core/scripts/` that name some `docs/` path, so the search can find a core-side
reference to `docs/` when one exists.

**The row's own claim is dead in every part, and the correction is that the defect is on this
side of the boundary.** Five blocks named: two absorbed, two under a standing "explicitly NOT
backported" ruling, one under a standing "LEAVE". As a push-candidate row it is a withdrawal
candidate, not a filing. What survives is an ai-dlc defect the row is evidence FOR: the
distribution keeps its absorption verdicts in a `docs/` design record marked `Status: PROPOSED`
that the reconcile machinery cannot reach, so every drain re-proposes items already refused, and
the refusal has to be re-derived by hand each time — which is what produced this entry. This is
the check-cannot-fire shape inverted: not a check that never fires, but a verdict with no
consumer.

The anchor is `consumer-absorption` under `core/skills/ai-dlc-update/`, because the fix is that
the reconcile machinery names the standing-verdict record — the join cannot be built without the
reference existing there. A tree-wide anchor was rejected on measurement: `v0.13.0-consumer-absorption-spec`
already matches two tracked files, so any receipt keyed on mere mention is satisfied by the
CHANGELOG line that recorded the spec's own creation, which is precisely an anchor on text the
fix quotes back. The control is `layer-drift` under the same subtree, which matches today, so a
mistyped path fails loudly instead of reporting a green absence.

Discharges the consumer entry `extensions/steps-domain/implementation-push.md` at pinned ledger
line 259. That row is a withdrawal candidate on its own terms; this entry is the ai-dlc-side
mechanism whose absence let it survive.


verify: sh grep -rqF 'layer-drift' core/skills/ai-dlc-update/ || exit 1; grep -rqF 'consumer-absorption' core/skills/ai-dlc-update/
## BL-025

**`SKILL.md`'s PREREQUISITES tells the lead that teammates set their own effort in their role
files, and all 18 role files say the opposite in the same words.**
`core/skills/ai-dlc/SKILL.md:22-25` reads *"Teammates set their own effort level via their role
files (high for planning roles, medium for implementation roles)."* Every role file states the
contrary: `core/team-roles/dev.md:8-10`, `pm.md:8-10`, `qa.md:8-10` and the rest carry **"Model
and effort: set at the start of your session from `aiDlcRoles.<role>` in `.claude/settings.json`.
That entry is the only source; do not infer either value from anywhere else."** Measured with a
control in the same invocation over `core/team-roles/`: files naming `effort` = **18 of 18**;
control, files naming `ownership` = **17**, so the corpus is real and the count is not an
artifact of the search. `SKILL.md:652` (Rule 19, *"Config is authoritative"*) agrees with the
role files and contradicts `SKILL.md:22-25` inside the same file.

The stated mapping is also unrepresentable. `templates/settings.json.template` configures four
distinct effort values across the 18 roles — `high` 11, `medium` 5, `xhigh` 1 (`ops`), `max` 1
(`pm-escalated`) — so **2 of 18 configured values fall outside the two-value vocabulary
`SKILL.md:22-25` states**, and a lead following that sentence would infer a value the config
never carries.

**What the filing got wrong, and the direction: wider, and a different cause.** The ledger files
this as `effort-SSOT`, an *additive* extension block supplying a single source of truth core
lacks. Core does not lack one — it has two, and they disagree. The defect is an internal
contradiction between a resident orchestrator file and every role file plus core's own Rule 19,
not a missing statement. The consumer block's own framing ("the one role config does not cover")
is likewise stale: `aiDlcRoles` covers it, and `core/hooks/ai-dlc-dispatch-guard.sh` binds it.
The lead reads `SKILL.md`; the teammate reads the role file; the two are handed opposite rules
about the same field, which is why nothing has ever surfaced it.

**Why the anchor is the anchor.** The predicate reads only the `## PREREQUISITES` block, and
asks the disjunction *"does it name `aiDlcRoles`, or has it stopped attributing effort to role
files"* — so it closes under either plausible fix (repoint the sentence at the config, or delete
it), and does not depend on wording nobody has written. A whole-file `grep` for `aiDlcRoles`
false-closes immediately: the token occurs at `SKILL.md:645` and `:652` inside Rule 19, which is
the half that is already correct. The block extraction carries its own control — the receipt
exits 1 if the block is empty or has stopped mentioning `effort` at all, so a heading rename
reports STILL-LIVE rather than closing.

Discharges the consumer entry `extensions/steps-domain/SKILL-push.md` at pinned ledger line 262
(the `effort-SSOT` block, `INITIALIZATION §2`).


verify: sh b=$(LC_ALL=C awk '/^## PREREQUISITES/{f=1;next} f&&/^## /{exit} f' core/skills/ai-dlc/SKILL.md); [ -n "$b" ] || exit 1; grep -qi effort <<<"$b" || exit 1; grep -qF aiDlcRoles <<<"$b" || ! grep -qi "role file" <<<"$b"
## BL-026

> **LEAD: this entry is an ADDITION the pin-262 ledger row does not name.** The row enumerates
> six blocks; the file at `510e4d9f5` carries five, and this is the one live block missing from
> the enumeration. Filed because dropping it would lose the measurement; drop or keep at your
> discretion.

**Core has no rule requiring an N-item independent dispatch to be split into N teammates, and
the only occurrence of the pattern's name in `core/` is fixture seed data.**
`core/skills/ai-dlc/SKILL.md` Rule 28 (`:1398`, *"Delegation is the default; inline execution is
the exception"*) decides delegate-vs-inline and says nothing about the shape of a single
dispatch: over its 82-line body, `parallel` = **0** and `split` = **0**, against controls
`delegat` = **2** and `inline` = **5** in the same invocation. Core's Rule 29 is *"Steering
budget: the operator must always be able to reach you"* (`:1481`) — the number collides with the
consumer's `Rule 929` and the subject does not. Across all 31 `### Rule N --` headings in
`SKILL.md`, none names parallel, split or sub-task dispatch.

`grep -rl split-dispatch core/` returns two files, both
`core/fixtures/layer-catalog-collision/` — `seed.sh:220` writes the literal heading
`## Rule 29 -- Parallel independent-scope sub-task dispatch (split-dispatch pattern)` as a
*collision probe*. That is a fixture manufacturing the string, not core carrying the rule, and it
is exactly the "a grep hit inside a file is not a statement about that file" trap: a naive
`grep -rl` over `core/` reports the concept present.

**What the filing got wrong, and the direction: the enumeration is incomplete.** The ledger row
lists `effort-SSOT; pending-approval author-side marking (S253); no-self-schedule re-entry ban;
Rule 19 model-derivation; four-clause file-write convention; gate-log auto-rotation`. Measured
against the file at `510e4d9f5` with a control in the same invocation: `pending-approval` = 0,
`S253` = 0, `self-schedule` = 0, `re-entry` = 0 — two named blocks are gone — while
`Effort level` = 1, `four-clause` = 2, `gate log` = 7, `Rule 19` = 4 confirm the search works on
the same file. The row names two blocks that no longer exist and omits this one, which is both
present and live.

**Why the anchor is the anchor.** The predicate is a disjunction over the two places a fix can
land — inside Rule 28's body, or as a new rule heading naming the pattern — so it does not
presume a shape. It scopes to Rule 28's body rather than the file, because `parallel` and
`split` both occur elsewhere in `SKILL.md` and a file-level grep closes on unrelated prose. The
`delegat` control fires in the same invocation, so a renamed or renumbered Rule 28 reports
STILL-LIVE instead of closing on an empty extraction.

Discharges the consumer entry `extensions/steps-domain/SKILL-push.md` at pinned ledger line 262
(the `Rule 929` split-dispatch block, unnamed in that row).


verify: sh S=core/skills/ai-dlc/SKILL.md; b=$(LC_ALL=C awk '/^### Rule 28 /{f=1;next} f&&/^### Rule 29 /{exit} f' "$S"); [ -n "$b" ] || exit 1; grep -qi delegat <<<"$b" || exit 1; grep -qEi 'parallel|split' <<<"$b" || grep -qEi '^### Rule [0-9]+ --.*(parallel|split-dispatch|sub-task)' "$S"
## BL-027

**`has_ready_sprint` is defined over every story in the tree with no sprint scope, and nothing on
the fresh-start path forbids reading the stale snapshot it is about to archive.**
`core/skills/ai-dlc/steps/route.md:18` reads ``- `has_ready_sprint`: boolean (stories exist with
status ready-for-dev or in-progress)``. Strip the identifier from that line and the word `sprint`
occurs **0** times — the variable that decides whether a sprint is ready never says *which*
sprint, so a stale `in-progress` story in a sprint block already closed sets it true. Same file,
`:51-55`: Step 0 item 3 hands the fresh-start case to Step 6 and stops; `read` occurs **0** times
in it, against a control of **3** in the adjacent item 2 (*"Do NOT re-read or re-grep the
snapshot"*) extracted by the same awk. Across the whole file, `unread|never read|without reading|
do NOT read` matches **0** lines while the control `read` matches **38** — core states no
read-prohibition anywhere on that path, and Step 6 at `:548` only says the old file is *absorbed*
into the archive, never that its content is not read first.

**What the filing got wrong, and the direction: narrower — one of its three blocks is superseded
and partly countermanded.** The row names three blocks and the first two reproduce as above. The
third, *script-based snapshot reset*, has been overtaken: core shipped
`core/scripts/rotate-snapshot-archive.sh`; `route.md:568` now says **"Run the rotator; do
not move the file by hand"** and `:561-562` explicitly **retires** the dated spelling
`pipeline-snapshot.archive.{ISO-timestamp}.md` — which is precisely the spelling the consumer
block mandates (`git mv` to that name), citing 158 accumulated files in five timestamp spellings
as the reason. Pushing that block would regress core. Its only surviving residue is that the
*create* path is still hand-authored prose rather than a script, which is not what the row
claims and is not filed here.

**Why the anchor is the anchor.** Both arms are conjoined deliberately: a fix that scopes
`has_ready_sprint` and leaves the snapshot read unprohibited still reports STILL-LIVE, because
the row is one entry covering two live blocks and closing it on half would lose the other. Arm 1
does not guess the fix's wording — it asks only whether the definition references a sprint
*outside its own identifier*, which any scoping fix must, whatever words it picks. Arm 2 is an
alternation over the read-prohibition forms (`unread`, `never read`, `not be read`, `without
reading`, `do not read`); it is deliberately tight rather than a negation-near-`read` regex,
because the looser form matches item 2's existing *"Do NOT re-read"* and false-closes on text
that predates the defect. Both arms exit 1 on an empty extraction, so a restructured `route.md`
reports STILL-LIVE rather than closing.

Discharges the consumer entry `extensions/steps-domain/route-push.md` at pinned ledger line 265.


verify: sh r=core/skills/ai-dlc/steps/route.md; v=$(LC_ALL=C awk '/^- .has_ready_sprint/{print;exit}' "$r"); [ -n "$v" ] || exit 1; s=$(sed 's/has_ready_sprint//g' <<<"$v"); grep -qi sprint <<<"$s" && grep -qEi 'unread|never read|not be read|without reading|do not read' "$r"
## BL-028

**Core's sprint-review has no rule for a decision branch that no live event exercises, so
mutation coverage of the branch *selection* is accepted as evidence the *selected* branch runs.**
`core/skills/ai-dlc/steps/sprint-review.md` §3 (*Fix and Re-Validate*, 29 lines) carries
`branch` = **0**, `carry-over` = **0** and `coverage` = **0**, against controls `mutation` = **1**
and `live` = **4** extracted from the same section in the same invocation — the section is real,
non-empty and does discuss live behaviour, and still says nothing about an unexercised branch.
Across `core/`, seven distinguishing tokens from the consumer block return zero files —
`decision-branch`, `execution-coverage`, `mutation-coverage`, `un-exercised`, `organic-trigger`,
`organic trigger`, `passive live` — against a control of **20** files naming `sprint-review`.

§3's nearest core rule is *Core-path seam non-deferral*, and it is a different subject that
cannot absorb this one: it governs a **wiring-reachable** seam and mandates an in-pipeline
mutation-RED test **before merge**. The case here is the complement — a branch that *cannot* be
exercised pre-merge because no live event takes it — and the prescribed act is a passive
live-validation carry-over with an organic reopen trigger, which core's rule has no room for.
Complementary, not duplicated.

**What the filing got wrong, and the direction: a REPOINT, not a close.** The row names
`extensions/steps-domain/sprint-review-push.md`, and that file does not exist on the consumer.
Measured with a control in the same listing: `ls` on it fails while `route-push.md` in the same
directory resolves. It was deleted at `a1e002e68` (`0.92.0 → 0.93.0` reconcile), and the ledger's
own section header at line 211 already said so. **The content was not retired.** That commit's
message records it: *"sprint-review-domain §3 (S258-DV-1) and sprint-review-push §3 (PI-S259-2)
REFILED into one override, `overrides/steps__sprint-review__fix-and-re-validate.md`"*, and, in
the same message, *"Push candidates drained to the ledger: the PI-S259-2 rule (upstream has no
equivalent)"*. The block is live at `overrides/steps__sprint-review__fix-and-re-validate.md:30`
and `:86`. Reading the missing file as a close would have discarded a still-unpushed rule; the
correction is to the path, not to the claim.

**Why the anchor is the anchor.** `branch` **and** `carry-over` are the two tokens the rule
cannot be written without — the branch is its subject and the carry-over is the act it mandates —
so neither is a phrasing this filing invented, unlike `decision-branch` or `execution-coverage`,
which are the consumer's own coinages and appear nowhere in core's vocabulary. The predicate is
scoped to §3 because both tokens occur elsewhere in `sprint-review.md` and in 5 and 17 other core
files respectively; a file-level conjunction closes on unrelated prose. The `live` control fires
on the same extraction, so a renamed §3 reports STILL-LIVE rather than closing on nothing.
**Known limit:** if core discharges the case with a *deferral* rather than a *carry-over*, the
receipt reports STILL-LIVE against a shipped fix and must be re-anchored.

Discharges the consumer entry `extensions/steps-domain/sprint-review-push.md` at pinned ledger
line 267, whose live carrier is now
`.claude/skills/ai-dlc/overrides/steps__sprint-review__fix-and-re-validate.md`.


verify: sh s=core/skills/ai-dlc/steps/sprint-review.md; b=$(LC_ALL=C awk '/^### 3\. Fix and Re-Validate/{f=1;next} f&&/^### 4\./{exit} f' "$s"); [ -n "$b" ] || exit 1; grep -qi live <<<"$b" || exit 1; grep -qi branch <<<"$b" && grep -qi carry-over <<<"$b"
## BL-038

**Core's sprint-review §3 lets a "genuinely environmental" integration seam defer with no
downstream obligation, and no step file picks it back up.** `core/skills/ai-dlc/steps/sprint-review.md:96-125`
("### 3. Fix and Re-Validate") carries the Core-path seam non-deferral rule: a *wiring-reachable*
seam on the primary deliverable path MUST NOT be deferred (HARD_BLOCK, Rule 12 Tier 1), and
"Only a genuinely environmental seam MAY defer." The permission is granted and the obligation is
never issued. Measured over that 31-line span: `environmental` = **2**, `carry-over` = **0**.
Control in the same invocation, same file: `carry-over` occurs at `sprint-review.md:21` — the
token is live in this file and absent from this span, so the zero is a placement fact, not a
vocabulary miss. Second control: `carry-over` appears in **12 of 21** core step files and owns a
whole step (`carry-over-evaluation.md`), so nothing about the corpus makes the word unlikely here.

**The filing got its own subject and its anchor wrong, and the correction runs both ways.** It
filed the gap as "upstream carries no equivalent rule" for decision-branch execution coverage and
anchored on `theirs_lacks core/skills/ai-dlc/steps/sprint-review.md "execution-coverage"`. That
hyphenated string occurs **0** times anywhere in `core/` (control: `coverage` = 68 files), and the
one place core spells the concept at all is `core/skills/ai-dlc/extensions/README.md:179`, with a
space, as the worked example of a rule belonging in a consumer's `extensions/` layer. So the
receipt was anchored on a phrasing the filing invented — it would have reported STILL-LIVE against
any fix upstream actually wrote. **Narrower** than filed: core has since grown a rule in this exact
section, so "no equivalent rule" is false. **Wider** than filed: that new rule is what creates the
hole, explicitly and in writing, rather than leaving it unaddressed. A seam classified
*environmental* is routed to deploy-validate, where smoke is the only instrument, and a branch no
organic event triggers is precisely the one smoke does not reach either.

The anchor is on core's own sentence and core's own vocabulary, not on the filing's. Either fix
closes it: `environmental` leaving §3 (the classification is withdrawn) or `carry-over` entering §3
(the deferral acquires an obligation). Both arms were driven on seeded copies and both returned 0;
the copies were asserted to differ from the source in the same invocation before the comparison was
read. `HARD_BLOCK` in the same file is the run control, and the section extraction is asserted
non-empty — a heading rename reports STILL-LIVE rather than closing silently.

Discharges the consumer entry `Decision-branch execution-coverage for sprint-review §3 "Fix and
Re-Validate" (PI-S259-2)` at pinned ledger line 316.


verify: sh F=core/skills/ai-dlc/steps/sprint-review.md; [ "$(grep -cF HARD_BLOCK "$F")" -ge 1 ] || exit 1; S=$(sed -n '/^### 3\. Fix and Re-Validate/,/^### 4\./p' "$F"); [ -n "$S" ] || exit 1; E=$(grep -ci environmental <<<"$S"); C=$(grep -ci carry-over <<<"$S"); [ "$E" -eq 0 ] || [ "$C" -ge 1 ]
## BL-048

**Two of the three dev-role checks this consumer carries have no upstream equivalent, and the
third is already upstream in a stronger form than the consumer's.** Derived per item against
`core/team-roles/dev.md` and `core/skills/ai-dlc/steps/`, with a control in the same invocation
(`AC` as a word over `core/skills/` + `core/team-roles/` = 17 files, so the corpus is live):

- **`LR→AC discriminating-test gate` — ALREADY UPSTREAM, and core is ahead.**
  `core/skills/ai-dlc/steps/stories-test-strategy.md:110` opens
  `**LR→AC discriminating coverage (MANDATORY).**` and `:115-118` carry the degenerate-implementation
  requirement and the per-LR `LR→AC` mapping line. `core/team-roles/dev.md:194-205` carries the
  same discipline as the **Mutation self-check**, with the identical non-discriminating
  vocabulary ("inline reproduction, test-local literal, or mock-only"), and it ships an ENFORCER
  the consumer's version does not have: `scripts/ai-dlc/validate-mutation-red.sh`.
- **`edit-landed git-diff check` — ABSENT.** `grep -c landed core/team-roles/dev.md` = **0**
  (control: `git diff` in the same file = 3, at `:68` for atomic refactor commits and `:154` for
  `git diff --staged --stat` scope verification — neither is a check that an edit already
  landed before re-issuing it).
- **`N≥10 live timing-ordering harness` — ABSENT.** `grep -c ordering core/team-roles/dev.md` =
  **0**; the single `timing` hit at `:176` is the words "benchmark timings" inside the
  Metric-reproduction clause, which is the clause immediately AFTER the consumer's
  timing-ordering block, so core adopted the neighbour and not this one.

**The filing overstates itself by one third and it is an inventory line, not a defect report.**
It sits under `## push_candidate: true extensions (by source)` at pinned ledger line 208 with no
`PC-` id, no receipt, no stated defect and no measurement — three feature names on one line. The
correction is narrowing: one of the three is stale and the upstream version is the stronger one,
which is the direction that matters, because pushing it would replace an enforced check with an
unenforced restatement.

This is not a refusal: no deliberate decision against either surviving item is recorded.
`grep -niE 'PI-S271-5|edit-landed|timing-dependent-ordering'` over `CHANGELOG.md` and `docs/`
returns **0**, and the CHANGELOG names no `PI-S` id at all (control: 0), so there is no
settled-decision text to defer to.

The receipt is `manual` and that is a real limitation, not a convenience. Both surviving items
are prose checklist bullets in a role file: there is no program to drive, and every substring
available — "edit-landed", "ordering", "N≥10" — is a phrasing THIS FILING INVENTED rather than
one core uses, which is the anchor failure this program has already shipped once. The
hand-review predicate is exact: does `core/team-roles/dev.md` carry a gate-1 checklist item that
(a) requires verifying whether an intended edit is already present in the working tree before
re-issuing it, and (b) requires repeated live/near-live runs as evidence for an AC whose
correctness depends on wall-clock ordering of concurrent processes.

Discharges the consumer entry `extensions/roles/dev-push.md` at pinned ledger line 276.


verify: manual
## BL-066 — the `named_absorbed` half landed at v0.387.0; the SIBLING half did not, and the release notes say it did

**TRIAGED AT BATCH 10: FOUR OF THE FIVE CLAIMS ARE ABSORBED, THE SIBLING CLAIM SURVIVES, AND
THIS ENTRY STAYS OPEN ON THAT CLAIM ALONE.** Two verifiers attacked the proposed close
independently, agreed on every measurement, and split on scope; the entry text below decided
it. `34c77736` (`v0.387.0`) genuinely fixed `named_absorbed()` — it removed 3 `tail -1` lines
and 3 `VERSION` reads, `na_v` now occurs **0** times in tracked code (controls in the same
invocation: `na_c` 3, `na_o` 2, `na_h` 2), the three surviving `tail -1` occurrences at `:393`,
`:457` and `:473` all classify as COMMENT against a control returning CODE at `:254-256`, and
driving the real function returns `<newest-sha> <oldest-sha> <n> <how>` with no version at all.
The consumer's installed copy is byte-identical. So the version-into-a-permanent-annotation harm
is closed.

**What survives is the SIBLING paragraph below, and it survives on its own words.** That
paragraph names two mechanisms (`| tail -1`, the `VERSION` read) and a distinct harm: *"its
output is the sha an operator is told to go and read. A fix keyed only on `named_absorbed`
leaves that half emitting the same wrong commit."* The mechanisms are gone; **the harm is not**.
`named_ambiguous()` at `:537-541` still resolves the message-grep to a set and emits ONE commit
— `_c="${_hits%%\n*}"`, now the NEWEST rather than the oldest — with no commit count and no
range, and its second field is the number of ledger ENTRIES sharing the prefix, not the number
of citing commits. Driven against a synthetic upstream where THREE commits cite the prefix, the
row emits `a6b80ae 2`, and `a6b80ae` is the ledger-drain docs commit — precisely the
"cited it while closing the ledger" confusion this entry names. Control in the same invocation:
with a one-entry ledger the function returns empty, so the arm discriminates.

**Two things make this a defect rather than an asymmetry worth noting.** `named_absorbed`'s own
shipped header at `:472` states the remedy standard — *"reports WHAT IT KNOWS — how many commits
name the id, and the two ends of the range — and stops electing one of them"* — and the sibling
did not receive it. And **`v0.387.0`'s CHANGELOG asserts *"Both name joins now report what they
know … and elect none of them"*, which is false as measured.** Nothing guards it:
`core/fixtures/ledger-reverify/run.sh:866-890` carries three `NAMED-UPSTREAM-AMBIGUOUS` arms and
none asserts a commit count or a range (control: a bogus token greps 0 in that file while
`NAMED-UPSTREAM` greps 18).

**THE RECEIPT BELOW IS DEAD AND MUST BE REPLACED, NOT RE-ANCHORED.** It exits 9 because
`sed -n "/^named_absorbed() {/,/^}/p"` truncates at the bare `}"` at `:504`, and repairing the
extraction does not rescue it — the assertion tests `$1 = "0.3.0"` and field 1 is now a short
sha, so a repaired receipt exits 1 against the *correct* fix and can never go green. That is the
trap this entry's own "Why this receipt" paragraph says an earlier draft was rewritten to avoid.
The replacement should assert that the `NAMED-UPSTREAM-AMBIGUOUS` row names ≥2 commits when ≥2
cite the prefix. Filed as evidence under `BL-089`, which this widens.

**`named_absorbed()` joins on the OLDEST commit whose MESSAGE mentions the id, which is not the
commit that absorbed the entry, and the version it reads there is interpolated into a permanent
paste-ready annotation.** `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402` is
`git log -F --grep="$_id" --format=%H "$THEIRS" | tail -1` — newest-first output, so the last line
is the FIRST commit whose message contains the id. `:427` then reads `VERSION` at that commit, and
`:848` interpolates the result into the row's instruction to the operator:
`**ADOPTED UPSTREAM (v$na_v, verified <date>)**`. That annotation is the form `ledger-rotate.sh`
keys on to archive the entry, so a wrong version here is written into the consumer's ledger by hand
and never re-derived.

**The join key is the defect, not the `tail`.** The comment at `:338-341` defends `tail -1` over
`--reverse | head -1` on SIGPIPE grounds and states the premise in as many words — *"the last line
is the FIRST commit to name the id"*. Naming is not absorbing. The two are not the same question,
and nothing between the grep and the `VERSION` read distinguishes them. This is the
`receipt_absent_subjects` "reads vs mentions" class one level along: there, a receipt path a file
MENTIONS was counted as one it READS; here, a commit message that MENTIONS an id is counted as the
commit that landed it. The SIGPIPE argument is orthogonal and does not block a fix — reading the log
into a variable and taking its first line abandons no pipe.

**Measured against this repo's own history, over the 29 `PC-` ids cited in `e939a92`'s message.**
For each id, `git log -F --grep=<id> --format=%H HEAD | tail -1`, `VERSION` read at that commit,
joined to `docs/reviews/graph-ledger-adjudication-data/final-disposition.tsv` on col2 with the
version parsed out of col3's `ALREADY-FIXED-v<X>`:

- **20 of 29 resolve to `e939a92` itself** and would be annotated with that release's version.
- **9 resolve to older commits.**
- **24 of the 29 carry a literal `ALREADY-FIXED-v<X>` verdict.** Of those, **2 agree** —
  `8dc52be`/`0.247.0` and `1537e4c`/`0.372.0` — and **22 disagree**.
- **A 25th is comparable and a `v`-anchored regex cannot see it.** The remaining five are 2
  `FALSIFIED`, 2 `DUPLICATE-OF` and one `ALREADY-FIXED-93e05d3` — an `ALREADY-FIXED` naming a SHA
  rather than a version. It is a real absorption claim, so it belongs in the comparable set:
  `93e05d3` CHANGES `VERSION` itself, `0.101.0` -> `0.102.0`, so it IS its own release and shipped
  at **`0.102.0`**, while the join reports **`0.373.0`**, resolving to `e939a92`. **So the split is
  25 comparable, 2 agreeing, 23 disagreeing**, and only the four refutation/duplicate rows name no
  absorbing release at all. Control in the same invocation: an impossible id resolves to 0 commits.
- **BOTH SHAPES EXIST IN THIS HISTORY AND ASSUMING EITHER IS AN ERROR.** A fix commit may land
  while `VERSION` still holds the previous number, with the bump arriving later in a separate
  release commit — that is `941021d`, the case the consumer's own `PC-S334` filing is about. Or the
  fix commit may BE the release, bumping `VERSION` in the same commit — that is `93e05d3`. Resolving
  a sha to its shipping release therefore takes the earliest `VERSION`-changing commit **at or
  after** it, inclusive of the commit itself.
- **THE SHA FORM IS THE SHAPE A JOIN SILENTLY MISBUCKETS, AND THIS ENTRY DEMONSTRATED IT TWICE.**
  A first derivation put the row in a bucket labelled "no comparable verdict" — not because it lacks
  one, but because the parser's grammar was `ALREADY-FIXED-v[0-9]` and the row spells its version as
  a commit. A zero over the wrong grammar reads exactly like an absence, and here it read as a row
  with nothing to say while it was in fact the largest single disagreement in the set.
- **3 of the 9 older resolutions are upstream's own documentation commits**, whose diffs are
  docs-only and which merely mention the id: `2bc7aa4` (`docs(plan)`, 1 file),
  `c9a4500` (`docs(reviews)`, 4 files), `40770c3` (`docs(reviews)`, 6 files).
- A fourth, `5b5b95c`, is worse than a docs mention: it is a ledger-drain release touching 23
  `core/` files, and the entry it is attributed to —
  `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES` — is adjudicated **FALSIFIED**. The
  function would propose an `ADOPTED UPSTREAM` annotation for an entry that was never a defect.

Control in the same invocation: the impossible id `PC-S999-IMPOSSIBLE-NEVER` resolves to **0**
commits while `PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE-FOR-A-STALLED-TERMINAL-PASS` resolves to
**2**, so the search runs and discriminates.

**This repo's own instruction produced the 20-row case.** `docs/plans/graph-ledger-full-drain.md:49`
directs that *"the id goes in the RELEASE COMMIT MESSAGE, verbatim, for every closed entry"*. That
correction is right for coverage and it is exactly what makes an unqualified message-grep resolve to
the release commit — the id is now guaranteed to appear in a commit whose relationship to the fix is
"cited it while closing the ledger", which the join cannot tell apart from "landed it".

**A SIBLING INSTANCE, SAME IDIOM, SAME FILE.** `named_ambiguous()` (`:433`) runs the same
`| tail -1` at `:453` and reads `VERSION` at `:455`, and its output is the sha an operator is told to
go and read. A fix keyed only on `named_absorbed` leaves that half emitting the same wrong commit.
The prefix-fallback arm inside `named_absorbed` at `:423` is a third site of the same idiom.

**NOT the same defect as `absorbed_at()`.** `absorbed_at()` (`:267`, `VERSION` at `:271`) uses a
content pickaxe (`log -S"$2"`) bounded to `BASE..THEIRS` with `--reverse | head -1`, so it already
joins on a diff rather than on a message; its filed problem is which version blob it reads at the
commit it found. Filed by the consumer as
`PC-S334-ABSORBED-AT-READS-THE-VERSION-BLOB-AT-THE-FIX-COMMIT`. Cross-referenced, not merged — the
two need different fixes and a joint one would satisfy neither join.

**Why this receipt and why it is behavioural.** A substring anchor is unusable: the fix will quote
the `tail -1` wording back inside the comment recording what it replaced, exactly as `:338-341`
already quotes the reasoning it is defending. The receipt instead `sed`-extracts the shipping
`named_absorbed()` body, evals it against a three-commit synthetic upstream in which a `docs(plan)`
commit at `0.2.0` MENTIONS the id and touches no subject, and the `fix:` commit at `0.3.0` absorbs it
— and asserts the returned version is the absorbing one. Its four sanity arms exit 9 (which reverify
reports as STILL-LIVE, the safe direction): the extraction produced a function, the two commits'
`VERSION` blobs genuinely differ, the mentioning commit really mentions the id, and the mentioning
commit does NOT touch the subject while the absorbing commit does. An earlier draft guarded on the
extracted text containing `tail -1`, which would have exited 9 on precisely the fix — a receipt that
cannot go green. Satisfiability demonstrated against a mutant whose two sides were asserted to
differ: shipping returns `0.2.0 <sha> slug` and exits **1**; the same receipt against a copy with
`| tail -1` changed to `| head -1` in that arm returns `0.3.0` and exits **0**.

Cross-references the consumer entry `PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION`,
filed by the graph consumer session. That id appears in **0** commits of this repo's history
(control in the same invocation: `PC-S303` appears in **8**), so nothing upstream can be read as
having answered it.

verify: sh L=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; f=$(sed -n "/^named_absorbed() {/,/^}/p" "$L"); case "$f" in *"named_absorbed()"*) : ;; *) exit 9 ;; esac; d=$(mktemp -d); u="$d/u"; mkdir -p "$u/docs"; git init -q "$u"; git -C "$u" config user.email a@b; git -C "$u" config user.name a; printf "0.1.0\n" > "$u/VERSION"; printf "x\n" > "$u/subj"; printf "p\n" > "$u/docs/plan.md"; git -C "$u" add -A; git -C "$u" commit -q -m "chore: seed"; printf "0.2.0\n" > "$u/VERSION"; printf "pp\n" > "$u/docs/plan.md"; git -C "$u" add -A; git -C "$u" commit -q -m "docs(plan): a handoff that MENTIONS PC-S999-PROBE-SLUG and touches no subject"; printf "0.3.0\n" > "$u/VERSION"; printf "fixed\n" > "$u/subj"; git -C "$u" add -A; git -C "$u" commit -q -m "fix: absorb PC-S999-PROBE-SLUG"; o=$(git -C "$u" show HEAD~1:VERSION); n=$(git -C "$u" show HEAD:VERSION); [ "$o" != "$n" ] || { rm -rf "$d"; exit 9; }; case "$(git -C "$u" log -1 --format=%B HEAD~1)" in *PC-S999-PROBE-SLUG*) : ;; *) rm -rf "$d"; exit 9 ;; esac; case "$(git -C "$u" show HEAD~1 --format= --name-only)" in *subj*) rm -rf "$d"; exit 9 ;; esac; case "$(git -C "$u" show HEAD --format= --name-only)" in *subj*) : ;; *) rm -rf "$d"; exit 9 ;; esac; r=$(DIST="$u" THEIRS=HEAD bash -c "$f; prefix_entry_count(){ echo 0; }; named_absorbed PC-S999-PROBE-SLUG"); rm -rf "$d"; [ -n "$r" ] || exit 9; [ "$(printf "%s" "$r" | awk "{print \$1}")" = "0.3.0" ]


## BL-067

**RE-SCORED AT v0.453.0. THE DEFECT SURVIVES, ITS COST CLAUSE HAS EXPIRED, AND ITS OWN REMEDY IS
UNSHIPPABLE. The entry is kept whole; the receipt below is REPLACED because the old one CERTIFIED
that remedy.** Which half died is the part that stops the next reader repeating this, so all four
claims are scored rather than the entry re-filed.

*Claim 1 — the field is declared, schema'd, printed, and consumed by nothing.* **SURVIVES.** The
three occurrences in `audit-layer-debt.sh` are unchanged, and nothing else reads the value.

*Claim 2 — "six of this consumer's sixteen OPEN debts" name a command, and running it made them
due silently.* **EXPIRED.** Re-derived against the reference register (297 rows, up from 213): the
six `migrate-artifact-paths.sh --apply` debts are **6 declared and 0 still OPEN** — they were
discharged, and by the same six closes that produced `BL-069`'s population. Control in the same
invocation: an impossible `closes_when` token returns 0. **Of the 16 OPEN debts today, ZERO name a
command to run.** The entry's cost paragraph therefore describes a state the only register that
exists no longer holds.

*Claim 3 — the remedy is a `TRIGGERED` list separating debts whose precondition has been met.*
**UNSHIPPABLE AS SPECIFIED, and this was established by BUILDING it, not by reading it.** The
entry's own satisfiability note describes the remedy as one line matching a `.sh` token out of
`closes_when`. Built exactly so, it emits **3 `DUE-AFTER:` rows on the live register and all three
are FALSE**: `validate-gate-manifest.sh` twice, out of *"validate-gate-manifest.sh reports 914
resolving to a gate-type set that includes retro"* — a CONDITION about a script's output, not a
command anyone runs to discharge — and `validate-mutation-red.sh`, out of *"so the forked copy
stops shadowing core's validate-mutation-red.sh"*, where the script is a NOUN. A false-positive
rate of 3 of 3 is a wrong answer delivered confidently to every consumer.

*Claim 4 — the receipt is a differential and its stated limit is a flag-gated fix.* **REFUTED, and
worse than its stated limit.** The remedy above **satisfies the old receipt at exit 0.** So the
receipt certified the very implementation that is 3/3 false. That is not the limit the entry
declares; it is the receipt accepting a regression.

**NO REPLACEMENT FIX IS SHIPPED, because every derivable signal is zero or false on the only
register that exists** — the `.sh` extractor is 3/3 false; an `OWED-`id join over `closes_when`
finds 3, all naming their own debt and **0 dangling**; and every one of the 16 OPEN debts already
carries a non-empty `closes_when`, so an absence check finds 0. A check that cannot fire reads
exactly like one that passed, so none was built. **What a future fix needs is a population, and
this entry is now the record that there is not one yet.**

**THE REPLACEMENT RECEIPT REJECTS THE FILED REMEDY BY NAME.** It seeds three OPEN debts in ONE
register so the negative sits beside the offender in the same run: `OWED-PROBE-A`, whose
`closes_when` names its own id; `OWED-PROBE-B`, carrying the live register's own
`validate-gate-manifest.sh` string verbatim; and `OWED-PROBE-C` as a bound so B's block is
terminated. Sanity arms exit 9 — the script must exist, the run must exit 0, and all three ids
must appear, which asserts the run got deep enough for a fix to be SITED. It then exits 1 on any
output naming `validate-gate-manifest.sh` outside the `closes when:` echo, which is the sole
discriminator against the filed remedy, and finally compares A's and B's rendered blocks **with
the debt id normalised out**, so a fix siting its output on the header line counts equally with
one siting it in the body. Scored against four implementations: shipping **1**, the filed remedy
**1**, a correct fix **0**, and a SECOND SPELLING of that correct fix **0**. The id normalisation
is there because the first draft scored the second spelling as **1** — it keyed on WHERE the fix
put its output, which is the "a receipt rejecting a competent author's other phrasing" failure.

**IT ERASES THE FIELD'S VALUE RATHER THAN STRIPPING A LABELLED LINE.** The first draft filtered
on the literal label `closes when:`, and a one-token relabel to `closes-when:` defeats that
filter and closes the entry while parsing nothing at all — the strip was keyed on a string the
fix under test is free to rename. Substituting the VALUE for a fixed token is invariant under
any relabel.

**IT SEEDS TWO PREDICATE-SHAPED ROWS AND REQUIRES THEM TO RENDER ALIKE, and that arm exists
because the version of this entry merged at `v0.453.0` CLAIMED A SCORE IT DID NOT HAVE.** That
revision said the receipt accepted 2 and rejected 5. **Measured against a wider candidate set it
accepted SEVEN.** Probe A and probe B differed in length, digit content, vocabulary and
self-reference — not solely in whether a command is named — so **any non-constant function of the
field's bytes passed**: its length, an md5 of it, whether it contains a digit, its last word.
Each reads `closes_when` and joins it to nothing, which is the defect itself. **The score was
right about the mutants it was run on and the mutant set was too narrow, which is the
"count what a receipt ACCEPTS" failure one level up — I counted acceptances over a set I chose.**

The repair is a fourth row, not another arm. `OWED-PROBE-D` carries a SECOND predicate-shaped
`closes_when` — different bytes, same kind — and the receipt requires B and D to render
IDENTICALLY before it reads A against B. A function of the bytes cannot satisfy that, because B
and D differ in bytes; only a fix that classifies by KIND can. Re-scored over eleven
implementations: **ACCEPTS 3, REJECTS 8.** Rejected are shipping, the filed remedy, the relabel,
a deleted printer, a re-echo under a new label, and four byte-functions. Accepted are the correct
fix, its second spelling sited on the header line, and a THIRD spelling that renders the same
self-reference join as a boolean — that last one is a correct implementation, not a leak.

**ONE HOLE IS KNOWN AND LEFT OPEN, STATED HERE RATHER THAN HIDDEN BEHIND THE SCORE.** The same
hand showed that an implementation gated on `len(rows)` satisfies any receipt whose register has
a fixed row count while leaving the report byte-identical on a real one. This receipt seeds three
rows, so a mutant keyed on `len(rows)==3` would pass it. **No receipt over a fixed seed can close
that**, and the durable guard is the fixture rather than the receipt — which is why
`core/fixtures/layer-debt-due-and-discharge` exists and why its DISARM mutant matters more than
this line does. A receipt is a tripwire against a false close; it is not the proof.

**`closes_when` names the command that discharges a layer debt, and nothing in the tree joins the
two — so running the named command clears the debt in fact and announces nothing.**
`core/scripts/audit-layer-debt.sh:108` carries the field into the report dict and `:215-216` prints
it verbatim (`print("      closes when: %s" % d["closes_when"])`). Those, plus the dict key itself,
are all **3** occurrences in that file. The value is free prose written by an adjudicator, and no
reader parses it.

**Declared and produced, but consumed by nothing.** `core/schemas/layer-adjudication-register.json:72`
declares `closes_when` as an optional property of `owed` (`required` is `["id","what"]`);
`core/skills/ai-dlc-update/SKILL.md:1242` instructs the adjudicator to write it and `:1251` shows an
example. The only other occurrences in the tracked tree are a seed row at
`core/fixtures/layer-debt-ledger/run.sh:55` and one CHANGELOG line — and that fixture has **0** hits
for the printed form `closes when` against **18** for `assert`/`expect`, so the field's rendering is
seeded but never asserted. The field has a producer, a schema, a printer, and no consumer.

**The command the values actually name has zero awareness of them.**
`core/scripts/migrate-artifact-paths.sh` has **0** hits for
`closes_when|layer-debt|audit-layer-debt`; positive control in the same invocation, `strip_token`
returns **3** in that same file, so the grep reaches the file and discriminates.

**Measured on the reference consumer's register**, `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`,
read out of the consumer tree without writing to it: 207 rows, **24** `owed` objects, **0** ids
appearing in any row's `closes_owed` — so all 24 are OPEN and none has ever been recorded as paid.
**6 of the 24 carry the identical `closes_when` value** *"immediately after
`scripts/ai-dlc/migrate-artifact-paths.sh --apply` completes"*. That consumer ran exactly that
command to clear an unrelated pre-push blocker; all six came due and nothing announced it. They were
found only because a session ran the debt audit and read the strings by hand. Control in the same
invocation: **0** open debts match the impossible token `zzz-no-such-cmd`.

**Tier: DEFECT, not BLOCKER.** No answer is wrong — the debts stay visible as OPEN, and
`audit-layer-debt.sh` is report-only by design (`exit 0` on findings). What is lost is the reminder:
the one moment at which a debt becomes payable passes silently, and the register's own `closes_owed`
half stays empty because nobody is told to fill it.

**Why the receipt is a differential and what its limit is.** There is no substring a fix must
contain, and anchoring on `closes_when` itself would be satisfied by the comment a fix writes about
the field. The receipt instead drives the shipping script twice over the SAME register path, with
one row whose `closes_when` names a command and one whose `closes_when` names no command at all,
strips the echoed `closes when:` lines from both outputs, and asserts what remains still differs —
i.e. that something other than the echo depends on the field's content. Sanity arms exit 9: both
runs must exit 0, both must name the probe id, the two register bodies must differ, and the two RAW
outputs must differ. **The first draft of this receipt FALSE-CLOSED** — it wrote the two registers to
two different temp paths, and the report's header line prints `register=%s`, so the outputs differed
on the path alone and the receipt reported the fix present against the shipping code. Re-run over
one path rewritten between the two runs, shipping exits **1**. Satisfiability demonstrated against a
mutant asserted to differ from shipping, which adds one line matching a `.sh` token out of
`closes_when` and printing `DUE-AFTER:` or `(no command named)`: that copy exits **0**. The limit,
stated rather than hidden: a fix that puts the join behind a new flag and leaves the default report
byte-identical would leave this STILL-LIVE — the safe direction, but not a close.

Found by the graph consumer session. Cross-references the consumer entry
`PC-S334-CLOSES-WHEN-NAMES-A-COMMAND-AND-NOTHING-JOINS-THE-TWO`.

verify: sh S=core/scripts/audit-layer-debt.sh; [ -f "$S" ] || exit 9; d=$(mktemp -d) || exit 9; A="a later register row for this entry names OWED-PROBE-A in closes_owed"; B="validate-gate-manifest.sh reports 914 resolving to a gate-type set that includes retro"; D="before the next pull, so the forked copy stops shadowing core validate-mutation-red.sh guidance"; [ "$A" != "$B" ] && [ "$B" != "$D" ] || { rm -rf "$d"; exit 9; }; h="{\"clause\":\"LC-E1\",\"entry\":\"extensions/p.md\",\"subject_digest\":\"d0\",\"verdict\":\"still-additive\",\"recorded_utc\":\"1970-01-01T00:00:00Z\",\"reason\":\"probe row\",\"owed\":{\"what\":\"same what\","; { printf "%s\"id\":\"OWED-PROBE-A\",\"closes_when\":\"%s\"}}\n" "$h" "$A"; printf "%s\"id\":\"OWED-PROBE-B\",\"closes_when\":\"%s\"}}\n" "$h" "$B"; printf "%s\"id\":\"OWED-PROBE-D\",\"closes_when\":\"%s\"}}\n" "$h" "$D"; printf "%s\"id\":\"OWED-PROBE-E\"}}\n" "$h"; } > "$d/r.jsonl"; o=$(bash "$S" --register "$d/r.jsonl" 2>/dev/null); rc=$?; rm -rf "$d"; [ "$rc" = 0 ] || exit 9; for i in A B D E; do case "$o" in *OWED-PROBE-$i*) : ;; *) exit 9 ;; esac; done; e=$(printf "%s\n" "$o" | sed "s|$A|<CW>|g; s|$B|<CW>|g; s|$D|<CW>|g"); case "$e" in *validate-gate-manifest.sh*|*validate-mutation-red.sh*) exit 1 ;; esac; blk() { printf "%s\n" "$e" | sed -n "/OWED-PROBE-$1/,/OWED-PROBE-$2/p" | sed "\$d" | sed "s/OWED-PROBE-$1/OWED-PROBE-X/g"; }; a=$(blk A B); b=$(blk B D); q=$(blk D E); [ -n "$a" ] && [ -n "$b" ] && [ -n "$q" ] || exit 9; [ "$b" = "$q" ] || exit 1; [ "$a" != "$b" ]

## BL-071

**`ledger-rotate.sh`'s split-refusal can still be silenced by a body line that merely MENTIONS the
annotation form, and the two inputs that decide it are not distinguishable by any signal the
current parse computes.** `ledger-rotate.sh:196` reads `if ($0 ~ /ADOPTED UPSTREAM/ && susp_at)
susp_closed = 1` — unanchored, so a suspect whose body says "Annotate it `ADOPTED UPSTREAM
(vX.Y.Z, verified <date>)` once the grep is non-zero" scores as carrying its own close and
suppresses the refusal. The refusal exists because rotating a split entry strands its receipt in
the live ledger under no heading, which `ledger-rotate.sh:104-106` calls unrecoverable to skip.

**The obvious fix was BUILT AND MEASURED IN THE RELEASE THAT FILED THIS, AND IT WEDGES ROTATION.**
Routing this predicate through `ledger_close_awk()` — the anchored grammar lifted from
`ledger-reverify.sh`, which the same release routes three other drifted predicates through —
turns `core/fixtures/ledger-rotate/run.sh`'s own `fp-quotes` false-positive case into a refusal.
Driven on the exact ledger that arm builds, shipping rotator, sides asserted byte-different first:
unanchored **rc=0, 0 refusals**; anchored **rc=1, `REFUSING to rotate`**. A refusal writes nothing,
so that is a real entry blocked from rotating forever.

**The reason one predicate cannot serve both, which is the part worth carrying.** The stuck-set
rule and this one ask a similar question and FAIL IN OPPOSITE DIRECTIONS. The stuck rule makes a
CLAIM — these are the entries `ledger-reverify.sh` skips — so a loose form states something FALSE
about an open entry, and tightening it is strictly correct. This one SUPPRESSES a refusal, so a
loose form merely lets a split through while a TIGHT form refuses a real entry and writes nothing.

**Why there is no `sh` receipt, stated rather than worked around.** The two cases a fix must
separate are, on today's signals, the same shape: both are a bold bullet inside a closed entry,
both carry a receipt below them (`susp_hasv`), and the real-entry case does not even carry the
trailing colon (`susp_colon`) that would mark an annotation lead-in. The ONLY thing separating
them in the current parse is the quotation itself — the real entry quotes the annotation form
because it is discussing it, and a genuine lead-in does not quote, it IS one. That is an
accidental signal, not a designed one, and a fix needs a signal the parse does not currently
compute. A receipt asserting both arms would therefore be UNSATISFIABLE against every predicate
available today, and shipping one would be a standard nobody can meet.

The two cases a fix must satisfy simultaneously, so the next session does not have to rederive
them: `core/fixtures/ledger-rotate/run.sh`'s `splitter` seed must be REFUSED, and its `fp-quotes`
seed must NOT be. Both already exist in that fixture and both are already asserted.

Found while remediating `BL-035`, by that fixture, against its own author.

verify: manual

## BL-077

**`validate-steering-budget.sh` refuses to run without a caller-supplied corpus, so the
derivation of "this session's transcript" is retyped by the MODEL in prose at
`core/skills/ai-dlc/steps/gate-validation.md:1665` and by hand in `steps/retro.md:614`, where
nothing can check either one.** With no corpus flag the script exits 1 at
`core/scripts/validate-steering-budget.sh:189` with `FAIL: pass --transcript PATH or --dir PATH`,
so every caller must construct the path itself. The gate's construction is
`T=$(ls -t ~/.claude/projects/"$(pwd | sed 's|/|-|g')"/*.jsonl 2>/dev/null | head -1)` — a model
transcription sitting in a step file, which is `.claude/rules/mechanism-design.md`'s own named
failure mode ("a skill that ends in a manual transcription step ends in a place where the
transcription silently stops happening"). That rule's remedy shape is to move the derivation
INTO the tool so the prose carries no transcription at all. Split from `BL-059`, whose two-part
remedy this is the first half of; the second half — naming the corpus that was read — shipped on
this branch and is what makes a wrong derivation VISIBLE rather than impossible.

**The retyped derivation is wrong in two ways and currently right by luck, and both halves must
be stated in the same breath.** Measured on the live tree: the operator's projects directory holds
**9** project slug directories and the one for this repo holds **163** top-level `*.jsonl` session files — down from **173** counted forty
minutes earlier in the same session, same glob, so the corpus `ls -t` reads is not merely
contended but actively PRUNED underneath it, of which **1** was modified in the last 60 minutes, **4** in the last 24 hours and **26** in
the last 7 days; `ls -t … | head -1` therefore picks **this session's file, correctly, right now**
— the race is LATENT, not a live miswitness, and needs a second concurrent session on the same
project to fire. The slug rule is the same shape: `sed 's|/|-|g'` and the harness's own `/` **and**
`.` collapse agree byte-for-byte on a path with no dot in it and DIVERGE on any checkout that
carries one — control, computed both ways in one invocation: `/Users/n8/git/my.app` gives
`-Users-n8-git-my.app` from the `sed` form against `-Users-n8-git-my-app` from the collapse. So
this repo cannot observe the bug, and a consumer whose checkout path holds a dot gets a directory
that does not exist, a `head -1` of nothing, and an empty `$T` that the gate's own SKIP branch then
reads as "no transcript (CI, a non-Claude-Code runner)". **A misderived corpus fails as a
legitimate SKIP**, which is the shape this repo calls a check that cannot fire.

**The consequence is not symmetric, and `--cite` is the half that matters.** `--cite` is THE
genuine-operator predicate — the convergence validator, the escalation gate and
`core/hooks/ai-dlc-gate-remediation-guard.sh` all delegate "a real human said this" to it, and the
guard is a `PreToolUse` hook that DENIES tool calls on the answer. A wrong corpus there makes a
genuine operator authorization unverifiable (NOMATCH, the record stops counting, `--cycle-state`
regresses to STALLED, every dispatch denied — the deadlock those files' own headers record), and
the inverse direction is worse in kind: a corpus WIDER than the session makes a citation verifiable
that the operator never made in the relevant sprint. **Frequency is UNMEASURED and it is
measurable** — every gate run writes `steering_violations:` into the gate log and the `--cite`
calls are hook-logged, so a consumer's committed gate-log archive would answer how often the
derived corpus was empty. That measurement was not taken here, and not taking it is not a limit on
the fix.

**Twelve call sites, and a default change breaks none of them, because every one passes an explicit
corpus flag today.** Derived over `core/` and `scripts/`, with an impossible flag returning rc 1 in
the same invocation so the scan is known to discriminate: seven fixture invocations across
`askuserquestion-citation`, `command-args-citation` and `check-25-steering-conduct`; the three
delegating callers; and the two prose sites. **`--transcript` and `--dir` MUST stay explicit
overrides** — a fix that makes either refuse a caller-supplied path breaks all ten mechanical sites
at once and is a regression, not a fix. The receipt asserts the override arms FIRST and exits 9 if
they have stopped discriminating, so a run that measured nothing reports STILL-LIVE rather than
closing.

**The three delegating callers are why this is not a one-line default, and why it did not ride
along with `BL-059`.** Each has an explicit "no corpus" branch that fails OPEN in hook mode
(`ADVERSARIAL_CITATION_UNVERIFIABLE`, return 0, never wedge the pipeline) and CLOSED in gate mode.
A derived default silently DELETES that branch: the hook stops failing open and starts adjudicating
against a corpus nobody chose, inside a `PreToolUse` deny path. That is the consumer-visible
behaviour change. **And the default differs by MODE**: those callers prefer the directory precisely
because an authorization OUTLIVES the session that recorded it, so a `--cite` default must be the
slug DIRECTORY while a `--count`/checks-A–D default is the single session FILE. One default for
both modes is wrong in whichever mode it was not written for.

**The environment the derivation reads is not the one first proposed, and three clauses of that
proposal re-derived FALSE.** `CLAUDE_CODE_SESSION_ID` IS present in a Bash-tool child (control: an
all-zeros UUID under the same slug directory is correctly absent). `CLAUDE_PROJECT_DIR` is **UNSET**
in that same child while **70** tracked files reference it — it is a HOOK-environment variable — so
a formula slugging `$CLAUDE_PROJECT_DIR` resolves to a path with an empty component and finds
nothing. The available root is the working directory, and it must be the REPO ROOT resolved by
walking up for `VERSION`, never `$PWD`: run from `core/scripts/`, a `$PWD`-slugged derivation on a
patched copy refused outright, while the same copy from the repo root resolved. Two further facts
belong in the specification rather than in a later session's surprise: **a subagent's Bash child
sees the TEAM session id, not its own**, and subagent transcripts live one level down under a
per-session directory — **13** of them for the session that measured this — invisible both to a
`<slug>/*.jsonl` glob and to the non-recursive directory read at `:427`. The derived corpus is the
LEAD's conduct, which is what Rule 29 asks for; that exclusion should be DECLARED, not discovered.

**The case against, and why it does not block.** The derivation depends on a harness variable with
no published contract, absent for a consumer running the validator from CI, a plain terminal or a
git hook outside the tool, and absent under a sandbox with a different `HOME`. Measured on a
patched copy with `HOME` pointed at an empty `mktemp -d`: it falls back to the existing refusal,
rc 1, byte-identical to today's message. **That is the required shape and it is the specification:
derive-or-fall-back-to-the-current-refusal, never derive-or-fail-differently.** A fix that makes an
underivable environment fail in a NEW way fails closed on every consumer not running Claude Code,
which is the shipping hazard here.

**The receipt anchors on the CONTRACT, not on the mechanism.** Anchoring on the literal
`CLAUDE_CODE_SESSION_ID` would prescribe one implementation and REJECT every other correct
derivation; anchoring on the absence of the `ls -t` line from `gate-validation.md` would CLOSE when
someone deletes the instruction without replacing it, and the receipt never reads that file for
exactly that reason. Instead: a corpus-flagless `--cite` run must name a corpus that EXISTS, is not
a path the receipt supplied, and is not inside the repo; and the same flagless run under a swapped
`HOME` must name something DIFFERENT, which makes a hardcoded constant unconstructible. Both rc 0
and rc 2 are accepted from that arm because **the receipt's own probe token enters the live
transcript the moment anyone runs it** — measured, a token typed literally into a command read
**4** occurrences in the session file while a token assembled at runtime read **0**, so a negative
control against a LIVE transcript is contaminated by the act of running it.

Proven in both directions with the sides asserted to differ first: **1** against the current tree,
and **0** against a patched copy carrying a derivation that never mentions the environment variable
at all, which is the property the receipt is meant to have. Killed: a hardcoded constant corpus, by
the `HOME`-swap arm; a derivation that also makes `--transcript` refuse a caller path, at exit 9 by
the override control; and a doc-only change, which moves nothing.

**Two constraints on the fix that the receipt imposes, stated rather than left to be discovered.**
It does not fire where no corpus is resolvable at all, which is the safe direction. And it requires
a derivation NOT rooted at the SCRIPT's own location: the receipt exercises the validator as a
COPY, so a `dirname "$0"` walk-up for a repo marker finds nothing above a `core/scripts` copy,
never derives, and scores a fix that is correct in the tree as STILL-LIVE. Measured on one patch
with a single expression changed — script-rooted **1**, working-directory-rooted **0**. That costs
nothing, because the rooting the receipt demands is the correct one on the merits: globbing
`$HOME/.claude/projects/*/<session-id>.jsonl` computes NO slug, sorts nothing, and is invariant to
both the working directory and the install layout that puts this file at `core/scripts/` here and
at `scripts/ai-dlc/` in a consumer — so it retires the `.`-versus-`/` slug bug and the `ls -t` race
in the same stroke.

**The extraction covers all THREE `--cite` diagnostics, and keyed on one of them it rejected a
correct fix.** Proven rather than reasoned: a seeded `HOME` whose slug directory holds a single
UNPARSEABLE transcript drives the zero-records branch, where a `sed` keyed on the `cite: scanned`
wording lifts an empty string and exits at the non-empty guard — a permanent false STILL-LIVE for
any consumer whose corpus happens to be unparseable. The shipped form lifts the ` from ` suffix
common to all three.


verify: sh V=core/scripts/validate-steering-budget.sh; [ -r "$V" ] || exit 9; DA=$(mktemp -d); DB=$(mktemp -d); [ "$DA" != "$DB" ] || exit 9; J='{"type":"user","message":{"role":"user","content":"probe"}}'; printf '%s\n' "$J" > "$DA/alpha.jsonl"; printf '%s\n' "$J" > "$DB/alpha.jsonl"; OA=$(bash "$V" --transcript "$DA/alpha.jsonl" 2>&1); RA=$?; OB=$(bash "$V" --transcript "$DB/alpha.jsonl" 2>&1); RB=$?; OC=$(bash "$V" --dir "$DA" 2>&1); RC=$?; ON=$(bash "$V" --cite zzzabsentphrasezzz 2>&1); RN=$?; EH=$(mktemp -d); OH=$(HOME="$EH" bash "$V" --cite zzzabsentphrasezzz 2>&1); rm -rf "$DA" "$DB" "$EH"; [ "$RA" = 0 ] && [ "$RB" = 0 ] && [ "$RC" = 0 ] || exit 9; grep -qF "transcripts read" <<<"$OA" || exit 9; [ "$OA" != "$OB" ] || exit 9; grep -qF "$DA/alpha.jsonl" <<<"$OA" && grep -qF "$DB/alpha.jsonl" <<<"$OB" || exit 9; case "$RN" in 0|2) ;; *) exit 1 ;; esac; name(){ L=$(sed -n '/ from /{p;q;}' <<<"$1"); L="${L##* from }"; L="${L%, no genuine operator message carried it}"; printf '%s' "${L%)}"; }; P=$(name "$ON"); [ -n "$P" ] || exit 1; { [ -r "$P" ] || [ -d "$P" ]; } || exit 1; case "$P" in "$PWD"/*|"$PWD") exit 1 ;; esac; Q=$(name "$OH"); [ "$Q" != "$P" ] || exit 1

## BL-082

**On a case-folding filesystem `--strays` reports a declared home as a stray when the caller
spells a path component in a different case, and every remedy that closes it opens a FALSE PASS
on a case-sensitive consumer.** `core/scripts/validate-provenance-block.sh` canonicalises each
candidate through `os.path.realpath`, which resolves symlinks and `..` and does **not** fold
case, so the canonical form keeps the caller's spelling and misses the home. Measured on this
host with the filesystem's behaviour PROBED rather than inferred from the platform name
(`[ -e "$PROJ/DOCS" ]` is true, so the two spellings are one file): `docs/retro/sprint-1.md`
exits **0**, `DOCS/retro/sprint-1.md` — the same file — exits **1** and is reported
`STRAY PARTY-MODE PROVENANCE: DOCS/retro/sprint-1.md`. Control in the same run: a genuine stray
spelled correctly, `server/handler.py`, exits **1**, so the scan fires and the passing arm is not
a dead scan.

**The direction is the safe one and that is why this is filed rather than fixed.** A case variant
cannot turn a non-home into a home — on a folding filesystem the two spellings name the same
directory either way — so there is no false-PASS counterpart to the defect itself. It is noise: a
false STRAY, loud, and the operator fixes it by respelling the argument.

**The obvious remedy is forbidden, and that is the entry's substance.** Case-folding the home
comparison would make `docs/retro/**` match a genuinely DISTINCT `DOCS/retro/` directory on a
case-sensitive filesystem, which is what a consumer's Linux CI runs. That converts a
noise-tier false stray on one platform into a false PASS on the platform that matters — the exact
direction `BL-060` was opened to close, reintroduced by its own cleanup. A per-component
case-canonicalising walk is correct only on the folding filesystem and is wrong to ship as a
general rule. So there is no remedy that is right on both platforms, and the entry exists to stop
the next author reaching for the one that looks obvious.

**It is unreachable in the place it would matter.** On a case-sensitive filesystem `DOCS/retro/`
names nothing, and the explicit-argument existence assert added alongside `BL-060` already
refuses it at exit 2 — which is the correct answer there. So this fires on a developer's macOS
checkout and never in a consumer's CI.

Found by the independent fixture hand for `BL-060` while enumerating sixteen path spellings; the
arm was written, measured, and then deliberately removed rather than left red or closed by
folding, with a comment at its site pointing here. Two spelling classes were enumerated alongside
it and are NOT covered by this entry: hard links, which are not a distinct spelling because a
second link is the same inode with no way for a caller to name it differently, and Unicode
NFC/NFD filename variants, which are constructible on APFS and were deliberately not asserted
because they were not measured.

The receipt drives the shipping validator on both spellings of one file and requires them to
agree, with the genuine-stray control in the same invocation so a disarmed scan cannot satisfy
it. It SKIPs — exit 9, which reverify reports as STILL-LIVE, the safe direction — on a filesystem
that does not fold case, because there the subject does not exist and an arm with no subject must
not report a verdict.


verify: sh V=core/scripts/validate-provenance-block.sh; [ -f "$V" ] || exit 9; R="$PWD"; D=$(mktemp -d); P="$D/proj"; mkdir -p "$P/.claude/schemas" "$P/docs/retro" "$P/server"; cp core/schemas/provenance-block.json "$P/.claude/schemas/" || { rm -rf "$D"; exit 9; }; printf '0.0.0\n' > "$P/VERSION"; python3 -c 'import json,sys;S=json.load(open(sys.argv[1]));e=S["envelope"];b=e["open"]+chr(10)+"skill: "+S["stray_scan"]["party_mode_skills"][0]+chr(10)+"invoked_at: 2026-07-28T09:00:00Z"+chr(10)+"mode: subagent"+chr(10)+e["close"]+chr(10);[open(p,"w").write(b) for p in sys.argv[2:]]' "$P/.claude/schemas/provenance-block.json" "$P/docs/retro/probe.md" "$P/server/stray.md" || { rm -rf "$D"; exit 9; }; [ -e "$P/DOCS" ] || { rm -rf "$D"; exit 9; }; ( cd "$P" && AI_DLC_PROJECT_ROOT="$P" bash "$R/$V" --strays server/stray.md >/dev/null 2>&1 ); c=$?; ( cd "$P" && AI_DLC_PROJECT_ROOT="$P" bash "$R/$V" --strays docs/retro/probe.md >/dev/null 2>&1 ); a=$?; ( cd "$P" && AI_DLC_PROJECT_ROOT="$P" bash "$R/$V" --strays DOCS/retro/probe.md >/dev/null 2>&1 ); b=$?; rm -rf "$D"; [ "$c" = 1 ] || exit 9; [ "$a" = 0 ] || exit 9; [ "$b" = 0 ]
## BL-083

**`verification-discipline.md` prescribes a root marker that does not exist in one of the two
layouts, so a fixture that follows the rule exactly cannot resolve its root on a consumer — and
the fixtures that work do so by the idiom the same rule forbids.** The rule reads *"Resolve the
repo root by walking up for a marker. Never count `..` hops... Walk up for `VERSION`."* Measured:
`scripts/install.sh` into an empty directory produces a tree with **0** `VERSION` files at any
depth, while the distribution root carries one — control in the same invocation, the installed
`tests/fixtures/<name>` directory IS present, so the install ran and the absence is real.

**The correct two-layout resolver already exists in this repo and the rule restates a different
one.** `core/scripts/validate-provenance-block.sh:98` is `ai_dlc_resolve_root()`, which walks up
for `.git` OR `.claude` OR `core/skills/ai-dlc` — a marker set satisfied in BOTH layouts, and
inlined into every validator that needs it with a comment recording why duplication is correct
there. So this is not a missing mechanism; it is a rule that restates one and has drifted from
it, which is the failure `mechanism-design.md` names as *"a rule that RESTATES a mechanism drifts
tighter than the mechanism, invisibly."*

**It was found the way it bites: by a fixture author following the rule.** A new fixture's first
draft walked up for `VERSION`, passed every distribution test, and then failed **all six arms** on
a tree built by `install.sh` with *"no VERSION marker … cannot resolve its own tree"*. It now
walks up for its own home — `<root>/core/fixtures/<name>` or `<root>/tests/fixtures/<name>` — which
is self-anchoring and additionally names the layout it resolved.

**The population is not one file.** **16** of the shipped fixture `run.sh` files test a `/VERSION`
marker (control in the same invocation: **155** carry the token `FIXTURE`, so the grep reaches the
corpus). Most other shipped fixtures resolve by counting three `..` hops — which happens to be
correct in both layouts and is the exact idiom the rule prohibits. So the rule is currently
obeyed by the files that break on a consumer and disobeyed by the files that work, which is the
strongest available evidence that the rule rather than the fixtures is what is wrong.

**Scope note, deliberately narrow.** The 16 is a FLOOR and an approximation: it counts files
testing the literal marker path, and a fixture that resolves correctly by another route may still
appear. The entry's claim is the divergence and the consumer-side zero, both of which are exact;
the 16 is offered as a population size to re-derive, not as a defect count.

**Why the receipt is two-armed.** Two different fixes are legitimate and a one-sided anchor would
go unsatisfiable when the other is taken: `install.sh` could land a root marker in the consumer
layout, or the rule and its followers could move to the marker set the shipped validators already
use. It closes on either, and it drives a real `install.sh` rather than reading the rule's prose,
because text about a program is not the program. It exits 9 — STILL-LIVE, the safe direction — if
the install did not produce a tree, so a broken probe cannot read as a fix.


verify: sh R="$PWD"; D=$(mktemp -d) || exit 9; mkdir -p "$D/_bmad"; bash scripts/install.sh "$D" >/dev/null 2>&1; [ -d "$D/tests/fixtures" ] || { rm -rf "$D"; exit 9; }; n=$(find "$D" -name VERSION -type f 2>/dev/null | wc -l | tr -d ' '); rm -rf "$D"; [ "$n" -gt 0 ] && exit 0; c=$(grep -l '/VERSION"' "$R"/core/fixtures/*/run.sh 2>/dev/null | wc -l | tr -d ' '); k=$(grep -l 'FIXTURE' "$R"/core/fixtures/*/run.sh 2>/dev/null | wc -l | tr -d ' '); [ "$k" -gt 0 ] || exit 9; [ "$c" -eq 0 ]


## BL-103 — an `ai-dlc-*.sh` hook the settings template cannot register withholds `--finish` forever

**`--finish` gates on `WORKLIST settings-merge`, and that row's own prescribed remedy does not
always clear it.** `settings-merge.sh` re-applies the TEMPLATE's owned hook block; it cannot
register a hook the template does not carry. So a consumer holding an `ai-dlc-*.sh` hook that
upstream has retired — or one whose registration the operator declined — gets
`validate-hook-registration.sh` rc 1 on every run, and the finisher withholds with no reachable
exit short of deleting the hook by hand.

Measured against a consumer built from the shipped template with the real validator: clean
consumer rc 0 gives `RESOLVED restamp` and a cleared marker; one unregistered `ai-dlc-*.sh` on
disk gives rc 1, `WORKLIST settings-merge`, `DECISION restamp-withheld` and a present marker;
running the row's own remedy left the validator still at rc 1 and the state unchanged.

Reachable because `apply.sh` emits `DECISION deletion` and never removes a consumer file, so a
hook retired upstream persists across every later pull.

**The population is EMPTY today and that is stated rather than assumed**: the reference consumer
carries 19 hooks and registers 19, validator rc 0, and `git log -p templates/settings.json.template`
shows zero genuinely retired hook names — the one candidate on a `-` line is still in the current
template, a moved line. A loaded gun, not live fire.

Tiered **DEFECT**. It wedges a consumer's push with no in-band exit, but nothing reaches the
state today.

Found by an adversarial pass on `v0.426.0`. Not a `PC-` candidate, so it ranks below the
PC-backed set.

verify: sh s=core/skills/ai-dlc-update/reconcile/settings-merge.sh; a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$s" ] && [ -f "$a" ] || exit 9; grep -q 'say WORKLIST settings-merge' "$a" || exit 9; grep -q 'worklist_n' "$a" || exit 9; code=$(sed 's/#.*//' "$s"); grep -q 'jq' <<<"$code" || exit 9; grep -qE '(echo|printf|say)[^#]*(retired hook|not carried by the template|cannot be registered)' <<<"$code" && exit 0; exit 1

---

## BL-119 — a `retire` verdict on an EXTENSION reaches no actor, because no step exists to reach

**Uncovered while fixing `BL-118`, and it is the same class one subject over — but not the same
defect, and the difference is the whole finding.** `apply.sh:731-741` suppresses the
`WORKLIST extension-reread` row on any recorded verdict, exactly as the override loop did. That
suppression is CORRECT: the row's obligation is *"re-read this entry against the new core text and
record a verdict"*, and any recorded verdict discharges it. The reading has been done.

**What is missing is the other half.** For an override, `still-additive` means keep and the other
two authorize a remedy the script emits. For an extension, `retire` and `contradicts-core` are
recordable, are honest answers, and authorize nothing — **there is no extension remedy emitter in
the tree at all.** Derived over `core/`, with the override path as the control in the same
invocation:

```
say (NOTE|WORKLIST|HARD…) <kind>  across apply.sh   -> 8 distinct kinds, none of them a retire
                                                       or repair for an extension
grep -rn 'extension-retire' core/                   -> 0
grep -c  'stamp retire' …/apply.sh                  -> 4    # control: the OVERRIDE path has one
```

`layer-drift.sh:1526` does tell a consumer to retire an extension that merely duplicates core, but
that is the `EXTENSION-TITLE-MATCHES-CORE` row and a different subject; nothing carries a
`retire` recorded against `EXTENSION-HOOK-DRIFT`. So a consumer that reads the entry, concludes it
should go, and records that honestly is left with a decision nobody is told to act on — the
outcome `BL-118` names, reached by a route `BL-118`'s fix does not touch.

Tiered **DEFECT**, and the consequence is silence rather than a wrong prescription: no consumer
has been observed hitting it, unlike `PC-S307`, which was filed off a live pull. Not filed
upstream — it was found here.

The receipt is the same DIFFERENTIAL the `apply-worklist-rows` fixture uses on the override side,
and its first cut was wrong in a way worth recording: comparing the two runs' full output scored
**0** on the unfixed tree, because the NOTE interpolates the verdict name and the two messages
therefore differ by construction. Keyed on the row SEVERITY and KIND instead it reads 1 here, and
0 against a mutant that emits any distinct row for a non-keep verdict. Exit 9 if the loop cannot
be located or the keep run emits nothing.

verify: sh set -e; a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$a" ] || exit 9; t=$(mktemp -d); sed -n '/^while IFS="$TAB_CH" read -r ext detail; do$/,/^EOF$/p' "$a" > "$t/l.sh"; [ -s "$t/l.sh" ] || exit 9; { echo 'TAB_CH="$(printf "\t")"'; echo 'say(){ printf "%s %s\n" "$1" "$2"; }'; echo 'ADJ_ROW_TOKEN=adjudicated'; echo 'ADJ_KEEP_VERDICT=still-additive'; echo 'LD_HOOK="$(printf "extensions/e.md\t%s" "$D")"'; echo '. "$T/l.sh"'; } > "$t/d.sh"; r=$(T="$t" D="adjudicated=retire :: p" bash "$t/d.sh" 2>&1) || exit 9; k=$(T="$t" D="adjudicated=still-additive :: p" bash "$t/d.sh" 2>&1) || exit 9; rm -rf "$t"; [ -n "$k" ] || exit 9; [ "$r" = "$k" ] && exit 1; exit 0

## BL-123 — the read-failure collapse is unfixed on `layer-contract.yaml`, and its message tells the operator the file is malformed

**Same class as `PC-S307-AWK-CANT-OPEN-FILE-MISREAD-AS-MISSING-FRONTMATTER`, one level up, and
`v0.435.0` did not touch it.** The contract is read at `core/scripts/validate-layer-entries.sh:781`
and `:782` with the status discarded, and again at `:1001`, `:1105` and `:1109` behind `2>/dev/null`.
An `awk` that cannot open the contract prints nothing and exits 2; a contract genuinely lacking
`contract_version:` prints nothing and exits 0. Both land in the same arm.

Measured with the contract present at mode 000, identical before and after `v0.435.0`:

```
rc=1
ERROR  E17  read no usable contract_version out of .../layer-contract.yaml (got '<none>')
ERROR  E17  read ZERO clauses with a since: out of .../layer-contract.yaml
ERROR  E16  could not read 'consumer_crosswalk_file:' from .../layer-contract.yaml
ERROR  E16  RETIRED-ID HISTORY UNREADABLE
LAYER_CONFORMANCE v1 contract_version=- entries=0 ... errors=4 warnings=1
```

**This is a WRONG-MESSAGE defect, not a false-PASS defect, and the distinction is why it was
deferred rather than treated as a blocker.** The run refuses, the footer honestly reads
`contract_version=-` and `entries=0`, and nothing is acquitted. But `got '<none>'` is not a value
that was read — it is a read that never happened — and the operator is told their contract is
malformed when it is intact and merely unreadable. The remedy they will reach for is to rewrite or
restore a file that has nothing wrong with it.

**The second-order cost is the one worth stating.** An unreadable contract empties `LC_CV`, which
SKIPS the census loop entirely, which is the only guard a healthy consumer exercises. So this state
silently disarms `v0.435.0`'s primary protection at the same moment it misreports its own cause.

**A SIBLING INSTANCE THIS ENTRY DOES NOT COVER, named so a close here is not read as a close there.**
`:1770`/`:1771` read `stories_dir` and `stories_dir_sprint_placeholder` out of
`schemas/sprint-status.json` with the status discarded; empty values leave `LC_ST_PARENT_RE` empty and
`:1839`'s `|| continue` skips the subject in silence. It gates one emitter, `warn W11`, so it costs a
warning and can never move an exit code — which is why it is NOT folded into this entry's subject and
NOT asserted by the receipt below. This entry expires when the `layer-contract.yaml` reads report a
read failure as a read failure, and that leaves the schema instance open.

**Not closable by rewording alone.** The message can only become accurate if the status is taken off
the read, which is the same fix shape `fm()` received. Note that `layer-conforms-to` asserts on E17
text, so a message change has a fixture obligation.

verify: sh V=core/scripts/validate-layer-entries.sh; C=core/skills/ai-dlc/layer-contract.yaml; [ -f "$V" ] && [ -f "$C" ] || exit 9; d=$(mktemp -d) || exit 9; trap 'chmod -R u+rwX "$d" 2>/dev/null; rm -rf "$d"' EXIT; K="$d/.claude/skills/ai-dlc"; mkdir -p "$K/extensions" || exit 9; cp "$C" "$K/" || exit 9; printf -- '---\nkind: role\nid: r\nhooks: steps/retro.md\npush_candidate: false\nconforms_to: 1\n---\n# R\n' > "$K/extensions/e.md"; O=$(bash "$V" "$d" 2>&1); grep -q "contract_version" <<<"$O" || { echo "HARNESS BROKEN: readable control produced no contract line"; exit 9; }; chmod 000 "$K/layer-contract.yaml"; if awk '{exit}' "$K/layer-contract.yaml" 2>/dev/null; then echo "HARNESS BROKEN: seal did not take"; exit 9; fi; U=$(bash "$V" "$d" 2>&1); grep -qE "could not READ|unreadable|cannot read" <<<"$U" || exit 1; grep -q "got '<none>'" <<<"$U" && exit 1; exit 0


## BL-126 — the pause-flag deny hook reads no agent identity, so it cannot let an in-flight teammate write reach a consistent stop

**The PreToolUse deny at `core/hooks/ai-dlc-acknowledge.sh:466` fires the moment
`_bmad-output/pipeline-paused.flag` exists, and the hook reads no field that could tell a
TEAMMATE's in-flight write from the LEAD's next advancing action.** Its whole read-set is
`.session_id` (`:60`), `.tool_name` (`:61`), `.transcript_path` (`:62`), `.tool_input.skill`
(`:161`) and `.tool_input.file_path` (`:402`). Grepping that file for `subagent`, `agent_type`,
`parent` or `teammate` returns only two prose comments (`:427`, `:521`) and no read — control in
the same invocation: `UPDATER_SESSION` returns 7 hits, so the grammar fires.

There is also no quiesce concept anywhere to hang a fix on: `grep -rn 'quiesce|drain|in-flight|inflight' core/hooks/`
returns nothing, against a control of `pipeline-paused` matching in five hook files.

**The consequence is an artifact left less consistent than either endpoint.** Arming the flag
while a teammate is mid-derive denies its next `Write`/`Edit` under `_bmad-output/`, so a
multi-section artifact keeps the sections already amended and the sections still carrying the text
those amendments contradict. Filed by the reference consumer as
`PC-S307-CONTINUE-HOOK-CANNOT-DISTINGUISH-A-DIRECTED-SESSION-FROM-AN-UNATTENDED-ONE`, whose second
claim this is, observed on its sprint-307 carry-over session.

**TWO PARTS OF THAT FILING ARE REFUTED AND ARE NOT THIS ENTRY'S SUBJECT.** It calls the blast
radius "binary (block everything, immediately)". It is not: the deny is scoped to
`Agent|Task|Skill|TaskCreate` plus `Write|Edit|MultiEdit|NotebookEdit` whose `file_path` is under
`_bmad-output/`, `:481` leaves Read/Grep/Glob/Bash allowed, and FOUR carve-outs already ship —
`:411` `_bmad-output/ai-dlc-update/*`, `:424` `*-resolution-p*.md`, `:438` `pipeline-snapshot.md`,
`:459` `pipeline-snapshot-history.md`. The exemption precedent is established; what is missing is a
predicate, not permission. And the filing's attribution of the denied writes to a named teammate is
**not established by any shipped artifact**: the `ACK_DENIED` log rows carry no `file_path` and no
agent identity, and both rows recorded that session carry the LEAD's session id. That
observability gap is part of this entry's subject — a deny nobody can attribute is a deny nobody
can adjudicate.

**Why this is not folded into the release that shipped the other half.** The sibling claim was a
retry-text gap in `ai-dlc-continue.sh`, a Stop hook. This is the PreToolUse deny path, a different
hook and a different subsystem, and the remedy is a quiesce semantic that does not exist yet
anywhere in `core/hooks/`. Under this repo's one-subsystem-per-batch rule those do not belong in
one release.

**Do NOT fix this by widening the carve-out list.** A fifth path pattern acquits a path for every
caller including the lead, which is the thing the flag exists to stop. The predicate has to be
about WHO is writing, and the hook is currently blind to that — so the first thing this entry owes
is a measurement of whether a PreToolUse payload carries any usable subagent discriminator at all.
If it does not, the entry's remedy is the observability half alone: record `file_path` and whatever
identity IS available on every `ACK_DENIED` row, so the next occurrence is attributable.

**Tiered DEFECT.** It corrupts a shared artifact rather than losing work outright, and reaching it
requires a pause to be armed while a teammate write is in flight.

**The measurement this entry owed first is delivered, and the receipt is replaced (`v0.496.0`,
`BL-156`).** A teammate's PreToolUse payload DOES carry a discriminator: `agent_id` and
`agent_type`, absent on the lead's own calls, with the LEAD's `transcript_path` beside them.
`v0.496.0` reads `.agent_id` in this very hook — for Check 2z, the router-read guard, and not
for the pause deny this entry is about. The receipt that stood here keyed on the hook's READ-SET
and would have read CLOSED on that change while a teammate's write on a paused tree still
answers `Rule 29` (measured, before and after). It now drives the pause deny with a teammate
payload on a paused tree: exit 1 while that write is denied as Rule 29, 0 only when the hook
both reads an identity field on a non-comment line (a whole-file grep was satisfied by a
comment, measured by the adversarial hand at `v0.496.0`) and no longer answers Rule 29 to it, and
9 when the lead's own
paused write is not Rule-29-denied (the deny is gone, nothing measured) or the teammate's returns
a deny naming another check. **Limit, stated:** a change that exempts every teammate from the
pause deny outright scores 0 here. This entry's own text asks for a quiesce semantic — let the
in-flight write finish, do not admit new dispatches — not a blanket exemption, so whoever closes
it must say which was built. A whole-hook early exit on `agent_id` also scores 0 and additionally
removes Check 2a's Rule 8 stop deny for teammates, which nothing here names as wanted. An
exemption keyed on `agent_type` scores 1: a lead started with `claude --agent <name>` carries
`agent_type` and no `agent_id`, and the receipt drives that lead as its own paused cell. Read `BL-156` for why Check 2z took the blanket form and this
check must not inherit it.

verify: sh h=core/hooks/ai-dlc-acknowledge.sh; [ -f "$h" ] || exit 9; command -v jq >/dev/null || exit 9; r=$(grep -v '^[[:space:]]*#' "$h" | grep -oE 'jq -r [^|]*\.[a-z_.]+' | grep -oE '\.[a-z_][a-z_.]*' | sort -u); [ -n "$r" ] || exit 9; printf '%s\n' "$r" | grep -q '^\.tool_name$' || exit 9; w=$(mktemp -d) || exit 9; trap 'rm -rf "$w"' EXIT; mkdir -p "$w/p/_bmad-output/planning-artifacts/s7" "$w/p/scripts/ai-dlc"; printf '#!/bin/sh\necho 7\n' > "$w/p/scripts/ai-dlc/sprint-status.sh"; chmod +x "$w/p/scripts/ai-dlc/sprint-status.sh"; : > "$w/p/_bmad-output/pipeline-snapshot.md"; : > "$w/p/_bmad-output/pipeline-paused.flag"; printf '{"type":"user","message":{"content":"<command-name>/ai-dlc</command-name>"}}\n{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/w/.claude/skills/ai-dlc/steps/route.md"}}]}}\n' > "$w/s.jsonl"; d(){ jq -nc --arg tr "$w/s.jsonl" --arg ag "$1" '{session_id:"r",transcript_path:$tr,tool_name:"Write",tool_input:{file_path:"/w/_bmad-output/planning-artifacts/x.md"}}+(if $ag=="" then {} elif $ag=="type" then {agent_type:"Explore"} else {agent_id:$ag,agent_type:"general-purpose"} end)' | CLAUDE_PROJECT_DIR="$w/p" bash "$h" 2>/dev/null; }; a=$(d ""); b=$(d ax); f=$(d type); case "$a" in *"Rule 29"*) ;; *) exit 9;; esac; case "$f" in *"Rule 29"*) ;; *) exit 1;; esac; case "$b" in *"Rule 29"*) exit 1;; *permissionDecision*) exit 9;; esac; printf '%s\n' "$r" | grep -qE '^\.(subagent|agent_type|agent_id|parent_session_id|invoked_by)' || exit 1; exit 0

## BL-130

**A `\b` word boundary works in `grep -E` on this platform and silently matches NOTHING in bash
`[[ =~ ]]`, and no arm distinguishes the two.** Measured here, same shell, one invocation:
`printf '%s\n' "stub = 1" | grep -cE '\bstub\b'` returns 1 and correctly returns 0 for
`client_stub`, so BSD grep (2.6.0-FreeBSD, "GNU compatible") supports it; while `re='\bstub\b'`
with `[[ "stub = 1" =~ $re ]]` does NOT match, against a control of the same test without the
boundary, which does. Inline and via-variable both fail. bash is 3.2.57.

**The consequence is a check that reads as hardened and examines nothing.** `v0.451.0`'s subject
was filed with exactly this remedy — `STUB_MARKER='\b(...)\b'` — and built as a mutant it examined
**0 markers over all 393 hot-path files**, passing `# stub, wire later` and
`raise NotImplementedError()` alike while reporting a clean tree. It was rejected on measurement
rather than on review, and nothing in the repo would have caught it.

**`scripts/validate-shell-portability.sh` is the right home and a table row is NOT the right
shape.** Its arms are a `S<N>_PAT` / `S<N>_WHY` / `S<N>_SKIP` table read by the loop at
`scripts/validate-shell-portability.sh:112`, and S5/S6 already carry the sibling case (`\s` in
grep and sed). But the same-line grammar this one looks like scores its own motivating case as a
NON-INSTANCE: the offender is a variable ASSIGNED a pattern containing `\b` at one line and
consumed by `=~` at another — 116 lines apart in the `v0.451.0` case. Measured: `=~` and `\b` on
one line, comments stripped, over 390 tracked shell files returns **0**, and a seeded two-line
probe under `mktemp` does NOT fire it. **That zero is a floor of unknown depth, not an absence.**

**So the arm needs a two-pass join and one exemption that is not optional.** Pass 1 collects
variables whose assigned value contains `\b`; pass 2 asks which of those reach a `[[ =~ ]]`. The
exemption is the grep/sed consumer, where `\b` is CORRECT on this platform — 17 live sites use it
that way today, several load-bearing in `scripts/validate-enforcement-map.sh:1127` and
`core/scripts/validate-spec-join.sh:931`, and an arm without that exemption convicts every one of
them. **A check that wedges correct code is worse than no check.**

**Provenance.** Uncovered by `v0.451.0` (batch 31) while building the filed remedy as a mutant.
Not consumer-filed and carries no `PC-` id, so it ranks BELOW any PC-backed entry by the
provenance-first rule. Filed rather than fixed because it is a different subsystem from that
batch and needs a join rather than the table row it resembles — recorded here so the next author
does not ship the one-line version and read its zero as clean.

  verify: sh V=scripts/validate-shell-portability.sh; [ -f "$V" ] || exit 9; d=$(mktemp -d) || exit 9; mkdir -p "$d/scripts" "$d/core" || exit 9; cp "$V" "$d/scripts/" || exit 9; printf '0.0.0\n' > "$d/VERSION"; printf 'ok\n' > "$d/core/note.md"; printf 'x=1\nre="\\b(foo)\\b"\nif [[ $x =~ $re ]]; then :; fi\n' > "$d/probe.sh"; printf 'n=$(printf %%s a | grep -cE "\\bfoo\\b")\n' > "$d/exempt.sh"; printf 'mapfile -t arr < /dev/null\n' > "$d/control.sh"; git -C "$d" init -q && git -C "$d" add -A && git -C "$d" -c user.email=t@t -c user.name=t commit -qm s || exit 9; out=$(bash "$d/scripts/validate-shell-portability.sh" 2>&1); rc=$?; rm -rf "$d"; case "$out" in *control.sh*) ;; *) exit 9 ;; esac; case "$out" in *exempt.sh*) exit 1 ;; esac; case "$out" in *probe.sh*) ;; *) exit 1 ;; esac; [ "$rc" -ne 0 ] || exit 1; exit 0

## BL-129 — a change to an adjudication predicate has no mechanism that can see what it RECLASSIFIES

**Every fixture seed for `validate-adversarial-convergence.sh` is hand-written, and written by
whoever is changing the predicate. So the suite cannot answer the one question a predicate change
raises: does this reclassify artifacts that were VALID under the predicate it replaces?** A green
fixture, a green mutant battery and a green gate are all consistent with a change that turns a
consumer's history non-conforming, because every input was authored against the new rule.

**Measured, not hypothetical.** `v0.442.0` shipped with `check-24` at 111 assertions, seven mutants
killed and the full gate green. Driven over the reference consumer's real pass series it turned
**33 from PASS to FAIL, 0 the other way**, three of them in a sprint that consumer had PAUSED. The
defect was found by running the shipped validator over a tree outside this repo, at the point the
operator said they were about to pull — not by anything in the gate. `v0.443.0` corrected it.

**THE PROMPT-SIDE REMEDY IS ALREADY KNOWN AND IS NOT ENOUGH.** "Run the differential against the
consumer before cutting the release" is correct and is being followed, but its only carrier is a
session's recollection, which `resident-context.md` says is not a carrier. It also lives on ONE
side of the boundary: `v0.442.0` reached a consumer precisely because a single party was looking.

**THE FRAMING ABOVE IS WRONG IN A WAY THAT MATTERS, AND THIS PARAGRAPH IS THE CORRECTION.** The
thing that caught `v0.442.0` was a DIFFERENTIAL, not a characterization: two predicates, old and
new, over whatever tree exists at the time. Nothing is frozen, so there is no golden verdict and no
moment at which today's bug becomes the reference — objection 1 below does not apply to it, and
neither does objection 2, because a differential enumerates the same set TWICE IN ONE RUN and a
wrong population definition cancels. Measured: the two parties' grammars disagreed 105 against 94
and the CHANGED count was 33 under both, then 0 under both. So the instrument is not missing.

**WHAT IS MISSING IS AN INPUT, AND THE REASON IS NOT ONLY THAT NO CONSUMER TREE IS ON THIS SIDE.**
Run the same differential over THIS REPO'S OWN fixture seeds and it reports **2 changed cells
against the consumer's 33** — and the two are the tell. Derived by driving the `0.441.0` and
`0.442.0` validators over the seed as it stood AT `v0.442.0`:

    ceiling-at-limit          0.441.0=1 -> 0.442.0=0     the INTENDED effect
    ceiling-refuses-at-limit  0.441.0=0 -> 0.442.0=1     THIS WAS THE REGRESSION

**The regression DID appear, as one row, and it was indistinguishable from the intended change
because the same session authored both the predicate and the case declaring that row correct.**
`ceiling-refuses-at-limit` was written to expect exit 1. The fixture scored it green. A differential
on this side does not fail for want of volume; it fails because its expectations are authored by the
hand being checked — the defect `.claude/rules/fixture-mutants.md` names as keeping the fixture
author different from the arm's.

**AND THE GENERAL FORM IS NEITHER AUTHORSHIP NOR VOLUME: AN INPUT SET THAT AGREES BY CONSTRUCTION
CANNOT DISCRIMINATE.** The two rows above agree because one hand wrote the predicate and the case.
A consumer artifact written AFTER a predicate ships agrees for a different reason and is equally
useless. So the discriminating population at any future pull is the subset PREDATING the predicate
under test, never the total — and quoting a total is how a vacuous run reads as a clean one.

**Derived, with a control, against the consumer at `0.443.0`:** of 94 series, **75 carry a
derivable `invoked_at`**, and **all 75 predate the `v0.442.0` merge — 0 do not**. Cut taken as a
full UTC instant (`2026-08-30T02:54:46Z`), not a date. Control: the same query at an
impossible-future cut returns 75, matching the derivable count.

**AN EARLIER REVISION OF THIS ENTRY PUBLISHED "3 POST-CUT" AND IT WAS WRONG, BY THE SAME CLASS OF
BUG THE ENTRY IS ABOUT.** The cut was written as the DATE `2026-08-29` and compared with `<`, so a
series whose newest pass fell ON that date was not less-than and dropped into the post bucket. All
three were `s307` series timestamped `2026-08-29`, i.e. genuinely pre-cut. **A date-only compare
mis-buckets exactly the same-day window the question is about**, and the artifacts carry `Z` while
`git show -s --format=%cI` returns an offset, so the two are not comparable as strings at all. Both
parties hit this independently; one of them got the right answer from the wrong method on the first
run, which is why it survived to be published here.

Two things follow, and both are limits on the metric rather than on the corpus:

- **19 of 94 series carry no derivable `invoked_at` at all**, so the discriminating-subset query
  cannot classify a fifth of the corpus and silently drops it. A figure taken from this metric is a
  FLOOR, and reporting it without that sentence repeats the defect one level up. **This is the
  finding to keep** — it holds at 19-of-94 and at the peer's 27-of-105, and it does not depend on
  which cut either party chose.
- **0 post-cut is the EXPECTED answer today and is not reassuring.** That consumer's pipeline has
  been paused throughout, so nothing could have been authored under the new predicate yet. The
  decay has not begun because nothing has RUN; it begins the moment the sprint resumes. Do not read
  today's total-equals-discriminating as a standing property — it is an artifact of a stopped
  pipeline, and a later run reporting a small pre-cut subset cannot discriminate at all.

**So the entry's subject is a BOUNDARY, not a missing tool**, and `consumer-boundary.md` already
owns it: the only inputs that can discriminate are artifacts THIS SIDE DID NOT WRITE. Do not spend
effort building a corpus to recover a property a differential has for free, and do not assume a
frozen input set fixes it — a set harvested here and blessed here reproduces the same defect one
layer down.

**AND THE INPUTS ARE ONLY HALF OF IT: A SINGLE DERIVATION OVER PERFECT INPUTS IS STILL WORTHLESS.**
Whoever scopes this will be tempted to read the paragraph above as "obtain the right artifacts, then
measure". That is not what happened. Across this episode BOTH parties wrote a wrong query on the
FIRST attempt, over the same real artifacts, every time:

- a series-prefix grammar that stripped the `-pass` stem — returned a clean `12 of 12 unchanged`,
  which reads as a refutation;
- a `find -name` predicate matching the BASENAME — returned a confident `32 over 75`, and the
  surviving exclusion was CORRECT BY LUCK;
- a cut written as a DATE and compared with `<` — mis-bucketed the same-day window that was the
  entire question, and published `3 post-cut` against a true `0`;
- a string compare of a `Z` timestamp against a `-04:00` offset — which returned the RIGHT answer
  for the WRONG reason, and would have shipped undetected on its own.

**Not one of those was caught by the tree, by a control, or by the party that wrote it.** Every one
was caught by a SECOND derivation, by a different hand, disagreeing out loud and then reconciling.
`fixture-mutants.md` states this for fixtures — *"keep the fixture's author different from the
arm's; an arm and a battery written by the same hand cannot disagree"* — and this entry is the
same rule for MEASUREMENTS. A mechanism that hands one session the right artifacts and one query
has reproduced the defect it was built to prevent.

**Consequence for scoping: whatever is built here must produce a number a SECOND party can
independently re-derive and compare**, and its output must carry the population definition it used,
because that definition is where all four errors above lived — never in the arithmetic.

**Candidate mechanism, NOT chosen and possibly not viable — a characterization corpus.** Freeze a
set of real-shaped pass series in the tree with their adjudicated verdicts, and fail the push when a
predicate change flips one without a declared reason. Read the paragraphs above FIRST; these three
objections are why it is recorded as a candidate rather than a plan:

- **A frozen verdict encodes today's behaviour as correct, and the counterfactual is exact.** Put
  by the peer session that measured the 33: *had `v0.442.0`'s arm B shipped a week earlier and the
  corpus been cut after it, the 33 would have frozen as CONFORMING and `v0.443.0` would have read
  as the regression.* A corpus can only ever encode what the predicate said when it was frozen,
  which is the thing under test. **This is the objection to answer first, and neither side has an
  answer.** A characterization corpus is not an oracle and must not be scoped as one.
- **`consumer-boundary.md` says no gate reaches the consumer's tree**, so the corpus must be
  committed here — and a committed copy of another repo's artifacts goes stale silently, which is
  the class this repo already has scars from.
- **AND THAT CORPUS WAS NEVER STABLE TO BEGIN WITH, which is worse than going stale.** The only
  tree holding real series is a LIVE sprint working directory: the population changes every
  sprint, artifacts are archived into `*-cycle-1/` directories mid-cycle, and the population
  DEFINITION was derived wrongly twice in one day by two parties before the two answers agreed —
  once as a silent under-count, once as an over-wide set including repair and resolution records
  that are not pass series at all. A harvest inherits all of that.
- **A declared-reason escape hatch is an opt-out**, and `CLAUDE.md` holds that an instruction
  shipping its own opt-out is not an instruction. Whether the declaration can be made costly
  enough to bind is the open design question.

**Scope note: this is NOT specific to the adversarial validator.** Ask, before scoping, which other
shipped predicates adjudicate persisted artifacts a consumer already holds — that population is the
entry's real subject and it has not been derived.

verify: unscoped — this entry records a gap and names a candidate, not a receipt. Do not close it
on a green `check-24` run or a green suite; that green is exactly what failed to see the defect.

## BL-128 — an override can restate a threshold that later migrates into a validator, and layer-drift cannot see it

**An `overrides/` file may restate a rule as prose; `layer-drift.sh` joins that override to the
`SKILL.md` section it shadows by `base_sha`. When the rule MIGRATES OUT of `SKILL.md` into a
shell validator, the shadowed section stops moving, the join keeps reporting `OVERRIDE-OK`, and
the override is now wrong with nothing able to say so.** No override carries a `base_sha`
against a script, so the migration is invisible to the only mechanism that watches overrides.

**Found by a peer session during the 0.443.0 pull rehearsal, on a live instance, not
hypothetically.** The reference consumer's `overrides/SKILL__Rule-8.md:31` restates arm E's
predicate: *"A nonzero MAJOR held at zero CRITICAL across 2+ passes is a STALL."* `v0.443.0`
moved arm E to `blocking > MAJOR_EXIT_CEILING`, so a plateau at 1–3 blocking MAJOR is no longer
a stall and that sentence is false. `layer-drift.sh` reported `OVERRIDE-OK` and was CORRECT to:
the `SKILL.md` section did not move. The rule did.

**The consumer-side reword is the consumer's and is NOT this entry.** This entry is the
distribution-side gap: nothing here detects an override whose subject has left the file the
override is joined to.

**Not yet scoped, and the population is unmeasured.** Two things to derive before building:
how many shipped rules have migrated from a role/skill file into a validator (the join's
blind set), and whether an override's prose can be bound to a validator at all without a
second restatement — `mechanism-design.md` warns that a rule restating a mechanism drifts
tighter than the mechanism. A detector keyed on "this override names a threshold" has an
unmeasured false-positive set and must not ship before that set is enumerated.

verify: unscoped — this entry records a gap, not a receipt. Do not close it on a green
`layer-drift.sh` run; that green is the defect.

## BL-127 — a fixture is skipped by the read-set map on exactly the change that breaks it

**`.ai-dlc-fixture-readsets.tsv` decides which fixtures a push runs, and a MAPPED fixture whose row
omits a file its `run.sh` actually opens is skipped on the one change most likely to break it.** The
fail-closed arm in `.githooks/pre-push` rescues only UNMAPPED fixtures — a mapped row with a hole
is trusted, so the hole is silent.

**Measured on the working tree, filtered to files that really exist under `core/hooks/`: 20
(fixture, hook) pairs across 15 distinct fixtures.** Control in the same derivation: the map does
carry hook paths — `ai-dlc-pause.sh` appears in 35 rows — so a zero would have meant the grammar,
not the corpus.

The instance that motivated this entry: **`pause-hook-origin` parses `ai-dlc-continue.sh` at four
sites and does not list it.** That fixture owns the `cat > "$LOG_FILE" <<'EOF'` log legend, 2860
bytes required byte-identical across FIVE hooks, and it is the only thing guarding that invariant.
A push touching only `ai-dlc-continue.sh` does not select it. `v0.441.0` edited that hook and
passed only because the release was gated with `AI_DLC_FIXTURE_NO_SKIP=1` by hand.

**THE FALSE-POSITIVE SET IS NOT MEASURED, AND MEASURING IT IS THE FIRST THING THIS ENTRY OWES.**
"Parses" here means the `run.sh` mentions the basename, and at least one hit is known to be
path-as-data rather than a read — `layer-readopt-gate` passes `hooks/ai-dlc-continue.sh` as an
ARGUMENT to the override-registration script and never opens it. So 20 is a CEILING on the real
population, not a count of defects, and this entry must not be closed on a fix whose FP set was
never taken. The discriminator is whether the path is OPENED, which a mention-grep cannot see.

**Do NOT fix this by hand-editing 20 rows.** The map is trace-derived; hand-patching it puts a
second, drifting declaration beside the derivation and the next regeneration silently reverts it.
The fix belongs at the point the map is GENERATED, or in an arm that fails the push when a mapped
fixture's row omits a `core/hooks/` path its `run.sh` opens — which is the same shape as the
existing bidirectional joins and is why the receipt below keys on an arm existing rather than on
the count reaching zero.

**A count-reaching-zero receipt would be unattainable and is deliberately not used.** Until the FP
set is enumerated, some of the 20 are legitimate, so "the gap is 0" is a criterion that can never
go green — the documented failure mode for acceptance criteria in this repo.

Discovered while shipping `v0.441.0`, which addressed the reference consumer's
`PC-S307-CONTINUE-HOOK-CANNOT-DISTINGUISH-A-DIRECTED-SESSION-FROM-AN-UNATTENDED-ONE`. Not filed by
that consumer and carries no `PC-` id of its own; it is an ai-dlc-internal discovery and ranks
below any PC-backed entry under the provenance-first rule.

**Tiered DEFECT.** It does not corrupt anything; it removes a guard silently, and the symptom of a
missing guard is a green push.

The receipt is STRUCTURAL: it exits 1 while no arm in `scripts/validate-enforcement-map.sh` binds a
fixture's read-set row to the `core/hooks/` paths its `run.sh` resolves, 0 once one does, and 9 if
the map or the read-set file cannot be located, so a relocated map reports a moved precondition
rather than a false close.

verify: sh m=scripts/validate-enforcement-map.sh; r=.ai-dlc-fixture-readsets.tsv; [ -f "$m" ] || exit 9; [ -f "$r" ] || exit 9; grep -q ai-dlc-pause.sh "$r" || exit 9; h=$(grep -cE "^# --- I[0-9]+[a-z]?:" "$m"); [ "${h:-0}" -ge 10 ] || exit 9; grep -qiE "^# --- I[0-9]+[a-z]?:.*(read-set|readset)" "$m" && exit 0; exit 1

## BL-132 — the safe-stop acquittal answers a question about BEHAVIOUR with a test on ancestry

Carries the reference consumer's `PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT`, so it is
PC-backed and ranks above any distribution-internal entry under the provenance-first rule. **The
candidate's DEFECT is real and its stated REMEDY is refuted — both halves were measured, and the
adjudication has been carried back in `docs/reviews/graph-s340-adjudication-brief.md` §1b.**

`self-update-gate.sh`'s `advise_safe_stop` acquits a split with "SPLIT BUYS NOTHING HERE", gated on
`machinery_at_or_past()` (`:205-213`), which is `git merge-base --is-ancestor` on the stamp's
`skill_commit` and nothing else. The sentence it emits is a claim about what the CLASSIFIER will
do; the test underneath it is about where a sha sits in the graph.

**DO NOT BUILD THE CONTENT/BYTE-EQUALITY ARM. It was scored and it does not fire on the pull that
filed the candidate.** The filing state was reconstructed from the consumer's own stamp history and
the shipping gate driven against it, giving a real candidate of 0.454.0. A byte arm stays quiet at
every candidate in the range, and the filing-state consumer matched **0 of 3** paths a hop would
write. Currency by set: machinery set (123) NO — 3 differ, 1 absent; `reconcile/` subtree (27) NO —
`setup-sites.md` differs; `reconcile/` executables (23) YES, 23 of 23. Control: the same scorer with
the candidate set to BASE returns 120 match / 0 differ, so it discriminates. `setup-sites.md` is a
genuine classifier input — `preclassify.sh` reads it at `:117`, `:218` and `:329` — and it genuinely
changed, so byte equality is FALSE at every scope above the executable subset.

**The claim measures TRUE behaviourally, which is what makes this a defect rather than a bad
filing.** The consumer's installed engine and the engine at 0.454.0, run against one tree with one
set of arguments: **0 changed classifier rows over 59 paths, against a control of 4** changed rows
versus a 0.432.0 engine, with `diff -rq` confirming the two engine directories differ. The hop's
engine change was inert and the gate could not say so.

**THE BEHAVIOURAL DIFFERENTIAL IS REFUTED AS THE REMEDY, MEASURED AT BATCH 137 BY A CONTRACT
ADVERSARY AND RE-DERIVED BY THE LEAD. DO NOT BUILD IT.** It was the predicate this entry named,
and it fails for the same reason as the byte arm it was meant to replace, only harder:

- **The filed INSTANCE is not an instance.** Reconstructed filing state (consumer at
  `8e53e4b41^`, stamp `0.452.0` / `11bdeb8e`; control: `HEAD` stamp reads `0.608.0` / `03c04e74`,
  so the extraction is genuinely historical), driving the consumer's own installed engine with
  `11bdeb8e cb3ac04d`: `SPLIT BUYS NOTHING HERE` rows = **0**. The run takes the `else` branch.
  `machinery_at_or_past` is FALSE there (`--is-ancestor b634e42d 11bdeb8e` rc=1; control:
  `--is-ancestor b634e42d cb3ac04d` rc=0) because the stamp is BEHIND the candidate. The
  acquittal never fired on the pull this entry was filed from, so a new conjunct ANDed under
  that guard changes nothing on the motivating case, in either direction.
- **The central measurement had a subject side byte-identical to its own baseline.**
  `preclassify.sh` is blob `860ed5494c38` at 0.452.0, 0.454.0 AND 0.456.0 (control:
  `setup-sites.md` differs across the same pair, `ba22836977` vs `88a0b4a50e`). The "0 changed
  classifier rows against a control of 4" was two runs of the SAME program; `diff -rq` proved the
  DIRECTORIES differ and never that the CLASSIFIER did.
- **The 59-row population is not the one the gate runs on.** On the real range the classifier
  emits **10** rows, all `UPSTREAM-ONLY` (6) or `UPSTREAM-ONLY-ADD` (4) — no consumer delta, so
  no judgement for two engines to disagree about. 59 came from a synthetic `0.432.0..0.456.0`.
- **The false-positive set is 92%.** Over the last 40 release hops `preclassify.sh` is UNCHANGED
  on **37** (control: the same walk over all of `core/` shows 34 of 40 hops changed, so the walk
  discriminates). The arm this entry banned the byte predicate for was vacuous on 7 of 39; this
  one is vacuous on 37 of 40.
- **No control-engine rule is derivable, and that half is a PROOF and not a bug.** Control = the
  engine at BASE is byte-identical to the installed engine exactly when it is needed. Control =
  N releases back is a magic number: the first differing `preclassify.sh` sits **7** releases
  back from the candidate, and N moves with cadence. A resolution control needs a KNOWN-DIFFERENT
  engine, establishable only by the byte comparison this entry bans or by an unbounded walk.

**THE DEFECT IS STILL REAL AND THE ENTRY STAYS LIVE.** Nothing above contradicts the finding that
the emitted sentence is a claim about BEHAVIOUR while the test underneath is graph-topological.
What is refuted is that a behavioural differential can carry it.

**THE DIRECTION THAT SURVIVES EVERY MEASUREMENT IS NARROWER: REFUSE, DO NOT ACQUIT.** Withhold the
acquittal when the classifier is byte-identical across `installed -> candidate`, because then the
ancestry test is the ONLY evidence and the sentence it licenses — "its machinery has already
landed" — is unsupported. One `git rev-parse` pair, no control engine, and it fires on the 37 of
40 hops where the differential is silent. It is NOT the banned byte-equality arm: that one gated
the PULL's content, this gates the ACQUITTAL's own evidence. It weakens an acquittal rather than
strengthening one, which is the asymmetry `self-update-gate.sh` already states for itself —
refusing costs less than firing wrongly. **Scope is the operator's; this is recorded as the
measured direction, not taken.**

**THREE THINGS ARE UNMEASURED AND THEY ARE WHY THIS IS FILED RATHER THAN BUILT.** Shipping a check
whose false-positive set has not been run is forbidden here, and this one has three open questions:

- **The new predicate's own FP set has not been run.** It needs its own battery.
- **A 10-ROW POPULATION CANNOT RESOLVE THIS DIFFERENTIAL.** Measured: at the filing range the
  subject read `0` and **the control also read `0`** — two demonstrably different engines producing
  identical output. That null was worthless and was nearly shipped as a result. Only at 59 rows did
  the control fire. **An arm of this shape must assert its own resolution in the same run or report
  UNDECIDED**, which is already this gate's doctrine for an unattributable answer.
- **COST IS NOT THE BLOCKER, AND AN EARLIER REVISION OF THIS ENTRY SAID IT MIGHT BE.** That
  revision put the resolution control at "a third, deliberately-older engine extracted per candidate
  ref" with a cost "not yet a number". **"Per candidate" was the load-bearing half and it is
  wrong**: `advise_safe_stop()` returns early on `AI_DLC_GATE_IN_SAFE_STOP`,
  which `:125` exports before the `--safe-stop` walk begins, so every per-candidate recursion
  short-circuits before reaching the acquittal and the differential is evaluated exactly once, on
  the single candidate the walk elected. Measured at **≈7s per invocation, independent of range
  length** — two subtree extractions at 0.03s each plus three `preclassify.sh` runs at ~2.3s over a
  59-row population, three interleaved reps. What blocks this is the unmeasured FP set above and the
  absence of a rule for CHOOSING the control engine, not the price.

**A byte predicate would also be VACUOUSLY TRUE on a large minority of hops**, which is a second
reason the refuted remedy must not come back: **7 of 39 consecutive release hops change ZERO
machinery paths** (0.427→0.428, 0.433→0.434, 0.437→0.438, 0.445→0.446, 0.453→0.454, 0.458→0.459,
0.464→0.465), against a control of **0 of 39** having an empty full diff.

**ONE CONJUNCT OF THE EVENTUAL ARM ALREADY SHIPPED, IN `v0.466.0`, AND MUST NOT BE REBUILT HERE.**
The acquittal now refuses on a tree carrying `.claude/.ai-dlc-applying`. That was filed as part of
this entry and then found to have a subject TODAY under the current ancestry route — a withheld
apply leaves `skill_commit` advanced beside a `commit` at base, and the acquittal fired on that
partial tree. It survives the switch to a behavioural predicate, because a partial tree can classify
identically and still not be a tree to acquit. **This entry is now only about the ancestry-vs-
behaviour predicate**, and closing it requires that, not the marker guard.

**Tiered DEFECT.** It wrongly advises a split on a consumer whose engine is already behaviourally
current. It is bounded: `advise_safe_stop` is called at exactly two sites, each immediately after
an `emit SELF-UPDATE-DEFER` inside a deferral block, so the acquittal is unreachable except behind
a DEFER and a wrong answer can only mis-advise a consumer already deferring — never one on the
happy path. **The bound re-derives TRUE; the line numbers this entry used to cite did not.** Every
anchor here had moved by `5540c7c6` — the acquittal, `machinery_at_or_past`, both call sites and
the early return — so the citations are given by NAME above and the reader greps for them. An
entry citing `path:line` into a file that moves is `BL-133`'s own subject, occurring here.

**THERE ARE TWO `SPLIT BUYS NOTHING HERE` EMITTERS AND ONLY ONE IS THE SUBJECT.** The second is
the push-refusal case with candidate `"-"`, whose window carries **0** non-comment references to
`machinery_at_or_past` or `advise_safe_stop` (control: 4 `emit` calls in the same window, so the
grep works) — its only textual hit is a comment explaining why the walk is deliberately skipped
there. Same banner, different premise, no ancestry test. **Name the subject by its
`machinery_at_or_past` guard, never by the banner text**, and note that the fixture asserts
`grep -c 'SPLIT BUYS NOTHING'` against expected counts at six sites: a fix landing on the wrong
emitter moves those counts and satisfies a banner-counting receipt while changing nothing.

**THE FIXTURE'S OWN MUTATION ANCHOR IS AIMED AT THE LINE A FIX MUST RESHAPE.**
`core/fixtures/self-update-gate/run.sh`'s `SC_A3` anchors on the literal
`    if machinery_at_or_past "$_ss"; then`, which matches the shipping gate exactly **1** time
(control: a bogus anchor matches 0). Any fix that rewrites that line empties the mutant silently —
it applies to nothing, the file stays byte-identical, and the battery reads SURVIVED. Assert
`! cmp -s` before scoring, and re-anchor the mutant on the predicate that DECIDES.

**THE RECEIPT IS REFUTED: IT REJECTS THE CORRECT FIX AND CLOSES ON THE DESTRUCTIVE INVERSE.**
Six candidates built from the shipping file, each asserted applied by `cmp -s` first. A real
differential — extract the candidate engine, run both `preclassify.sh`, compare — scores **1**,
REJECTED, because the receipt demands `show|archive|worktree` and `preclassify` on ONE line with
no `|` between them, and the extraction is necessarily two lines: `preclassify.sh` sources
`lib.sh` at `:47` and reads `setup-sites.md` via `dirname "$0"`, so it cannot be extracted as a
single file. Meanwhile the same line inside an UNCALLED function, the same line under `if false`,
an unconditional `: "$(git show … | head -0)"` consulting nothing, AND a mutant replacing the
guard with `git archive … || true` — which acquits **every** consumer unconditionally — all score
**0**, closed. The inverse mutant emits 1 `SPLIT BUYS NOTHING` row on the motivating case against
the shipping tree's 0, so the FIXTURE separates them and the receipt does not. **Key the
replacement on the EMISSION SITE** — that the acquittal's own guard consults a behaviour term —
plus a non-vacuity arm, and score it against all six before filing it.

verify: sh g=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; [ -f "$g" ] || exit 9; grep -q "advise_safe_stop" "$g" || exit 9; grep -vE "^[[:space:]]*#" "$g" | grep -qE "(show|archive|worktree)[^|]*preclassify" && exit 0; exit 1

## BL-133 — line-number citations in shipped core prose resolve against a different file on every consumer

A consumer runs whatever version it last installed, so a `<path>:<line>` written into shipped
`core/` prose points into a file that has moved. It does not error; it silently lands on unrelated
text, which is the failure mode this repo treats as worse than a missing citation.

**Found by the reference consumer**, which could not confirm a passage this side cited by line
because its tree was two releases behind and the numbers landed elsewhere. `v0.469.0` fixed the one
instance introduced by `v0.468.0`, re-citing by a greppable token instead.

**THE FIRST COUNT WAS WRONG, BY A GRAMMAR THAT COULD NOT SPELL ITS OWN SUBJECT — and that is the
part worth keeping.** The scan matched the path-plus-number form and not the bare colon-number form
the offending citation actually used, so it scored its own subject as a non-instance and reported
"the only one". Re-run over both forms with a seeded positive control and a negative control: FOUR
remain, in `core/skills/ai-dlc-update/SKILL.md`, `core/skills/ai-dlc-update/reconcile/predicate-sites.md`
(2) and `core/skills/ai-dlc/steps/_gate-procedures.md`.

**A second false-positive class was measured and removed rather than tolerated**: prose EXPLAINING
this defect, if it spells either form as an example, becomes an instance of its own subject. The
count read 6 until the examples were reworded. Any check built for this must exempt the passage
that documents it, or it will flag its own remedy forever.

**Tiered NOTE.** Nothing breaks; a reader follows a citation to the wrong place and has to recover
by searching, which is what they would have done with no citation at all.

The receipt counts BOTH forms across shipped `core/**/*.md`. Scored two directions: 1 against the
tree, and 0 against a scratch copy with every citation redacted.

verify: sh n=0; for f in $(git ls-files "core/**/*.md"); do a=$(grep -coE "\`[a-zA-Z0-9._/-]+\.(sh|md|yaml|json):[0-9]+" "$f"); b=$(grep -coE "\`:[0-9]+" "$f"); n=$((n+a+b)); done; [ "$n" -eq 0 ] && exit 0; exit 1

## BL-142 — a withdrawn claim is reported forever, and its withdrawal is invisible by construction

**Found by two adversarial hands after `v0.478.0` merged**, 2026-09-02, and NOT fixed here. It
corrects `BL-141`'s claim that the false-acquittal set was empty, and files the defect that review
turned up underneath it. Distribution-internal; no `PC-` id, so it ranks BELOW any PC-backed entry.

`audit-layer-debt.sh`'s UNDECLARED arm reports a row whose `reason` prose reads like an obligation.
The register is APPEND-ONLY, so the only way to correct a row is to write a later one. **The later
row is very often a DISCHARGE row, and discharge rows are exempted at `core/scripts/audit-layer-debt.sh:225`.**
So the register holds both a claim and its formal retraction, and the arm reads only the claim.

Measured on the reference consumer's register, the two rows verbatim:

    line 302  retro-push-sprint-ship-verification.md  19:10:00Z  closes_owed absent  -> REPORTED
      "...the body-relocation half of that debt was NOT re-checked this run and the debt is
       therefore left open."

    line 304  same entry                              19:30:00Z  closes_owed present -> SKIPPED
      "CORRECTION to the row I recorded for this entry earlier in the same session... There is
       no body-relocation half... The earlier sentence was an unverified inference and is
       withdrawn; the register is append-only, so this row is the correction."

**The two exemptions compose badly and each is right on its own terms.** The discharge exemption
exists so an operator is not charged for closing a debt correctly — that is `BL-140`-era work and
it should stay. But it makes the register's only correction channel unreadable, permanently, with
no act available to clear the row.

**THE SCHEMA'S SUPERSESSION FIELD CANNOT EXPRESS THIS, WHICH IS WHY THIS IS NOT A ONE-LINE FIX.**
`core/schemas/layer-adjudication-register.json` carries `supersedes`, and its own description
scopes it: *"Required only when this record states a DIFFERENT verdict from an earlier record
under the same key."* Both rows here are `still-additive`, so the author correctly did NOT use it
— the correction withdraws a factual sentence inside `reason` without changing the verdict, and
the schema has no field for that. Exactly 1 of 318 rows uses `supersedes` at all, on a different
entry, and `audit-layer-debt.sh` reads it in **0** places against a control of 9 for `closes_owed`.

**THREE REMEDIES WERE BUILT AND SCORED BEFORE FILING. THE OBVIOUS ONE IS REFUTED.**

- **Entry-grain** (silence a reported row when any later row on the same entry discharges
  anything), which is what the `contradicts-core` arm's satisfiability argument at lines 181-186
  would imply here: silences **3 of 19**, and **2 of the 3 are wrong** — they are silenced by the
  discharge of an unrelated debt. Refuted.
- **Retraction token** (a later row on the same entry says `withdrawn`/`CORRECTION`/`retract`):
  silences exactly **1 of 19**, precisely the withdrawn row, against a control of 5 rows carrying
  such a token anywhere in the register. Correct on this corpus — but it keys on free prose, which
  is the class this arm has now been wrong on three separate times, and 5 rows is not a corpus
  from which to measure a false-positive set.
- **Schema field** — a way to withdraw a `reason` clause without changing the verdict. That is the
  shape the defect actually has, and it is a SCHEMA change plus a producer change, not an edit to
  this reader. It is a different subsystem, so say which one you are closing.

Sibling to `BL-141`, which narrowed the same arm. Taking this means saying whether you are
changing the schema or accepting a prose predicate, and measuring the false-positive set of
whichever you choose.

verify: sh set -e; d=$(mktemp -d); printf '%s\n' '{"clause":"LC-E4","entry":"x/e.md","subject_digest":"a","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"The body-relocation half of that debt was NOT re-checked and the debt is therefore left open."}' '{"clause":"LC-E4","entry":"x/e.md","subject_digest":"a","verdict":"still-additive","recorded_utc":"2026-01-01T00:30:00Z","closes_owed":["OWED-X"],"reason":"Debt discharged. CORRECTION to the row recorded earlier for this entry: there is no body-relocation half; that sentence was an unverified inference and is withdrawn."}' '{"clause":"LC-E4","entry":"x/keep.md","subject_digest":"b","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"The split remains deferred to a later pull."}' > "$d/r.jsonl"; o="$(bash core/scripts/audit-layer-debt.sh --register "$d/r.jsonl" 2>/dev/null)"; grep -q 'keep\.md' <<<"$o" && ! grep -q 'x/e\.md\|^  e\.md' <<<"$o"

## BL-145 — a docs commit that MENTIONS a candidate id is reported to the consumer as upstream having absorbed it

**Found while scoping batch 43**, 2026-09-02, and NOT fixed here — the fix is a change to
`named_absorbed()`'s join, which is a bootstrapping step the consumer runs to classify its own
pull, and this batch is already changing three hooks in the same range. Distribution-internal in
its cause and CONSUMER-FACING in its effect, so it ranks below any PC-backed entry a sweep turns
up but above the distribution-only entries.

`named_absorbed()` (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402`) resolves
"did upstream take this candidate" with `git log -F --grep`, which reads **commit MESSAGES**. A
message is text about a program, not the program: any commit whose message contains the id
satisfies the join, including a commit that changes no code at all.

**THIS PROGRAM MANUFACTURES ITS OWN FALSE POSITIVES.** The plan's resume block names candidate
ids in prose, and every edit to it is a `docs(plan):` commit carrying those ids in its message.
Measured against `origin/main` at `v0.480.0`, driving the shipping script over the reference
consumer's live ledger: **6 entries report `NAMED-UPSTREAM` where EVERY commit naming them
touches zero `core/` paths.**

    PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD                             1 commit, 0 core
    PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK                      1 commit, 0 core
    PC-S334-ROTATE-ACCEPTANCE-TEST-FALSE-FAILS-ON-THE-WORKFLOW-IT-DOCUMENTS  1 commit, 0 core
    PC-S336-STEP-1-AUTOPUSH-IS-THE-UNGUARDED-TWIN-OF-THE-PUSH-STEP-2-HARDENED 1 commit, 0 core
    PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY                1 commit, 0 core
    PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT                1 commit, 0 core

`PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD`'s sole naming commit is `aa819280`,
*"docs(plan): batch 32 merged, so the block that told you to run it is now a description of
finished work"* — **one file changed, zero core paths**. Control in the same derivation:
`PC-S340-VALIDATE-SPAWN-LEDGER-OVERSHOOTS-CHECK-22-DECLARED-ROLE-SCOPE` resolves two commits
touching four `core/` files each, so the discriminator separates the two classes rather than
scoring everything docs-only.

**IT IS NOT A COSMETIC ROW.** `NAMED-UPSTREAM` is the signal a pull session reads to decide a
candidate was taken, and the standing instruction in `## Start here` is to put every closed id in
the RELEASE COMMIT MESSAGE precisely because this join reads messages. That instruction is
correct and it is also what makes the false-positive class reachable: the same channel carries
both a fix's citation and a plan's cross-reference, and the join cannot tell them apart.
`ledger-reverify.sh:978` already records one instance of this exact class from v0.153.0 — *"the
entry was then wrongly recorded upstream as absorbed on that basis — a citation read as a fix"* —
so the shape is known; what is new is that this program is now the largest producer of it.

**THE OBVIOUS FIX IS NOT OBVIOUSLY RIGHT, WHICH IS WHY THIS IS FILED RATHER THAN TAKEN.**
Requiring a naming commit to touch `core/` would drop all six, and it would also drop a genuine
close whose remedy was a `steps/*.md` or `templates/` change — both reach a consumer and neither
lives under `core/` in every case. Deriving "did this commit change anything the consumer
installs" is the real predicate, and its false-positive set has not been measured. Scope that
before building it.

**A THIRD CLASS, MEASURED AT BATCH 113, AND IT DEFEATS THE CANDIDATE FIX ABOVE.** The six rows
of the table are docs-only commits, and the `touches core/` predicate drops all six. It does NOT
drop this one. `b3debba3` (`v0.568.0`) names
`PC-S308-GATE-METRICS-CHECK2-STALE-VERDICT-READ-ORDER` in its message with the true sentence
*"discharged by an archived entry and cited by no release commit until now"*, and it touches
**6** `core/` paths — `core/scripts/derive-fixture-readsets.sh`,
`core/skills/ai-dlc/steps/gate-validation.md` and four others. Control in the same invocation:
`aa819280`, the table's own docs-only example, touches **0**; an impossible path prefix returns 0
from the same commit. So the naming commit passes every reachability filter proposed here while
the candidate's subject, `validate-suppression-lifetime.sh`, appears **0** times in its diffstat
against a control of **1** for `gate-validation.md`.

**The citation was TRUE and the close was still WRONG.** The archived entry it refers to,
`BL-194`, says in its own provenance paragraph *"This is NOT that candidate's subject"* and names
`BL-195` as the filed subject's disposition. `BL-195` is live and its premise re-derives in full.
The consumer's sweep read the naming commits for explicit discharge language, found some, and
closed the candidate 14 days later as `ADOPTED UPSTREAM (v0.568.0)`.

**This program predicted it and then did it anyway.** `docs/plans/graph-ledger-full-drain.md`
records the citation being DELIBERATELY WITHHELD at batch 71 for exactly this reason — *"a
citation would make `named_absorbed()` emit a `NAMED-UPSTREAM` row telling the consumer to close
an entry this release did not resolve"* — after which the resulting `discharged-but-INVISIBLE 1`
row was carried as a bookkeeping irritant for ~28 batches until batch 102 cleared it by adding
the citation. **Clearing that row is what caused the false close**, so the two obligations are in
direct conflict and only one of them is mechanised.

**What this means for the fix.** The real predicate is not "did the commit change something the
consumer installs" but "does the commit change something THIS id's subject depends on", and a
per-id subject path is a datum nothing currently records. Scope that before building either
version. A weaker but constructible half: a release commit citing an id it does not FIX needs a
distinguishable form, so the join can exclude it — which is a producer-side change, where there
is one writer, rather than a reader-side heuristic over every historical message.

**Sibling to `BL-089`** — a status that cannot distinguish "I measured nothing" from a genuine
reproduction. Same class, and this is the absorption side of it.

**Stated limitation of the receipt below.** It anchors on one real id whose naming commit is
docs-only today. A future core-touching commit naming that id closes the receipt without the join
being fixed; if that happens, re-anchor on another row of the table above rather than reading the
close. It is scored three ways against THIS corpus's convention, where exit 0 is the fix being
present — the subject id exits 1 (still live), an id backed by a core-touching fix exits 0, and
an impossible id exits 9 rather than reporting a false close. The first cut of this receipt was
written the other way round, carrying `ledger-reverify.sh`'s opposite convention into a
`docs/backlog.md` entry, and it read as an incidental close in the histogram.

verify: sh set -e; r="$PWD"; id='PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD'; n=0; c_core=0; for c in $(git -C "$r" log --format=%H -F --grep="$id" origin/main); do n=$((n+1)); git -C "$r" show --name-only --format='' "$c" | grep -q '^core/' && c_core=$((c_core+1)); done; [ "$n" -gt 0 ] || exit 9; [ "$c_core" -eq 0 ] || exit 0; w=$(mktemp -d); mkdir -p "$w/c/_bmad-output/ai-dlc-update" "$w/c/.claude"; printf '%s\n' '# l' '' "## $id — probe" '' 'Body.' '' 'verify: sh cd "$CONSUMER" && grep -q zzz-never-present README.md' > "$w/c/_bmad-output/ai-dlc-update/push-candidate-ledger.md"; printf 'version: 0.471.0\ncommit: 31b51d48\nskill_version: 0.471.0\nskill_commit: 31b51d48\n' > "$w/c/.claude/.ai-dlc-version"; h="$(git -C "$r" rev-parse HEAD)"; o="$(cd "$w/c" && bash "$r/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" "$r" 31b51d48 "$w/c" "$h" 2>/dev/null)"; grep -q "$id" <<<"$o" || exit 9; grep -qE "^NAMED-UPSTREAM[[:space:]]+$id" <<<"$o" && exit 1; exit 0



## BL-159 — four handoff-completion defects adjacent to `BL-158`, found by the batch-49 hands and deliberately not fixed there

Distribution-internal, no `PC-` id; ranks below any PC-backed entry. Filed together because they
share one subject and one release would otherwise have widened past its scope. NOTE tier for each
until one is measured to have moved a verdict on the consumer.

1. **`PUSH_OK` counts COMMITS, so a skipped step 2 reads `ahead 0` and passes.**
   `core/hooks/ai-dlc-continue.sh`'s push arm reads `git rev-list --count '@{u}..HEAD'`; an
   uncommitted tree is zero commits ahead. The consumer at batch 49 read `ahead 0` with 7 dirty
   files. `handoff.md:64-65` names the trap in prose. A working-tree test beside the ref test is
   the shape; its false-positive set on a consumer whose `_bmad-output/` is deliberately dirty
   mid-sprint has not been measured, which is why it is filed and not shipped.
2. **The entry marker is TRACKED in the consumer although the schema declares it ignored.**
   `core/schemas/pipeline-state-paths.json` marks `_bmad-output/.handoff-in-progress` transient
   with an `ignore` pattern; on the consumer `git ls-files` returns it and `git check-ignore` exits
   1. Two of the schema's 14 transient patterns are missing from the consumer's `.gitignore`
   (control: 12 present). `core/scripts/sync-transient-ignore.sh` is the producer; whether it was
   never run there or predates the two entries is a consumer-side question.
3. **The auto-handoff twin never clears the marker.** `_gate-procedures.md`'s auto-handoff step 5
   creates the pause flag and omits `rm -f _bmad-output/.handoff-in-progress` (control: it names
   `pipeline-paused.flag` once). Today that is inert — an auto-handoff reads no `handoff.md`, so
   no marker exists — and becomes a wedge only if a marker from an interrupted manual handoff
   survives into an auto-handoff, which `BL-158`'s marker arm would then block on correctly.
4. **Check 0's on-disk trigger sits behind a readable-transcript test.** `ai-dlc-continue.sh:288`
   requires `$TRANSCRIPT` to exist before any arm runs, including the `HANDOFF_ON_DISK` path built
   for the case the transcript cannot see. A Stop with no transcript path skips the guard.

verify: sh h=core/hooks/ai-dlc-continue.sh; [ -f "$h" ] || exit 9; grep -q 'PUSH_OK=' "$h" || exit 9; grep -qE 'git -C "\$PROJECT_DIR" (status --porcelain|diff --quiet)' "$h" && exit 0; exit 1


## BL-195 — Check 2's suppression-lifetime arm reads a verdict the CURRENT gate has not yet written, and all four candidate remedies are refuted by measurement

**Provenance.** `PC-S308-GATE-METRICS-CHECK2-STALE-VERDICT-READ-ORDER`, filed by the reference
consumer 2026-09-06. **This entry is FILED AND DELIBERATELY NOT FIXED.** The defect is real and
better evidenced than the filing claims; every remedy proposed for it — the filing's two, plus two
derived here — was built or measured and refuted. It is recorded so the next session does not
rebuild any of them.

**The defect, verified against the consumer's own committed history.** Check 2 invokes
`validate-suppression-lifetime.sh` (`core/skills/ai-dlc/steps/gate-validation.md:245`), which
decides whether a suppression's named check is still failing by reading the newest recorded
verdict in `gate-metrics.jsonl` (`core/scripts/validate-suppression-lifetime.sh:471`). That file
is written ONLY by Check 12 (`gate-validation.md:736`), which runs after. So Check 2 necessarily
reads the PREVIOUS gate's verdict, and a fix landing between two gates is invisible to it.

The filing's cited case reproduces exactly: the FAIL row at `2026-09-05T22:58:00Z` carries sha
`7729b544a…`, and `git merge-base --is-ancestor` puts that tree strictly BEFORE the reword fix at
`33f925bcf` (exit 0; reverse direction exit 1 as control).

**THE CONSUMER DIAGNOSED THIS ELEVEN DAYS BEFORE FILING IT, AND CHOSE TO SUPPRESS.**
`docs/escalations/pending.md:3684`, 2026-08-26: *"Check 16 itself passed cleanly THIS gate on its
own merits … but that PASS has not yet been recorded to `gate-log.md` (Check 12 runs after this
adoption), so `validate-suppression-lifetime.sh` still reads story 2.1 gate-3's real 23-finding
check-16 FAIL as the last recorded verdict and reactivates these two unrelated older entries."*
That entry's own options list reads *"(a) fresh SUPPRESSED for check 16, this gate only [chosen];
(b) investigate/fix the Check 12-before-Check 2 ordering instead"*. A sibling entry at the S305
sprint-review gate does the same on check 22. **The recurrence is the choice, not the mechanism.**

**Recurrence: 3 distinct gate events across 2 sprints (S305 ×2, S308 ×1),** derived by scanning
both escalation corpora for entries naming a Check-2 suppression-lifetime FAIL together with a
last-recorded-verdict cause; 4 entries resolve to 3 gates. Impossible-phrase control returns
nothing. **An earlier reading of this batch narrowed it to 1 and was wrong** — that reading rested
on an ancestry test which cannot answer the question, because it asks whether the FAIL row was
written before the fix, which is necessarily true of every entry: the row IS the record of the
failing gate. The staleness is in the READ, not the write.

**THE FINDING THAT OUTRANKS THE FILING'S OWN CLAIM.** The metrics file is not merely stale at
unlucky moments; it is the LOSSY artifact in principle. Check-2 verdicts, full population:

| source | PASS | FAIL |
|---|---|---|
| per-gate `*.verdict.json` | 158 | **38** |
| `gate-metrics.jsonl` | 93 | **3** |

**A 12.7× undercount**, and the cause is structural: a gate that FAILs Check 2 halts before
reaching Check 12, so the row recording that failure is never written. Control — check 16, which
does not halt the gate, agrees far better (18 verdict FAILs against 5 metrics FAILs). The arm
consults the one artifact that structurally cannot record the failures that matter most.

**THE FOUR REFUTED REMEDIES. Do not rebuild these.**

**(a) Re-sequence Check 2's read to after Check 12's write — A CYCLE.** Check 12's own instruction
(`gate-validation.md:750`) is to emit a row for *every other check the manifest loaded*, which
includes Check 2. Measured: 12 rows carry `"check":"2"`, against an impossible-id control of 0.
Check 12 cannot write until Check 2 has produced a verdict to record, so "read after the writer
writes" is self-referential.

**(b) Re-run the underlying check live — FAILS OPEN ON 22 OF 57 CHECKS.** `enforcement-map.yaml`
gives 22 ids `enforcer: []` against 35 with one (57 total, partitioning exactly; impossible-key
control 0): `1 1c 3 3a 4 6 7 8 9 10 11 11a 12 13 14 15 19 20 21 27 29 H1`. **`[core] 11` is
suppressed twice in the live corpus and has no enforcer to run.** Treating "cannot re-run" as PASS
acquits every suppression on those 22 ids; treating it as FAIL fabricates blocks on them. The 35
that do have enforcers resolve to distinct CLI contracts with no generic invocation, so (b) would
additionally need a hand-written per-check invocation table.

**(c) Refuse when the recorded row's `sha` is not current — DISARMS ON A SQUASH-MERGE CONSUMER.**
Over the live metrics: 11 distinct shas, **0 ancestors of HEAD**, 10 orphans, 1 unresolvable;
control `merge-base --is-ancestor HEAD HEAD` exit 0. The consumer squash-merges, so the commit a
gate records is orphaned by the merge that lands the work. This shape reports NOT-APPLICABLE for
every row on a healthy tree — a total disarm that reads as green. `tool-hazards.md` states the
general rule: never test whether work landed by ancestry in a squash-merge repo.

**(d) Read the CURRENT gate's `*.verdict.json` instead — NO JOIN EXISTS.** 198 verdict files carry
the right answer (the file the S305 entry names records `check_id 16 → PASS` at the exact gate
where the metrics said FAIL), and they cover every suppressed id including the ones (b) cannot
reach — `2` (196 files), `16` (195), `11` (69), `22` (69), `24` (1), `30` (1), impossible-id
control 0. But **96 distinct gate events in the metrics against 197 distinct verdict
`generated_at` values intersect at 9**, control (ts ∩ ts) = 96. `generated_at` is the
adjudicator's write time, not the gate's `ts`. With no key, the fix either wedges 87 of 96 gates
or falls back to the stale row and reintroduces the defect. `gate_nonce` identifies a file
uniquely (197 of 198) but is not available to the validator, and "newest verdict.json" picks the
wrong file within two hours at the S305 gate — the original defect one file over. The directory
is also absent on a fresh consumer.

**What a fix would actually require**, stated so the next attempt starts from the real
constraint rather than from the filing's framing: a gate-scoped identifier that both the verdict
artifact and the suppression validator can see, passed IN by the caller rather than discovered.
That is a change to Check 2's invocation line in a resident skill file plus a new flag, and it is
fail-open the moment one caller omits it. **Nothing here is a small fix, and the smallest honest
change is documentation** — Check 2's body stating that its verdict source is the PREVIOUS gate's
record, and the arm reporting the `ts` of the row it read so a false positive is legible when it
fires.

**The consumer-owned half is not upstream work.** Why the 2026-07-22 failure happened at all, and
whether their sprints should keep suppressing rather than escalating, is that consumer's own
carry-over.

verify: manual

## BL-214 — `story_normalize` reads a carry-over ITEM number as a sprint, and the licence that authorised it used a non-discriminating control

`story_normalize()` (`core/scripts/migrate-artifact-paths.sh:244`) rewrites `story-<A>-<B>` to
`story-s<A>-<B>`, taking `A` as the sprint. In the pre-s199 era `A` is the carry-over ITEM or epic
number, not the sprint, so the migration places those files under the wrong slot.

Driven on the shipping program, seeded from the consumer's own file, with a refused control in the
same run: a story whose body carries `**Sprint:** 53` is planned into `s102/`, because its basename
is `story-102-1-…`. On the reference consumer the real file
`s102/stories/story-1-effective-spread-500.md` carries `**Sprint:** 53` and the title
`Epic: 102 — Sprint 53 … (Item 102)`; `docs/retro/s53/retro.md` opens by naming that story, while
`docs/retro/s102/retro.md` is a different sprint entirely. There is no `s53` planning directory,
against a control that `s102` exists.

**Scale, and it is not a delivery lag.** 1045 story files compared header-against-slot: 598 agree,
165 DISAGREE, 282 silent. Control on 600 non-story artifacts under a slot: 4 disagree of 90 valued.
All 165 run ONE direction — slot strictly greater than header, 165 to 0. An authored-in-one-sprint
delivered-in-the-next reading predicts a small positive gap; the mass sits at gaps of 44, 45, 48 and
50, and only 8 files sit at gap 1. Adjudicated against sprint retros, the header-named sprint's retro
claims the story 22 times against the slot-named sprint's 3; the 3 counter-cases are all gap 1 and
are genuine carry-over, correctly slotted. Against add-commit subjects on a 300-file sample, the
header sided with the subject against the name 58 times to 4.

**The licence's own control could not discriminate, which is why this shipped.**
`core/skills/ai-dlc/artifact-path-grammar.md:191` justifies reading `A` as the sprint on the ground
that all 786 `story-<A>-<B>` basenames have `A` "inside the sprint range the tree actually uses
(7–302)". An item number falls inside that same range, so the observation is true and cannot
separate the two hypotheses it is offered as evidence for. This is the repo's own rule — a control
drawn from a form you already know cannot discover the form you do not — collected on the licence
that authorised 951 moves.

**Not fixed here, and deliberately not folded into the `STORY-NO-SPRINT` work beside it.** That
subject is the refusal class for files with NO derivable sprint; this is the opposite failure — a
sprint derived confidently and wrongly — and the remedy is a change to `story_normalize`'s licence
with its own false-positive measurement over the post-s199 era, where `A` genuinely is a sprint. The
repair also cannot be a pure rename of the recovery order: 598 files agree today and must not move.

**Tiered DEFECT.** Files are placed under a wrong but well-formed slot, so nothing reports and the
error is invisible to every conformance check — the destination is on the grammar either way.

verify: sh set -e; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; mkdir -p "$d/_bmad-output/planning-artifacts/stories"; ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t ); printf '# S\n\n**Sprint:** 53\n\nB.\n' > "$d/_bmad-output/planning-artifacts/stories/story-102-1-x.md"; ( cd "$d" && git add -A && git commit -qm s ); o="$(bash core/scripts/migrate-artifact-paths.sh --root "$d" --grammar "$PWD/core/skills/ai-dlc/artifact-path-grammar.md" 2>&1)"; grep -q 's102/stories' <<<"$o" && exit 1; exit 0

## BL-215 — an ADR that defers work reaches the next sprint's intake, but the intake's disposition vocabulary has no slot for "this names undone work"

Filed by the consumer as `PC-S309-ADR-DEFERRED-WORK-HAS-NO-CARRIER-INTO-BACKLOG`. **The filing's
headline is refuted and the narrowed finding is what stands.**

The filing says an ADR's deferred work is invisible to the next sprint's intake. It is not.
`route.md:434` puts the carry-over variant at `carry-over-evaluation → requirements → architecture`,
and `requirements.md:50-56` MANDATES a grep of `docs/adr/` as part of the settled-decision corpus,
cites the literal command, and FAILs the gate if it is absent. Derived: `docs/adr` appears 0 times in
`carry-over-evaluation.md` against a control of 3 for `carry-over-backlog` in the same file, and 1
time in `requirements.md`. So the step AFTER the blind one does read the corpus.

**What it cannot do is read it AS deferred work.** That mandated grep is keyed on subsystem keywords
and its disposition vocabulary is `superseded / still binding / not relevant` — there is no slot for
"this names work nobody has filed". The symptom the consumer observed is real; its account of where
the gap sits is one step wide.

**No enforcer is constructible on what exists today, and that is the finding.** The predicate is
"this ADR's own text defers work" — intent, not an act. This repo's mechanisms deny an ACT and never
evaluate a REASON. There is no ADR frontmatter and no ADR template, and no core script takes
`docs/adr` as a corpus: 0 scripts name it, against a control of 20 naming `docs/retro`. A
same-commit join would need a machine-readable `defers:` field that does not exist and that an
author could omit silently, which relocates the judgement rather than mechanising it.

**Ownership is contestable and should be settled before any upstream work.** `extensions/` is a
consumer-owned layer grain (`core-manifest.md:13-14`), and the consumer already runs steps-domain
entries hooking `steps/retro.md`. An architecture-step domain entry is available to it today and
survives `apply`. Under the standing rule — establish that no simpler change suffices — that is the
question to answer first.

**Tiered NOTE.** Recorded so the refutation is not re-derived and the enforcer question is not
re-opened blind.

verify: manual

## BL-258 — `agent-definition-render`'s `check-is-presence-only` mutant is killed by two arms under the pool and by one arm solo, so a green tree goes red on a run that changed nothing

**DEFECT.** During batch 117's pole calibration — three serial full `AI_DLC_FIXTURE_NO_SKIP=1` gate
runs in a `file://` clone of `origin/main` at `83747ef4`, no change between runs — run 2 went red on
exactly one unit while runs 1 and 3 were green 21/21. The failing line, verbatim from the pool's
captured output:

```
FAIL  MUTANT check-is-presence-only killed by check_joins_declaration_to_projection AND by: three_states_are_distinct  — those arms are entangled and at least one is not independently load-bearing
```

Solo from the repo root, five consecutive runs: 5 of 5 green, the mutant killed by
`check_joins_declaration_to_projection` alone every time. So the second kill appears only under
the 12-way pool, which is the same shape `BL-230` records for `reconcile-emit-report`.

**WHY THE SECOND KILL IS NOT EXPLAINED BY THE MUTATION.** `check-is-presence-only`
(`core/fixtures/agent-definition-render/run.sh:482`) turns the renderer's byte comparison
(`core/scripts/render-agent-definitions.sh:222`, `cmp -s - "$target"`) into `true`. Arm
`arm_three_states_are_distinct` (`run.sh:329`) asserts `--check` returns 3 with no `aiDlcRoles`, 1
on a fresh project with the declaration restored, and 0 after a render. Its `1` comes from the
MISSING branch (`[ ! -f "$target" ]`, one line above the mutated `cmp`), not from drift, so the
mutation should leave all three of its exit codes unchanged — and solo it does. Under the pool one
of the three moved. Which one, and why load moves it, is not derivable from the captured output:
the harness prints the entanglement verdict and not the per-arm rc triple.

**WHAT IS OWED.** Make the harness print the failing arm's observed rc(s) beside the entanglement
verdict, so the next pool red says WHICH world moved rather than only that one did; then reproduce
under the pool (`AI_DLC_FIXTURE_NO_SKIP=1` on an unchanged tree, as the calibration did) and read
it. Do not narrow the mutant or drop the entanglement check to make the fixture green: the
entanglement check is the assertion that each arm is independently load-bearing, and it fired.
The rate is 1 of 3 pool runs on that evening, against 0 of 5 solo; a single-digit pool rate is
the same band `BL-230` measures, and a fix for one may be a fix for both — grep both entries
before building.

**WIDENED AT BATCH 123, AND THE "RARE FLAKE" FRAMING ABOVE IS REFUTED. THIS IS A CONCURRENCY
DEFECT WITH A ~90% RATE, NOT A SINGLE-DIGIT ONE.** It went red on a gate run, was nearly
dispositioned as the `BL-230` contention class on the strength of 9 green solo runs, and the
solo runs turn out to be the OUTLIER. Driven at a discriminating N — the predicted event count
at the rate this entry claims is **0.27 for an 8-run sweep**, below one, so the 8 greens that
first looked like an acquittal could not discriminate and were discarded:

```
solo         N=9    0 red
pool width12 N=12   5 red   (42%)
tip          N=32  29 red   (91%)
base         N=32  29 red   (91%)
```

**BASE AND TIP ARE IDENTICAL AT THE SAME N**, which is what establishes this belongs to `main`
and not to whatever change is in flight — the misattribution both this entry and `BL-230` exist
to stop, measured rather than argued this time.

**AND THE HARNESS DOES NAME THE SECOND KILLER; the claim above that it is "not derivable from
the captured output" is wrong.** Over 64 concurrent runs the entanglement verdict names THREE
distinct shapes, so the population is wider than the one arm this entry was filed on:

```
27  foreign_definition_untouched three_states_are_distinct
14  foreign_definition_untouched
14  three_states_are_distinct
 3  SURVIVED (check_joins_declaration_to_projection passes against the mutated subject)
```

Those 3 SURVIVED rows are the direction that matters: under load the mutant is not merely
killed by extra arms, it sometimes is not killed at all — a mutation scoring green against a
subject that no longer does the thing the arm asserts.

**THE LEAD IS `mut()`'s `cp "$SUBJ_DIR"/*` at `run.sh:419`**, which copies the LIVE
`core/scripts/` directory — 53 files — once per mutant, while 105 fixtures naming that path run
in the same pool. The copy is not atomic and the source is shared. `MUTROOT` is a private
`mktemp -d`, so the DESTINATION is correctly isolated and the SOURCE is not; that asymmetry is
why solo is clean and the pool is not. Verify that before building: the rc triple this entry
already asks for will say which world moved, and the copy race says why.

**What does NOT change: do not narrow the mutant or drop the entanglement check.** It is firing
correctly on a real property. What is owed is isolating the source of the copy, not silencing
the arm that reports it.

**THE RECEIPT KEYS ON THE HARNESS'S REPORT LINE, NOT ON THE FLAKE.** A flake cannot be a
receipt's subject — a run that happens to go green closes it. What is owed and checkable is
that the entanglement verdict carries the OBSERVED rc of every arm that fired, so the receipt
extracts the `bad "MUTANT $label killed by $want AND by:` line from the fixture's harness and
requires it to interpolate a per-arm rc value (a `$rc`-shaped token for the second killer, or
the whole `$out` line set) rather than only `$others`, the arm NAMES. Scored: the shipped line
(names only) exits 1; a line that appends the observed output exits 0; a tree whose only copy
of the words sits in a COMMENT exits 9, because the extraction is anchored on the uncommented
`bad "MUTANT` emitter and finds none — the emitter being gone is a precondition moved, not a
close.

verify: sh f=core/fixtures/agent-definition-render/run.sh; [ -f "$f" ] || exit 9; l="$(grep -E '^[[:blank:]]*bad "MUTANT \$label killed by \$want AND by:' "$f")"; [ -n "$l" ] || exit 9; case "$l" in *'$out'*|*'rc='*|*'observed'*) exit 0 ;; esac; exit 1

## BL-273 — I33b's batched grammar narrowed on `${VAR/../…}` against an equivalence claim, and the one input separating the two implementations was in no corpus and no assertion

**NOTE.** Found by the contract adversary auditing `0.594.0` and re-derived here. The release
claims the batched predicate is equivalent to the per-file one, and on the live corpus it is —
byte-identical stdout and stderr, 29 intermediate rows reproduced, 4 findings against 4 on a
seeded tree. **The grammars are not the same grammar, and the corpus cannot tell.**

**The divergence.** The old predicate asked `grep -qE "\$(\{)?VAR(\})?/\.\./"`, in which the
brace group is OPTIONAL ON BOTH SIDES INDEPENDENTLY — so `${A/../foo}`, which is bash pattern
substitution and not a directory walk at all, satisfies it as `${A` plus `/../`. The batched
program requires the closing `}` to immediately precede `/../` when a brace was opened, so it
does not match. Measured on a constructed file: old grammar **1**, new grammar **0**.

**It is a narrowing TOWARD correctness, which is why this is a NOTE and not a defect.** The old
behaviour was a false positive; the new one is right. But `0.594.0` shipped under an equivalence
claim, and the one input that separates the two implementations is the one input nobody wrote
down — so a future port has an oracle that says "match the old one" and a program that
deliberately does not.

**Why the corpus cannot see it.** `grep -rlE '\$\{[A-Za-z_][A-Za-z0-9_]*/\.\./' core/fixtures`
returns **0** files, against a control of **97** for `${VAR}` in the same corpus, so the form is
absent rather than the grep being broken. An absence from today's corpus is not a fact about what
the predicate must handle.

**FIXED IN THE SAME BATCH, which is why this entry is filed rather than left open.**
`A27c_i33b_pattern_substitution_is_not_a_walk` seeds BOTH forms in one tree: `${A/../foo}` must
NOT be named, and `${A}/../schemas/x.json` — the same variable, the same braces, differing only in
whether the brace closes before `/../` — must be. The silence half alone would pass against a
predicate that stopped matching anything, so the ALLOW TWIN is the half that makes it mean
something. Proven both ways: `ok` on the shipped grammar, and with the loose brace grammar
restored it reports `I33b named zz-i33b-patsub` and fails.

**The receipt DRIVES the predicate rather than grepping the file that implements it**, because the
first draft of this entry was prose-satisfiable and `R2`'s ratchet caught it at the gate — 2
against a ceiling of 1. It extracts `i33b_scan` from the validator, runs it over both seeded
files, and exits 9 rather than 0 if the walk-up case stops being seen, so a predicate that matches
nothing cannot close it.

verify: sh v=scripts/validate-enforcement-map.sh; [ -f "$v" ] || exit 9; grep -q 'I33B_WALK_AWK' "$v" || exit 9; d=$(mktemp -d) || exit 9; sed -n '/^I33B_WALK_AWK=/,/^}$/p' "$v" > "$d/p.sh"; grep -q 'i33b_scan()' "$d/p.sh" || { rm -rf "$d"; exit 9; }; printf 'A="$(dirname "$X")"\nB="${A/../foo}"\n' > "$d/pat.sh"; printf 'A="$(dirname "$X")"\nB="${A}/../schemas/x.json"\n' > "$d/walk.sh"; . "$d/p.sh"; w=$(i33b_scan "$d/walk.sh" | grep -c .); p=$(i33b_scan "$d/pat.sh" | grep -c .); rm -rf "$d"; [ "$w" -eq 1 ] || exit 9; [ "$p" -eq 0 ] || exit 1; grep -q 'A27c_i33b_pattern_substitution' core/fixtures/enforcement-map-derivations/run.sh && exit 0; exit 1

## BL-272 — `fork-profile.sh --section by-line` prints 60 of its rows and says nothing, so a by-line sum is silently partial and disagrees with the by-arm column it should equal

**DEFECT.** Found by summing `--section by-line` per arm range, reading the result against the
by-arm column, and taking the difference for a `BL-268` misattribution artifact. It was not one.
**The by-line section is truncated and the header above it is identical to an untruncated one.**

**The site.** `scripts/fork-profile.sh:360` is `head -60 "$RUN/by-line"`, under the header
`--- forks-by-line ---` printed at `:359`. The full file holds **926** rows at this tip; the
section prints **60**. Nothing in the output says which it is, and there is no count, no ellipsis
and no total beside it.

**THE ASYMMETRY IS WHAT MAKES IT WRONG RATHER THAN MERELY TERSE.** `emit_by_arm` is unbounded — it
emits all **115** arm rows. So `--section all` prints a COMPLETE by-arm table beside a
SILENTLY PARTIAL by-line table, under two headers of the same shape, and the natural reading is
that both describe the same run at two granularities. They do, but only one of them is whole.

**Measured, and it is the reason this is filed rather than noted.** Summing the printed 60 rows
into the arm ranges resolved from `render-invariant-index.sh --arm-lines` gives
`I82=642 I82b=0 I99=95 I83=129 I84=512`. Summing the same ranges over the untruncated file from
`--dump` gives `I82=657 I82b=9 I99=97 I83=134 I84=527` — **byte-identical to the by-arm column**.
The first reading invents a per-arm discrepancy of exactly the tail it could not see, and that
discrepancy reads as a known, filed, real defect (`BL-268`) rather than as an instrument artifact.
It cost a contract three wrong numbers before anything was built: a removable-fork target of 1108
against a true 1203, a landing of ~3670 against a true 3571, and an arm attribution that moved 95
forks out of I82 and into I99. Every done-when threshold keyed on those was unreachable.

**`--dump` IS THE UNTRUNCATED SOURCE AND NOTHING SAYS SO.** `--dump <dir>` writes `by-line`,
`by-arm` and `trace` whole. It appears in the usage line and nowhere else: the header comment
explains `@N@`, the known undercount, and why the instrument is dynamic, and never mentions that
the printed section is a preview. A reader who wants a sum has no way to learn from the program
that the thing on screen is not it.

**What is owed.** Any of three, and the cheapest is the first: print the row count and the total
beside the header (`60 of 926 rows shown; --dump for all`), or emit the whole file as `by-arm`
already does, or fail the section when a caller sums it. `BL-268`'s own remedy text — mark what is
structurally unreliable rather than leaving a reader to take it — is the same shape and the two
should be read together.

**Relation to `BL-268`.** Distinct defects that produce one symptom. `BL-268` is a real
`LINENO` artifact in which a `<(...)` body's forks are attributed to the enclosing chain's closing
line; it is live at this tip (95 `tr` forks report at bare `fi` line 7132, while line 6838 — the
only `tr` site in the range, negative control 0 — reports none). This entry is a display bound. A
reader who hits both at once, as one did, reconciles the truncation artifact by blaming the
attribution one and stops looking.

**Receipt.** Keys on the emission site, not on prose about it, and not on the row counts — those
move with the corpus. Scored before filing across four inputs: tip **1**, the section rewritten to
`cat` **0**, a file mentioning `head -60 "$RUN/by-line"` only inside a comment **0**, a stub with
no `forks-by-line` header **9**. Exit 9 if the profiler or that header is gone.

verify: sh f=scripts/fork-profile.sh; [ -f "$f" ] || exit 9; LC_ALL=C grep -q 'forks-by-line' "$f" || exit 9; LC_ALL=C grep -qE '^[[:blank:]]*head -[0-9]+ "\$RUN/by-line"' "$f" && exit 1; exit 0


## BL-271 — no `PreToolUse` hook checks the artifact-path grammar, so a non-conforming path is created by `Write` and caught only at `pre-push`, after other artifacts have cited it

**DEFECT.** Filed from the consumer candidate
`PC-S312-ARTIFACT-PATH-GRAMMAR-HAS-NO-WRITE-TIME-ENFORCEMENT`, read from the consumer's sprint
branch ledger at `8990d8cad`. **It is reachable through no other ref** — `main` does not carry it,
and the drain plan's election loop cannot elect the branch that does (`BL-270`). Not fixed here.

**The gap is timing, not absence.** `validate-artifact-paths.sh` exists and does catch a sprint
token in a basename outside the reserved `s<N>/` slot, but it has exactly one call site:
`.githooks/pre-push`. That is (a) opt-in — the consumer must set `core.hooksPath` — and (b)
batched over everything already committed. The consumer's measured episode: a code-reviewer
teammate wrote `docs/reviews/s312-story-2-1-gate1-review.md`, nothing stopped the `Write`, the
file was committed, merged, and then cited by name in `pipeline-snapshot.md`,
`pipeline-continuation-log.md` and a later gate-2 QA review that quoted the path verbatim as its
own evidence trail. Detection came at `git push`.

**The attachment point already exists and is already paid for.** Two `PreToolUse` hooks fire on
every `Edit|Write|MultiEdit` in this distribution — `ai-dlc-core-guard.sh` and
`ai-dlc-gate-remediation-guard.sh` — and neither checks the grammar.

**Re-derived here, with controls.** The candidate's own receipt run against this tree exits **1**:
neither guard names `artifact-path` or `artifact_path`. Both files exist (control: `ls` resolves
both) and both are real hooks (control: 23 and 30 hits for `PreToolUse|tool_input|hook`), so the
zero is an absence and not an unreadable file. Widening to all 23 files under `core/hooks/`, three
name the token — `ai-dlc-protect.sh`, `ai-dlc-acknowledge.sh`, `ai-dlc-continue.sh` — and **all
three are prose mentions inside comments**, not checks. A whole-file grep satisfied by a comment is
the shape this repo's own rule warns about, which is why the receipt keys on the guard files the
candidate names rather than on the hooks directory.

**The consumer's proposed disposition, recorded and then NARROWED ON MEASUREMENT.** It asked for a
grammar check on one or both `Edit|Write|MultiEdit` guards rejecting the whole MOVABLE class. That
scoping is too wide in two ways, and both were measured before anything was built.

**42 OF THE 73 BLOCKING PATHS ARE NOT ATTRIBUTABLE TO THE WRITE.** Population: 1882 paths ADDED
under the scan roots after the 2026-08-07 grammar migration on the reference consumer,
materialized as empty files in a scratch tree carrying that consumer's REAL grammar,
`artifact-paths.md` and `layer-contract.yaml`, then judged by the SHIPPING validator (resolver
agreement control: the scratch tree resolves the same 17 areas and 4 scan roots as the live one).
**1806 CONFORMING / 73 NONCONFORMING / 3 AMBIGUOUS.** Splitting the 73 by the validator's own
`component <bad>` detail rather than a second grammar: **31 the BASENAME is the offender, 26 an
ancestor that is a well-formed `^s[0-9]+$` slot, 16 another ancestor.** Denying a `Write` because
of a directory the author did not name in that call refuses a blameless basename and offers no
action, so the guard denies only the 31.

**AND THE ANCESTOR CLASS IS NOT A STABLE POPULATION, WHICH IS THE STRONGER REASON.** Declaring ONE
depth-3 area (`_bmad-output/planning-artifacts/party-mode`) in the consumer's `artifact-paths.md`
moves **73 → 47**, and the 26 rows that flip are EXACTLY the ancestor-bare-slot class (set
comparison empty in both directions; area sets asserted to differ at 17 vs 18 BEFORE the
verdicts were compared). Two legal remedies exist — move the slot up, or declare the deeper area —
and the consumer chose the first. Picking one at write time is a judgment this guard cannot make,
and `validate-enforcement-map.sh` I82b already owns that under-specification.

**A FIRST-ORDER PURITY TEST CANNOT SEE THAT, AND MINE DID NOT.** Judging one path alone in an
empty tree returns an identical verdict, and dropping the consumer file entirely ALSO returns 73 —
the inference loop at `validate-artifact-paths.sh:227-237` recovers a depth-2 area from the scan
root, so a depth-2 declaration is not discriminating. Only a DEPTH-3 area separates them, because
inference takes exactly one component under the root. The verdict is a function of the path AND
the declared area set; what is genuinely path-only is the BASENAME half, since a slot is always a
directory and the basename is never at `slotidx`.

**THE FALSE-POSITIVE SET IS EMPTY, AND THE CORPUS HAD TO BE CONSTRUCTED TO SAY SO.** Zero over the
reference consumer's 6510 tracked files under the scan roots, zero over this distribution's 69.
**That consumer tree PASSES today** — 6507 conforming, 0 blocking — so the live set holds no
offender at all and could not discriminate. The population above was built from HISTORY for
exactly that reason; a reader who sees only "FP set empty" would correctly read it as untested.

**THE GAP COSTS REAL REMEDIATION, MEASURED: 62 OF THE 73 WERE RENAMED ONTO THE GRAMMAR BY HAND.**
Joined against a 1192-pair rename map derived with `-M` across all refs since the migration
(controls: a present pair joins LIVE, an absent path joins GONE): **62 RENAMED / 11 GONE / 0 still
live at HEAD.** Destinations are conforming and are the same move the guard now suggests —
`docs/reviews/s312-story-2-1-gate1-review.md` → `docs/reviews/s312/story-2-1-gate1-review.md`. So
the harm rate is 3.3% of writes, not the single episode this entry was filed from, and it is a
delivery fact rather than a projection. **An earlier figure of 1-of-73 in this entry's own working
notes was WRONG** — a `--follow` query scoped too narrowly returns one pair where a proper rename
map returns 1192.

**DENY, NOT WARN, AND THE CONSTRAINT WAS CHECKED RATHER THAN INHERITED.** The plan-channel hook was
held to a WARNING because plan mode's harness REQUIRES its path to exist, so a deny breaks the mode
outright. No equivalent requirement exists here: every pipeline step prescribes a conforming
destination, and I82 fails the build if core ever prescribes otherwise, so a deny cannot contradict
an instruction core gives.

**THE TIP ADVERSARY FOUND THE CONSUMER WEDGE THE CONTRACT PASS PREDICTED AND MISSED: A
GITIGNORED PATH.** `validate-artifact-paths.sh:136-140` builds its corpus with `git ls-files`
— the TRACKED set — while a write-time guard's corpus is whatever reaches `Write`. Those differ
by exactly the ignored set, and the difference runs the dangerous way: for an ignored path the
batched arm can NEVER render a verdict, so a deny is the only verdict and there is nothing to
appeal to. Measured by driving the shipped hook over the reference consumer's ignored paths
under the scan roots: **five denials**, all generated evidence the pipeline has written for
hundreds of sprints (`s241-1-evidence-manifest.txt`, `sprint-148-smoke-test-*.log`,
`cdk-diff-s310-services-stack.txt`), ignored by `*.txt` and `*.log`, and every future
`sprint-NNN-*.log` would hit it. **The 0-of-6510 false-positive figure is correct and was
measured over the TRACKED population, which is not the deny surface** — that is the gap. The
guard now fails open on `git check-ignore`, and the arm discriminates in both directions:
seeding `*.txt`/`*.log` flips the ignored paths to ALLOW while the tracked `.md` offender is
unmoved.

**THE SUGGESTED REMEDY WAS WRONG ON THE COMMONEST SHAPE, AND ONE REMEDY WAS REFUSED BY THE
GUARD THAT ISSUED IT.** A token in the SUFFIX position ends at the `.`, so a strip whose
trailing class carried `.` ate the extension separator: `review-s288.md` → `review-md`. That
position is the COMMON one — `artifact-path-config.sh:106-108` records it as 173 files and it
is why `TOKEN_RE` is not anchored to a whole component. And `sed` replaces once per expression,
so `s12-s12-x.md` kept its second token and the suggestion was itself DENIED on the next
keystroke — a mechanism defending its own defect. Fixed by splitting the extension off the stem
and stripping to a fixed point; a basename that is ONLY a token now composes `s304/artifact.md`
rather than re-inserting the token through the fallback. **Every suggestion over ten probed
inputs is now ALLOWed by the guard that issued it (denied remedies: 0), and two match the
consumer's own hand-migration byte-for-byte.**

**THE FAIL-OPEN SET WAS CLAIMED ENUMERATED AND WAS NOT.** `./`, `//` and `/../` spellings that
RESOLVE into a scan root bypassed the prefix test and were ALLOWED. `REL` is now normalised
before the scan-root test — including a `//` collapse BEFORE the project-prefix match, since a
doubled slash at the boundary defeats that match itself and was the one spelling still allowed
after the first fix. A path that walks ABOVE the project keeps its `../`, matches no root, and
correctly fails open.

**AND THE GUARD TAXED EVERY WRITE IN THE CONSUMER.** It resolved three expressions before
testing whether the path was its subject at all, so a `Write` to `src/main.ts` paid the full
resolver cost: 64ms against a 9ms non-`Write` control, 20 reps. Only `--scan-roots` is needed to
bail, so the scan-root test now precedes the token/slot resolution — **38ms**, discrimination
unchanged across all six probe cases.

**ONE PRESCRIPTION DID SEND AN AGENT TO A DENIED PATH, AND IT IS FIXED IN THE SAME CHANGE.**
`code-reviewer.md` and `qa.md` prescribe `docs/reviews/s<N>/<story-index>-…md`, and the pipeline
mints ids SPRINT-FIRST (`s306-1`), so an agent resolving `<story-index>` to the id writes
`s312/s312-1-code-review.md` — measured NONCONFORMING with `s312/1-code-review.md` as the
same-invocation conforming control. Both role files now state that the placeholder is the bare
index. A deny whose remedy is a path core itself prescribes against is the shape that teaches an
operator to turn a guard off.

**Relation to I82.** `scripts/validate-enforcement-map.sh`'s I82 enforces this same grammar over
what core PRESCRIBES, at prose time; I82b covers the adjacent blindness where a prescription names
no sprint at all. Neither reaches a consumer's `Write`. The subjects are the same declaration and
the mechanisms do not overlap.

**Receipt — REPLACED, because the filed one was closable by non-code AND refused the correct fix.**
The original keyed a whole-file `grep` on the two named guards, narrowed to non-comment lines.
`grep -v '^[[:blank:]]*#'` strips only WHOLE-LINE comments, so it was closable three ways that
change nothing — measured: a trailing comment on a code line **0**, a dead variable
`artifact_path_check_enabled=0` never read **0**, a heredoc body naming the token **0**. A dead
variable closing the entry is precisely the failure the narrowing was added to prevent, one
spelling over. And keying on those two filenames made it score **1** against a correct fix sited
in a NEW hook — siting a mechanism by where a grep points is the tail wagging the dog.

**AND THE FIRST REPLACEMENT WAS STILL CLOSED BY A GUARD THAT COULD NEVER RUN.** Keying on the
EMISSION SITE plus the registration killed the prose forms but left five DEAD-GUARD states
scoring 0, because all three conjuncts were lexical-presence tests: `permissionDecision` is
satisfied by an `allow` emission, and naming the hook's basename anywhere in the template says
nothing about WHICH matcher block holds it. The form now filed adds the deny VALUE
(`permissionDecision[^)]*deny`), the `Write` tool gate, the token predicate, and a `jq` assertion
that the hook sits in a `PreToolUse` block whose matcher actually matches `Write`.

**Scored across nine inputs, every mutation asserted APPLIED in the same invocation** (two
earlier readings were `sed` expressions that silently no-op'd and returned a meaningless 0 — the
silent-unmutated-run defect, caught by a `cmp` guard): tip **0**; parent commit **1**; dead
variable **1**; trailing comment **1**; UNREGISTERED **1**; deny emission deleted **1**;
predicate INVERTED **1**; tool gate that can never match **1**; registered under a DEAD matcher
**1**; guard that exits 0 immediately **1**; an unrelated allow-only hook resolving the same
config with the real guard deleted **1**. The control that the grep can fire is
`permissionDecision` in `ai-dlc-core-guard.sh`, which exits 9 if absent. The line as filed is
byte-identical to the form scored, and runs verbatim from this file.

verify: sh t=templates/settings.json.template; [ -f "$t" ] || exit 9; [ "$(LC_ALL=C grep -c 'permissionDecision' core/hooks/ai-dlc-core-guard.sh)" -gt 0 ] || exit 9; g=0; for f in core/hooks/*.sh; do b="${f##*/}"; n="$(LC_ALL=C grep -hv '^[[:blank:]]*#' "$f")"; printf '%s' "$n" | LC_ALL=C grep -q 'artifact-path-config\.sh' || continue; printf '%s' "$n" | LC_ALL=C grep -qE 'permissionDecision[^)]*deny' || continue; printf '%s' "$n" | LC_ALL=C grep -qF 'TOOL_NAME" = "Write"' || continue; printf '%s' "$n" | LC_ALL=C grep -qF 'TOKEN_RE" <<<"$BASE" || exit 0' || continue; jq -e --arg b "$b" '.hooks.PreToolUse[] | select(any(.hooks[]; .command | test($b))) | select(.matcher | test("(^|\\|)Write($|\\|)"))' "$t" >/dev/null 2>&1 || continue; g=1; done; [ "$g" -eq 1 ] && exit 0; exit 1


## BL-268 — `fork-profile.sh --section by-line` misattributes forks across arm boundaries on bash 3.2, and the by-arm table inherits it

**DEFECT.** Found by a contract adversary attacking a proposed four-arm fork cut at batch 123,
and re-derived here independently. **The instrument this repo uses to decide WHICH arm to
optimise can name the wrong arm.** Nothing was shipped against the wrong reading — the finding
is recorded so the next session scoping that work does not re-derive it wrongly.

**The measurement that was wrong.** `--section by-line` reported `7118 tr 94`, which was read as
I84's cost. At the revision measured, line 7118 was a bare `fi` — the close of the I82/I82b/I99
conditional chain — and I84 contains no `tr` at all. Re-derived at this tip (line numbers move;
derive them, do not quote these): I84's range opens at `# --- I84:` and holds **0** `tr`; the
real site is one `tr '/' '\n'` inside I82's per-component split, and the arm containing it opens
at `# --- I82:`, the header before it. Control: an impossible `tr 'QQQ'` returns 0 in the same
invocation.

**The mechanism is a bash 3.2 `LINENO` artifact**, not a bug in the profiler's classifier: a
`<(...)` process substitution nested inside a deep if/elif/fi chain reports its commands' line
number as the chain's CLOSING line. So the forks are attributed to whatever arm's range happens
to contain that `fi`.

**THE BY-ARM TABLE INHERITS IT, WHICH IS THE PART THAT MATTERS.**
`render-invariant-index.sh --arm-lines` buckets the closing line into the arm whose range
contains it, so a per-arm column can be understated and its neighbour inflated by the same
count with nothing announcing the swap. The by-arm table is this repo's only ranking that has
predicted anything about fork cost; it is still the right instrument, and a single LINE citation
taken from it is not evidence about which ARM owns the cost.

**What is owed.** Either attribute a `<(...)` body to the line where the substitution is
WRITTEN, or have `--section by-line` mark lines whose attribution is structurally ambiguous (a
traced command whose reported line is a bare `fi`/`done`/`esac` cannot be the site that forked)
so a reader cannot silently take one. Until then: before scoping an arm's cut from a by-line
citation, confirm the named line is an executable fork site in that arm's range.

**Receipt.** Keys on the ambiguity being MARKED or the attribution being fixed — not on the
count, which moves with the corpus. Exit 9 if the profiler is gone.

verify: sh f=scripts/fork-profile.sh; [ -f "$f" ] || exit 9; LC_ALL=C grep -qE 'process substitution|substitution is WRITTEN|ambiguous attribution|bare (fi|`fi`)' "$f" && exit 0; exit 1

## BL-269 — I75 has no fixture anywhere, so the arm most at risk from a batching rewrite is the one with no equivalence oracle

**DEFECT.** Found by the same contract adversary and re-derived here. `I75` in
`validate-enforcement-map.sh` asserts that every `core/scripts/*.sh` consulting a project root
does it through the canonical precedence chain, and that the chain fails closed.

**No fixture exercises it.** Derived with a control in the same invocation: **33** fixtures
name `validate-enforcement-map` at all, and `i75_norm`, `i75_chain` and `i75_failsclosed`
return **0** each. The arm's only self-test is the two probes inline in its own body.

**AND ITS FINDING SETS ARE EMPTY ON A CLEAN TREE** — all 26 subjects hash to the same modal
chain, so `i75_drift` and `i75_open` are both empty. Comparing findings before and after any
rewrite therefore compares two empty sets, which is the vacuous shape measured at 0-of-205 in
`0.587.0`. I82, I33b and I84 each have a seeded mutation that flips their findings non-empty;
I75 has none.

**Why this is filed rather than fixed.** The oracle has to be built before the rewrite it
would guard, and no rewrite is in flight. Whoever takes it: seed a synthetic `core/scripts/`
copy whose root block is reordered (`CLAUDE_PROJECT_DIR` read before the override) or carries
no terminal guard, and assert `i75_drift`/`i75_open` name it — then the batching has something
to be equivalent to.

**One design note measured while scoping, so it is not re-derived:** I75's per-subject
`shasum` cannot collapse into a single awk pass — there is no SHA-256 in POSIX awk. The
tractable form is dropping the hash and comparing normalised text directly, which is
semantically identical and removes the per-subject external.

verify: sh v=scripts/validate-enforcement-map.sh; [ -f "$v" ] || exit 9; LC_ALL=C grep -q 'i75_chain' "$v" || exit 9; n=$(grep -rl 'i75_norm\|i75_chain\|i75_failsclosed' core/fixtures/ --include='*.sh' 2>/dev/null | wc -l | tr -d ' '); [ "$n" -gt 0 ] && exit 0; exit 1

## BL-267 — `I59_UNDOC_AWK` buffers a whole file into `lines[]`, so its memory cost is the largest corpus file rather than a constant

The shell form this replaced read each file twice through `grep` and `awk`, streaming both
times. The batched form holds every line of the current file in `lines[]` so the documentation
pass can revisit them after the mode set is complete, and frees it per file (`delete lines`).

**Bounded and small today, and that is a fact about the corpus rather than about the program.**
The largest file in I59's corpus is well under a megabyte and the loop holds exactly one file at
a time, so the ceiling is one file's lines, not the corpus. But nothing states that bound and
nothing checks it, and `awk`'s failure mode on exhaustion is not a clean refusal.

**What is owed.** Either a second pass over the file (re-`getline` from the start, trading one
extra read for a constant memory profile) or an assertion that the largest corpus member is
under a stated size. The first is the honest form: the arm already pays one `find` and the file
is in page cache by then.

**Tiered NOTE.** Nothing is wrong today and no guard is weakened; this records a
characteristic the change introduced so that a future corpus growth is not a surprise.

verify: sh v=scripts/validate-enforcement-map.sh; [ -f "$v" ] || exit 9; grep -q 'I59_UNDOC_AWK' "$v" || exit 9; LC_ALL=C grep -qE '^[[:blank:]]*lines\[\+\+nl\] = line$' "$v" || exit 0; exit 1


## BL-266 — `enforcement-map-sites`' I59 corpus mutation edits four arms' corpora and the battery can only see one of them

**The sed is `-type f -name '*.sh' -not -path`, with no line address, and `sed` applies `s///`
once per matching line.** Measured on a seeded tree at `4feee7f9`: it applies to **4** lines and
sends `--arms I59` (exit 1, `I59 found only 0 shipped script(s)`, its own assertion), `--arms I83`
(exit 1) and `--arms I60` (exit 1) red together, with I84 unaffected at exit 0.

**It is PRE-EXISTING and this release widened it by one.** Same mutation at the parent `5e5ff9e7`:
3 lines, with I59 and I83 both red and I60 still green. `0.588.0` added I60's own corpus `find` in
the batched rewrite, so the anchor picked up a fourth site.

**The arm passes for its own reason and the collateral is invisible.** `vrun` derives `--arms I59`
from the calling function's name, so the battery reads only I59's verdict and never observes that
two other arms were disabled in the same breath. `.claude/rules/fixture-mutants.md` requires a
mutant to fail ONLY its own assertion; this one cannot be seen to violate that, which is the part
worth filing — the check that would notice is the one that does not exist.

**What is owed.** Either the mutation is line-addressed to I59's own corpus line, or the battery
asserts that the arms the mutation is NOT about stay green in the same run. The second is the
stronger form and generalises: every mutation in this file could carry it.

**Tiered NOTE.** No verdict is wrong today and no guard is removed; the mutation is over-broad
rather than insufficient, which is the safe direction for a kill.

The receipt keys on the two REMEDIES as executable forms — a line-addressed `sed` for the corpus
mutation, or a `vrun`-style drive of a second arm inside assertion 33 — never on prose. Its first
form asked for the words "stays green" and came back 0 immediately, satisfied by two unrelated
comment lines about a hand-copied path; that is this repo's text-about-a-program trap, met while
writing the entry that describes it.

verify: sh f=core/fixtures/enforcement-map-sites/run.sh; v=scripts/validate-enforcement-map.sh; [ -f "$f" ] || exit 9; [ -f "$v" ] || exit 9; grep -q 'I59 grammar mutation' "$f" || exit 9; n="$(grep -c "name '\*\.sh' -not -path" "$v")" || n=0; [ "$n" -le 1 ] && exit 0; LC_ALL=C grep -qE "^[[:blank:]]*sed \"?'?[0-9]+s@-type f -name" "$f" && exit 0; LC_ALL=C grep -qE '^[[:blank:]]*bash "\$V" --arms I(60|83|84)' "$f" && exit 0; exit 1


## BL-265 — the fork budget's A4 stale-high arm had become unreachable at its own committed budget, and the mutant that should have said so was wired to a derived value

**`core/fixtures/validator-fork-budget/run.sh`'s `judge` evaluates A1 floor before A4
stale-high.** A1 was a hardcoded `[ "$t" -le 5000 ]`, sized when the validator forked 8225. A4
fires only when `t*10 < b*7`. So A4's window is `5000 < t < 0.7b`, which is EMPTY for every
budget at or below 7143. Measured across the budgets this file has actually carried: at
`FORK_BUDGET=8225` (0.583.0) the window was 5001..5756; at `6431` (0.587.0) there was **none**.
A4 — whose own message reads *"a ceiling nothing can reach is a check that cannot fire, and it
reads exactly like one that passed"* — had become exactly that, one release before anyone looked.

**`m3` could not see it, and the reason is the mutant's wiring rather than its predicate.** It
drives `judge` with `budget = T1 * 2`, where the window is non-empty under any floor, so it
stayed green through the closure. The comment above it explains that mutants are wired to `$T1`
rather than `$BUDGET` deliberately — measured, because entangling them with the committed budget
made m5 and m6 fire on the ceiling arm. That reasoning is right for m2–m6 and it is precisely
what left no arm watching the committed budget's own reachability.

**Fixed in this release, both halves.** A1 is now `40%` of `FORK_BUDGET`, so the two bounds move
together; `0.4b < 0.7b` for every positive budget, so A4 has a window at every budget this can
carry. The floor still refuses every input it exists to refuse — measured in one invocation, the
three real broken-tracer cases read **0** (a subject that forks nothing), **0** (the `PS4` marker
neutered, where the profiler's own self-probe refuses first) and **1** (the validator truncated at
line 400, the case A1's header names), against a control of **4767** for the live reading, which
must and does pass. And `m8` asserts A4's reachability at the LIVE budget by constructing the
midpoint of its window — the one mutant that must key on `$BUDGET`. Scored against the old
constant floor it reports the FAIL at `b=6431` and `b=4773` and passes at `b=8225`, which is the
closure it would have caught.

**The trigger was a correct change reading as a broken one.** Taking I59 and I60 from 1724 forks
to 66 put the true reading at 4767, under the constant, and the fixture reported
`BROKEN ... a broken tracer, an unmatched marker or a validator that exited early` with m2, m3, m5
and m6 all going off on A1 instead of their own arms — five failures from one improvement.

**What is owed, and why this entry survives the fix.** The floor is now proportional but the
FRACTIONS are still two literals (`4/10`, `7/10`) in one `judge`, and nothing joins them to the
quantity they are about. A future ratchet that takes the budget far enough down makes `0.4b` a
number a genuinely broken tracer could exceed — the tracer's failure modes read near zero today,
but that is a property of the profiler's current shape, not a bound. The durable form derives the
floor from what a BROKEN subject actually measures rather than from a fraction of the ceiling.

**Tiered DEFECT.** No guard was removed and nothing shipped wrong; what it cost was one arm that
could not fire for a release, and a correct change that had to be diagnosed before it could land.

The receipt keys on the two EMITTING lines — the floor's own `if` test and the `kill_j` call
that drives m8 — never on the file merely containing the fraction or the mutant's name. Its
first form did the latter and was satisfied by a three-line file of pure comments carrying no
executable floor at all; scored again on the emission sites it reads 0 on the real file, 1 on
that prose file and 1 at the parent commit.

verify: sh f=core/fixtures/validator-fork-budget/run.sh; [ -f "$f" ] || exit 9; grep -q 'A4 stale-high' "$f" || exit 9; grep -qE '^[[:blank:]]*if \[ "\$t" -le "\$\(\(b \* 4 / 10\)\)" \]; then' "$f" || exit 1; grep -qE '^[[:blank:]]*kill_j "m8 A4-reachable' "$f" && exit 0; exit 1


## BL-264 — the read-set deriver records GITIGNORED paths, so a tracked map is a function of ambient harness activity

**`core/scripts/derive-fixture-readsets.sh` traced every path a fixture touched and wrote all of
them into `.ai-dlc-fixture-readsets.tsv`, with no gitignore filter** — 0 `check-ignore` or
`gitignore` sites in the deriver before this change, against a control of 2 after it. The tracer
therefore recorded `.claude/worktrees/agent-*/`, which is the **Claude Code harness's own agent
checkouts**: not this project's state, not any project's state, and present in whatever number of
concurrent sessions happened to be running when the derivation ran.

**Measured on the tracked map at `264a95de`: 12435 of 36046 rows point into
`.claude/worktrees/`, plus 49 `.DS_Store` rows.** Re-derived across the whole map, 3943 of 6605
distinct paths are gitignored and **12506 of 36036 data rows — roughly 35% — are paths no fixture
depends on**. Control in the same derivation: `core/fixtures/ledger-reverify/run.sh` is present in
the map and is NOT in the ignored set, so the filter discriminates rather than matching everything.

**THE DEFECT IS REPRODUCIBILITY, NOT SELECTION.** Two derivations of one fixture minutes apart
returned 4815 rows and then 26854 — a 5.6x move with no change to the fixture, caused only by how
many agents were live. A derived artifact whose content depends on ambient activity cannot be
reviewed, diffed, or reproduced, and the map is tracked, so every such run is a large spurious
diff. The selection consequence is bounded and is in the SAFE direction: an over-broad read-set
makes a fixture run MORE often than it must, never less.

**The boundary is the repository's own `.gitignore`, read by git — never a hand-written prefix
list.** `.claude/rules/**` is un-ignored by negation and IS tracked, and fixtures read those rule
files; a prefix list keyed on `.claude` drops them. `git check-ignore` separates the two and a
string match cannot. The filter FAILS OPEN by design: if `check-ignore` yields no usable verdict
every path is kept, the read-set is a superset, and the fixture runs more often — the dangerous
direction would be dropping a real input, which makes a fixture skip when its subject moved.

**This is NOT `BL-127`, which is the opposite direction** — a mapped row OMITTING a file its
`run.sh` opens, so the fixture is skipped on the change most likely to break it. That entry is
about under-inclusion and silence; this one is about over-inclusion and irreproducibility. Both
were checked before filing.

**The 12435 stale rows are not cleared by this change.** The map is trace-derived and hand-editing
it puts a second, drifting declaration beside the derivation — `BL-127` says so in as many words.
They clear on the next `sudo bash core/scripts/derive-fixture-readsets.sh` run, which needs root
and is the operator's to run, and which should be taken with no agent worktrees on disk so the
result is stable.

**Tiered DEFECT.** Nothing is corrupted and no guard is removed; what it costs is a 2.9MB tracked
artifact that no reviewer can diff and that moves for reasons unrelated to the suite.

The receipt keys on the filter EXISTING in the deriver, not on the map's row count reaching zero:
the rows clear only on a root-privileged re-derivation, so a count-based receipt would be
unattainable in this session and would read as a failure of a fix that works.

verify: sh d=core/scripts/derive-fixture-readsets.sh; [ -f "$d" ] || exit 9; grep -q '^norm()' "$d" || exit 9; grep -q '^drop_ignored()' "$d" && grep -q 'check-ignore' "$d" && exit 0; exit 1


## BL-278 — the join between an entry's receipt and the fixture that covers the same subject has no home a consumer can run

**DEFECT.** Found at batch 134, when the arm that would have carried this join was reverted out
of a shipping fixture by the pre-push dead-doc-ref phase.

**THE JOIN IS REAL AND NOTHING ASSERTS IT.** A backlog entry's `verify: sh` receipt and the
fixture arms covering the same subject divide the work between them: the receipt establishes
that the fix is present, and the arms establish what the receipt cannot express. At batch 134
that division was measured rather than assumed — BL-040's receipt is blind to a mutant deleting
only the Check 12 writer half, and blind to a comment or a bare mention replacing the comparand,
so three of the six seeded shapes are fixture-owned. **The division is currently stated in a
comment**, and a comment goes stale in silence: the next hand to widen the receipt reads the arms
as redundant and deletes one.

**WHY IT HAS NO HOME TODAY.** The join's two sides live on opposite sides of the consumer
boundary. The receipt is a line in `docs/backlog.md`, which `install.sh` does not ship; the arms
live in `core/fixtures/gate-verdict-grep-shape/`, which does. Derived at this tip, both sides in
the same invocation: `grep -rlF 'docs/backlog.md' core/fixtures/` returns **4** fixtures —
`backlog-ledger`, `backlog-receipt-binding`, `backlog-rotate-fence-guard`, `backlog-size-ceiling`
— and **4 of 4** carry a `.dist-only` marker, against **0** shipping ones. So the tree's existing
answer to this class is unanimous and the arm that broke it was the anomaly.
`scripts/validate-no-dead-doc-refs.sh` enforces exactly that, and the class it names is not
cosmetic: a shipping fixture whose corpus is absent on a consumer STANDS DOWN there, and a unit
that cannot fail scores as a pass in that consumer's own suite verdict.

**THE OBVIOUS REPAIR IS THE ONE TO REFUSE.** Hardcoding the receipt into the fixture makes the
arm runnable on a consumer and creates a second definition of the receipt — which is the drift
this entry exists to prevent, one level down. The receipt must be DERIVED from the entry or not
scored at all.

**What is owed is a `.dist-only` home beside the other backlog units.**
`core/fixtures/backlog-receipt-binding/` already reads `docs/backlog.md` (14 sites) and already
drives receipts over seeded ledgers, and its `.dist-only` marker states this exact reasoning.
Whether the join belongs as arms there, or in a new `.dist-only` fixture, is the scoping question
— `.claude/rules/fixture-ship-decl.md` governs either way, and a NEW fixture directory also owes
a read-set row the operator must derive with root.

Discharges nothing upstream; this is distribution-internal and ranks below any PC-backed entry.

verify: sh h=core/fixtures/gate-verdict-grep-shape/run.sh; [ -f "$h" ] || exit 9; b=core/fixtures/backlog-receipt-binding/run.sh; [ -f "$b" ] || exit 9; [ -f core/fixtures/backlog-receipt-binding/.dist-only ] || exit 9; grep -q 'docs/backlog.md' "$h" && exit 9; grep -qE 'BL-040|CHECK_LOADED: 5' "$b" && exit 0; exit 1

## BL-279 — a consumer ledger receipt false-CLOSES on edits that change no behaviour, and whether a correct fix closes it at all is a property of WORD CHOICE

**DEFECT.** Found while replacing `BL-029`'s receipt, by scoring `PC-S296`'s own receipt against
a mutant set instead of reading it. Two independent faults in one predicate; they are filed
together because they share a subject and the second is only visible once the first is understood.

**THE POLARITY IS THE WHOLE STAKE.** In `docs/backlog.md` a receipt's exit 0 means
CLOSE-CANDIDATE. In the CONSUMER's ledger the polarity is inverted:
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2063` emits STILL-LIVE on exit 0 and
`:2099` emits CLOSE-CANDIDATE on non-zero (control: an impossible verdict name scores 0 in that
file). So for a consumer receipt a spurious NON-ZERO is a false CLOSE, and a false close retires
a live defect. Every measurement below is in that direction.

**THE SUBJECT.** `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS`, whose `verify: sh` line sits
indented in `/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md` under the
`## PC-S296-…` heading at `:459` (control: an impossible `## PC-` id scores 0 in that file). The
receipt has two arms: the Return schema must carry exactly the five known keys, and the bucket
span must NOT match `depends|dependency|presuppos|push_candidate`.

**FAULT 1 — three edits that change no behaviour drive it to CLOSE-CANDIDATE.** Scored on
mutants built from the shipping `classify-block.md` blob, each asserted different from shipping
by `cmp -s` before any score was read; shipping itself scores 0 (STILL-LIVE), which is the
in-invocation control.

- A **multi-line** HTML comment inside the Return schema block → **1**. The key extractor
  returns `id bucket action needs_operator_confirmation note reviewer`, against
  `id bucket action needs_operator_confirmation note` on shipping — the comment's continuation
  line parses as a sixth key. A **single-line** HTML comment there scores 0 and a single-line
  comment in the bucket span scores 0, so the fault is the multi-line form specifically, not
  HTML comments generally. That narrowing is the measurement, and it is narrower than the shape
  originally suspected.
- Any indented `word: text` line added to the Return block — e.g. `example: a one-line note` →
  **1**, by the same sixth-key path. An unrelated genuine sixth schema field does this too, which
  the original `BL-029` filing already noted in the abstract; it is measured here.
- Plain PROSE anywhere in the bucket span carrying one of the four vocabulary words, and a
  single-line HTML comment in the bucket span carrying one → **1** each. Neither changes what the
  classifier does.

**FAULT 2 — the receipt is VOCABULARY-BOUND, so whether a correct fix closes it is word choice.**
A fix written without `depends`/`dependency`/`presuppos`/`push_candidate` — phrased instead as
"no core text at the hook target RELIES on" and "a gate that CANNOT PASS without the machinery",
carrying the identical rule — scores **0**, STILL-LIVE, forever. Our committed wording scores 1
and closes it, and the fixed bucket span carries all four words at 1 hit each (control: an
impossible word = 0 in the same span). **That close is a property of which synonyms we happened to
use, not of the fix.**

**WE CANNOT REPAIR IT, AND THAT IS THE FINDING.** `.claude/rules/consumer-boundary.md` is
unconditional: an ai-dlc session never writes to a consumer, and this receipt lives in the
consumer's ledger. The remedy is the operator's to carry into a consumer session — re-anchor the
receipt on the DECISION site (`core/skills/ai-dlc-update/SKILL.md`'s two bucket bullets, read at
`$THEIRS`) asserting the flag VALUES, exactly as `BL-029`'s replacement receipt now does on this
side. Until then, any CLOSE-CANDIDATE this receipt reports is unsafe to act on without reading
what actually changed.

**The upstream half is already done and is what makes this filable at all**: the distribution's
`ledger-reverify.sh` cannot distinguish these cases, because it executes whatever predicate the
entry carries. Nothing here is a defect in the engine.

Discharges nothing upstream. This is a finding ABOUT a consumer-owned receipt; it can only be
closed by a consumer session and has no distribution-side predicate.

verify: manual — the subject is a consumer-owned file this repo must not write, and no
distribution-side predicate can observe it.

## BL-282 — "a green gate is not a landed push" has no enforcer, and the obvious check RACES a backgrounded push

**NOTE.** Filed at batch 138 after the lead reported a push failure that had not happened.

**CAUSE FOUND AT 0.619.0–0.621.0, AND IT IS AN OPERATOR DOTFILE, NOT THE TREE.** `git push`
opens the SSH connection before `pre-push` runs (the hook reads the remote's refs on stdin), the
suite then idles that connection for the length of a full run, GitHub's sshd drops it, and git
takes SIGPIPE writing the pack — exit 141, gate green, ref absent. Three consecutive pushes on the
0.619.0 branch dropped at the same point mid-suite, each log carrying `Connection to github.com
closed by remote host` before `pre-push: all gates green`. `~/.ssh/config` for the alias carried
no keepalive. With `ServerAliveInterval 60` / `ServerAliveCountMax 30` added — the one variable
changed — the next three pushes ran **8m04s, 8m41s, 8m08s** with zero drops and every ref
landed. The receipt below asks for an `ls-remote` reader in the hook, which is a detector for a
symptom whose cause is now known; the mechanism that would fire is the hook WARNING at push time
when the ssh alias lacks a keepalive, which is a check with a measured false-positive set (this
box, before the change). The entry stays open on that reshaped receipt, and this note is the
record that the symptom-detector is no longer the right shape.

**THE RULE IS PROSE WITH NOTHING BEHIND IT.** `.claude/rules/verification-discipline.md:216`
records the measured hazard: twice, every phase PASS, `pre-push: all gates green`, **exit 141 from
the transport**, and the ref NOT on origin. It instructs confirming the remote ref moved before
opening a PR or reporting a release. Derived at this tip: `grep -rn 'ls-remote'` over
`.githooks/pre-push` and `scripts/*.sh` returns **0** readers, against a control of 15 `pre-push`
occurrences in `docs/backlog.md` — so the instruction has no mechanism and depends on the session
remembering it.

**AND GIT OFFERS NO HOOK POINT FOR IT.** Derived from the hook samples git itself ships:
`post-push` is **0** of the 14, against a control of **1** for `pre-push`. `pre-push` runs BEFORE
the transport, so the failure it would need to observe happens after it exits. **A hook cannot
carry this check**, which is why the rule has stayed prose and why this entry is a NOTE rather
than a fix with a known shape.

**THE OBVIOUS CHECK HAS A MEASURED FALSE POSITIVE, AND THE LEAD SHIPPED IT THIS BATCH.** A
`git ls-remote --heads origin <branch>` reading 0 is only evidence of an absent ref if the push
has FINISHED. Measured: `git push -q` was backgrounded under a 600s timeout, `ls-remote` ran while
it was still in flight and read **0** against an impossible-branch control of 0, and the push then
completed and the ref appeared. The reflog shows exactly **one** push landing the sha — the
"re-push" that followed was a no-op against an already-landed ref. **A zero read from a check
whose subject is still being written is not a finding**, and it is indistinguishable from the real
exit-141 case the rule exists for.

**SO A CHECK MUST ESTABLISH THAT THE PUSH COMPLETED BEFORE IT READS THE REF.** That is the
property the design has to carry, and it is the reason this is not a one-line addition. A session
that backgrounds the push cannot read the ref until the background task reports, and nothing today
joins those two events.

**WHAT A FIX MUST NOT DO.** Do not put the check in `pre-push` — it cannot see the outcome.
Do not key it on the push command's exit status alone: that is the value the measured hazard
reports as 0 while the ref is absent, and reading it through a pipe makes it worse, because this
shell has no `PIPESTATUS` and a pipeline answers with its last stage.

verify: sh set -e; r=.claude/rules/verification-discipline.md; [ -r "$r" ] || exit 9; LC_ALL=C grep -q 'green gate is not a landed push' "$r" || exit 9; n="$(grep -rlF 'ls-remote' .githooks/ scripts/ 2>/dev/null | grep -cv '^$')" || n=0; [ "$n" -gt 0 ] && exit 0; exit 1

## BL-300 — five sibling scripts fail closed in the consumer layout under an override root carrying no schema

**DEFECT.** The failure is latent. Found by the batch 150 contract adversary, while it was
attacking the fix for `BL-299`. It discharges no consumer candidate.

**THE SAME SHAPE AS `BL-299`, IN FIVE MORE PROGRAMS.** `sprint-status.sh`,
`sync-taught-schema.sh`, `validate-audit-anchors.sh`, `validate-write-format-steering.sh` and
`validate-gate-adjudication.sh` each look for their schema beside the script
(`../schemas/`) and under the resolved project root. None of them falls back to the install
root. In the consumer layout the script-relative candidate is `scripts/schemas/`, which does not
exist. So an `AI_DLC_PROJECT_ROOT` naming a root without `.claude/schemas/` makes every one of
them fail closed. `validate-gate-adjudication.sh` resolves `enforcement-map.yaml` the same
root-keyed way (at `core/scripts/validate-gate-adjudication.sh:327-329`), so it needs both
lookups fixed.

**MEASURED IN A FRESH INSTALL OF `14129c75`**, against a foreign root holding only `.claude/`.
Each script was run from the consumer root with and without the override, and the `not found`
or `cannot find` diagnostic was counted in both runs. Without the override, all five print
neither (the control). With it, all five print one, and `sprint-status`, `sync-taught-schema`,
`validate-audit-anchors` and `validate-write-format-steering` exit 1.
`validate-gate-adjudication` needs `--expected implementation` to get past its usage exit
before it reads the schema, and then it exits 2 with
`schemas/gate-adjudication-verdict.json not found`. The fixed pair from `BL-299`, run the same
way, prints neither diagnostic.

**WHY IT IS LATENT.** No production caller points the override at a root with no schema. A
consumer's override names the consumer, which carries `.claude/schemas/`. The failure needs a
fixture or an operator to aim the override somewhere foreign, which is exactly what arm R did
for the writer.

**ANY FIX ALSO NEEDS THE `validator-path-resolution` TREATMENT.** Every one of these scripts
mentions `AI_DLC_PROJECT_ROOT`, so that fixture's non-vacuity arm requires each to change its
output under a wrong root. For any script whose only root-keyed read reachable from its current
`argv_for` is the schema lookup, an install-root fallback makes that script score inert, and the
arm goes red, as it did for the provenance pair. Each fixed script needs an `argv_for` that
reaches a root-keyed read that is not the schema. Apply the same order rule as `BL-299`: append
the fallback LAST.

The receipt exits 0 once none of the five prints a `not found` or `cannot find` diagnostic under
the foreign override. It exits 9 if the no-override control already prints one, or if the install
fails. It scores **1** at `14129c75`, printing five `LIVE:` lines.

verify: sh R="$(pwd)"; command -v git >/dev/null || exit 9; T="$(mktemp -d)" || exit 9; F="$(mktemp -d)" || exit 9; mkdir -p "$F/.claude" || exit 9; ( cd "$T" && git init -q && mkdir _bmad && git -c user.name=r -c user.email=r@r commit -q --allow-empty -m init && bash "$R/scripts/install.sh" "$T" </dev/null ) >/dev/null 2>&1 || exit 9; bad=0; for s in sprint-status sync-taught-schema validate-audit-anchors validate-write-format-steering validate-gate-adjudication; do p="$T/scripts/ai-dlc/$s.sh"; [ -f "$p" ] || exit 9; a=""; [ "$s" = validate-gate-adjudication ] && a="--expected implementation"; c="$(cd "$T" && bash "$p" $a 2>&1)"; case "$c" in *"not found"*|*"cannot find"*) exit 9 ;; esac; e="$(cd "$T" && AI_DLC_PROJECT_ROOT="$F" bash "$p" $a 2>&1)"; case "$e" in *"not found"*|*"cannot find"*) echo "LIVE: $s"; bad=1 ;; esac; done; [ "$bad" -eq 0 ]

## BL-301 — the gate runs no shipped fixture in the consumer layout, so a fixture red on every consumer ships green

**DEFECT.** Found by the batch 150 contract adversary. It discharges no consumer candidate.

**THE GAP `BL-299` FELL THROUGH.** The distribution's pre-push runs `core/fixtures/*/run.sh` in
the distribution tree. `install.sh` splits what shares a parent here, so `core/scripts/<x>`
lands at `scripts/ai-dlc/<x>` and `core/schemas/` at `.claude/schemas/`. A fixture that resolves
a sibling through the distribution's relative layout therefore passes here and fails on every
consumer. That is what happened to story-provenance's arm R, which went red in every consumer
install from 0.628.0 while every distribution push stayed green. The consumer found it on its
own tree, three releases later. The installer-driving fixtures here (`consumer-machinery-home`,
`layer-crosswalk-home`, `shipped-rule-version-floor` and five more, located by grepping
`core/fixtures/*/run.sh` for `scripts/install.sh`) each assert one property of the installed
tree. None of them runs the shipped fixture set there.

**THE SHAPE OF A FIX, AND WHY IT IS NOT A SMALL ONE.** A gate phase would install HEAD into a
`mktemp -d` consumer with `_bmad/`, then run every shipped fixture there through the consumer's
own installed runner, `core/git-hooks/pre-push`, which is the program a consumer runs. It has to
use that runner so that the pool and the verdict accounting match. The shipped set is the
fixtures carrying no `.dist-only` marker. The cost is a second full pass over most of the suite,
and the suite is pole-bound, so the phase has to be scheduled against the existing pole rather
than appended serially. **Measure that cost before choosing** between a full consumer-layout
pass and a pass limited to the fixtures whose read-set crosses a path that `install.sh` remaps.

**`verify: manual`, because no behavioural receipt is constructible at receipt scale.** The
property is that the GATE runs the shipped set in a consumer layout. The only behavioural test
is to seed a fixture that fails only in the consumer layout and run the gate, which means running
the suite from inside a receipt, and the receipt runner itself runs from inside that gate. A
grep of `.githooks/pre-push` for `install.sh` would be satisfied by a comment, and
`scripts/validate-backlog-receipts.sh` would correctly report it as PROSE-CLOSABLE. Close this
entry by hand on the release whose gate shows the new phase failing on a seeded consumer-only
fixture and passing on its removal.

verify: manual

## BL-302 — in the distribution layout the provenance writer and reader load different schemas when the override root carries its own

**DEFECT.** The disagreement predates `BL-299` and is not changed by it. Found by the batch 150
contract adversary. It discharges no consumer candidate.

**THE TWO CHAINS ARE ORDERED DIFFERENTLY.** In `core/scripts/stamp-story-provenance.sh` the
writer tries `$SP_SCRIPT_DIR/../schemas/` FIRST, and the root candidates after it. In
`core/scripts/validate-provenance-block.sh` the reader tries `<root>/core/schemas/` and
`<root>/.claude/schemas/` first, and its script-relative candidate after them. In the
distribution the script-relative candidate always exists. So when `AI_DLC_PROJECT_ROOT` names a
root that carries its own schema, the writer loads `core/schemas/` while the reader loads the
foreign root's copy. On a consumer the writer's first candidate is `scripts/schemas/`, which
does not exist, so the pair already agree there. `BL-299`'s fix appended the install root last
in both chains and left their first candidates as they were, so this split survives the fix.

**MEASURED AT `14129c75`, in the distribution layout.** The override root carries a copy of the
schema whose `tool_use_id` `forbidden` list additionally names `toolu_FIXTURE`. That field
matches by `prefix_ci`, and the fixture seed's ids begin with that stem. Under that override the
writer's `--print-schema` names `core/scripts/../schemas/provenance-block.json`. The writer stamps
the bug story (`wrote s1/stories/story-2-fix-thing.md`), and the reader then refuses it with
`tool_use_id: toolu_FIXTUREaaaaaaaa is forbidden`, exit 1. Each program is consistent with its
own schema, and the two schemas differ.

**THE RECEIPT, AND A FIX-SHAPED CONTROL.** The receipt asserts that the writer's `--print-schema`
is `-ef` the override root's copy. Then, if the writer stamps at all, the reader accepts what it
stamped. It scores **1** at `14129c75`. A scratch copy with the writer's script-relative
candidate moved after its two root candidates, which is the reader's order, scores **0**. That
control establishes that the receipt can close, and that a fix of that shape closes it.
**Check the fixtures before shipping that reorder.** Several fixtures plant a schema into a world
and drive the writer or the reader against it. The order is load-bearing for them, and the
contract for `BL-299` forbade reordering for exactly that reason.

verify: sh R="$(pwd)"; W="$R/core/scripts/stamp-story-provenance.sh"; V="$R/core/scripts/validate-provenance-block.sh"; K="$R/core/schemas/provenance-block.json"; [ -f "$W" ] && [ -f "$V" ] && [ -f "$K" ] && [ -f "$R/core/fixtures/story-provenance/seed.sh" ] || exit 9; command -v python3 >/dev/null || exit 9; G="$(mktemp -d)" || exit 9; M="$(mktemp -d)" || exit 9; mkdir -p "$G/.claude/schemas" || exit 9; python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); f=[x for x in s["fields"] if x.get("name")=="tool_use_id" and x.get("forbidden_match")=="prefix_ci"]; assert len(f)==1; f[0]["forbidden"].append("toolu_FIXTURE"); json.dump(s,open(sys.argv[2],"w"))' "$K" "$G/.claude/schemas/provenance-block.json" 2>/dev/null || exit 9; bash "$R/core/fixtures/story-provenance/seed.sh" --mixed-into "$M" >/dev/null 2>&1 || exit 9; P="$(AI_DLC_PROJECT_ROOT="$G" bash "$W" --print-schema 2>/dev/null)"; [ -n "$P" ] && [ "$P" -ef "$G/.claude/schemas/provenance-block.json" ] || exit 1; B=s1/stories/story-2-fix-thing.md; if ( cd "$M" && AI_DLC_PROJECT_ROOT="$G" bash "$W" --terminal s1/bug-fix-oneshot-story-2-fix-thing.md --profile bug-story-provenance "$B" ) >/dev/null 2>&1; then ( cd "$M" && AI_DLC_PROJECT_ROOT="$G" bash "$V" "$B" --require-skill bmad-review-adversarial-general ) >/dev/null 2>&1 || exit 1; fi; exit 0

## BL-306 — a memo key embeds the percent-encoded dist path, and past about 190 characters of path the cache write fails and detectors silently change output

**DEFECT.** Found at batch 152 by the `BL-303` fix hand, and confirmed by the tip adversary. It
discharges no consumer candidate.

Every memo function in `core/skills/ai-dlc-update/reconcile/lib.sh` names its cache file after
the dist path, the ref and the blob path, percent-encoded (`:902`, `:928`, `:945`, `:974`,
`:994`). The filename limit is 255 bytes. Past it, the write fails with `File name too long`, the
lookup falls through, and the detector answers differently without refusing. Measured with
`preclassify.sh` on a graph clone: a 190-character dist path emitted 418 bytes, and a
210-character one emitted 0 bytes with four `too long` errors on stderr. Base and the
`BL-303` tip were identical at every length, so `BL-303` did not widen this.

The encoded dist path has about 122 characters of budget, given a 40-character ref and the
longest theirs path (87 encoded). A `/Users/<name>/git/<repo>` checkout produces keys of 129 to
173 characters, and a `/private/var/folders/…` dist produces 189 to 221, all under the limit.
Only deep scratch paths reach it today, which is where the fix hand's receipt world first hit it.

The candidate fix is to hash the key, or to go direct when `${#_k}` exceeds about 240. Its
receipt must drive a detector from a dist path long enough to fire, and compare its output with
the same run from a short path. `lib.sh` is bootstrapping, so the fix ships alone.

verify: manual

## BL-307 — a zero-byte `pending.md` takes an exit-0 road through Checks 2 and 2a that prints no `EXAMINED NOTHING`

**NOTE.** Found at batch 152 by the `BL-305` fix hand during its Check 2 and 2a audit. It
discharges no consumer candidate.

With `docs/escalations/pending.md` absent, `validate-escalation-resolution.sh`,
`validate-escalation-status-vocabulary.sh` and `validate-suppression-lifetime.sh` each exit 0 and
print `OK: EXAMINED NOTHING`. With the file present and zero bytes long, each exits 0 without
that token:

- `OK: no S1 RESOLVED/OVERRIDDEN escalation requires an operator citation.`
- `OK: n=[] no **Status:** entries found`
- `OK: entries_scanned=0 … no suppression is past its lifetime`

A reader following the `BL-305` instruction therefore reads an empty file as a real pass. Whether
an empty `pending.md` is a legitimate consumer state has not been measured. Measure it on the
reference consumer's history first; if the state is legitimate, the three programs should say
`EXAMINED NOTHING` on it too.

verify: manual
