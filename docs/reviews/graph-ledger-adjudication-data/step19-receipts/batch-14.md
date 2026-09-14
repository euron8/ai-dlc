# Step 19 batch 14 — replacement `verify:` receipts for the two post-pin entries

**Covers pins 4357 and 4392 — the same two as `batch-13.md`, deliberately.** This is the
`batch-12.tsv` assignment, authored by `step19-b12`, first written as `batch-12.md` and renamed
once on instruction; it is offered here for comparison rather than as a second claim.
`extract-receipts.sh` ARM 4b exits 8 while both files are present, so exactly one of the two must
survive reconciliation. Section "Where this differs from batch-13" at the end states the three
measured differences and nothing else.

Both pins sit **above** the 4356-line corpus pin, so they are outside the pinned snapshot and
outside the Phase 0 census. They were read from the LIVE ledger at
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md`, and the pin was still
verified first as the boundary those reads sit above: `head -n 4356` md5
`2fd444dcf406cdff728fe3c0c4352267`, with the 4355-line control differing
(`d4e39a96a33c5c92adfe4c8457020064`) in the same invocation. The live file is 4503 lines and
`awk 'NR>=4357 && /^## /'` puts headings at 4357, 4392 and 4435, so each entry's body is the span
up to the next heading and both assigned line numbers are current.

Labels are verbatim from `docs/reviews/graph-ledger-adjudication-data/post-pin-verdicts.tsv`, the
map the extractor unions with the census for exactly these pins.

All derivations against `/Users/n8/git/ai-dlc` at committed HEAD **`0f67164`**, re-run there after
the tree moved; consumer read-only. Nothing was written outside this file.

**The receipts are cwd-invariant, and that is deliberate.** The brief states the receipt runs with
the process cwd at `$DIST`; the emitter disagrees. `ledger-reverify.sh:1015` runs
`bash -c "cd \"$CONSUMER\" && { $rest; }"`, so the consumer engine runs it at **`$CONSUMER`**, while
`extract-receipts.sh` measures it at `$DIST` under `set -u`. Each receipt therefore opens with
`[ -n "${THEIRS_TREE:-}" ] || exit 127; cd "$THEIRS_TREE" || exit 127` and names no relative path.

**The cwd is `$THEIRS_TREE` and not `$DIST`, because `$DIST` is a CHECKOUT.** `ledger-reverify.sh`'s
header records that a receipt reading `$DIST` as a filesystem path measures whatever the operator
last checked out rather than `theirs`, and the grammar at `ledger-reverify.sh:809` refuses that form
as NEEDS-REVIEW. The subject each receipt runs — the script under `core/scripts/` — is therefore
resolved from the materialized tree at theirs, and the opening guard degrades the receipt to a
review rather than a false close on an engine that predates the value.

**Neither receipt exposes a path to `receipt_absent_subjects`, and that took a deliberate spelling.**
That guard (`ledger-reverify.sh:502-515`) extracts `(docs|_bmad-output|scripts|\.claude)/…` from the
receipt text with an **unanchored** regex, so a receipt naming `core/scripts/x.sh` yields
`scripts/x.sh`, which does not exist under the consumer root — turning a future genuine
CLOSE-CANDIDATE into a NEEDS-REVIEW. Both receipts split the path at that boundary
(`S="$THEIRS_TREE/core/scripts"; F="$S/…"`), and the guard's own regex run against both receipt texts
extracts **0** paths, against a control text (`scripts/ai-dlc/foo.sh`) from which the same
invocation extracts one.

## Pin 4357 — `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX`

**Re-derivation.** The subject is `core/scripts/validate-spec-join.sh:164`, which is the whole of
the entry: `CAP_ENTRIES="$(grep -E '^[[:space:]]*[-*][[:space:]]*\((capability|capabilities)\)' "$MEMLOG")"`
— a `)` demanded immediately after the type word — guarding the `exit 2` at `:167`, which precedes
every other join in the script. `grep -cF '\((capability|capabilities)\)'` over that file returns
**1**, against the impossible needle `\((capabilityZZZ)\)` returning **0** in the same invocation.
The entry carries no directive: `grep -c '^verify:'` over the live span `4357,4391` returns **0**,
against a control of **69** over the pinned 4356 lines, same invocation. The receipt is behavioural
— it drives the shipping script twice over one synthetic spec seeded two ways, differing only in the
producer's optional ` by <author>` qualifier, and reads the **exit code**, so there is no substring
for a fix to quote back. The bare-form arm is the control and must return exactly **0**, which is
what proves the synthetic corpus satisfies every other arm of the script and that the qualified
run's `2` is this predicate and not some unrelated DISARM.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh [ -n "${THEIRS_TREE:-}" ] || exit 127; cd "$THEIRS_TREE" || exit 127; S="$THEIRS_TREE/core/scripts"; V="$S/validate-spec-join.sh"; [ -f "$V" ] || exit 127; d=$(mktemp -d) || exit 127; mkdir -p "$d/bare" "$d/qual" || exit 127; printf "# PRD\n\n- FR-S303-1 the functional requirement, CAP-7\n- LR-S303-1 the locked requirement\n" > "$d/prd.md"; printf -- "# SPEC\n\n- **CAP-7** the capability\n" > "$d/bare/SPEC.md"; cp "$d/bare/SPEC.md" "$d/qual/SPEC.md" || exit 127; printf -- "- (capability) LR-S303-1 -> CAP-7\n" > "$d/bare/.memlog.md"; printf -- "- (capability by bmad-spec) LR-S303-1 -> CAP-7\n" > "$d/qual/.memlog.md"; cmp -s "$d/bare/.memlog.md" "$d/qual/.memlog.md" && { rm -rf "$d"; exit 127; }; bash "$V" --spec "$d/bare" --prd "$d/prd.md" >"$d/b.out" 2>&1; b=$?; bash "$V" --spec "$d/qual" --prd "$d/prd.md" >"$d/q.out" 2>&1; q=$?; [ "$b" -eq 0 ] || { rm -rf "$d"; exit 127; }; [ "$q" -eq 0 ] && { rm -rf "$d"; exit 1; }; [ "$q" -eq 2 ] || { rm -rf "$d"; exit 127; }; grep -q "no .(capability). entries" "$d/q.out" || { rm -rf "$d"; exit 127; }; rm -rf "$d"; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**

**RE-MEASURED WHEN THIS RECEIPT MOVED ONTO `$THEIRS_TREE`: rc=1 (CLOSE-CANDIDATE), and before the
seed repair below it was a NULL at rc=127.** Neither value is caused by the rewrite: original and
rewritten forms were driven in the same invocation against a detached worktree and a `git archive`
of the same commit, and agreed. The rc is a property of the subject, not of the harness's refs —
re-run with `$BASE` at three distinct commits it reads 1 each time.

**Two-sided probe.** Base rc=0 with the bare-form control at **0** and the qualified run at **2**;
mutant rc=1, the mutation being the one literal `\((capability|capabilities)\)` widened to
`\((capability|capabilities)([[:space:]][^)]*)?\)` in a `mktemp -d` copy — applied by a script that
asserts the occurrence count is exactly 1 before writing, so a silent no-op mutation cannot pass as
a fix. `cmp` of the two copies returned non-zero before either output was read, and under the mutant
the control arm stayed at **0** while the qualified arm went **2 → 0**, so the two sides moved for
the reason claimed. Every extraction and every sanity arm exits **127**, never a bare non-zero: a
missing script, a failed `mkdir`/`cp`, two identical memlogs, a control arm that is not 0, a
qualified rc that is neither 0 nor 2, and a `2` whose message names a different DISARM arm.

**Anchor shapes checked.** *Quote-back* — the verdict is an exit status of a live run, and no
comment recording a removal can produce rc 2. *Invented phrasing* — the qualifier shape
` by bmad-spec` was not taken from the filing's prose; the predicate it must defeat was grepped out
of `:164` with a control, and the message discriminator was read from `:166` rather than described.
*The fix's own closing clause* — the only prose match in the receipt (`no .(capability). entries`)
is read from the RUN's stderr, never from a file, and it can only route to 127, so it cannot
manufacture a close.

**Hesitation.** The filing's own under-narrow fix — accepting ` by <author>` and nothing else —
flips this receipt to CLOSE-CANDIDATE, because that is precisely the shape the receipt seeds. That
is the right answer for *this* entry, whose claim is about the `by <author>` suffix, but it means the
receipt closes on a fix that still misses the producer's ordinal-before-`by` form; the entry's
adjudication upstream is where that residue is owed, not here. Secondarily, the synthetic spec is
minimal, so a future arm added *above* `:164` that this corpus fails to satisfy would drop the
control arm off 0 and the receipt would report NEEDS-REVIEW rather than STILL-LIVE — the safe
direction, and it costs a read.

**THAT SECOND HESITATION CAME TRUE, AND IT HAD MADE THE RECEIPT A NULL.** Re-measured while moving
this receipt onto `$THEIRS_TREE`: an arm added above the subject — the `mentions CAP-<n> but DEFINES
none` DISARM — refuses the seeded `SPEC.md`, which writes `CAP-7 the capability` as bare prose. Both
arms exited 2, the control arm was therefore not 0, and the receipt exited **127** on its
`[ "$b" -eq 0 ]` guard. A receipt pinned at 127 reports NEEDS-REVIEW on every run and can never
report either verdict, so it measured nothing at all — the safe direction, as predicted, and still
a dead receipt. **The repair is in the SEED, not in the arms**: the DISARM's own message names the
shape it reads, so the seed now writes `- **CAP-7** the capability`, which the definition grammar at
`:535` matches (verified by driving that one `sed` expression against the seed text, which yields
`CAP-7`, and against the old seed text, which yields nothing). With that seed the control arm is
**0** and the receipt is armed again.

**And armed, it reads 1 — the subject was fixed upstream.** `CAP_ENTRIES` now lives at `:797` and
already carries `([[:space:]][^)]*)?`, the exact widening this entry's mutant paragraph describes,
so the qualified arm returns 0 and the receipt reports CLOSE-CANDIDATE. Driven four ways in one
invocation, on a `mktemp` copy `cmp`-asserted to differ from the shipping file: shipping grammar
with the repaired seed gives bare=0 qual=0; the grammar reverted to the entry's stated old form
gives bare=0 qual=2. The two sides move on the grammar and not on the seed, so the `1` is this
entry's own subject being gone rather than an artifact of the seed repair. Adjudicating that close
is the upstream entry's, not this file's.

## Pin 4392 — `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF`

**Re-derivation.** `core/scripts/report-propagation-fanout.sh:255` is one `export` statement
carrying **10** `FANOUT_*` variables, the full unified diff (`FANOUT_DIFF="$DIFF"`) and the whole
`git ls-files` corpus (`FANOUT_FILES="$CORPUS_FILES"`) among them, and `:262` then runs
`python3 - <<'PYEOF'`. That is the **only** `python3` invocation in the file — `grep -c 'python3 - <<'`
returns **1** — which is what makes a single env dump from a shim safe to read as *the* payload. The
entry carries no directive: `grep -c '^verify:'` over the live span `4392,4434` returns **0** against
a control of **69** over the pinned corpus, same invocation. The filed crash reproduces verbatim at
HEAD: `bash core/scripts/report-propagation-fanout.sh adec9ae` exits **126** with
`line 262: /opt/homebrew/bin/python3: Argument list too long`, the diff for that scope being
**1277175** bytes against `getconf ARG_MAX` of **1048576**.

**And that reproduction is exactly what the receipt must NOT use.** The engine maps 126 and 127 to
NEEDS-REVIEW, not STILL-LIVE, so a receipt that reproduces the crash reports the receipt as broken.
The receipt therefore measures the **channel** rather than the overflow: it puts a `python3` shim
first on `PATH`, dumps the child's environment, and asserts that each payload's own signature is
present in it — a whole line equal to the tracked path `VERSION` for the corpus, and `^@@ ` hunk
headers for the diff. So a fix that renames `FANOUT_DIFF` while leaving it on the env channel cannot
close it, and neither can a PARTIAL fix. Both signatures carry a control against the source payload
in the same invocation, so their absence from the env means the channel changed and not that the
signature vanished: `git ls-files --error-unmatch VERSION` must succeed, and the scope's diff must
carry at least one `^@@ ` hunk.

**BOTH SIGNATURES ARE WHOLE-LINE ANCHORED, AND THAT IS LOAD-BEARING RATHER THAN TIDY.** An
unanchored needle naming the script's own path matches inside `FANOUT_DIFF` as readily as inside
`FANOUT_FILES`, because this program's own artifacts quote receipt text — the brief and
`replacement-receipts.tsv` both do, by design. Measured against the partial-fix mutant at this HEAD:
the anchored `^VERSION$` reads **1** on the shipping script and **0** the moment `FANOUT_FILES`
moves off the environment, so it measures the corpus channel and only that. A diff line can never
equal `VERSION`, because every diff line carries a `+`/`-`/space/`@`/`d` prefix.

**The scope is `${BASE}~1 $BASE`, and the immutability is the point.** Two refs, both derived from
the engine's own exported `BASE`, so the diff is a committed commit's own diff — **5415** bytes,
**3** hunks, re-measured unchanged after the tree moved — rather than `HEAD~1` against a working
tree, whose size drifts with every commit and whose non-emptiness the upstream backlog receipt simply
assumed. It is guarded rather than assumed here: an empty diff exits **127**.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh [ -n "${THEIRS_TREE:-}" ] || exit 127; cd "$THEIRS_TREE" || exit 127; S="$THEIRS_TREE/core/scripts"; F="$S/report-propagation-fanout.sh"; [ -f "$F" ] || exit 127; git -C "$DIST" ls-files --error-unmatch VERSION >/dev/null 2>&1 || exit 127; h=$(git -C "$DIST" -c core.quotepath=false diff -U0 "${BASE}~1" "$BASE" | grep -c "^@@ ") || exit 127; [ "$h" -ge 1 ] || exit 127; d=$(mktemp -d) || exit 127; printf "#!/bin/sh\ncat >/dev/null\nenv > %s/env\n" "$d" > "$d/python3" || exit 127; chmod +x "$d/python3" || exit 127; AI_DLC_PROJECT_ROOT="$DIST" PATH="$d:$PATH" bash "$F" "${BASE}~1" "$BASE" >/dev/null 2>&1; [ -s "$d/env" ] || { rm -rf "$d"; exit 127; }; grep -q "^PATH=" "$d/env" || { rm -rf "$d"; exit 127; }; f=$(grep -c '^VERSION$' "$d/env"); g=$(grep -c "^@@ " "$d/env"); rm -rf "$d"; { [ "$f" -ge 1 ] || [ "$g" -ge 1 ]; } || exit 1; exit 0
```

**Measured today: rc=0 (STILL-LIVE).**
**RE-MEASURED WHEN THIS RECEIPT'S SUBJECT READ MOVED ONTO `$THEIRS_TREE`: rc=1 (CLOSE-CANDIDATE).**
The rewrite is not the cause: the original and rewritten forms were driven in one invocation against
a detached worktree and a `git archive` of the same commit and both returned 1, and the value holds
with `$BASE` at three distinct commits. It is the FULL fix arm described below, reached — both
signatures read **0**, because `:323-324` now exports `FANOUT_DIFF_FILE` and `FANOUT_FILES_FILE`,
two paths under a `mktemp`, and the python at `:359` and `:452` reads each payload from its file.
Neither payload is on the environment channel the receipt measures. Adjudicating that close belongs
to the upstream entry, not to this file.

**Two-sided probe.** Three variants in one `mktemp -d`, pairwise `cmp`-asserted to differ (all three
comparisons non-zero) before any output was read, and the fix shape leaves the `export` statement
**byte-identical** — it inserts one line above it that writes the payload to a temp file and rebinds
the variable to that path, which is what proves the receipt anchors on the channel's contents and
not on the export line's text or on a variable name. Shipping: corpus-signature **1**,
diff-signature **3**, rc=**0**. PARTIAL fix, corpus moved off the env and the diff left on it:
**0** and **3**, rc=**0** — it correctly refuses to close on a half fix, which is the arm the
upstream backlog receipt's first draft got wrong. FULL fix, both payloads off the env: **0** and
**0**, rc=**1** (CLOSE-CANDIDATE). The partial arm doubles as the proof that each signature comes
from the variable claimed: `^VERSION$` disappears only when `FANOUT_FILES` moves, `^@@ ` only when
`FANOUT_DIFF` does. Reach is asserted before the verdict, per arm — the env dump must be non-empty
and must carry `PATH=`, or **127** — and every extraction failure is 127, never a bare non-zero.

**Anchor shapes checked.** *Quote-back* — the receipt reads a child process's environment block, and
no comment in the script can appear there; the whole-line anchoring above is what keeps the
program's own quoted copies of this receipt out of the measurement. *Invented phrasing* — neither
signature came from the filing: `VERSION` is the repo-root marker every validator here walks up for
and is asserted tracked in the same invocation, and `^@@ ` is unified-diff syntax counted out of the
actual scope. *The fix's own closing clause* — a fix that documents "moved the diff off the
environment" satisfies nothing, since the predicate never reads the file.

**Hesitation.** The receipt needs the exec to happen, so it depends on the diff-plus-corpus payload
for `${BASE}~1..${BASE}` staying under `ARG_MAX`. Today that is roughly 35KB of a 1048576-byte
ceiling and the diff half is frozen, but the corpus half grows with the repo — `git ls-files` went
28811 → 29311 bytes across this batch alone; if it ever crosses, the shim is never reached and the
receipt reports **127** rather than STILL-LIVE — safe, and undiagnosable from the status alone. The
receipt also pins `AI_DLC_PROJECT_ROOT="$DIST"`, which the tracked script does not need since it
resolves the same root from its own directory; the pin is there so the measurement cannot silently
move if the receipt is ever run against a copy, and it does mean a regression in that resolver is
invisible here.

**AND THAT ONE `$DIST` STAYS, WHILE THE SUBJECT READ BESIDE IT MOVED TO `$THEIRS_TREE`.** The two
uses are not the same kind of read. `S="$THEIRS_TREE/core/scripts"` resolves the SCRIPT UNDER TEST,
which must come from theirs; `AI_DLC_PROJECT_ROOT` here is a REPOSITORY HANDLE, because
`report-propagation-fanout.sh:216` runs `git rev-parse --git-dir` against that root and exits 2 when
it is not a repository — and `$THEIRS_TREE` is a `git archive` extraction with no `.git`. Measured:
the receipt with both halves moved exits **127**, which the engine scores NEEDS-REVIEW rather than
STILL-LIVE, so the whole measurement is lost. Two workarounds were built and refuted. Borrowing
`$DIST`'s `GIT_DIR` runs (rc=1) and still discriminates, but the corpus is `git ls-files`, so it
answers from the CHECKOUT's index — measured on a deliberately divergent pair, the borrowed index
lists a path absent from the tree the script reads, which is this defect one call frame down.
Building a synthetic repository inside the receipt also discriminates, but it replaces the engine's
exported `${BASE}~1..${BASE}` scope, whose immutability is the point stated above. So this line is a
KNOWN false positive of the subtractive grammar at `ledger-reverify.sh:809`, which strips only the
`git -C` form: carried into a ledger it reads NEEDS-REVIEW, which costs one read and never an entry.

## Where this differs from batch-13

Three differences, each measured against `batch-13.md` as committed. They are the whole of the case
for preferring this file; everything else is a wording difference.

1. **Pin 4392's corpus needle.** `batch-13.md` uses unanchored
   `core/scripts/report-propagation-fanout.sh`, which matches inside `FANOUT_DIFF` too. Against the
   partial-fix mutant it read **4**, not 0 — and `git diff -U0 HEAD~1 --name-only` located those
   hits in `graph-ledger-adjudication-brief.md`, `replacement-receipts.tsv` and `batch-13.md`
   itself, i.e. in the program's own quoted copies of the receipt (impossible-needle control: 0).
   The anchored `^VERSION$` here reads 1 → 0 across the same mutant.
2. **Pin 4392's scope.** `batch-13.md` uses `HEAD~1` with no non-emptiness guard, and with the
   corpus needle neutralised the whole "stays open" arm rests on the diff hunk count. Measured with
   that predicate under an empty-diff scope: the partial fix gives 0/0 and rc=**1**, a false close.
   `HEAD~1` also moved 116508 → 15633 bytes during the batch. `${BASE}~1 $BASE` is 5415 bytes and 3
   hunks, unchanged across the same interval, and an empty diff exits 127 here.
3. **`receipt_absent_subjects` exposure, both pins.** `batch-13.md`'s receipts yield
   `scripts/validate-spec-join.sh` and `scripts/report-propagation-fanout.sh` to that guard, both
   measured ABSENT under `$CONSUMER` against the control `scripts/ai-dlc` measured PRESENT in the
   same invocation, so a real fix would report NEEDS-REVIEW instead of CLOSE-CANDIDATE. Both
   receipts here extract 0 paths.
