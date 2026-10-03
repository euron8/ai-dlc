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
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
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

## BL-071 — `ledger-rotate.sh`'s split-refusal can be silenced by a body line that mentions the annotation form

**LANDED (v0.719.0, verified TBD).** The loose (colon-less) suppressor now reads the suspect body with its inline code removed — balanced double-backtick spans, then balanced single spans, then a lone backtick to end of line — so a backticked QUOTATION of the close form no longer silences the split refusal. The colon branch keeps the unstripped archive grammar.

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

**Why the receipt below REPRODUCES rather than closes.** It exits non-zero while the colon-less
case survives, and it is expected to stay non-zero: what follows is why no predicate available
today separates that case. The colon subclass, which the parse DOES separate, is shipped (Held
note below). The two cases a fix must
separate are, on today's signals, the same shape: both are a bold bullet inside a closed entry,
both carry a receipt below them (`susp_hasv`), and the real-entry case does not even carry the
trailing colon (`susp_colon`) that would mark an annotation lead-in. The ONLY thing separating
them in the current parse is the quotation itself — the real entry quotes the annotation form
because it is discussing it, and a genuine lead-in does not quote, it IS one. That is an
accidental signal, not a designed one, and a fix needs a signal the parse does not currently
compute. A receipt asserting both arms would therefore be UNSATISFIABLE against every predicate
available today, so it would be a standard nobody can meet if it were read as a close condition.

The two cases a fix must satisfy simultaneously, so the next session does not have to rederive
them: `core/fixtures/ledger-rotate/run.sh`'s `splitter` seed must be REFUSED, and its `fp-quotes`
seed must NOT be. Both already exist in that fixture and both are already asserted.

Found while remediating `BL-035`, by that fixture, against its own author.

Held note (batch 178): the COLON subclass is closed and the entry narrows to the rest. The suppressor (now near `ledger-rotate.sh:290`) uses the archive grammar `ledger_body_archives()` when the suspect label ends in a colon (`susp_colon`, already computed) and keeps the loose `ledger_entry_line_closes()` otherwise, so a `- **Note:**` lead-in whose body only QUOTES the annotation form now refuses. A colon-titled line with a genuine bolded close still rotates, and the `fp-quotes` seed still rotates. WHAT SURVIVES: a colon-LESS suspect whose body mentions the form is still silenced, because for that label a mention and a real entry discussing the form are the same shape; the entry stays open on it. The header prose that said the consumer archive "reports 22" now says what the number counts: suspect boundary lines inside CLOSED entries, each silenced by its own close, 27 on a copy of the consumer archive at 0.674.0 (22 at the commit first measured), and 0 reported by the guard. Consumer differential, old vs new rotator: live ledger 0/0 findings and the archive 0/0, rc 0 both. Across all 144 historical live-ledger revisions the only difference is 2 revisions already refused for other lines (5eb222bb, 0def7560), which gain a `The share:` suspect in `PC-S296-WHOLE-READ-POOL` whose only silencer was an unbolded close; both rotators refuse those revisions either way. The receipt below asserts the SURVIVING subject and exits 0 only when the colon-less mention also refuses; scored under `bash -c 'set -uo pipefail; …'`: tip 3 (colon cell not refused), fix 1 (surviving cell), archive-grammar-for-every-suspect 4 (the real quoting entry refused), colon-never-silenced 5 (a genuine colon close refused).

Re-ruling (batch 191, operator option A): `fp-quotes` is an INTENDED refusal, on `fp-open`'s rationale (`core/fixtures/ledger-rotate/run.sh`, arm (2)). A colon-less suspect inside a closed entry whose body only QUOTES the annotation form carries no close of its own, so it is as unclassifiable as an open prose-titled line; a wrong refusal costs a two-line edit and a wrong rotation strands a receipt. The escape is the one the refusal text names: the entry gives itself a close or an id. This supersedes the "fp-quotes seed must NOT be refused" condition above. Fixture cells, base -> fix (R refused, S rotates): splitter R->R; colon-mention R->R; nocolon, nocolon-odd, nocolon-twoline, nocolon-dbl S->R; fp-quotes S->R; colon-closed, fp-legacy, fp-versionless, realclose-afterquote S->S; colon-btbold R->R; title-nocolon, title-colon (a quotation on the suspect boundary line itself) S->R; close-after-span (the consumer's legacy body shape) and close-between-spans S->S. The suspect boundary line is read with its inline code removed too, for both label shapes. Nine committed mutants each move only their own seeds: strip-both-branches (colon-btbold), strip-also-removes-bold (fp-legacy, fp-versionless, realclose-afterquote), balanced-only (nocolon-odd, nocolon-twoline), no-double-span (nocolon-dbl), drop-single-span-gsub (fp-legacy, close-after-span, close-between-spans), greedy-single-gsub (close-between-spans), strip-off (the four nocolon seeds and fp-quotes), colon-revert (every body-line refusal but splitter), boundary-unstripped (title-nocolon, title-colon). The ship-ahead key is now `ledger_entry_line_closes(ledger_strip_inline_code($0))`, and its absence in the distribution is a FAIL rather than a skip. Consumer differential, base vs fix, over 164 live-ledger and 70 archive revisions of the reference consumer (`git log --all -- <path>`; 135 and 54 on its current branch alone, which also read 0 changes) plus both working files: 236 inputs, 0 verdict changes, 8 refused under each; control, the live ledger at `5eb222bb`, refuses under both. A PARTIAL close of the mention class. Four shapes still silence the guard: a mention in straight quotes; a mention inside a fenced block; an unquoted mention on the same line as a quoted one; and a backticked span wrapped across lines whose token sits on the CONTINUATION line, which carries no backtick before it (the lone-backtick rule covers a wrapped span only when the token is on the opening line). No count of surviving consumer lines is recorded: the contract's figure and a re-derivation on the working files used different, unreconciled populations, so neither is stated as a measurement. The receipt below exits 0 only on the fix; scored under `bash -c 'set -uo pipefail; …'`: base 4, strip-both-branches 6, strip-also-removes-bold 8, balanced-only 7, no-double-span 2, strip-off 4, colon-revert 3, drop-single-span-gsub 12, greedy-single-gsub 13, boundary-unstripped 10.

verify: sh R=core/skills/ai-dlc-update/reconcile/ledger-rotate.sh; [ -f "$R" ] && [ -f "${R%/*}/lib.sh" ] || exit 9; D=$(mktemp -d) || exit 9; trap 'rm -rf "$D"' EXIT; H='# Push-candidate ledger\n\n- **PC-CLOSED-ABOVE** — closed\n\n  <br>**ADOPTED UPSTREAM (v0.100.0, verified 2026-01-01).** Upstream took it.\n\n'; V='  verify: theirs_has core/scripts/thing.sh "MARKER_A"\n'; Q='  Annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero.\n\n'; printf "$H"'- **Note:** a lead-in\n\n'"$Q$V" > "$D/colon.md"; printf "$H"'- **A real entry that QUOTES the annotation form** in its body\n\n'"$Q$V" > "$D/real.md"; printf "$H"'- **Note:** a colon-titled line\n\n  **ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02).** closed in its own right\n\n'"$V" > "$D/cclosed.md"; printf "$H"'- **Note** a lead-in with no colon\n\n'"$Q$V" > "$D/nocolon.md"; printf "$H"'- **Note:** a lead-in\n\n  **`foo.sh` ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02).** a name\n\n'"$V" > "$D/btbold.md"; printf "$H"'- **Note** a lead-in with no colon\n\n  Annotate it `ADOPTED UPSTREAM (vX.Y.Z,\n  verified <date>)` once the grep is non-zero.\n\n'"$V" > "$D/twoline.md"; printf "$H"'- **A real entry that quotes and then closes** in its body\n\n'"$Q"'  **ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02).** closed in its own right\n\n'"$V" > "$D/aftq.md"; printf "$H"'- **Note** a lead-in with no colon\n\n  Annotate it ``ADOPTED UPSTREAM (vX.Y.Z, verified <date>)`` once the grep is non-zero.\n\n'"$V" > "$D/dbl.md"; printf "$H"'- **Note** annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero\n\n'"$V" > "$D/tnc.md"; printf "$H"'- **Note:** annotate it `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` once the grep is non-zero\n\n'"$V" > "$D/tc.md"; printf "$H"'- **A real entry** in the legacy body shape\n\n- `validate-provenance-block.sh` → ADOPTED UPSTREAM (v0.135.0). Stock carries it.\n\n'"$V" > "$D/aspan.md"; printf "$H"'- **A real entry** with spans around a close\n\n  `a.sh` ADOPTED UPSTREAM (v0.2.0, verified 2026-01-02). `b.sh`\n\n'"$V" > "$D/btwn.md"; printf "$H"'- **Note:** a lead-in\n\n'"$V" > "$D/ctl.md"; ref() { o=$(bash "$R" "$1" --archive "$D/a.md" 2>&1); [ $? -ne 0 ] && grep -q 'REFUSING to rotate' <<<"$o"; }; ref "$D/ctl.md" || exit 9; ref "$D/colon.md" || exit 3; ref "$D/real.md" || exit 4; ref "$D/cclosed.md" && exit 5; ref "$D/nocolon.md" || exit 1; ref "$D/btbold.md" || exit 6; ref "$D/twoline.md" || exit 7; ref "$D/aftq.md" && exit 8; ref "$D/dbl.md" || exit 2; ref "$D/tnc.md" || exit 10; ref "$D/tc.md" || exit 11; ref "$D/aspan.md" && exit 12; ref "$D/btwn.md" && exit 13; exit 0

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
consumer installs" but "does the commit change something THIS id's subject depends on". The
engine now takes a per-id subject path from the entry's own receipt paths (see the batch-185
paragraph below), and that datum does not separate `b3debba3`, which touches its receipt file. A weaker but constructible half: a release commit citing an id it does not FIX needs a
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

**Held note (batch 178): NARROWED, STAYS OPEN.** On `b178-b2`, a naming set in which no commit
changes a path under `core/` or `templates/` (the two trees `install.sh` copies into a consumer) is
emitted as `NAMED-UPSTREAM-DOCS-ONLY`. The row is kept, with the full sha list. `named_reach` lists
files with `git log --no-walk --stdin -m`, because a merge lists none without `-m`. If the listing
fails, the answer is the old kind, never docs-only. The same predicate is folded into the
`NAMED-UPSTREAM-AMBIGUOUS` detail. The new kind is documented in SKILL.md step 3f and step 8 and in
emit-report's heading, which satisfies I39, and `docs/vocabulary-index.md` was re-rendered. On the
reference consumer's archive with its close annotations stripped (the population where upstream
named entries), 33 of 214 NAMED-UPSTREAM rows move to DOCS-ONLY. Re-derived with `git diff-tree -m`,
none of the 33 has a naming commit that touches `core/` or `templates/`. The control: the first 8
rows that stayed each have one. The live ledger moves 0 rows, because it has no open entry upstream
names. **What survives is the third class.** A commit that changes `core/` but not the entry's
subject (`b3debba3` for PC-S308) still reads NAMED-UPSTREAM. Batch 185 closes the part of it that
touches no receipt file. `b3debba3` touches PC-S308's receipt file and leaves only the receipt
substring unchanged, and substring matching is refuted (see below), so PC-S308 still reads
NAMED-UPSTREAM.

**Amended on `b178-b2-rel`: a naming commit that changes `VERSION` also reaches.** In this repo's
release convention the release commit names the id and changes only `CHANGELOG.md` and `VERSION`,
while its parent carries the `core/` fix and names nothing, so the first cut read real absorptions
as DOCS-ONLY. Its row text and SKILL.md step 8 also forbade annotating them. Both texts now say
the naming is not evidence and send the operator to the entry's subject. Re-run on the same
stripped archive (base `f7eec6f5`, theirs = the branch tip), DOCS-ONLY falls from 32 to 5 and
NAMED-UPSTREAM rises from 201 to 228. Every one of the 27 movers has a VERSION-touching naming
commit and no `core/` or `templates/` one, re-derived per parent with `git diff-tree`. Each of the 5
survivors has only naming commits that touch none of the three. Rows of every other kind are
byte-identical between the two engines. A release that names an id only to adjudicate it, such as
`c79a1d55` (ALREADY-FIXED), now reads NAMED-UPSTREAM too. That kind already says naming is not
absorbing. Fixture arm S954 holds the release shape, and its mutant `reach-no-version` is killed by
that cell alone. The receipt below has no VERSION-touching commit, so its verdict does not move.

The replacement receipt drives `ledger-reverify.sh` over three single-commit entries: docs-only,
templates-only, and a core commit that mentions an id whose subject it never touches. It exits 1
while that third class reads NAMED-UPSTREAM, which today is by design, so the entry stays open. It
exits 1 too if the docs-only entry is not emitted as DOCS-ONLY or the templates-only entry is
demoted. Scored: B1+B5 tip 1 (docs read as NAMED-UPSTREAM), fix 1 (third class only), a
`core/`-only predicate 1, and the delete-the-row fix 1 (`docs=<no row>`). Fixture arms: S950
docs-only, S951 templates-only, S952 merge, S953 ambiguous reach, each with a mutant (`reach-off`,
`reach-core-only`, `reach-no-m`).

**Producer half, batch 183: the third class is closed for a citation the WRITER marks. The
per-id-subject half stays open.** A distribution release that cites an id it did not discharge
now names it on its own body line, `Not-discharged: PC-S<n>` or `Not-discharged: PC-S<n>-<SLUG>`.
`named_cited_filter` in `ledger-reverify.sh` drops a commit from the naming set when only that
line names the id. It runs at all four query sites, before the count and before `named_reach`.
A set with no commits left emits `NAMED-UPSTREAM-CITED-ONLY` with every sha. Arm F of
`scripts/validate-release-version.sh` refuses a misspelled or misplaced form in a release range;
its false-positive set over 2001 `origin/main` messages is 0. This closes only the case where the
writer knows the citation is not a discharge. It is forward-only, so `b3debba3` still reads
NAMED-UPSTREAM. A consumer's installed engine reads the form as an ordinary mention until it
pulls. A core-touching commit that BELIEVES it discharged an id, and touched none of that id's
subject, read NAMED-UPSTREAM here. Batch 185 demotes it when the commit touches none of the entry's
receipt files. It still reads NAMED-UPSTREAM when the commit touches a receipt file without changing
the receipt substring, which is the PC-S308 shape. The
receipt below drives the fixed engine over four shapes: form-only, both forms, inline form, and
form-on-core plus an ordinary docs mention. It also uses a never-named control. Scored under
`set -uo pipefail`: tip (`abe3afb7`) 1, fix 0, mutants `filter-off`, `filter-any-form-line`,
`filter-unanchored`, `reach-unfiltered` and `cited-only-no-row` 1 each, engine absent 9. Fixture
arms S955-S959 sit in the `cited_only` unit of `ledger-reverify`, shard d, with the same five
mutants. The citation must appear in the BODY of the squash or release commit that lands on
`main`, which is the message a consumer's engine reads, and a misspelling there is caught by running
`scripts/validate-release-version.sh --commit <squash sha>` after the merge.

**Receipt replaced: the producer half shipped and the previous receipt exits 0, so it now tests the open half, claim 3.** It drives the shipping `ledger-reverify.sh` over four entries whose receipt subject is `core/subject.sh`: a core commit naming an id and changing only `core/other.sh` (the third class), a commit naming an id and changing the subject together with another core file (genuine), a docs-only naming, and a never-named control. It exits 0 only when the third class still has a `NAMED-` row whose kind is none of NAMED-UPSTREAM, -DOCS-ONLY, -CITED-ONLY or -AMBIGUOUS, while the genuine naming still reads NAMED-UPSTREAM and the docs naming still reads NAMED-UPSTREAM-DOCS-ONLY. Relabelling the third class as DOCS-ONLY does not satisfy it, because that row's text says no naming commit changes `core/`, which would be false here. The receipt also assumes the subject is taken from the entry's receipt path, which is the only per-id datum the seed carries. A fix that reads another datum has to re-anchor this receipt. It exits 9 when the engine is absent or the never-named control gains a `NAMED-` row. Scored under `set -uo pipefail` in copies of `core/`, with every edit asserted applied: tree as-is 1 (`third=NAMED-UPSTREAM`); a fix in the main loop that reads the receipt path and emits a new kind 0; a fix with a `named_touches` helper and a differently named kind 0; demote every core naming on a receipt-bearing entry 1; drop the row 1; relabel it DOCS-ONLY 1; the subject test inverted 1; a test for the subject existing at theirs instead of being touched 1; engine absent 9.

**Batch 185: a naming set that reaches code and touches NO receipt file is closed, and the PC-S308 shape stays open.** `named_subject` in `ledger-reverify.sh` takes the entry's subject set from the union of its `theirs_has|theirs_lacks` receipt paths, staged once before the entry loop. A path absent at theirs is resolved by unique basename at theirs, the way the verb dispatch already resolves a consumer-layout path. A path that matches 0 or more than 1 file, or that git could not read, is unresolvable, and any unresolvable path keeps the whole entry at the old kind. A naming commit that changes `VERSION` is judged over its release span: from the previous commit that changed `VERSION` (exclusive) through the naming commit. A naming commit that is not a release is judged on its own listing. Any listing failure answers the old kind. When the reach is `code`, the subject set is non-empty and resolved, and no naming commit changes any subject path, the row is `NAMED-UPSTREAM-OFF-SUBJECT`. That kind is decided after `cited` and `docs`, keeps every sha, and is never a close. An entry with no path receipt keeps its prior kind byte-for-byte. The ambiguous row does not take the predicate, because it stands for two or more entries with different receipt paths. **What stays open is the real PC-S308 shape.** `b3debba3` touches PC-S308's receipt file `core/skills/ai-dlc/steps/gate-validation.md` (1 in its `diff-tree -m` listing, against 0 for `validate-suppression-lifetime.sh`). None of the 32 changed lines in that file carries the receipt substring `gate-metrics.jsonl`, which occurs 4 times in the file at HEAD. A per-file test therefore scores it `touched`, and it still reads NAMED-UPSTREAM. **Substring matching is refuted, so do not build it.** The contract adversary modelled "did a naming commit change the receipt substring" in Python over the reference consumer's archive. It demoted 16 of 50 on-subject rows that were genuine absorptions whose anchors had gone stale. That figure comes from the model and not from a shipped engine. A fix for the remainder needs a datum that separates a cross-reference from a fix on the same file.

**Ship gate, measured over the reference consumer's archive with close annotations stripped.** The base engine `c18897d9` and the fix engine `d7bdcc41` each emitted 576 rows over that population. 570 are byte-identical and 6 moved to `NAMED-UPSTREAM-OFF-SUBJECT`. Five of the six are true off-subject rows. Each is named only by `e939a925` (`v0.373.0`), whose 43-commit release span touches none of the five receipt paths: PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK, PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW, PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD, PC-S299-UNREGISTERED-DRIFT-SCAN-SKIPS-CORE-FIXTURES-AND-CORE-SCRIPTS and PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1. The archive annotates each of them FALSIFIED, ALREADY-FIXED or DUPLICATE at an earlier version. The sixth, PC-S298-SETUP-SUBSTITUTION-EATS-SITE-DECLARATION-COMMENT, is a genuine absorption. `362f6840` (`v0.144.0`) adds the fix to `core/skills/ai-dlc-setup/SKILL.md`, while the receipt anchors on a structural precondition, `core/team-roles/dev-escalated.md`. Its sibling PC-S298-SETUP-NEVER-INSTRUCTS-REMEDIATOR-MODEL-FILL is named by the same commit and stays NAMED-UPSTREAM, which is the in-commit control. The measured set is therefore 6 movers: 5 true, and 1 of a named class. When an author picks a receipt path as a precondition rather than as the subject, a genuine absorption reads OFF-SUBJECT, and only that author can tell the two apart. The row text allows for that case, and no suppression heuristic is built, for the same reason substring matching was refused. Over the live ledger at the sprint tip, 0 of 12 rows moved. The engines' wall-clock difference was not resolved: under load 12-100 each engine's spread was about 105s against a gap of about 5s.

**Receipt replaced again: the previous one exits 0 on the per-file fix (scored on the R1 tip under `set -uo pipefail`) while PC-S308 is still open, which would retire a live entry.** The new receipt drives the shipping `ledger-reverify.sh` over seven entries in one repo. Clause (i) is a core commit that touches the entry's receipt file and leaves the receipt substring unchanged. The receipt exits 0 only when that entry has a `NAMED-` row outside NAMED-UPSTREAM, -DOCS-ONLY, -CITED-ONLY and -AMBIGUOUS, so it exits 1 while the PC-S308 shape stays open. Five controls each exit 1 and name their own clause on stderr when they fail. (ii) A core commit touching no receipt file must read NAMED-UPSTREAM-OFF-SUBJECT. (iii) A squash-shaped release, on an entry with two receipt paths where only the second is touched, must read NAMED-UPSTREAM. (iv) A branch-shaped release must read NAMED-UPSTREAM; its fix parent names nothing, and the naming child changes only `CHANGELOG.md` and `VERSION`. (v) A non-release naming commit must read OFF-SUBJECT; an unnamed neighbour in the same span touched its subject. (vi) A docs-only naming must read DOCS-ONLY. (vii) A never-named control that gains a `NAMED-` row exits 9, and so does an absent engine. The controls run before clause (i), so a broken engine never reports as the open entry. Scored under `set -uo pipefail` from the repo root, in scratch copies of `core/` with every mutation asserted applied: R1 tip 1 (`i-RECEIPT-FILE-TOUCHED-SUBSTRING-UNCHANGED-READ-AS-ABSORBED filetouched=NAMED-UPSTREAM`); base `c18897d9` 1 (`CONTROL-ii`); `span-off` 1 (`CONTROL-iv`); `span-expand-all` 1 (`CONTROL-v`); `subject-inverted` 1 (`CONTROL-ii`); `first-path-only` 1 (`CONTROL-iii`); a hand-built substring fix 0; engine absent 9; never-named control given a `NAMED-` row 9. The receipt carries no cleanup trap, matching the one it replaces. Its scratch repo is left under `TMPDIR`.

verify: sh L="$PWD/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; [ -f "$L" ] || exit 9; w="$(mktemp -d)" || exit 9; g() { git -C "$w/d" -c user.name=r -c user.email=r@r -c commit.gpgsign=false "$@"; }; c() { g add -A && g commit -qm "$1"; }; git init -q "$w/d" || exit 9; mkdir -p "$w/d/core" "$w/d/docs" "$w/c" || exit 9; echo 1.0.0 > "$w/d/VERSION"; for f in a s o q r x; do echo "ANCH_$f" > "$w/d/core/$f.sh"; done; c base || exit 9; B="$(g rev-parse HEAD)"; echo pad >> "$w/d/core/a.sh"; c "fix: absorb PC-S890-FILE-TOUCHED" || exit 9; echo x >> "$w/d/core/o.sh"; c "fix: absorb PC-S891-THIRD-CLASS" || exit 9; echo "ANCH_s fixed" >> "$w/d/core/s.sh"; echo 1.1.0 > "$w/d/VERSION"; c "1.1.0 -- absorb PC-S892-SQUASH" || exit 9; echo "ANCH_r fixed" >> "$w/d/core/r.sh"; c "fix: unnamed" || exit 9; echo n > "$w/d/CHANGELOG.md"; echo 1.2.0 > "$w/d/VERSION"; c "1.2.0 -- absorb PC-S893-BRANCH" || exit 9; echo "ANCH_x fixed" >> "$w/d/core/x.sh"; c "fix: unnamed neighbour" || exit 9; echo y >> "$w/d/core/o.sh"; c "fix: absorb PC-S894-OVER-EXPAND" || exit 9; echo p > "$w/d/docs/p.md"; c "docs(plan): mention PC-S895-DOCS-CTL" || exit 9; T="$(g rev-parse HEAD)"; e() { printf -- '- **%s** -- control.\n' "$1"; shift; for p in "$@"; do printf -- '  verify: theirs_has core/%s.sh "ANCH_%s"\n' "$p" "$p"; done; printf '\n'; }; { printf '# l\n\n'; e PC-S890-FILE-TOUCHED a; e PC-S891-THIRD-CLASS s; e PC-S892-SQUASH q s; e PC-S893-BRANCH r; e PC-S894-OVER-EXPAND x; e PC-S895-DOCS-CTL s; e PC-S896-NEVER s; } > "$w/c/l.md" || exit 9; o="$(bash "$L" "$w/d" "$B" "$w/c" "$T" "$w/c/l.md" 2>/dev/null)"; k() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l && $1 ~ /^NAMED-/ {print $1; exit}'; }; n() { printf '%s\n' "$o" | awk -F'\t' -v l="$1" '$2==l {c++} END {print c+0}'; }; [ "$(n PC-S896-NEVER)" -gt 0 ] && [ -z "$(k PC-S896-NEVER)" ] || exit 9; f() { v="$(k "$3")"; echo "BL145-$1 $2=${v:-<no row>}" >&2; exit 1; }; [ "$(k PC-S891-THIRD-CLASS)" = NAMED-UPSTREAM-OFF-SUBJECT ] || f "CONTROL-ii-FILE-UNTOUCHED-NOT-OFF-SUBJECT" third PC-S891-THIRD-CLASS; [ "$(k PC-S892-SQUASH)" = NAMED-UPSTREAM ] || f "CONTROL-iii-GENUINE-SQUASH-TWO-PATH-DEMOTED" squash PC-S892-SQUASH; [ "$(k PC-S893-BRANCH)" = NAMED-UPSTREAM ] || f "CONTROL-iv-BRANCH-RELEASE-SPAN-DEMOTED" branch PC-S893-BRANCH; [ "$(k PC-S894-OVER-EXPAND)" = NAMED-UPSTREAM-OFF-SUBJECT ] || f "CONTROL-v-NON-RELEASE-SPAN-EXPANDED" over PC-S894-OVER-EXPAND; [ "$(k PC-S895-DOCS-CTL)" = NAMED-UPSTREAM-DOCS-ONLY ] || f "CONTROL-vi-DOCS-NOT-DOCS-ONLY" docs PC-S895-DOCS-CTL; case "$(k PC-S890-FILE-TOUCHED)" in ""|NAMED-UPSTREAM|NAMED-UPSTREAM-DOCS-ONLY|NAMED-UPSTREAM-CITED-ONLY|NAMED-UPSTREAM-AMBIGUOUS) f "i-RECEIPT-FILE-TOUCHED-SUBSTRING-UNCHANGED-READ-AS-ABSORBED" filetouched PC-S890-FILE-TOUCHED ;; esac; exit 0



## BL-375 — the sandbox read-set tracer drops reports and omits fixtures on real runs, so the root-requiring `fs_usage` tracer cannot yet be retired

**RE-SCOPED ON THE OPERATOR'S BATCH-185 RULING: THE FIRST DELIVERABLE IS A SANDBOX TRACE THAT
DOES NOT DROP.** The sandbox mode is built: `--tracer sandbox` refuses root and runs every fixture
under `sandbox-exec`, and `operator-rulings.md` already requires sessions to trace with it. It is
not yet a replacement, because real `--list` runs lose reports. Recorded in the plan's resume block,
not re-measured here: at batch 183, 6 of 12 fixtures were OMITTED at load 7-10; at batch 184, 11 of
18 were OMITTED at load 3-8 with zero agent worktrees, with dropped-report counts from 7 to 1254.
Both maps were discarded. Load and worktrees alone do not explain the drops. Until a multi-fixture
`--list` run under the sandbox tracer finishes with no OMITTED line, `fs_usage` is the only tracer
that produces a committable map. Removing it, and running the `--tracer both` comparison, both wait
on that. The receipt below still names the end state, so it reads 1 throughout.

**DEFECT.** Operator-scheduled on 2026-09-29 as its own release, after v0.665.0.
`core/scripts/derive-fixture-readsets.sh` requires root (`[ "$(id -u)" = "0" ]`) because `fs_usage`
does, so every read-set trace blocks a release on an operator `sudo` step.

**Measured at batch 173 on four fixtures** (`plan-shape`, `document-partition`,
`derivation-capture`, `check-24-adversarial-convergence`), with the tree pinned at 43306861 and
compared against the map the operator traced there with `fs_usage` plus atime:
- The scoped sandbox tracer saw every map row outside `.git/**` and `.gitignore`. It missed 14 or
  15 rows per fixture, all of them git internals. The four fixtures produced 0 sandbox reports under
  `.git/`, against 56 to 5579 under `core/` in the same windows. Those rows appear in all 218
  mapped fixtures.
- It saw three negative lookups `fs_usage` never recorded, which is the safe direction.
- The atime tracer added nothing the sandbox did not see (sandbox ∪ atime = sandbox on all four).
- Micro-probe: `cat`, `[ -f existing ]`, `[ -f missing ]`, `[ -d missing ]`, `stat`, `git
  rev-parse`, `ls` and `readlink` are all reported, as unprivileged. The impossible-token control
  read 0.
- Event loss: the scoped profile had 0 drop notices in 6 runs, idle and with two heavy fixtures
  concurrent. An unscoped `(allow default (with report))` dropped 64,673 messages on `check-24` and
  lost paths, so the scope is load-bearing.
- Cost: about +4% on `derivation-capture`.

**Profile:**

    (version 3)
    (allow default)
    (allow file* process-exec* (subpath "<TREE>") (with report))

**Extraction,** started BEFORE the fixture (`log show` afterwards returns 0 lines, and the
`(trace ...)` directive writes nothing). In zsh, `log` is a builtin, so call `/usr/bin/log`.
`<TREE>` must be the canonical `/private/tmp/...` path.

    /usr/bin/log stream --level debug --style compact \
      --predicate 'sender == "Sandbox" AND eventMessage CONTAINS "<TREE>/"'

Per line, `Sandbox: <proc>(<pid>) allow <op> <TREE>/<path>`: keep `file*` and `process-exec*` ops,
then apply the deriver's DAEMONS filter, `norm`, the sentinel drop and `drop_ignored`.

**Open before it replaces `fs_usage`:**
- Only 4 of 218 fixtures were compared. Add the sandbox tracer as a mode beside the existing one.
  Take ONE final `sudo` run that traces all 218 with both tracers in the same pass, and require the
  sandbox's miss set outside `.git/**` and `.gitignore` to be exactly 0. Then remove `fs_usage` and
  the root check.
- Establish whether the runner's content-key skip reads the `.git/**` rows. If it does, record them
  without root (e.g. a fixed set for every mapped fixture); do not simply drop them.
- `log stream --level debug` was tested only from an admin-group account.
- `sandbox-exec` is documented as deprecated. It works on macOS 27.2.
- A read by a process outside the sandboxed lineage (an XPC or launchd helper) is invisible by
  construction. The per-fixture process census saw only bash, cp, grep, cmp, python and awk.

The batch-173 harness is kept outside the tree at
`~/.claude/projects/-Users-n8-git-ai-dlc/b173-sandbox-tracer/`: `trace2.sh` (the scoped tracer),
`mktree.sh`, `micro3.sh`, `compare.sh` and `load.sh`. It is evidence, not the implementation.

Held note (batch 178): the comparison mode is BUILT and the operator's fixed command now parses:
`sudo bash core/scripts/derive-fixture-readsets.sh --all --tracer both` (or `--list "<fixtures>"`).
It needs root, runs each fixture ONCE as `sudo -n -u "$SUDO_USER" sandbox-exec` under both tracers,
prints `sandbox-missed` and `fs_usage-missed` per fixture, and ends `SANDBOX-MISSES-NOTHING` (0),
`SANDBOX-MISSES <n> path(s) across <m> fixture(s)` (1, paths listed in `$WORK/both.missed`) or
`REFUSED` (2). Every refusal in that mode is 2, including not-root and a linked worktree, and so is
compared < listed, naming each uncompared fixture and why. It never writes the map. Miss = fs_usage
minus sandbox, after excluding `.git`/`.git/**` by prefix and the `git check-ignore` set; the
tracked FILE `.gitignore` is NOT excluded. The deriver's header states each choice and its reason.
`core/fixtures/readset-skip` drives the verdict span, the refusals, and a full stub-world run whose
map md5 must not move, with a mutant deleting the exit to prove the md5 would move. NOT run with
root: whether root `log stream` sees a `sudo -u` child's Sandbox reports is unmeasured; if it does
not, every fixture reads `sandbox set empty` and the run REFUSES rather than passing. Stays open
for the operator's run. The receipt reads the entry's real close: no `fs_usage -w` and no uid-0
check left in the deriver while `sandbox-exec -f` remains. It reads 1 on this branch by design.

**Batch 186: the drops follow the stream, not the fixture, and a one-fixture `--list` dodges
them for most units.** Three sandbox runs at `89aef8b5`, no agent worktrees on disk. A 27-fixture
`--list` at 1-minute load 4.7 on 18 cores OMITTED 6, with drop counts 82 to 748. The 21 that
traced clean, re-run alone as one `--list`, OMITTED 2 different ones (`ledger-reverify` 73,
`procsub-staged-refusal` 432), both clean in the first run. Each of the 27 traced alone, as its own
`--list`: 20 clean, 7 OMITTED with 34 to 2061 drops (`apply-drift-refile`,
`enforcement-map-sites`, `procsub-staged-refusal-boot`, `reconcile-emit-report`,
`self-update-gate`, `suite-pole-guard`, `validator-arm-selection-b`). Load rose to 35 during that
pass from processes outside this repo, so it is not a clean low-load reading. The 20 clean
fixtures' rows were committed; every other fixture's rows are byte-identical. A second
one-at-a-time pass over those 7, at `895ac0df` and load 7.3 falling to 3.8, mapped 3 more
(`procsub-staged-refusal-boot`, `self-update-gate`, `suite-pole-guard`). The other 4 OMITTED again:
`apply-drift-refile` 39, `enforcement-map-sites` 763, `reconcile-emit-report` 81,
`validator-arm-selection-b` 228 drops. Those four dropped on every pass. Size does not predict it:
two carry 858 rows, the other two carry 50 and 52, and the 350-row `procsub-staged-refusal`
traced clean alone.

**PARTIAL IN BATCH 188 (0.715.0): `validator-arm-selection-b`'s drops have a measured mechanism
and a fix; the other three do not.** Measured by the batch-188 diagnosis hand in a scratch clone
of `25ac399d`:
- `validator-arm-selection-b` dropped 222-228 reports on every trace. Every drop fell in a 1-2s
  window running at 14k-46k reports/s with 26-118 concurrent `grep -r` from the fixture's inner
  `xargs -P 6` pools. Shard b's concurrency is the attribution pool, run twice, plus the seeded
  plain run dispatched beside it. A synthetic reproduction dropped at K=6 and K=12 concurrent
  greps, never at K=1 or K=2, and never serially at 26.6k reports, so concurrency is the variable
  and volume is not. At inner width 1 it traced clean from load 34.8: 0 drops, 956 paths, covering
  every committed non-`.git` row except 9 rows for files no longer in the tree, plus 122 new rows.
- `enforcement-map-sites` dropped 1445 reports on the diagnosis hand's run, made with the sibling
  pool at width 1. The knob does not reach it: its own pool is a hard-coded `JOBS=8`, so "at
  width 1" does not describe it. Its drops come from its `cp -R` seed.
- `apply-drift-refile` and `reconcile-emit-report` drop on load-dependent upstream events.

The fix: `core/scripts/derive-fixture-readsets.sh` launches every traced fixture as
`... env VAS_INNER_POOL_WIDTH=1 bash <run.sh>` on both launch lines, after `sudo -u` and
`sandbox-exec`. Under `fs_usage` and `--tracer both` the fixture runs through sudo, whose
env_reset strips an export or a prefix in front of it. Under `--tracer sandbox` no sudo is on the
path, so a prefix in front of `sandboxed` would survive there; the `env` form is used on every
path so that one spelling holds under all three tracers.
`core/fixtures/validator-arm-selection/run.sh` resolves `JOBS` once from
`${VAS_INNER_POOL_WIDTH:-6}`, refuses a value that is not an integer from 1 to 64 with exit 2
(more than 3 digits is refused before any numeric test, which a 20-digit value would overflow),
and prints `inner pool width: N`. The width changes the schedule, not the work, so a set traced
at width 1 is the set at width 6. The knob carries no `AI_DLC_` prefix as future-proofing against
the fixture env scrubs keyed on it; no scrub is on this path today.
Held by `validator-arm-selection` (phase `width`: unset gives 6, 1 gives 1, 64 gives 64; 0, `abc`,
65 and a 20-digit value exit 2; and a source-text check that both `xargs` pool sites read
`"$JOBS"` and `JOBS` is assigned once) and `core/fixtures/readset-skip` (under `--tracer
sandbox` a copy of the real deriver traces a probe that echoes the knob and must log `width=1`,
the same probe outside the deriver logs `unset`, and a deriver copy with the injection removed
fails the arm; under `--tracer both` the stub world's sudo strips the knob as env_reset does, and
fxa must log `width=1`, which the injection moved in front of sudo, the `sandboxed` launch
dropping it, and a `VAS_INNER_POOL_WIDTH=1 sandboxed` prefix each fail). The `fs_usage` launch
line runs only as root and is covered only by the operator's own run.
**The shipped knob reaches the traced run, but width 1 is NOT sufficient: the fixture still
drops.** Measured on two re-traces at 0.715.0 (`9c28d78e`), in the main checkout with no linked
worktree. In both, `$TRACE_ROOT/w/validator-arm-selection-b.log` line 2 reads
`inner pool width: 1`, so the injection worked.
- The first re-trace started at 1-minute load 24 and the stream dropped reports 7 times.
- The second started at load 6 and dropped 19 times. Load rose to 25 during that run from
  other work on the box.

The deriver omitted the fixture, failed its own `zero fixtures mapped` control, and wrote no map
both times. That is down from 222-228 drops at width 6, and still not zero. The diagnosis clone's
0-drop run at width 1 is a single sample. At width 1 shard b still runs two validators at once,
the seeded run at `:413` beside the attrib pool, so the K=2 synthetic, which was clean, is the
nearest analogue and not an equivalent. Stage 1 stays unmet for all four fixtures.

**BATCH 189: THE ARM-6 SERIALISATION LEVER IS STRUCK.** ~~Serialise the seeded run against the
attrib pool when traced.~~ Refuted by the one trace on disk (`validator-arm-selection-b`, 0.715.0,
inner pool width 1, 19 drop notices). It places 0 of the 19 in arm 6's concurrent window. Of the
19, 17 fall in the seed `cp -R` burst at `core/fixtures/enforcement-map-sites/seed.sh:27-34`,
which is one `cp` process at about 4000 reports per 100ms, a third of them xattr reads. One falls
in an I91/I94-shaped `grep` burst at 09:08:30 and one at a burst tail. This is ONE sample. Two
levers replace it:
- (a) **The validator cwd fix, `BL-436`, in 0.716.0.** Arms I81, I91, I94 and I95 of
  `scripts/validate-enforcement-map.sh` read the process cwd, so a seeded tree's validator run
  from the repo root grepped the LIVE tree. That trace carries 166,633 such live-tree grep
  reports. Once the validator `cd`s into its own tree, the seeded tree's greps land under
  `$TMPDIR`, outside the profile's subpaths, and are expected to leave the stream. That is a
  prediction from the mechanism. The lead's before/after trace of `validator-arm-selection-b
  enforcement-map-sites` on the release branch and on the base is the measurement.
- (b) **The seed copy form: measured, and no form ships.** Each form copied the four subtrees of
  `seed.sh:27-34` and was traced alone under the deriver's own sandbox profile and stream reader,
  3 reps per form, at 1-minute load about 28-37 on the base tree `9bbc5a50`. Every rep was
  byte-equivalent to an untraced `cp -R`. Reports per rep, then drop notices:
  `cp -R` 8719/8984/6600 (about 2850 xattr), 0/0/0; `cp -RX` 2981/3009/2992 (0 xattr), 0/0/0;
  `tar` about 28000, 0/47/68; `tar --no-xattrs --no-mac-metadata` about 6000, 0/0/0;
  `ditto --noextattr` about 10500, 33/0/17. **The control does not drop:** `cp -R` alone gave 0
  notices in 3 of 3 reps, so the 17 seed-burst drops in the fixture trace come from the burst
  coinciding with other traced load, not from the copy alone, and this differential cannot show
  that any form removes them. `cp -RX` cuts the burst to about a third of its reports with an
  identical read set (956 paths in each rep, 0 missing against the union of `cp -R`'s sets). It is
  the candidate to try inside a real fixture trace, and it is unproven.

**A TRACE CAN LOSE REPORTS WITH NO DROP NOTICE.** In the batch-189 seed measurement, `cp -R` rep 3
recorded 946 of the 956 paths it must have read, and 747 `file-read-data` reports against 956, with
ZERO `Messages dropped` notices. One sample. So a run with no OMITTED line and 0 notices is not
proof of a complete read set, and the deriver's loss guard keys only on the notice. This is an
open measurement: the close criterion needs a completeness control as well as a zero-notice count.

**Stage 1's close criterion, as the batch-189 contract states it:** three consecutive
multi-fixture `--list` traces under the sandbox tracer with no OMITTED line and 0 drop notices,
with a completeness control beside the notice count.

**Do NOT switch the stream to `--style ndjson` to cut the report rate.** Measured: it lost up to
two-thirds of per-pid coverage while printing zero `Messages dropped` notices. The deriver's loss
guard keys on that notice, so ndjson would turn an omitted fixture into a silently smaller
read-set.

Still open: `enforcement-map-sites`, `apply-drift-refile`, `reconcile-emit-report` and
`validator-arm-selection-b` drop, so no multi-fixture `--list` is yet guaranteed clean, and the
stage-1 deliverable is not met.

verify: sh D=core/scripts/derive-fixture-readsets.sh; [ -f "$D" ] || exit 9; B="$(grep -v '^[[:space:]]*#' "$D")"; grep -q 'sandbox-exec -f' <<<"$B" || exit 1; grep -q 'fs_usage -w' <<<"$B" && exit 1; grep -qF '"$(id -u)" = "0"' <<<"$B" && exit 1; exit 0

**BATCH-189 BEFORE/AFTER TRACE, ONE SAMPLE PER SIDE.** `bash core/scripts/derive-fixture-readsets.sh --list "validator-arm-selection-b enforcement-map-sites" --tracer sandbox`, main checkout detached at each sha in turn, map restored and nothing committed. Base `9bbc5a50` (load 4.52): `validator-arm-selection-b` OMITTED with 108 drop notices, `enforcement-map-sites` OMITTED with 894. Tip `946fb8ce`, carrying the BL-436 cwd fix (load 11.46): `validator-arm-selection-b` CLEAN, `enforcement-map-sites` OMITTED with 1036. Lever (a) moved the fixture it was predicted to move, at the higher load; one sample per side is not a close. `enforcement-map-sites` still drops on its seed `cp -R` burst, where no copy form was shown to help. Stage 1 and the three-consecutive-clean-traces criterion with a completeness control stand.

## BL-438 — QA writes a verdict vocabulary and a file name that gate-validation.md Check 1 does not read

**NOTE.** Measured by the batch 189 contract adversary on the reference consumer's
`docs/reviews/s316/` and re-counted read-only there for this entry. `qa.md:303` prescribes
`docs/reviews/s<N>/<story-index>-gate2-qa.md`; of the 20 QA files in that directory, 0 carry that
name (`ls | grep -c -- '-gate2-qa.md'`) and all 20 are named `<idx>-qa-validation.md` or
`<idx>-qa-validation-p<k>.md`, against 21 `-code-review` files as the same-directory control. 18
of the 20 carry a column-0 `Verdict: PASS` line (`grep -qE '^Verdict: PASS'`), and 19 of 20 carry
a PASS on a line Check 1's pattern matches. `gate-validation.md` Check 1 reads verdict values from
the set `code-reviewer.md` declares under `## Verdict`, where only `APPROVED` passes, and `qa.md`
declares no `## Verdict` set of its own. So a QA verdict of `PASS` is outside the I112 set, and the
name the role prescribes is one this consumer never wrote. One file (`1b-qa-validation.md`) reads
NEEDS_REWORK and one (`4b-qa-validation.md`) matches Check 1's pattern twice. This is why gate 2
ships serial-only in BL-437: a QA shard merge would have had to choose a vocabulary first.

verify: manual -- the remedy is a choice between giving qa.md its own declared verdict set and Check 1 a second set, or binding QA to the code-reviewer set; either is a contract change across a consumer's existing review files and is the operator's to make.

**LANDED (v0.720.0, verified TBD).** `qa.md` now declares its own set under a bare `## Verdict`
heading, in the template shape `code-reviewer.md` uses: `PASS | NEEDS_REWORK`. Check 1 in
`gate-validation.md` reads each review file against the set of the gate its Gate-status line
cites it for (the gate comes from the citation, not the filename; a file cited for both gates
must read a value in both sets). A capital run followed by a hyphen or other qualifier reads as
the whole token, so `PASS-pending-PVC` fails. Check 1 carries one bullet per owner: `- **Code-review verdict
values (`code-reviewer.md`)**` and `- **QA verdict values (`qa.md`)**`. I112 binds both sets,
each owner against its own bullet. It refuses a missing heading or a short template per owner,
and the span scan's exclusion is the union of the two sets. The arm's self-probe seeds a swapped
pair of bullets and requires both owners to report both directions on it and to stay quiet on
the matching pair. `core/fixtures/enforcement-map-derivations` A58-A63 hold the QA half. Each of
the six scores an unmutated control in its own frame, then requires the exact I112 message and
finding count. A58: qa.md loses `## Verdict`. A59: qa.md gains an unnamed member. A60:
`APPROVED` on the QA bullet. A61: `PASS` on the code-review bullet. A62: the two bullets merged,
which produces two findings. A63: `PASS` added to code-reviewer.md's template. Each cross-gate
token is derived as a set difference of the two templates.

**Scope narrowed on purpose.** Check 1 stays `adjudication: llm`. The arms prove that both sets
are bound to Check 1's text, and they say nothing about how a lead executes Check 1 at a gate.

**Consumer replay, read-only on the reference consumer's `docs/reviews/s316/`.** It holds 22 QA
files, all named `<idx>-qa-validation[-p<k>].md`. Read by Check 1's own rule (its grep, then
its value rule with the suffix guard), 21 of the 22 read `PASS` and one, `1b-qa-validation.md`,
reads `NEEDS_REWORK`. Its tracked sibling `1b-qa-validation-p2.md` reads `PASS`, and Check 1's
re-review rule reads that higher-`p<M>` sibling in place of the cited file and names both. A simpler reader keyed only on `^Verdict:` and a bare heading scores 20 of 22,
because it misses `B1-qa-validation-p2.md`'s `## Verdict: PASS` line. `4b-qa-validation.md`
matches the grep twice, and both lines read `PASS`. Every s316 QA value is in the new set.

**The older `-gate2-qa.md` files are history.** The consumer's `docs/` holds 37 files named
`*-gate2-qa.md` (36 under `docs/reviews/`, `/usr/bin/find`). That is 38 with the broader glob
`*gate2-qa*`, which adds one `-evidence-summary.md`. No reader in `core/` opens that name. The
only `core/` hits are fixture seed data: two path-grammar probes in `artifact-path-conformance`
and one evidence-seed row in `gate-adjudication`. None of them is a reader. Check 1 reads the
file a story's Gate-status line cites, so none of those 37 files is re-read and none needs
migrating.
