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
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
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

## BL-451 — the slowest fixtures take 23 to 41 minutes each, and four of the five ship to consumers

**DEFECT.** Filed in batch 199 on the operator's direction that these wall clocks are not acceptable. Loaded costs in
`$(git rev-parse --git-common-dir)/ai-dlc-fixture-durations` at filing: `apply-self-overwrite` 2463s,
`apply-setup-sited-merge` 2430s, `self-update-fixture-log` 2425s, `remediator-shard-join` 2420s,
`backlog-receipt-binding` 2166s, `review-shard-merge` 1738s. These are LOADED figures and some may carry a laptop sleep
(batch 198 recorded a 2608s gate run in transit); each must be re-measured solo in a clean worktree before it is cut.
Only `backlog-receipt-binding` is `.dist-only`; the other four ship, so the reference consumer pays them on every push
that selects them.

**Measured cause, on one of them.** `review-shard-merge` went from 731s to 1738s across batch 199. Its `score()` runs
every predicate for every mutant (arms × mutants), and the batch added arms and mutants to both factors. The same shape
is likely behind the mutation-battery fixtures above (`self-update-fixture-log` 35 mutation sites,
`remediator-shard-join` 10, `apply-self-overwrite` 8) and is not established for `apply-setup-sited-merge`, which has
none.

**Remedy.** Per fixture: measure solo, attribute the time, then cut it — move a mutation battery behind a shipped
fixture into its own `.dist-only` fixture (`fixture-ship-decl.md`), score mutants in parallel within the fixture, and
remove repeated setup. `review-shard-merge` is being split in batch 199 as the first instance.

verify: manual -- the subject is wall clock on a loaded box, which no in-tree receipt can measure; close on a solo
re-measurement of each named fixture recorded in the closing entry.

## BL-452 — pre-push never traces the unmapped fixtures it runs, so they stay unmapped and run on every push

**DEFECT.** Filed in batch 199 on the operator's direction ("close the cycle"). A fixture with no row in
`.ai-dlc-fixture-readsets.tsv` runs on every push, and nothing maps it unless a session hand-runs the deriver. Supersedes
`BL-375`'s stage 1, closed by ruling in the same batch. Design and two adversary rounds: the contract is quoted
verbatim in the batch-199 record of `docs/plans/graph-ledger-full-drain.md` (or its archive once rotated). In short: after a green suite, both hooks start one detached, unprivileged `derive-fixture-readsets.sh --tracer sandbox`
run for the unmapped fixtures and record clean traces in a local map under git-common-dir, keyed on the hash of every
recorded path and of the deriver. Measured: per-fixture `FXTAG` profile tags attribute concurrent reports with zero
cross-attribution, drops are system-wide, and silent loss requires a private tree copy so the atime canary can run.

verify: sh grep -qF -- '--local-map' .githooks/pre-push && grep -qF -- '--local-map' core/git-hooks/pre-push

## BL-453 — teammate verification calls are ad-hoc compound shell that no allow rule matches, so an unattended sprint stops for approval

**DEFECT.** Carries the reference consumer's PC-S317-TEAMMATE-VERIFICATION-COMMANDS-ARE-AD-HOC-COMPOUND-SHELL-THAT-NO-ALLOW-RULE-MATCHES-SO-THEY-STOP-FOR-APPROVAL.
A teammate confirming a claim writes a `bash -c` wrapper, a function definition, or a chain of variable assignments
joined by `;`/`&&`. None of those matches a command-prefix allow rule, so each one raises an approval prompt, and in an
unattended sprint nobody is there to answer it. The filing's census counted 38 wrapper-shape calls in 840 (a function
definition or `bash -c`); remediator 30/290, adversary 3/525.

**Fix (option 1 of the filing).** One byte-identical paragraph in every file matching `core/team-roles/*.md`, the glob
`install.sh` copies, opening `**Verify with one read-only command per Bash call.**`: confirm a claim with a `derived`
fence replayed by one `scripts/ai-dlc/validate-artifact-derivations.sh` call, or with one read-only command in its own
Bash call. Invariant `I121` binds it: present exactly once in every role file as its own paragraph, byte-identical,
no copy elsewhere, and the validator path resolving to `core/scripts/validate-artifact-derivations.sh`.

**Done when, consumer side, owed as residue and not held open here.** On the first consumer sprint after a pull that
carries this text, re-run the filing's census over that sprint's subagent transcripts (wrapper-shape calls: a function
definition or `bash -c`), against the before figures above. Options (2)-(4) of the filing are weighed only if the rate
stays high. That census is recorded as owed residue in the CHANGELOG at release; the receipt below closes on the text.

verify: sh set -- core/team-roles/*.md; [ -f "$1" ] || exit 9; awk -v n="$#" -v op='**Verify with one read-only command per Bash call.**' -v fp='`scripts/ai-dlc/validate-artifact-derivations.sh <that file>`' 'function chk() { if (w != 1 || s != 1 || !p) bad++ } FNR == 1 { if (nf++) chk(); w = 0; s = 0; p = 0; at = 0; pr = "" } { if (index($0, op)) s++; if (index($0, op) == 1 && pr == "") { w++; at = FNR } if (at && FNR - at <= 7 && index($0, fp)) p = 1; pr = $0 } END { if (nf) chk(); if (nf != n) bad++; exit (bad ? 1 : 0) }' "$@"
