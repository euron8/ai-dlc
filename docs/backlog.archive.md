# Carry-over backlog — archive

Entries closed and rotated out of `docs/backlog.md` by `scripts/backlog-rotate.sh`.
Nothing here is deleted; this file is the destination, not a wastebasket.

## BL-009

**LANDED (v0.373.0, verified 953e39e).** Both halves the receipt requires are present:
`**Evidence required:**` on the severity rule, and a query-shape step in the procedure
directing the reviewer at "the fields the change SENDS, not only the ones it reads". Fixed at
`941021d`, guarded at `953e39e`, both inside v0.373.0. **The procedure half is UNGUARDED and
that was a measurement, not an oversight** — an arm keyed on the token `quer` plus a closed
list of send verbs fired on 3 of 5 legitimate rewordings that fully preserved the instruction,
leaving a false-positive set that is an open class of legitimate English. The guard's own
header says so at `core/fixtures/gate-verdict-grep-shape/run.sh`, so its green line is not to
be read as covering that half.

**A producer-side severity rule whose triggering condition no procedure tells the reviewer to
look for.** `core/team-roles/code-reviewer.md:223-228` classifies *Missing Pre-Deploy Field
Verification* as Important: "Any change that adds a new field to an API query without logged
verification against the deployed schema". That condition is PRODUCER-side — a change to the query
being sent.

The file's only field-verification procedure is at `:116-129`, headed
`## Field Verification (API-Consuming Stories)`, and its step 1 directs the reviewer at "response
field access patterns" — READ patterns only. Nothing in `core/` points a reviewer at query shape:
`grep -rniE 'query-shape|query shape|changes that add fields' core/` returns rc=1 across the whole
tree, against a control of `response field access patterns` hitting `:121`. **The rule cannot fire,
because the observation that would trigger it is one nobody is instructed to make.**

Gate Check 10 does not cover it. `core/skills/ai-dlc/steps/gate-validation.md:589` opens "Skip if no
stories modify API queries or schema definitions" — it PRESUMES someone already knows a query
changed, which is exactly what the missing procedure step would produce, and it is a different
actor, artifact and time.

Within the contiguous severity run at `:187-228` it is also the only rule carrying no
`**Evidence required:**` clause. **The TSV evidence overstated that scope and it is narrowed here:**
`## Mandatory Severity Classifications` starts at `:171` with 19 `###` subsections and the file has
4 `Evidence required` sites total, so 15 lack one. The claim holds over `:187-228`, not the section.

Anchored on both halves a fix cannot omit — the file's own `Evidence required:` convention inside
the rule, and the query side inside the procedure. A partial fix does not close it.

Discharges the consumer bullet at pinned ledger line 273
(`extensions/roles/code-reviewer-push.md`, which carries no `PC-` id). That row is `CLOSE-NARROWED`
and its close is GATED on this entry.

verify: sh f=core/team-roles/code-reviewer.md; a=$(LC_ALL=C awk '/^### Missing Pre-Deploy Field Verification/{g=1;next} g&&/^### /{exit} g' "$f"); b=$(LC_ALL=C awk '/^## Field Verification/{g=1;next} g&&/^## /{exit} g' "$f"); [ -n "$a" ] && [ -n "$b" ] && grep -qF "Evidence required" <<<"$a" && grep -qiE "quer" <<<"$b"

## BL-011

**LANDED (v0.373.0, verified cb94a43).** The three seeded legends are byte-identical at 2102
bytes each, `PAUSE_SKIPPED` is documented, `BACKOFF` carries one stated cause, and the
retro-guidance block is in all three. Fixed at `941021d`, guarded at `cb94a43`, both inside
v0.373.0. The guard is Assertion 8 in `core/fixtures/pause-hook-origin/run.sh` with a mutation
battery at Assertion 9 — it refuses to compare until each hook has exactly ONE legend opener
and each extraction is non-empty, so three empty strings cannot compare equal and close the
entry on a dead instrument. That is the arm the entry's own anti-vacuity clause asked for, and
it replaces the per-hook assertion that stayed green through the whole life of the divergence.

**Three hooks seed the flow log's legend, first writer wins, and the three disagree.**
`_bmad-output/pipeline-continuation-log.md` is opened by whichever of three hooks fires first, each
seeding a legend into an absent-or-empty file and returning otherwise:
`core/hooks/ai-dlc-continue.sh:103`, `core/hooks/ai-dlc-acknowledge.sh:489`, and
`core/hooks/ai-dlc-pause.sh:248-251`. Three heredoc bodies, measured at HEAD: 1435 / 1148 / 1835
bytes. Three ways the same sprint's log can be documented, selected by hook firing order.

- **`BACKOFF` has two definitions.** `pause.sh:270` says "stop_hook_active was true; loop prevention
  engaged"; `continue.sh:118` and `acknowledge.sh:506` say "rapid-fire stop attempts detected; stall
  confirmed". Two different causes for one event name.
- **`PAUSE_SKIPPED` is documented in one legend of three** (`pause.sh:261`), so a log seeded by
  either sibling and then written by `pause.sh:299` carries events its own legend never names.
- **`acknowledge.sh` omits the retro-guidance block entirely**, going `:506` to `:509` while
  `continue.sh:122-128` and `pause.sh:274-281` carry the interpretation bullets.

`retro.md` §4b reads this log for per-event counts, so the legend is the reader's only statement of
what a count means.

`core/fixtures/pause-hook-origin/run.sh:100-106` already asserts the legend documents
`PAUSE_SKIPPED` — but it reads `pause.sh` ONLY. It is a per-hook assertion against a cross-hook
defect, so it stays green while the divergence stands, and it is why exactly one of the three
legends carries that entry.

Anchored on byte-identity of the three heredoc bodies, which no prose can satisfy. The non-emptiness
guard is the anti-vacuity arm: if extraction ever breaks, three empty strings compare equal and the
entry would close on a broken instrument.

Discharges the surviving sub-claim of `PC-S295-FLOWLOG-HEADER-LEGEND-IS-GREPPABLE-AS-DATA` (pinned
line 387), whose own close annotation names this defect as "a separate defect, worth filing" and
which was NEVER filed — 0 hits in `docs/backlog.md` and `docs/backlog.archive.md` against a control
of `verify:` hitting `docs/backlog.md:13`. A clean close of that entry deletes the sole written
record of a live defect, so the close is GATED on this entry.

verify: sh L(){ LC_ALL=C awk '/cat > "\$LOG_FILE" <<.EOF.$/{f=1;next} f&&/^EOF$/{exit} f' "$1"; }; a=$(L core/hooks/ai-dlc-continue.sh); b=$(L core/hooks/ai-dlc-pause.sh); c=$(L core/hooks/ai-dlc-acknowledge.sh); [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" = "$b" ] && [ "$b" = "$c" ]

## BL-012

**LANDED (v0.374.0, verified 21df49b).** The `**Style:**` block now carries the permitted form
— `Rule <n>`, `Rule <n>(<letter>)`, `Step <n>`, and `I23` for a mechanism — fixed at `941021d`
inside v0.373.0. **The close is at v0.374.0 and not v0.373.0, because the fix shipped with its
guard OWED**: `941021d`'s own body closes with "None of the three entries may be annotated
LANDED until that work is done", and BL-012's guard was the one of the three that never
arrived. It is `IDENTIFIER_GRANT`, Class 1c of `core/scripts/audit-rule-files.sh`, probed both
directions by assertions 12m–12p of `core/fixtures/retro-audit-scans/run.sh`.

The guard is anchored on the grant's TEMPLATE for the reason this entry already measured: the
grant's closing clause is itself a prohibition, so a Style block holding that clause alone is
prohibitions-only, IS the defect, and still contains the word `identifier`. That input is
assertion 12m, and it is the one an `identifier` anchor scores CLEAN.

`PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS` (pinned line 610) is the consumer entry this
discharges, and its gate is unchanged by this close: **close 610 ONLY as part of an APPLIED
merge with pinned line 177**, which is `verify: manual` and whose body says no mechanical
anchor was derivable. This receipt remains the only mechanical anchor either entry has.

**The rule-authoring style guide forbids every way a rule could carry a citable identifier, and
permits none.** `core/skills/ai-dlc/rule-authoring.md` is the style guide that `SKILL.md` Rule 18
(`:615`) and `retro.md` Step 4's rule-file audit both bind to. Its `**Style:**` block prohibits "No
sprint or story references" at `:15` and "No parenthetical origin notes after a directive" at `:17`,
and grants no permitted form for a stable identifier a later rule can cite:
`grep -niE 'carve-out|carve out|exception|except when|stable identifier|identifier'` over the file
returns rc=1, against a control of `No sprint or story references` hitting `:15`. `SKILL.md`'s only
`carve-out` hit is `:347`, an unrelated live-security-state grant.

So `retro.md` Step 4 has a prohibition it can enforce against any tag a rule carries, and no form it
can point the author at instead. Rules in this skill are already cited by identifier throughout —
"Rule 18", "Rule 27", "Rule 25(c)", the `I79` markers at `SKILL.md:612` and `:631` — a shape the
guide governing them never authorizes.

**This is a missing-permitted-form defect, NOT a live contradiction, and the TSV evidence implied
otherwise.** `grep -rnE '\bS[0-9]{3}\b|\bLR-S[0-9]+|Sprint [0-9]{3}'` over `rule-authoring.md` and
`SKILL.md` returns rc=1, against a control of the same regex over `core/skills/ai-dlc/steps/`
returning 4 hits. Neither rule file currently violates its own prohibition.

Anchored on the `**Style:**` block, not the whole file. A looser anchor false-closes today:
`grep -nwE 'id'` already matches `:26` ("shadows it by id"), and a mention outside the Style block is
not a permitted form an author can follow.

**Anchored on the grant's TEMPLATE, not on the word "identifier", and that narrowing is the
receipt.** The grant is one multi-line bullet whose closing clause is itself a prohibition — "An
identifier is a name and MUST NOT encode a sprint, story, version, or date" — so a Style block
holding that clause ALONE is prohibitions-only, is exactly the defect this entry states, and
contains the word "identifier". Measured on a `cmp -s`-guarded copy: with the grant clause deleted
and that trailing prohibition retained, an `identifier` anchor returns **rc=0 CLOSE-CANDIDATE** on
the defect itself; only total deletion of the bullet returns rc=1. A permitted form cannot be
written without EXHIBITING the form, so the anchor is the backticked placeholder template
(`` `Rule <n>` ``, `` `Step <n>` ``), which no prohibition in the block carries. False-positive set
measured EMPTY over five legitimate rewordings of the same block — bullets reordered, grant prose
rewritten, grant widened with a further kind, placeholder letter changed, bullet unwrapped to one
line — all rc=0, against the two offenders above at rc=1 in the same invocation.

Discharges the mechanical anchor of `PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS` (pinned line 610).
**This gate is load-bearing in a way the others are not.** That entry's `merge:` field routes it into
the pinned line 177 entry, which is `verify: manual` and whose body says "No mechanical anchor was
derivable" — so this receipt is the only mechanical anchor either entry has, and line 177 carries a
RECIPROCAL duplicate declaration naming 610 as the survivor. An adjudicator reading either alone has
textual grounds to close it into the other, which would delete the anchor permanently. **Close 610
ONLY as part of an APPLIED merge.**

verify: sh s=$(LC_ALL=C awk '/^\*\*Style:\*\*/{g=1;next} g&&/^\*\*/{exit} g' core/skills/ai-dlc/rule-authoring.md); [ -n "$s" ] && grep -qE '`[A-Z][a-z]+ <[a-z]+>`' <<<"$s"

## BL-008 — `suite-dispatch-order` asserts an ordering built from wall-clock, and flakes under the pool

**LANDED (v0.375.0, verified 8140993).** The costs are seeded rather than measured, so
`$SECONDS` is no longer in any assertion's path. **The scope was WIDER than this entry states**
and both arms are fixed: the entry names only the arm at `:218`, but arm 1 at `:122` had the
identical exposure — its record was also written by a full-width `drive` and read back at
width 1. Fixing only the named arm would have left one poisoned assertion of five.

**This entry's prescribed fix, applied literally, would have deleted a real property**, and
that is recorded here because the next reader of a prescribed fix should expect it. `run.sh`'s
own header argued that hand-seeding arm 1 makes the arm worthless, because the two-run shape is
what binds the writer's record format to the reader's parser end to end. The argument is
correct, so that binding is now asserted DIRECTLY as arm 1b — the hook's `NF == 2` predicate
joined to the basename it derives — off a real run, with a one-field near-miss rejected in the
same invocation. 11 assertions became 12.

Arm 4's consequence reads aaa's POSITION alone. aaa's cost is seeded at 1 and never measured,
because aaa is withheld from the only run that dispatches anything; mmm and zzz sleep 2 and
`$SECONDS` is integer elapsed, so neither can record less. `aaa < mmm, zzz` holds by
CONSTRUCTION rather than by luck, and under a replace aaa's unknown cost maps to 999999 and
would sort FIRST — so the two states cannot collide on position.

Each reshaped arm is proven reachable by a DIFFERENT probe against the hook the fixture
resolves, with an unmutated control run first and green: sort-ascending reddens arm 1a and
arm 4's consequence; a changed writer separator reddens arm 1b alone; the merge removed
reddens both of arm 4's.

**REPRODUCED at 1/20 loaded against 0/30 unloaded, and the FIRST ATTEMPT FAILED in a way that
is the more useful half of this record.** A 6-vs-6 differential under 36 spinners on 18 cpus
produced zero failures on BOTH sides, which discriminates nothing; it was reported as no
evidence rather than as a pass. **Spinners are the wrong load.** What moves a worker's
`$SECONDS` is `bash -c` STARTUP LATENCY, contended on PROCESS CREATION, not CPU — 64 pure
spinners reproduce the same 0-of-8. A fork storm of 96 concurrent `while :; do /usr/bin/true;
done` reproduces it, and driving only the record-writing run rather than the full width-1 replay
is ~20× cheaper per repetition, which is what makes a 1-in-20 event observable at all.

**THE TRIGGER IS EQUALITY, NOT INVERSION, WHICH IS TIGHTER THAN THIS ENTRY'S OWN PROSE.** The
entry says a `sleep 0` unit outranks the `sleep 1` unit; that never occurred in 30 repetitions
and it does not need to. `sort -k1,1nr`'s `-r` is KEY-SCOPED, so tied keys fall through to a
FORWARD whole-line last-resort compare. Re-derived against `sort` 2.3-Apple (199), both
directions in one invocation: `aaa 1 / mmm 1 / zzz 3` gives `zzz aaa mmm`, which is exactly the
order this entry reports, while the untied control `aaa 0 / mmm 1 / zzz 3` gives `zzz mmm aaa`.
The window is "the cheapest unit gains about a second of startup while the middle one stays
under two", not "milliseconds of noise".

**Both reshaped arms are immune to that trigger BY CONSTRUCTION, not by margin.** Arm 1's seeded
costs are 1 / 5 / 9 and cannot tie. Arm 4 pits a seeded 1 against measured costs that
integer-elapsed `$SECONDS` cannot report below 2, so those cannot tie either — and a tie is the
entire failure mode.

**One reason given for leaving M1–M4 untouched was incomplete, and the code is already better
than the reasoning.** "They assert glob order, which holds for any record" is true of the
VERDICT and false of the KILL: a mutant fed a record the unmutated hook would also serve in glob
order scores a kill it did not earn. Before this change M1 and M2 copied a MEASURED record and
carried the same tie exposure one level down. They now copy the seeded record, which closes it.

Its arm "after the narrowed run the next full run is still longest-first (zzz mmm aaa)" sorts
three toy fixtures by the durations the previous run RECORDED. Under the 12-way pool those three
units take single-digit milliseconds and their measured order is noise, so the arm reads
`zzz aaa mmm` instead and reports a cost "lost to a narrowed run".

Measured on one branch, same tree, same commit, three observations: **`ok` under the pool,
`FAIL` under the pool on the immediately following run, and green when run alone.** It is
load-dependent, not a regression — it was already green under the pool on a run that carried
every change on that branch.

This matters beyond the flake: a fixture that fails intermittently in the gate is the shape that
gets re-run until green, and a re-run-until-green unit certifies nothing. The fix is to stop
sorting on real elapsed time in the assertion — seed the durations record with fixed costs and
assert the dispatch order those produce, so the arm measures the ORDERING RULE rather than the
machine's scheduler.

`verify: manual` because the defect is a race: a receipt that ran the fixture once would report
whichever side of it that run landed on, which is the same coin-flip the arm already is.

verify: manual

## BL-070

**LANDED (v0.375.0, verified 0b77fcb).** `core/fixtures/architecture-index-cell-escaping/` is
the guard, 8 assertions, SHIPPING — the subject is present on a consumer, so no `.dist-only`
marker, and registered in `uninstall.sh` plus both `core_manifest` copies, which **I74** joins
in both directions.

It carries the mutant arm this entry required, and arm 8 turns this entry's own trap into an
ASSERTION: the non-adjacent backslash-and-pipe seed is required to score identically under the
fixed and the reverted escaping, so a later author cannot weaken arm 4's seed into one that
passes either way without arm 8 going red. The mutant is not a source-level revert and is not
described as one — `e9c5970` also EXTRACTED the cell helper, so the pre-fix source has no
`cell` at all; what is reverted is the escaping LAYER, and the equivalence was measured, with
the mutant's index byte-identical to the real `e9c5970^` script's on this seed against a
control confirming pre-fix and current DIFFER.

**This entry's own receipt scored the correct guard as ABSENT**, and the re-anchoring is
recorded above where the old anchor is described.

**`gen-architecture-index.js` ships to every consumer and NOTHING in the tree exercises it, so the
CodeQL escaping defect just fixed at `e9c5970` can return with every check green.** The script builds
a markdown table and escapes free text into its cells at `core/scripts/gen-architecture-index.js:129`.
That escaping had a sanitization-order fault — `js/incomplete-sanitization`, flagged high by CodeQL on
a consumer that had pulled the file into `scripts/ai-dlc/` — and it is fixed. The fix has no guard.

Measured over the corpus that could hold one: `grep -rlE '(bash|node)[^|]*gen-architecture-index'`
over `core/fixtures/` returns **nothing**, against a positive control of the identically-shaped
pattern for `validate-mandatory-rules` returning **3** files in the same invocation. Widening to a
plain name search over `.githooks/`, `core/git-hooks/`, `core/fixtures/`, `scripts/` and
`core/scripts/` returns exactly **1** tracked hit and it is the script itself, against a control of
**13** for a token known present in that corpus.

**The `.ai-dlc-fixture-readsets.tsv` rows naming this path are NOT coverage and are the trap here.**
Five fixtures record it in their read-sets — `consumer-machinery-home`, `crosswalk-home-declaration`,
`enforcement-map-derivations`, `enforcement-map-derivations-b`, `enforcement-map-sites` — because
each scans `core/scripts/` as a CORPUS. Reading a file while enumerating a directory is not
exercising the program in it. A coverage question answered off that TSV returns "five fixtures touch
it" and is wrong, which is the same reads-vs-mentions class this repo has now measured in six other
places.

**It reaches consumers by GLOB, which is why a by-name search of the installer says otherwise.**
`scripts/install.sh:523` derives its copy loop as `core/scripts/*` and never enumerates, so
`grep -n 'gen-architecture-index' scripts/install.sh` returns 0 for this file and would for every
other one — the false-zero shape `CLAUDE.md` already lists. The two invokers spell the INSTALLED
path: `core/skills/ai-dlc/steps/architecture.md:302` and
`core/skills/ai-dlc/steps/artifact-consolidation.md:119`.

**The defect this guards against is narrow and the obvious test input does not reach it.** Only a
backslash IMMEDIATELY BEFORE a pipe corrupts a row: `both\|here` escaped pipes-only yields `both\\|here`,
an escaped backslash followed by a BARE pipe, which ends the cell early. A title carrying a backslash
and a pipe that are not adjacent produces an intact row under both the broken and the fixed script,
so a fixture seeded with the obvious input would pass either way. Measured through the shipping
script at `HEAD` and `HEAD~1`, asserted to differ by `cmp -s` before the outputs were compared: the
pre-fix row carries **7** unescaped pipes where a four-column row has **5**, and the fixed row
carries 5, matching a clean control in the same run. Counting unescaped pipes requires tracking
escape state — a `grep -o '[^\]|'` scores both rows at 4 and discriminates nothing, because the
character before the bare pipe IS a backslash, the one that is itself escaped.

Scope of the fix was checked and is complete for the table-cell class: `r.line` is numeric, `indent`
is a constant, and `r.anchor` passes the slugger's `[^\w\- ]+` strip at `:58`, which removes both
characters — the anchor was byte-identical under the broken and fixed scripts in the same run.

**Anchored on the fixture PASSING, not on a reference existing**, so a stub that names the script
cannot close this. The receipt locates a fixture that names the script and then RUNS it, requiring
exit 0.

**THE ORIGINAL ANCHOR WAS `(bash|node)[^|]*gen-architecture-index` OVER THE FIXTURE TEXT, AND A
CORRECTLY-BUILT GUARD CANNOT CARRY IT.** Measured against the guard written for this entry: rc=1,
with the guard present, passing, and killing its own mutant. A fixture must name BOTH install
layouts and resolve one into a variable — **I33**, and the same `core/scripts/` vs `scripts/ai-dlc/`
split that put this script out of reach of a by-name installer search — so it invokes
`node "$GEN"`, and no line anywhere in it places an interpreter and the script's name together.
The anchor was a hypothesis about what a guard would LOOK like, written before one existed, and it
scored the correct guard as absent. Text about a program is not the program.

**Re-anchored on BEHAVIOUR, in both directions, which is what the entry always meant.** The receipt
runs the guard against the shipping script and requires PASS, then rebuilds the guard's own two-layout
neighbourhood in a `mktemp` root around `e9c5970^`'s pre-fix script and requires the same guard to
FAIL there. `cmp -s` refuses if the two scripts are not different, so a reverted tree reports STILL-LIVE
rather than closing. Proven in three states in one invocation: no guard rc=1; **a stub that names the
script and exits 0 rc=1**, because it passes both runs and the second must fail; the real guard rc=0.

**Known limit, stated rather than papered over**: the receipt establishes that a guard exists and
passes, not that it carries a mutant proving it can fire. `.claude/rules/fixture-mutants.md` binds
that half and it is enforced at review. A guard for this belongs with a mutant arm reverting the
escaping, because an assertion over an intact row is exactly the arm that passes against a subject
that never ran.

verify: sh S=core/scripts/gen-architecture-index.js; [ -f "$S" ] || exit 9; command -v node >/dev/null 2>&1 || exit 9; d="$(grep -rl gen-architecture-index core/fixtures/ 2>/dev/null | head -1)"; [ -n "$d" ] || exit 1; fx="$(dirname "$d")"; [ -f "$fx/run.sh" ] || exit 1; bash "$fx/run.sh" >/dev/null 2>&1 || exit 1; W="$(mktemp -d)" || exit 9; mkdir -p "$W/scripts" "$W/fixtures/g" || { rm -rf "$W"; exit 9; }; git show e9c5970^:core/scripts/gen-architecture-index.js > "$W/scripts/gen-architecture-index.js" 2>/dev/null || { rm -rf "$W"; exit 9; }; cmp -s "$S" "$W/scripts/gen-architecture-index.js" && { rm -rf "$W"; exit 9; }; cp "$fx/run.sh" "$W/fixtures/g/run.sh" || { rm -rf "$W"; exit 9; }; bash "$W/fixtures/g/run.sh" >/dev/null 2>&1; r=$?; rm -rf "$W"; [ "$r" -ne 0 ]
## BL-013

**LANDED (v0.376.0, verified 9b18af4).** `ledger-reverify.sh`'s ENTRY-SWALLOWED arm gains a
second gate: the CONJUNCTION of the two predicates its own header records as measured and
REJECTED, neither shippable alone -- a non-id bullet CAPTURED a receipt, the id-keyed entry
above it emitted no row of its own, and that entry is not CLOSED. The third clause exists
because `core/fixtures/ledger-rotate`'s acceptance test caught a false positive without it: a
CLOSED entry emits no row because it is skipped, not because it was swallowed.

**The shipping colon gate was INERT, which is stronger than "too narrow".** It fires zero
times across the consumer's live ledger, that consumer's archive, and both distribution
backlog files, while those corpora contain annotations really swallowing entries. False
positives for the new gate, enumerated rather than asserted: 1 live, 0 archive, 3 in
`docs/backlog.md`, all four genuine annotation sub-bullets; the capture predicate ALONE fires
11 times on that same ledger.

**The naive repair was not taken and the boundary rule is untouched** -- `ledger_entry_shape()`
is byte-identical, because six call sites across four programs read it plus a third hand-copy
in `reconcile/warn-shadowed-local-validators.sh:84-85`. `ledger_entry_id()` is single-homed in
`lib.sh`, replacing a local `idshape()` whose `^[A-Z0-9-]+$` excluded `_` and `.` and scored two
real consumer entries as annotations.


**A bold bullet whose bold span does NOT end in a colon splits a ledger entry, and nothing reports
it.** `ledger_entry_shape()` at `core/skills/ai-dlc-update/reconcile/lib.sh:276` opens a new entry on
any line-leading `- **`. That is correct and load-bearing for every ledger whose entries are bullets.
The `ENTRY-SWALLOWED` diagnostic that makes the resulting split legible is gated on the bold span
ending in a colon — `label ~ /:$/` at
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1086`. So an annotation written
`- **Some lead-in** text` truncates the entry above it, CAPTURES that entry's receipt, and produces
no row under the swallowed entry's id and no `ENTRY-SWALLOWED` row either.

Measured through the shipping `ledger-reverify.sh` on a three-entry synthetic ledger:
`PC-PROBE-SPLIT-NO-COLON` is named **0** times in the output, and its receipt is attributed to the
label `False CLOSE-CANDIDATE`. Controls in the same run, both non-zero: the clean entry emits **1**
row under its own id, and the byte-identical annotation WITH a colon emits `ENTRY-SWALLOWED` naming
the truncated entry.

The colon gate was a deliberate choice, not an oversight — the arm's own header records that
re-keying the entry-shape rule was considered and rejected because narrowing the bullet arm drops
real entries. **The naive repair is measured worse than the defect**: a plain `infence = !infence`
toggle over the reference consumer's 4356-line ledger takes the entry-start count from 142 to 95,
silently dropping 47 real entries, because that corpus carries 111 fence delimiters — an ODD number,
one entry holding an unterminated fence — and the toggle desynchronises there permanently.
`scripts/backlog-rotate.sh` took the other road for the same shared boundary rule: it refuses to
rotate rather than re-keying the parse.

Discharges `PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT`, whose other two halves — the
`all_present()` SIGPIPE false-absent and the "first directive wins" receipt parse — are both already
fixed. A close of that consumer entry is GATED on this filing.

The receipt asserts BEHAVIOUR, not prose: exit 0 when the tool NAMES the truncated entry, which both
plausible fixes produce — re-attributing the receipt to its own id, or emitting a diagnostic whose
detail carries the swallowed id. Verified satisfiable: the same probe with a colon added returns 0,
and that colon is the only difference between exit 1 and exit 0 today. The finding is a property of
the commit, not of the worktree: it was re-run against `git show HEAD:` copies of both
`ledger-reverify.sh` and `lib.sh` while a sibling change sat in the tree, same verdict.

verify: sh W=$(mktemp -d); mkdir -p "$W/c"; L="$W/c/led.md"; printf '%s\n' '# probe' '' '- **PC-PROBE-CLEAN-CONTROL** — a clean entry, no annotation in its body' '' '  veri''fy: theirs_has VERSION "0"' '' '- **PC-PROBE-SPLIT-NO-COLON** — the entry a no-colon bold bullet splits' '' '- **False CLOSE-CANDIDATE** this bold span does not end in a colon' '' '  veri''fy: theirs_has VERSION "0"' > "$L"; O=$(bash core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "$PWD" HEAD~1 "$W/c" HEAD "$L" 2>&1); C=$(LC_ALL=C grep -c PC-PROBE-CLEAN-CONTROL <<<"$O" || true); S=$(LC_ALL=C grep -c PC-PROBE-SPLIT-NO-COLON <<<"$O" || true); rm -rf "$W"; echo "control_rows=$C swallowed_id_named=$S"; [ "$C" -ge 1 ] || { echo "HARNESS BROKEN: the control entry emitted no row"; exit 2; }; [ "$S" -ge 1 ]

## BL-032

**LANDED (v0.376.0, verified 9b18af4).** `ledger-rotate.sh` REFUSES rather than splitting. Three
candidate discriminators died on measurement first: a `PC-` id requirement blinds the rotator to
every legacy id-less entry, a tail-shape signal has an enumerated false-positive set of 12 on the
live ledger, and `docs/analysis/ledger-entry-boundary-measurement.md`'s own `---`-terminator route
is REFUTED on this corpus -- 96 boundary-shaped lines against 50 separators live, 142 against 70
archived.

**The guard is keyed on the HARM, not the shape, and four false positives were found by other
hands before it shipped.** A shape-keyed form wedged `core/fixtures/ledger-rotate/seed.sh`, whose
real prose-titled entry with a VERSIONLESS close follows a closed one -- the class the analysis
file predicts and the consumer corpus does not contain. A second reviewer then found three more:
a legacy entry whose close sits in its OWN bold span was invisible to a close test reading only
the lines below; a closed entry carrying its receipt ABOVE the boundary can strand nothing; and
the refusal named only the annotation remedy, which would destroy a real entry. It now fires only
when the closed entry's receipt would actually be stranded, and reports ZERO over all four corpora
while firing on the reproduction and staying silent on the indented near-miss.

**Refusing a genuinely ambiguous case is deliberate and asymmetric**: a wrong refusal costs a
two-line operator edit, a wrong rotation costs the entry.


**`reconcile/ledger-rotate.sh` physically splits a closed ledger entry at a line-leading bold
annotation: the head goes to the archive and the tail, including the entry's `verify:` receipt,
stays in the live ledger under no heading.** Driven behaviourally against the shipping script with a
near-miss control in the same invocation. Two synthetic ledgers, byte-identical except for the
indentation of one bullet, each rotated with `--apply` into its own archive:

```
bullet at column 0 (a boundary)   archive: HEAD 1  TAIL 0  receipt 0
                                  live:    HEAD 0  TAIL 1  receipt 1   heading for that entry: 0
bullet indented   (not a boundary) archive: HEAD 1  TAIL 1  receipt 1
                                  live:    HEAD 0  TAIL 0  receipt 0
```

Both runs exited 0. The control proves the harness drives a working rotator and that the entry
rotates whole when no boundary-shaped line sits inside it; the arm shows the split. The two
post-rotation live files were asserted byte-different before the comparison was read.

`ledger_entry_shape()` at `core/skills/ai-dlc-update/reconcile/lib.sh:276-280` is the boundary rule
— `if (l ~ /^- \*\*/) return "bullet"` — and `ledger-rotate.sh:111` partitions on it.

**The filing prescribed two fixes and one of them has LANDED and is provably insufficient, which is
the correction.** Fix shape 2 was "share one boundary parser between the two tools". That is done:
`lib.sh` now owns the single copy and `ledger-rotate.sh:54-56` records the merge in as many words —
"This block used to carry its own [copy] ... There is one boundary now." The probe above runs on
that shared parser and still splits, because unifying the rule changed nothing about what the rule
SAYS. Fix shape 1, a refuse-to-rotate guard, did not land. The correction moves the entry NARROWER
in cause (the defect is the rule's content, never the duplication) and leaves its consequence
exactly as filed.

**The shipped rotator's one integrity check cannot see this class, and that is structural.**
`ledger-rotate.sh:186` refuses when `kept + moved != total` — a line-accounting conservation
predicate. A split conserves every line; the two halves simply land on opposite sides. The
distribution's own rotator has the check this one lacks: `scripts/backlog-rotate.sh:71-143` refuses
to rotate a ledger the boundary rule cannot parse safely, and its header at `:78` cites this very
consumer entry by id. That guard is keyed on the FENCE case (`:101-104`, "KEYED ON THE SPLIT
PREDICATE, NOT ON `ledger_entry_shape()` ALONE"), so it would not fire on the bold-annotation case
either — but it establishes that the distribution already accepted refusal as the answer for this
class in its own tool and did not carry it into the shipped one.

`docs/analysis/ledger-entry-boundary-measurement.md` is the upstream measurement and it is NOT a
decision to leave this alone: "The report is correct and the consequence is destructive... **the
guard belongs in the tool**." It rules out the two cheap discriminators with numbers (49 of 123
boundary-matching lines name no `PC-` id; some are real legacy entries) and lists four things a real
fix must establish first. It is an analysis file with no receipt and no reader, which is why this
belongs in a ledger that re-executes.

**Distinct from `BL-013`, deliberately.** `BL-013` is the `ledger-reverify.sh` DIAGNOSTIC being
gated on the bold span ending in a colon — the no-colon case, where nothing is reported. This probe
uses `- **Note:** …`, which DOES end in a colon, so the diagnostic fires and the rotator destroys
the entry anyway. Different tool, different half of the corpus, opposite failure.

The receipt asserts the entry is not SPLIT — that HEAD and TAIL end on the same side — rather than
that it rotates. That takes BOTH candidate fixes: a boundary rule that stops treating the annotation
as a title (both halves archived, 0 == 0) and a refuse-to-rotate guard (both halves retained,
1 == 1). Verified satisfiable in the same invocation: a copy of `lib.sh` patched so a bold span
ending in a colon is not a boundary — asserted byte-different from the shipping file first — takes
the receipt to exit 0, with the control still green. A receipt asserting "the tail reached the
archive" would have reported STILL-LIVE forever against a refusal-shaped fix.

Discharges the consumer entry `PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOTATION` at pinned
ledger line 2957. **That entry's own receipt is inverted and must not be trusted when draining it**:
it reads `theirs_lacks ... ledger-rotate.sh "ENTRY-SWALLOWED"`, the token is absent from that file
today and has been throughout, so the receipt reports CLOSE-CANDIDATE while the defect reproduces.
Its adjacent note gives a `theirs_has` rationale — "anchored on the status name a refuse-to-rotate
guard cannot be written without" — so the verb, not the anchor, is the error.


**THE RECEIPT BELOW CARRIES A THIRD LEDGER, AND WITHOUT IT THIS RECEIPT CLOSES ON THE ONE FIX
THAT MUST NEVER SHIP.** The `H -eq T` arm asks only that the entry is not split, and deleting
the bullet arm outright — `if (0) return "bullet"` in `ledger_entry_shape()` — satisfies it
perfectly, because a rule that sees no bullets splits nothing. That is the remedy
`docs/analysis/ledger-entry-boundary-measurement.md` rules out as *worse* than the defect: it
blinds the rotator to every bullet-keyed entry, 21 live and 38 archived on the reference
consumer, which is silent non-archival rather than a visible refusal. Measured over three
trees in one invocation, sides asserted byte-different first: pre-fix **1**, the shipped
refusal guard **0**, and the `if (0)` mutant **0** — a FALSE CLOSE available to the forbidden
fix. This is the inverse of the receipt defect this program usually finds; not a correct fix
scored as work remaining, but a destructive one scored as done. The `c.md` arm requires a
CLOSED BULLET entry to still reach the archive, which no bullet-blind rule can satisfy: the
same three trees now measure **1 / 0 / 1**.

verify: sh D=$(mktemp -d); R=core/skills/ai-dlc-update/reconcile/ledger-rotate.sh; mkl() { printf '# L\n\npre\n\n## PC-PROBE-SPLIT — t\n\nHEADMARK\n\n**ADOPTED UPSTREAM (v0.1.0, verified deadbee).**\n\n%s\n\nTAILMARK\n\nverify: theirs_has core/probe.md "TOK"\n\n---\n\n## PC-PROBE-OPEN — t\n\nbody\n' "$2" > "$1"; }; mkl "$D/a.md" '- **Note:** an annotation lead-in, not an entry title.'; mkl "$D/b.md" '  **Note:** an annotation lead-in, not an entry title.'; printf '# L\n\npre\n\n- **PC-PROBE-BULLET-ENTRY** — a CLOSED entry keyed as a top-level bullet\n\nBULLETMARK\n\n**ADOPTED UPSTREAM (v0.2.0, verified deadbee).**\n\n- **PC-PROBE-BULLET-OPEN** — an open bullet entry\n\nbody\n' > "$D/c.md"; bash "$R" "$D/a.md" --archive "$D/a.arc.md" --apply >/dev/null 2>&1; bash "$R" "$D/b.md" --archive "$D/b.arc.md" --apply >/dev/null 2>&1; bash "$R" "$D/c.md" --archive "$D/c.arc.md" --apply >/dev/null 2>&1; CTRL=$(grep -c TAILMARK "$D/b.arc.md" 2>/dev/null); ARC=$(grep -c BULLETMARK "$D/c.arc.md" 2>/dev/null); H=$(grep -c HEADMARK "$D/a.md"); T=$(grep -c TAILMARK "$D/a.md"); rm -rf "$D"; [ "${CTRL:-0}" -eq 1 ] || exit 1; [ "${ARC:-0}" -eq 1 ] || exit 1; [ "$H" -eq "$T" ]
## BL-036

**LANDED (v0.376.0, verified 9b18af4).** The `|| echo false` fallback is gone -- it made a `jq`
ERROR and a genuine `false` the same string, so every guard downstream of it was blind by
construction. `jq`'s own exit status is read and a verdict can only come from a literal
`true|false`.

**FOUR input classes reached the silent `no`, not the one the report named**: 0-byte (where `jq`
exits 0 and prints nothing, so the fallback never fires), readable non-JSON, a bare JSON scalar,
and a valid JSON object whose `.hooks` is not an object. **The last two are VALID JSON**, which is
why validating the template as JSON does not close this.

**The narrower fix was built FIRST and measured failing**, which is why the fallback had to go
rather than be guarded: a `case` refusing anything that is not a literal `true|false`, added with
the fallback still in place, closes ONLY the 0-byte case. A separation that makes a wrong answer
unlikely is not one that makes it unconstructible.

Guarded by `core/fixtures/settings-merge-unparseable-template/`, `.dist-only` because its positive
control needs `templates/settings.json.template`, which no `cp` in `install.sh` places under a
consumer root.


**`settings-merge.sh --check` answers `model_row_needed=no` and exits 0 on a template it could not
parse, and there are TWO such templates, not one.** `SENSOR_WIRED` at
`core/skills/ai-dlc-update/reconcile/settings-merge.sh:100-103` is `jq` over `$TEMPLATE` with a
`|| echo false` fallback; the guard at `:108` is `[ "$SENSOR_WIRED" = "true" ] && [ -z "$EXISTING_ROW" ]`,
so anything that is not the literal `true` collapses to `no` at `:115`. Measured against one
consumer `settings.json` carrying no `.env.AI_DLC_MODEL_ROW`, three templates, same script, same
invocation:

```
CORRECT template (wires ai-dlc-context-sensor.sh)  sensor_wired=true   model_row_needed=yes  exit 0
0-BYTE template                                    sensor_wired=       model_row_needed=no   exit 0
READABLE NON-JSON template                         sensor_wired=false  model_row_needed=no   exit 0
```

The first row is the control: same consumer, same script, the answer flips to `yes` the moment the
template is readable. Step 5 raises the provisioning question only on `yes`, so on a consumer that
genuinely needs the row the operator is never asked and `.env.AI_DLC_MODEL_ROW` is never written,
with the run still green.

**The filing is wrong in both directions.** Narrower: its headline says "0-byte **or unreadable**",
and the unreadable half is already guarded — `:81` is `[ -r "$TEMPLATE" ] || { echo "FAIL: cannot
read template: $TEMPLATE" >&2; exit 1; }`, measured exit **1**. Wider: the suppression has two
distinct paths and the filing describes only the empty one. The non-JSON path is the one that
actually takes the `|| echo false` fallback the filing's own prose blames, and the empty path does
not (an empty `jq` input exits 0 and prints nothing, so `SENSOR_WIRED` is the empty string). **The
filing's prescribed fix does not close the defect it describes**: transcribed and run against the
cases the filing itself reproduces, `[ -r "$TEMPLATE" ] && [ -s "$TEMPLATE" ]` rejects the 0-byte
template (`FAIL: cannot read template`) and leaves the non-JSON template returning
`sensor_wired=false model_row_needed=no` at exit 0 — unchanged.

Scope is `--check` only, and that is measured rather than assumed: the merge path with the same
non-JSON template refuses with `FAIL: merge produced no output; consumer left untouched`. So the
writer is guarded and the sensor is not, which is why the failure is silent.

The anchor drives the real script over all three templates in one invocation and asserts the
`model_row_needed=` line it prints, not a phrase describing a guard nobody has written. The correct
template is the positive control: a fix that closes the check by breaking it fails the receipt too.
A looser anchor — `has settings-merge.sh "-s \"$TEMPLATE\""` — would close on the filing's own
broken fix. Measured against a copy carrying a real fix (`jq -e . < "$TEMPLATE"` beside the `-r`
guard): exit **0**. Against the tree today: exit **1**.

Discharges the consumer entry `PC-S333-SETTINGS-MERGE-CHECK-READS-AN-EMPTY-TEMPLATE-AS-A-VERDICT`
at pinned ledger line 4052.


verify: sh M=core/skills/ai-dlc-update/reconcile/settings-merge.sh; D=$(mktemp -d); printf '{"env":{"ENABLE_PROMPT_CACHING_1H":"1"},"hooks":{}}\n' > "$D/c.json"; printf '{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-context-sensor.sh"}]}]}}\n' > "$D/good.json"; : > "$D/empty.json"; printf 'not json at all\n' > "$D/junk.json"; g=$(bash "$M" --consumer "$D/c.json" --template "$D/good.json" --check 2>/dev/null); e=$(bash "$M" --consumer "$D/c.json" --template "$D/empty.json" --check 2>/dev/null); j=$(bash "$M" --consumer "$D/c.json" --template "$D/junk.json" --check 2>/dev/null); rm -rf "$D"; grep -qF 'model_row_needed=yes' <<<"$g" || exit 1; ! grep -qF 'model_row_needed=no' <<<"$e" || exit 1; ! grep -qF 'model_row_needed=no' <<<"$j"
## BL-065

**LANDED (v0.376.0, verified 9b18af4).** `field_of()` now NORMALIZES the line -- stripping `**`,
`__` and backticks -- then matches `NAME[[:space:]]*:[[:space:]]*VALUE` position-independently.
Enumerating wrapper alternatives around the name is what failed.

**The filing named two failing grammars and SIX were measured**, by driving the pre-fix function
over a grammar table rather than reading its regex: bold-colon-inside (`**`), bold-colon-outside
(empty), a BACKTICKED VALUE (empty -- the value class excluded a backtick), a bold span wrapping
the whole pair, `__underscore bold__`, and a bold name with a backticked value. The empty results
route to an ACCUSATION, not a malformed-value report.

**The function is deliberately SELF-CONTAINED.** The receipt below lifts it by its own definition
boundaries and evals it alone, so a correct fix delegating to a helper leaves that helper
undefined and reports the defect STILL-LIVE against working code -- measured at exit 9 BEFORE the
fix was written.

**Residue, stated rather than implied**: single-character emphasis (`*name*`, `_name_`) still
returns empty, because a single `_` cannot be stripped -- the field name contains one. Neither
form is a regression and neither appears in the producer's output.

**This receipt also ACCEPTS `field_of() { echo confirmed; }`**, a fix that closes the check by
breaking it. The negative arms live in `core/fixtures/scope-confirmation/`, which previously
seeded zero bold-form lines.


**`field_of()` corrupts a bold-markdown field into the literal string `**`, and the sibling grammar
it never considered returns EMPTY and accuses the lead of skipped conduct.** The function at
`core/scripts/validate-scope-confirmation.sh:158-162` was lifted out and EXECUTED rather than
restated, because a restated regex is a second implementation whose bugs nobody finds. Over four
grammars in one invocation it returns `confirmed` for `- scope_confirmed: confirmed` and `confirmed`
for the backtick prose form — the two controls, and the only two its own comment block documents —
then **`**`** for `- **scope_confirmed:** confirmed` and **empty** for
`- **scope_confirmed**: confirmed`. The first routes to the FAIL at `:199`, "scope_confirmed is
'**', which is not one of confirmed|corrected". The second routes to the FAIL at `:186-190`, "a
Rule 3(d) pause point that did not happen" — a well-formed snapshot with a correct value read as
evidence the lead skipped a mandatory operator pause. Single site: `field_of` appears in exactly
**1** core script, against a control of **8** naming `grep -o`.

**The filing is right about the mechanism and misses the harsher half.** It reproduces only the
colon-inside form and its `**` corruption; the colon-outside form is a second established bold
grammar that fails into an accusation rather than a malformed-value report, and the filing never
mentions it. `scope_confirmed_cite` corrupts identically at `:206`.

**The prescribed fix does not fix the case the filing itself reproduces, and half of it is silently
inert here.** Transcribed literally and run: it still returns **`**`** on the colon-inside form,
because the closing `**` sits BETWEEN the colon and the value while the prescribed alternation places
the wrapper BEFORE the colon; on the colon-outside form it is strictly worse, capturing the whole
line `**scope_confirmed**: confirmed` as the "value". And `\|` is a GNU BRE extension that this
machine's `grep` honours but BSD `sed` does not — measured in one invocation, the alternation `sed`
left `scope_confirmed**: confirmed` untouched while the same `sed` with a plain `\(\*\*\)` capture
stripped it to `scope_confirmed: confirmed`. `field_of`'s second leg is a `sed`, so the prescribed
change would half-apply with no error at all. The remediation is to NORMALIZE the line — strip `**`
and backticks — before matching `NAME[[:space:]]*:[[:space:]]*VALUE`, which is position-independent
and needs no `\|`. Enumerating wrapper alternatives around the name is what fails.

**The guarding fixture is seeded from what its own reader already accepts.**
`core/fixtures/scope-confirmation/` SHIPS and seeds **0** bold-form lines in `seed.sh` and **0** in
`run.sh`, against a control of **5** and **9** `scope_confirmed` mentions in those same two files —
exactly the two grammars the parser handles and no third. A fix would ship green and unguarded. The
consumer has converted only the two lines the check consumes: **14** bold-field lines remain in its
`_bmad-output/pipeline-snapshot.md` against **10** plain, so every one of them is exposed to the
identical misparse by any future `field_of`-style reader.

**Why the receipt is the receipt, and why it is not `manual`.** The filing declared `verify: manual`
on the grounds that the failure depends on the caller's markdown styling rather than a stable string.
That is right about the consumer's engine and wrong here: the tree is executable, so the receipt
lifts `field_of` from the shipping script by its own definition boundaries and drives it, asserting a
BEHAVIOUR rather than any text a fix could quote back. The plain-bullet arm returning `confirmed` is
the control in the same invocation and exits 9 if it ever stops holding, which would mean the lift
broke rather than the defect closed. It reaches 0 when both bold forms yield `confirmed`,
demonstrated against a normalizing implementation that returns `confirmed` for all three inputs where
the shipping one returns `confirmed`, `**` and empty.

Discharges the consumer entry `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR` at
LIVE ledger line 4435, past the 4356-line pin.

verify: sh V=core/scripts/validate-scope-confirmation.sh; F=$(sed -n "/^field_of() {/,/^}/p" "$V"); [ -n "$F" ] || exit 9; eval "$F"; D=$(mktemp -d); printf -- "- scope_confirmed: confirmed\n" > "$D/p.md"; printf -- "- **scope_confirmed:** confirmed\n" > "$D/i.md"; printf -- "- **scope_confirmed**: confirmed\n" > "$D/o.md"; p=$(field_of scope_confirmed "$D/p.md"); i=$(field_of scope_confirmed "$D/i.md"); o=$(field_of scope_confirmed "$D/o.md"); rm -rf "$D"; [ "$p" = confirmed ] || exit 9; [ "$i" = confirmed ] && [ "$o" = confirmed ]

## BL-031

**LANDED (v0.377.0, verified 867597a).** The literal escape at the `ENTRY-SWALLOWED` emit site is now the single U+2026 character. Population re-derived independently and it is EXACTLY ONE: the other five `\uXXXX` occurrences under `core/` are correct by construction — three JSON `description` strings no reader ever prints undecoded, one Python `re.compile` pattern where the escape IS interpreted (measured: matches an em-dash, does not match a backslash or the letter `u`), and one fenced JSON example. Control in the same invocation: 110 emit sites across 16 files.

**ITS OWN RECEIPT HAD THREE HOLES AND ONE OF THEM SURVIVES A CORRECT FIX.** The anchor `^[[:space:]]*emit ` binds the escape's SYNTACTIC POSITION, not whether it reaches stdout. Probed, all exit 0: deleting the `emit ENTRY-SWALLOWED` call outright; a bare line-continuation before the status token; and — the serious one — HOISTING the message into a variable on a prior line, which leaves the escape in the file and still emitting while flipping the receipt to CLOSE-CANDIDATE. That is the mirror of the whole-file anchor this entry was written to avoid. The durable guard is a fixture arm bound to the EMITTED bytes with a positive control, not this receipt.

**`ledger-reverify.sh` emits its `ENTRY-SWALLOWED` detail with a literal backslash-u-2026 escape,
and that detail is rendered into the region `emit-report.sh --verify` byte-compares.** The escape is
at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1174`, inside the third argument of an
`emit` call. `emit()` at `:193` is `printf '%s\t%s\t%s\n' "$1" "$2" "$3$RSFX"` — a `%s` conversion,
which does not interpret escapes in its argument — so the six characters reach stdout verbatim. The
same string literal carries a REAL em-dash (`cat -v` on `:1174` shows `M-bM-^@M-^T`), so this is an
inconsistency inside one message rather than an ASCII-safety convention. The detail is not dropped
downstream: `emit-report.sh:251` prints field `$3` for every row whose status is neither
`STILL-LIVE` nor `HAND-REVIEW`, and `ENTRY-SWALLOWED` is neither.

Measured over `core/`, with a control in the same invocation: emit-site lines carrying a
`\uXXXX`-shaped escape = **1**, in that one file; total `emit ` call sites in that same file =
**21**. So the offender is 1 of 21 in its own file and 1 across the whole of `core/` — an outlier,
not a convention.

The filing is right about the mechanism and wrong about one coordinate: it cites line **767**, and
the emit site is at **1174** today. That is a REPOINT, not a close — the string, the escape and the
`printf '%s'` emitter are all unchanged. Nothing else in the filing moved.

**The consequence was reproduced first-hand while filing this, which is the strongest evidence
available for it.** Three separate attempts to type the six-character escape into a probe — through
a heredoc, through the `Write` tool, and inline — arrived as a single `…` character every time, and
the arm reported "no match" on all three. The probe only worked once the escape was assembled from
parts at runtime (`B='\'` then `"${B}u2026"`). That is precisely the filing's claim — "any faithful
reader, a model, a markdown renderer, a copy through anything that normalises JSON escapes, will
turn it into `…`" — reproduced on the reader most likely to be pasting the region.

The receipt keys on the EMIT SITE (`^[[:space:]]*emit `), not on the file. A whole-file grep is the
anchor failure this program keeps measuring: a fix that emits the character directly and records
what it removed in a comment leaves the substring in the file, and a file-scoped anchor would then
report STILL-LIVE forever. The receipt's own near-miss arm asserts a comment line carrying the same
escape does NOT satisfy it. Verified satisfiable in the same invocation: a `sed`-substituted copy of
the file — asserted byte-different from the original before comparing — takes the count from 1 to 0
and the receipt to exit 0, with all 112 real em-dashes intact.

Discharges the consumer entry
`PC-S311-ENTRY-SWALLOWED-DETAIL-EMITS-A-LITERAL-BACKSLASH-U-ESCAPE-SO-A-VERBATIM-PASTE-FAILS-VERIFY`
at pinned ledger line 2231.


verify: sh F=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; B='\'; RE="^[[:space:]]*emit .*${B}${B}u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]"; grep -qE "$RE" <<<"  emit X \"a ${B}u2026 b\"" || exit 1; grep -qE "$RE" <<<"# comment quoting ${B}u2026" && exit 1; [ "$(grep -cE "$RE" "$F")" -eq 0 ]
## BL-035

**LANDED (v0.377.0, verified 867597a).** `reconcile/lib.sh` gains `ledger_close_awk()`, which LIFTS the anchored close grammar out of `ledger-reverify.sh` rather than owning or restating it — the `map_consumer()` shape already used at six sites in that directory. THREE drifted predicates now route through it: `ledger-rotate.sh`'s stuck-set `loose` rule, `ledger-reverify.sh`'s `hasclose`, and `warn-shadowed-local-validators.sh`, which also loses the THIRD hand-copy of the entry-boundary rule.

**THE ENTRY NAMED ONE PREDICATE AND FOUR HAD DRIFTED.** Measured on the reference consumer's live ledger, sides asserted byte-different first: the stuck-set report goes **12 rows to 5**, seven dropped, zero added — and three of the seven false rows are `PC-S329`, `PC-S330` and `PC-S334`, the entries filing these very defects. `warn-shadowed-local-validators.sh` pre-fix advises RETIRING a fork whose entry only says "annotate it ADOPTED UPSTREAM once X is upstreamed"; post-fix it drops that row and keeps the genuinely closed one.

**THE ENTRY'S OWN PIN HAD EXPIRED** — it cites 4356 lines and 9 stuck rows; the ledger is 2953 lines and the shipping rotator reported 12.

**SHAPE 3 OF THREE, AND THE OTHER TWO WERE BUILT AND MEASURED.** Restating the anchor at the call site satisfies the receipt but leaves two copies. MOVING the predicate into `lib.sh` is genuinely correct and breaks TWO independent anchors keyed on the emitting line's text — `core/fixtures/ledger-reverify/run.sh`'s mutation arm, which then correctly reports "the mutation matched nothing, so the anchor assertions above are unproven", and this receipt. Reading the line leaves `ledger-reverify.sh:769` byte-unchanged, so both keep working and the grammar still exists once.

**THE FOURTH PREDICATE WAS DELIBERATELY NOT ROUTED, ON A MEASUREMENT, AND IS FILED AS `BL-071`.** `susp_closed` SUPPRESSES a refusal, so it fails in the OPPOSITE direction to the stuck rule: driven on the false-positive case `core/fixtures/ledger-rotate/run.sh` already carries, the anchored form turns a REAL entry into `REFUSING to rotate` — rc 0 to 1 — and a refusal writes nothing. One rule cannot serve both.

**`ledger-rotate.sh` reports an entry as "closed for re-verification" using an UNANCHORED phrase
test, while `ledger-reverify.sh` decides the same question with a LINE-LEADING anchor — so 4 of
the 9 entries the report names are ones reverify does not skip.** `ledger-rotate.sh:145` is
`/ADOPTED UPSTREAM|WITHDRAWN|\(original text, retained for the record\)/ { loose = 1 }`, matching
anywhere on any body line. `ledger-reverify.sh:769` is
`/^[ \t]*(<br[ \t]*\/?[ \t]*>)?[ \t]*(\*\*[^`]*)?(ADOPTED UPSTREAM|WITHDRAWN)/ { closed=1 }` —
same words, but only where the line LEADS with the marker. Measured on the pinned reference-consumer
ledger (4356 lines, md5 `2fd444dcf406cdff728fe3c0c4352267`; control: the 4355-line prefix hashes
`d4e39a96a33c5c92adfe4c8457020064`, so the pin is exact), running the shipping
`ledger-rotate.sh` in report mode: **9 stuck rows**. Re-deriving both predicates over the same
corpus through the same `ledger_entry_awk` boundary rule splits those 9 into **5 that reverify
really does skip and 4 that it does not** — `PC-S299`, `PC-S313`, `PC-S329`, `PC-S330`. Controls in
the same invocation, both non-zero: **6** entries reverify closes that rotate's `loose` never sees
at all (they are closed by their TITLE, and `ledger-rotate.sh:106` `next`s on the entry line so
neither of its rules reads a title), and **0** entries rotate would archive that reverify would not
skip. The re-derived stuck total, 5 + 4, equals the shipping program's 9.

The claim the report prints is therefore false for 4 of 9. `ledger-rotate.sh:199-200` tells the
operator "`ledger-reverify.sh` skips them, so they never appear in a report again"; `:17-18` states
the same premise in the header as "treats an entry as closed on `/ADOPTED UPSTREAM/` anywhere in
it"; and `:144` labels the loose rule "reverify.sh entry_line_closes(), restated as the LOOSE side
of the same question" — but `entry_line_closes()` at `ledger-reverify.sh:691` is applied to the
ENTRY LINE only, and reverify's body rule is the different, anchored one at `:769`. Three
statements of a premise that no longer holds, and the middle one is a restatement of a mechanism
rather than a citation of it.

**What the filing got wrong, and the direction: a different cause, and its prescribed fix is now
actively harmful.** The entry says reverify "scopes its skip to the entry TITLE" and prescribes
"scope `loose` to the title, the way `ledger-reverify.sh` scopes `s`." That was true at the sha the
filing measured; it is not true here. Reverify closes on body lines too — it is the ANCHORING that
differs, not the SPAN. Executing the filing's own remedy against the case it reproduces: a copy of
`ledger-rotate.sh` with `loose` computed from the entry line only reports **8** rows instead of 9,
and the two sets overlap in **2** entries. It drops 7 of today's 9 and adds 6 that are new, and **3
of the 5 genuinely-stuck entries disappear from the report** — the exact invisibility the stuck-set
report exists to end. The correction is a REPLACEMENT of the cause, not a widening: the fix is to
give `loose` reverify's line-leading anchor, not the title scope.

The anchor is behavioural and binds to reverify's own regex by `grep -F`-ing the emitting line out
of `ledger-reverify.sh` and running it as awk, rather than restating it — a restated regex is the
drift this entry is about. A looser anchor would false-close: a substring check for the word
"anchored" in `ledger-rotate.sh` is satisfied by the header prose already there, and an anchor on
the premise sentence at `:199` is satisfied by any rewording that leaves the predicate untouched.
The probe's two arms are each other's control: the mid-sentence mention must be reported stuck by
rotate and NOT closed by reverify's predicate, and the line-leading `**WITHDRAWN` annotation must be
reported by rotate AND closed by reverify. Measured against a copy carrying the fix
(`loose` given reverify's anchor): exit **0**. Against the tree today: exit **1**.

Discharges the consumer entry `PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-RULE-IT-CITES`
at pinned ledger line 3647.


verify: sh R=core/skills/ai-dlc-update/reconcile; P='(ADOPTED UPSTREAM|WITHDRAWN)/ { closed=1 }'; [ "$(grep -cF "$P" "$R/ledger-reverify.sh")" -eq 1 ] || exit 1; A=$(grep -F "$P" "$R/ledger-reverify.sh"); D=$(mktemp -d); printf '## PC-PROBE-MENTION — probe\n\nProse: annotate ADOPTED UPSTREAM (v9.9.9, verified <date>) once the grep is non-zero.\n' > "$D/m.md"; printf '## PC-PROBE-ANNOT — control\n\n**WITHDRAWN 2026-01-01, the premise was false.**\n' > "$D/a.md"; cat "$D/m.md" "$D/a.md" > "$D/push-candidate-ledger.md"; S=$(bash "$R/ledger-rotate.sh" "$D/push-candidate-ledger.md" 2>&1); LC_ALL=C awk "$A"'END{exit !closed}' "$D/m.md"; vm=$?; LC_ALL=C awk "$A"'END{exit !closed}' "$D/a.md"; va=$?; rm -rf "$D"; [ "$vm" = 1 ] && [ "$va" = 0 ] || exit 1; grep -qF 'PC-PROBE-ANNOT' <<<"$S" || exit 1; ! grep -qF 'PC-PROBE-MENTION' <<<"$S"
## BL-046

**LANDED (v0.377.0, verified 867597a).** The scrub was already in both hooks; what this release establishes is that it RUNS BEFORE the fixture dispatch, and what it ADDS is the arm that would fail without it.

**THE RECEIPT IS PRESENCE-ONLY AND THE CLAIM IS SITING, SO THE STATUS WAS NOT THE EVIDENCE.** Adjudicated behaviourally instead, by a real `git push` from a real LINKED WORKTREE through the shipping hook, with only the scrub line removed and the two sides asserted byte-different first. `.githooks/pre-push`: scrub present, the dispatched worker sees `GIT_DIR=<UNSET>` and the repository is untouched; scrub removed, `GIT_DIR=<repo>/.git/worktrees/<name>`, commit count 971 to **972**, `poison.txt` tracked in the real repo **1**. `core/git-hooks/pre-push`, measured on a tree built by `scripts/install.sh` rather than in `core/`: `<UNSET>` and 1 to 1 against `GIT_DIR` set and 2 to **3**.

**THE FIX WAS UNRELEASED.** `6c8bb7c` carries `VERSION=0.376.0` and sits after that release commit, so the inclusive forward walk lands on THIS release — and `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` appeared in **0** commit messages against a prefix control of 6, so it had never reached the consumer's close channel at all.

**THE GUARD FOUND A MUTANT THE BRIEF DID NOT ASK FOR, AND IT IS THE DECISIVE ONE.** `core/fixtures/prepush-worktree-env-scrub/` kills three: the scrub removed, a comment merely naming the variable, and — the third — the scrub MOVED BELOW THE DISPATCH, which satisfies this entry's receipt regex EXACTLY ONCE and still lands the probe's sandbox commit on the real repository. That is the entire gap between "the line exists" and "the line runs first".

**Neither pre-push hook scrubs git's worktree environment, so a push issued from a linked
worktree redirects 33 fixture sandboxes onto the real repository.** Measured on this machine
with a control in the same invocation: a `pre-push` hook driven by a push from the PRIMARY
checkout sees `GIT_DIR` **UNSET**; the same hook driven by a push from a LINKED WORKTREE sees
`GIT_DIR=<repo>/.git/worktrees/<name>`. The damage arm, same construction: with `GIT_DIR`
exported, a fixture-shaped `mktemp -d; git init; git add; git commit` sequence committed into
the REAL repository — commit count 1 → 2, `poison.txt` tracked in the real repo = **1**; with
`GIT_DIR` unset the identical sequence left the real repo untouched — count unchanged, tracked
file = **0**. Both hooks lack the scrub: `grep -c GIT_OBJECT_DIRECTORY` over
`.githooks/pre-push` and `core/git-hooks/pre-push` = **0 / 0**, against a control token
(`fixture`) in the same invocation over the same two files = **66 / 68**. `unset GIT_` occurs
**nowhere** in the tree. Blast radius: **33 of 160** fixture directories `git init` inside a
`mktemp` sandbox and so depend on git's upward repository discovery, which git only consults
when `GIT_DIR` is unset (control: an impossible token over the same corpus = 0).

**The filing is narrower than the defect in two directions, and its stated reason that
upstream is immune is false.** It anchors on `core/git-hooks/pre-push` alone; `.githooks/pre-push`
— this repo's own runner, which invariant **I66** binds to be one program with it — has the
same hole, and its `xargs -P "$FIXTURE_JOBS"` dispatch at `.githooks/pre-push:494` inherits the
parent environment exactly as the consumer's does at `core/git-hooks/pre-push:537`. More
importantly the entry argues "the distribution develops in its own primary checkout, where git
exports nothing, so the asymmetry does not arise there." **Measured now: `git worktree list` on
this distribution repo reports 8 entries, 6 of them linked worktrees under
`.claude/worktrees/agent-*`** — created by the agent-isolation harness, not by hand. The
distribution is in the affected population today, and the entry's own reason for treating it as
out of scope is the part that expired.

The anchor is `GIT_OBJECT_DIRECTORY` because the scrub cannot be written without naming the
variables it unsets, and the pattern is anchored to `^[[:space:]]*unset[[:space:]]` — the
EMISSION site, not the file. Measured against the dominant failure mode: a line reading
`# we deliberately do not unset GIT_OBJECT_DIRECTORY here` does **not** satisfy it, so a fix
that documents what it removed cannot false-close the receipt. Seeded both other directions in
the same invocation: with both hooks scrubbed the predicate returns **0**, and with only ONE of
the two scrubbed it stays **1** — a half-fix cannot close it.

Discharges the consumer entry `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` at
pinned ledger line 3881.


verify: sh for h in .githooks/pre-push core/git-hooks/pre-push; do grep -qE '^[[:space:]]*unset[[:space:]].*GIT_OBJECT_DIRECTORY' "$h" || exit 1; done
## BL-050

**LANDED (v0.377.0, verified 867597a).** Step 8 now carries a disposition for every status `reconcile/emit-report.sh`'s push-candidate heading puts in front of the operator, and a fourth **I39** arm makes the omission unconstructible.

**THE ENTRY NAMED ONE STATUS AND FOUR WERE UNDISPOSED** — `NAMED-UPSTREAM`, `NAMED-UPSTREAM-AMBIGUOUS`, `INPUT-UNRESOLVED` and `RECEIPTS-UNDECIDED`. And step 8 was the odd one out among THREE readers, not two: the report heading already groups `NAMED-UPSTREAM` with `CLOSE-CANDIDATE` under "the operator confirms and annotates", agreeing with §3f against step 8.

**I39 COULD NOT SEE IT AND WIDENING IT IS NOT THE FIX.** Its SKILL-side population is step 3f's span alone, bounded because the same bullet grammar over the whole file matches other detectors' statuses. §3f is the DESCRIPTION and was correct throughout; the disagreement lived in the ACTION. The new arm binds the acting region to the heading's status set — both sides derived, neither hand-listed — intersected with what the emitter produces, so a phantom heading status is reported once rather than twice.

**THE RECEIPT CLOSES ON A SENTENCE ABOUT A DIFFERENT STATUS.** `grep -F NAMED-UPSTREAM` matches inside `NAMED-UPSTREAM-AMBIGUOUS`, so a step 8 disposing only the AMBIGUOUS row satisfies it — measured, exit 0, a false close — while the backtick-delimited arm still reports `NAMED-UPSTREAM` missing. An "out of scope for this step" sentence RESTATING the defect closes it too. The delimiters are the whole false-positive narrowing: SKILL.md already writes every status that way, and `STILL-LIVE` — filtered from the report, owed no action — resolves 0, so the predicate discriminates rather than flagging everything.

**Step 8 forbids the annotation §3f instructs, and `NAMED-UPSTREAM` is the status it never
names.** `core/skills/ai-dlc-update/SKILL.md:1688` is the acting instruction — "Close ONLY
`CLOSE-CANDIDATE` rows; a `NEEDS-REVIEW` row is never a close, whatever its detail says." §3f at
`:738-745` says the opposite for `NAMED-UPSTREAM`: "**Not auto-closable** … It is not *unclosable*:
the row instructs an annotation, and **any** occurrence of `ADOPTED UPSTREAM` in an entry makes
`ledger-reverify.sh` skip it from the next run on." The emitter at
`reconcile/ledger-reverify.sh:848` instructs that annotation in its detail. Measured over step 8's
region (`^8\. \*\*Deliver` to `^9\. \*\*Safety`): occurrences of `NAMED-UPSTREAM` = **0**; control,
`CLOSE-CANDIDATE` in the same region = non-zero, so the search ran over live text.

**The filing is wrong about the mechanism in two places, and the defect moved rather than
survived.** It claimed line 787's detail hands the reader "the identical closure instruction" as
the three `CLOSE-CANDIDATE` emitters. That is now false: `:848` reads "Confirm whether that commit
ABSORBED the entry or recorded a rejection/split; if it absorbed, annotate…", which is exactly the
disambiguation the filing's own remedy asked for, while `:906`/`:935`/`:1027` still assert
absorption. It also quoted §3f as saying "**Not closable**"; §3f now reads "**Not auto-closable**"
and resolves the contradiction the filing's SECOND coherent answer proposed — make it closable and
say so. What did not happen is the other half of that answer: "§3f and step 8 must say so, and the
two places must agree." Step 8 was never updated.

The direction also flipped. The filing feared over-closing on the strength of a naming. Today's
residue is under-closing: a reader executing step 8 literally leaves every `NAMED-UPSTREAM` row
unannotated, which is the "confident wrong answer" §3f warns about at `:733-737` — the entry keeps
reporting `STILL-LIVE` on a receipt §3f has already told you is structurally incapable of deciding.

The anchor is a status TOKEN inside the region that acts, not prose describing a fix: step 8 cannot
be given a disposition for `NAMED-UPSTREAM` without naming it. A whole-file grep would false-close
immediately — the token occurs five times in §3f at `:732`, `:737`, `:748`, `:755` and `:791`,
which is the near-miss, and the receipt reports 1 against it today.

Discharges the consumer entry `PC-S329-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS-OWN-STATUS-FORBIDS`
at pinned ledger line 3595. **Its own receipt is inverted and must not be trusted to close it** —
`theirs_has …/ledger-reverify.sh "recorded a rejection/split; if it absorbed, annotate"` anchors on
the defect's CURRENT wording, which is present at `:848` (count 1; control, `ADOPTED UPSTREAM` = 16),
so it reads CLOSE-CANDIDATE while the entry is live.


verify: sh S=core/skills/ai-dlc-update/SKILL.md; r="$(sed -n '/^8\. \*\*Deliver/,/^9\. \*\*Safety/p' "$S")"; grep -qF CLOSE-CANDIDATE <<<"$r" || { echo "CONTROL FAILED"; exit 9; }; grep -qF NAMED-UPSTREAM <<<"$r" && exit 0; exit 1
## BL-068

**LANDED (v0.377.0, verified 867597a), AND THE REMEDY IS PROSE.** The invariant is corrected at every site: `ledger-rotate.sh`'s header, the message it PRINTS to the operator at report time, `SKILL.md` step 8, and the fixture's `README.md` and `run.sh`. `prefix_entry_count()` is byte-unchanged.

**ITS OWN RECEIPT REWARDED A DOCUMENTED REGRESSION.** Four candidate remedies were built and run. The ONLY one it accepts is dropping the counter's archive arm — which `CHANGELOG.md` records as a deliberate earlier fix, whose removal made the count ANTI-MONOTONIC and turned a correct `AMBIGUOUS` into a confidently wrong single attribution. A bare `prefix_entry_count() { echo 1; }` stub also exits 0. Both remedies this entry's own prose calls legitimate — rewording, and deleting the sentence — exit 1 forever, because the receipt's entire corpus is `ledger-reverify.sh` and the string `ledger-rotate` never appears in it. The receipt is REPLACED with one that drives the shipping rotator and reads what it prints, proven four ways: fixed 0, pre-fix 1, a silent stub 9, the guidance line deleted 1.

**THE CODE ROUTE WAS MEASURED AND REJECTED.** Widening the live side to include annotated-but-unrotated entries moves 18 displayed counts on the reference consumer and flips **zero** classifier verdicts — control: a synthetic 1 to 2 does report a flip — and it double-counts retained copies. Not enough to touch a reader seven call sites share.

**THE FIXTURE'S ACCEPTANCE ARM HAD BEEN DECORATIVE SINCE THE DAY IT WAS WRITTEN**, and unconstructibly so: its corpus carried no `PC-S<n>` id, so `named_ambiguous()` could never produce the row it asserts on, whatever the code did. It now seeds a PC-S900 trio and an archive, compares the ROW SET by status and subject, and fires BOTH ways — 7 rows before and after with the set identical and 2 of 7 LINES differing, so the byte assertion it replaces would have FAILED there; and a committed SWEEP mutant where the row set genuinely changes and the new arm FAILS. A counter-regression arm now kills the archive-arm deletion, which nothing in this repo caught before.

**`ledger-rotate.sh` states a byte-identical invariant that its own prescribed workflow breaks, and
the fixture asserting it cannot reach the shape that breaks it.** `ledger-rotate.sh:38-41` reads
*"Closed entries are exactly the ones ledger-reverify already skips, so rotating them must not
change its output by a single byte. Run ledger-reverify.sh before and after and diff the two — that
is the acceptance test, and the fixture asserts it."* The premise is false for any entry annotated
in the same pass, which is exactly what the annotate-then-rotate step prescribes.

**The mechanism is an asymmetric union.** `prefix_entry_count()`
(`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:386-390`) counts over
`$ENTRIES` unioned with `$ARCHIVE_LABELS`. The live side is the OPEN set — the extractor skips any
entry containing `ADOPTED UPSTREAM` (`:639`). So a freshly annotated entry is on NEITHER side while
it sits in the live file, and on the ARCHIVE side once rotated. **The count RISES across a move that
can only ever reduce the live set.** Measured by extracting the shipping function and driving it
either side of the move: `1` before, `2` after.

That count is emitted only inside a `NAMED-UPSTREAM-AMBIGUOUS` row, so the diff appears as changed
prefix counts on otherwise identical rows. Measured on the reference consumer across a real
annotate-then-rotate of 56 entries: the row SET was identical at 84 rows, 10 LINES differed, and
10 of 10 carried a prefix count — `PC-S296` went from *"6 entries in this ledger carry it"* to
*"10 entries"*. Nothing was swept.

**The consequence is an operator unwinding correct work.** The spec's stated conclusion for a
non-empty diff is that a live entry was swept. Here the diff is real and the conclusion is false,
and the instruction is followed at exactly the moment a large batch of closes has just landed.

**The fixture cannot fire on this, and the row it would need is UNCONSTRUCTIBLE rather than merely
unseeded.** `core/fixtures/ledger-rotate/` seeds already-annotated entries and asserts the
byte-identical property at `run.sh:5` and `run.sh:90`, but has **0** occurrences of `AMBIGUOUS` in
either `seed.sh` or `run.sh` — control in the same invocation, `STILL-LIVE` returns 2 in `run.sh`.

The structural reason is one level down: **`seed.sh` carries 0 ids of the form `PC-S<n>`**. Its
labels are `PC-OPEN-A`, `PC-CLOSED-A` and `PC-OPEN-DECOY`. Control in the same invocation — 6 entry
headings and 2 `PC-` ids of any form are present, so the search reaches the file and discriminates.
`named_ambiguous()` extracts a `PC-S<n>` sprint prefix and gates on two or more entries sharing it,
so with no such id in the corpus **the fixture could not produce a `NAMED-UPSTREAM-AMBIGUOUS` row no
matter what the code under test did.**

**That distinction decides the remedy.** "Unseeded" invites adding a seed. "Unconstructible" says
the fixture's corpus shape cannot express the property its own assertion names — so that assertion
has been decorative since the day it was written, and would have stayed green through any future
rewrite of the invariant it exists to guard. A guard that never had a subject is not a gap in
coverage; it is a check that cannot fire, reading exactly like one that passed.

**The substantive guarantee DOES hold and is what the test should compare**: the row set, by status
and subject, is unchanged. Only the count annotation on ambiguous rows moves.

Both a counter fix and a rewording of the invariant are legitimate, so the receipt keys on the
BEHAVIOUR rather than on any substring: it extracts the shipping `prefix_entry_count()`, drives it
with a label on the live side and a second label moving into the archive, and asserts the two counts
AGREE. Sanity arms exit 9 — the extraction must contain the function, must `eval` cleanly, must
leave it callable, and both counts must be integers of at least 1.

**THE `eval`-CLEANLY AND STILL-CALLABLE ARMS WERE ADDED AFTER A FALSE GREEN IN THIS ENTRY'S OWN
SATISFIABILITY TEST.** A first mutant mangled the function into invalid shell; the original guard
tested only that the extracted TEXT CONTAINED the string `prefix_entry_count`, which mangled text
still does. `eval` failed, the function was never defined, both counts came back EMPTY, and
`[ "" = "" ]` returned 0 — a receipt reporting the fix present against a copy where its subject did
not exist. A guard that a name is MENTIONED is not a guard that it is DEFINED.

Verified in three directions: against the shipping tree the receipt exits **1** (STILL-LIVE);
against a copy whose live side is widened to include annotated-but-unrotated entries it exits **0**,
with the copy asserted to differ from shipping AND to pass `bash -n` before the result was read;
and against a deliberately mangled extraction it exits **9** rather than falsely closing.

Found by the graph consumer session while applying the adjudication brief. Cross-references the
consumer entry `PC-S334-ROTATE-ACCEPTANCE-TEST-FALSE-FAILS-ON-THE-WORKFLOW-IT-DOCUMENTS`.

verify: sh R=core/skills/ai-dlc-update/reconcile/ledger-rotate.sh; [ -f "$R" ] || exit 9; d=$(mktemp -d) || exit 9; printf '# L\n\n- **PC-CLOSED** an entry\n\n  **ADOPTED UPSTREAM (v0.1.0, verified 2026-01-01).**\n\n- **PC-OPEN** another\n\n  verify: theirs_has core/scripts/t.sh "M"\n' > "$d/push-candidate-ledger.md"; out="$(bash "$R" "$d/push-candidate-ledger.md" 2>&1)"; rc=$?; rm -rf "$d"; [ "$rc" = 0 ] || exit 9; printf '%s' "$out" | grep -q 'would move' || exit 9; printf '%s' "$out" | grep -qi 'BYTE-IDENTICAL' && exit 1; printf '%s' "$out" | grep -q 'SAME ROW SET'

## BL-058

**LANDED (v0.378.0, verified 890b921), AND ITS OWN RECEIPT REQUIRED THE DEFECT TO SURVIVE.** The three spellings are one token, `EXAMINED NOTHING`, declared in `core/skills/ai-dlc/enforcement-map.yaml` under a single top-level `empty_subject_verdict:` block, rendered into `docs/vocabulary-index.md` and bound by invariant **I93**. The exit codes are deliberately UNCHANGED — they are per-validator contracts, one consumer-visible, and unifying them is filed separately as `BL-078`.

**THE RECEIPT COUNTED THE DIVERGENT SPELLINGS AND DEMANDED `n >= 2`.** A correct unification necessarily deletes what it counts: measured live as the fix landed, 3 → **0**, so the original exits 1 forever against a completed fix. Third occurrence of this polarity in the program. Its first replacement, written by an independent hand, keyed on the vocabulary's NAME and was ALSO rejected once the build named the set `empty-subject verdict token` — the shipped receipt keys on the EMITTER PATHS, which a rename cannot move, plus `render-vocabulary-index.sh --check`, which forecloses prose. Proven across seven scenarios; correct in all seven where the original is wrong in three, in both directions.

**THE ENTRY'S SCHEMA HALF WAS STRUCK AS UNSOURCED** — all three emitters mention `gate-adjudication` zero times against a control of 12, so nothing was ever recorded as a pass there, and acting on it would have proposed the third enum member `BL-039` already rejected. A SECOND defect surfaced from that audit and is filed as `BL-080`: the map's Check 3b posture still reads `exit 0 required`, which a vacuous run satisfies.

**Three core validators emit an "examined nothing" verdict, in three spellings carrying three
different exit codes, and no vocabulary joins them.** (The filing's second clause — that the
schema a gate writes its verdict into can express only `PASS` and `FAIL`, so a vacuous run is
recorded as a pass — is STRUCK below as unsourced, and is removed from this sentence rather than
left standing where a reader meets it first.) The three, each with its own documented rationale for
its own choice: `core/scripts/validate-stub-audit.sh:263` prints `AUDITED NOTHING` at **exit 4**;
`core/scripts/validate-locked-anchor.sh:607` prints `PASS — NOTHING VERIFIED` at **exit 0**;
`core/scripts/validate-ci-gates.sh:197`, declared at `:11`, prints `VACUOUS:` at **exit 78**.
Measured over `core/scripts/*.sh`: 3 files emit one of those tokens, out of 34
`core/scripts/validate-*.sh`; control in the same invocation, the same grep shape for an
impossible token returns 0 files. `docs/vocabulary-index.md` — the derived, pre-push
byte-compared register of every controlled vocabulary — carries 7 cross-file vocabularies and 5
schema enums, and **none** of the twelve is this one; the same case-insensitive grep that returns
3 files under `core/scripts/` returns 0 rows there.

**THE SCHEMA HALF OF THIS ENTRY IS STRUCK: it was UNSOURCED, and it would have sent the fix into
a decision another entry has already settled.** The entry claimed that because
`gate-adjudication-verdict.json` records the `verdict` enum as exactly `PASS` `FAIL`, a run that
examined nothing "is recorded as a pass". Measured: all three emitters mention `gate-adjudication`
**zero** times, against a positive control of **12** in `validate-gate-adjudication.sh` in the same
invocation. **There is no path from a vacuous verdict to that schema at all**, so nothing was ever
recorded as anything. Worse, acting on it would have meant proposing a third enum member — which
`BL-039` already adjudicated and rejected, citing the field's own documentation: *"There is no
third value and no empty value. A check you cannot evaluate is FAIL-with-reason, never omitted and
never PASS-by-default."* A third member also breaks a generated region that
`sync-taught-schema.sh --check` byte-matches, and leaves two prose restatements OUTSIDE that region
stale and silent. **A premise that reads as a measurement and names a real file is not a
measurement** — the file existing was never the claim.

**The filing named the wrong home for its one cited instance, and undercounted the population.**
It cites "the file-local `VACUOUS`/rc=78 vocabulary in `ci-local.sh`". No `ci-local.sh` exists
anywhere in this tree — `find` returns nothing for it and returns `./core/scripts/validate-ci-gates.sh`
for the same invocation, which is where that vocabulary actually lives. That is a repoint, not a
close. The population is also wider than the filing's "one instance": three emitters, three
spellings, three exit codes, each argued for at length in its own header and none of them wrong
on its own terms. The disagreement is the finding, not any one choice.

The anchor is `docs/vocabulary-index.md` because that file is **rendered** by
`scripts/render-vocabulary-index.sh` from the owner files at render time and byte-compared at
pre-push, so it cannot be satisfied by prose: a token reaches it only by a real vocabulary
declaration in a real owner.

**THE ORIGINAL RECEIPT REQUIRED THE DEFECT TO SURVIVE IN ORDER TO CLOSE, and this is the third
time that polarity has appeared in this program.** It counted files still carrying the three
divergent spellings and demanded `n >= 2`, describing that clause as a guard against a broken
search. It is not a guard. **A correct unification NECESSARILY DELETES the spellings it counts** —
measured live as the fix landed, the count went 3 → 0 while the new token appeared in 3 files
against an impossible-token control of 0 — so the clause exits 1 forever against a completed fix.
It also failed the second question: the index renders EVERY enum in `core/schemas/*.json`, so
adding a member spelled `vacuous` to any unrelated schema closed it while touching no validator,
and a bare prose sentence in the generated file closed it too.

**The replacement keys on the EMITTER PATHS, which a rename cannot move.** An independent hand's
first attempt keyed on the vocabulary's NAME and was rejected by the build, which named the set
"empty-subject verdict token" — containing none of the words that receipt looked for. That is the
same polarity again, caught by driving rather than by reading. The shipped form asks a structural
question instead: does the cross-file section carry a row naming at least two of the emitters, and
does `render-vocabulary-index.sh --check` still agree with the tree. `--check` is what forecloses
prose — the row cannot be hand-written, because the renderer derives it from a real owner
declaration and the pre-push byte-compare fails otherwise. The marker-count clause is the control:
if the `# vocabulary:` convention is ever rewritten the receipt reports STILL-LIVE rather than
closing on a dead read.

Proven across seven scenarios, sides asserted byte-different first. It is correct in all seven
where the original is wrong in three, in both directions: registration alone **0**, registration
plus unification **0** (the original said 1 — a false reject of the shipped fix), unification with
no registration **1**, an unrelated schema enum member **1** (the original said 0), a bare prose
sentence **1** (the original said 0), one emitter's vacuous branch deleted **1**, and the unfixed
baseline **1**. Rejecting unification-without-registration is deliberate: unifying the spelling
removes today's disagreement and leaves nothing binding it, so a later author simply re-diverges.

**ONE FURTHER CLAUSE, because "registration alone closes" leaves a false close reachable.** A
vocabulary can be registered whose MEMBERS are the three divergent spellings — the set documented
rather than unified — and a receipt that asks only whether a row exists reads that as a fix. The
receipt therefore lifts the members cell out of the row it already found and requires each of the
three emitters to print that exact string on a line that is not a comment. The comment grain is
load-bearing: every one of these scripts states its verdict token in its own exit-code table, so a
whole-file match is satisfied by documentation. Measured with the two forms side by side over a
seeded validator whose header RECORDS the retirement — the shape a good header takes — the
comment-aware form finds 0 and the whole-file form finds 3, with the live token found on the
seed's one emitting line as the control in the same run.

**WIDER than filed on the population, and the widening is deliberately NOT all remediated.** The
same shape exists at other spellings and other exit codes: `NOT-APPLICABLE` emitted by
`validate-artifact-paths.sh`, `validate-request-coverage.sh`, `validate-snapshot-conservation.sh`
and `validate-suppression-lifetime.sh`; `DISARMED` by `validate-spec-join.sh`,
`validate-ac-falsifiability.sh`, `validate-bmad-invocations.sh` and `audit-layer-debt.sh`;
`COMPARED NOTHING` at exit 4 by `sprint-status.sh` in both `check-stories` and `derive-stories`.
Those are EXCLUDED here and enumerated rather than overlooked. `DISARMED` is a DIFFERENT state —
the check could not run at all, which is not the same as running over an empty subject — and the
`NOT-APPLICABLE` / `COMPARED NOTHING` sites are the same state at a scope this entry does not
name. Unifying them is a second change against a wider consumer surface.

**The exit codes are deliberately untouched, and unifying them is not this entry's to decide.**
4, 0 and 78 are per-validator caller contracts, each argued in its own header, and
`validate-ci-gates.sh` argues 78 at length at `:11`. This is a report-grammar unification only.

Remediated at `core/skills/ai-dlc/enforcement-map.yaml` `empty_subject_verdict:` — chosen as owner
because it is the only file in the tree that already declares all three emitters, so the owner is
not one peer promoted over the other two — rendered into `docs/vocabulary-index.md` and bound by
**I93** in `scripts/validate-enforcement-map.sh`. The unified token is `EXAMINED NOTHING`.

Discharges the consumer entry `PC-S297-VALIDATOR-PASS-VS-NOTHING-TO-CHECK-CONVENTION` at pinned
ledger line 1226.


verify: sh G=/usr/bin/grep; V=docs/vocabulary-index.md; M=scripts/validate-enforcement-map.sh; [ -f "$V" ] && [ -f "$M" ] || exit 1; [ "$($G -c '^[[:space:]]*#[[:space:]]*vocabulary:' "$M")" -ge 6 ] || exit 1; SEC=$(sed -n '/^## Cross-file vocabularies$/,/^## Schema enums$/p' "$V"); [ -n "$SEC" ] || exit 1; ROW=$($G -E '^\|' <<<"$SEC" | awk '{c=0; if(/validate-stub-audit\.sh/)c++; if(/validate-locked-anchor\.sh/)c++; if(/validate-ci-gates\.sh/)c++; if(/validate-spec-join\.sh/)c++; if(/audit-layer-debt\.sh/)c++; if(c>=2) print}' | head -1); [ -n "$ROW" ] || exit 1; TOK=$(printf '%s\n' "$ROW" | awk -F'|' '{ x=$3; gsub("\140","",x); sub(/^ +/,"",x); sub(/ +$/,"",x); print x }'); [ -n "$TOK" ] || exit 1; for f in core/scripts/validate-stub-audit.sh core/scripts/validate-locked-anchor.sh core/scripts/validate-ci-gates.sh; do awk -v t="$TOK" '{ if (index($0,t)==0) next; s=$0; sub(/^[[:space:]]+/,"",s); if (substr(s,1,1)=="#") next; n=1 } END { exit(n?0:1) }' "$f" || exit 1; done; bash scripts/render-vocabulary-index.sh --check >/dev/null 2>&1
## BL-059

**LANDED (v0.378.0, verified 890b921), AND ITS OWN FIXTURE REFUTED THE FIRST FIX.** The corpus and the members read are now named across all four output modes, including `--cite` — THE genuine-operator predicate — whose THREE separate diagnostics each carried a count without an identity. The third was found by the replacement receipt after two were patched by reading.

**RENDERING ONLY THE MEMBERS LEFT THE EMPTY CORPUS NAMING NO SOURCE**, and a `--since` window that excludes everything is the invocation `steps/retro.md` itself prescribes — so the corpus is named on its own line, unconditionally. The arm that caught it was written by a different hand from the fix. `--count` stays a bare integer and `transcripts scanned : N` is byte-identical, because `retro.md` reads that line by label.

**THE THREE `--cite` DELEGATORS DISCARD STDERR**, so that half reached no reader inside the distribution until their own FAIL texts were changed to name `$STEER_ARG`. Without it, "the operator did not say this" is asserted over a corpus the reader cannot see. Part 1 of the filing's two-part remedy — deriving the session's own corpus — is deliberately NOT delivered here and is filed as `BL-077`; it changes the default for twelve call sites.

**`validate-steering-budget.sh` reports how MANY transcripts it read and never WHICH, so a
wrong-session run is byte-identical to a correct one.** `--transcript` is a free caller-supplied
path at `core/scripts/validate-steering-budget.sh:152`, `--dir` a free caller-supplied directory at
`:153`, and `:426-437` resolves the corpus as `files = one ? [one] : fs.readdirSync(dir)…` —
nothing binds either input to the invoking session. The evidence block at `:601-603` prints
`transcripts scanned : ${files.length}`, a count. Measured: two runs against two DIFFERENT files
holding identical content produced **byte-identical output**, with **0** occurrences of either
filename in the run that read it. Control in the same invocation: `transcripts scanned` occurs **1**
time in that same output, so the run emitted its evidence header and the zero is a real absence.
`--dir` over the same temp directory printed `transcripts scanned : 2` and named neither file.

**The filing is right about the mechanism and narrow about its scope, in two directions.** It names
only `--transcript`; `--dir` — added after it, for the sprint-scope defect the comment at `:409-424`
records — carries the same unbound-input shape and the same count-only evidence line, so the fix
surface is both modes rather than one. And a PARTIAL fix has landed in the more dangerous half: the
`transcripts scanned` line did not exist when this was filed, and a count reads as provenance while
answering a different question. Of the filing's two-part remedy — derive the lead's own session
transcript, AND print which transcript file was actually read — neither part is done. Direction:
wider, and now with a plausible-looking near-miss sitting in front of it.

**The anchor is the second half deliberately.** Naming the source is what makes a wrong-source run
visible on the gate's face, which is this entry's own stated goal, and it is the half a receipt can
assert without predicting the shape of a derivation mechanism. A looser anchor on `transcripts
scanned` false-closes the moment it is written: that string is already present today. So the receipt
uses it as its CONTROL — if the script stops emitting its evidence header the receipt reports
STILL-LIVE rather than closing on a run that produced nothing. Satisfiability proved against a
mutant: a copy of the script with one extra `log(\`transcripts read   : ${files.join(", ")}\`)`
line above `:603` takes the same receipt to exit 0.

**Corrected on remediation. The population is FOUR output modes and the original receipt could
not see three of them.** `--transcript` and `--dir` share the evidence block; `--cite` — which is
THE genuine-operator predicate that `validate-adversarial-convergence.sh`,
`validate-escalation-resolution.sh` and `ai-dlc-gate-remediation-guard.sh` all delegate to — has
its own output path and carried the same count-without-identity on THREE separate diagnostics;
`--count` is a bare integer by contract and cannot carry provenance without breaking
`steps/gate-validation.md` and `core/fixtures/check-25-steering-conduct`. `$TRANSCRIPT` and `$DIR`
were each printed at exactly one site, both on the unreadable-input FAIL path, so on any
SUCCESSFUL run the identity appeared nowhere. **The third `--cite` site was found by the
replacement receipt, not by reading**: two of the three were patched, the differential still
reported the two corpora indistinguishable, and the zero-parseable-records branch was the reason.

**The original receipt failed all three questions and in three different polarities.** It CLOSED
on a hardcoded constant string that reads nothing; on an echoed ARGUMENT rather than the resolved
corpus; and on a fix that renders the path and then exits 1, because `O=$(...)` discards `$?` and
the receipt never read the validator's status. It REJECTED the entry's own two-part remedy
implemented as a refusal, and it closed on a `--transcript`-only fix with `--dir` — which this
entry puts in scope — still broken. Measured across a 13-variant battery on patched copies.

**The replacement anchors on DISCRIMINATION rather than on a string**, which is this entry's own
measurement turned into an assertion: two `mktemp -d` corpora holding identical content and
identically-named members, whose outputs must DIFFER, in all three of `--transcript`, `--dir` and
`--cite`. Random directory names make a hardcoded literal unconstructible; the four exit-status
guards kill the render-then-fail regression; the member-name arms kill the argument echo and force
both modes. Proven both ways in one invocation with the two sides asserted to differ: **0** against
the fixed tree, **1** against the pre-fix copy.

**The `--cite` half of the fix reached NO reader inside the distribution until its three
delegators were changed too, and that was found by the fixture hand rather than by the fix.** All
three callers — the convergence validator, the escalation gate and the remediation guard — invoke
`--cite … --quiet >/dev/null 2>&1` and read only `$?`. `--quiet` does not suppress the cite
diagnostic (it is `console.error`, ungated); what discards it is each caller's own redirection. So
naming the corpus inside `--cite` improves a human's hand-run and nothing else. The place identity
actually reaches a reader is each delegator's own FAIL text, which named the QUOTE and the window
and never the corpus — meaning "the operator did not say this" was asserted over a corpus the
reader could not see, and a wrong-corpus run made that accusation indistinguishable from a true
one. Both failure texts now name `$STEER_ARG`.

**The first fix was incomplete and its own fixture refused it, in the case that matters most.**
Rendering only the members READ leaves a run that found NOTHING naming no source — and a
`--since` window that excludes every file is the invocation shape `steps/retro.md` itself
prescribes, so the empty corpus is a live path rather than an edge. A wrong-corpus run that comes
back empty is exactly the reading a reader cannot distinguish from a right one, which is this
entry's whole subject. The corpus is therefore named on its own line, unconditionally, and the
member list is separate. **The arm that caught it was written by a different hand from the fix**,
which is the mechanism `fixture-mutants.md` requires and the second time in this batch it refuted
its own author.

**Half of the filing's two-part remedy is NOT delivered here, deliberately and with the reason.**
Part 1 — derive the lead's own session transcript rather than trusting a caller-supplied path — is
implementable: `CLAUDE_CODE_SESSION_ID` is in the environment of any harness child, the derived
corpus path resolves to a real file, and an all-zeros-UUID control correctly does not. It is filed
separately rather than landed here because it changes the DEFAULT corpus for twelve call sites and
retires a model-retyped `ls -t | head -1` derivation in `steps/gate-validation.md`, which is a
consumer-visible behaviour change and not the half this entry's anchor is about.

Discharges the consumer entry `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE` at pinned
ledger line 1381.


verify: sh DA=$(mktemp -d); DB=$(mktemp -d); [ "$DA" != "$DB" ] || exit 9; J=type:user; for d in "$DA" "$DB"; do printf "%s\n" "$J" > "$d/alpha-session.jsonl"; printf "%s\n" "$J" > "$d/bravo-session.jsonl"; done; V=core/scripts/validate-steering-budget.sh; OA=$(bash "$V" --transcript "$DA/alpha-session.jsonl" 2>/dev/null); RA=$?; OB=$(bash "$V" --transcript "$DB/alpha-session.jsonl" 2>/dev/null); RB=$?; OC=$(bash "$V" --dir "$DA" 2>/dev/null); RC=$?; OD=$(bash "$V" --dir "$DB" 2>/dev/null); RD=$?; OE=$(bash "$V" --dir "$DA" --cite zzznosuchphrasezzz 2>&1); OF=$(bash "$V" --dir "$DB" --cite zzznosuchphrasezzz 2>&1); rm -rf "$DA" "$DB"; [ "$RA" = 0 ] && [ "$RB" = 0 ] && [ "$RC" = 0 ] && [ "$RD" = 0 ] || exit 9; grep -qF "transcripts scanned" <<<"$OA" || exit 9; [ "$OA" != "$OB" ] || exit 1; [ "$OC" != "$OD" ] || exit 1; [ "$OE" != "$OF" ] || exit 1; grep -qF "$DA" <<<"$OA" && grep -qF "$DB" <<<"$OB" && grep -qF "$DA" <<<"$OC" && grep -qF "$DB" <<<"$OD" || exit 1; grep -qF "alpha-session.jsonl" <<<"$OC" && grep -qF "bravo-session.jsonl" <<<"$OC"
## BL-061

**LANDED (v0.378.0, verified 890b921), AND THE PREDICATE HAD THREE COPIES.** `steer_dir_has_transcript()` now requires a readable `*.jsonl` rather than a directory that merely exists, byte-identically in `validate-adversarial-convergence.sh`, `validate-escalation-resolution.sh` and `core/hooks/ai-dlc-gate-remediation-guard.sh`, bound by invariant **I92** in both directions — drift between the copies, and a fourth copy appearing.

**THE TRIGGER IS NOT EMPTINESS BUT HOLDING NO `*.jsonl`**, since that is what the corpus reader selects, so a sidecar-only directory was exactly as blind. The escalation copy was not a wedge but reported the OPERATOR as having said nothing where the true state was no corpus; the hook copy took `dirname` and made its own readable-file fallback unreachable.

**THE FIX IS IN THE PREDICATE BECAUSE THE ENTRY'S OWN THIRD SHAPE IS A REGRESSION** — clearing `STEER_FLAG` after the chain has run skips the single-file fallback and loses the deny for a caller passing both flags, measured rc 3 → rc 0 on a real fabrication. The original receipt contained no arm anything must still DENY, so deleting the feature scored as FIXED, while a PENDING/SKIP remedy at a distinct code was rejected forever; the replacement pins five exit codes and was proven against three correct fixes and five wrong ones.

**A transcript corpus containing ZERO transcripts is classified as operator forgery rather than
as absent ground truth, so passing an empty `--transcript-dir` WEDGES the pipeline while passing
no flag at all does not.** `core/scripts/validate-adversarial-convergence.sh:795` selects the
corpus with `[ -n "$TRANSCRIPT_DIR" ] && [ -d "$TRANSCRIPT_DIR" ]` — the directory EXISTS, never
that it holds a transcript — so an empty directory takes precedence and the `[ -z "$STEER_FLAG" ]`
fail-open branch at `:800-807` is never reached. Driven end-to-end against the real validator on
the seeded `adversarial-citation` corpus, one series, three arms:

```
(no flag)                        state=RESOLVED   rc=0     <- fail-open, as designed
--transcript-dir <0 files>       state=DIVERGENT  rc=3     <- DENIES every dispatch
--transcript-dir <real.jsonl>    state=RESOLVED   rc=0     <- CONTROL: corpus path verifies
```

The third arm is the control in the same invocation: it returns RESOLVED on the same record and
the same series, so arm 2's rc 3 isolates the empty corpus and cannot be a malformed record
reported twice. The three sides differ, so this is not two runs reading one tree. At the predicate
below it, `core/scripts/validate-steering-budget.sh --dir` returns the same rc 2 for an empty
directory (0 files) as for a populated one lacking the quote (1 file), while a populated directory
carrying the quote returns rc 0 — so the "searched and absent" and "nothing to search" cases are
byte-identical to every caller.

**Reachable from the shipped hook by an asymmetry in its own two guards.**
`core/hooks/ai-dlc-acknowledge.sh:266` gates `--transcript` on `[ -r "$TRANSCRIPT" ]`, but `:271`
gates `--transcript-dir` on `[ -d "$(dirname "$TRANSCRIPT")" ]` only. A `transcript_path` that is
set but not yet readable therefore suppresses the file flag and still forwards the directory, and
rc 3 at the hook tier denies every `Agent|Task|Skill|TaskCreate` dispatch. I did not measure how
often that state occurs in production; a consumer transcript corpus lives outside both repos, and
that is an unmeasured frequency, not an unmeasurable one.

**The filing is corrected in two directions, both NARROWER.** Its second-site claim —
`validate-escalation-resolution.sh` "still on the OLD single-file scoping … no `--dir` arm in its
own arg parse and no forwarding" — is DEAD. That file now parses `--transcript-dir` at `:102` and
forwards `--dir` at `:246`, landed in `2e75c33` ("the escalation citation verifier could not see
the session the operator spoke in", v0.255.0); control, an impossible token `--transcript-ZZZNOSUCH`
over the same file, returns 0 commits. And the general fail-open/fail-closed inversion the entry
calls "perverse" is a SETTLED DESIGN, not a defect: `core/fixtures/adversarial-citation/run.sh:100-104`
asserts both halves as required behaviour (`terminal/none RESOLVED/0` and
`terminal/silent.jsonl DIVERGENT/3`) with a stderr-marker arm forbidding a silent fail-open, and
the run is 10/10 ok today. What survives is only the case the design's own comment at `:801`
already claims to handle — "No ground truth to check against" — reached with a corpus that has none.

**Why the anchor is the anchor.** No fixture arm anywhere exercises an empty corpus: all 10
`--transcript-dir` occurrences under `core/fixtures/` pass a populated `"$ROOT"`, and 0 pass a
`mktemp` directory. A looser receipt keyed on the two-tier posture generally would false-close the
moment anyone reads the fixture, because that posture is correct and asserted. A substring receipt
would be worse still: the three fix shapes (count the corpus before selecting it, require a
readable transcript inside it, or fall through to the `-z "$STEER_FLAG"` branch) share no token.
The 10 and the 0 are confirmed on re-derivation; the control figure of "178 fixtures that use
`mktemp`" is a FILE count mislabelled as a fixture count — the suite holds 162 fixture directories,
so 178 could never have been one, and the correct control is 182 files across 156 directories.

**Corrected on remediation, in three directions, and each correction moved the fix.**

**The trigger is not emptiness, it is holding no `*.jsonl`.** `validate-steering-budget.sh:427`
selects the corpus with `readdirSync(dir).filter(f => f.endsWith(".jsonl"))`, so a directory
holding a sidecar `.txt` is exactly as blind as an empty one and reached the same DIVERGENT/3.
That is the MORE reachable half: the hook passes `dirname "$transcript_path"`, a harness directory
that can hold sidecar files. Five arms in one invocation, with two positive controls — a real
`silent.jsonl` corpus still DENIED at 3 and a real `real.jsonl` corpus RESOLVED at 0 — so the
empty and no-`.jsonl` arms are isolated and the scan is not dead.

**The predicate has THREE copies, not one.** `core/scripts/validate-escalation-resolution.sh` and
`core/hooks/ai-dlc-gate-remediation-guard.sh` carry it byte-identically. The escalation copy is not
a wedge — that tier is fail-closed by design — but with nothing to search it reports the OPERATOR
as having said nothing, which is an accusation where the true state is that the gate had no corpus.
The hook copy takes `dirname "$TRANSCRIPT"`, so its `--dir` branch won on an empty corpus and the
readable-file fallback below it was unreachable. A fix at one site leaves the other two.

**The fix goes in the PREDICATE, and the entry's own third shape is a regression.** Clearing
`STEER_FLAG` after the `if`/`elif` chain has run skips the `-r "$TRANSCRIPT"` fallback, so a caller
passing an empty directory ALONGSIDE a readable transcript falls to fail-open instead of using the
file it was handed: driven on a real forgery, rc 3 → rc 0, the deny lost.
`core/skills/ai-dlc/steps/gate-validation.md` instructs the operator to pass both flags, so that
state is documented rather than hypothetical.

**The receipt was REPLACED, and the original failed all three questions.** It asserted only that
two arms both return 0 — no arm anything must still DENY — so deleting the `--transcript-dir`
feature, neutering the citation check, and making the dir branch unreachable ALL scored as FIXED,
while the entry's own third fix shape scored as fixed despite losing the deny. Arm `a` was not a
control either: it asserts 0, the same direction as the verdict. And a PENDING/SKIP remedy at a
distinct non-zero code — which `mechanism-design.md` explicitly permits — would have been REJECTED
forever, so the replacement reads `b -ne 3` rather than `b -eq 0`. The replacement adds the three
arms the original lacked: a genuine corpus must still RESOLVE at 0, a forgery corpus must still
DENY at 3, and an empty directory passed alongside a readable forgery must still DENY at 3. Driven
across three independently written correct fixes and five wrong ones, the replacement passes only
the three correct ones; proven both ways in one invocation, **0** against the fixed tree and **1**
against the pre-fix copy with the two sides asserted to differ.

Discharges the consumer entry `PC-S300-RESOLUTION-RECORD-CITATION-CANNOT-OUTLIVE-ITS-SESSION` at
pinned ledger line 2785.


verify: sh R=$(bash core/fixtures/adversarial-citation/seed.sh | tail -1); E=$(mktemp -d); G=$(mktemp -d); D=$(mktemp -d); cp "$R/real.jsonl" "$G/"; cp "$R/silent.jsonl" "$D/"; V=core/scripts/validate-adversarial-convergence.sh; S="$R/terminal/s-adversarial-p"; bash "$V" --series "$S" --cycle-state >/dev/null 2>&1; a=$?; bash "$V" --series "$S" --cycle-state --transcript-dir "$E" >/dev/null 2>&1; b=$?; bash "$V" --series "$S" --cycle-state --transcript-dir "$G" >/dev/null 2>&1; c=$?; bash "$V" --series "$S" --cycle-state --transcript-dir "$D" >/dev/null 2>&1; d=$?; bash "$V" --series "$S" --cycle-state --transcript "$R/silent.jsonl" --transcript-dir "$E" >/dev/null 2>&1; e=$?; rm -rf "$R" "$E" "$G" "$D"; [ "$a" -eq 0 ] && [ "$b" -ne 3 ] && [ "$c" -eq 0 ] && [ "$d" -eq 3 ] && [ "$e" -eq 3 ]
## BL-063

**LANDED (v0.378.0, verified 890b921), AND ITS FIXTURE FOUND A FALSE POSITIVE THE FIX MADE REACHABLE.** `:164` accepts the producer's optional qualifier, so `(capability by bmad-spec)` no longer empties `CAP_ENTRIES` and disarms the whole of Check 30 at an `exit 2` sitting above every other join. Measured on the reference consumer: sprint s302 goes from **0 of 7** locked-requirement ids checked to **7 checked**. The DISARM message moved with the predicate.

**THE ORIGINAL RECEIPT'S `[ "$s" -ne 2 ]` ACCEPTS rc 1, AND BOTH DESTRUCTIVE REMEDIES LAND THERE** — with the predicate deleted the run falls through to the next join and fails at it, so deleting the guard scored as FIXED. The replacement pins five exact codes, including a non-capability corpus that must still DISARM at 2, which is what kills both a destructive fix and a widening gone vacuous.

**UN-DISARMING CHECK 30 EXPOSED A PRE-EXISTING DEFECT ONE LINE UP**, filed as `BL-079`: the LR population is a whole-file scan, so an absent-id CONTROL TOKEN quoted in a consumer's prose becomes a finding. It is filed rather than patched because the symmetric narrowing drops zero and every narrowing that clears it loses genuine locked requirements or disarms the check.

**One `grep` at `core/scripts/validate-spec-join.sh:164` takes down the whole of Check 30 when a
memlog tags a capability entry with the producer's optional `by <author>` qualifier.** The predicate
requires `)` immediately after `capability`/`capabilities`, and the `exit 2` it guards at `:167`
precedes every other join in the script. Driven rather than read: a synthetic spec seeded
`- (capability) LR-S1-1 -> CAP-1` returns **rc 0**, `PASS (1 locked requirement(s), 1
capability(ies)...)` — the positive control — while the otherwise byte-identical spec seeded
`- (capability by bmad-spec) LR-S1-1 -> CAP-1` returns **rc 2, DISARMED**. Both runs in one
invocation, same PRD, with the two memlogs asserted to differ before the comparison is read.

So it is not "the LR->CAP join" that dies, as filed. Joins (2) CAP->FR, (2a) CAP->AD, (3) story
`capabilities:` frontmatter, the borrowed `lint_spine.py` and `bmad-testarch-trace` verdicts and the
baseline-did-not-reproduce arm all sit below `:167` and never run. **The blast radius is understated
and the stated cause is false.** The filing says `bmad-spec`'s output changed to tag every entry. It
did not: the producer is the consumer's own `_bmad/scripts/memlog.py`, where `--by` is an OPTIONAL
per-append flag — declared at `:210`, rendered at `:170` — whose header at `:58` documents both forms
as legal, "`(idea)`, `(idea by user)`, `(by coach)`. Omit them for a plain note." ai-dlc ships no
memlog producer at all: **0** tracked paths matching `memlog` against a control of **26** matching
`spec`, so the grammar is the consumer's to vary per append and the upstream reader must tolerate
both. The stated consequence — "a permanently-DISARMED join at every story gate" — is false in the
same direction: across all four spec memlogs on the reference consumer the split is s299 **10 bare /
0 suffixed**, s301 **13 / 0**, s302 **0 / 26**, s303 **11 / 0**. One sprint in four, decided per
append. The predicate is also far older than the filing's stated 0.360.0->0.372.0 span, entering at
`a5a21a3` (v0.169.1) — `git log -S CAP_ENTRIES` over that file returns that one commit, against a
control needle known present returning 1 and an impossible needle returning 0.

**The filing's prescribed fix is under-narrow.** It accepts only ` by <author>`. Following the
producer's documented `(<type>[ <qualifier>])` grammar instead — `([[:space:]][^)]*)?` before the
closing paren — matches bare, ` by bmad-spec` and the ordinal-before-`by` shape ` 2 by lead`, and
still returns **0** on `- (event by bmad-spec)`, which is the negative control that stops the
widening from making the join vacuous.

**The "ordinal" reading of that shape is WRONG about the producer, and the correction matters
more than the claim did.** The memlog writer has no ordinal path: it emits `(<type>)`, or
`(<type> by <author>)` when the append carried an author, and nothing else. What looked like an
ordinal — `(resolution 2 by lead, adversarial pass 4 STALL, …)` — is a free-text TYPE, because the
type is whatever the caller passed. So ` by <author>` is the whole qualifier grammar, and the
reason to accept `[^)]*` anyway is not the ordinal: it is that the TYPE side is unconstrained on
the producer's side, and a predicate narrower than this would have to track its wording. The
widening is correct for a different reason than the one first given, and a receipt built on the
first reason would have been guarding a shape the producer cannot emit.

The DISARM text at `:166` should move with the predicate: it frames
the remedy as tracking a change in "bmad-spec's memlog entry types", when what is required is
tolerating a qualifier that was always legal.

**The guarding fixture certifies a shape it never had.** `core/fixtures/spec-join-integrity/seed.sh:200`
reads "REAL bmad-spec SHAPE, captured from an actual headless run" and seeded **0**
`(capability by ...)` entries against a non-zero number of bare ones. It was green under both the
broken and the widened predicate, so this was not remediated when `:164` changed — it was
remediated when that fixture seeded the suffixed form and failed without the widening.

**The "13 bare" this entry originally cited is a MENTION count, not an entry count, and the
correction is the point rather than the arithmetic.** The seed writes its corpus inside `printf`
strings, so three defensible ways of counting give three answers — 5 line-anchored bullets, 8
emitted entries, 13 occurrences of the token including comments and the two `sed` mutator
expressions. Only one of those is the population the predicate reads. The durable fact is the
ratio's numerator: **zero** qualified entries, which is why the fixture could not express the
defect, and that number does not decay.

**The mutators are themselves paren-anchored**, at `seed.sh:260` and `:268`, so a qualified arm
built by `sed`-mutating the bare corpus silently no-ops and asserts nothing. The suffixed corpora
are hand-written from the producer's output for that reason, which is `fixture-mutants.md`'s
"never seed from what the reader accepts" arriving by a second route.

**Why the receipt is the receipt, and why the two-run one it REPLACES had to go.** The original
drove the shipping script twice — bare and suffixed — and closed on `[ "$s" -ne 2 ]`. That accepts
every exit code except 2, and **both destructive remedies reach one**: deleting the `exit 2` at
`:167`, and deleting the `CAP_ENTRIES` predicate outright, each leave the suffixed run falling
through to join (1) and failing there at **rc 1**, which the receipt scored as FIXED. A fix that
removes the guard is not a fix, and that is the same false close that shipped once already. Driven
across seven variants, each asserted to differ from baseline before any verdict was read.

The replacement drives five corpora and pins **exact** codes rather than an inequality. `noncap`
(`(event by ...)` only) must still DISARM at **2** — that is the arm that kills both destructive
remedies and also kills a widening gone vacuous, since `\([^)]*\)` without the leading
`[[:space:]]` swallows `(event ...)` and drives `noncap` to 0. `sever` (a qualified capability
entry present, the locked requirement uncited) must reach **1**, which proves the widened entries
actually FEED the join instead of merely satisfying the emptiness test at `:165`. `ord`
(`(capability 2 by lead)`) must reach **0**, and it is what discriminates this entry's fix from the
filing's under-narrow ` by <author>` — the narrow form leaves `ord` at 2 and the receipt correctly
stays STILL-LIVE. `bare` remains the sanity arm at exit 9, the safe direction but not a distinct
status. Proven both ways in one invocation with the two sides asserted to differ: **0** against the
widened predicate, **1** against the pre-fix copy.

Discharges the consumer entry `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX` at LIVE ledger
line 4357, past the 4356-line pin. That entry carries no `verify:` receipt of its own and is
invisible to the consumer's closer.

verify: sh D=$(mktemp -d); mkdir -p "$D/bare" "$D/suf" "$D/ord" "$D/noncap" "$D/sever"; printf "# PRD\n\n- FR-S1-1 the functional requirement, CAP-1\n- LR-S1-1 the locked requirement\n" > "$D/prd.md"; for k in bare suf ord noncap sever; do printf "# SPEC\n\nCAP-1 the capability\n" > "$D/$k/SPEC.md"; done; printf -- "- (capability) LR-S1-1 -> CAP-1\n" > "$D/bare/.memlog.md"; printf -- "- (capability by bmad-spec) LR-S1-1 -> CAP-1\n" > "$D/suf/.memlog.md"; printf -- "- (capability 2 by lead) LR-S1-1 -> CAP-1\n" > "$D/ord/.memlog.md"; printf -- "- (event by bmad-spec) LR-S1-1 -> CAP-1 verified\n" > "$D/noncap/.memlog.md"; printf -- "- (capability by pm-escalated) CAP-1 stands alone\n- (event by bmad-spec) LR-S1-1 -> CAP-1 verified\n" > "$D/sever/.memlog.md"; for k in suf ord noncap sever; do cmp -s "$D/bare/.memlog.md" "$D/$k/.memlog.md" && { rm -rf "$D"; exit 9; }; done; r(){ bash core/scripts/validate-spec-join.sh --spec "$1" --prd "$D/prd.md" >/dev/null 2>&1; echo $?; }; b=$(r "$D/bare"); s=$(r "$D/suf"); o=$(r "$D/ord"); n=$(r "$D/noncap"); v=$(r "$D/sever"); rm -rf "$D"; [ "$b" -eq 0 ] || exit 9; [ "$n" -eq 2 ] && [ "$v" -eq 1 ] && [ "$s" -eq 0 ] && [ "$o" -eq 0 ]

## BL-056

**LANDED (v0.379.0, verified 944085a1).** Fixed WIDER than filed: all four legacy path sites in
`core/ci-templates/validate-retro-compliance.yml` migrated, plus a fifth coupled site no filing
named — the sprint extraction, which read the number from the BASENAME while the migrated shape
carries it in a DIRECTORY component, so a path-only migration produced a workflow with zero legacy
sites that fired, filtered, and then skipped every step green. An empty extraction over a non-empty
changed-set is now a hard failure, guarded by arm A7 of the new `retro-compliance-workflow`
fixture. The invocation also declares `--require-skill bmad-party-mode` so the step does not depend
solely on a regex in another file. Two further callers corrected: `steps/retro.md` prescribed the
validator with no argument while telling the reader it "MUST exit 0" (measured rc=2), and
`templates/pr-classes.md` passed a directory (rc=1). The receipt was REPLACED — its arm 1 was an
unconditional exit on a substring, satisfied by a comment and by the flag placed BEFORE the path
(which makes the invocation exit 2 on every PR), while REJECTING a correct fix with the path
hoisted into a variable.

**The one shipped flagless call to `validate-provenance-block.sh` hands it a path its retro
classifier does not match, so the retro-provenance CI step reports OK on a retro doc carrying no
provenance block at all.** `core/ci-templates/validate-retro-compliance.yml:83` runs
`./scripts/ai-dlc/validate-provenance-block.sh "docs/retro/sprint-${sprint}.md"` with no
`--require-skill`. `core/scripts/validate-provenance-block.sh:411` is
`RETRO_PATH_RE = re.compile(r"docs/retro/s\d+/retro\.md$")`, so `is_retro` at `:424` is false for
the path the template builds, no flag was passed, and the `if not blocks` arm at `:430` prints
`OK: no provenance block required or present` and exits 0. Measured on a blockless file at that
path: **rc=0**; control in the same invocation, the identical file with
`--require-skill bmad-party-mode`, **rc=1**. Three sibling path shapes were tried alongside
(`docs/retros/sprint-303.md`, `_bmad-output/retro/sprint-303.md`, `docs/retro/retro-303.md`), all
rc=0, so the pass is the classifier missing rather than one malformed probe path.

**The filing describes a different mechanism.** It frames this as a default-direction defect —
"a safety-relevant validator that fails open by default rather than requiring an explicit
`--allow-missing`-style opt-out" — demonstrated on `/etc/hosts`. That default is deliberate and
documented: the header states the artifact is "handed ONE artifact by a gate that already decided
the artifact is in scope", the requirement is the caller's to declare, and `--strays` exists as
the corpus-wide floor under exactly that carve-out. The correction runs in both directions at
once — **narrower in cause** (not the default, but one caller that declares nothing and one path
regex that misses it) and **wider in consequence** (not a hypothetical on `/etc/hosts`, but the
shipped retro compliance workflow, which `scripts/install.sh:564-566` copies into a consumer's
`.github/workflows/`).

**Both of the validator's own same-run probes pass and neither can see this.** `:412` asserts the
regex matches `docs/retro/s301/retro.md` and `:418` asserts it refuses `docs/retro/s301/retro-draft.md`
— written, correctly, against the migrated path form. `core/scripts/migrate-artifact-paths.sh:192`
records that form as the migration target of `docs/retro/sprint-299.md`, so the template is on the
pre-migration shape and the probes are on the post-migration one, with nothing joining them. The
same staleness disarms the workflow twice: its `paths:` trigger at `:19` and its changed-set filter
at `:46` are both `docs/retro/sprint-*.md`, so on a migrated consumer the job does not fire at all.

The receipt is a three-armed join rather than a grep, because either side is a legitimate fix and
a one-sided anchor would go unsatisfiable when the other is chosen: it exits 0 if the template's
invocation gains `--require-skill`, or if the template stops constructing the legacy
`docs/retro/sprint-` form, and otherwise requires the validator to refuse a blockless doc at the
path the template actually builds. An empty grep of the template — the invocation removed entirely
— holds the entry open rather than closing it, since a deleted check is not a repaired one.

Discharges the consumer entry `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` at pinned ledger
line 1136.


verify: sh python3 scripts/verify-backlog-bl056.py "$PWD"
## BL-060

**LANDED (v0.379.0, verified 944085a1).** Fixed in both directions, of which the filing named one.
The single writer of `rel` now canonicalises to a root-relative realpath form, closing the filed
false-STRAY spellings (absolute, `/private`, doubled-slash, symlinked parent) and the FALSE PASS the
filing did not name — a genuine stray reached through a home prefix, `docs/retro/../../server/x`,
which was opened, read, and then excused because `match_home` compared raw strings. Normalisation
could not reach the zero-candidate class, so an explicit argument that does not resolve now exits 2;
and an independent fixture hand found that guard incomplete on the member its own comment claimed it
closed, since `[ -e ]` FOLLOWS a symlink while `grep -rlI` does not descend one it was handed, so
explicit arguments are resolved to their physical path first. The HOME pattern is canonicalised too:
four legitimate consumer spellings of a real home matched NOTHING in silence, reporting the
consumer's own files as strays. The default whole-tree scan's output is byte-identical throughout.
The receipt was REPLACED — its negative control was spelled relatively, so nothing required an
ABSOLUTE stray to still be refused, and both remedies making `--strays` blind to absolute paths
scored as FIXED. Case-variant spellings are filed separately as `BL-082`; every remedy that closes
them opens a false PASS on a case-sensitive consumer.

**`validate-provenance-block.sh --strays` judges the declared homes on the path SPELLING, so the
same file passed as an absolute path is reported as an out-of-place stray.** The explicit-path
branch at `core/scripts/validate-provenance-block.sh:184-188` sets `STRAY_DEFAULT=0` and hands the
caller's paths to `grep -rlI` verbatim; only the DEFAULT whole-tree branch normalizes, by forcing
`STRAY_PATHS=(".")` at `:177` under a comment at `:176` that states the mechanism — *"an absolute
scan root would make every path miss every home"* — in the one branch where it cannot bite.
Reproduced on a sandbox root, one file, same validator, three invocations: `--strays
docs/retro/probe.md` (a declared home) exits **0**, `--strays: PASS`; `--strays
"$P/docs/retro/probe.md"` exits **1**, `STRAY PARTY-MODE PROVENANCE: /var/…/docs/retro/probe.md
[reason:out-of-place-party-mode]`. Control in the same invocation: `--strays server/stray.md`, a
genuine non-home spelled relatively, exits **1** — so the scan fires on a real finding and the
passing arm is not a dead scan.

**The filing measured this on the CONSUMER's installed copy; the subject is core's.** It reproduces
in the distribution copy, upstream of every install, so the repro needs no consumer tree and no
`$CONSUMER` variable. That matters because the filing's own receipt has already been re-anchored
once, on 2026-08-14, when its subject `docs/retro/sprint-249.md` moved to `docs/retro/s249/retro.md`
and the `&&` chain began short-circuiting on a missing file. Direction: same cause, moved one tree
up and off a moving subject. The filing's two self-corrections both hold as written — the comment
placement at `:176` and the silence of the explicit-path branch are exactly as it describes.

**Scope is narrower than the entry reads, and that belongs in the record.** The shipped gate is not
affected: `core/git-hooks/pre-push:109` invokes `--strays` with no paths, which takes the
normalizing default branch. The exposure is every caller that passes an explicit path, and nothing
guards it — `core/fixtures/stray-party-mode-provenance/run.sh` carries **6** occurrences of
`--strays` and **0** of `PWD` or `absolute`, so the fixture that owns this validator's tree
behaviour has no arm for the case at all.

**Why a behavioural probe and why it is built from the schema.** The sandbox root's block is
assembled from `envelope.open`, `envelope.close` and `stray_scan.party_mode_skills[0]` read out of
`core/schemas/provenance-block.json`, so the receipt restates no grammar and — the reason this is
not optional — `docs/backlog.md` carries no literal envelope marker. Writing one here would make
the backlog itself a subject of the whole-tree scan this entry is about, which is the v0.194.0
lesson `core/fixtures/stray-party-mode-provenance/seed.sh:40-43` already records. The relative-home
arm doubles as the proof that the target state is reachable: the same file, same validator, exits 0
when the path is spelled relatively, so normalizing an absolute argument in the explicit-path branch
closes this receipt. A substring anchor would false-close on the fix's own comment, which will quote
the absolute-path wording back.

Discharges the consumer entry `PC-S312-STRAYS-DOES-NOT-NORMALIZE-AN-ABSOLUTE-PATH` at pinned ledger
line 2492.


verify: sh D=$(mktemp -d); P="$D/proj"; mkdir -p "$P/.claude/schemas" "$P/docs/retro" "$P/server"; cp core/schemas/provenance-block.json "$P/.claude/schemas/"; python3 -c "import json,sys;S=json.load(open(sys.argv[1]));e=S['envelope'];b=(e['open']+chr(10)+'skill: '+S['stray_scan']['party_mode_skills'][0]+chr(10)+'invoked_at: 2026-07-28T09:00:00Z'+chr(10)+'mode: subagent'+chr(10)+e['close']+chr(10));open(sys.argv[2],'w').write(b);open(sys.argv[3],'w').write(b)" "$P/.claude/schemas/provenance-block.json" "$P/docs/retro/probe.md" "$P/server/stray.md"; V=$(grep -ls -- '--strays' core/scripts/*.sh 2>/dev/null | xargs -I{} grep -ls 'party_mode_skills' {} 2>/dev/null | head -1); [ -n "$V" ] || { rm -rf "$D"; exit 1; }; V="$PWD/$V"; AI_DLC_PROJECT_ROOT="$P" bash "$V" --strays docs/retro/probe.md >/dev/null 2>&1; R1=$?; AI_DLC_PROJECT_ROOT="$P" bash "$V" --strays server/stray.md >/dev/null 2>&1; R2=$?; AI_DLC_PROJECT_ROOT="$P" bash "$V" --strays "$P/docs/retro/probe.md" >/dev/null 2>&1; R3=$?; AI_DLC_PROJECT_ROOT="$P" bash "$V" --strays "$P/server/stray.md" >/dev/null 2>&1; R4=$?; rm -rf "$D"; [ "$R1" = 0 ] && [ "$R2" = 1 ] && [ "$R3" = 0 ] && [ "$R4" = 1 ]
## BL-073

**LANDED (v0.380.0, verified 5b1fea28).** The `|| echo 0` / `|| echo ""` fallbacks are gone from
all five reads in `core/hooks/ai-dlc-subagent-probe.sh`; the fix is the subtractive one `BL-036`
shipped. The receipt reports `CLOSE-CANDIDATE` against an impossible-id control of 0.

**THIS ENTRY'S OWN RECEIPT WOULD HAVE REJECTED A CORRECT FIX, AND IT CLOSES ONLY BECAUSE THE
SHIPPED REMEDY HAPPENS TO KEEP ITS SHAPE.** It requires exactly three lines matching
`^\s*(PEAK|TURNS|COMPACTIONS)=.*jq`, so the literal token `jq ` must sit on a line beginning with
the variable name. An independent hand drove four ordinary refactors that are behaviourally
correct — the fixture passes each at rc=0 and `BL-084`'s behavioural receipt accepts each at 0 —
and **every one exits 9**: hoisting the reads into a `probe_field()` helper; a pure reformat onto
continuation lines; `JQ="$(command -v jq)"` plus `"$JQ" -r`, which is **this repo's own `I33`
two-layout pattern**; and one `jq` call emitting all five via `@sh`. `backlog-reverify.sh:183`
reads any non-zero as `STILL-LIVE`, so exit 9 is byte-indistinguishable from "still reproduces" —
the entry would have read open forever against a correct tree.

**It is also evadable in the closing direction by one character**, and it is the only guard its
class has: `|| echo "0"`, `|| PEAK=0` on the same line, and `: "${PEAK:=0}"` on the next line all
reintroduce the exact defect and all report `CLOSE-CANDIDATE`. The first also passes the fixture.
The lesson is the one this program keeps relearning — **key on the LOCATION (an assignment
reaching a defaulting construct), never on the spelling `echo 0`.** Recorded here rather than
repaired, because the entry archives with this release and the receipt stops guarding anything
the moment it does.

**`ai-dlc-subagent-probe.sh` reads three telemetry values through the same `|| echo 0` conflation
`BL-036` was closed for, so an unparseable transcript reports as a measured zero.**
`core/hooks/ai-dlc-subagent-probe.sh:100-102` reads `peak`, `turns` and `compactions` as
`jq -r '.<field>' 2>/dev/null || echo 0`. `jq` exits non-zero on malformed input, so the fallback
fires on exactly the case it cannot distinguish: a genuine `0` and a read that FAILED produce the
identical string, and every consumer of those three values sees a number rather than an absence.
`model` and `end_ts` at `:103-104` take the same shape with `""`.

**It is a NOTE rather than a defect, and the reason is the consequence, not the mechanism.** The
mechanism is exactly `BL-036`'s — measured there across four unparseable-template classes, two of
which are VALID JSON — but these three values gate no operator question and block nothing. They
are telemetry. A wrong zero here produces a wrong number in a probe record, not a wrong verdict on
a push.

**The fix `BL-036` shipped is the one to copy and it is subtractive**: the fallback goes, rather
than a guard being placed downstream of it. A separation that makes a wrong answer unlikely is not
one that makes it unconstructible, and a downstream check for a literal integer closes only the
0-byte case — measured in that release, which is why the narrower fix was built first and
abandoned.

The receipt keys on the three reads and carries a control: a fix that removes the fallback closes
it, and a fix that deletes the reads fails the control arm.

verify: sh H=core/hooks/ai-dlc-subagent-probe.sh; [ -f "$H" ] || exit 9; n="$(grep -cE '^[[:space:]]*(PEAK|TURNS|COMPACTIONS)=.*jq ' "$H")"; [ "$n" -eq 3 ] 2>/dev/null || exit 9; b="$(grep -E '^[[:space:]]*(PEAK|TURNS|COMPACTIONS)=.*jq ' "$H" | grep -c 'echo 0')"; [ "$b" -eq 0 ]

## BL-084

**LANDED (v0.380.0, verified 5b1fea28).** Both read sites in
`core/hooks/ai-dlc-subagent-probe.sh` now resolve the teammate's own transcript at
`<slug>/<session-uuid>/subagents/agent-<agent_id>.jsonl`, absent means no row, and the row stamp
is `v:2`. The receipt reports `CLOSE-CANDIDATE` against an impossible-id control of 0. The gate
was run the way the hook runs it — exit 0 read directly, 15 of 15 phases PASS, 161 fixtures ok /
0 FAIL, `subagent-probe` read BY NAME against an impossible-name control of 0 in the same
invocation — and the merged tree is byte-identical to the gated one.

**THREE INDEPENDENT HANDS WERE PUT ON SCOPE, FIXTURE AND RECEIPT, AND TWO FOUND DEFECTS IN WORK
ALREADY COMMITTED.** The fixture's one arm covering "teammate transcript missing" was reading the
PREVIOUS fire's file, because `fire()` skipped the copy when a seed was absent but never removed
what an earlier fire left under the same `agent_id` — so a hook mutated to fall silently BACK to
the lead transcript produced output **byte-identical** to the fixed hook's across the whole
fixture. And two claims this branch had already committed were false: the header's assertion that
true teammate peaks sit well below the threshold and true `compactions` is zero (32 of 1086 exceed
it, 16 compacted, max 372633), and `99.1%` for lead-arm agreement (95.9%, 1248 of 1301). Both are
retracted in place rather than quietly corrected.

**The fix also narrows the population, and that is declared in the hook rather than left to be
discovered.** From `v:2` the file records NAMED teammates; bare unnamed spawns resolve 40 of 646
against 557 of 557 named, with reaping controlled for.

**`ai-dlc-subagent-probe.sh` derived every teammate field from the LEAD's transcript, so the one
instrument in the pipeline built to see inside a teammate never measured one.**
`.transcript_path` at `SubagentStop` is the lead's session file, and BOTH read sites took from it —
the bounded tail read and the bounded head read — so `peak_tokens`, `turns`, `compactions`,
`model`, `end_ts`, `duration_s` and the `role` fallback were all the lead's, from the day each
field shipped. The teammate's own transcript exists one level down, at
`<project-slug>/<session-uuid>/subagents/agent-<agent_id>.jsonl`.

**Three independent proofs, each with its control in the same invocation.** The implied starts
(`ts − duration_s`) for one sprint collapse onto THREE values, and those three are that sprint's
three harness sessions, 48 rows sharing one minute — against a control of 118 distinct `ts`
minutes over the same 145 rows, so the collapse is in the derived value and not in the sampling.
Nine stop-seconds carry more than one record and EIGHT of the nine are byte-identical on
`peak_tokens|turns|compactions|model` across distinct agents, against a control of `agent_id`
distinct in 9 of 9. And the probe's `model` matches the LEAD's own recorded arm on **95.9%** of
rows (1248 of 1301), against a control with the lead's arm flipped at 4.1%.

**Measured against teammates' own transcripts, eight rows, every field was wrong**: peak
over-reported 25–160% (381571 recorded against a true 147024), `model` wrong on 7 of 8 — every one
an opus teammate recorded as sonnet — `compactions` reporting 1 where the truth is 0, duration
inflated 16–40×. Corpus-wide the probe's `model` agrees with the teammate's true arm on **41.2%**
of rows against **89.1%** for the dispatch guard's `model_bound` (630 of 707 rows that resolve to
a teammate transcript): below chance on a two-class problem where opus is the majority.

**This voided the instrument's own purpose, and the shape of the wrongness is what hid it.** The
hook exists to answer *"how close do teammates get to the threshold, and do any of them
compact"* — the open question under `autoCompactWindow`, where the alternative is paying a
measured ~19% bill increase for an unquantified benefit. Its recorded peak MAXIMUM exceeds the
threshold it is read against, which is the lead crossing its own ceiling. A number that is too large in the
direction the reader is worried about reads as the instrument working.

**The true teammate distribution is now derivable, and it is not what an earlier draft of this
entry and of the hook header both asserted.** Both said teammate peaks sit well below the
threshold and true `compactions` is zero, generalised from the eight rows above. Scanned over the
whole teammate corpus with the hook's own predicates, 1086 files: **32 exceed the 287000 threshold
and 16 actually compacted**, 17 boundary records, max teammate peak **372633** — above it. Control
in the same scan: one teammate reads peak 0, so the scan can return a zero; an independent raw grep
finds the boundary token in 18 files. The `autoCompactWindow` question is therefore still open and
answerable, which it was not while the field beneath it emitted the lead's numbers.

**It never worked, so there is no era of the record that is sound.** The earliest day in the
reference consumer's corpus already reads 100% of runs over 900s. The header's own calibration
(`10% of runs, ~47% of agent-hours`) was not stale but UNREPRODUCIBLE from any point in the
record — a sound measurement taken by a different method and orphaned onto a column that did not
exist when it was taken, which read as confirmation for a month.

**The fixture certified exactly the assumption the hook violated, and could never have fired.**
`core/fixtures/subagent-probe/run.sh` handed the hook a teammate-shaped transcript DIRECTLY, a
layout that does not occur in production, so its `duration_s` assertion was green for the whole
life of the defect. This is the `check that cannot fire` class, sited inside the only guard the
subject had.

**Filed with the release that fixes it, deliberately.** The defect was found by an investigation
rather than by a filing, so no entry existed to carry it; the archive is where this repo's
record of a found-and-fixed defect lives, and an id in the archive is what a later reader and the
`CHANGELOG` can both cite. The value of the entry is the receipt below — but read what it
actually asserts: `peak_tokens` provenance and the no-row contract, not every field. **The full
regression guard is `core/fixtures/subagent-probe/run.sh`, not this receipt**, and an independent
hand established the difference by driving a one-line mutant that restores the headline defect on
the HEAD read: the receipt accepts it, the fixture fails it and names the value it got. Cite the
fixture where you need coverage and this receipt only for the close.

**The receipt drives the shipping hook rather than reading it, and it is two-armed on purpose.**
Arm 1 gives the hook a real two-file layout where the lead file carries a peak no teammate reaches
and asserts the emitted row carries the TEAMMATE's number; arm 2 fires the same hook for a
teammate whose transcript is ABSENT and asserts NO row is written. The pre-fix hook fails both —
it reports the lead's peak, and it writes a row for a teammate that left no transcript. Proven
five ways before filing: the fixed hook **0**, the real pre-fix hook from `origin/main` **1**, an
`exit 0` stub **1** (arm 1 is presence-shaped, so silence cannot close it), a mutant that resolves
the teammate path correctly but falls BACK to the lead when it is absent **1**, and an absent
subject **9**.

verify: sh H=core/hooks/ai-dlc-subagent-probe.sh; [ -f "$H" ] || exit 9; command -v jq >/dev/null 2>&1 || exit 9; D=$(mktemp -d) || exit 9; mkdir -p "$D/_bmad-output" "$D/lead/subagents" || { rm -rf "$D"; exit 9; }; : > "$D/_bmad-output/pipeline-snapshot.md"; printf '%s\n' '{"type":"assistant","timestamp":"2026-01-01T00:00:00Z","message":{"model":"lead","usage":{"input_tokens":999999}}}' > "$D/lead.jsonl"; printf '%s\n' '{"type":"assistant","timestamp":"2026-01-01T00:00:10Z","message":{"model":"mate","usage":{"input_tokens":123}}}' > "$D/lead/subagents/agent-mate1.jsonl"; O="$D/_bmad-output/subagent-context.jsonl"; printf '{"transcript_path":"%s","agent_id":"mate1"}' "$D/lead.jsonl" | CLAUDE_PROJECT_DIR="$D" AI_DLC_STATE_DIR=_bmad-output bash "$H" >/dev/null 2>&1; p=$(jq -r '.peak_tokens' "$O" 2>/dev/null | tail -1); n1=$(wc -l < "$O" 2>/dev/null | tr -d ' '); printf '{"transcript_path":"%s","agent_id":"no-such-teammate"}' "$D/lead.jsonl" | CLAUDE_PROJECT_DIR="$D" AI_DLC_STATE_DIR=_bmad-output bash "$H" >/dev/null 2>&1; n2=$(wc -l < "$O" 2>/dev/null | tr -d ' '); rm -rf "$D"; [ "${n1:-0}" = 1 ] && [ "${p:-}" = 123 ] && [ "${n2:-0}" = 1 ]
## BL-084 — two unshared encodings of the container set, currently agreeing

**LANDED (v0.389.0, verified 9b939ff7).** The trigger fired as filed: the indentation fix
touched both folds, so the spine fold was routed through `CONTAINER` first. The receipt
anchored on the call-site count of the shared predicate, which is now 4. Two things the entry
did not anticipate. The unconditional terminators must be tested BEFORE the container test,
because `CONTAINER` carries `>` and `|` and the more-indented rule would otherwise turn a
blockquote or a table row into a CONTINUATION — the false-BIND direction, at rc=0. And the
seven containers the entry measured were measured by hand: none of them existed as seeds, so
the fixture was blind to the reroute by construction and four had to be added, three that must
terminate and one that must continue.

`core/scripts/validate-spec-join.sh` has ONE container definition on the kernel side —
`CONTAINER` in `CAP_DECL_AWK`, consumed by the fold terminator and the leading test. The
SPINE fold carries its own container handling and does not use it. That is a second,
unshared encoding of the same markdown fact.

**It is correct today, and that is the whole problem.** Measured across seven containers by
the adversarial pass that found it: a `- **Binds:** CAP-1` bullet followed by a line naming
two capabilities in a numbered item, a `+` bullet, a blockquote, a table row and a thematic
break all TERMINATE the fold and leave both capabilities correctly unbound; only a plain
prose line absorbs, which is the accepted W2 limit. The spine fold is in fact more complete
than the kernel's was.

The reason to unify anyway is the base rate. In v0.388.0 this exact class — one markdown
fact written N times, no two copies agreeing — produced four defects, and every one was
created by REPAIRING ONE COPY AND NOT THE OTHER: BLOCKER 35, 39 and 41 were each introduced
by the fix for the one before it, and three of the four were silent drops of a real
capability that the fixture could not see.

**TRIGGER, and it is the point of this entry: WHEN EITHER FOLD IS NEXT EDITED, UNIFY THEM
FIRST.** An undated intention decays; a precondition on the next edit fires exactly when the
risk becomes real, on the author who is already in the file. The seven measured rows above
mean whoever trips it inherits a passing baseline rather than having to establish one.

**The reader is deliberately NOT in the set and must stay out**, and the reasoning belongs
with it as a rule rather than as an exemption: `CONTAINER` encodes a MARKDOWN FACT — what
starts a block-level item — true regardless of who wrote the file. The reader's `[-*]`
encodes a PRODUCER CONTRACT — what `bmad-spec` emits — true only while it emits it. Two
kinds of knowledge that go stale on different schedules must not share a definition. Folding
the reader in would flip eleven loud DISARMs into eleven quiet reads, which is the opposite
of what that arm exists for.

Anchored on the number of CALL SITES of the shared predicate, not on the shared definition
itself — the definition already exists, so a receipt keyed on it reads as fixed the moment
this entry is filed. Today `container_start(` occurs twice: one definition and one call,
from the kernel fold. A fix that routes the spine fold through it makes that three.

verify: sh test "$(grep -c 'container_start(' core/scripts/validate-spec-join.sh)" -ge 3

---

## BL-079

**`validate-spec-join.sh`'s join (1) reads its locked-requirement population with a whole-file
scan of the memlog, while the capability predicate three lines below it is deliberately
restricted to typed entries — with a comment refusing to read the spec's own self-report as
evidence. The LR side reads that same self-report as its population.** The scan is
`LRS="$(grep -ohE '\bLR-[A-Za-z0-9]+-[0-9]+[a-z]?\b' "$MEMLOG" | sort -u)"` (re-derive the line;
it drifts). Measured on the reference consumer across all four spec memlogs: **18 join-(1)
findings, exactly 1 false** — `LR-S999-9` in s302, an absent-id CONTROL TOKEN quoted inside an
`(event by bmad-spec)` entry recording *"an id-presence sweep run with an absent-id control
(LR-S999-9) that returned zero, proving the search could return nothing"*. That is this repo's own
zero-is-not-a-finding discipline, written into a consumer's memlog and read back by a validator as
data. It appears in no `locked-requirements.md` anywhere in the tree; positive control in the same
sweep, `LR-S302-1` is present in 35 files. Genuineness of the other 17 is not a judgment call: 13
are declared in their sprint's own `planning-artifacts/<sprint>/locked-requirements.md`, and 4 are
undeterminable only because s301 ships no such file.

**This became reachable rather than newly broken, and the entry that exposed it is `BL-063`.**
Before the capability predicate was widened to accept the producer's optional qualifier, s302
returned rc 2 DISARMED — the LR scan ran and nothing downstream of it did. The widening takes s302
from **0 of 7 LR ids checked to 7 checked, 6 correct, 1 false**, which is a strict gain in
coverage, and it is why the false finding is tolerable in the interim rather than blocking.

**It is NOT fixable by symmetrizing the predicate, and that refutes the obvious patch.**
Restricting the LR side to typed entries — the symmetric change the asymmetry invites — drops
**0**: every LR occurrence in the corpus is already on a typed entry line, so the change is a
measured no-op. Four further discriminators were driven over all four sprints and every one loses
genuine declared locked requirements: excluding ids seen only in `(event)`/`(note)` entries loses
**5**; excluding `(event)`-only loses **3**; requiring a `CAP-<n>` on the same line loses **5**,
two of them already baselined, which additionally converts two suppressed findings into
did-not-reproduce failures; requiring the sprint prefix to match the spec directory loses **1**, a
declared cross-sprint carry-over this consumer demonstrably has.

**The leading candidate is a DISARM and both the seeded corpus and the fixture say so
independently.** Requiring a `CAP-<n>` on the LR's own line returns **rc 0 on a corpus carrying a
genuinely uncited locked requirement** — because an LR that reaches no capability is, in the
ordinary case, exactly an LR with no `CAP-` on any of its lines, so the candidate excludes the
primary failure mode from its own population. `mechanism-design.md`: a fix that satisfies a join by
deleting the join's subject reads as green forever. Swapped into a copy of `core/` asserted
byte-different, it turns three arms of `core/fixtures/spec-join-integrity` red — including *"join
(1): a locked requirement citing no capability FAILS"* — against a sanity control on the identical
temp-tree harness with unpatched code at 56 ok / 0 FAIL.

**No predicate can separate these two inputs, which is why this needs a design change rather than
a regex.** The absent-id control is BY CONSTRUCTION an id shaped exactly like a real one — that is
its whole purpose. Typed entry, sprint-shaped id, ordinary prose. The only thing distinguishing it
is the surrounding English, and keying a validator on prose phrasing is the failure
`verification-discipline.md` names as text-about-a-program. **The sound remedy is a DECLARED
population** — take the sprint's `locked-requirements.md` as the LR set through a new flag — and it
is blocked on two things that must be settled in the same change: s301 carries no such file, so the
flag needs SKIP semantics that do not silently pass; and the deployed baseline is a single
project-wide file measured against s299, which fires its did-not-reproduce arm **15** times when
run at s302. **So "just baseline the false positive" is not available either** — the shared
baseline cannot absorb a sprint-local entry without breaking at the other three sprints, and that
is why the interim disposition is to leave the finding reported.

**Why the receipt is the receipt.** It must reject a disarm, because every candidate remedy
measured here is one. It therefore drives the shipping script twice and requires BOTH directions in
the same invocation: a seeded memlog carrying a genuinely uncited locked requirement must still
exit 1, AND the absent-id control token must stop being reported. A remedy satisfying only the
second is the disarm above, and it is the shape a narrowing naturally takes. The seeded arm is
built at run time rather than lifted from the consumer, so the receipt carries no dependency on a
tree outside this repo. Tier: **DEFECT** — one false finding today on a gate the consumer already
records as failing, against a coverage gain that is strictly larger.

**LANDED (v0.415.0, verified 2b474ad2).** `--locked-requirements` declares join (1)'s
population; the memlog scan remains as the documented fallback. Three things in this entry were
re-derived and did not hold. **Its own `verify:` receipt was EXPIRED** — the seeded `SPEC.md`
used a capability grammar the validator now DISARMs, so both arms returned 2 and the receipt
exited 9 against every implementation including a correct one; it is replaced. **The population
is six memlogs, not four**, and the partition is 12 declared / 5 from the sprint shipping no
declarations file / 1 false. **The shared baseline this entry names as a blocker does not exist
and is not tracked in that consumer**, so the did-not-reproduce hazard it describes is not live.

**Two of the entry's own prescriptions were NOT delivered, and that is a substitution rather
than a satisfied precondition.** What shipped is a FALLBACK, not SKIP semantics: a sprint with
no declarations file omits the flag and keeps the memlog scan, so it keeps both its findings and
its exposure to this defect. And the false positive dying does not turn that gate green — run
the way the consumer's own gate log records the invocation, a join (2a) spine finding survives,
byte-identical either way.

**The declared population also ADDS ids a memlog scan structurally could not see**: a locked
requirement absent from the memlog entirely. Two live instances, and they are different
defects — one is an operator-locked item appearing in no spec file at all, the other is mapped
to a capability in the spec's own prose and never journalled. Both report as `note` by operator
ruling, because failing the second reddens a gate that is green today on a requirement the spec
demonstrably reaches.

**`I97` is the carrier for the single-source decision** and it exists because the first cut
violated it: a hand-rolled marker pair read 2 of the grammar's 6 measured spellings.
`validate-locked-anchor.sh --emit-blocks` is the owner and this is its third caller.


verify: sh V=core/scripts/validate-spec-join.sh; A="$(dirname "$V")/validate-locked-anchor.sh"; { [ -r "$V" ] && [ -r "$A" ]; } || exit 9; D=$(mktemp -d) || exit 9; X(){ rm -rf "$D"; exit "$1"; }; mkdir -p "$D/a" "$D/b" || X 9; printf '%s\n' '# PRD' '' '- **FR-S1-1 (CAP-1)** the functional requirement' > "$D/prd.md"; printf '%s\n' '# SPEC' '' '- **CAP-1** the capability' > "$D/a/SPEC.md"; cp "$D/a/SPEC.md" "$D/b/SPEC.md" || X 9; printf '%s\n' '- (capability by bmad-spec) LR-S1-1 -> CAP-1' '- (event by bmad-spec) an id-presence sweep run with an absent-id control (LR-S999-9) that returned zero' '- (constraint by bmad-spec) LR-S1-9 is a Tier 2 addendum, recorded below the locked block' > "$D/a/.memlog.md"; printf '%s\n' '- (capability by bmad-spec) LR-S1-1 -> CAP-1' '- (constraint by bmad-spec) LR-S1-2 is locked and reaches no capability' > "$D/b/.memlog.md"; L1='- **LR-S1-1** the locked requirement'; L5='- **LR-S1-5** locked and never journalled'; L9='- **LR-S1-9** the Tier 2 addendum'; printf '%s\n' '<!-- LOCKED_REQUIREMENTS -->' "$L1" "$L5" '<!-- END S1 LOCKED_REQUIREMENTS -->' "$L9" > "$D/a/narrow.md"; printf '%s\n' '<!-- LOCKED_REQUIREMENTS -->' "$L1" "$L5" "$L9" '<!-- END S1 LOCKED_REQUIREMENTS -->' > "$D/a/wide.md"; printf '%s\n' '<!-- LOCKED_REQUIREMENTS_BEGIN -->' "$L1" "$L5" '<!-- LOCKED_REQUIREMENTS_END -->' "$L9" > "$D/a/exotic.md"; printf '%s\n' '<!-- LOCKED_REQUIREMENTS -->' "$L1" "$L9" > "$D/a/dangling.md"; printf '%s\n' '<!-- LOCKED_REQUIREMENTS -->' 'no requirements were locked this sprint' '<!-- END LOCKED_REQUIREMENTS -->' > "$D/a/empty.md"; printf '%s\n' '<!-- LOCKED_REQUIREMENTS -->' "$L1" '- **LR-S1-2** locked and reaching no capability' '<!-- END LOCKED_REQUIREMENTS -->' > "$D/b/locked.md"; ab=$(bash "$A" "$D/a/narrow.md" --emit-blocks 2>/dev/null); rab=$?; { [ "$rab" -eq 0 ] && grep -qF 'LR-S1-1' <<<"$ab" && ! grep -qF 'LR-S1-9' <<<"$ab"; } || X 9; cmp -s "$D/a/narrow.md" "$D/a/wide.md" && X 9; [ "$(sort "$D/a/narrow.md")" = "$(sort "$D/a/wide.md")" ] || X 9; cmp -s "$D/a/narrow.md" "$D/a/exotic.md" && X 9; [ "$(grep -v '<!--' "$D/a/narrow.md")" = "$(grep -v '<!--' "$D/a/exotic.md")" ] || X 9; cmp -s "$D/a/.memlog.md" "$D/b/.memlog.md" && X 9; on=$(bash "$V" --spec "$D/a" --prd "$D/prd.md" 2>&1); rn=$?; { [ "$rn" -eq 1 ] && grep -qF 'LR-S999-9' <<<"$on"; } || X 9; oa=$(bash "$V" --spec "$D/a" --prd "$D/prd.md" --locked-requirements "$D/a/narrow.md" 2>&1); ra=$?; ow=$(bash "$V" --spec "$D/a" --prd "$D/prd.md" --locked-requirements "$D/a/wide.md" 2>&1); rw=$?; og=$(bash "$V" --spec "$D/a" --prd "$D/prd.md" --locked-requirements "$D/a/exotic.md" 2>&1); rg=$?; ob=$(bash "$V" --spec "$D/b" --prd "$D/prd.md" --locked-requirements "$D/b/locked.md" 2>&1); rb=$?; bash "$V" --spec "$D/a" --prd "$D/prd.md" --locked-requirements "$D/a/empty.md" >/dev/null 2>&1; re=$?; bash "$V" --spec "$D/a" --prd "$D/prd.md" --locked-requirements "$D/a/dangling.md" >/dev/null 2>&1; rd=$?; [ "$oa" != "$on" ] || X 1; [ "$ra" -eq 0 ] || X 1; grep -qF 'LR-S999-9' <<<"$oa" && X 1; grep -qF 'LR-S1-9' <<<"$oa" && X 1; grep -qF 'LR-S1-5' <<<"$oa" || X 1; [ "$rg" -eq 0 ] || X 1; grep -qF 'LR-S1-9' <<<"$og" && X 1; [ "$rw" -eq 1 ] || X 1; grep -qF 'LR-S1-9' <<<"$ow" || X 1; [ "$rb" -eq 1 ] || X 1; grep -qF 'LR-S1-2' <<<"$ob" || X 1; [ "$re" -eq 2 ] || X 1; [ "$rd" -eq 2 ] || X 1; X 0

## BL-076

**LANDED (v0.416.0, verified 727ddc6c).**

**Five sibling validators report how MANY files they read and never WHICH, so a run over the
wrong corpus is byte-identical to a run over the right one — the same defect `BL-059` fixed in
`validate-steering-budget.sh`, in `validate-ci-gates.sh`, `validate-ac-falsifiability.sh`,
`validate-scope-confirmation.sh`, `validate-spec-join.sh` and
`validate-suppression-lifetime.sh`.** Each takes its corpus from the caller — an argv flag, a
positional, or an `AI_DLC_*` env override — and each prints the corpus identity at exactly one
site, on a path a successful run never reaches.

**The population is derived, and it is FIVE, not the three the sweep was opened on.** 86 tracked
files across `core/scripts`, `core/hooks`, `core/git-hooks`, `scripts` and `.githooks`; 68 lines
in 23 of them emit a count over a named noun, and the control that the grammar can see its own
subjects is that all three originally-suspected validators appear in that set. Narrowing clause 1
— the corpus comes from the CALLER — leaves 12 files with an argv case-arm assigning from `$2`, a
positional collector, or an `AI_DLC_*` override; a count over a DERIVED or FIXED corpus is a
different thing and is not this defect. Narrowing clause 2 — the resolved corpus is emitted
NOWHERE on a success path — leaves five. The seven that fall out fall out for the right reason
and are the enumerated false-positive set: `validate-spawn-ledger.sh` prints
`COUNTS: examined N ... in ${LEDGER}`, `rotate-snapshot-archive.sh` and `backlog-rotate.sh` name
their archive and ledger, and `validate-artifact-paths.sh` and `migrate-artifact-paths.sh` print a
resolved root, grammar and scan-root list above their counts. Those are the convention, not the
defect.

**Measured, each driven twice over two `mktemp -d` corpora holding identical content, with a
control token in the same invocation.** `validate-scope-confirmation.sh`: rc 0 both runs, output
byte-identical, `answers_entries_scanned` present **1** time and either corpus path present **0**
times. `validate-ci-gates.sh`: rc 0 both runs, byte-identical across two different retro trees AND
two different enforcement surfaces, `Scanned` present 1 time, neither tree named — and
`ALIAS_TABLE_FILE` is emitted **0** times anywhere in the file against a control of **1** for
`RETRO_DIR`. `validate-ac-falsifiability.sh`: rc 0 both runs, byte-identical, `term(s) loaded`
present 1 time, neither the lexicon nor the story file named. `validate-spec-join.sh`: rc 0 both
runs, byte-identical, `PASS` present 1 time, no corpus named.
`validate-suppression-lifetime.sh`: rc 0 both runs, byte-identical.

**Rank them on what a wrong corpus BUYS, because all five are enforcement-map rows and tiering
them by "feeds a gate" collapses the set into one register.** The discriminator is whether the
wrong corpus fails loud or passes clean, and it was measured in both directions.

**`validate-ci-gates.sh` is worse than `BL-059`, and it is the only one of the five for which
that is true.** A retro tree that EXISTS and holds no gate declarations turns a real finding into
a clean pass: same enforcement surface, right root → **rc 1**, `1 gates declared, 1 dormant`;
wrong root → **rc 0**, `0 gates declared, 0 dormant`. Both roots are consumer-tunable by design
and the file's own comment says so, the verdict ships to a consumer's CI through
`core/ci-templates/validate-ci-gates.yml`, and the line reporting the pass names neither tree. The
one place `RETRO_DIR` IS printed is the branch where the directory does not exist — the case a
reader could already diagnose.

`validate-ac-falsifiability.sh` is second and fails open the same way through its lexicon. A story
whose AC states its predicate with `exhaustive` — the first term in the live `AC_UNBOUNDED_TERMS`
block — is **rc 1 FAIL** against the real lexicon and **rc 0 PASS** against a readable two-term
file passed to `--lexicon-from`, and the PASS line reports `2 term(s) loaded` without saying from
where. Its DISARMED guard names the lexicon and catches only the ZERO-term case; a wrong lexicon
with any terms in it walks straight past.

`validate-scope-confirmation.sh` is third, and the framing this arrived under — "arguably worse
than BL-059, it feeds a routing verdict" — does not survive checking. It does not FEED routing; it
adjudicates a routing record already written, and both its FAILING directions already name their
corpus. What is unnamed is the PASS — the run that certifies a human pause point happened. A
`--answers` pointed at another sprint's capture history that happens to carry the cited digest
passes silently, and the file's own header states the principle its emission half-implements: a
run that scanned nothing and a run that scanned forty healthy entries must not look alike.

`validate-spec-join.sh` is fourth and the best defended: every empty-set direction is a DISARMED
that names its corpus, so only a populated-but-wrong spec folder reaches the identity-free PASS.

`validate-suppression-lifetime.sh` is last, and its shape is the inversion worth recording: it
names the escalations file when the file is ABSENT and there is nothing to say, and omits it when
it is delivering a verdict.

**`validate-layer-entries.sh` is NOT part of this and the reason is clause 1.** It has **0** argv
case-arms and **0** `AI_DLC_*` overrides, against a control of four on `validate-ci-gates.sh`; its
roots come from `artifact-path-config.sh --scan-roots`, derived rather than supplied, and it
already reports the resolution. There is no caller-chosen corpus for it to conceal.

**The fix is one appended line per emitter, and the convention already exists — but not in the two
files it is usually attributed to.** `validate-artifact-budget.sh` and
`validate-snapshot-conservation.sh` carry **0** label-column emitters under a grammar that finds
**4** in `validate-steering-budget.sh`; they render per-finding rows and `WARN:` sentences, not an
evidence block. The live shell exemplar is `validate-artifact-paths.sh` — a resolved-root header
over a label column carrying grammar, scan roots and counts together — and the JS one is
`validate-steering-budget.sh` as `BL-059` left it. Every fix APPENDS and none rewrites, because
`BL-059` nearly broke `steps/retro.md`, which reads `transcripts scanned : N` by label.

**Four downstream readers parse these lines and all four survive that fix, measured against the
patched copies rather than reasoned about** — the `scope-confirmation`, `ci-gates-resolution`,
`spec-join-integrity` and `suppression-lifetime` fixtures each read one of these lines by label or
prefix, and all four HOLD against a negative control token that correctly does not. No caller
parses any of them: the two hits outside the fixtures are prose and a comment.

**Nothing guards this today and the proof is not a grep.** All five owning fixtures run rc 0 with
144 passing assertions between them on this tree, and this entry's receipt reports the defect LIVE
in all five on that same tree. A fixture that is green while its subject is broken cannot express
the break. A keyword scan of the fixture bodies for discrimination language was tried first and
DISCARDED: it scored **0** on `core/fixtures/adversarial-citation/run.sh`, which post-`BL-059`
does assert corpus identity, so the instrument failed its own control and its numbers are not
reported.

**The receipt anchors on DISCRIMINATION, not on a string, and it splits each validator's inputs
across TWO temp roots so that naming one corpus cannot satisfy the other.** All five must produce
DIFFERENT output on the two sides while both sides exit their success status. Random directory
names make a hardcoded literal unconstructible; the five exit-status guards kill a fix that renders
the path and then breaks the verdict; requiring BOTH temp roots in the output of the four
two-input validators kills a fix that echoes one argument and calls it provenance; requiring the
literal root — not merely that the outputs differ — kills a fix that discriminates with a nonce or
a timestamp; and putting all five in one chain means a fix to one leaves the receipt STILL-LIVE.
The control is the evidence line itself: if any of the five stops emitting its count line the
receipt exits 9 rather than closing on a run that produced nothing.

**Proven in both directions with byte-identical receipt text, and against five mutants.** Against
this tree: **1**, past the exit-9 guards, so all five reached their success path and emitted their
evidence. Against a `mktemp -d` root holding patched copies of all five — the two sides asserted to
differ first by `diff -rq`, which named exactly those five files: **0**. The three questions,
answered by mutation of that fixed tree: a hardcoded constant corpus string → **1**; naming one of
two caller-supplied corpora → **1**; rendering the path then failing → **9**; fixing one validator
and leaving four → **1**; a per-run nonce that discriminates without naming → **1**. The unmutated
fix scores **0** in the same invocation, so the receipt is satisfiable and not merely strict.


**RE-DERIVED FOR BATCH 9, AND THE ENTRY WAS WRONG IN FOUR PLACES.** Each correction carries
the measurement that produced it.

**The receipt above had been unable to measure anything for 28 releases.** Its seed wrote
`- CAP-1 x` into `SPEC.md`, and `validate-spec-join.sh` DISARMs that spelling at rc 2 —
*"mentions CAP-<n> identifiers but DEFINES none in the '- **CAP-<n>** — <intent>' bullet shape
this check reads"* — so the `[ "$c4" = 0 ]` sanity arm tripped and the receipt exited 9 against
every implementation, a correct one included. Bisected against four revisions each carrying a
positive control in the same invocation: PASS at `6011d94d` (v0.378.0, where it was filed) and
at `0218b490` (v0.387.0); DISARMED from `80ed80c8` (v0.388.0) onward, the commit that
introduced the `**`-anchored `CAP_DEFS` extractor and the DISARM together. The grammar is the
`**` emphasis, not the em dash: `- **CAP-1**` with nothing after it passes, `- __CAP-1__` and
`- **CAP-1 stores things**` do not. This is the class `BL-089` was filed about — an expired
receipt and a live defect are one `STILL-LIVE` row.

**`validate-ci-gates.sh` has TWO success emitters, not one.** `:144` exits **0** after
`Scanned N retros, 0 gates declared, 0 dormant`, and that is a different `echo` from the `:251`
verdict line. It is the site this entry itself ranks worst — the retro tree that exists, holds
no declarations, and passes clean — and the old receipt never reached it. A fix touching `:251`
alone would have closed this entry with the measured false pass unfixed.

**`--story` is unnamed on the success path too**, so the entry undercounts
`validate-spec-join.sh`'s undisclosed caller-supplied corpora by one. Control: a story missing
its `capabilities:` frontmatter fails rc 1 and names the story path, so the search sees a named
story when one is there.

**v0.415.0 half-discharged `validate-spec-join.sh`, and only on one branch.** Its
`join (1) reads N locked requirement(s) from <source>` line is emitted unconditionally on the
success path, but `$LR_POP_SOURCE` has two spellings: the `--spec`-derived memlog when
`--locked-requirements` is omitted, and the `--locked-requirements` file itself when it is not.
On the second, the `--spec` root disappears from the success path entirely — measured at rc 0
over three disjoint roots, spec present 0 times, prd present 0 times. A fix leaning on that line
discloses nothing there, so the rebuilt receipt drives the validator WITH
`--locked-requirements` and names `--spec` explicitly.

**The rebuilt receipt uses four disjoint roots per side** so that naming one caller-supplied
corpus cannot satisfy the clause for another. Proven in both directions and against nine
mutants, the two sides asserted to differ by `diff -rq` first: shipping tree **1**, correct fix
**0**; a hardcoded constant corpus string **1**; naming one of two caller corpora **1**;
rendering the path then failing the verdict **9**; fixing the ci-gates verdict but not its
zero-gate exit **1**; a per-run nonce that discriminates without naming **1**; fixing four of
the five validators **1**; the evidence line itself deleted **9**; naming `--spec` and `--prd`
but not `--story` **1**; leaning on join (1) for the spec root **1**.


verify: sh T=$(printf '\140'); S() { P="$1"; Q="$2"; Z="$3"; L="$4"; mkdir -p "$P/spec" "$P/retro-nogates"; H=$(printf hi | shasum -a 256 | cut -d' ' -f1); printf '%s\n' "- user_request_verbatim: x" "- scope_confirmed: confirmed" "- scope_confirmed_cite: $H" > "$P/snap.md"; printf '%s\n' "- SHA256: $H" > "$Q/ans.md"; printf '%s\n' "add CI gate ${T}g1${T} here." > "$P/retro.md"; printf '%s\n' "a retro that declares no gates at all." > "$P/retro-nogates/r.md"; printf '%s\n' "run: g1" > "$Q/w.yml"; printf '%s\n' "<!-- AC_UNBOUNDED_TERMS v1 -->" "aaa, bbb" "<!-- AC_UNBOUNDED_TERMS_END -->" > "$P/lex.md"; printf '%s\n' "- **AC1 (unit).** counter increments by exactly 1." > "$Q/story.md"; printf '%s\n' "- **CAP-1** — the system stores a thing." > "$P/spec/SPEC.md"; printf '%s\n' "- (capability) LR-S1-1 -> CAP-1" > "$P/spec/.memlog.md"; printf '%s\n' "- FR-1 (CAP-1) x" > "$Q/prd.md"; printf '%s\n' "# esc" > "$P/esc.md"; printf '%s\n' "<!-- LOCKED_REQUIREMENTS -->" "- LR-S1-1 the thing is stored" "<!-- END LOCKED_REQUIREMENTS -->" > "$L/lr.md"; printf '%s\n' "---" "capabilities: CAP-1" "---" "- **AC1 (unit).** counter increments by exactly 1." > "$Z/s.md"; }; R() { P="$1"; Q="$2"; Z="$3"; L="$4"; O1=$(bash core/scripts/validate-scope-confirmation.sh --snapshot "$P/snap.md" --answers "$Q/ans.md" 2>&1); C1=$?; O2=$(AI_DLC_RETRO_DIR="$P" AI_DLC_CI_SURFACE="$Q" bash core/scripts/validate-ci-gates.sh 2>&1); C2=$?; O3=$(bash core/scripts/validate-ac-falsifiability.sh --lexicon-from "$P/lex.md" "$Q/story.md" 2>&1); C3=$?; O4=$(bash core/scripts/validate-spec-join.sh --spec "$P/spec" --prd "$Q/prd.md" --story "$Z/s.md" --locked-requirements "$L/lr.md" 2>&1); C4=$?; O5=$(bash core/scripts/validate-suppression-lifetime.sh --escalations "$P/esc.md" 2>&1); C5=$?; O6=$(AI_DLC_RETRO_DIR="$P/retro-nogates" AI_DLC_CI_SURFACE="$Q" bash core/scripts/validate-ci-gates.sh 2>&1); C6=$?; }; A1=$(mktemp -d); A2=$(mktemp -d); A3=$(mktemp -d); A4=$(mktemp -d); B1=$(mktemp -d); B2=$(mktemp -d); B3=$(mktemp -d); B4=$(mktemp -d); [ "$A1" != "$B1" ] && [ "$A2" != "$B2" ] && [ "$A3" != "$B3" ] && [ "$A4" != "$B4" ] || exit 9; S "$A1" "$A2" "$A3" "$A4"; S "$B1" "$B2" "$B3" "$B4"; R "$A1" "$A2" "$A3" "$A4"; a1=$O1 a2=$O2 a3=$O3 a4=$O4 a5=$O5 a6=$O6; c1=$C1 c2=$C2 c3=$C3 c4=$C4 c5=$C5 c6=$C6; R "$B1" "$B2" "$B3" "$B4"; b1=$O1 b2=$O2 b3=$O3 b4=$O4 b5=$O5 b6=$O6; rm -rf "$A1" "$A2" "$A3" "$A4" "$B1" "$B2" "$B3" "$B4"; [ "$c1" = 0 ] && [ "$c2" = 0 ] && [ "$c3" = 0 ] && [ "$c4" = 0 ] && [ "$c5" = 0 ] && [ "$c6" = 0 ] || { echo "GUARD: exit statuses $c1 $c2 $c3 $c4 $c5 $c6" >&2; exit 9; }; grep -qF "answers_entries_scanned" <<<"$a1" && grep -qF " retros," <<<"$a2" && grep -qF "term(s) loaded" <<<"$a3" && grep -qF "locked requirement(s)" <<<"$a4" && grep -qF "entries_scanned=" <<<"$a5" && grep -qF "0 gates declared" <<<"$a6" || { echo "GUARD: an evidence line vanished" >&2; exit 9; }; [ "$a1" != "$b1" ] && [ "$a2" != "$b2" ] && [ "$a3" != "$b3" ] && [ "$a4" != "$b4" ] && [ "$a5" != "$b5" ] && [ "$a6" != "$b6" ] || { echo "LIVE: outputs do not discriminate" >&2; exit 1; }; grep -qF "$A1" <<<"$a1" && grep -qF "$A2" <<<"$a1" && grep -qF "$A1" <<<"$a2" && grep -qF "$A2" <<<"$a2" && grep -qF "$A1" <<<"$a3" && grep -qF "$A2" <<<"$a3" && grep -qF "$A1" <<<"$a4" && grep -qF "$A2" <<<"$a4" && grep -qF "$A3" <<<"$a4" && grep -qF "$A1" <<<"$a5" && grep -qF "$A1" <<<"$a6" && grep -qF "$A2" <<<"$a6" || { echo "LIVE: side A does not name its roots" >&2; exit 1; }; grep -qF "$B1" <<<"$b1" && grep -qF "$B1" <<<"$b2" && grep -qF "$B1" <<<"$b3" && grep -qF "$B1" <<<"$b4" && grep -qF "$B1" <<<"$b5" && grep -qF "$B1" <<<"$b6" || { echo "LIVE: side B does not name its roots" >&2; exit 1; }

## BL-078

**LANDED (v0.416.0, verified 727ddc6c).**

**`EXAMINED NOTHING` was just unified across three validators and is emitted at three different
exit codes, and the wider population it was lifted out of is 17 sites across 13 files and 4 exit
codes with no vocabulary, no invariant and no shared word recording which code means what.**
`core/scripts/validate-locked-anchor.sh:607` prints `PASS — EXAMINED NOTHING` at **exit 0**,
`core/scripts/validate-stub-audit.sh:263` prints `EXAMINED NOTHING (exit 4)` at **exit 4**, and
`core/scripts/validate-ci-gates.sh:197` prints `EXAMINED NOTHING:` at **exit 78**; control in the
same invocation, the impossible token `EXAMINED ZQZQNOTHING` returns 0 files against 3. The
unification is correct and the codes were held on purpose — `validate-locked-anchor.sh:599` records
that *"'Every claim verified' and 'there was nothing to check' still share exit code 0 … They are
separable now without moving the exit code"* — but the result is that one registered-looking token
now spans a passing gate, a bespoke code with no reader, and a consumer-visible code, and nothing
in the tree says so.

**The population that token was lifted out of is far wider than the three.** Derived over
`core/scripts/*.sh`, `scripts/*.sh` and `core/skills/**/*.sh` with comment lines excluded: 6
spellings occupy **46 emission sites in 21 files**; control in the same invocation, the same grep
shape for an impossible token returns 0 files against 21. **30 of the 46 are ordinary
malformed-input refusals and are not this defect** — an unreadable `--baseline`, a missing `--prd`,
a usage error. The remaining **17 are empty-subject verdicts**, at 4 codes: **exit 0** —
`validate-artifact-paths.sh:329`, `validate-escalation-resolution.sh:143`,
`validate-escalation-status-vocabulary.sh:144`, `validate-gate-adjudication.sh:523`,
`validate-locked-anchor.sh:607`, `validate-request-coverage.sh:356`; **exit 2** —
`validate-spec-join.sh:141,173,180,207,275`, `audit-layer-debt.sh:81`,
`validate-ac-falsifiability.sh:132`, `validate-bmad-invocations.sh:160`,
`scripts/validate-plan-shape.sh:54`; **exit 4** — `validate-stub-audit.sh:263`; **exit 78** —
`validate-ci-gates.sh:197`.

**One phrase already carries opposite verdicts.** `nothing to check` is emitted by
`validate-escalation-status-vocabulary.sh:144` for an absent declared subject at **exit 0**, and by
`scripts/validate-plan-shape.sh:54` for an absent declared corpus at **exit 2** — each citing a
principle, the first that an absent escalations file is a legitimate clean state, the second that a
zero is not a finding applied to the corpus itself. Both are defensible; nothing records which case
is which, so the next validator picks by whichever neighbour its author happened to read.

**`validate-escalation-resolution.sh` is the exemplar, not an offender, and it is the evidence that
the distinction is real and load-bearing.** That file draws the line deliberately and BY MODE:
`:134` states that a caller asking "was this authorized?" must not read "nothing to check" as yes,
and `:135` emits `NONE:` at **exit 1** for the absent file under `--any-authorized` while `:143`
emits `OK: … nothing to check.` at **exit 0** for the same absent file under the gate mode. One
file discovered the split, encoded it privately, and nothing carries that reasoning to the other
twelve. `validate-request-coverage.sh:238` did the same independently.

**The `DISARMED` polarity claim this entry was scoped around does NOT hold, and the correction
matters more than the claim would have.** `DISARMED` is a genuine de-facto shared vocabulary — 24
emission sites across `validate-spec-join.sh`, `validate-ac-falsifiability.sh`,
`validate-bmad-invocations.sh` and `audit-layer-debt.sh` — and every one of the 24 exits **2**,
uniformly, derived by taking the first `exit <n>` within 15 lines of each site and collapsing to
distinct values, which yields the single value 2. The three `DISARMED:` prints in
`scripts/validate-enforcement-map.sh:5264,5268,5271` are **not** a fourth polarity: their
`sys.exit(0)` belongs to an inner heredoc python whose stdout is captured, and the shell `case` at
`:5293` matches `DISARMED:*` and calls `err`, so the script exits **1**. Same token, same meaning,
non-passing on both sides. What survives is narrower and still real: a 24-site cross-file
vocabulary that `docs/vocabulary-index.md` does not register — 0 hits there for each of `DISARMED`,
`EXAMINED NOTHING`, `NOT-APPLICABLE`, `VACUOUS` and `nothing to check`, against a control of 6 hits
for `vocabulary` in the same file.

**The exit codes are a separate decision and it is the operator's, not this entry's.** Derived
readers, with `\b` avoided in every pattern because git grep's ERE does not support it and silently
returned 0 for all five codes — including `-eq 0`, which certainly exists — before that was caught:

- **exit 2** is the most heavily contracted code in the tree — roughly 40 fixture arms assert it as
  fail-closed, several naming this exact class: `core/fixtures/bmad-invocation-resolve/run.sh:163`
  ("zero enumerated call sites exits 2, not 0"), `core/fixtures/layer-debt-ledger/run.sh:117` (rc 2
  **and** the `DISARMED` token together), `core/fixtures/setup-site-drift/run.sh:249`.
- **exit 4 has no reader at all.** All four files invoking `validate-stub-audit` compare an rc to 4
  **zero** times; control in the same loop over the same four files finds an `-eq 1` compare in
  `check-15-bypass/run.sh`. The distinction that code buys is unobserved.
- **exit 78** is the best-defended and the only consumer-visible one.
  `core/fixtures/ci-gates-resolution/run.sh:70` asserts it and `:73` mutates `exit 78` → `exit 2` to
  prove the arm can kill, and `core/skills/ai-dlc/steps/retro.md:360` names the code to the lead in
  shipped prose.
- **exit 0** is what a gate reads as a pass, which is why `validate-gate-adjudication.sh:523` spells
  a zero-subject result `PASS — 0 series … Nothing to count; nothing counted` — the one site where
  the vacuous verdict is literally the word PASS.

**Three coherent options.** (1) **Bind the token only, leave every code as it is** — cheapest,
breaks no caller, and leaves a reader unable to tell exit 0 "legitimately empty" from exit 0
"passed" without parsing prose; this is the state the tree is in right now, arrived at by default
rather than by decision. (2) **Unify onto one empty-subject code** — makes the class
machine-readable everywhere, and breaks the ~40 rc-2 fixture arms, the 78 assertions, and
`retro.md`'s shipped text. (3) **Tier into a documented two-member set**, one code for "no subject
exists and that is legitimate" and one for "the subject is missing so nothing ran" — the
distinction two files already found alone; costs a migration of the exit-0 sites that are really
refusals, and leaves 78 and 4 as outliers to absorb or keep.

Tiered **DEFECT**, not BLOCKER. Every site is individually justified in its own header and none was
measured emitting a wrong verdict; the harm is that the judgment is remade from scratch at each new
validator with nothing to consult, which is how the three in `BL-058` diverged in the first place —
and how their unified replacement now spans three exit codes.

**The receipt keys on the REGISTRATION, never on a count of the divergent spellings, and it is
built to reject `BL-058`'s narrower fix.** A receipt counting the old spellings requires the defect
to survive in order to close; that shape was live in `BL-058`'s own receipt and is why this one
differs — and it is now concrete, because `BL-058`'s unification drove those spellings to zero.
`docs/vocabulary-index.md` is a GENERATED file, byte-compared at pre-push, whose rows render from
the owner that declares each vocabulary, so a row cannot be hand-written to satisfy this: its
existence implies a real owner and a real binding invariant. The receipt requires a row naming the
empty-subject class **and** reaching at least three emitters outside `BL-058`'s three, or a
`core/scripts/*` glob covering them — that reach is what separates this entry's close from
`BL-058`'s. All three options above end in that row, so a correct fix of any shape satisfies it.
The table-header guard means a broken scan exits 9 and reports STILL-LIVE rather than closing.
Proven in four directions against copies under `mktemp`, each asserted byte-different from the
shipping file first: shipping tree exits 1; a `BL-058`-only registration exits 1; a wide
registration exits 0; a truncated index exits 9.

Split from `BL-058`, which unified the token for its three named emitters only. The wider
population and the exit-code question were left out of that remediation deliberately.


**RE-DERIVED FOR BATCH 9. THE CORE DEFECT HOLDS; FOUR CLAIMS AROUND IT DO NOT, AND THE
RECEIPT HAD A HOLE THAT WAS MEASURED RATHER THAN ARGUED.**

**The filed receipt could be closed by PROSE.** It read only the RENDERED ROW of
`docs/vocabulary-index.md`, whose Readers column is populated from a `# vocabulary-readers:`
COMMENT in the arm header — and `scripts/render-vocabulary-index.sh` checks those entries for
file EXISTENCE and nothing else. Measured on a copy of `origin/main`: appending three of the
ten basenames to that one comment and re-rendering gave receipt **0**, render **0** and
`validate-enforcement-map.sh` **0**, with no owner, no invariant, no emitter and no behaviour
changed. The entry's assurance that *"a row cannot be hand-written to satisfy this"* is
therefore false. The rebuilt receipt keeps the registration arm and adds the one a comment
cannot satisfy: every declared emitter must PRINT the token on a NON-COMMENT line. Against the
same prose-only mutant it exits **1** where the filed one exits 0.

**The receipt's `core/scripts/*` escape hatch is unreachable by its intended route.** The
renderer fails closed on a glob in Readers, so that clause could only ever have been satisfied
by free prose in the vocabulary NAME — the same hand-written close one field over.

**Five of the seventeen cited sites do not resolve, and they are the whole exit-2 spec-join
list.** `:141` is a comment about suppression expiry, `:173` is a bare `rc=1`, `:180` and
`:207` are comments, `:275` is `return 1`. The offsets are 16/105/101/75/8, so this is not one
stale rebase — the five were never a coherent set. Control: an impossible line number in the
same file returns NO SUCH LINE, and the other twelve citations do land on real emissions. The
REAL empty-subject verdicts in that file are `:767, :799, :934, :945, :1007, :1027, :1211`,
each a `DISARMED — <subject> contains ZERO/no <thing>` at exit 2, and those are what this
batch fixed.

**`EXAMINED NOTHING` was already registered when the entry claimed it was not.** The entry
reports 0 hits in `docs/vocabulary-index.md` for each of five tokens; measured today,
`EXAMINED NOTHING` returns **1** — the `I93` row — against the entry's own control of 6 for
`vocabulary`, an exact match, so it was the same file. `BL-058` landed that row in the same
commit this entry was filed in. The narrow surviving claim, that `DISARMED` is an unregistered
24-site vocabulary, holds in direction; the count is **38** emission sites, 33 of them in the
four files the entry names and all of those at exit 2.

**The class spans FIVE exit codes, not four.** `validate-escalation-resolution.sh:135` and
`:221` emit `NONE:` at exit **1**. The entry cites `:135` by name and then excludes the file
from its own tally by designating it the exemplar. Those two sites are left alone deliberately:
that file draws the legitimate-empty vs nothing-ran line BY MODE on purpose, and it is the
distinction the whole entry is about.

**Sites the entry's seventeen omits, found by re-derivation and fixed here:**
`validate-suppression-lifetime.sh:115` and `validate-snapshot-conservation.sh:173, :203, :236`.
**Left unfixed and recorded rather than swept in:** `core-paths.sh:263`,
`audit-rule-files.sh:311, :474, :479` (per-check `N/A n=[]` rows inside an audit, not a run
verdict) and `scripts/validate-enforcement-map.sh:5709, :5713, :5716` — the entry's four
citations there are all offset by exactly +445, which confirms its reasoning and only its
numbers were stale.

**`scripts/validate-plan-shape.sh:54` emits the token but is NOT a declared emitter.** It sits
outside `core/scripts/`, and `enforcement-map.yaml` SHIPS — a declared emitter absent from a
consumer tree is an arm-A failure by construction. Its edit is unguarded and that is stated
rather than hidden.


verify: sh V=docs/vocabulary-index.md; M=core/skills/ai-dlc/enforcement-map.yaml; [ -f "$V" ] && [ -f "$M" ] || exit 9; grep -q "^| Vocabulary | Members | Owner | Bound by | Readers |$" "$V" || exit 9; row="$(grep -iE "^\|[^|]*(vacuous|empty.subject|examined nothing|nothing to check|not.applicable|nothing verified)[^|]*\|" "$V")"; [ -n "$row" ] || exit 1; tok="$(awk '/^empty_subject_verdict:/{on=1;next} on&&/^[^[:space:]#]/{exit} on&&/^  token:[[:space:]]/{v=$0;sub(/^  token:[[:space:]]*/,"",v);print v}' "$M")"; [ -n "$tok" ] || exit 9; ems="$(awk '/^empty_subject_verdict:/{on=1;next} on&&/^[^[:space:]#]/{exit} on&&/^  emitters:[[:space:]]*$/{e=1;next} on&&e&&/^  [a-z_]+:/{e=0} on&&e&&/^    - /{v=$0;sub(/^    - /,"",v);print v}' "$M")"; [ -n "$ems" ] || exit 9; n=0; for f in validate-spec-join validate-plan-shape audit-layer-debt validate-bmad-invocations validate-ac-falsifiability validate-escalation-status-vocabulary validate-artifact-paths validate-request-coverage validate-gate-adjudication validate-snapshot-conservation; do case "$ems" in *"$f.sh"*) n=$((n+1)) ;; esac; done; [ "$n" -ge 3 ] || exit 1; bad=0; while IFS= read -r f; do [ -n "$f" ] || continue; [ -f "$f" ] || { bad=1; continue; }; hit="$(awk -v t="$tok" '{ if (index($0,t)==0) next; s=$0; sub(/^[[:space:]]+/,"",s); if (substr(s,1,1)=="#") next; c++ } END { print c+0 }' "$f")"; [ "$hit" -gt 0 ] || bad=1; done <<<"$ems"; [ "$bad" -eq 0 ] || exit 1; ctl="$(awk -v t="$tok" '{ if (index($0,t)==0) next; s=$0; sub(/^[[:space:]]+/,"",s); if (substr(s,1,1)=="#") next; c++ } END { print c+0 }' VERSION)"; [ "$ctl" -eq 0 ] || exit 9; exit 0

## BL-081

**LANDED (v0.386.0, verified 5d02dcf4).** EXPIRED, not remediated here — the subject was fixed
thirty releases before this triage found it, and the ledger row was never joined to the fix
because v0.386.0's CHANGELOG names this id zero times (control: `ledger-reverify` twice in the
same range). `5d02dcf4` replaced the unanchored `grep -oE` with a shell-word split,
`receipt_path_tokens() { printf '%s\n' "$1" | tr -c 'A-Za-z0-9_./$-' '\n' || true; }`; `:` is
outside the keep-set, so a rev-spec splits at the colon and its `core/…` half fails the four
`case` prefixes. Two independent verifiers confirmed against the tree, neither relying on the
receipt. Both ran both implementations over all 70 `verify: sh` receipts in the consumer's
live + archive ledgers with `CONSUMER=/Users/n8/git/graph`: pre-fix **14** receipts emit an
absent-subject finding including ` scripts/validate-steering-budget.sh`, HEAD emits **1**, and
that one is a genuine consumer path with no rev-spec in it. The regex is gone rather than
relocated — `grep -rn --include=*.sh -F "(docs|_bmad-output|scripts|\.claude)/"` over the whole
tree exits 1, control `-F receipt_path_tokens` returns 4 hits and exits 0.
<br>**Claim 4 is PRESERVED and claim 5 is SATISFIED**, which is what separates this from a
guard deletion: a genuinely absent `$CONSUMER/docs/no-such-file.md` is still reported at HEAD,
present paths stay silent, and the fix is a tokenizer change rather than the
`scripts/` → `scripts/ai-dlc/` re-mapping the entry forbids (the file refuses a private inverse
table at `:677-679`). Guarded, not merely present: `core/fixtures/ledger-reverify/run.sh:183`
asserts `Entry SH-DIST-PATH` → CLOSE-CANDIDATE, deliberately paired at `:178` with
`Entry SH-SUBJECT-GONE` → NEEDS-REVIEW, which is the two-directional receipt this entry
specified. Claim 6 discharged: `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE` now
appears only in the consumer's archive ledger.
<br>**Claim 7's 3-vs-9 split was wrong, in the direction that strengthens the close.** All
twelve `scripts/<x>.sh` findings sit inside a distribution path — `${THEIRS}:`, `$THEIRS:`,
`$t/`, `$DIST/` or bare `core/scripts/…` — so none was a genuine consumer-side mis-anchor. The
entry's split was an artifact of a strip matching only the `$THEIRS:` spelling. The fix
therefore swept in no class it should have left alone; there was no such class.
<br>**The receipt is retired with the entry rather than ported.** It has exited 1 having
measured NOTHING since v0.402.0: `d983feb9` factored the split into `receipt_path_tokens()` one
line ABOVE its `sed -n "/^receipt_absent_subjects() {/,/^}/p"` range, so both arms die with
`receipt_path_tokens: command not found` and `b` comes back empty. Its sanity arm cannot see
that — it tests only that the body was captured. Widening the `sed` to include the helper gives
`a=[]`, `b=[ docs/no-such-file.md]`, exit 0: this entry's own pass condition, met. That failure
mode is NOT filed separately — it WIDENS `BL-089`, whose population is receipts that measure
nothing while reading STILL-LIVE, and splitting it would give the class two entries and neither
a full view. The latent prefix-defence gap is filed as `BL-092`.

**`receipt_absent_subjects()` fabricates a consumer-relative path out of a substring of a
distribution-relative rev-path, and downgrades the close that receipt had just earned.**
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:521` scans the receipt text with
`grep -oE '(\$CONSUMER/)?(docs|_bmad-output|scripts|\.claude)/[A-Za-z0-9_./-]+'`. That expression
is **unanchored**, so the token `core/scripts/validate-steering-budget.sh` — which the receipt uses
only as `git -C "$DIST" show "$THEIRS:core/scripts/…"`, a rev-path resolved inside the distribution
clone — yields the substring `scripts/validate-steering-budget.sh`. `:520` then tests that against
`$CONSUMER`, finds nothing, and `:1031` routes the receipt's non-zero exit to NEEDS-REVIEW instead
of CLOSE-CANDIDATE. The fabricated token names a file that exists in **neither** tree: `install.sh`
splits `core/scripts/<x>` to `scripts/ai-dlc/<x>`, which is the two-layout rule invariant **I33**
exists to enforce, so `scripts/<x>` is the one spelling that is wrong on both sides of the
boundary. The guard is the code that checks whether a receipt's subject moved, and it is reading a
path the receipt never asked any consumer about.

**Measured on the shipping function, driven against a synthetic consumer carrying both layouts.**
With `scripts/ai-dlc/validate-steering-budget.sh` present and bare
`scripts/validate-steering-budget.sh` absent, the function returns
` scripts/validate-steering-budget.sh` for a receipt whose only path token is a `$THEIRS:`
rev-path, and ` docs/no-such-file.md` for a receipt naming a genuinely absent consumer path. The
first is the defect; the second is the behaviour that must survive any fix.

**It cost a correct close on the release that is in the consumer's tree now.**
`PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE`'s receipt asserts the validator prints the
transcript it read. Extracted and run at `6011d94^` it exits **0**; at `6011d94` — the v0.378.0
release commit that landed exactly that change — it exits **1**, the two blobs differing
(`fe66c6d0…` → `d7f2febc…`). Non-zero is CLOSE-CANDIDATE. The consumer's 0.373.0 → 0.378.0
reconcile instead recorded `NEEDS-REVIEW … the receipt exited 1, but consumer-relative path(s) it
names DO NOT EXIST: scripts/validate-steering-budget.sh`, and the entry is still live. The same
report carries that entry's `NAMED-UPSTREAM` row at v0.378.0 and calls the pair *"the highest-value
pair the tool prints"* — the signal was complete and the guard talked the session out of it.

**Scope: three of the twelve findings the guard emits on the reference consumer are of this class,
and the other nine are a different problem that must not be swept in with it.** Over all **69**
`verify: sh` receipts in that consumer's live and archive ledgers, driven through the shipping
function with `CONSUMER` set to the real consumer root: **14** receipts contain a `$THEIRS:`/`$BASE:`
rev-path, **12** emit an absent-subject finding, and **3** of those findings vanish when rev-paths
are stripped from the input. Those three are wholly fabricated. The remaining nine name a bare
`scripts/<x>.sh` token, and **9 of the 10 distinct tokens exist at `scripts/ai-dlc/<x>.sh`**
(control in the same invocation: an impossible `scripts/NO-SUCH-CONTROL.sh` absent in both layouts;
one token genuinely absent in both). Those receipts really are mis-anchored, and the guard is right
to say so — the report's own "Re-anchor at `scripts/ai-dlc/…`" is the correct remedy for them.
**The two classes need different fixes**: this entry is the one where no consumer path was ever
named, and a fix that merely taught the guard the `scripts/` → `scripts/ai-dlc/` mapping would
close the wrong nine and leave this one reporting.

**Why the receipt is the receipt.** A substring anchor on the regex is unusable — the fix will
quote the old expression in the comment recording what it replaced, which is this file's habit at
`:1011-1017`. The receipt therefore `sed`-extracts the shipping `receipt_absent_subjects()` and
drives it against a `mktemp` consumer holding both layouts, so the two-layout split is exercised
rather than described. Its decisive arm is a **negative control**: a receipt asserting only that the
fabricated token disappears is satisfied by deleting the guard, and deleting the guard is the
destructive remedy this class invites, so the receipt additionally requires that a genuinely absent
`$CONSUMER/docs/…` path is **still** reported. Measured against both destructive mutants — the
`[ -e … ]` accumulation line deleted, and the whole function stubbed to `return 0` — the receipt
exits **1** in each, while the correct fix exits **0** and the unfixed tree exits **1**. A sanity
arm exits **9** (which reverify reports as STILL-LIVE, the safe direction) if the extraction
captured no function body, proven live by renaming the definition.

Found while adjudicating whether the v0.378.0 close channel reached the reference consumer. It did:
all four `PC-` ids produced `NAMED-UPSTREAM` rows. This is the one entry among them whose close was
mechanically earned and mechanically refused.


verify: sh L=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; f=$(sed -n "/^receipt_absent_subjects() {/,/^}/p" "$L"); case "$f" in *"receipt_absent_subjects()"*) : ;; *) exit 9 ;; esac; d=$(mktemp -d); c="$d/c"; mkdir -p "$c/scripts/ai-dlc" "$c/docs"; printf "x\n" > "$c/scripts/ai-dlc/validate-steering-budget.sh"; [ -e "$c/scripts/ai-dlc/validate-steering-budget.sh" ] || { rm -rf "$d"; exit 9; }; if [ -e "$c/scripts/validate-steering-budget.sh" ] || [ -e "$c/docs/no-such-file.md" ]; then rm -rf "$d"; exit 9; fi; a=$(CONSUMER="$c" bash -c "$f"'; receipt_absent_subjects "$1"' _ 'git -C "$DIST" show "$THEIRS:core/scripts/validate-steering-budget.sh" > "$d/v.sh"'); b=$(CONSUMER="$c" bash -c "$f"'; receipt_absent_subjects "$1"' _ 'grep -q probe "$CONSUMER/docs/no-such-file.md"'); rm -rf "$d"; [ -z "$a" ] && [ -n "$b" ]
## BL-090 — `I93` asks whether every DECLARED emitter emits the token and never whether every EMITTER is declared, so a new one is invisible

**The join runs one way only.** `scripts/validate-enforcement-map.sh`'s arm A walks the
`empty_subject_verdict: emitters:` list in `core/skills/ai-dlc/enforcement-map.yaml` and fails
the push if a declared file does not print the token outside a comment. Arm C sweeps
`core/scripts/*.sh` for RETIRED spellings. **Nothing asks the reverse question** — whether a
file printing the DECLARED token is declared at all — so a validator that adopts the
vocabulary without being registered joins it silently and the index under-reports the set.

**Measured, by seeding rather than by reading the arms.** A new `core/scripts` validator whose
only emission is the declared token, named nowhere in the declaration, is added to a scratch
copy and the shipping validator is driven over it: **rc 0**, no finding. Controls in the same
invocation: the unseeded copy passes (so a later non-zero would be attributable to the seed),
the seed genuinely emits under the same non-comment reader arm A uses, and the seeded name is
genuinely absent from the map.

**It is not hypothetical — there is a live instance today.**
`scripts/validate-plan-shape.sh:54` emits `EXAMINED NOTHING` and is deliberately NOT declared,
because `enforcement-map.yaml` SHIPS to consumers while that script does not, so declaring it
would write a permanently false emitter path into every consumer tree, unfalsifiable at the
only place it is wrong. That exemption is correct and it is exactly what makes the gap
invisible: the one file that proves the reverse arm is missing is also the one file that must
not be declared. A reverse arm therefore needs a stated exemption, not just a sweep.

**THE DECLARATION IS THREE HAND-LISTS AND NOTHING BINDS ANY TWO OF THEM.** The yaml's
`emitters:` and `readers:` are consumed by arms A and B. The arm header's
`# vocabulary-readers:` marker at `scripts/validate-enforcement-map.sh:7233` is consumed by
`scripts/render-vocabulary-index.sh` and by nothing else — no arm checks that a path in it
exists, carries the token, or agrees with the yaml. That third list is what makes
`BL-078`'s receipt satisfiable by editing one comment, and it is why the rendered Readers
column currently carries EMITTERS, which is not what arm B means by a reader.

**The clean fix is subtraction, and it was scoped out of batch 9 deliberately rather than
missed.** A `# vocabulary-emitters:` field rendered as its own column, with both columns
DERIVED from the yaml the owner already declares, removes the third hand-list, closes the
reverse-arm gap and fixes the column semantics in one change. It touches the renderer, every
row and the pre-push byte-compare, which is more than the token-binding `BL-078` was closed
under, so it is filed rather than folded in.

Tiered **DEFECT**. Nothing is emitting a wrong verdict today; the harm is that the vocabulary's
population is whatever the last author remembered to declare, which is the state `BL-058` and
`BL-078` both exist to end.

Found by two independent hands re-deriving `BL-078` during batch 9, one of which demonstrated
the one-comment close on a copy of `origin/main`.

**LANDED (v0.419.0, verified 5efb3d17).** All three claims discharged in one change. Arm D is
the reverse join: every file under `core/scripts/` and `scripts/` that prints the token
outside a comment must be declared in the map or exempted, and the single exemption is
`scripts/validate-plan-shape.sh` -- the file this entry named as the live instance, and the one
file that must not be declared. The exemption carries its reason and is checked four ways; the
arm requiring an exempt file to still EMIT is arm D's own positive control, fired in the same
invocation as the zero it licenses. The population is every FILE in those two directories
rather than every `*.sh`, because a file extension answers no question about who joined a
vocabulary and `core/scripts/gen-architecture-index.js` exists today -- an `*.sh` sweep would
have reproduced this entry's own defect one grain over. The third hand-list is deleted: the
marker's sixteen restated paths are now an `@owner-declares` sentinel the renderer resolves
against the owner, and `docs/vocabulary-index.md` gained an Emitters column, so its Readers
column no longer carries emitters. Measured: this entry's own receipt went raw exit 1 -> 0, the
validator stays 0 on the clean tree, it fires on a seeded undeclared emitter in both halves of
the population and on a non-`.sh` one, and stays quiet on both near-misses.
`enforcement-map-sites` gained A35-A37 including an arm-D mutant and both directions of the
probe's four new bits; `vocabulary-index` went 11 -> 14 mutants. The change is fork-NEGATIVE by
47 and `FORK_BUDGET` ratcheted 7076 -> 7029.

verify: sh M=core/skills/ai-dlc/enforcement-map.yaml; V=scripts/validate-enforcement-map.sh; [ -f "$M" ] && [ -f "$V" ] || exit 9; tok="$(awk '/^empty_subject_verdict:/{on=1;next} on&&/^[^[:space:]#]/{exit} on&&/^  token:[[:space:]]/{v=$0;sub(/^  token:[[:space:]]*/,"",v);print v}' "$M")"; [ -n "$tok" ] || exit 9; D="$(mktemp -d)" || exit 9; tar --exclude=.git -cf - . 2>/dev/null | tar -xf - -C "$D" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$V" >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; printf '%s\n' '#!/bin/bash' "echo \"probe: ${tok} — seeded undeclared emitter\"" 'exit 0' > "$D/core/scripts/validate-bl090-probe.sh"; n="$(awk -v t="$tok" '{ if (index($0,t)==0) next; s=$0; sub(/^[[:space:]]+/,"",s); if (substr(s,1,1)=="#") next; c++ } END { print c+0 }' "$D/core/scripts/validate-bl090-probe.sh")"; [ "$n" -gt 0 ] || { rm -rf "$D"; exit 9; }; grep -qF 'validate-bl090-probe.sh' "$D/$M" && { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$V" >/dev/null 2>&1 ); rc=$?; rm -rf "$D"; [ "$rc" -ne 0 ] || exit 1; exit 0

## BL-094 — a marker field declared TWICE is last-wins and silent, so a contradiction between two declarations of one field is never reported

**LANDED (v0.421.0, verified 045ef6d9).** `MARKER_AWK` now carries a per-block partition — five
scalar seen-flags reset in `flush()` and `BEGIN` — so a second declaration of any of the five
fields is refused rather than resolved by overwriting, naming the block, the line, the field and
BOTH values. The seen-flags are separate from the values because an emptiness test accepts a
second declaration whose first was EMPTY, which is the contradiction being refused.

**The likely fix named below was right and the receipt filed below was NOT**, which is the part
worth reading. The original receipt seeded one of the five fields, so a partition covering that
field alone returned exit 0 while a duplicated `vocabulary-owner:` still rendered silently. It
has been replaced; see the paragraph above the `verify:` line. Two further defects were found by
seeding states this entry's own population excludes: a finding naming only the field and its two
values does not LOCATE the offending block, and an unreadable corpus was reported as a changed
grammar. Both fixed in the same release.

**The renderer resolves a repeated field by overwriting, and says nothing.**
`scripts/render-vocabulary-index.sh`'s `MARKER_AWK` assigns on every matching comment line —
`vocabulary-readers:`, `vocabulary-emitters:`, `vocabulary-owner:`, `vocabulary-extract:` and
`vocabulary-invariant:` alike — so a second declaration of the same field silently discards the
first. The row renders from the LAST one, `--check` byte-compares clean, and the gate is green.

**Measured on the real renderer, in a scratch copy.** A literal reader path inserted immediately
above the `@owner-declares` sentinel gives two `# vocabulary-readers:` lines with different
values: renderer **exit 0**, index written, the derived list rendered and the literal
declaration discarded with no message. Control in the same invocation: the unseeded copy passes
`--check`.

**It is PRE-EXISTING, not introduced by the field that exposed it.** Driven against
`5efb3d17^` — before `vocabulary-emitters:` existed — with `# vocabulary-readers:` duplicated:
renderer **exit 0** there too, against a control confirming that copy carries no emitters field.
`v0.419.0` widened the surface from four fields to five; it did not create the behaviour.

**Why it matters here specifically.** This file's whole subject is that one declaration has one
home. Two declarations of one field is the state that satisfies NEITHER reading, and the
renderer already refuses the sibling case — `(consumer-owned)` alongside an extractor fails
loudly with "one of the two declarations is wrong". A repeated field is the same class and is
accepted. Arm D of `I93` refuses the same shape one level out, failing the push when a path is
both declared an emitter and exempted.

**The likely fix is a partition rather than a detector**: have `MARKER_AWK` refuse to overwrite
a field that is already set within one marker block, so the contradictory state cannot be
expressed. Measure the false-positive set first — a marker block is delimited by the next arm
header, and an arm header inside a heredoc or a quoted string could make two unrelated blocks
read as one.

Tiered **NOTE**. Nothing emits a wrong verdict today and the rendered index is correct on the
live tree; the cost is that a contradiction is unreportable, which is the state every other
declaration in this file is held out of.

Found by an adversarial pass over `v0.419.0`/`v0.420.0` run after both had merged.

**The receipt below REPLACED the one filed with this entry, and the reason is a measured false
close.** The original seeded a duplicate `vocabulary-readers:` only, so a partition applied to
that ONE field returned exit 0 while a duplicated `vocabulary-owner:` still rendered silently —
four fifths of this entry's stated subject closable without being fixed. Two more defects went
with it: a bare count guard over the same line satisfied it while detecting nothing about
duplication, and its `-ge 2` seed assertion was VACUOUS, because six `^# vocabulary-readers:`
lines pre-exist and a no-op seed passes it. It also anchored on `^# ` where `MARKER_AWK` accepts
`^[[:blank:]]*#[[:blank:]]*`, and this file already carries one INDENTED marker block, so two
spaces on the sentinel sent it to exit 9 — reported as STILL-LIVE.

**THEN THE REPLACEMENT WAS FOUND TO SHARE A BLIND SPOT WITH BOTH OTHER CHANNELS, AND THAT IS THE
FINDING OF THIS ENTRY.** Its first cut seeded each of the five fields VERBATIM by duplicating the
declaration IN PLACE — `awk NR==n{print} {print}` — which can only ever produce an ADJACENT pair.
So did the renderer's own self-probe, and so did every `dup-*` mutant in
`core/fixtures/vocabulary-index/run.sh`. Three independent-looking channels, ONE input shape.
A guard firing only when the repeat sits on the line immediately after the first declaration
(`s_read && lastfield == "read"`) was MEASURED to pass the clean tree, this receipt, and all 21
fixture mutants — and then render a genuine duplicate separated by two other fields at exit 0,
byte-identically. That is this entry reopened, closed, and green. **A separator that is not
itself a marker field does not defeat it either** — a bare `#` line between the two declarations
leaves the adjacency state untouched, so the seed must be separated by ANOTHER FIELD.

The receipt below therefore runs TEN rounds, not five: each field seeded twice, once BESIDE its
original and once APART from it with at least one other field line between, with the gap asserted
in each direction before the renderer is consulted. Both new controls were proven able to fire —
a variant whose seeding `awk` is replaced by `cat` exits 9, and a variant whose apart-mode
insertion point is collapsed back onto the original exits 9. Measured: unfixed **1**, fixed **0**,
adjacency-only fix **1**, readers-only partial fix **1**.

verify: sh R=scripts/render-vocabulary-index.sh; M=scripts/validate-enforcement-map.sh; [ -f "$R" ] && [ -f "$M" ] || exit 9; F="^[[:blank:]]*#[[:blank:]]*vocabulary-"; D="$(mktemp -d)" || exit 9; tar --exclude=.git -cf - . 2>/dev/null | tar -xf - -C "$D" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$R" --check >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; cp "$D/$M" "$D/m.orig" || { rm -rf "$D"; exit 9; }; n=0; for f in invariant owner extract readers emitters; do for mode in beside apart; do cp "$D/m.orig" "$D/$M"; L="$(grep -n "$F$f:" "$D/$M" | head -1 | cut -d: -f1)"; [ -n "$L" ] || { rm -rf "$D"; exit 9; }; if [ "$mode" = beside ]; then T="$L"; elif sed -n "$((L-1))p" "$D/$M" | grep -qE "$F"; then T="$((L-2))"; elif sed -n "$((L+1))p" "$D/$M" | grep -qE "$F"; then T="$((L+1))"; else rm -rf "$D"; exit 9; fi; b0="$(wc -l < "$D/$M")"; c0="$(grep -c "$F$f:" "$D/$M")"; awk -v l="$L" -v t="$T" 'NR==l{s=$0} {a[NR]=$0} END{for(i=1;i<=NR;i++){print a[i]; if(i==t) print s}}' "$D/$M" > "$D/m.tmp" || { rm -rf "$D"; exit 9; }; mv "$D/m.tmp" "$D/$M"; [ "$(wc -l < "$D/$M")" -eq "$((b0+1))" ] || { rm -rf "$D"; exit 9; }; [ "$(grep -c "$F$f:" "$D/$M")" -eq "$((c0+1))" ] || { rm -rf "$D"; exit 9; }; set -- $(grep -n "$F$f:" "$D/$M" | head -2 | cut -d: -f1 | tr '\n' ' '); B="$(awk -v x="$1" -v y="$2" 'NR>x && NR<y && /^[[:blank:]]*#[[:blank:]]*vocabulary-/{c++} END{print c+0}' "$D/$M")"; if [ "$mode" = beside ]; then [ "$(($2-$1))" -eq 1 ] || { rm -rf "$D"; exit 9; }; else [ "$B" -ge 1 ] || { rm -rf "$D"; exit 9; }; fi; ( cd "$D" && bash "$R" >/dev/null 2>&1 ) || n=$((n+1)); done; done; cp "$D/m.orig" "$D/$M"; ( cd "$D" && bash "$R" >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; rm -rf "$D"; [ "$n" -eq 10 ] || exit 1; exit 0

## BL-052

**LANDED (v0.422.0, verified bccc8d9c).** All thirteen renderings quoted, not the five filed —
the population was re-derived rather than believed, and the entry's own receipt grammar could
not spell two of them. `S8` of `scripts/validate-shell-portability.sh` now binds the class over
a `core/` corpus that scans comment lines, so the comments are sites rather than the exemption
the original scope was narrowed to dodge. Verified on a tree built by `scripts/install.sh`:
0 unquoted renderings, against a control of 6 files carrying the quoted form across both
install destinations.

**The update skill renders every `git show <ref>:<path>` unquoted, and under zsh the `:c`/`:t`
history modifiers eat the path.** Five sites, two files, none quoted:
`core/skills/ai-dlc-update/SKILL.md:642` and `:1156` (`show <theirs>:<core-path> > <consumer-path>`),
`:879` and `:1402` (`show <theirs>:templates/settings.json.template`), and
`core/skills/ai-dlc-update/reconcile/apply.sh:1252`, which EMITS the templates form at runtime as a
command the operator is told to run. Measured over `core/skills/ai-dlc-update/`: files matching
`show +<(theirs|base|ours)>:` = **2**; control, the same pattern with the ref quoted = **0**. A
reader who binds the ref to a variable — which is what `t=$(mktemp); git -C <dist> show <theirs>:…`
leads them to do — gets `fatal: ambiguous argument 'ca1fb6eemplates/settings.json.template'`, while
the redirect still creates `"$t"` as a 0-byte file that the next command reads and reports on.

**The filing counted 2 and the defect is 5.** It grepped only the literal
`show <theirs>:templates/settings.json.template`, so it missed both `<core-path>` renderings in
SKILL.md and the `apply.sh` emission. The `apply.sh` site is the most exposed of the five: the other
four are instructions a reader may adapt, that one is a string the tool prints as the fix for
"hook(s) present and UNREGISTERED after this apply", at the moment the operator is being told to
paste it.

Nothing else in the filing was wrong. The correct form is established practice in the same tree —
this repo's own `CLAUDE.md` names the hazard by name and the backlog's `verify: sh` receipts write
`"${SHA}:core/…"` quoted throughout.

**Not claimed:** that a reader substituting a literal sha hits this. They do not; the modifier fires
only on parameter expansion.

The anchor is the unquoted rendering itself — adding the quotes IS the fix, so it is a token the fix
cannot leave in place. It is scoped to `core/skills/ai-dlc-update/` deliberately, and the scope was
measured rather than chosen: `core/scripts/validate-hook-registration.sh:291` is a COMMENT that
quotes the hazardous form back while explaining it, and a wider grep would be pinned non-zero by
that comment forever — the unfalsifiable case. Probed with a partial fix: quoting four of the five
sites leaves the receipt at 1, and it reaches 0 only when `apply.sh:1252` is quoted too.

Discharges the consumer entry `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT` at
pinned ledger line 4096.

**RE-DERIVED AT v0.422.0. THE POPULATION IS 13 SITES ACROSS 8 FILES, NOT 5 ACROSS 2, AND THE
RECEIPT ABOVE COULD NOT SPELL ITS OWN SUBJECT.** `show +<(theirs|base|ours)>:` misses
`SKILL.md:1148`, which renders `<ancestor>:<core-path>` and sits INSIDE the receipt's own scoped
directory. The scope then excluded a printed REMEDY at
`core/scripts/validate-snapshot-conservation.sh:344`, a step-file instruction at
`core/skills/ai-dlc/steps/gate-validation.md:2506`, descriptive prose at `steps/retro.md:100`,
three shell comments, and `core/fixtures/settings-merge-unparseable-template/.dist-only:19`.
Derivation: `git ls-files -z 'core/*' | xargs -0 grep -HnE '(show|cat-file -p|ls-tree|archive|diff)[[:space:]]+<[^>]+>:'`
returns 13 on the pre-fix tree and 0 on the fixed one, against a control over `docs/` that
returns 8 in the same invocation.

**THE UNFALSIFIABLE-CASE ARGUMENT ABOVE IS WRONG, AND THE EXCLUSION IT JUSTIFIED WAS THE DEFECT.**
It holds only for a grep that cannot change the comment. A rev-path rendered inside a comment is
pasted exactly as readily as one rendered in a heredoc, so the comments are SITES rather than
exemptions; quoting them makes the wider grammar reach zero with no exemption list at all. Two of
the thirteen were comments.

**The narrowing that was NOT taken, recorded so it is not re-proposed.** Requiring the word `git`
on the same line finds the same 13 over `core/` — the difference set is empty — so it is rejected
on structure, not on a measured miss: a rendering can wrap and leave `git -C <dist>` on the line
above while the bracketed `<ref>:` token stays whole. Tree-wide the two patterns differ 37 to 29,
and all 8 of those are `docs/` prose quoting the bare fragment. That number is about this file, not
about the corpus the arm scans.

**The receipt below DRIVES `S8` of `scripts/validate-shell-portability.sh` rather than restating
its grammar**, so the corpus derivation and the battery exclusion cannot drift from the arm's.
It self-probes FIRST, in a seeded `mktemp` tree, and refuses to read the clean run until S8 has
reported a seeded offender by name — a gutted S8 yields exit 9, not exit 0. Measured in all three
directions: 0 on the fixed tree, 1 on a tree with one rendering reintroduced, 9 with `S8` removed
from `ARMS` (mutant applied under `cmp -s`). **What else satisfies it:** deleting the instructions
outright, or moving the files out of `core/` — both of which unship the text they are written to
deliver.


verify: sh d=$(mktemp -d); mkdir -p "$d/scripts" "$d/core/rules" || { rm -rf "$d"; exit 9; }; echo 0.0.0 > "$d/VERSION"; cp scripts/validate-shell-portability.sh "$d/scripts/" || { rm -rf "$d"; exit 9; }; printf "#!/usr/bin/env bash\necho ok\n" > "$d/scripts/clean.sh"; printf "git show <theirs>:<p>\n" > "$d/core/rules/probe.md"; ( cd "$d" && git init -q . && git add -A ) >/dev/null 2>&1; o=$( cd "$d" && bash scripts/validate-shell-portability.sh 2>&1 ); p=$?; rm -rf "$d"; [ "$p" -eq 1 ] && grep -q "FAIL: S8:" <<<"$o" || exit 9; bash scripts/validate-shell-portability.sh --quiet
## BL-033

**LANDED (v0.423.0, verified 5c3711e2).** Four rows repaired, not the one filed — the population
was re-derived through the shipping classifier rather than believed, and the two extra `M`-branch
cases and the `A`-branch case are recorded in the amendments below. The fix is a mode conjunct on
the arms that mean "nothing to do", deriving theirs' bit from `git ls-tree`, which is the same
source of truth `apply.sh`'s `sync_mode_from_theirs()` reads. **The arm reorder the entry's own
receipt accepted was measured to be a REGRESSION and was rejected**; the receipt was replaced with
one that separates the two mode-only consumers, and a mode-aware hash — the filing's alternative —
was built and rejected on its measured fanout into the `A` and `D` branches. New fixture
`core/fixtures/preclassify-mode-bucket` (9 cases, 8 mutants, an unmutated control) is green on the
fix and exit 1 on an unfixed tree. Filed `BL-099` and `BL-100` on the way through.

**A mode-only upstream change buckets `UPSTREAM-ONLY` even when the consumer copy is already
identical to `theirs` in content AND mode, so step 2's termination subtraction can never drop it.**
Driven behaviourally through the shipping `preclassify.sh` on a synthetic three-ref case, with a
reachability control in the same invocation:

```
base   100644 blob 273a402f0f8b  core/rules/modeonly.sh
theirs 100755 blob 273a402f0f8b  core/rules/modeonly.sh     <- same blob, mode only
M  core/rules/modeonly.sh  .claude/rules/modeonly.sh  UPSTREAM-ONLY        <- ARM
M  core/rules/content.sh   .claude/rules/content.sh   ALREADY-AT-THEIRS    <- CONTROL
```

The consumer copy of `modeonly.sh` was written with `theirs`' content and `chmod 755` — fully in
sync, nothing left to apply — and still classified as work to do. The control is a genuine content
change whose consumer copy is already at `theirs`; it reaches `ALREADY-AT-THEIRS` in the same run,
so the bucket is reachable and the harness is sound.

The cause is arm order at `core/skills/ai-dlc-update/reconcile/preclassify.sh:309-312`:
`ours_h = base_h -> UPSTREAM-ONLY` is tested at `:310`, before `ours_h = theirs_h ->
ALREADY-AT-THEIRS` at `:311`. `blob_hash()` at `:120` is `git rev-parse <ref>:<path>`, a blob sha,
and `file_hash()` at `:121` is `git hash-object` — both content-only, so a mode-only change makes
all three hashes equal and the earlier arm shadows the later one. The `A` branch at `:298-301` has
no `ours_h = base_h` arm and the `D` branch's arms are not co-reachable this way, so the `M` branch
is the only one affected.

**The consequence is verbatim the one `SKILL.md` names.** `SKILL.md:292-303` — unchanged at HEAD —
says "EMPTY is a CONTENT question, not a diff question — or this step never terminates", and closes
"drop from the slice every path whose consumer copy already matches `theirs`. Do not hand-roll that
comparison: `reconcile/preclassify.sh` already buckets exactly this as `ALREADY-AT-THEIRS`. The
slice is the sliced paths MINUS those." A mode-only path is one whose consumer copy DOES already
match `theirs`, and the one bucket that paragraph delegates to is the one it cannot enter.

**The filing is wrong about its own escape hatch, in the direction that changes which fix a reader
picks.** Its alternative fix reads: make the hash mode-aware, "but then `apply` must actually
restore the mode, which it does not do today." That clause is false at HEAD.
`sync_mode_from_theirs()` at `apply.sh:196-201` derives the bit from `git ls-tree` (`100755 ->
chmod +x`, `100644 -> chmod -x`) and is called at `:257` on the temp before the atomic swap, and an
EXEC-BIT AUDIT at `:1049-1090` re-checks every upstream-100755 path after the apply. Control in the
same corpus: `apply.sh` is the only file under `reconcile/` naming `chmod` at all. So the mode-aware
alternative is more viable today than the filing says. Everything else in the filing reproduces.

The receipt asserts the BUCKET, not the arm order, and takes either fix: the reorder produces
`ALREADY-AT-THEIRS` because `ours_h = theirs_h` is then tested first, and a mode-aware hash produces
it because the fully-synced consumer copy then matches `theirs` exactly. Verified satisfiable in the
same invocation: an `awk` line-swap of `:310` and `:311` on a copy — asserted byte-different from
the shipping file first — takes the receipt to exit 0 with the control still green. A structural
line-order anchor was rejected: the fix is a reorder of two existing lines, so no token is added or
removed, but a reformat of the surrounding `case` would move it with no behavioural change.

**AMENDED at v0.423.0 — the entry is WIDER than filed, in three ways, all measured through the
shipping classifier on synthetic three-ref repos.** (a) The same shape holds in the
`100755 -> 100644` direction, which the filing does not mention. (b) A path whose content
already matches theirs but whose bit does NOT reaches `ALREADY-AT-THEIRS` at the arm BELOW the
one filed, and is dropped from the worklist, so the chmod is never delivered — and that one is
SILENT in the `100644` direction, because the exec-bit audit inspects only upstream-100755
paths. (c) The `A` branch's `ALREADY-PRESENT` has the identical defect. All four rows are
repaired by one mode conjunct on the arms that mean "nothing to do".

**AMENDED — THE RECEIPT BELOW REPLACES ONE THAT CERTIFIED A REGRESSION, and that is the
transferable finding.** The original asserted only that a mode-only change with the consumer
copy already at `755` reaches `ALREADY-AT-THEIRS`. The entry's own prose said it "takes either
fix", and it did: a bare swap of the `ours_h = base_h` and `ours_h = theirs_h` arms took it to
exit **0**. That swap is a REGRESSION — with a mode-only change every content hash is equal, so
a bare `ours_h = theirs_h` cannot separate the consumer that already has the bit from the one
that still needs it, and answers "nothing to do" for both. Measured across three trees built by
`git archive HEAD`, asserted pairwise-different before the verdicts were read: original receipt
`head 1 / reorder 0 / conjunct 0`; replacement `head 1 / reorder 1 / conjunct 0`. **A receipt
that accepts either of two candidate fixes has not established which one it accepts** — the
replacement carries both mode-only consumers in ONE invocation, so no implementation can satisfy
it by collapsing them. It also pins `core.fileMode true` on its own scratch repo: under a global
`core.fileMode = false` the `chmod` never reaches the tree, theirs records `100644`, and the
whole case degrades into a no-op that passes — an exit 9 guard on theirs' recorded mode catches
that rather than reporting a false green.

Discharges the consumer entry
`PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPSTREAM-ONLY-SO-THE-SELF-UPDATE-CANNOT-TERMINATE`
at pinned ledger line 3018.


verify: sh D=$(mktemp -d); P=core/skills/ai-dlc-update/reconcile/preclassify.sh; export GIT_AUTHOR_NAME=p GIT_AUTHOR_EMAIL=p@p GIT_COMMITTER_NAME=p GIT_COMMITTER_EMAIL=p@p; mkdir -p "$D/d/core/rules" "$D/c/.claude/rules"; git -C "$D/d" init -q; git -C "$D/d" config core.fileMode true; for f in synced needsbit content; do printf "body\n" > "$D/d/core/rules/$f.sh"; chmod 644 "$D/d/core/rules/$f.sh"; done; printf "old\n" > "$D/d/core/rules/content.sh"; git -C "$D/d" add -A >/dev/null; git -C "$D/d" commit -qm base >/dev/null; B=$(git -C "$D/d" rev-parse HEAD); chmod 755 "$D/d/core/rules/synced.sh" "$D/d/core/rules/needsbit.sh"; printf "new\n" > "$D/d/core/rules/content.sh"; git -C "$D/d" add -A >/dev/null; git -C "$D/d" commit -qm theirs >/dev/null; T=$(git -C "$D/d" rev-parse HEAD); [ "$(git -C "$D/d" ls-tree "$T" -- core/rules/synced.sh | cut -c1-6)" = 100755 ] || { rm -rf "$D"; exit 9; }; printf "body\n" > "$D/c/.claude/rules/synced.sh"; chmod 755 "$D/c/.claude/rules/synced.sh"; printf "body\n" > "$D/c/.claude/rules/needsbit.sh"; chmod 644 "$D/c/.claude/rules/needsbit.sh"; printf "new\n" > "$D/c/.claude/rules/content.sh"; O=$(bash "$P" "$D/d" "$B" "$T" "$D/c" 2>&1); rm -rf "$D"; g() { LC_ALL=C awk -F"\t" -v n="$1" '$2 ~ n {print $4}' <<<"$O"; }; [ "$(g content)" = ALREADY-AT-THEIRS ] || exit 1; [ "$(g synced)" = ALREADY-AT-THEIRS ] || exit 1; [ "$(g needsbit)" = UPSTREAM-ONLY ]
## BL-101 — half of `v0.423.0`'s fix can be reverted and the fixture stays green

**LANDED (v0.424.0, verified 98ad402e).** `CASE_TABLE` now carries a per-case expected STATUS
instead of a blanket `M`, and six `A`-branch cases: the consumer-absent add, both mode-matched
siblings as adjacent controls, both mode-mismatched directions, and a both-added case. The
mutation battery gained the `A`-branch reverts and its mode-derivation mutant spans both branches
now. Green on the shipped tree at 5s; exit 1 on the `A`-reverted copy, naming `A3` and `A5`.
**The receipt read 1 while the fix sat uncommitted** — it extracts `git archive HEAD`, which
cannot see a working-tree change, so the flip to 0 came with the commit rather than with the fix.
Filed and closed in one cycle.

**`core/fixtures/preclassify-mode-bucket` guards the `M`/rename branch and nothing else, but the
fix it was built for changed TWO branches.** Its `CASE_TABLE` is nine cases, every one asserted
by `S2` to be status `M` in the `base..theirs` diff. The `A` branch's `ALREADY-PRESENT` arm — item
(c) of `BL-033`'s own amendment, and one of the four rows that release repaired — has no case, no
mutant and no assertion anywhere in the battery.

Measured by reverting exactly the `A`-branch half on a `git archive HEAD` copy (the `ALREADY-PRESENT`
conjunct dropped and the `UPSTREAM-ONLY-ADD` fall-through deleted, with the `M`-branch conjunct
asserted still present in the same invocation, so this is the `A` half alone):

```
fixture vs the shipped tree                     exit 0   <- control, the harness works
fixture vs dropbase   (delete the base_h arm)   exit 1   killed by C5
fixture vs halfmode   (100755 direction only)   exit 1   killed by C4
fixture vs arevert    (the A-branch half gone)  exit 0   <- SURVIVES
```

**`C5` and `C4` are the reason this is filed narrowly rather than as "the battery is weak".** The
same sweep that found this proposed four implementations that satisfy `BL-033`'s receipt; the
fixture independently kills three of them, because it carries an ordinary-content-change case and
both mode directions. It is a good battery with one uncovered branch, not a broken one.

**This is the repo's own recurring defect, in work this repo shipped hours earlier.** A guard that
cannot fire reads exactly like a guard that passed, and the `A`-branch arm now has a green suite
standing behind it while asserting nothing.

**Candidate fix**: one `A`-status case pair — a net-new upstream file at `100755` whose consumer
copy is byte-identical at `644` (`-> UPSTREAM-ONLY-ADD`), and its mode-matched sibling at `755`
(`-> ALREADY-PRESENT`) as the adjacent control — plus a mutant that reverts the `A` conjunct and
is killed by exactly that pair. `S2` asserts every case is status `M`, so it needs a per-case
expected status rather than a blanket one; that is the only structural change. False-positive set
NOT yet measured.

**Provenance.** Found by the receipt hand of batch 14, as finding (e) of an attack on `BL-033`'s
replacement receipt. Three of its other four findings are real against the RECEIPT and already
covered by the FIXTURE — that split was measured by the lead, not taken from the report. The
receipt itself is archived with `BL-033` and is not the live guard, which is why this entry is
about the fixture.

Tiered **DEFECT**. Not a `PC-` candidate, so it ranks below the PC-backed set — but it is a hole in
`v0.423.0`'s own guard, which is an argument for taking it early.

verify: sh F=core/fixtures/preclassify-mode-bucket/run.sh; P=core/skills/ai-dlc-update/reconcile/preclassify.sh; [ -f "$F" ] && [ -f "$P" ] || exit 9; D="$(mktemp -d)" || exit 9; git archive HEAD 2>/dev/null | tar -x -C "$D" || { rm -rf "$D"; exit 9; }; grep -q 'ALREADY-PRESENT' "$D/$P" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$F" >/dev/null 2>&1 ) || { rm -rf "$D"; exit 9; }; perl -0pi -e 's/^(\s*elif \[ "\$ours_h" = "\$theirs_h" \] && mode_at_theirs [^\n]*ALREADY-PRESENT[^\n]*\n)(\s*elif \[ "\$ours_h" = "\$theirs_h" \];\s*then bucket="UPSTREAM-ONLY-ADD"[^\n]*\n)/      elif [ "\$ours_h" = "\$theirs_h" ];    then bucket="ALREADY-PRESENT"\n/m' "$D/$P" || { rm -rf "$D"; exit 9; }; cmp -s "$D/$P" "$P" && { rm -rf "$D"; exit 9; }; bash -n "$D/$P" 2>/dev/null || { rm -rf "$D"; exit 9; }; grep -q 'mode_at_theirs "$path" "$cons"; then bucket="ALREADY-AT-THEIRS"' "$D/$P" || { rm -rf "$D"; exit 9; }; ( cd "$D" && bash "$F" >/dev/null 2>&1 ); rc=$?; rm -rf "$D"; [ "$rc" -ne 0 ]

## BL-030

**LANDED (v0.426.0, verified 5cc6c4f5).** The guard now withholds on `mech_fail` OR an
outstanding hand-back count taken in `say()` itself, and withholds the marker clear with it;
`apply.sh --finish` is the terminating exit, and `SKILL.md` step 7 instructs it. The `:1251`
arm this entry flagged as NOT covered by its receipt is covered after all, in the direction
that was available: under `--finish` the hook-registration check runs BEFORE the stamp, where
its answer is verified by a validator rather than attested, so the one `WORKLIST` site that
structurally could not reach the stamp predicate now does on the invocation where it means
something. The ordinary run's ordering is unchanged, for the reason its own comment gives.

**`apply.sh` writes the re-stamp and clears the mid-pull marker on any run whose only guard,
`mech_fail`, is zero — and that guard is declared in the file itself to exclude outstanding
`WORKLIST` hand-backs, so a tree with unfinished semantic merges is stamped as being at THEIRS and
has its fixture suite re-enabled.** `core/skills/ai-dlc-update/reconcile/apply.sh:1109` is
`if [ "$mech_fail" -gt 0 ]; then` and nothing else; `:261-266` states the exclusion in terms —
"NOT the same as the declared hand-backs: a WORKLIST semantic-merge or an operator DECISION is work
the caller completes in this same run, and the stamp is still true once it does." Measured over the
file: **10** `say WORKLIST` emission sites and **0** lines tallying them, against **16**
`mech_fail=` assignments found by the same grammar in the same invocation — so the absence is
established, not merely searched for. The else-branch at `:1174-1185` then emits
`RESOLVED restamp`, `rm -f "$APPLYING"` and `RESOLVED consistent "the tree matches …; fixture suite
re-enabled"`.

Clearing that marker is the part the filing does not name and it is the wider half.
`APPLYING="$CONSUMER/.claude/.ai-dlc-applying"` (`:146`) is the consumer's own mid-pull block:
`core/git-hooks/pre-push:667` refuses the fixture suite while it exists, and its comment at `:644`
states the contract this breaks — "clears `.claude/.ai-dlc-applying` only when it writes the
re-stamp, so while that marker exists the tree is a mixture of two releases … REFUSE rather than
skip: a skipped suite is the green light nobody earned." With semantic merges outstanding the tree
is exactly that mixture, and the marker is gone.

The filing's stated cause is false and the correction is to a different cause, not a wider or
narrower one. It says "apply.sh does it first" and "the prose ordering and the driver ordering
disagree". Against the working tree the re-stamp is last: 9 of the 10 `say WORKLIST` sites (354,
356, 439, 581, 583, 589, 591, 626, 648) precede the guard at 1109, and the declared-token gate at
`:884` precedes it too. The defect is the guard's PREDICATE SCOPE, not statement order. The filing
also declares `verify: manual` on the reasoning that "no substring predicate distinguishes
'restamp is emitted last' from 'restamp is emitted'; the receipt is the relative position of two
lines in the driver's own output" — also false, and it is why this entry had no mechanical receipt
for a year: the withholding condition is one named variable on one line and is directly checkable.

The filing's ordering claim does survive in one place, and it is worth recording because the
receipt below does not cover it. The tenth `say WORKLIST` site is at `:1251` — the
hook-registration row, "hook(s) present and UNREGISTERED after this apply … on disk, wired to
nothing, and indistinguishable from one that is working." It runs strictly after the marker clear
at `:1184` and after `RESOLVED consistent` at `:1185`. No predicate at the stamp can account for a
row emitted after it, so closing that arm means moving the hook-registration check above the stamp,
which is a second and different change. The receipt gates only the predicate-scope arm; an operator
confirming a close should read `:1251` before annotating.

The anchor is the guard line's condition count plus the absence of any worklist tally, disjoined so
that either plausible fix shape turns it green — a second condition on the guard, or incrementing
a counter at the `say WORKLIST` sites. It deliberately does not anchor on the rationale comment at
`:261-266`, which is the obvious target and the known-bad one: fixes in this repo document what
they removed, so that sentence would survive inside the comment recording its own reversal.

**THAT ANCHOR WAS THE DEFECT, AND THE RECEIPT BELOW REPLACES IT. Disjoining so that "either
plausible fix shape turns it green" is the same sentence as "this receipt cannot tell a fix from a
regression", one clause apart, and it was written as a convenience.** Scored at v0.426.0 against
six implementations built as real edited copies, each proved to differ from its parent before the
cell was read: the correct fix **0**, a second spelling of the correct fix **0**, the unfixed
program **1** — and then `if [ "$mech_fail" -gt 0 ] || [ "$mech_fail" -gt 999 ]; then`, which
withholds nothing new, **0**; and a bare `worklist_note=0` inserted at the top of the file,
changing no behaviour whatever, **0**. Both disjuncts were satisfiable by text that resolves
nothing. This is the `BL-033` shape a release earlier — an entry whose own text tells you its
receipt takes either fix — and it is now two for two.

The replacement keys on the EMISSION SITE and on a relationship rather than on a spelling. It
reads the counter name out of `say()`'s own `WORKLIST` case, requires that name to appear in the
two lines preceding the `say DECISION restamp-withheld` call, requires `--finish)` to be a
recognised option, and requires the single `rm -f "$APPLYING"` to lie between the withheld row and
the `restamp-failed` row — which is what a partial fix breaks. Scores: correct **0**, second
spelling **0**, unfixed **1**, both trivial regressions **1**, and a partial fix that withholds the
stamp while hoisting the marker clear out of the read-back **1**. Precondition arm proved
reachable in three states (no file, empty file, `say()` present with no restamp rows), all **3**.

**The citations here are as filed and two of them do not resolve.** Re-derived at v0.426.0:
`apply.sh:146`, `:884`, `:1184` and `:1251` are exact; `:1109` is the `say` row and the guard it
names is `:1108`; and `core/git-hooks/pre-push:667`/`:644` resolve to unrelated lines — the marker
refusal is `applying_guard` at `:751`, its contract comment at `:710-716`. The claim was true; only
the line numbers had moved.

Discharges the consumer entry `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` at pinned
ledger line 1977.


verify: sh bash -c 'a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$a" ] || exit 3; s=$(LC_ALL=C grep -n "^say() {" "$a" | head -1 | cut -d: -f1); w=$(LC_ALL=C grep -n "say DECISION restamp-withheld" "$a" | head -1 | cut -d: -f1); f=$(LC_ALL=C grep -n "say DECISION restamp-failed" "$a" | head -1 | cut -d: -f1); [ -n "$s" ] && [ -n "$w" ] && [ -n "$f" ] && [ "$w" -gt 2 ] && [ "$f" -gt "$w" ] || exit 3; v=$(LC_ALL=C sed -n "$((s+1)),$((s+8))p" "$a" | LC_ALL=C sed -n "s/.*WORKLIST[^)]*)[[:blank:]]*\([a-z_][a-z_]*\)=\$((.*/\1/p" | head -1); [ -n "$v" ] || exit 1; LC_ALL=C grep -q "\$$v" <<<"$(sed -n "$((w-2)),$((w-1))p" "$a")" || exit 1; LC_ALL=C grep -q -- "--finish)" "$a" || exit 1; [ "$(LC_ALL=C grep -c "rm -f \"\$APPLYING\"" "$a")" = 1 ] || exit 1; c=$(LC_ALL=C grep -n "rm -f \"\$APPLYING\"" "$a" | head -1 | cut -d: -f1); [ "$c" -gt "$w" ] && [ "$c" -lt "$f" ] || exit 1; exit 0'
## BL-104 — gate-validation Check 2 blocked on any unresolved HARD_BLOCK ever filed, with no sprint or relevance scope

**LANDED (v0.428.0, verified 1e129935).** Check 2's blocking clause is scoped by the entry header's sprint, a past-sprint HARD_BLOCK is surfaced at implementation/story/retro gates and still blocks at planning and sprint-review, and an entry naming no sprint blocks everywhere.

**Discharges `PC-S306-CHECK-2-HAS-NO-SPRINT-SCOPE`, filed by the reference consumer in
sprint 306.** Check 2's rule read *"If any entry has status `HARD_BLOCK` and is not RESOLVED,
do NOT proceed"* and named no sprint, story or path scope anywhere in its body. Measured over
the check's whole span with a control in the same invocation: `grep -ci sprint` = **0**,
control `grep -c HARD_BLOCK` = **4**. So any unresolved `HARD_BLOCK` ever filed in
`docs/escalations/pending.md` blocked every gate of every later sprint, including one with no
relationship to the blocker's subject.

**The cost is measured, not hypothesised.** On the reference consumer, during a live
production bug-fix sprint, a nine-day-old sprint-303 finding about a declined UI refactor and
a CI alias-table gap FAILed the implementation gate. The mechanism to release it existed
(Check 2's own `DEFERRAL_REQUEST` branch), but reaching it cost a full extra operator
round-trip on a completely unrelated topic at the worst moment to ask for one.

**The scoping predicate was already one check away.** Check 2a's body says *"legacy sprints
are out of scope, so the gate does not wedge on old data"*, and
`core/scripts/validate-escalation-resolution.sh:160` implements it as
`header ~ ("[Ss]" sprint "([^0-9]|$)")`. Check 2 sat directly above it, over the same corpus,
unscoped.

**The escape hatch this creates is closed in the same change, and that is the load-bearing
half.** A stale `HARD_BLOCK` that stops blocking is a `HARD_BLOCK` you can outrun by waiting
one sprint. So a past-sprint entry is SURFACED at an `implementation`, `story` or `retro` gate
and still BLOCKS at every `planning` and `sprint-review` gate — the boundary where the
operator is already dispositioning scope. An entry whose header names no sprint blocks at
every gate; an unknown sprint is not a past one.

Tiered **DEFECT**. It cost the operator a live incident interruption, and the failure mode is
the gate correctly enforcing a rule whose scope was never written down.

**The receipt is bullet-partitioned and that is not cosmetic.** A span-level grep for `sprint`
over Check 2's body is satisfied by any sentence anywhere in the check — scored against a
build that adds one HTML comment to the span and changes nothing else, a span-level receipt
returns 0. This one partitions the span into bullets and fails any bullet that issues a
`HARD_BLOCK` do-not-proceed directive without a sprint qualifier in that same bullet. Scored
against five builds: the shipped fix **0**, a second spelling by a different author **0**, the
pre-fix body **1**, a straight revert **1**, and the comment-only prose attack **1**. Exits 9
if the span extractor returns fewer than 10 lines, so a renamed heading reports a moved
precondition rather than a false close.

verify: sh g=core/skills/ai-dlc/steps/gate-validation.md; [ -f "$g" ] || exit 9; span=$(awk '/^### 2\. No unresolved/{s=1;next} /^### 2a\./{s=0} s' "$g"); [ "$(printf '%s\n' "$span" | grep -c .)" -ge 10 ] || exit 9; bad=$(printf '%s\n' "$span" | awk 'function p(){ if (b ~ /HARD_BLOCK/ && b ~ /do NOT/ && b !~ /[Ss]print/) print "UNSCOPED" } /^- /{ if (b != "") p(); b = $0; next } { b = b " " $0 } END { if (b != "") p() }'); [ -z "$bad" ]

---

## BL-105 — a suppression declared by its fields is discarded in silence when the status line's first token is something else

**LANDED (v0.428.0, verified 5d66d9f7).** An entry carrying `**Suppresses:**` or `**Expires after:**` while classifying as anything other than `SUPPRESSED` is reported, and the verdict line carries `malformed_attempt=`.

**Discharges `PC-S306-SUPPRESSED-STATUS-FIRST-TOKEN-SILENT-NO-OP`, filed by the reference
consumer in sprint 306.** `core/scripts/validate-suppression-lifetime.sh:183` reads the
disposition as `if (match(s,/[A-Z_]+/)) status=substr(s,RSTART,RLENGTH)` — the first
uppercase run after `**Status:**` — and the `case` that branches on it has no else. An entry
whose status line reads `DECIDED_AUTONOMOUSLY (root cause), with a SUPPRESSED marker on
Check 22 below.` classifies as `DECIDED_AUTONOMOUSLY`, and its `**Suppresses:**`,
`**Expires after:**` and `**Operator authorization:**` fields are never read. `entries_scanned`
increments, `suppressed` does not, and the run reports PASS.

**The failure is silent on both sides.** The tool's output was identical for "no suppressions
this pass" and "one suppression attempted and silently dropped", and the entry reads as
resolved to a human skimming the file, because the parenthetical literally contains the word
`SUPPRESSED`.

**Both directions the candidate proposed were built and measured, and both are unshippable.**
Requiring the `**Status:**` line to be exactly one vocabulary token rejects most of the
corpus — a suppression conventionally carries `SUPPRESSED (operator, <ts>)`. Flagging a second
vocabulary token elsewhere on the line scores **5 of 108** status lines on the reference
consumer's `pending.md` and **all five are false**: four are `DECIDED_AUTONOMOUSLY (…) — not a
HARD_BLOCK` and one is `DEFERRAL_REQUEST (items 3 and 5 only; item 2 already RESOLVED BY FACT
below)`. The negation and the intent are the same shape to that rule, so it cannot separate the
true positive from its own false positives. **Both filed directions passing their own reading
and failing on the corpus is the finding, not a detail of it.**

**The shipped arm keys on the FIELDS.** `**Suppresses:**` and `**Expires after:**` are
adjudicated for exactly one disposition, so an entry carrying either while classifying as
anything other than `SUPPRESSED` has had its authorization discarded. False-positive set
measured on the reference consumer: **0 of 123 entries**, against a control of **16** entries
that do classify `SUPPRESSED`. The verdict line carries `malformed_attempt=` so the two states
the tool used to conflate are now distinguishable in its own output.

**Sited above the `case`, not as its else**, because `RESOLVED`/`OVERRIDDEN` match an earlier
branch and an else-shaped arm cannot reach the same discard through them.

Tiered **DEFECT**. An operator authorization is adjudicated by nothing and no party is told.

Guarded by `core/fixtures/suppression-lifetime` assertions 17–21 and MUTANT F, which demotes
the predicate to one that can never hold and must kill assertion 17 while leaving the lifetime
arms green. The receipt is three-armed and was scored against five builds — the shipped fix
**0**, a second spelling `[ -n "${supp}${expires}" ]` **0**, a regression that drops the field
predicate **1**, a regression that demotes the arm into the `case` **1**, and the unfixed
subject on `origin/main` **1**.

verify: sh v=core/scripts/validate-suppression-lifetime.sh; [ -f "$v" ] || exit 9; d=$(mktemp -d); printf '## E\n**Status:** DECIDED_AUTONOMOUSLY (x), with a SUPPRESSED marker below.\n**Suppresses:** `2`\n**Expires after:** 2 gates\n**Operator authorization:** 2026-01-01T00:00:00Z | "ok"\n' > "$d/a.md"; printf '## E\n**Status:** RESOLVED (the SUPPRESSED marker below carries it)\n**Suppresses:** `2`\n**Expires after:** 2 gates\n**Operator authorization:** 2026-01-01T00:00:00Z | "ok"\n' > "$d/b.md"; printf '## E\n**Status:** DECIDED_AUTONOMOUSLY (x), not a HARD_BLOCK and not a SUPPRESSED entry.\n' > "$d/c.md"; bash "$v" --escalations "$d/a.md" >/dev/null 2>&1; r=$?; bash "$v" --escalations "$d/b.md" >/dev/null 2>&1; s=$?; bash "$v" --escalations "$d/c.md" >/dev/null 2>&1; t=$?; rm -rf "$d"; { [ "$r" = 2 ] || [ "$s" = 2 ] || [ "$t" = 2 ]; } && exit 9; [ "$r" -ne 0 ] && [ "$s" -ne 0 ] && [ "$t" -eq 0 ]

---

## BL-106 — the propagation-fanout corpus is tracked-only, so every artifact a remediator writes mid-sprint is invisible to it

**LANDED (v0.428.0, verified 2fb3d244).** The corpus is tracked plus `--others --exclude-standard`, de-duplicated, with the untracked share printed in band. The `@SPRINT@` half is a second subject and stays open.

**Discharges `PC-S306-FANOUT-UNTRACKED-FILES-INVISIBLE`, filed by the reference consumer in
sprint 306.** `core/scripts/report-propagation-fanout.sh:253` built its mutable corpus from
`git ls-files -z`, which lists TRACKED files only. The consumer commits planning and
implementation artifacts at PR time, so every artifact a remediator writes or edits DURING a
sprint is untracked at the moment this script runs, and invisible to both the corpus scan and
`git diff -U0 <base>`.

**The caller is the gate remediation loop, which runs mid-sprint by construction, so this was
not an edge case — it was the tool's only operating condition.** Reproduced: a run over a tree
that held two new files at exactly the right sprint-scoped path printed `SCOPING FAILURE:
sprint 306 was declared, but not one corpus file came from its artifact directory` and exited
3. The wrong-tree exit, fired on the right tree, and a scoping failure reads identically for
"wrong tree" and "right tree, nothing staged yet".

**The header's original justification was a real measurement and it was the wrong KIND of
measurement.** It read *"Untracked scratch under `docs/` is not an artifact anyone cites, and
including it made the corpus 47% larger without moving the worklist"* — a COST argument, taken
over one consumer's untracked set at one instant, which is the population that varies most. It
is superseded by a measurement of the CORRECTNESS cost, and the superseding is recorded beside
it rather than replacing it silently.

**`--exclude-standard` is load-bearing and the figure is measured, not asserted.** On the
reference consumer `git ls-files --others` alone lists **84371** paths, **12640** of them under
the two corpus roots (build output, caches, `node_modules`); with `--exclude-standard` that same
tree contributes **0**, against a control of **10666** tracked files. The admitted share is now
printed in band on every run, because a one-instant measurement of another consumer's untracked
set cannot be carried across consumers.

**`git ls-files` can emit one path twice** (an unmerged path lists once per stage), so the
corpus is de-duplicated in document order. A duplicate would double-count a citation into the
worklist.

Tiered **DEFECT**. The script is advisory and non-gating by its own docstring, so it blocked
nothing — but it could not fulfil its stated purpose for any consumer that does not commit
mid-sprint artifacts, and it failed silently, through an exit code that names the wrong cause.

**The `@SPRINT@` half of the candidate is a SECOND SUBJECT and it is not closed here.** Upstream
also reports that the consumer's `_bmad-output/implementation-artifacts/` is flat, so the
script's `_bmad-output/implementation-artifacts/@SPRINT@` root can never match anything in that
layout regardless of tracked state, and it asks the consumer be consulted on whether that
directory is meant to be flat or per-sprint before the root shape is assumed. That is a question
for the consumer, not a distribution-side measurement, so it stays open and this entry does not
claim it.

Guarded by `core/fixtures/fanout-untracked-corpus`, which drives the shipping script through a
`git` shim and carries mutants for both halves of the change.

**The receipt sets `AI_DLC_PROJECT_ROOT`, and without it the receipt measures the WRONG TREE.**
`report-propagation-fanout.sh:213` does `cd "$AI_DLC_ROOT"`, resolved by walking up from the
script's own directory — so a probe repo built under `mktemp` and entered with `cd` is silently
ignored and the run reports on the distribution. The first cut of this receipt did exactly that
and its worklist cited `docs/backlog.archive.md`. Three arms, scored against five builds: the
shipped fix **0**, a second spelling using `git status --porcelain` **0**, the unfixed subject
**1**, a regression dropping `--exclude-standard` **1**, and a regression that collects the
untracked half and never unions it into the corpus **1**.

verify: sh s=core/scripts/report-propagation-fanout.sh; [ -f "$s" ] || exit 9; s="$(cd "$(dirname "$s")" && pwd)/$(basename "$s")"; d=$(mktemp -d) || exit 9; ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t && mkdir -p docs _bmad-output/planning-artifacts/s901 && printf 'seed\n' > docs/a.md && git add docs/a.md && git commit -qm base && printf 'x `docs/a.md:1` y\n' > docs/b.md && git add docs/b.md && git commit -qm second ) >/dev/null 2>&1 || { rm -rf "$d"; exit 9; }; r() { ( cd "$d" && AI_DLC_PROJECT_ROOT="$d" bash "$s" HEAD~1 --sprint s901 ) 2>/dev/null; }; printf 'cites `docs/a.md:1`\n' > "$d/_bmad-output/planning-artifacts/s901/note.md"; r >/dev/null; ok=$?; n1=$(r | sed -n 's/^  mutable corpus: \([0-9]*\) files.*/\1/p'); mkdir -p "$d/docs/ignored"; printf 'docs/ignored/\n' > "$d/.gitignore"; printf 'cites `docs/a.md:1`\n' > "$d/docs/ignored/j.md"; n2=$(r | sed -n 's/^  mutable corpus: \([0-9]*\) files.*/\1/p'); rm -rf "$d/docs/ignored" "$d/.gitignore" "$d/_bmad-output/planning-artifacts/s901/note.md"; r >/dev/null; ctl=$?; rm -rf "$d"; [ "$ok" = 2 ] && exit 9; [ -n "$n1" ] && [ -n "$n2" ] || exit 9; [ "$ok" -ne 3 ] && [ "$ctl" -eq 3 ] && [ "$n1" -eq "$n2" ]

---

## BL-107 — `--series` accepts only the remediator's repair-record name, so a lead-authored resolution reads as MISSING

**LANDED (v0.428.0, verified af3515ed).** `gate-<type>-resolution-p<M>.md` is accepted alongside the repair name, the `gate-` anchor is kept, and the structure requirement is unchanged.

**Discharges `PC-S306-SERIES-VALIDATOR-NO-LEAD-RESOLUTION-PATH`, filed by the reference
consumer in sprint 306.** `core/scripts/validate-gate-adjudication.sh:688` globbed
`gate-*-repair-p<M>.md` and nothing else when deciding whether a pass-to-pass FAIL shrink was
backed by a record. That is the REMEDIATOR artifact-repair convention:
`core/hooks/ai-dlc-gate-remediation-guard.sh` requires a real remediator `agent_id` and a bound
edit to produce one.

**A FAIL can close without a remediator, and the same guard says so.** It leaves
`docs/escalations/**` and `*-resolution-p*.md` LEAD-editable. Reproduced sprint 306: pass 1
FAILed Check 2 on a stale sprint-303 `HARD_BLOCK`; the lead closed it with a two-line status
edit to `docs/escalations/pending.md`, no gate-log or protected-artifact edit, so no remediator
dispatch was warranted or possible, and pass 2 independently confirmed the resolution. The
lead's only exits were to file a record asserting a dispatch that never happened, or to take a
`MISSING REPAIR RECORD` finding for work correctly done.

`gate-<type>-resolution-p<M>.md` is now accepted alongside the repair name.

**The `gate-` anchor is what makes the widening safe, and dropping it repeats a measured
mistake one suffix over.** `<artifact>-resolution-p<M>.md` is the ADVERSARIAL resolution record
and sits in the same sprint directory with the same pass numbers. Measured on the reference
consumer at depth 2 under `planning-artifacts`: `gate-*-repair-p<M>` **15** files,
`*-repair-p<M>` **113**, `*-resolution-p<M>` **17** — of which **16** are adversarial and
exactly **one** is a gate record. The unanchored form pulls in sixteen foreign records; `gate-*`
pulls in the one meant.

**The accepted NAME widened; the STANDARD did not.** A record still has to carry
`disposition:`, `edit:` and `derivation:` read literally, so `MISSING REPAIR RECORD` keeps its
subject: a FAIL repaired with no record on disk still fires. **And the consumer's own
`gate-implementation-resolution-p1.md` states its disposition, edit site and derivation in
PROSE and labels none of them, so it scores UNSTRUCTURED under this arm** — that is a finding
about the consumer's record, not a reason to relax the standard, and the fixture's `(h)` case
says it out loud.

Tiered **DEFECT**. A false `MISSING REPAIR RECORD` on a genuinely-resolved FAIL trains a lead
to fabricate remediator dispatches, which is pure overhead with no correctness benefit and
poisons the corpus the arm reads.

Guarded by `core/fixtures/gate-repair-record` cases (f), (g) and (h), and by
`core/fixtures/gate-repair-record-mutants`, which scores five mutants — removing the resolution
suffix, its anchor, its structure check, or the subject itself each kills the one case that
owns that property. **Case (g) is seeded STRUCTURED on purpose**, which is harder than the real
corpus where none of the 16 adversarial records are: a seed that leaned on their being
unstructured would leave the anchor untested, because the arm would still say UNSTRUCTURED and
the mutant would come back green.

**The receipt drives the shipping validator against the fixture's own seeded corpus, four arms.**
Scored against five builds: the shipped fix **0**, a second spelling using two concatenated
globs **0**, the unfixed subject **1**, a regression dropping the `gate-` anchor **1**, and a
regression dropping the structure requirement **1**. Exits 9 if the seed does not produce the
four case directories, so a reshaped fixture reports a moved precondition rather than a false
close.

verify: sh V=core/scripts/validate-gate-adjudication.sh; S=core/fixtures/gate-repair-record/seed.sh; [ -f "$V" ] && [ -f "$S" ] || exit 9; R=$(bash "$S") || exit 9; [ -n "$R" ] && [ -d "$R" ] || exit 9; g() { bash "$V" --series "$R/$1/_bmad-output/gate-adjudication" >/dev/null 2>&1; }; for k in gate-repaired-lead-resolution gate-repaired-adversarial-resolution-only gate-repaired-inline-no-record gate-repaired-resolution-off-label; do [ -d "$R/$k/_bmad-output/gate-adjudication" ] || { rm -rf "$R"; exit 9; }; done; g gate-repaired-lead-resolution; a=$?; g gate-repaired-adversarial-resolution-only; b=$?; g gate-repaired-inline-no-record; c=$?; g gate-repaired-resolution-off-label; d=$?; rm -rf "$R"; [ "$a" = 2 ] && exit 9; [ "$a" -eq 0 ] && [ "$b" -ne 0 ] && [ "$c" -ne 0 ] && [ "$d" -ne 0 ]

---

## BL-108 — an entering gate is treated as one monolithic blocker on the next step, so a FAIL on a check the next step never reads serialises the whole dispatch

**LANDED (v0.428.0, verified a00076c3).** Section 6 carries a numbered action list conditioning the routing on the next step's read-set, and Section 7's completion condition names the entering gate.

**Discharges `PC-S306-GATE-REMEDIATION-BLOCKS-INDEPENDENT-DEV-DISPATCH`, filed by the reference
consumer in sprint 306.** Rule 4 — *"do not jump to the next step file until the current step's
execution sequence is complete and its gate validation has passed"* — plus
`core/skills/ai-dlc/steps/bug-investigation.md:134`'s literal sequencing read as a strict gate:
`implementation.md` Section 2 does not begin until every escalated check on the entering
`implementation` gate has PASSed.

**The checks are heterogeneous and nothing said so.** Some gate bookkeeping the next step does
not consume; others gate content it needs. Reproduced sprint 306: Check 22 (Teammate-spawn role
binding, which reads `_bmad-output/spawn-ledger.jsonl` and role contracts, not the story or its
acceptance criteria) FAILed on a pre-ledger defect and took three adjudication passes across two
sprints to close. The lead ran the whole repair-and-reverify cycle serially before dispatching
the story's dev, and the two only ran in parallel because the operator asked an ETA question that
prompted the lead to notice.

**The fix is prose in the two step files, and the schema extension upstream suggested was
rejected on measurement.** That direction adds a per-check `blocks_next_step` field to
`core/skills/ai-dlc/enforcement-map.yaml`. That file carries **57** per-check entries, so it is
57 hand-assigned judgments about what the next step reads, and a check added later without one
is a silent hole. It is also the file `scripts/validate-enforcement-map.sh` validates, which the
fixture suite's POLE invokes — measured at **20.3s** on this tree before any change, and
`CLAUDE.md` records one arm added there as a nested loop taking that validator 13.0s → 18.1s and
the whole suite to ten minutes. **The decisive reason is neither of those.** The value is a
judgment about the NEXT STEP's read-set, which the lead has in front of it at the moment of the
FAIL; a declared value goes stale the first time a check's remediation changes what it writes,
and a stale one authorises skipping a gate that check does gate. A wrong `blocks_next_step: []`
is worse than no field.

**The escape hatch is closed in the same change, and that is the load-bearing half.**
`implementation.md` Section 7's completion condition now names the ENTERING gate: no story lands
and the sprint does not complete until that gate PASSes, including any check whose repair was
dispatched in parallel with the routing. Without that, "route now, repair in parallel" is a way
to finish a sprint over a FAIL.

Tiered **DEFECT**. It costs real wall clock on every FAIL that lands on a check the next step
does not read, and nothing in the step files distinguished the two classes.

**The receipt partitions Section 6 by NUMBERED ACTION rather than scanning its span**, because
the bold sentence introducing the rule contains the same words as the condition and survives a
regression that guts the numbered item beneath it — scored, that build returns 0 under a
span-level receipt. Two arms, scored against five builds: the shipped fix **0**, a second
spelling that rewords both the introduction and the numbered item **0**, the unfixed pair **1**,
a regression shipping the parallel dispatch while reverting Section 7's land bar **1**, and a
regression making the routing unconditional **1**. Exits 9 if either span comes back shorter
than its minimum, so a renamed heading reports a moved precondition rather than a false close.

verify: sh B=core/skills/ai-dlc/steps/bug-investigation.md; I=core/skills/ai-dlc/steps/implementation.md; [ -f "$B" ] && [ -f "$I" ] || exit 9; s6=$(awk '/^### 6\. Gate Validation/{s=1;next} /^### 7\./{s=0} s' "$B"); s7=$(awk '/^### 7\. All Gates Passed/{s=1} s' "$I"); [ "$(printf '%s\n' "$s6" | grep -c .)" -ge 3 ] || exit 9; [ "$(printf '%s\n' "$s7" | grep -c .)" -ge 2 ] || exit 9; printf '%s\n' "$s6" | awk 'function p(){ if (b ~ /^[0-9]+\./ && b ~ /[Rr]oute/ && b ~ /the next step (does not consume|reads|needs)/) f=1 } /^[0-9]+\. /{ p(); b=$0; next } { b=b" "$0 } END{ p(); exit f?0:1 }' || exit 1; grep -qiE 'entering gate' <<<"$s7"

---

## BL-109 — the stub-audit marker set treats `Phase [0-9]` as an unfinished-work token, so ordinary prose fails Check 16

**LANDED (v0.428.0, verified ab311230).** `Phase [0-9]` requires a statement of absence on the same line; the other four markers require nothing, and the alternative is narrowed rather than deleted.

**Discharges `PC-S306-STUB-AUDIT-PHASE-N-MATCHES-WORD-BOUNDED-PROSE`, filed by the reference
consumer in sprint 306 while this batch was being written.** `core/scripts/validate-stub-audit.sh`'s
marker set was `(stub|TODO|FIXME|wired later|Phase [0-9]|NotImplementedError)`. Four of those five
are unfinished-work tokens; the fifth is an ordinary English noun phrase that any codebase with
numbered delivery phases writes in ordinary prose.

**It is DISTINCT from `PC-S303-STUB-AUDIT-MARKER-REGEX-MATCHES-LOCAL-VAR-NAMED-STUB`, and the
adjacent fix does not close it.** That entry proposes word-boundary anchoring on `stub`.
`Phase 4` in `"""Alert Evaluator — Harmonization Phase 4 (Stories 103-1 and 103-2)."""` is
already word-bounded on both sides, so a `\b` fix leaves this false positive exactly as it was.

Reproduced sprint 306: that module docstring predated story 306-1 and had never been audited;
Check 16 FAILed on it and clearing the gate took a dedicated commit rewording
`"Harmonization Phase 4"` to `"Harmonization work"` — **a factual historical phase reference
deleted to satisfy a detector.** The consumer's own commit `35cf53978` is that workaround, in
its history. A consumer-owned file has no exemption; the only one is upstream ownership.

**`Phase [0-9]` is kept and NARROWED, not deleted, and that choice is measured.** It is a stub
marker only inside a statement of ABSENCE, so it now requires an absence phrase on the same
line while the other four markers require nothing. Deleting it outright was built and rejected:
a real deferral written only as a phase reference stops being seen by anything, and a detector
that cannot fire reads exactly like one with nothing to find.

**The narrowing, measured over both trees with a control in the same invocation.** Over tracked
hot-path files (`.py .ts .tsx .js .sh .sql`) — **377** here and **1754** on the reference
consumer — the lines where `Phase [0-9]` is the SOLE matcher number **19** here and **129**
there; requiring the absence phrase takes those to **1** and **8**. Control: an impossible token
returns 0 on both. **That is a line-level count over whole files and is a FLOOR relative to what
the script sees**, which decomments each line and applies the upstream-ownership exemption
first; the fixture enumerates the survivors rather than describing them.

**`exposed` was in the absence vocabulary and was removed**, because it was the one term that
kept a prose line firing — *"... does NOT belong here and is not exposed to the same fault"*,
the sentence the check's own body records as having failed a consumer gate four times. Nothing
is lost: a genuine "not yet exposed" is carried by `[Nn]ot yet`.

**The absence vocabulary is a FLOOR, not a closed set.** A deferral phrased outside it is a
false NEGATIVE against a check whose other four markers still run. A false POSITIVE has no
escape hatch for a consumer-owned file and its only remediation is rewording true prose.

**Nothing is being reversed.** The marker set came in wholesale from the reference consumer's
own hand-written check and carried no measurement; nothing recorded chose the bare alternative
over the narrowed one.

Tiered **DEFECT**. Its remediation is to delete true information from a consumer's source.

Guarded by `core/fixtures/check-15-bypass` arms V13, V14 and V16 and three mutants — the bare
alternative restored (killed by V13), the alternative deleted outright (killed by V14), and a
marker OUTSIDE the phase rule dropped (killed by V15, which no other arm here notices).

**The receipt drives the shipping script over three seeded files rather than grepping its
regex**, so it survives any spelling of the fix. Three arms, scored against five builds: the
shipped fix **0**, a second spelling reordering the absence vocabulary and adding a synonym
**0**, the unfixed subject **1**, a regression restoring the bare alternative **1**, and a
regression deleting the alternative outright **1**. Exits 9 on any exit-2 refusal, so a missing
resolver reports a moved precondition rather than a false close.

verify: sh v=core/scripts/validate-stub-audit.sh; [ -f "$v" ] || exit 9; v="$(cd "$(dirname "$v")" && pwd)/$(basename "$v")"; d=$(mktemp -d) || exit 9; mkdir -p "$d/src"; printf '"""Alert Evaluator — Harmonization Phase 4 (Stories 103-1 and 103-2)."""\n\ndef f():\n    return 1\n' > "$d/src/prose.py"; printf 'def g():\n    # Deferred to Phase 2: the pool scoping lands with the evaluator.\n    return None\n' > "$d/src/deferral.py"; printf 'def h():\n    raise NotImplementedError()\n' > "$d/src/bare.py"; r() { ( cd "$d" && AI_DLC_PROJECT_ROOT="$d" bash "$v" --root "$d" "src/$1" ) >/dev/null 2>&1; }; r prose.py; a=$?; r deferral.py; b=$?; r bare.py; c=$?; rm -rf "$d"; { [ "$a" = 2 ] || [ "$b" = 2 ] || [ "$c" = 2 ]; } && exit 9; [ "$a" -eq 0 ] && [ "$b" -eq 1 ] && [ "$c" -eq 1 ]
## BL-110 — a hook-appended context block is indistinguishable from adversarially-shaped text of the same form

**Discharges `PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL`.** Filed by the reference
consumer, session-level rather than against a repo script, and its subject is the transcript
form itself.

**Nine hooks under `core/hooks/` emit `additionalContext`, and it reaches the lead as an
unsolicited `system-reminder` block attached to a turn it did not ask for.** Text arriving
through a file read, a fetched page or a subagent's returned report reaches the lead in the
SAME form. Nothing separated the two: no checksum, no tool-call correlation, no origin tag.

**The cost is measured, not hypothetical.** Mid-sprint, a lead facing a merge plus a live
production deploy met a block of unsolicited `system-reminder` content, had no cheap way to
establish where it came from, and took the only action available — paused the pipeline, set
`pipeline-paused.flag`, and asked the operator to re-confirm authorization. Both facts were
already established, so the pause produced no information and cost several turns during a
production incident.

**The wrong fix is "trust unsolicited content more".** That trades a real security property
for speed. The right one is a check the lead can run itself, so a pause is spent on an anomaly
that needs one.

**Fix**: `core/hooks/ai-dlc-context-provenance.sh`, a sourced library. Every emission opens
with a marker line carrying a nonce; the nonce is appended to
`_bmad-output/.ai-dlc-context-nonce`, which the lead reads and compares. `SessionStart`
rotates it and restates the contract — the only event that recurs after a compaction, and
therefore the only carrier a resident rule file could not have been. The store is append-only
and verification is by MEMBERSHIP, so a concurrent rotation cannot make a correctly-marked
block fail. Every call site is fail-open: a hook that cannot mark its output still emits it.
**I98** binds the fleet in both directions and **I13**'s registration arm now derives its
library exemption from the source join rather than a name list.

**What it does NOT establish is in the library's header and is part of the fix**: it cannot
authenticate blocks the harness itself generates, so an unmarked block is unattributed rather
than hostile; and it is not a signature, because anything that has read this transcript has
read the nonce.

**THE MARKER HAS TO BE A LINE, AND THE FIRST CUT MADE IT ONE ONLY BY ACCIDENT.** Call sites
spelled it `"$(ai_dlc_provenance_tag ...)$body"`; command substitution strips trailing newlines,
so the body was glued onto the marker's own line. Measured: a line-anchored match scored **0** on
a real `PreToolUse` emission and **1** on the library's own output. The contract tells the lead
the block opens with the marker LINE, so that spelling made the check the contract describes fail
on correct output. It hid because the only hook probed first is SessionStart-only, where the tag
emits two lines and the CONTRACT paragraph absorbed the glue instead. `ai_dlc_provenance_wrap`
now owns the newline and `I98` fails the push on a hook that calls the tag directly — the
affordance removed rather than the violation policed.

**LANDED (v0.429.0, verified 7133e404).**

verify: sh L=core/hooks/ai-dlc-context-provenance.sh; [ -f "$L" ] || exit 9; d=$(mktemp -d) || exit 9; ( CLAUDE_PROJECT_DIR="$d"; export CLAUDE_PROJECT_DIR; . "$L" || exit 9; S="$d/_bmad-output/.ai-dlc-context-nonce"; t=$(ai_dlc_provenance_tag probe SessionStart) || exit 9; case "$t" in "[AI-DLC-HOOK-PROVENANCE "*) ;; *) exit 1 ;; esac; n=$(printf '%s' "$t" | sed -n 's/.*nonce=\([0-9a-f][0-9a-f]*\).*/\1/p' | head -1); [ -n "$n" ] || exit 1; [ -f "$S" ] || exit 1; s=$(cat "$S"); case "$s" in *"$n"*) ;; *) exit 1 ;; esac; case "$s" in *deadbeefdeadbeef*) exit 1 ;; esac; case "$t" in *"PROVENANCE CONTRACT"*) exit 1 ;; esac; t2=$(ai_dlc_provenance_tag probe PreToolUse); case "$t2" in *"nonce=$n"*) ;; *) exit 1 ;; esac; case "$t2" in *"PROVENANCE CONTRACT"*) exit 1 ;; esac; t3=$(ai_dlc_provenance_tag probe SessionStart); case "$t3" in *"nonce=$n"*) exit 1 ;; esac; s2=$(cat "$S"); case "$s2" in *"$n"*) ;; *) exit 1 ;; esac; w=$(ai_dlc_provenance_wrap probe PreToolUse "$(printf 'body one\nbody two')") || exit 1; a=$(printf '%s\n' "$w" | grep -cE '^\[AI-DLC-HOOK-PROVENANCE .*\]$' || true); [ "${a:-0}" = 1 ] || exit 1; g=$(printf '%s' "$(ai_dlc_provenance_tag probe PreToolUse)body one"); ga=$(printf '%s\n' "$g" | grep -cE '^\[AI-DLC-HOOK-PROVENANCE .*\]$' || true); [ "${ga:-0}" = 0 ] || exit 1; case "$w" in *"body two"*) ;; *) exit 1 ;; esac; wc=$(ai_dlc_provenance_wrap probe SessionStart "" contract); case "$wc" in *"PROVENANCE CONTRACT"*) ;; *) exit 1 ;; esac; wn=$(ai_dlc_provenance_wrap probe SessionStart ""); case "$wn" in *"PROVENANCE CONTRACT"*) exit 1 ;; esac; exit 0 ); r=$?; rm -rf "$d"; [ "$r" -eq 9 ] && exit 9; [ "$r" -eq 0 ] || exit 1; u=""; for f in core/hooks/*.sh; do case "$f" in *ai-dlc-context-provenance.sh) continue ;; esac; e=$(awk '!/^[[:space:]]*#/' "$f"); case "$e" in *additionalContext*) ;; *) continue ;; esac; case "$e" in *"ai_dlc_provenance_wrap "*) ;; *) u="$u $f" ;; esac; case "$e" in *"ai_dlc_provenance_tag "*) u="$u $f" ;; esac; done; [ -z "$u" ]

---

## BL-112 — the warning against naming a primary-tree path for a worktree teammate lives in the one role that is never worktree-isolated

**Discharges `PC-S306-WORKTREE-DELIVERABLE-PATH-AMBIGUOUS-PRIMARY-VS-WORKTREE`.**

**A worktree-isolated dev dispatch asked its teammate to write to a worktree path "resolved
relative to the primary tree" — two filesystem roots for one file, in one sentence.** The
teammate wrote inside its own worktree, which is correct and is what the role contract says
happens. The lead's `wait-for-deliverable.sh` beat then watched the primary-tree path, which
could not exist until the branch merged, and the merge is downstream of the join.

**The equivalent warning already existed, at `core/team-roles/adversary.md:81-89`** — "an
absolute output path handed to a worktree-isolated agent resolves inside that agent's own
worktree". That file is the ONE role told never to run worktree-isolated, so the warning sat
where it could not fire, and nothing warned the LEAD authoring a dispatch that IS
worktree-isolated. This is the shape this repo calls a check that cannot fire, in a role file.

**Measured cost**: the dev's fix was complete and idle in about seven minutes; the beat sat
reporting non-delivery, was re-armed twice, and the real state took three separate reads to
reconstruct. Caught only because the operator asked whether the wait was still appropriate.

**Fix**: item 7 of the worktree-explicit dev dispatch protocol in
`core/skills/ai-dlc/steps/implementation.md`. A worktree-isolated teammate's deliverable path
is always relative to its own worktree root; the lead MUST NOT name a primary-tree path for a
file that teammate is to produce, and reads the file after the merge instead. Two consequences
are stated with it because the second is where the cost landed: do not arm a beat on a
primary-tree path for a worktree dispatch, and a beat reporting non-delivery is not evidence
the teammate is working. Sited in the numbered action list rather than beside it, because that
is where the executor decides deliberately and the operator can see the branch.

**LANDED (v0.429.0, verified 7133e404).**

verify: sh I=core/skills/ai-dlc/steps/implementation.md; [ -f "$I" ] || exit 9; s=$(awk '/^\*\*Worktree-explicit dev dispatch/{f=1} /^\*\*Bounded-join/{f=0} f' "$I"); [ -n "$s" ] || exit 9; [ "$(printf '%s\n' "$s" | grep -cE '^[0-9]+\. ')" -ge 7 ] || exit 9; printf '%s\n' "$s" | awk 'function p(){ if (b ~ /^[0-9]+\./ && b ~ /own worktree/ && b ~ /MUST NOT/ && b ~ /wait-for-deliverable/) f=1 } /^[0-9]+\. /{ p(); b=$0; next } /^[[:space:]]/{ if (b != "") b = b " " $0; next } { p(); b="" } END{ p(); exit f?0:1 }'

## BL-111 — the wait beat's output was identical whether a teammate was working or had gone idle without delivering

**Discharges `PC-S306-WAIT-BEAT-CANNOT-DISTINGUISH-SLOW-FROM-NEVER`.**

`wait-for-deliverable.sh`'s only vocabulary was `WAITING ... not yet delivered` / `DELIVERED`.
A teammate that finished its real work and went idle — having written its answer to a path the
beat was not watching — produced text byte-identical to one still in progress, beat after beat.
**The identity is what did the damage**: the lead re-armed the same beat twice against an
unchanging false negative and only found out because the operator asked whether the wait was
still appropriate.

**The blind spot is general, not specific to the dispatch-wording mistake that exposed it.** A
crash after partial delivery, a role that returns text instead of a file, or a path typo in
either direction all produce the identical silent-forever symptom.

**A liveness signal IS reachable from a shell, which the entry was not sure of.** The harness
writes each teammate's transcript under `~/.claude/projects/<slug>/<session-id>/subagents/*.jsonl`,
`CLAUDE_CODE_SESSION_ID` is exported into a hook's environment, and the newest mtime across
those files is the time since any teammate in this session took a turn. Verified independently
of the change: the directory exists for a live session and holds one file per teammate.

**Fix**: the beat reports `TEAMMATE IDLE, DELIVERABLE ABSENT` when no teammate has taken a turn
within the threshold and the watched paths are still absent, `LIVENESS a teammate took a turn N
ago` when one has, and `LIVENESS unavailable` when no transcripts are reachable. The WAITING
line also carries the beat count and the elapsed time since the join armed, so consecutive beats
are no longer byte-identical.

**The threshold is measured, not picked** — over 1,337 real teammate transcripts, gaps beyond
1200s occur in 0.0036% of turns. The report errs toward UNDER-reporting: one live teammate
suppresses the idle report for the whole wave, and an absent transcript directory reads as
`unavailable`, never as idle. An absent signal reported as idleness would be the false direction
that re-dispatches a working teammate.

**LANDED (v0.429.0, verified 7133e404).**

verify: sh W=core/scripts/wait-for-deliverable.sh; [ -f "$W" ] || exit 9; W="$(cd "$(dirname "$W")" && pwd)/$(basename "$W")"; d=$(mktemp -d) || exit 9; mkdir -p "$d/tm" || exit 9; r() { ( cd "$d" && AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_TEAMMATE_IDLE_SECS=60 AI_DLC_TEAMMATE_DIR="$1" CLAUDE_PROJECT_DIR="$d" bash "$W" docs/never.md ) 2>&1; }; : > "$d/tm/a.jsonl"; touch -t 202001010000 "$d/tm/a.jsonl"; stale=$(r "$d/tm"); : > "$d/tm/a.jsonl"; fresh=$(r "$d/tm"); none=$(r "$d/absent"); rm -rf "$d"; case "$stale$fresh$none" in *WAITING*) ;; *) exit 9 ;; esac; case "$stale" in *"TEAMMATE IDLE"*) ;; *) exit 1 ;; esac; case "$fresh" in *"TEAMMATE IDLE"*) exit 1 ;; esac; case "$fresh" in *LIVENESS*) ;; *) exit 1 ;; esac; case "$none" in *"TEAMMATE IDLE"*) exit 1 ;; esac; case "$none" in *LIVENESS*) ;; *) exit 1 ;; esac; exit 0

---
## BL-114 — core prescribes a gate-evidence path whose sprint token is invisible to the invariant that forbids it

**LANDED (v0.430.0, verified c1f594b4).**

**Consumer provenance: `PC-S306-GATE-REVIEW-ARTIFACTS-WRITTEN-OUTSIDE-SPRINT-SLOT`.** The
consumer recorded the same defect class on two sprints, s304 and s306, each time discovered at
push time and never at write time.

`artifact-path-grammar.md` rule 2 forbids a sprint token in any basename, and **I82** enforces
that over core's own prescriptions — corpus `core/skills/ai-dlc/steps/*.md`,
`core/skills/ai-dlc/*.md`, `core/team-roles/*.md`. `core/team-roles/code-reviewer.md` prescribed
`docs/reviews/<story-id>-review.md`, which is IN that corpus and PASSED, while the path it
expands to on a real sprint is a violation.

**Measured, with a positive control in the same invocation.** Against the ERE I82 resolves from
`core/scripts/artifact-path-config.sh --token-re-prescribed`:

```
FLAGGED   sprint-<N>.md            control: the ERE sees a VISIBLE placeholder
FLAGGED   s306-story-1-gate1.md    control: the EXPANDED form is a real violation
not-seen  <story-id>-review.md     the prescription core actually shipped
not-seen  story-<id>-<slug>.md     the same class
```

`artifact-path-grammar.md` already documents this limit and hands it to the consumer-side
`validate-artifact-paths.sh` at PUSH time. That posture is what cost the consumer two sprints:
the file is written, passes gate-1 and gate-2 and an 18/18 sprint-review gate, and surfaces as a
`VERDICT: FAIL` buried among roughly 160 checks mid-deploy, blocking a push already authorized.

**The QA half is an ABSENCE, not a wrong prescription.** `core/team-roles/qa.md` prescribed no
gate-evidence path at all, so the role invented one and the invented name carried the sprint.
An unprescribed path is where the writer guesses, and the guess is what rule 2 forbids.

**No reader keyed on the old basename shape** — every programmatic reader of `docs/reviews/` is
area-level (`docs/reviews/**`) or is a grammar enforcer, so rewriting the prescription broke no
glob. The conforming destination is not invented either: `core/fixtures/artifact-path-migration/run.sh:129`
already derives `docs/reviews/S301-1-code-review.md` -> `docs/reviews/s301/1-code-review.md`.

**`code-reviewer-escalated.md` needed no edit** — it delegates to `code-reviewer.md` in full and
deliberately holds no second copy.

verify: sh [ -n "$(grep -E "docs/reviews/s<N>/" core/team-roles/code-reviewer.md | grep -v "^[[:space:]]*<!--")" ] && [ -n "$(grep -E "docs/reviews/s<N>/" core/team-roles/qa.md | grep -v "^[[:space:]]*<!--")" ] && ! grep -qE "docs/reviews/<story-id>-review\.md" core/team-roles/code-reviewer.md

## BL-115 — core states a harness behaviour as unconditional fact, and a retro check scores a COMPLETE audit as mis-scoped on the strength of it

**LANDED (v0.430.0, verified 1046eb6d).**

**Consumer provenance: `PC-S306-RETRO-AUTOCOMPACT-TRANSCRIPT-FILE-ASSUMPTION-UNVERIFIED`.**

`steps/retro.md` stated that *every handoff and every auto-compact starts a new transcript
file*, and gated its steerability audit on it: `transcripts scanned : N` **must be > 1 on any
sprint that handed off OR auto-compacted**, with N=1 scored as a mis-scoped audit.

**The auto-compact half is false on Claude Code, measured here on an independent corpus.** All
174 `.jsonl` transcripts under this repo's own project directory, keyed on a STRUCTURAL
`isCompactSummary: true` field rather than a substring — the substring is contaminated, because
this repo's sessions discuss compaction in prose and 2 of 4 substring hits carried no such
field. Two files hold a real boundary. **Both sit MID-FILE**: record 1318 of 2845 and record
2067 of 3590, with 1317 and 2066 records of conversation before them, ~1500 after, and ONE
unchanging `sessionId` spanning both sides. A compaction continues in the same file.

So a sprint that auto-compacted but never handed off legitimately reports N=1, and the rule
scored that as mis-scoped. The HANDOFF half stands and was kept.

**The claim sat at FOUR sites, one more than the candidate names**, including the `--cite`
deadlock comment which reasoned FROM it. The fourth now cites the usage block rather than
restating it.

**The consumer's own suggested remedy would have shipped a silent false confirmation.** It
pointed at `find -newermt <ISO>` as the way to confirm N=1 is complete. **BSD `find` REJECTS
the `Z`-suffixed ISO-8601 form** `--since` takes — `find: Can't parse date/time`, exit 1, empty
stdout — which is byte-identical to a window holding no transcript and reads as confirmation of
exactly the narrow scan being checked for. The space-and-offset form is prescribed instead, with
an instruction to read the exit status.

verify: sh ! grep -rqiE "handoff and (every )?auto-compact starts a new" core/ && [ -n "$(awk "/N must be greater than 1 on/,/mis-scoped/" core/skills/ai-dlc/steps/retro.md | grep -i "HANDED OFF")" ] && [ -z "$(awk "/N must be greater than 1 on/,/mis-scoped/" core/skills/ai-dlc/steps/retro.md | grep -i "auto-compact")" ] && grep -q newermt core/skills/ai-dlc/steps/retro.md
## BL-116 — `wait-beat-liveness`'s delivered case arms its join AFTER writing the deliverable, and fails only under pool load

**LANDED (v0.430.0, verified 5e864a38).**

**DEFECT. Found by batch 18's gate run, which it refused.** No consumer provenance — this is
an ai-dlc-internal discovery.

**IT WENT ON TO BLOCK THE MERGE PUSH TOO — 2 of 5 pushes on the branch — so it was fixed
rather than carried.** The load-dependent reproduction was replaced by a deterministic one:
injecting a 2s gap between the write and the beat forces it every time, and the differential
is decisive — with `--since` PASS and 0 failures, without it FAIL and 2 failures byte-identical
to the gate's own. The fix is the subject's documented escape hatch and `--since` is CLAMPED to
pull the threshold only EARLIER, so it widens nothing the subject would otherwise enforce.

`core/fixtures/wait-beat-liveness/run.sh:317-318` writes `deliv.md` and THEN arms the join:

```
printf 'answer\n' > "$W/deliv.md"
beat "$SUBJ" "$W" 60 "$TD"
```

The subject deliberately refuses a file that predates the arming instant — *"this join waits
for a write NEWER than the arming instant. A file that predates the join cannot be shown to be
THIS dispatch's answer."* That refusal is correct and is the behaviour the fixture elsewhere
asserts. So the delivered case passes only while the write and the arming instant land close
enough together to be indistinguishable, and it fails when they do not.

**It is load-dependent, which is why it has survived.** Measured: 3 of 3 runs PASS solo on this
branch AND 3 of 3 PASS solo on `origin/main`; under the pre-push pool at width 12 it was the
single red unit of 174. A fixture that is green solo and red under the pool is invisible to
every way an author checks their own work.

**NOT caused by the branch that found it**, established by read-set rather than by inspection:
the fixture's subject set is `{core,scripts}/…/wait-for-deliverable.sh`, and the intersection
with this branch's 13 changed files is EMPTY, against a positive control — the one fixture the
branch does change appears in that same comparison.

**Candidate fix**: arm the join before creating the deliverable, or pass the dispatch instant
via `--since`, which is the escape hatch the subject already documents for exactly this shape.
The receipt takes either, because both make the ordering sound; it does NOT take a sleep,
which would leave the same race with a wider window.

**The receipt was REPLACED after an adversarial pass closed the first one two ways without
changing anything.** Both holes are recorded because both are general:

- `grep -q -- "--since"` over the whole window was satisfied by a COMMENT — and the comment a
  reader would naturally write is a paraphrase of this entry's own candidate-fix sentence, so
  the entry was steering its reader into closing it vacuously. `--since` occurs 0 times in the
  window today, so that clause was inert and would have become the entire verdict the moment
  anyone typed it. It now requires `--since` on a NON-COMMENT line.
- The write anchor `/deliv[.]md"$/` also matched the TEARDOWN `rm -f "$W/deliv.md"` below the
  subject. Redirect the real write to a variable and the anchor silently re-points at a line
  that is always after the beat, and the receipt passes forever with the race untouched. It now
  anchors on a REDIRECTION into the deliverable, and when that anchor stops resolving it exits
  **9** — measured — rather than 0, so a moved subject reports "I measured nothing" instead of
  a close.

Scored against six cases: unfixed HEAD 1, both real fixes 0, comment-only 1, sleep 1,
variable-redirect 9. No mutant reaches 0 without the ordering actually being sound.

verify: sh s=$(grep -n "^S5_delivered_is_silent()" core/fixtures/wait-beat-liveness/run.sh | cut -d: -f1); [ -n "$s" ] || exit 9; e=$((s+30)); f=core/fixtures/wait-beat-liveness/run.sh; w=$(awk -v s="$s" -v e="$e" "NR>=s && NR<=e && /> *\"[\$]W\/deliv[.]md\"/{print NR; exit}" "$f"); bt=$(awk -v s="$s" -v e="$e" "NR>=s && NR<=e && /beat \"[\$]SUBJ\"/{print NR; exit}" "$f"); [ -n "$bt" ] || exit 9; sn=$(awk -v s="$s" -v e="$e" "NR>=s && NR<=e && /--since/ && \$0 !~ /^[[:space:]]*#/{print NR; exit}" "$f"); [ -n "$sn" ] && exit 0; [ -n "$w" ] || exit 9; [ "$w" -gt "$bt" ]

## BL-118 — a recorded verdict suppressed the remedy it authorizes

**LANDED (v0.433.0, verified 2f9bb771).**

**`apply.sh` matched the adjudication token's PRESENCE and suppressed the whole ATOMIC
override-retire sequence for it.** `adj_v` was extracted and used for exactly one thing —
interpolation into the NOTE — so the row asserted a property of the verdict on a code path that
never read the verdict. The message is the proof rather than a symptom: *"No retire steps are
emitted: acting on them would undo a decision, not complete one"* is true of `still-additive` and
false of the other two members. The register's vocabulary has three
(`core/schemas/layer-adjudication-register.json:35-37`), and `adj_lookup()`
(`core/skills/ai-dlc-update/reconcile/layer-drift.sh:615`) clears on any conforming record, so
**the suppression fired at 2 of 3**. On a `retire`, acting COMPLETES the decision; on a
`contradicts-core` the register records that the override contradicts core and the remedy is then
suppressed. Recording the honest verdict is what made the remedy unreachable, and no verdict
existed that both told the truth and left the steps emitted.

**A second failure was invisible from outside the code and arrives WITH the branch.** The detail
field's tokens are an ordered prefix parsed positionally
(`core/skills/ai-dlc-update/reconcile/apply.sh:625-641`) and the adjudication token sits ahead of
them, so a row falling through with it still attached misses both `replaces_with=` and
`retire_anchor=`. Measured against the shipping loop, one input, strip present and deleted:

```
detail = adjudicated=retire :: retire_anchor=steps/retro.md#4a :: core moved
  with strip: WORKLIST override-retire — remove the anchor `steps/retro.md#4a` … leave its
              other anchors byte-untouched
  without:    WORKLIST override-retire — core supersedes this entry: adjudicated=retire :: …
```

The second row is obeyed by deleting an override file that core superseded ONE anchor of, which
is the outcome `apply.sh:607-612` exists to forbid. It could not occur while the arm always
`continue`d.

**The provenance is the mirror image, and that is the lesson.** `apply.sh:558-567` names the
motivating case: a recorded `still-additive` overrun by a prescribed step 2 that would have
deleted 119 consumer-only lines, filed as `PC-S327`. That fix generalised from one member to the
whole vocabulary without asking what the exemption ACQUITS — the same shape as `I99` at
`v0.430.0`, one release earlier.

Filed by the reference consumer as
`PC-S307-RECORDED-VERDICT-SUPPRESSES-THE-REMEDY-IT-AUTHORIZES`, hit live on its
`0.427.0 -> 0.430.1` pull. Tiered **DEFECT**: it silences a remedy rather than prescribing a wrong
one, and the consumer had to reason its way out of a state where no honest verdict worked.

The receipt DRIVES the shipping loop rather than grepping it, so no comment, rename or doc line
closes it. It runs the loop twice from one extraction — once on a `retire` verdict, which must
produce the anchor-narrowing row, and once on the keep verdict, which must NOT. **The second
drive is not symmetry.** Scored against five constructions in one invocation, a receipt fed only
the `retire` case scores the over-correction — emit the sequence for every verdict, `PC-S327`
back — as FIXED. With both: the committed fix 0, a `case`-arm-on-the-literal spelling of the same
behaviour 0, the live defect 1, a mutant naming all three members in the NOTE text 1, the
over-correction 1, an unread second assignment of the verdict 1. Exit 9 if the loop cannot be
located, so a reshaped file reports a moved precondition rather than a false close.

verify: sh set -e; a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$a" ] || exit 9; t=$(mktemp -d); sed -n '/^while IFS="$TAB_CH" read -r ovr detail; do$/,/^EOF$/p' "$a" > "$t/l.sh"; [ -s "$t/l.sh" ] || exit 9; { echo 'TAB_CH="$(printf "\t")"'; echo 'say(){ printf "%s %s %s\n" "$1" "$2" "$4"; }'; echo 'ADJ_ROW_TOKEN=adjudicated'; echo 'ADJ_KEEP_VERDICT=still-additive'; echo 'LD_SUP="$(printf "overrides/x.md\t%s" "$D")"'; echo '. "$T/l.sh"'; } > "$t/d.sh"; r=$(T="$t" D='adjudicated=retire :: retire_anchor=A :: p' bash "$t/d.sh" 2>&1) || exit 9; k=$(T="$t" D='adjudicated=still-additive :: retire_anchor=A :: p' bash "$t/d.sh" 2>&1) || exit 9; rm -rf "$t"; case "$k" in *"remove the anchor"*) exit 1 ;; esac; case "$r" in *"remove the anchor"*) exit 0 ;; esac; exit 1

## BL-120 — the handoff's push is a bare `git push`, so a sprint's FIRST handoff cannot succeed

**LANDED (v0.434.0, verified 3bde1ca9).**

**`core/skills/ai-dlc/steps/handoff.md:36-37` prescribes a bare `git push`, and that command
cannot succeed on a branch that has never been pushed** — which is every sprint's first handoff on
a consumer that cuts a branch per sprint. Reproduced by the reference consumer in its live tree, on
the branch it stranded:

```
$ git push --dry-run
fatal: The current branch ai-dlc/carry-over/dashboard-backlog-s307 has no upstream branch.
```

**The failure fallback then routes the defect past itself.** `handoff.md:41-44` says *"If the push
fails (no remote configured, offline, or a protected branch), report it to the operator in one line
and continue; the local commits still stand and the handoff is not blocked."* All three enumerated
causes are environmental and genuinely non-blocking. **An upstream-less branch is none of them** —
it is a defect in the command as written — and *"the local commits still stand"* is separately
false whenever step 2 was also skipped, which is what happened.

**The distribution already knows the right form, one step file away.**
`core/skills/ai-dlc-update/SKILL.md:173` handles this exact state: *"**AUTO-PUSH**: run
`git push -u origin <branch>` to publish it, then proceed."* Two step files, one repo, one state,
two commands, one of which works. Derived, with the control in the same invocation:

```
handoff.md   grep -cF '(`git push`)'                        -> 1   # the bare form, present
handoff.md   grep -cE 'push -u|set-upstream|push origin'    -> 0
SKILL.md     grep -cE 'push -u|set-upstream|push origin'    -> 1   # control: the grammar CAN see it
```

**It composes with `PC-S336`, and each supplies the other's precondition.** This entry guarantees a
never-pushed sprint branch after every first handoff; `PC-S336` means the next bare
`/ai-dlc-update` — no commit, no `apply` argument — silently publishes whatever that branch is. So
a consumer's standing state between its first handoff and its next pull is: durable state stranded
locally, and a dry run that will publish it unasked. Neither is visible from inside a session.
`BL-086` carries the composed root cause with step 2; this is a third strand of the same rope.

**The asymmetry is why it stayed invisible.** Step 1 has a mechanical enforcer —
`core/hooks/ai-dlc-continue.sh` Check 0 blocks the stop while any teammate row reads `in-flight`.
Steps 4 and 5 produce artifacts whose presence IS their verification. **Steps 2 and 3 are the only
two that produce OFF-MACHINE state, and neither has an enforcer.** Measured at `origin/main`:

```
files under core/hooks + core/scripts mentioning "handoff"          14
of those, any reasoning about push/upstream state                    0
control: the same grammar over core/skills/ai-dlc-update/            1   # it can see it where it exists
```

`ai-dlc-continue.sh` returns 6 hits for `push|upstream` and **all six are unrelated prose** —
*"upstream cause"*, *"pre-push"*, *"pushes DELTA"*. Reading the hits rather than trusting the count
is what separates that from a finding.

**What it cost, on the reference consumer.** The handoff ran its bookends and skipped its middle:
step 1 done, steps 4 and 5 done, steps 2 and 3 absent. 19 uncommitted paths, `@{u}` fatal,
`git ls-remote origin <branch>` empty. Among the 19, an entire sprint's
`_bmad-output/planning-artifacts/s307/` and `_bmad-output/party-mode-transcripts/s307/` are
untracked — in git nowhere — plus 8 of 14 staged repairs living only in an ended session's
scratchpad. **The handoff emitted a resume line for a successor with nothing durable behind it.**

Filed by the reference consumer as
`PC-S307-HANDOFF-PUSH-IS-A-BARE-GIT-PUSH-SO-A-FIRST-HANDOFF-CANNOT-SUCCEED`. Tiered **BLOCKER**:
it silently discards a sprint's output, the loss is off-machine and unrecoverable from the session
that caused it, and it fires on a schedule — every sprint's first handoff.

**Whether the predecessor attempted step 3 and took the fallback, or never reached step 3, is NOT
established** — the consumer flagged that as inference rather than finding, correctly, and the
receipt does not depend on which.

The receipt is anchored on the durable prose, not on the defective command, **because the first cut
was anchored on `` (`git push`) `` and a correct fix DELETES that string** — scored, and it returned
9 against the fix rather than 0, reporting a working repair as unmeasurable. Re-anchored it scores:
live **1**; `git push -u origin HEAD` **0**; a `set-upstream` phrasing **0**; the prose reworded
with no fix **9**, which is unmeasurable rather than a false close. Note the consumer's ledger runs
the OPPOSITE polarity to this file — 0 reproduces there, 1 here — so the two receipts are not
interchangeable.

verify: sh set -e; h=core/skills/ai-dlc/steps/handoff.md; [ -f "$h" ] || exit 9; grep -qF "push the current branch to origin" "$h" || exit 9; grep -qE "push -u|set-upstream|push origin" "$h" && exit 0; exit 1

## BL-045

**LANDED (v0.431.0, verified 6060f787).** Closed as bookkeeping in v0.435.0, not fixed by it. The
prescribed change — promoting the `## Machine Audits` heading from `####` to `###` so it stops
sitting inside the `4a. Close-Out Sweep` span — landed at `6060f787`, whose subject says so in as
many words. The entry was never annotated or rotated, so its receipt has reported CLOSE-CANDIDATE
ever since and no release claimed it. Found by running the receipt histogram BEFORE this batch's
own work, which is the only instrument that surfaces a landed-but-unclosed entry.

**Core's `## Machine Audits` table is a `####` child of `### 4a. Close-Out Sweep`, so every
override that shadows §4a deletes the table as a side effect — and core's own §4 delegates into
it too, which no detector can see.** Driven through the shipping resolver
(`core/skills/ai-dlc-update/reconcile/lib.sh:71`, `span_of`), `span_of "4a. Close-Out Sweep"` over
`core/skills/ai-dlc/steps/retro.md` returns **`373 604`**, and that span contains exactly ONE
sub-heading: `core/skills/ai-dlc/steps/retro.md:581`,
``#### `## Machine Audits` — one table, not five transcriptions``. Occurrences of the construct
inside the §4a span: **2**. **Control in the same invocation** — the sibling span
`span_of "4b. Operator-steerability audit"` = `605 705`, occurrences there **0**, so the counter
discriminates rather than answering yes everywhere. The detector that reports the consequence is
live: `OVERRIDE-DELEGATES-INTO-SHADOW` occurs **4** times in
`core/skills/ai-dlc-update/reconcile/layer-drift.sh` (emit site `:1289`); control, the impossible
status `OVERRIDE-DELEGATES-INTO-NOWHERE`, **0** in the same file.

The consumer entry framed the victims as its own two `OVERRIDE-DELEGATES-INTO-SHADOW` rows. **The
correction is WIDER, and it is core's.** `core/skills/ai-dlc/steps/retro.md:290` — "Record the
verdicts in the `## Machine Audits` table (below)" — sits in §4, whose span is `205 334`, while the
table it names is at 581 inside §4a. So core itself holds a cross-section delegation into the
shadowable span. The emit at `layer-drift.sh:1289` fires inside the per-override loop keyed on an
entry's `shadows:` value, so its population is `overrides/` entries; core has no `shadows:` and
never enters that loop. A consumer that shadows §4a therefore drops core's own §4 delegation target
as well as its override's, and **that half is structurally outside every arm's population** — not
merely unreported today, unreportable by this detector's join key.

The entry's remaining claims hold as written. Its middle remedy — "narrow `shadows:` to the
sub-headings actually rewritten" — is genuinely unavailable for an override that rewrites §4a,
because the one sub-heading in the span IS the delegation target; that is the measurement above,
re-derived, not transcribed. Its `verify: manual` reasoning does not carry across the boundary: it
was correct for a consumer ledger grepping a `theirs` ref, and this tree is executable.

**The prescribed fix works when executed**, which is worth stating because it usually does not
here. Promoting line 581 from `####` to `###` — one character, no new prose, so no date, version
tag or origin narrative enters resident text — moves `span_of "4a. Close-Out Sweep"` from
`373 604` to **`373 580`**, drops the construct count inside §4a from 2 to **0**, and makes the
table its own resolvable span `581 604`, addressable by the existing `<file>#<anchor>` key with no
new anchor vocabulary. The two sides were asserted to differ before the comparison was read (`diff`
= 4 lines, the single heading). An unnumbered `###` sibling is already the house form in this file:
`### Empirical gate validation` (335) and `### Sprint-Ship Verification` (706).

Blast radius, measured on a `--local` clone with the promotion applied, both sides asserted
different: `scripts/validate-enforcement-map.sh` output **byte-identical** across the two, and
`section_of`/`span_of` appear in that validator only inside comments, so it cannot resolve a
retro.md heading at all. `core/scripts/audit-rule-files.sh` output **byte-identical** across the
two, all three tier-1 classes `CLEAN` on both. Both validators exit 1 on both sides for
pre-existing tier-2 findings that name other files. The only two fixtures that read the real
`retro.md` are `core/fixtures/check-17-counts/run.sh:49` (provenance block) and
`core/fixtures/enforcement-map-sites/run.sh:1023` (an audit-anchor template string); neither keys
on heading level.

**Why the anchor is the anchor.** The receipt asserts a relation between two spans the shipping
resolver computes, not a substring. The looser form — "does the §4a span still contain the string
`## Machine Audits`" — was probed and **false-OPENS forever**: seeding the fix plus one comment
line above 581 quoting the old heading back (the dominant failure mode in this corpus, since fixes
here document what they moved) leaves **1** occurrence inside the shrunken §4a, so a substring
predicate reports STILL-LIVE against a landed fix. The span predicate returned **0** on that same
seeded tree. Both directions of anchor death report STILL-LIVE rather than closing: renaming the
heading so `span_of` cannot resolve it exits **1**, and removing `lib.sh` exits **1**.

Not a settled decision. `CHANGELOG.md:2517` (v0.334.0) measured this exact span — "231 lines with
exactly ONE sub-heading, at offset 207" — and declined to restructure, but for a different
question: making a non-heading ARM addressable, which needs a declaration format. That section
names `Machine Audits` **0** times; controls in the same section and invocation, `Close-Out Sweep`
**2** and `strikethrough` **1**. The nesting was never adjudicated.

Discharges the consumer entry `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT`
at pinned ledger line 2101.


verify: sh . core/skills/ai-dlc-update/reconcile/lib.sh; F=core/skills/ai-dlc/steps/retro.md; A=$(span_of "4a. Close-Out Sweep" < "$F"); B=$(span_of "## Machine Audits" < "$F"); [ -n "$A" ] && [ -n "$B" ] || exit 1; [ "${B%% *}" -gt "${A##* }" ]
## BL-121 — a validator reported a finding about content it never read, because empty stdout means two opposite things

**LANDED (v0.435.0, verified 15f4f5c8).** Filed and discharged in the same release, which is what the
operator's standing correction asks for: a candidate moved from UNFILED to a `BL-` row and no
further is a number changing, not a defect closing. The receipt scores the shipped validator, not
this file.

**Upstream `PC-S307-AWK-CANT-OPEN-FILE-MISREAD-AS-MISSING-FRONTMATTER`, filed by the reference
consumer off a live `git push`.** A pre-push run from inside a freshly-created `git worktree`
reported 20 ERRORs against exactly two files, both of which declare every key the run named as
missing, with `awk: can't open file` on stderr beside them. The same commit from the normal
checkout gave 0 errors.

`fm()` reads one frontmatter scalar with one `awk` per file per key, and its stdout cannot
distinguish the two states that matter. Measured, all four, with the ok-case as the control:

```
ok          stdout=[x]  rc=0
keyless     stdout=[]   rc=0
unreadable  stdout=[]   rc=2
missing     stdout=[]   rc=2
```

Only the status separates them, and every caller read the value through `$( )`, which discards it.

**The fix takes the status off a read each loop already performs**, at four call sites, and exits 2
with a distinct FATAL rather than reporting a finding about content it never saw. Keyed on the
STATUS and not on a pre-flight `[ -r ]`: the filing declines to say why `awk` could not open a
readable file and names a `worktree add` race as at least as likely as a path bug, and a
readability test cannot cover a file that passes the test and vanishes under the read.

**The fourth site was found by a probe, not by reading.** The `conforms_to` census loop runs before
the override and extension loops, so with the other three guards in place an unreadable entry still
produced exactly one `E17`. Two of the four are sited on a specific read for a reason a later author
would undo: `shadows` is split from `base_sha` because `a=$(x); b=$(y)` reports only y's status, and
the extensions loop guards `kind` and not `hooks` because `$(fm … | awk …)` reports awk's status and
never `fm`'s.

**Measured both directions on the shipped script, seeded root as the subject and the pre-fix copy as
the control in the same invocation:** an unreadable entry gives exit 2 and **0** ERROR lines naming
it, where the pre-fix copy gives exit 1 and **5**. A genuinely keyless entry still takes its normal
missing-key ERROR, so the guard discriminates rather than refusing everything.

**This is not a wedge, and the direction is the reason.** `layer_files()` yields only `*.md` under
`extensions/` and `overrides/`, so an unreadable file there is always a real entry and there is no
irrelevant-file false refusal. A read failure already refused the push; what changes is that the
refusal now names the true cause instead of manufacturing four content findings per file.

**What this does NOT close.** The filing's other half — reproducing the `worktree add` race that
made `awk` fail on a readable file — is untouched and stays open upstream. Do not read a close here
as a close of that.

**The receipt DRIVES the shipped validator and asserts observable behaviour**, rather than grepping
the source, so no comment and no renamed function can satisfy it and any second spelling with the
same behaviour passes — scored: a variant that renames `entry_unreadable` throughout still exits 0.
It refuses (exit 9) rather than reporting a verdict when `chmod 000` did not take, because `chmod`
does nothing for root and a receipt whose seed silently failed would report a false close.

**The receipt shipped here is the THIRD version, and each earlier one was certified by its author
and killed by someone else.** Draft one seeded a single tree; on an ordinary tree the census loop
reaches every entry FIRST and aborts, so a fix guarding that one site alone produces exit 2 and zero
ERROR lines, and the receipt scored it 0. Draft two added a second tree with an unreadable
`layer-contract.yaml` — which empties `LC_CV` and skips the census — and that fixed the narrowness
but left two holes an independent hand found by building the variants: its `grep -c "ERROR.*probe"`
was UNANCHORED and read stderr, so a correct fix whose FATAL happened to open with the word `ERROR`
was REJECTED (today's wording passes by luck, not by property); and `rc=2` alone is satisfied by ANY
early refusal — the pre-fix original plus one unrelated early `exit 2` scored 0, reporting
CLOSE-CANDIDATE on a tree where all four sites still collapse the two facts.

**What closes both is a readable control inside the receipt.** Each of its three trees runs TWICE:
first with the probe readable, requiring at least one `^ERROR ` line naming it — which is what
establishes the run REACHED the probe — then sealed with `chmod 000`, requiring exit 2 and zero.
A run that never got there now fails the control instead of passing the assertion. It probes
readability with `awk '{exit}'` rather than `[ -r ]`, testing the operation that actually fails, and
it distinguishes HARNESS BROKEN from a finding.

**One limitation, stated because it is invisible rather than because it is severe.**
`backlog-reverify.sh:199` maps the status through a single `-eq 0`, so its exit 9 and an ordinary
exit 1 produce a byte-identical STILL-LIVE row. On a box where `chmod 000` does not seal — root —
this receipt reports the defect as still reproducing when in fact nothing was measured. Read a
STILL-LIVE here as "not measured or not fixed", never as a measurement.

**The superseded second draft seeded TWO trees.** On an ordinary tree
the census loop reaches every entry FIRST and aborts, so a fix guarding that one site alone produces
exit 2 and zero ERROR lines — measured, and the one-tree receipt certified it. Tree B makes
`layer-contract.yaml` unreadable, which empties `LC_CV` and skips the census loop entirely; that is
the only state in which the override, extension and live-layer guards are reachable at all. Scored
against the census-only variant: tree A passes, tree B gives exit 1 with 4 ERROR lines, receipt
rejects. A one-tree receipt here would have closed this entry against three of four sites still
broken.

verify: sh V=core/scripts/validate-layer-entries.sh; [ -r "$V" ] || exit 9; D=$(mktemp -d) || exit 9; trap 'chmod -R u+rwX "$D" 2>/dev/null; rm -rf "$D"' EXIT; S="$D/c/.claude/skills/ai-dlc"; mkdir -p "$S/extensions" "$S/overrides" || exit 9; W=0; sc(){ printf '%s\n' "$1" > "$S/layer-contract.yaml" || exit 9; rm -f "$S/extensions/zzprobe.md" "$S/overrides/zzprobe.md"; printf -- '---\ntitle: zzprobe\n---\n' > "$2" || exit 9; awk '{exit}' "$2" 2>/dev/null || { echo "HARNESS BROKEN: $3 probe unreadable before it was sealed"; exit 9; }; C=$(bash "$V" "$D/c" 2>/dev/null | grep -c '^ERROR .*zzprobe' || true); [ "$C" -ge 1 ] || { echo "HARNESS BROKEN: $3 readable control emitted no ERROR naming the probe"; exit 9; }; chmod 000 "$2"; if awk '{exit}' "$2" 2>/dev/null; then echo "HARNESS BROKEN: $3 seal did not take, awk still opens the probe"; exit 9; fi; O=$(bash "$V" "$D/c" 2>/dev/null); R=$?; N=$(grep -c '^ERROR .*zzprobe' <<<"$O" || true); chmod 644 "$2"; echo "$3 control_errors=$C rc=$R errors_naming_probe=$N"; { [ "$R" -eq 2 ] && [ "$N" -eq 0 ]; } || W=1; }; sc 'contract_version: 1' "$S/extensions/zzprobe.md" census; sc 'clauses: []' "$S/overrides/zzprobe.md" overrides; sc 'clauses: []' "$S/extensions/zzprobe.md" extensions; [ "$W" -eq 0 ]
## BL-051

**LANDED (v0.436.0, verified 0b060987).**
**Step 2 computes which machinery paths the consumer has edited and then discards the answer.**
`core/skills/ai-dlc-update/SKILL.md:207` grounds the whole autonomous cycle on "the consumer never
edits them (like `core`)", and instructs the write as "from `theirs` **only the paths that diff
names**". `core/git-hooks/pre-push` is the fourth entry of the `machinery:` list in
`reconcile/setup-sites.md`, and a consumer that has edited its `.githooks/pre-push` gets bucketed
`BOTH-CHANGED->CLASSIFY` by `reconcile/preclassify.sh`. Nothing disposes of that state. Measured:
occurrences of `BOTH-CHANGED|consumer-modified` in `reconcile/self-update-gate.sh` = **0** (grep
exit 1); control, `SELF-UPDATE-OK` in the same file = **6**. Same tokens across step 2's region
(`^2\. \*\*Self-update` to `^3\. \*\*Mechanical`) = **0**; control, `ALREADY-AT-THEIRS` in that
region = non-zero.

**The filing said the nearest rule was scoped elsewhere. It is worse than that, and narrower to
fix.** Step 2 already CALLS the tool that answers this question — `:302-303`, "Do not hand-roll
that comparison: `reconcile/preclassify.sh` already buckets exactly this as `ALREADY-AT-THEIRS`.
The slice is the sliced paths MINUS those." The call is made, `BOTH-CHANGED->CLASSIFY` comes back
in the same output, and step 2 reads one bucket. So the remedy is not a new derivation; it is a
second subtraction from a call already in the instruction. The filing's other half stands unchanged:
the only "never overwrite a consumer edit" rule in the step, at `:353-356`, is explicitly about
FIXTURES, and its `.claude/skills/ai-dlc-update/**` carve-out sits inside it as a subordinate clause.

The downstream half exists — `reconcile/apply.sh` emits `semantic-merge` worklist rows (6
occurrences; control, `WORKLIST` = 24), so a path excluded here lands in front of the operator at
step 7 rather than vanishing. What is missing is step 2 declining to overwrite it, and the gate
having an arm that says so.

**Not claimed:** that any consumer has lost a machinery delta this way. The reference consumer did
not, because its operator stopped and reasoned about it. The finding is that nothing in the tool
would have stopped it. **And this is the bootstrapping shape** — step 2 delivers step 2, so the
release carrying the fix is written by the unfixed step.

**The receipt DRIVES the gate; it no longer reads either file.** The filing's own anchor was
`theirs_has SKILL.md "the consumer never edits them"` — an inverted verb, so it read CLOSE while the
defect was live. The receipt that replaced it grepped both files for the bucket token, and a
COMMENT naming the bucket closed it with no behaviour changed. The one here seeds a throwaway
distribution and two consumers under `mktemp`, runs `self-update-gate.sh` against both, and requires
a `SELF-UPDATE-CARRY` row for the diverged consumer on TWO different divergence shapes while
requiring an UNDIVERGED machinery path INSIDE THE SAME RUN to get none. Scored against six
implementations — defect-live 1, prose-only comment 1, unconditional emission 1, a key narrowed to
the literal `BOTH-CHANGED` 1, an all-or-nothing arm that carries the WHOLE slice as soon as
anything diverged 1, a second spelling of the correct fix 0, a fix naming the status token
differently 0, a fix emitting the consumer path instead of the core path 0, the shipped fix 0.

**IT KEYS ON THE PATH, NEVER ON THE STATUS TOKEN OR THE PATH'S SPELLING.** `SELF-UPDATE-CARRY`
is UNBOUND vocabulary — `docs/vocabulary-index.md` carries no `SELF-UPDATE` entry and no
`# vocabulary:` arm covers the gate's status column (measured: 0 and 0, against a control of 1 for
a vocabulary that IS bound). So nothing forces that word on a later author, and a token-keyed
receipt REJECTS a correct fix that picks another one — an independent hand writing this fix blind
chose `SELF-UPDATE-CONSUMER-MODIFIED`. The receipt therefore accepts any advisory-shaped row (a
`SELF-UPDATE-*` status that is not DEFER, UNDECIDED or SAFE-STOP) and matches the path by
basename, because naming the CORE path and naming the CONSUMER path are both defensible readings
of "name the path" and the entry never constrained it. Scored: both alternate spellings 0.

**THE SEED MUST REACH THE END OF THE GATE, OR ARM SITING DECIDES THE VERDICT.** Four `exit 0`
paths sit before the differential loop, and an earlier seed stopped at the first of them — which
scored a correct fix sited AFTER that point as still-live, for no reason but where its author put
it. The seed now gives the consumer a `.githooks/pre-push` that invokes a changed `core/scripts/`
script present on both sides, and a control asserts the run reached that loop.

**THE IN-RUN NEGATIVE REPLACED A SEPARATE CLEAN CONSUMER, AND THAT IS THE WHOLE DIFFERENCE.** The
receipt that shipped with v0.436.0 used a second, undiverged consumer as its negative, and an
independent hand killed it: a separate tree can only ask *does the arm fire at all*, never *does it
fire on the RIGHT paths*, because in the run where the arm fires there is nothing present it is
supposed to stay quiet about. That receipt returned 0 for an implementation that carries the entire
machinery set the moment one path diverges — which satisfies every clause it stated and still
contradicts the arm's own header, `ADVISORY, NOT A VERDICT ... it removes paths FROM the cycle`. On
the reference consumer one edited `.githooks/pre-push` would have handed the operator the whole
machinery set. Re-derived here rather than taken on report, and the live fixture's
`carry-quiet-untouched` arm DOES kill it (`got=[1] want=[0]`, 9 of 44 assertions red), so the gap
was in the certificate and never in the guard. **A near-miss in a separate run is an ADJACENT
input; the discriminating one is a near-miss standing beside the offender.**

**The population is wider than this entry filed it, and keying on `BOTH-CHANGED` catches one case of
three.** `preclassify.sh` marks a consumer-diverged machinery path `BOTH-CHANGED->CLASSIFY` when
both sides edited it, `UPSTREAM-DELETED+consumer-modified->CLASSIFY` when upstream deleted what the
consumer kept and changed, and `BOTH-ADDED->CLASSIFY` when both sides created it independently. All
three destroy consumer state on a blind write, and the last two carry the most, since in the deleted
case the consumer's copy is the only copy left. The shipped key is the `->CLASSIFY` marker plus
`RELOCATE-MOVE+consumer-edited`, which is the same key `apply.sh`'s own `*CLASSIFY*)` dispatch reads
to emit the `WORKLIST semantic-merge` row this fix hands the path to.

Discharges the consumer entry `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`
at pinned ledger line 3918.


verify: sh t=$(mktemp -d "${TMPDIR:-/tmp}/bl051-XXXXXX") || exit 9; d=$t/d; c=$t/c; mkdir -p "$d/core/git-hooks" "$d/core/rules" "$d/core/scripts" "$c/.githooks" "$c/.claude/rules" "$c/scripts/ai-dlc" || exit 9; git -C "$d" init -q && git -C "$d" config user.email r@r && git -C "$d" config user.name r || exit 9; printf '#!/usr/bin/env bash\nexit 0\n' > "$d/core/git-hooks/pre-push"; printf 'base rule\n' > "$d/core/rules/doomed.md"; printf 'base steady\n' > "$d/core/rules/steady.md"; printf '#!/bin/sh\nexit 0\n' > "$d/core/scripts/walker.sh"; printf '0.1.0\n' > "$d/VERSION"; git -C "$d" add -A && git -C "$d" commit -qm base || exit 9; b=$(git -C "$d" rev-parse HEAD); printf '#!/usr/bin/env bash\n# upstream reworks it\nexit 0\n' > "$d/core/git-hooks/pre-push"; printf 'theirs steady\n' > "$d/core/rules/steady.md"; printf '#!/bin/sh\n# reworded, still passes\nexit 0\n' > "$d/core/scripts/walker.sh"; git -C "$d" rm -q core/rules/doomed.md; printf '0.2.0\n' > "$d/VERSION"; git -C "$d" add -A && git -C "$d" commit -qm theirs || exit 9; h=$(git -C "$d" rev-parse HEAD); printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/walker.sh\n' > "$c/.githooks/pre-push"; printf '#!/bin/sh\nexit 0\n' > "$c/scripts/ai-dlc/walker.sh"; printf 'base rule\nconsumer kept and edited this\n' > "$c/.claude/rules/doomed.md"; printf 'base steady\n' > "$c/.claude/rules/steady.md"; g=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; p=core/skills/ai-dlc-update/reconcile/preclassify.sh; [ -f "$g" ] && [ -f "$p" ] || exit 9; o=$(bash "$g" "$d" "$b" "$h" "$c" 2>/dev/null); z=$(bash "$p" "$d" "$b" "$h" "$c" 2>/dev/null); u=$(printf '%s\n' "$z" | grep -c 'pre-push.*CLASSIFY'); w=$(printf '%s\n' "$z" | grep -c 'doomed.md.*CLASSIFY'); y=$(printf '%s\n' "$z" | grep -cE 'steady.md.*(UPSTREAM-ONLY|ALREADY)'); deep=$(printf '%s\n' "$o" | grep -c 'walker.sh'); [ "$u" -eq 1 ] && [ "$w" -eq 1 ] && [ "$y" -eq 1 ] && [ "$deep" -ge 1 ] || { echo "CONTROL FAILED (both-changed=$u upstream-deleted=$w in-run-undiverged=$y reached-differential=$deep)"; rm -rf "$t"; exit 9; }; adv=$(printf '%s\n' "$o" | awk -F'\t' '$1 ~ /^SELF-UPDATE-/ && $1 !~ /DEFER|UNDECIDED|SAFE-STOP/ && $2 !~ /walker\.sh/ && $2 != "-" {print $2}'); printf '%s\n' "$adv" | grep -q 'pre-push' && printf '%s\n' "$adv" | grep -q 'doomed\.md' && ! printf '%s\n' "$adv" | grep -q 'steady\.md'; r=$?; rm -rf "$t"; exit $r
## BL-049

**LANDED (v0.437.0, verified fa92ac44).**

**The self-update slice cannot carry a fixture the pull itself fixes, because ~~no derivation
anywhere reads the diff for fixtures~~ THE FIXTURE TERM OF THE SLICE does not.**
`core/skills/ai-dlc-update/SKILL.md:215-217` defines the
slice's fixture term as "every `core/fixtures/<dir>/` whose `*.sh` names one of the machinery
paths **this diff actually touched**", and `:355` states the exclusion outright — "the derived set
is grepped from the fixtures rather than from the diff, so it names fixtures this pull does not
change". A fixture the diff CHANGES, that names no changed machinery path, is outside the slice by
construction. It is not recoverable downstream either: the one program that runs the set,
`core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh:32-34`, refuses to derive it — "The
fixture set is passed IN rather than re-derived here" — so step 2's prose is the sole derivation
site. Measured over `core/skills/ai-dlc-update/`: files joining a `git diff` to `core/fixtures`
= **0**; control, files naming `core/fixtures` at all = **9**.

The consumer's pre-push runs the whole suite, not the slice, so a fixture left at `ours` while its
subject moves to `theirs` blocks the push the self-update is making — and
`reconcile/self-update-gate.sh` is correct to return OK, because it is a differential over
individual scripts and a pre-existing red cannot move a differential. Its OK arms at `:332`, `:339`
and `:406` say so in their own detail. It never executes the hook: `$HOOK` appears at `:317-319`
and `:325` only, as an `-f` test and a `grep -oE` argument.

The filing was right about the mechanism and understated the reach. It read the differential
property off the gate's header comment and labelled that an INFERENCE; the gate's arms make it
measurable, and `:406` goes further than the filing knew — it returns OK explicitly when both
versions exit non-zero, so a pre-existing red is not merely invisible to the gate, it is a
documented OK.

**This is the bootstrapping shape: the fix ships inside the step that is broken.** Step 2 delivers
step 2, so the release carrying this fix is classified by the unfixed derivation. The fix has to
land machinery-only, or the first pull that needs it is the one that cannot deliver it.

**CORRECTED — THE FILING'S WIDEST SENTENCE WAS NEVER TRUE, AND IT SURVIVED FOUR RELEASES BECAUSE
THE GREP THAT WOULD HAVE KILLED IT WAS POINTED AT THE WRONG LITERAL.** `preclassify.sh:295` runs
`git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/`, and `core/fixtures/` is inside
`core/`, so a derivation reading the diff for fixtures has existed all along — driven against a
scratch copy of the reference consumer at `base=f0b8ddcc theirs=origin/main` it returns 10 rows,
**5 of them `core/fixtures/` rows** with correct `tests/fixtures/` destinations. The entry's
own measurement — "files joining a `git diff` to `core/fixtures` = 0" — scored that site a
non-instance because the pathspec is the literal `core/`, never `core/fixtures`. What is true, and
is the entry's actual subject, is narrower: **step 2's FIXTURE TERM does not read the diff**, and
those preclassify rows are bucketed for the WRITE and never consulted when the fixture set is
derived. The subject stands; the sentence that carried it did not.

**Its line citations were all stale by the time the fix landed** — `SKILL.md:215-217`/`:355` are
now `226-231`/`391-395`, the gate's OK arms are not `:332`/`:339`/`:406`, and `$HOOK` is not at
`:317-319`. Named here rather than repaired in place, because the entry is a record of what was
filed and the rotation is about to archive it.

**THE REACH WAS MEASURED, AND IT IS NOT A CORNER CASE.** Over the last 69 release-to-release
ranges of this distribution, **16 carry at least one SHIPPING fixture directory the range changes
and the grep term cannot see** — 21 directory-instances. Unfiltered by `.dist-only` the figures are
29 ranges and 47 instances. Derived by building the fixture→token map once at `HEAD` and
intersecting it per range against the non-fixture `core/` paths that range changed; the map is
taken at `HEAD` rather than per-range, so a fixture that named different tokens then is mis-scored
and the figure is a floor rather than an exact count.

**THE RECEIPT WAS REPLACED BEFORE THE FIX LANDED, AND THE ONE IT REPLACES WAS CLOSABLE BY PROSE.**
The old receipt anchored on two sentences — one in each file — and either one changing closed it,
so deleting a comment shipped nothing and reported CLOSE. The replacement DRIVES
`reconcile/self-update-fixtures.sh` against a seeded two-commit repository in which the diff
repairs a fixture that names no moved machinery path, and asks whether a named set OMITTING that
fixture is accepted. It carries a positive control in the same invocation — the COMPLETE set must
run green — so a run that died at one of the runner's four earlier exits reports 9 rather than a
false close, and it keys on the runner's BEHAVIOUR rather than on any status word or path spelling.

**BOTH HALVES ARE REQUIRED, AND A SCRIPT-ONLY FIX IS A WEDGE RATHER THAN A PARTIAL FIX.** The
runner only ever REFUSES a set; it never produces one. So a runner that asserts coverage while
step 2 still derives term (a) alone turns a silent gap into a hard stop on every range where the
two disagree — independently measured at **35 of 159** ranges under strict path matching, 23 under
basename matching, replicating this entry's 16-of-69 from a different sample. The receipt therefore
carries a `SKILL.md` conjunct whose only job is to reject that spelling; the behavioural arm carries
the weight, and the prose arm alone cannot close anything.

**THE FIRST REPLACEMENT SEED WAS ITSELF DEFECTIVE, AND AN INDEPENDENT HAND FOUND IT BY BUILDING
TWENTY-SEVEN IMPLEMENTATIONS RATHER THAN BY READING IT.** That seed held one repaired fixture and
one named one — no `.dist-only` dir, no dir DELETED at theirs, and no present-but-untouched dir. So
the entire EXEMPTION half of the fix was unexercised, and five wrong runners scored CLOSE:
deleting both exemptions, reading them at `base`, reading them from the working tree, demanding
every dir in the consumer's fixture root, and a pure ARITY test that read nothing at all. Four of
those five WEDGE the self-update on correct input, which is a worse outcome than the defect.

**The seed that stands carries six directories and one non-obvious property: the omitting run names
the SAME NUMBER of fixtures as the control.** `lonely` is repaired and omitted, `named` is repaired
and named, `distonly` gains its marker at theirs, `doomed` is deleted at theirs, `other` is
untouched and named, `spare` is present at the consumer and never mentioned. Equal cardinality is
what kills the arity implementation — a count cannot tell a complete set from an incomplete one of
the same size — and the marker is written at THEIRS then removed from the working tree, which is
what separates a read at `theirs` from a read at `base` or on disk.

**AND THE SECOND REPLACEMENT WAS WRONG IN THE OTHER DIRECTION, WHICH IS THE WORSE ONE.** Its
`SKILL.md` conjunct was a literal uppercase `grep -qF`, and a literal phrase test is simultaneously
too STRICT and too WEAK. Measured: the same fix with step 2's sentence merely lowercased scored
**STILL-LIVE** — a receipt that reports a shipped fix as unshipped — while `HEAD`'s unfixed prose
plus a bare `<!-- … -->` comment carrying the phrase scored **CLOSE**. That is the
closable-by-prose hazard reintroduced one level up, by the arm added to avoid it. The conjunct is
now case-insensitive and rejects a match that sits inside an HTML comment.

**A THIRD RUN WAS ADDED because the seed's `$DIST` was always well-formed**, so the WRONG-REPO arm
was unexercised and deleting it scored CLOSE. The third run hands the runner a repository carrying
`core/fixtures` at BASE and not at THEIRS, which separates the arm from the ref-resolution guard
beside it: a repo with no such tree at all fails ref resolution first, and the two guards would
then cover each other.

Thirteen implementations were built and scored, not reasoned about. Accepted, all correct: the
shipped fix **0**, `git diff-tree` instead of `git diff` **0**, refusal as `exit 1` **0**,
`git show` instead of `cat-file -e` **0**, step 2's prose REWORDED **0**. Rejected, all wrong:
pre-fix **1**, script-only **1**, prose-only **1**, arity-only **1**, a vacuous join whose result
is never read **1**, the WRONG-REPO arm deleted **1**, unfixed prose plus a comment **1**, and — as
control failures, because they refuse the CONTROL run — no exemptions **9**, exemptions at `base`
**9**, exemptions at the working tree **9**, whole-suite **9**.

**WHAT THIS RECEIPT STILL CANNOT DO, stated rather than left to be discovered.** Its `SKILL.md`
half is a phrase anchor, not a behavioural test, because step 2's derivation is prose an agent
executes and there is no program to drive. A wholesale rewrite of that sentence scores STILL-LIVE.
That is accepted deliberately: dropping the arm instead accepts a SCRIPT-ONLY change, which turns
this defect into a hard stop on 35 of 159 ranges. The live guard on the behavioural half is
`core/fixtures/self-update-fixture-log`, which is not archived when this entry rotates, and it
kills the WRONG-REPO deletion independently — measured.

Discharges the consumer entry `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH`
at pinned ledger line 3413.


verify: sh R=core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh; S=core/skills/ai-dlc-update/SKILL.md; { [ -f "$R" ] && [ -f "$S" ]; } || { echo "CONTROL FAILED: subject absent"; exit 9; }; G="-c user.email=a@b -c user.name=n -c commit.gpgsign=false"; T=$(mktemp -d); C=$(mktemp -d); W=$(mktemp -d); git init -q "$T"; git init -q "$W"; for d in lonely named distonly doomed other spare; do mkdir -p "$T/core/fixtures/$d" "$C/tests/fixtures/$d"; printf 'exit 0\n' > "$T/core/fixtures/$d/run.sh"; printf 'exit 0\n' > "$C/tests/fixtures/$d/run.sh"; done; git -C "$T" add -A >/dev/null 2>&1; git -C "$T" $G commit -qm base >/dev/null 2>&1; B=$(git -C "$T" rev-parse HEAD); for d in lonely named distonly; do printf '# repaired\n' >> "$T/core/fixtures/$d/run.sh"; done; printf 'battery\n' > "$T/core/fixtures/distonly/.dist-only"; rm -rf "$T/core/fixtures/doomed"; git -C "$T" add -A >/dev/null 2>&1; git -C "$T" $G commit -qm theirs >/dev/null 2>&1; H=$(git -C "$T" rev-parse HEAD); rm -f "$T/core/fixtures/distonly/.dist-only"; mkdir -p "$W/core/fixtures/named"; printf 'exit 0\n' > "$W/core/fixtures/named/run.sh"; git -C "$W" add -A >/dev/null 2>&1; git -C "$W" $G commit -qm wbase >/dev/null 2>&1; WB=$(git -C "$W" rev-parse HEAD); rm -rf "$W/core"; printf 'x\n' > "$W/README"; git -C "$W" add -A >/dev/null 2>&1; git -C "$W" $G commit -qm wtheirs >/dev/null 2>&1; WH=$(git -C "$W" rev-parse HEAD); mkdir -p "$W/core/fixtures/named"; printf 'exit 0\n' > "$W/core/fixtures/named/run.sh"; bash "$R" "$T" "$B" "$H" "$C" lonely named other >/dev/null 2>&1; ctl=$?; bash "$R" "$T" "$B" "$H" "$C" distonly named other >/dev/null 2>&1; sub=$?; bash "$R" "$W" "$WB" "$WH" "$C" named other >/dev/null 2>&1; wr=$?; rm -rf "$T" "$C" "$W"; [ "$ctl" -eq 0 ] || { echo "CONTROL FAILED: the complete-and-exempt set did not run green (rc=$ctl)"; exit 9; }; [ "$sub" -eq 0 ] && exit 1; [ "$wr" -eq 0 ] && exit 1; M=$(grep -iE 'the diff itself touches' "$S" | grep -v '<!--'); [ -n "$M" ] || exit 1; exit 0
## BL-125 — the handoff procedure emits an entry line its own router does not recognise, and `handoff` is not routed at all

**LANDED (v0.438.0, verified 8dfd6fbd).**

**BOTH SUBJECTS CLOSED TOGETHER, which the receipt required and which each half alone failed.**
`route.md` Step 0 now reads an ENTRY TOKEN before anything else: `handoff` dispatches to
`steps/handoff.md`, and `resume` is a resume signal with `/ai-dlc resume` named verbatim so the two
files agree on a STRING rather than on a description. Probed both ways on the release branch —
removing the handoff arm returns the receipt to 1, and replacing the named entry line returns it
to 1.

**The gap this entry named as its own is now closed too.** It shipped with no fixture and no
invariant behind it; `core/fixtures/resume-whole-read` gains **A8** and **A9**, and A8 derives BOTH
sides — it extracts the entry line from `handoff.md`'s fenced block and requires `route.md` to name
that exact string, so re-wording either file alone turns the arm red rather than leaving it green
over a disagreement. Two mutants added, each failing its own arm alone. The receipt archives when
this entry rotates; the fixture does not.

**`steps/handoff.md` tells the successor session to enter with exactly `/ai-dlc resume`, and
`steps/route.md` Step 0 does not accept that string as a resume signal.** The producer and the
reader are two prose files that must agree and nothing joins them.

`core/skills/ai-dlc/steps/handoff.md:59` instructs the handing-off session to "emit the successor's
entry line — exactly `/ai-dlc resume`", and `:82` carries it in a fenced copy-paste block. `:72-74`
then states the contract outright: "the resume path (`route.md` Step 0) reads
`_bmad-output/pipeline-snapshot.md` for ALL state."

`core/skills/ai-dlc/steps/route.md:29-30` defines the only two inputs Step 0 accepts as a resume:
input that **begins with** `Resuming an ai-dlc sprint`, or that **explicitly references**
`pipeline snapshot`. **`/ai-dlc resume` is neither.** Measured, with both controls in the same run:
the two accepted forms are present in `route.md` (1 and 3 hits), the emitted entry line matches
neither (0 and 0), and a control string containing `pipeline snapshot` matches (1) — so the test
discriminates rather than merely returning zeros.

**The consequence is not "resume fails", it is `route.md:51-55` — Step 0 path 3.** Input that does
not indicate a resume falls through to Step 1, which is fresh-pipeline routing, and Step 6 then
archives the snapshot as stale. So the documented handoff entry line is classified as a NEW FEATURE
REQUEST, and the state the handoff spent five steps preserving is retired by the session sent to
pick it up.

**SECOND SUBJECT: `handoff` has no dispatch arm at all.** `route.md` mentions the word three times
(`:41`, `:539`, `:582`) and every one is incidental — teammate-table semantics, a cross-reference to
`handoff.md` Step 1, and a note about context reminders. None routes the token. `SKILL.md:441-446`
makes handoff trigger (a) a NATURAL-LANGUAGE judgment the lead makes mid-session, so a lead already
in conversation honours the bare word `handoff` while the same word arriving as a skill argument
falls to Step 1 with the rest.

**PROVENANCE — operator-reported from the graph consumer, 2026-08-29, and the report is what found
this.** The operator observed three attempts: the first handoff did not run all of the handoff
steps; a second, invoked as `/ai-dlc handoff`, **resumed the pipeline instead of handing off**; a
third, typed as the bare word `handoff`, ran every step. Corroborated from the consumer's own
`_bmad-output/pipeline-continuation-log.md`, which records `USER_PAUSE` for each attempt — including
the slash form — and one `HANDOFF_GUARD_BLOCK (1/3)`, consistent with the incomplete first attempt.
**The pause hook is not the defect**; it fired correctly every time. What the log cannot settle is
the dispatch behaviour, which is why the mechanism above is derived from the two step files rather
than from the log.

**Both subjects must close together and the receipt requires it**, because fixing either alone
leaves the other live: teaching the reader the bare entry line still leaves `/ai-dlc handoff`
unrouted, and routing `handoff` still leaves the successor's own entry line unrecognised.

**Scored across six inputs before shipping**, not reasoned about: current tree **1**, reader taught
the entry line only **1**, `handoff` routed only **1**, both **0**, `route.md` deleted **9**, and
`handoff.md`'s fenced entry line removed **9** — the last two are control failures rather than
false closes, which is the direction that matters.

**The receipt derives BOTH SIDES rather than grepping for a sentence.** It extracts the entry line
from `handoff.md`'s fenced block and tests it against the forms `route.md` accepts, so a reworded
remedy still closes it and a comment does not. It is still prose-on-prose: neither step file is a
program, so there is nothing to drive. **This entry has no fixture and no invariant behind it, and
that is the gap** — the join it describes is exactly the kind `CLAUDE.md` says to bind mechanically,
and doing so is not this filing.

**NOT a consumer filing.** A `PC-` id belongs in the consumer's ledger and an ai-dlc session never
writes to a consumer tree, so this is filed here, where the subject lives.

verify: sh H=core/skills/ai-dlc/steps/handoff.md; R=core/skills/ai-dlc/steps/route.md; { [ -f "$H" ] && [ -f "$R" ]; } || { echo "CONTROL FAILED: subject absent"; exit 9; }; E=$(awk '/^```$/{f=!f;next} f && /^\/ai-dlc /{print;exit}' "$H"); [ -n "$E" ] || { echo "CONTROL FAILED: handoff.md emits no fenced /ai-dlc entry line"; exit 9; }; grep -qF 'Resuming an ai-dlc sprint' "$R" || { echo "CONTROL FAILED: route.md carries neither accepted resume form"; exit 9; }; ok=0; case "$E" in "Resuming an ai-dlc sprint"*) ok=1 ;; esac; case "$E" in *"pipeline snapshot"*) ok=1 ;; esac; case "$(grep -c 'ai-dlc resume' "$R")" in 0) ;; *) ok=1 ;; esac; h=0; grep -qE '^[^#]*\bhandoff\b.*steps/handoff\.md' "$R" && h=1; [ "$ok" -eq 1 ] && [ "$h" -eq 1 ] && exit 0; exit 1
## BL-037

**`apply.sh` emits an `override-readopt` row and a two-step ATOMIC `override-retire` sequence for
the SAME override path, and the retire's last step tells the operator to land it in the "Same
commit as the row(s) above".** Reproduced through the real `apply.sh` on this tree, with a stub
`layer-drift.sh` emitting one `HARD-OVERRIDE-DRIFT-SECTION` and one `OVERRIDE-SUPERSEDED` row for
one path (the harness `core/fixtures/apply-worklist-rows/run.sh:26-28,74-99` already establishes —
`apply.sh` shells to `$SELF/layer-drift.sh`, so the worklist is a pure function of that TSV):

```
WORKLIST  override-readopt  …/steps__w__probe.md  merge the moved core section into the override body, then readopt-override.sh --stamp readopt
WORKLIST  override-retire   …/steps__w__probe.md  1/2 ATOMIC — write AI_DLC_PROBE_KEY into .claude/settings.json "env" …
WORKLIST  override-retire   …/steps__w__probe.md  2/2 ATOMIC — readopt-override.sh --stamp retire …. Same commit as the row(s) above.
```

Three `WORKLIST` rows for one subject; the control in the same invocation is the total `WORKLIST`
count, **3**, so nothing else in the manifest is contributing. Structurally, `apply.sh:436` builds
`LD_HARD` and `:451` builds `LD_SUP` from the same `LD_OUT` with no join between them, and
`grep -n 'LD_HARD\|LD_SUP'` over the file returns 7 lines, none of which compares the two sets.
`SKILL.md:1131-1137` then binds the reader: "Do every step of that subject in the printed order and
commit them together. Do not reorder them, do not land one without the others." **An earlier
revision of this entry cited `SKILL.md:1062-1068` for that sentence; those lines are the step-7 git
isolation preconditions and say nothing of the kind.** The claim was right and the citation was
wrong by about seventy lines.

**The correction is narrower than the filing, in one specific way: the co-emission is deliberate,
and the defect is that the reason never reaches the manifest.** `apply.sh:444-448` already
contemplates the both-case in as many words — "an entry can be both … and in that case the readopt
is work whose result is an entry that still freezes its shadowed span." So the filing's "nothing
marking them as ALTERNATIVES" is true of the ROWS and false of the SOURCE: the author knew the
readopt's outcome is futile under a supersession and recorded it in a comment no operator reads.
That moves this from "two detectors are unaware of each other" to "a known interaction is
documented only on the emitting side", which is a smaller claim and a different fix. Everything
else in the filing reproduces unchanged, including the exact three-row shape it quotes.

**BOTH REMEDIES THE PREVIOUS RECEIPT ACCEPTED WERE BUILT AND BOTH ARE REGRESSIONS.** That receipt
closed on either "suppress the retire sequence while a readopt is outstanding" or "drop the 'Same
commit as the row(s) above.' phrasing", and scored exit 0 for each. Driven through the real
`apply.sh` on a seed that is both drift-hard and superseded:

- **Suppressing the retire** leaves ONE row, the readopt — deleting the only work that resolves the
  supersession and keeping the work `apply.sh:517-521` calls futile. Backwards.
- **Dropping the phrasing** deletes the ATOMIC ordering instruction. `SKILL.md:1131-1137` calls that
  order "a safety property, not a preference", because writing the replacement key BEFORE the retire
  stamp is what stops the next gate failing.

**The defect is the WORD "above", not the instruction.** For an entry that is also drift-hard, "the
row(s) above" names the `override-readopt` row for the same path — the one row that must NOT be in
that commit. So the fix marks the readopt as subsumed and rewords the atomicity instruction to name
its own sequence, keeping every row and the safety property.

The receipt is REPLACED rather than kept, because the old one accepted two fixes and therefore
established neither. The new one is behavioural, drives the real `apply.sh`, and was scored five
ways against copies each asserted byte-different before it was read: **the tree before the fix
exits 1, retire-suppressed exits 1, phrasing-deleted exits 1, a subject replaced by `exit 0` exits
1, and only the shipped fix exits 0.** It requires the readopt row (control arm), the retire rows
(so a suppression cannot pass), the subsumption NOTE, a surviving `Same commit` instruction (so a
deletion cannot pass), and zero occurrences of `row(s) above`.

**The durable half is the fixture, not this receipt** — a rotated entry archives its receipt while
`core/fixtures/apply-worklist-rows/run.sh` keeps running. Arms 9-13 there cover the same ground,
and the fixture's tree could not EXPRESS this defect before: every override it seeded was
superseded only, never also drift-hard, which is why it scored 42 ok against the defect and against
both regressions alike. Two mutants guard the new arms — one widens the exemption to every
supersession, one suppresses the retire under a marked readopt — and each is asserted not to move
the other's arm.

Discharges the consumer entry
`PC-S331-APPLY-SH-CO-EMITS-READOPT-AND-RETIRE-FOR-ONE-SUBJECT-AS-IF-BOTH-WERE-OWED` at pinned
ledger line 4258.

**LANDED (v0.439.0, verified c647c885).**


verify: sh R=core/skills/ai-dlc-update/reconcile; W=$(mktemp -d); O='.claude/skills/ai-dlc/overrides/steps__w__probe.md'; for r in dist cons; do mkdir -p "$W/$r"; git -C "$W/$r" init -q .; echo seed > "$W/$r/f"; git -C "$W/$r" add -A >/dev/null 2>&1; git -C "$W/$r" -c user.email=f@x -c user.name=f commit -qm seed >/dev/null 2>&1; done; mkdir -p "$W/rec"; cp "$R"/*.sh "$W/rec"/; printf '#!/usr/bin/env bash\nADJ_ROW_TOKEN="adjudicated"\nADJ_KEEP_VERDICT="still-additive"\nprintf %s\n' "'HARD-OVERRIDE-DRIFT-SECTION\t$O\tsteps/w.md\tthe shadowed section changed upstream\nOVERRIDE-SUPERSEDED\t$O\tsteps/w.md\treplaces_with=AI_DLC_PROBE_KEY :: core provides what this entry was written to work around.\n'" > "$W/rec/layer-drift.sh"; chmod +x "$W/rec/layer-drift.sh"; M=$(bash "$W/rec/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null); rm -rf "$W"; f() { LC_ALL=C awk -F'\t' -v o="$O" -v t="$1" -v k="$2" '$1==t && $2==k && $3==o' <<<"$M"; }; RE=$(f WORKLIST override-readopt | LC_ALL=C grep -c .); RT=$(f WORKLIST override-retire | LC_ALL=C grep -c .); NS=$(f NOTE override-readopt-subsumed | LC_ALL=C grep -c .); AT=$(f WORKLIST override-retire | LC_ALL=C grep -cF 'Same commit'); AMB=$(f WORKLIST override-retire | LC_ALL=C grep -cF 'row(s) above'); [ "$RE" -ge 1 ] && [ "$RT" -ge 1 ] && [ "$NS" -ge 1 ] && [ "$AT" -ge 1 ] && [ "$AMB" -eq 0 ]
## BL-117 — the `NAMED-UPSTREAM` row elects two commits and neither is usually the absorbing one

**HALF OF THIS ENTRY EXPIRED BEFORE IT WAS TAKEN, AND THE HALF THAT SURVIVED IS WIDER THAN IT WAS
FILED.** The entry is kept whole rather than re-filed, because which half died is the load-bearing
part: a reader who takes the original text at face value builds a channel the defect no longer
needs.

**DEAD — the `tail -1` election.** The filing said `named_absorbed()` "joins an id to the OLDEST
commit whose MESSAGE contains it, and `tail -1` elects it". That was true when filed and is not
now: `PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION` removed the election, and the
function returns the whole match set's shape rather than one elected member.

**DEAD — the wrong version in a permanent annotation.** The filing's damage claim was that "the
consumer is handed an absorbing version that is too early, inside a PERMANENT paste-ready
annotation". The row now carries **no version at all**, deliberately, and says so in its own text.
There is no version to be wrong.

**SURVIVES, AND IS THE SUBJECT — electing two ends instead of one.** The replacement reported
`in <n> commits, newest <a> and oldest <b>`, which swapped one election for two and picked the
worst possible pair. The oldest mention of an id is the commit that FILED the entry, or a plan, or
the withdrawal that disowns it; the newest is the rotate or docs commit written after the fix
landed. **The absorbing commit sits in the middle and was never shown**, and for `n > 2` the
operator was not told which of the named commits they were not being shown.

**The population is WIDER than the withdrawal case this was filed as.** Measured by DRIVING
`ledger-reverify` against a scratch copy of the reference consumer and counting the rows it
actually emits: it emits **16** per-entry `NAMED-UPSTREAM` rows, **9 carry more than one commit,
and in 3 of those 9 NEITHER advertised end is a `fix`/`feat` commit** — both ends are docs, chore
or merge commits. A withdrawal is one way to occupy an end, not the only way. Controls in the same
run: an impossible status matches 0 rows, stderr is empty.

**COUNT THIS OVER EMITTED ROWS, NOT OVER THE LEDGER.** A first cut read 21 / 12 / 5 by grepping
the ledger for ids. That set includes every entry already carrying an `ADOPTED UPSTREAM` or
`WITHDRAWN` marker, which `ledger-reverify` skips by design — so no row is ever emitted for them
and they cannot be instances of a defect in a row. The shipping extraction is the population.

The clearest live instance, and the reason a grammar fix was never the answer:

```
id=PC-S307-AWK-CANT-OPEN-FILE-MISREAD-AS-MISSING-FRONTMATTER
git log --format='%h %s' -F --grep="$id" origin/main
  81443020  Merge v0.435.0 ...              <- advertised as "newest"
  e8a3f09b  docs(v0.435.0): close/rotate ...
  81e8b69d  fix(v0.435.0): ...              <- THE ABSORBING COMMIT, never shown
  edcb5ffa  docs(plan): re-derive ...       <- advertised as "oldest"
git log -F --grep=PC-S999-CONTROL-TOKEN-NOT-THE-PLANS --format=%H origin/main | grep -c .   -> 0   # control
```

**THE REMEDY IS SUBTRACTION, NOT A NEW CHANNEL, AND THE FILED REMEDY IS WITHDRAWN.** The filing
asked for a `Withdraws-attribution: <id>` commit trailer that the join subtracts. That was
rejected on measurement, for three reasons: it cannot reach a single commit already written,
including the `29516443` that motivated the filing; it needs every future withdrawal author to
remember one line, with nothing to remind them; and it adds a declared channel to keep in sync in
order to suppress one member of a list the operator is being told to read anyway. Emitting the
**whole** list and electing nothing removes the privileged slot the defect lives in, reaches every
commit already written, and deletes code rather than adding a mechanism.

`n` is bounded and that was measured rather than assumed: over the emitted rows the distribution
is 7 ids at n=1, 7 at n=2, one at n=3, one at n=4. An id is written once by the commit that lands
the entry and re-cited only by the release that fixes it and the docs commit that rotates it, so
`n` tracks one entry's lifecycle and does not grow with the corpus. Shas rather than subjects,
because `emit()` is a three-field TSV row on one line and a commit subject may contain a tab.

**WHAT THIS DOES NOT FIX, RECORDED BECAUSE THE FIX MAKES IT VISIBLE AND SOMEONE WILL READ THAT AS
A NEW DEFECT.** Of the 16 emitted rows, **7 name no `fix`/`feat` commit anywhere in their list** —
only filings, backlog rotations and CHANGELOG commits. For those the honest answer is "none of
these absorbed it", and the row still asks the operator to read them and decide. `PC-S339` itself
is one of the seven: its sole naming commit is the `docs:` commit that FILED this entry. That is
not this entry's subject and is not closed by it; the row already states in its own text that
naming is not absorbing, and it claims no version. Listing every commit surfaces the state instead
of hiding it behind two elected ends.

**An n=1 row still names exactly one commit, and that is NOT a surviving election.** Listing every
member of a one-member set is the same act as listing every member of a four-member set; there is
no privileged slot left to remove. The n=1 concern is the paragraph above — whether any naming
commit absorbed anything — not the shape of the row.

Filed by the reference consumer as `PC-S339-WITHDRAWAL-COMMIT-BECOMES-THE-NEW-ATTRIBUTION`,
observed on the `0.430.1 -> 0.432.0` pull. Tiered **DEFECT**: it points the operator at the wrong
commits in a row whose entire purpose is to be read, on 5 of the 12 measured multi-commit ids.

**LANDED (v0.440.0, verified b58937e0).**

**The receipt DRIVES THE SHIPPING PROGRAM and keys on BEHAVIOUR.** It builds a throwaway
repository with three commits naming one probe id — the MIDDLE one absorbing, both ends not — and
a probe ledger holding that id, runs `ledger-reverify.sh` against them, and asserts that each of
the three shas appears in the emitted `NAMED-UPSTREAM` row EXACTLY ONCE. All three present kills
"shows only the ends" and "shows only a count"; exactly-once kills "shows the list and still
elects one". `NAMED-UPSTREAM` is the only identifier it keys on and it is a bound vocabulary
member. Controls inside the receipt: the three shas must be pairwise distinct, so a silently
failed commit cannot score the safe-but-wrong 1, and a row for the probe label must exist, which
is what proves the run REACHED the emit site. Exit 9 means the subject moved — file gone, `git` or
`mktemp` unusable, probe history not built, no such row — never a real still-live.

**THREE naming commits is the minimum discriminating seed, and that was measured.** The same
harness with TWO commits scores 0 on the unfixed tree and 0 on the fixed one, because at `n = 2`
the two elected ends ARE the whole list. A two-commit seed would have certified anything.

**What still scores STILL-LIVE, deliberately**: any implementation naming one commit twice,
including one that prints the full list AND an `<oldest>..<newest>` range beside it — that is
re-electing ends. A rewrite of the row's PROSE alone also scores 1, because the receipt reads the
shas the function supplied and not the sentence around them.

**The receipt this replaced was wrong in BOTH directions, and so was the first replacement.** The
original grepped the function body for the token `withdraw` — the FILED remedy, not the defect —
so it rejects the correct fix and is closed by a vacuous `_withdrawn=""` whose behaviour is
identical to the unfixed code. The first replacement EVALUATED the extracted function instead of
running the program, and therefore accepted a space-joined list: that reads correctly out of the
function but the caller parses the return with `awk '{print $3}'`, so only the first sha ever
reaches the row. **A receipt that reads the subject instead of running it cannot see a defect that
lives in the caller.**

verify: sh f=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; [ -f "$f" ] || exit 9; t=$(mktemp -d) || exit 9; trap 'rm -rf "$t"' EXIT; d=$t/d; L=PC-S999-RECEIPT-PROBE-LABEL; mkdir -p "$d" "$t/c/_bmad-output/ai-dlc-update" || exit 9; git -c init.templateDir= -C "$d" init -q >/dev/null 2>&1 && git -C "$d" config user.email r@r && git -C "$d" config user.name r || exit 9; printf '0.1.0\n' >"$d/VERSION"; git -C "$d" add -A >/dev/null 2>&1; git -C "$d" commit -qm base >/dev/null 2>&1 || exit 9; B=$(git -C "$d" rev-parse HEAD); git -C "$d" commit -q --allow-empty -m "fix: oldest names $L" >/dev/null 2>&1; O=$(git -C "$d" rev-parse --short HEAD); git -C "$d" commit -q --allow-empty -m "chore: middle names $L" >/dev/null 2>&1; M=$(git -C "$d" rev-parse --short HEAD); git -C "$d" commit -q --allow-empty -m "docs: newest names $L" >/dev/null 2>&1; N=$(git -C "$d" rev-parse --short HEAD); [ -n "$O" ] && [ "$O" != "$M" ] && [ "$M" != "$N" ] && [ "$O" != "$N" ] || exit 9; printf '# probe ledger\n\n## %s\n\nverify: manual\n' "$L" >"$t/c/_bmad-output/ai-dlc-update/push-candidate-ledger.md"; r=$(awk -F'\t' -v l="$L" '$1=="NAMED-UPSTREAM"&&$2==l{print $3}' <<<"$(bash "$f" "$d" "$B" "$t/c" HEAD 2>/dev/null)"); [ -n "$r" ] || exit 9; case "$(awk -v o="$O" -v m="$M" -v n="$N" '{a=gsub(o,"");b=gsub(m,"");c=gsub(n,"");print a b c}' <<<"$r")" in 111) exit 0 ;; esac; exit 1

## BL-064

**LANDED (v0.448.0, verified d3b0f601).** All three
unbounded payloads — `FANOUT_DIFF`, `FANOUT_FILES` and `FANOUT_UNTRACKED` — now travel by file.
Measured on the reference consumer, both sides in one invocation with a `cmp -s` control that the
two scripts differ: the child's environment falls from **700857 bytes to 3182**, 67% of `ARG_MAX`
to 0.3%, with the corpus and diff signatures at 0 and the `PATH=` reach control at 1 on both
sides. The worklist is byte-identical across the change.

**THREE OF THIS ENTRY'S OWN PREMISES HAD EXPIRED BY THE TIME IT WAS TAKEN, AND TWO OF THEM WOULD
HAVE MISDIRECTED THE WORK.** Recorded rather than edited away, because which half died is what
stops the next reader repeating it.

- Its citations `:255-261` and `:262` had drifted to `:289-295` and `:297`. A `path:line` that
  resolves to the wrong line reads exactly like one that resolves.
- *"That entry carries no `verify:` receipt of its own and is invisible to the consumer's
  closer"* is **false**. The consumer has since given
  `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` a receipt, and its sibling
  `PC-S303-FANOUT-SCRIPT-ARG-MAX-VIA-EXPORTED-DIFF-ENV-VAR` carries
  `theirs_has core/scripts/report-propagation-fanout.sh "export FANOUT_DIFF="` — which this fix
  falsifies directly, so that second candidate closes on the consumer's own next reverify without
  anything further from here.
- *"Fixture directories matching `fanout` or `propagation`: 0"* is **false**;
  `core/fixtures/fanout-untracked-corpus` exists and drives this same script. The new battery was
  built beside it rather than folded into it: that fixture's subject is the corpus DEFINITION and
  this one's is the payload CHANNEL, and a mutant of either would have to leave the other's arms
  untouched to be readable.

**THE FILED REMEDY WAS BUILT AS A MUTANT AND SCORED, AND IT DOES NOT CLOSE THIS.** Both consumer
filings prescribe moving the diff. Scored against this entry's receipt with `AI_DLC_PROJECT_ROOT`
pinned and reach asserted per arm: shipping exits 1, **diff-only exits 1**, corpus-only exits 1,
the full fix exits 0, and a second spelling that passes the same three paths on ARGV rather than
in `FANOUT_*_FILE` also exits 0 — so the receipt rejects neither a competent author's other
phrasing nor accepts a partial. A sixth variant that writes the files and leaves the old exports
beside them exits 1. The corpus is the fixed cost: 607945 bytes of `git ls-files` against an
`ARG_MAX` of 1048576 is 58% of the ceiling before a byte of diff exists, so the prescribed remedy
would have closed the filing and left the defect.

**`report-propagation-fanout.sh` hands its whole corpus to `python3` through the ENVIRONMENT, and
`execve` charges its size limit on that block whatever the heredoc does.**
`core/scripts/report-propagation-fanout.sh:255-261` is a single `export` statement carrying **10**
`FANOUT_*` variables — the full unified diff and the entire `git ls-files` corpus among them — and
`:262` then runs `python3 - <<'PYEOF'`. Measured behaviourally against the shipping script with a
`python3` shim first on `PATH`, so the thing under test is the program and not a restatement of it:
the child's own environment is **2236** bytes when exec'd directly and **31962** bytes when exec'd by
this script from this repo — a payload of **29726** bytes, stable across three consecutive runs, on a
tree whose `git ls-files` is **27885** bytes and whose diff was **1741**. `ARG_MAX` here is
**1048576**, and the ceiling is real in both directions in one invocation: a 1000KB environment execs
`/usr/bin/true` fine and an 1100KB one returns `Argument list too long`.

**It is a large-REPO defect, not the large-diff defect that was filed, and the named trigger cannot
produce the crash.** The fixed cost is the file list, not the diff: on the reference consumer
`git ls-files` is **607945** bytes across **10146** paths, which is **58%** of `ARG_MAX` consumed
before a single byte of diff exists. A fix that moves only `FANOUT_DIFF` to a temp file leaves that
58% in place. The filing also blames one variable when `:255-261` exports ten, so the subject is the
env-passing pattern rather than any one name. And the stated consequence does not hold: the filing's
harm is that "a caller checking `$? -in (0,2,3)` would misclassify this", but no such caller exists —
`core/skills/ai-dlc/steps/_gate-procedures.md:457-458` states the report "is not a gate verdict and
no exit code of it adjudicates a gate", and `:460` that "its exit codes say whether it could LOOK,
never what it found". Exit 126 with empty stdout reads as could-not-look, which is correct. The real
gap is that 126 is undocumented, which is milder than filed.

**There is no fixture, and this repo's own corpus cannot build one.** Fixture directories matching
`fanout` or `propagation`: **0**, against a control of **159** fixture directories; exactly **1**
fixture names the script at all. A new one cannot use this tree as its corpus — ai-dlc is 27885 bytes
across 633 paths against the consumer's 607945 across 10146 — so it has to synthesize the payload
size rather than reach `ARG_MAX` honestly.

**Why the receipt is the receipt.** It dumps the child's ENVIRONMENT and looks for each payload's
SIGNATURE in it — a tracked path for the file list, a hunk header for the diff — rather than naming a
variable or thresholding a total size. So a fix that renames `FANOUT_DIFF` while leaving it on the
env channel cannot close it, no comment recording the change can satisfy it, and neither can a
PARTIAL fix. Its control is that the shim was REACHED at all, asserted in the same invocation before
the verdict is read: the env dump must be non-empty and must carry `PATH=`.

**Both of those clauses are there because the first draft of this receipt failed them, measured.** It
thresholded total env growth at 4096 bytes, and a mutant that moves only `FANOUT_FILES` off the env
leaves the diff behind at **4113** bytes of child environment against a **2236**-byte baseline — under
the threshold, so that draft reported the fix PRESENT while the diff channel was still live. Worse,
its satisfiability proof was itself invalid: the mutant was a copy under `/tmp`, which resolves
`AI_DLC_ROOT` elsewhere and **exited 2 before ever exec'ing `python3`**, so the receipt read a stale
baseline as a clean environment and a dead mutant reported as a passing fix. Re-run with
`AI_DLC_PROJECT_ROOT` pinned and with reach asserted per arm, three pairwise-different variants
separate correctly: shipping gives corpus-signature **1** and diff-signature **1**, the partial fix
gives **0** and **1** and stays open, and a full fix that moves both payloads off the env gives **0**
and **0** and closes. That is the change which makes this receipt reach 0.

Discharges the consumer entry `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` at LIVE ledger line
4392, past the 4356-line pin. That entry carries no `verify:` receipt of its own and is invisible to
the consumer's closer.

verify: sh d=$(mktemp -d); n="$d/env"; printf "#!/bin/sh\ncat >/dev/null\nenv > %s\n" "$n" > "$d/python3"; chmod +x "$d/python3"; PATH="$d:$PATH" bash core/scripts/report-propagation-fanout.sh HEAD~1 >/dev/null 2>&1; [ -s "$n" ] || { rm -rf "$d"; exit 9; }; p=$(grep -c "PATH=" "$n"); f=$(grep -c "core/scripts/report-propagation-fanout.sh" "$n"); g=$(grep -c "^@@ " "$n"); rm -rf "$d"; [ "$p" -ge 1 ] || exit 9; [ "$f" -eq 0 ] && [ "$g" -eq 0 ]

## BL-075

**LANDED (v0.451.0, verified 5da86e57).**

**Check 16's marker gate is applied to the RAW source line while all four elements it gates
assume a comment block, so any occurrence of a marker in code opens the elements against a line
that can never satisfy them.** `core/scripts/validate-stub-audit.sh:108` is
`STUB_MARKER='(stub|TODO|FIXME|wired later|Phase [0-9]|NotImplementedError)'`, matched at `:184`
as `[[ $line =~ $STUB_MARKER ]]` — unanchored, no boundary guard, and against `$line`, not the
decommented text. `decomment_line()` at `:131` already exists and is called only at `:196` to
build `dec[]`, which feeds element 4 alone; its own header states the subject is "a comment
block", and element 1's finding message says so too. The gate is the one part of the check that
does not.

Driven through the shipping script on probe trees under `mktemp`: `self.stubborn = 1` and
`client_stub.call()` return rc=1 with two `element1-item-ref` findings, and
`stub = AsyncMock(return_value=None)` returns rc=1 with two. Positive control in the same
invocation, `# stub, wire later`, rc=1; discriminating control, a file whose only body is
`return 42`, rc=0 at `0 stub marker(s) examined` — so the zero is a real absence and not a broken
invocation. Population over the 354 tracked hot-path files (control: the same `git ls-files` for
`*.zzzznope` returns 0): **115 markers examined, 115 findings**, of which 9 are substring
inflections (`stubbed`, `stubs`) and 17 raw hits come from `Phase [0-9]` matching ordinary prose
such as `core/fixtures/check-15-bypass/seed.sh:188`. The site is unique: a sweep of
`core/scripts/` (46 files) and `core/hooks/` (17) for a bare-word alternation regex var returns
`:108` and nothing else, with a seeded `MY_MARKER='(foo|bar|baz)'` probe proving the sweep fires
and an impossible-token control returning 0.

**THREE OF THE FIGURES ABOVE HAVE SINCE EXPIRED AND ONE CLAIM IS NOW WRONG, kept rather than
edited away because which half died is the part that stops the next reader repeating it.** A
later release narrowed `Phase [0-9]` to require an absence statement on the same line, so it is
no longer in the bare marker set: the `17 raw hits` sentence describes a rule that is gone, and
`115 markers / 115 findings over 354 files` re-derived here is **138 / 138 over 393**. The
`:184` and `:196` citations have drifted. **The central claim survived every re-derivation** —
the marker set was still matched against the raw `$line`, unanchored and unbounded, and the four
elements still assume a comment block.

**RE-MEASURED ON THE REFERENCE CONSUMER, which is where the defect was observed and where the
distribution's own corpus cannot speak for it.** Both copies driven against
`/Users/n8/git/graph` in one invocation, `cmp -s` first asserting the two binaries differ:
1776 hot-path files, 339 dropped upstream-owned, 1437 audited, **486 markers examined and 486
findings before, 73 and 73 after — 413 sites removed and 0 added**. The false-negative control
is the one that matters and it is clean: **0 of the 413 removed lines carry
`NotImplementedError`**, against 1 that does in the surviving set, so the arm that keeps the
most reliable deferral signal is live and the removals are all prose.

**The filing's prescribed remedy is a total disarm on this platform, and its own receipt accepts
it.** bash's `[[ =~ ]]` does not honour `\b` here — measured, `[[ "stub = 1" =~ \b(stub)\b ]]`
does not match while `(stub)` matches — so `STUB_MARKER='\b(...)\b'` examines **0 markers over
all 354 corpus files** and passes `# stub, wire later`, `raise NotImplementedError()` and
`# TODO: fix` alike. The cited precedent, `core/scripts/audit-layer-debt.sh:186`, is a **Python**
`re.compile` with lookbehind run through `python3` at `:85`, which `[[ =~ ]]` cannot take.

**The two obvious remedies each fail one direction, and the receipt is shaped to reject both.**
A word boundary drops 9 of 115 findings and adds 0, but still fires on `stub = AsyncMock(...)`,
the bare-word case the filing itself reports. Gating the marker on comment text clears that and
drops 36 — none of which, enumerated, is a genuine deferred implementation — but it drops
`raise NotImplementedError()` in live code by construction, which is the most reliable stub
signal in the list. That false negative is invisible on this corpus: all 22 real stubs here sit
at `core/fixtures/check-15-bypass/seed.sh` written `raise NotImplementedError  # stub`, whose
trailing comment the gate happens to keep. A remedy that survives measurement for that reason has
not been measured. Splitting the set — `NotImplementedError` matched anywhere, the prose markers
matched only in comment text, both word-bounded — satisfies all four arms, takes the corpus from
115 markers to 73 with 0 findings added, and keeps every one of the 22. **It is not free, and the
cost is a predicate this file does not have.** `decomment_line()` cannot supply it: it strips
leading whitespace at `:133` BEFORE it inspects the prefix, so its output differs from its input
for every INDENTED line, comment or not. A patch deriving "this line carries no comment" from
`[ "$(decomment_line "$line")" = "$line" ]` therefore passes the comment arm and the substring arm
and FAILS the bare-word arm on any indented code — which is all Python code. That patch was built
and driven here and it returns rc=1 where the split returns rc=0. The prefix has to be tested
directly.

The receipt is behavioural because every narrower anchor false-closes here. A textual anchor on
the marker line closes on the `\b` disarm; an anchor on `element1-item-ref` closes on nothing,
since element 1 is merely whichever element fails first when no backlog exists.

**THE FOUR-ARMED RECEIPT WAS NOT ENOUGH AND THE FIX IS WHY.** Its arms are a bare identifier in
code, a substring in code, a bare marker in a comment and a bare `NotImplementedError` — and
three separate wrong implementations satisfy all four. It is replaced by a seven-armed one and
every arm below is the SOLE discriminator for one wrong answer, scored against ten candidate
implementations built as copies under `mktemp`, each `cmp -s`-asserted byte-different from its
source first: **it accepts 2 and rejects 8, with the pre-fix tree exiting 1, the post-fix tree 0
and an absent subject 9.** The two it accepts are the correct fix and a second spelling of it —
a receipt that rejects a competent author's other phrasing is as broken as one accepting a
regression.

The eight it rejects, each by a different arm, are: the shipping defect; **both filed remedies**;
a word boundary with no comment gate; a comment gate over the whole marker set; the marker read
off the raw line; the quote guard removed; and a comment test that looks only at a LEADING
prefix. That last one is the arm this batch had to add, and it was found by the fixture rather
than by reasoning: a leading-prefix test drops every TRAILING comment — `: # TODO` and
`x = 1  # stub` — which is the commonest deferral idiom there is, and it silently took element
3's own seeded adversary out of scope. **A fixture going red on a correct change has usually
lost its subject; the repair is a new subject, not a relaxed assertion.**

**THE WALL-CLOCK DIFFERENTIAL IS UNREADABLE AND IS RECORDED AS SUCH.** Three interleaved reps
over 70 files from inside the repo: 14.49 / 14.09 / 13.59 before against 14.64 / 15.32 / 13.40
after. The spread within one side is larger than the difference between them, so the null means
nothing and is not a cost claim. What bounds the cost is structural — `comment_text` forks only
where the cheap raw-line regex has already matched, which is once per marker rather than once
per line.

Discharges the consumer entry `PC-S303-STUB-AUDIT-MARKER-REGEX-MATCHES-LOCAL-VAR-NAMED-STUB`,
**and its unfiled sibling
`PC-S304-STUB-MARKER-REGEX-MATCHES-DOCSTRING-PROSE-AND-BARE-IDENTIFIERS`, which names the same
script and the same line from the next sprint.** The sibling is cited here because `DISCHARGED`
is keyed on a live candidate being named by an archived entry: fixed without being filed, it
would be invisible to the goal partition. Its own prescribed remedy — comment-gating the `stub`
alternative alone and leaving the other three on the raw line — was built and scored, and it is
one of the eight the receipt rejects.


verify: sh V=core/scripts/validate-stub-audit.sh; [ -f "$V" ] || exit 9; d=$(mktemp -d) || exit 9; mkdir -p "$d/src" || exit 9; : > "$d/bl.md"; printf 'def f():\n    stub = AsyncMock(return_value=None)\n    return stub\n' > "$d/src/a.py"; printf 'def f():\n    # the client_stub helper is fine\n    return 0\n' > "$d/src/b.py"; printf 'def f():\n    # stub, wire later\n    return 0\n' > "$d/src/c.py"; printf 'def f():\n    raise NotImplementedError()\n' > "$d/src/e.py"; printf 'widen() {\n  : # TODO\n}\n' > "$d/src/h.sh"; printf 'emit() {\n  printf "# stub, wire later\\n"\n}\n' > "$d/src/i.sh"; printf 'function s(o) {\n  return o.t;  // stub, wire later\n}\n' > "$d/src/j.js"; r() { bash "$V" --root "$d" --backlog bl.md "$1" >/dev/null 2>&1; echo $?; }; ra=$(r src/a.py); rb=$(r src/b.py); rc=$(r src/c.py); re=$(r src/e.py); rh=$(r src/h.sh); ri=$(r src/i.sh); rj=$(r src/j.js); rm -rf "$d"; [ "$rc" = 1 ] || exit 1; [ "$re" = 1 ] || exit 1; [ "$rh" = 1 ] || exit 1; [ "$rj" = 1 ] || exit 1; [ "$ra" = 0 ] || exit 1; [ "$rb" = 0 ] || exit 1; [ "$ri" = 0 ] || exit 1; exit 0

## BL-069

**LANDED (v0.453.0, verified e411dba1).** The skip now also honours `closes_owed`, and the
coercion behind it is single-sourced as `closes_ids()` so the debt join and the migration arm
cannot answer differently about the same row. Measured on the reference consumer's register,
both binaries in one invocation under a `cmp -s` control asserting they differ: **33 UNDECLARED
before, 24 after — 9 removed, 0 added**, false-negative control **0 of the 9 removed rows lacking
`closes_owed`**. The entry filed 21 flagged / 8 false; the population had grown to 33 / 9 by the
time it was fixed, so the entry was WIDER than filed in absolute terms while its noise FRACTION
fell from 38% to 27% — the genuine remainder grew faster than the noise. Two controls establish
that this narrowed rather than disarmed the arm: 11 rows carry `closes_owed` and only 9 were
being flagged, so the fix removed a proper subset; and the OPEN-debt count (16) and
`mistyped_closes_owed` count (1) are equal on both sides. Receipt exits 1 against the shipped
copy at `origin/main` and 0 against this tree, in one invocation.

**`audit-layer-debt.sh`'s migration arm files its own discharge rows as undeclared debt, so the
metric moves the wrong way in response to the action it exists to encourage.** The arm at
`core/scripts/audit-layer-debt.sh:189-190` skips a row only when `owed` is a dict:

```
    if isinstance(r.get("owed"), dict):
        continue
```

It never consults `closes_owed`. A discharge row carries `closes_owed` and — by the convention
every existing discharge row in the reference consumer's register follows — opens its `reason` with
`Debt discharged.`, which matches the `debt` cue in `PROSE`. **The correct way to close a debt is
also the phrasing that files it as an undeclared one.**

Reproduced behaviourally against the shipping script, with the discriminating control in the same
invocation: a one-row register whose only row is a discharge row with the conventional reason
reports `UNDECLARED (1)`; the byte-differing register carrying the identical row with a neutral
reason reports `UNDECLARED (0)`. The two registers are asserted to differ before either result is
read.

Measured on the reference consumer's register after a six-debt discharge, 213 rows: 21 rows flagged
UNDECLARED, **8 of them carrying `closes_owed`** — false positives — leaving a genuine remainder of
13. 10 discharge rows are present and 8 of the 10 trip it. **38% noise, and it grows by one every
time a debt is correctly closed.** The consumer discharged six debts and watched UNDECLARED rise by
exactly six, which is how it was found.

**This is the second false-positive class in that arm and the first STRUCTURAL one.** The author had
already measured and excluded a LEXICAL class — `debt` inside the identifier
`test-check18-debt-audit`, which is why the `(?<![\w-])…(?![\w-])` guard exists. A narrowing that
fixes cue matching cannot reach this one, because the prose here genuinely is about a debt; the row
simply is not declaring one.

The remedy is to `continue` on `r.get("closes_owed")` as well. Where a discharge row must still be
scannable for a NEW obligation, the schema already permits `owed` and `closes_owed` on one row, so
requiring an explicit `owed` keeps that case reachable rather than exempting it.

The receipt keys on the BEHAVIOUR rather than a substring, because a fix may land in the skip
condition, in the cue set, or in the discharge-row convention, and no anchor survives all three. Its
sanity arms exit 9: the script must exist, the two registers must differ, both runs must exit 0,
both counts must parse, and **the neutral-reason control must itself report 0** — without that last
arm a script that flagged everything, or nothing, would read identically to one that discriminates.

Verified in both directions: against the shipping tree the receipt exits **1** (STILL-LIVE); against
a copy whose skip condition also honours `closes_owed` it exits **0**, with the copy asserted to
differ from shipping before the result was read.

Found by the graph consumer session while discharging six artifact-path layer debts. Cross-references
the consumer entry
`PC-S334-AUDIT-LAYER-DEBT-FLAGS-ITS-OWN-DISCHARGE-ROWS-AS-UNDECLARED-DEBT`.

verify: sh S=core/scripts/audit-layer-debt.sh; [ -f "$S" ] || exit 9; d=$(mktemp -d) || exit 9; h="{\"clause\":\"LC-E1\",\"entry\":\"extensions/p.md\",\"subject_digest\":\"da39a3e\",\"verdict\":\"still-additive\",\"recorded_utc\":\"1970-01-01T00:00:00Z\",\"closes_owed\":[\"OWED-X\"],\"reason\":"; printf "%s\"Debt discharged. The repath landed.\"}\n" "$h" > "$d/a.jsonl"; printf "%s\"The repath landed.\"}\n" "$h" > "$d/b.jsonl"; cmp -s "$d/a.jsonl" "$d/b.jsonl" && { rm -rf "$d"; exit 9; }; a=$(bash "$S" --register "$d/a.jsonl" 2>/dev/null); ra=$?; b=$(bash "$S" --register "$d/b.jsonl" 2>/dev/null); rb=$?; rm -rf "$d"; [ "$ra" = 0 ] && [ "$rb" = 0 ] || exit 9; na=$(printf "%s" "$a" | sed -n "s/.*UNDECLARED (\([0-9]*\)).*/\1/p" | head -1); nb=$(printf "%s" "$b" | sed -n "s/.*UNDECLARED (\([0-9]*\)).*/\1/p" | head -1); [ -n "$na" ] && [ -n "$nb" ] || exit 9; [ "$nb" = 0 ] || exit 9; [ "$na" = 0 ]


## BL-134 — Check 22 judged the harness's own agent types against a role contract they never had

**LANDED (v0.472.0, verified b4b82b03).** **CORRECTED at v0.473.0 — read that entry in the
CHANGELOG before this text.** `v0.472.0`'s residue figure ("25 arms, 14 genuine uncited plus 11
mismatches") is WRONG: read by ROW rather than by arm, 24 of those 25 are on `<unnamed>` rows the
dispatch guard did not write, and exactly one — `gate-adjudicator-s304-story4-impl` — is a genuine
finding. `--ledger` is an append-only file any session can write to; that consumer carries 14 rows
in a hand-written provenance schema, 13 of them naming a declared role, whose ABSENT fields the
check was reading as observations. **The corrected figure is 25 arms → 1.** The receipt below is
`v0.473.0`'s and is not the one this entry rotated on; the one it rotated on could not see the
empty-role guard at all.

Closes `PC-S340-VALIDATE-SPAWN-LEDGER-OVERSHOOTS-CHECK-22-DECLARED-ROLE-SCOPE`, filed by the
reference consumer while routing its carry-over `CO-S307-SPAWNLEDGER-SCOPE-OVERSHOOT`.

`ai-dlc-dispatch-guard.sh` derives a row's `role` from `subagent_type` whenever the prompt cited
no `team-roles/<role>.md`, and that fallback accepts any lowercase agent type — so the harness's
built-in types land in the spawn ledger carrying `role_contract_cited=false` and
`role_file_readable=false`. `validate-spawn-ledger.sh` judged every one of them, and each is two
Rule 19 violations that no consumer action can ever clear: there is no contract for a
`general-purpose` dispatch to cite and no role file for it to resolve.

**Measured on the reference consumer's ledger, sprints 298–307, two independent derivations
reconciled exactly.** 122 FAIL arms = 48 unreadable + 63 uncited + 11 tier mismatch. Of the 111
role arms, 97 are on roles declared nowhere in that consumer's `aiDlcRoles` (`general-purpose` 84,
`fork` 12, one other), against 14 genuine. Seven of eight sprints exited 1; the lead re-derived the
in-scope subset by hand at every implementation gate for the exit code to mean anything.

**THE FILED REMEDY WAS BUILT FIRST AND IS REFUTED.** It asks for Check 22's five gate-trigger roles
as the row scope. Scored on that same ledger it drops to 2 arms — it acquits 23 of the 25 genuine
findings, because `adversary`, `remediator`, `pm`, `architect`, `gate-adjudicator`, `tea`, `ux` and
`pm-escalated` are all real team roles Rule 19 binds and none is in the five. The five are the
gate TRIGGER, not the row scope, and the fix says so in `gate-validation.md` rather than leaving
the two readings of that section standing.

**The scope key is DECLARATION and it is derived, not listed.** A row is judged when it cited a
role contract, or when its role is a key of `aiDlcRoles` — the surface Rule 19 already names as its
single source of truth, which the script already reads for the pin, and which **I22** binds to
`core/team-roles/*.md` in both directions. The `role_contract_cited` disjunct is what keeps the
filter from being a disarm: deleting an `aiDlcRoles` entry cannot silence a finding against a
dispatch that cited its contract, and it is also what keeps the fail-closed `role_file_readable`
arm reachable for an undeclared role. Out-of-scope rows are counted and NAMED in `COUNTS:`, and a
sprint whose every row is out of scope exits 3 rather than passing on a comparison it never made.

**AN ADVERSARIAL HAND FOUND THE FILTER'S JOIN KEY IS THE FIELD THE VIOLATION CORRUPTS.** A real
team role dispatched with `subagent_type: general-purpose` and no contract citation records
`role: general-purpose`, so naming the skipped ROLE surfaces nothing. **18 of the 49 skipped rows
on that consumer are that shape** — `dev-escalated-s299-1-v4`, `code-reviewer-s299-1-fixforward`,
`qa-s299-1-fixforward`, three `gate-adjudicator-story-s302-*` and twelve more across four sprints,
reproduced by two independent derivations. The `role_contract_cited` disjunct cannot reach them:
being uncited IS the violation. The dispatch NAME is therefore read as a second signal and every
skipped row named after a declared role is NOTEd by name and counted — a NOTE and not a FAIL,
because a utility genuinely named `dev-*` is a false-positive path and `mechanism-design.md`
forbids erroring on correct data. Check 22 now tells the adjudicator to disposition each one.

Two more from the same hand: the doc sentence naming the filter's only failure mode named the
RARE one (a deleted `aiDlcRoles` entry) while the common one hid inside the list it told the
reader to ignore; and the `COUNTS:` role list de-duplicated only its first element, a
space-separated accumulator against a newline-delimited membership test.

**THE FIRST RECEIPT NEVER READ AN EXIT CODE AND ACCEPTED A TOTAL VERDICT DISARM.** Scored by a
second hand against sixteen implementations, it accepted six — a fix that prints every `FAIL:`
line and exits 0, one with the exit-3 arm removed, and a five-line script that examines nothing
and prints canned text. Four content arms over merged stdout and stderr are four arms a `printf`
can forge. The receipt asserts three EXIT CODES now — 1 on a violating ledger, 1 on a cited
undeclared row, 3 on an all-out-of-scope one — beside its content arms, and carries a row whose
undeclared role is not a harness built-in, which is the input separating a DERIVED scope from a
hardcoded `{general-purpose, fork, claude}`.

Two further correctness defects came out of the same pass. An empty role was a DECLARED role: with
no `aiDlcRoles` block `DECLARED_NL` is two newlines, the pattern an empty role builds, so a
role-less row was judged and its scope depended on how many roles the file declared. And the
vocabulary claim named the wrong file — `I22` binds `templates/settings.json.template`, not the
consumer's `.claude/settings.json` that `--settings` reads, so the scope key is bound at INSTALL
and unbound thereafter.

**THE SAME HOLE THEN SURVIVED ONE ARM OVER.** With the exit codes asserted, a build whose `COUNTS:`
named no role at all still passed — the arm meant to bind the role list had been dropped, and the
new `NOTE:` supplied the role token by itself. So did one whose out-of-scope counter never
incremented, because the count sentence prints unconditionally. Both are now bound: the receipt
asserts the COUNT and names an out-of-scope role (`rubric-walker`) that no implementation can
produce without having read the row.

**ONE COST, TAKEN DELIBERATELY.** A build that rewords the `COUNTS:` sentence while keeping the
role list and the count now scores STILL-LIVE. That sentence is what `gate-validation.md` tells the
lead to record in the gate log and what `enforcement-map.yaml`'s posture line points at, so a
reword IS a change to the published contract. A rewrite of the SCOPE TEST is accepted — the second
spelling deletes `row_in_scope` entirely and inlines it.

Scored against fifteen implementations: it ACCEPTS the fix and a second spelling, and REJECTS the
pre-fix script, the filed five-role remedy, a total disarm, the fix minus its cited disjunct, a fix
that skips out-of-scope rows without counting them, one that skips a role-named row without NOTEing
it, one that exits 0 on violations, one with the exit-3 arm deleted, one that hardcodes the harness
types as an exclusion list, a canned-output script that examines nothing, one whose `COUNTS:` names
no role, one whose skip counter is stuck at zero, and the reword above.

**THE FIXTURE IS THE STRONGER MECHANISM AND THAT IS MEASURED, NOT ASSERTED.** Every implementation
this receipt ever accepted is killed by `core/fixtures/check-22-spawn-ledger/run.sh` — run in a
probe tree with the shipped script as a passing control, the canned-output script fails all 28
assertions, the hardcode 3, the missing exit-3 arm 5. No wrong-accept was ever a live coverage gap.

verify: sh V=core/scripts/validate-spawn-ledger.sh; set -e; d=$(mktemp -d); printf '%s' '{"aiDlcModels":{"o":"opus"},"aiDlcRoles":{"adversary":{"model":"o"}}}' > "$d/s.json"; printf '%s' '{"aiDlcModels":{"o":"opus"},"aiDlcRoles":{}}' > "$d/e.json"; printf '%b' '{"v":1,"sprint":900,"name":"gp","role":"general-purpose","model_bound":"i","model_requested":"i","role_contract_cited":false,"role_file_readable":false}\n{"v":1,"sprint":900,"name":"walker","role":"rubric-walker","model_bound":"i","model_requested":"i","role_contract_cited":false,"role_file_readable":false}\n{"v":1,"sprint":900,"name":"adversary-misrouted","role":"general-purpose","model_bound":"i","model_requested":"i","role_contract_cited":false,"role_file_readable":false}\n{"sprint":900,"role":"adversary","dispatched_at":"t","deliverable":"x.md","sha":"a","step":"s"}\n{"v":1,"sprint":900,"name":"adv","role":"adversary","model_bound":"o","model_requested":"o","role_contract_cited":false,"role_file_readable":true}\n' > "$d/l.jsonl"; printf '%b' '{"v":1,"sprint":900,"name":"gpc","role":"general-purpose","model_bound":"x","model_requested":"x","role_contract_cited":true,"role_file_readable":false}\n' > "$d/c.jsonl"; printf '%b' '{"v":1,"sprint":900,"name":"gponly","role":"general-purpose","model_bound":"i","model_requested":"i","role_contract_cited":false,"role_file_readable":false}\n' > "$d/o.jsonl"; printf '%b' '{"v":1,"sprint":900,"name":"nr","role":null,"model_bound":"i","model_requested":"i","role_contract_cited":false,"role_file_readable":true}\n' > "$d/n.jsonl"; a=$(bash "$V" --ledger "$d/l.jsonl" --sprint 900 --settings "$d/s.json" 2>&1) && ra=0 || ra=$?; b=$(bash "$V" --ledger "$d/c.jsonl" --sprint 900 --settings "$d/s.json" 2>&1) && rb=0 || rb=$?; o=$(bash "$V" --ledger "$d/o.jsonl" --sprint 900 --settings "$d/s.json" 2>&1) && ro=0 || ro=$?; bash "$V" --ledger "$d/n.jsonl" --sprint 900 --settings "$d/s.json" >/dev/null 2>&1 && n1=0 || n1=$?; bash "$V" --ledger "$d/n.jsonl" --sprint 900 --settings "$d/e.json" >/dev/null 2>&1 && n2=0 || n2=$?; [ "$ra" -eq 1 ] || exit 1; [ "$rb" -eq 1 ] || exit 1; [ "$ro" -eq 3 ] || exit 1; [ "$n1" -eq "$n2" ] || exit 1; [ "$n1" -eq 3 ] || exit 1; case "$a" in *"3 row(s) out"*) ;; *) exit 1 ;; esac; case "$a" in *rubric-walker*) ;; *) exit 1 ;; esac; case "$a" in *"1 row(s) the dispatch guard did not write"*) ;; *) exit 1 ;; esac; case "$a" in *"FAIL: [adv]"*) ;; *) exit 1 ;; esac; case "$a" in *"NOTE: [adversary-misrouted]"*) ;; *) exit 1 ;; esac; case "$a" in *"FAIL: [gp]"*) exit 1 ;; esac; case "$a" in *"FAIL: [walker]"*) exit 1 ;; esac; case "$a" in *"FAIL: [<unnamed>]"*) exit 1 ;; esac; case "$b" in *"FAIL: [gpc]"*) ;; *) exit 1 ;; esac; exit 0
## BL-135 — the derivation allowlist split a command on `|` without regard for quoting, and refused correct read-only commands

**LANDED (v0.474.0, verified 3453285f).**

Cites `PC-S340-DERIVATION-CAPTURE-HOOK-ROLLS-BACK-THE-WHOLE-FILE-ON-A-REJECTED-BLOCK`.

`cmd_is_safe()` in `core/scripts/validate-artifact-derivations.sh` splits a fenced command into
pipeline segments and requires every segment's first word to be on the read-only allowlist. It did
that with `tr '|' '\n'`, which is quote-blind, so a bar inside a quoted ERE was read as a pipe and
the fragment after it was refused as an unknown command:

    $ grep -cE 'alpha|beta' data.txt   ->  FAIL (ALLOWLIST), refused token `'beta'`
    $ grep -cE 'alpha' data.txt        ->  exit 0, the near-miss that names the cause

**THE ENTRY IT CITES HAS TWO CLAIMS AND ONLY ONE SURVIVED. Both are kept here rather than
re-filed, because which half died is the part that stops the next reader repeating it.** The
filing's headline was that the rejection ROLLED BACK the whole target file, destroying a consumer
artifact. That is REFUTED against the tree: `core/hooks/ai-dlc-derivation-capture.sh` is a
PostToolUse hook that reads the target, writes only inside its own `mktemp -d`, and on a mismatch
emits stderr and exits 2 — it has no write, truncate, move or remove path against the target at
all. The parse half is real, and it is what this entry closes.

**THE FALSE-REFUSAL POPULATION IS MEASURED, NOT ESTIMATED.** A verdict differential drove the
extracted `cmd_is_safe()` from both implementations over the 3408 `$ `-prefixed command lines in
the reference consumer's 237 fence-carrying artifacts: **43 newly allowed, 0 newly refused**.
Controls in the same invocation: the two extracted functions differ (4893 vs 7817 bytes) and both
extractions end at a function close. The 43 split three ways — a bar inside quotes, a
backslash-escaped bar, and a quoted bar sitting beside a genuine pipe — and all three are the same
defect wearing different clothes.

**THE UNBALANCED-QUOTE REFUSAL IS LOAD-BEARING, AND A MUTANT IS WHY THAT IS KNOWN.** Splitting
quote-aware without refusing an unresolved quote opens a hole the old code closed:
`grep $'a\'b' f | xargs rm` is ONE word plus a real pipe to bash, while a quote-parity scan sees an
odd number of quotes and stops splitting — so the segment's first word is `grep` and `xargs rm`
never gets checked. Scored against a copy of the fix with that refusal deleted: pre REFUSE, fix
REFUSE, no-refusal **ALLOW**, with bash confirming it parses. The guard is not tidiness.

**MY OWN NEW ARM SHIPPED A FALSE REFUSAL FIRST, AND ONLY AN INDEPENDENT PARSER FOUND IT.** Checked
against `bash -n -c`, which is the actual executor and therefore ground truth, the quote scan
disagreed on exactly two of 3408 — both `python3 # ... test_safeguards.py's own regex`, where bash
reads the apostrophe inside a `#` COMMENT and the scan did not. Left alone that would have refused
`grep -c x f # note`, a correct allowlisted command, which is the very class this change exists to
remove. The scan now ends a command at an unquoted `#` opening a word. Cross-checked separately
against python `shlex`: 0 disagreements on top-level pipe count across the 3381 both parse.

**Tiered DEFECT.** It refuses correct data, and since `ai-dlc-derivation-capture.sh` began re-running
a block inside the tool call that wrote it, the refusal blocks an author's write with no human in the
loop — the state this repo's own comment says gets a hook turned off.

**THE RECEIPT WAS SCORED, AND ITS FOURTH ARM EXISTS BECAUSE THE FIRST THREE ACCEPTED A
REGRESSION.** Seven implementations were built and scored — the fix, a second spelling that masks
quoted regions and splits with `tr`, the pre-fix original, a version that never splits, the fix
minus its unbalanced-quote refusal, a total disarm, and one with the allowlist widened to every
command on `PATH`. Each was asserted to differ from the fix first. Three arms accepted **3 of 7**,
the extra being the no-refusal variant: every one of its inputs still exits 1, because a command
bash cannot run fails as STALE instead of ALLOWLIST, so an exit-code-only arm cannot separate them.
The fourth arm reads the failure CLASS for an ANSI-C quoted input, and the count is **2 of 7**.

The receipt drives the shipped validator four ways in one run: a quoted alternation must PASS, a
non-allowlisted command behind a genuine pipe must still FAIL, a trailing `#` comment must PASS,
and `$'...'` hiding a pipe must be refused as UNBALANCED rather than merely failing. The second arm
rejects the regression that "fixes" this by not splitting at all; the fourth rejects the one that
drops the refusal. Note that a reword of the `unbalanced quote` phrase scores STILL-LIVE — that
string is what the fourth arm keys on, and no vocabulary binds it.

verify: sh set -e; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; printf 'alpha\nbeta\n' > "$d/f.txt"; V=core/scripts/validate-artifact-derivations.sh; printf '```derived\n$ grep -cE "alpha|beta" f.txt\n2\n```\n' > "$d/a.md"; printf '```derived\n$ grep -c alpha f.txt | xargs echo\n1\n```\n' > "$d/b.md"; printf '```derived\n$ grep -c alpha f.txt # note\n1\n```\n' > "$d/c.md"; printf '```derived\n$ grep $\047a\\\047b\047 f.txt | xargs rm\n2\n```\n' > "$d/e.md"; AI_DLC_PROJECT_ROOT="$d" bash "$V" "$d/a.md" >/dev/null 2>&1 || exit 1; AI_DLC_PROJECT_ROOT="$d" bash "$V" "$d/b.md" >/dev/null 2>&1 && exit 1; AI_DLC_PROJECT_ROOT="$d" bash "$V" "$d/c.md" >/dev/null 2>&1 || exit 1; o=$(AI_DLC_PROJECT_ROOT="$d" bash "$V" "$d/e.md" 2>&1) || true; case "$o" in *"unbalanced quote"*) ;; *) exit 1 ;; esac; exit 0

## BL-136 — `v0.474.0` made the derivation split quote-aware and acquitted five arbitrary-execution paths in the same edit

**LANDED (v0.475.0, verified 9c1a1645).**

Fixes a regression this repo shipped one release earlier. `v0.474.0` replaced `tr '|' '\n'`
in `cmd_is_safe()` with a quote-aware split, removing 31 false refusals. **The quote-blind
split was also, by accident, the only thing refusing five arbitrary-execution vectors**, and
removing the accident removed the refusal. Found by an adversarial hand AFTER the merge and
reproduced here independently with a canary file as the observable, driving the whole
validator end to end:

    grep -c $'a\'b' data.txt | xargs touch canary \'      pre: REFUSED   v0.474.0: RAN
    grep -c $'\''   data.txt | xargs touch canary \'      pre: REFUSED   v0.474.0: RAN
    grep -c $'a\'b' data.txt | xargs touch canary\'       pre: REFUSED   v0.474.0: RAN
    awk 'BEGIN{print "" | "touch canary"}'                pre: REFUSED   v0.474.0: RAN
    awk 'BEGIN{"touch canary" | getline x}'               pre: REFUSED   v0.474.0: RAN

**THE TWO CLASSES HAVE DIFFERENT CAUSES AND NEEDED DIFFERENT ARMS.** `$'...'` is ANSI-C
quoting: bash reads an escaped quote inside it as a LITERAL where a parity scan reads a
toggle, so the two finish balanced while disagreeing about where the quotes were, and a bar
lands in that window. The awk vectors need no quoting trick at all — `print | "cmd"` and
`"cmd" | getline` are awk's own pipes to a shell, invisible to the metacharacter ban because
they contain no shell metacharacter, and `awk:*system(*` covers only one of three exec forms.

**BOTH OBVIOUS ONE-LINE ARMS HAVE A MEASURED FALSE-POSITIVE SET, WHICH IS WHY NEITHER
SHIPPED.** Banning `$'` as a SUBSTRING in the up-front metacharacter test refuses **21**
correct commands in the reference corpus, every one a regex end-anchor before a closing quote
(`grep -n '...verdict$'`). Only the quote STATE separates those from ANSI-C quoting, so the
test sits inside the scanner where that state exists; there its false-positive set is 0 by
construction. Refusing an awk segment whose bar sits adjacent to a double quote falsely
refuses `awk -F'|' '{print $2,"|",$3,"|",$7}'`, which is real and present in that corpus.

**AWK THEREFORE KEEPS ITS PRE-SPLIT BEHAVIOUR: any bar in an awk segment is refused.**
Separating an exec vector from `/alpha|beta/` requires scanning awk's own string and regex
grammar — a second parser and a second divergence surface, on a boundary that just produced
one. Those commands are refused TODAY for the accidental reason, so this is not a new
refusal; it costs the 3 awk alternations in the corpus, which stay exactly as they are.

**THE PUBLISHED FIGURE FROM `v0.474.0` WAS WRONG AND IS CORRECTED HERE: 31, NOT 43.** That
count was taken over every `$ `-prefixed line in a fence-carrying FILE. The population
`cmd_is_safe` actually sees is the lines INSIDE a ```derived fence, which is 3044 of 3408 —
364 sit outside any fence and are never submitted. Re-run fence-aware against the
pre-`v0.474.0` original: **31 newly allowed, 0 newly refused.**

**Tiered BLOCKER while it was live.** A ```derived fence could execute arbitrary commands,
and `ai-dlc-derivation-capture.sh` runs this boundary inside the tool call that writes the
block, with no human in the loop. No consumer was exposed — the reference consumer is
installed at `0.471.0` and the regression existed only in this distribution's `main`.

**THE GATE WAS GREEN THROUGHOUT, AND THAT IS THE LESSON.** Every arm in
`core/fixtures/artifact-derivations` asserted a VERDICT, and no arm ran a command and then
looked at the tree. Section H now scores by execution: each case is first run by bash
directly and must create the canary — that is what makes it an exec vector rather than a
string resembling one — and only then put through the validator, where the canary must not
appear. Against `v0.474.0` those arms report `EXECUTED through the validator`; the fixture
would have caught this.

verify: sh set -e; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; V=$PWD/core/scripts/validate-artifact-derivations.sh; cd "$d"; printf 'alpha\nbeta\n' > f.txt; printf '```derived\n$ awk \047BEGIN{print "" | "touch canary"}\047\n0\n```\n' > a.md; printf '```derived\n$ grep -cE "alpha|beta" f.txt\n2\n```\n' > b.md; bash -c 'awk "BEGIN{print \"\" | \"touch canary\"}"' >/dev/null 2>&1; [ -e canary ] || exit 1; rm -f canary; AI_DLC_PROJECT_ROOT="$d" bash "$V" a.md >/dev/null 2>&1 || true; [ -e canary ] && exit 1; AI_DLC_PROJECT_ROOT="$d" bash "$V" b.md >/dev/null 2>&1 || exit 1; exit 0

## BL-138 — the re-adoption gate tests one direction of a two-sided difference, and matches whole lines

**LANDED (v0.476.0, verified ed9bf798).**

**Provenance: `PC-S340-STAMP-READOPT-GATE-IS-BLIND-TO-AN-ADDITIVE-CHANGE-AND-TO-A-REWRITTEN-BODY`**,
filed by the reference consumer during its `0.452.0 -> 0.456.0` pull. **FIXED in this release** —
this entry records what was measured, which of the filing's two claims survived, and what was
deliberately left.

`readopt-override.sh`'s `stale_lines()` computed one set difference — substantive lines core
carried at `base_sha` and does not carry at `theirs`, still present in the override body — and
tested body membership with a whole-line fixed-string match. Two failures, and the first is the
one that costs a consumer a fix:

- **A purely ADDITIVE upstream change yields an empty stale set BY CONSTRUCTION.** `--check`
  printed OK, `--stamp readopt` then rewrote `base_sha`, and drift is computed
  `base_sha..theirs` — so the next pull sees no drift on that section and never offers the new
  core text again. The block is cleared by doing nothing, permanently, and every mechanical
  check stays green.
- **A whole-line test cannot see a body that re-wrapped what it copied.** An override of a
  section the consumer rewrote is a re-wrap by definition, so the predicate was weakest exactly
  where it was needed.

**Measured on the entry's own motivating case** — the consumer's `steps__retro__domain-sections.md`
at the revision the pull stamped, `base_sha a5cbdf0b` against `theirs 95670e58`: the shipping gate
exits **0**, and core's `#4a. Close-Out Sweep` gained **5** substantive lines the body does not
carry. The same run scores its other three anchors at 0, so the reading discriminates rather than
firing on any moved file.

**The fix** adds `unadopted_lines()` — the same difference with `comm -13` and the body test
negated — and replaces the whole-line body test with `body_carries()`, a containment test against
the body flattened to one line. `--check` reports `UNADOPTED-CORE-TEXT`, `--stamp readopt` refuses,
and the dossier carries the matching panel. `--merge` already produces the body that clears it.

**The containment corpus is the body past the frontmatter fence, and the first cut read the whole
file.** `reason:` is prose about the override; quoting upstream's clause there to DECLINE it scored
it as adopted, clearing the gate on the entry whose own sentence says it was not. Found by
attacking the change rather than by review, measured at exit 0 against a control of 1 for the same
entry with the clause nowhere, and fixed by reusing `--merge`'s body extractor so the two cannot
disagree about where a body starts. The fixture arm carries both halves in one run.

**False-positive set: 0.** The consumer's 8 live overrides, each at its own declared `base_sha`
against this distribution's `origin/main`, scored pre-fix and fixed: 0 refused either way, 0 newly
refused. Controls in the same invocation: `cmp -s` asserts the two implementations differ, and the
pre-fix copy was materialised beside its own `lib.sh` — a lone script copy dies sourcing it, and
that exit reads as a finding while being a refusal.

**The filing's REWORD half is not fixed and is not claimed.** Its second measurement is a deleted
core line surviving in the body reworded — "relocate" where core says "archive" — which no
containment test over core's own words can reach. On the motivating entry the UNADOPTED direction
catches the file anyway; in general a reword inside an otherwise-adopted section is what
`--stamp reaffirm --note` exists for.

**NOTE, found while proving the gate satisfiable and NOT fixed here:** `--check` reports OK on a
body containing unresolved `<<<<<<<` conflict markers. `--stamp readopt` refuses on them, so
nothing can be stamped away, but the gate's own OK line is wrong about a body a `--merge` has just
conflicted on. Separate claim, separate arm, not part of this entry's subject.

**The consumer's own receipt for this candidate cannot see the fix.** It is a substring test for
the removed flags over the whole file, so a comment quoting them would keep it matching forever;
this release therefore describes the deleted spelling rather than reproducing it, and the token is
now absent from the file (control: present at `origin/main`, and carried by no other file in that
directory). That is the only reason their entry can close.

verify: sh set -e; RO="$PWD/core/skills/ai-dlc-update/reconcile/readopt-override.sh"; ROOT="$(bash "$PWD/core/fixtures/layer-readopt-gate/seed.sh")"; trap 'rm -rf "$ROOT"' EXIT; D="$ROOT/dist"; C="$ROOT/consumer"; O="$C/.claude/skills/ai-dlc/overrides"; printf '\n**A NEW UPSTREAM CLAUSE ADDED TO THE SWEEP RULE**, recorded here and nowhere\nelse, so the change to this section is purely additive.\n' >> "$D/core/skills/ai-dlc/SKILL.md"; git -C "$D" -c user.email=f@x -c user.name=f commit -aqm additive; T="$(git -C "$D" rev-parse --short HEAD)"; A="$O/SKILL__Rule-19-nested.md"; B="$(sed -n 's/^base_sha:[[:space:]]*//p' "$A" | head -1)"; ! bash "$RO" "$D" "$T" "$C" "$A" --stamp readopt >/dev/null 2>&1; [ "$(sed -n 's/^base_sha:[[:space:]]*//p' "$A" | head -1)" = "$B" ]; bash "$RO" "$D" "$T" "$C" "$O/SKILL__Rule-12-anchor.md" --check >/dev/null 2>&1; printf -- '---\nshadows: SKILL.md#Rule 19\nbase_sha: %s\nreason: adopted at its own wrap.\n---\n\n## Rule 19 -- Sweep (CONSUMER OVERRIDE)\n\nThe near-miss for the same arm: its override nests a sub-heading INSIDE the claimed section.\nA heading-set difference would report that child; a span-based claim does not.\n\n**A NEW UPSTREAM CLAUSE ADDED TO THE SWEEP RULE**, recorded here and\nnowhere else, so the change to this section is purely additive.\n' "$B" > "$O/adopted.md"; bash "$RO" "$D" "$T" "$C" "$O/adopted.md" --check >/dev/null 2>&1; printf -- '---\nshadows: SKILL.md#Rule 8\nbase_sha: %s\nreason: consumer validation-intensity table.\n---\n\n## Rule 8 -- Validation Depth\n\n**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass\nN+1 reports more CRITICALs than pass N, the repair step is injecting\ndefects faster than review removes them; another pass only finds the\nnext wave. STOP.\n' "$B" > "$O/SKILL__Rule-8.md"; ! bash "$RO" "$D" "$T" "$C" "$O/SKILL__Rule-8.md" --check >/dev/null 2>&1

**Scored against eight implementations, each asserted to differ from the fix first: the receipt
ACCEPTS 2** — the fix and a second spelling that flattens with `awk` and tests with `grep -Fq`. It
rejects the pre-fix original, a variant that reports the new finding in `--check` but does not gate
the stamp (caught by the `base_sha` arm alone), the flattening without the new direction, the new
direction without the flattening, a disarmed `unadopted_lines`, and an over-refusing variant that
ignores the body and refuses every moved section. The FIXTURE passes only the fix: the second
spelling fails it because the committed mutant is anchored on the shipped flattening and `cmp -s`
correctly reports an un-applied mutation rather than a kill.

The receipt drives the shipping script over a real dist repo and a real consumer tree that
`seed.sh` writes, and it is four assertions rather than one: the additive offender must be
REFUSED, `base_sha` must still hold its old value afterwards (an implementation that reports and
stamps anyway passes any exit-code-only arm), a section that did not move must still be ALLOWED,
and the SAME moved section adopted at a different wrap must also be ALLOWED — without that last
one the receipt is satisfied by refusing every entry whose section changed, which passes the first
three and wedges every legitimate re-adoption. The fourth arm is the superseded-and-re-wrapped
body, which keys on the flattening rather than on the new direction.
## BL-139 — the un-adopted arm shipped as a REFUSAL, and a refusal there loses the clause it protects

**LANDED (v0.477.0, verified 36e36f0e).**

**Provenance: `PC-S340-STAMP-READOPT-GATE-IS-BLIND-TO-AN-ADDITIVE-CHANGE-AND-TO-A-REWRITTEN-BODY`**,
the same candidate `BL-138` closed. **FIXED in `v0.477.0`**, which corrects `v0.476.0`. Raised by a
late adversarial hand and re-derived here against the consumer's own history before acting on it.

**A body is a REWRITE by definition, so the mirror predicate inherits the defect it fixes.** The
filing's own claim is that a line-literal test cannot see a body that REWORDED what it copied;
`unadopted_lines()` is that test with the sign flipped, so it cannot see a body that adopted
upstream's addition by rewording — and `v0.476.0` REFUSED on that.

**Measured on 27 real adjudications, not on a constructed case.** Every commit in the reference
consumer's history where an override's `base_sha` moved, with the body as it stood when the stamp
was taken — `--merge` writes the body and `--stamp` rewrites only `base_sha`, and both land in one
commit. 35 events, **27 re-adoptions / 8 reaffirms**, split by the tool's own
`RE-AFFIRMED against <sha>` record. Scored against three implementations, each asserted to differ
from the others first (27103 / 34243 / 36938 bytes):

    pre-v0.476.0  allows 27/27      (it must -- these stamps happened)
    v0.476.0      allows 10/27      -> 17 newly refused: 7 unadopted, 10 stale
    v0.477.0      allows 17/27      -> the 7 unadopted refusals are gone

**The escape is worse than the wedge, which inverts the argument that shipped it.** `v0.476.0`
recorded that the refusal "terminates rather than wedging" because `--stamp reaffirm --note`
advances `base_sha`. True, and that is the defect: a falsely refused re-adoption routed to
reaffirm is re-stamped, so the clause is never offered again — permanently, under a note asserting
the consumer declined text it had already adopted. That is the failure this file exists to
prevent, reached THROUGH the new arm instead of around it.

**So the un-adopted direction REPORTS.** `--check` prints the panel and exits 0 when that is the
only finding; `--stamp readopt` prints it and lands. The filed defect was SILENCE, and silence is
what is gone. Superseded text still refuses, unchanged.

**An HTML comment is not the body either, and the frontmatter fix left this target open.** The same
upstream lines pasted into `<!-- … -->` inside the body scored as adoption, against a near-miss
control of unrelated text in the same place that did not — and `--check` prints the offending
lines verbatim, so the tool emitted the exact text that silenced it. Comment spans are stripped
before flattening, both directions.

**Two figures `BL-138` published are corrected.** Its "false-positive set 0 over the consumer's 8
live overrides" was a check that could not fire: all 15 shadowed anchors are byte-identical
`base_sha`→`origin/main`, derived two ways, while the enclosing files moved hard — `OK` was the
only reachable verdict, so that FP set is UNMEASURABLE rather than zero. And its "5 lines absent
from the body" holds for the PRE-merge body it names and reads as 1 against the body at stamp
time, because the operator's merge had already adopted 4 of the 5 verbatim.

**The 10 surviving refusals are the superseded direction and are the filed defect working.** Of 38
carried stale lines, 25 are re-wraps and 13 are a core line inside a longer body line. The one
event resting entirely on the second kind was adjudicated by reading it — both matches are the
body carrying core's superseded clause, extended or re-flowed. The other nine are not
individually adjudicated and are **not** claimed.

verify: sh set -e; RO="${RECEIPT_SUBJECT:-$PWD/core/skills/ai-dlc-update/reconcile/readopt-override.sh}"; ROOT="$(bash "$PWD/core/fixtures/layer-readopt-gate/seed.sh")"; trap 'rm -rf "$ROOT"' EXIT; D="$ROOT/dist"; C="$ROOT/consumer"; O="$C/.claude/skills/ai-dlc/overrides"; CL='**A NEW UPSTREAM CLAUSE ADDED TO THE SWEEP RULE**, recorded here and nowhere else in core.'; printf '\n%s\n' "$CL" >> "$D/core/skills/ai-dlc/SKILL.md"; git -C "$D" -c user.email=f@x -c user.name=f commit -aqm additive; T="$(git -C "$D" rev-parse --short HEAD)"; A="$O/SKILL__Rule-19-nested.md"; B="$(sed -n 's/^base_sha:[[:space:]]*//p' "$A" | head -1)"; out="$(bash "$RO" "$D" "$T" "$C" "$A" --check 2>&1)"; printf '%s' "$out" | grep -q 'UNADOPTED-CORE-TEXT'; bash "$RO" "$D" "$T" "$C" "$A" --check >/dev/null 2>&1; bash "$RO" "$D" "$T" "$C" "$A" --stamp readopt >/dev/null 2>&1; [ "$(sed -n 's/^base_sha:[[:space:]]*//p' "$A" | head -1)" = "$T" ]; F="$O/fm.md"; printf -- '---\nshadows: SKILL.md#Rule 19\nbase_sha: %s\nreason: we decline %s\n---\n\n## Rule 19 -- Sweep (CONSUMER OVERRIDE)\n\nConsumer sweep rules.\n' "$B" "$CL" > "$F"; printf '%s' "$(bash "$RO" "$D" "$T" "$C" "$F" --check 2>&1)" | grep -q 'UNADOPTED-CORE-TEXT'; H="$O/hc.md"; printf -- '---\nshadows: SKILL.md#Rule 19\nbase_sha: %s\nreason: consumer sweep rules.\n---\n\n## Rule 19 -- Sweep (CONSUMER OVERRIDE)\n\nConsumer sweep rules.\n\n<!--\n%s\n-->\n' "$B" "$CL" > "$H"; printf '%s' "$(bash "$RO" "$D" "$T" "$C" "$H" --check 2>&1)" | grep -q 'UNADOPTED-CORE-TEXT'; P="$O/ad.md"; printf -- '---\nshadows: SKILL.md#Rule 19\nbase_sha: %s\nreason: consumer sweep rules.\n---\n\n## Rule 19 -- Sweep (CONSUMER OVERRIDE)\n\nConsumer sweep rules.\n\n%s\n' "$B" "$CL" > "$P"; ! printf '%s' "$(bash "$RO" "$D" "$T" "$C" "$P" --check 2>&1)" | grep -q 'UNADOPTED-CORE-TEXT'

## BL-141 — the debt audit charges an adjudicator for writing down that nothing is owed

**LANDED (v0.478.0, verified 36cb2ac3).**

**Filed from the reference consumer's push-candidate ledger**, 2026-09-02, as
`PC-S340-UNDECLARED-CUE-CANNOT-TELL-A-REFERENCE-FROM-A-DECLARATION`, and FIXED in the same
release. The third false-positive class of `audit-layer-debt.sh`'s UNDECLARED arm, after the
lexical one (a cue inside an identifier) and the structural one (a discharge row).

This one is GRAMMATICAL: the cue sits in a clause that DENIES an obligation. `No owed is carried
because there is no residual obligation on this entry`, `No owed: nothing is left outstanding`,
`no re-grain is owed`, `GAP CLOSED IN THIS COMMIT rather than deferred`. Every one is an
adjudicator stating correctly that the row owes nothing, and the arm charged them for it.

**It is self-defeating, which is what makes it worth a fix rather than a glance.** The remedy the
report prints is *"re-record each with an `owed` object"*. An adjudicator who instead writes that
no obligation exists trips the cue by writing it, and the register is APPEND-ONLY, so no later act
can clear the row. One row on the reference register records `audit-layer-debt.sh lists this entry
under UNDECLARED on cue 'deferred'` and is itself flagged for that sentence — the tool scoring its
own output as an instance of its own subject.

**Measured on the only register that exists**, 318 rows, driving the shipping script both ways in
one invocation with a `cmp -s` control asserting the two copies differ: **29 flagged before, 19
after**, `OPEN` unchanged at 16 either side. All 10 acquitted rows were read in full — 8 deny an
obligation in as many words, 2 draw an explicit contrast. **The false-acquittal set is 8 unarguable denials and 2 rows taken on the
adjudicator's word** — see `BL-142`, which corrects this and files what it found. The two genuine debts both survive, asserted as a fixture arm rather than assumed.

**THE COMMA HAD TO BE ADDED TO THE CLAUSE BOUND, AND THAT CAME FROM ATTACKING THE FIX AFTER IT
WAS COMMITTED.** The first cut bounded a clause on `.`, `;` and `:` only. A comma does not bound
one, so a negator opening a long comma-spliced sentence reached a cue much later in it — and
adjudicators on this register write comma-spliced reasons as a matter of course. Constructed and
run against the shipping script, one register, two rows: `There is no restatement of core clause
here, but the narrowing this row proposes is still deferred to a later pull.` was SILENCED while
the same obligation without the opening clause was reported. **That is a genuine debt lost to a
`no` governing something else**, and false acquittal is the direction this arm must never fail
in. Adding the comma costs exactly ONE row on the reference register — 18 back to 19 — and that
row is a false positive of the `debt` cue, not an obligation. Mutant M9 keys on it.

**THE FILED REMEDY WAS REFUTED BY BUILDING IT, and that is the reusable half.** The candidate asked
to skip a row whose cue occurrences all sit inside a resolvable `OWED-<id>` token. Built and
scored, it removes **0 of 29**, because a cue occurrence inside such a token is unconstructible:
the arm's own `(?![\w-])` lookahead already refuses it. Control in the same run — `OWED-DEBT` and
`OWED-DEFERRED-X`, ids built entirely out of cue words, yield zero cue matches while `debt
deferred` standing alone yields two. The citation shape the filing describes is real; the
mechanism it named cannot fire.

**THE `nothing` CARVE-OUT WAS JUSTIFIED FROM THE WRONG EVIDENCE, AND AN ADVERSARIAL HAND CAUGHT
IT AFTER THE COMMIT.** Admitting `nothing` acquits **0 of 29** — both rows carrying *"Nothing but
this reason field is tracking that debt"* survive on an `OWED REMEDIATION, deferred` cue five
hundred characters earlier, so that sentence is not what protects them. The exclusion stays
because a row whose ONLY cue is that sentence is constructible and is lost without it; the fixture
seeds that row and M7 kills on it. `never` acquits 0 and is vacuous. `not` acquits exactly one
more, accidentally, on a `not` governing a parenthetical several clauses from the cue.

**The hand's other finding was already closed by the comma bound**, and its probe — a period
swapped for a comma — REPORTS in both forms against what shipped. It had scored the pre-comma
revision. Re-measure a late finding against what shipped before acting on it.

**What is NOT claimed.** Two false-positive classes survive and are stated rather than deferred:
the cue naming a CORE CONSTRUCT (`core's Remediation Rule 12`, `the remediation EDIT`) and the cue
in a clause citing a resolvable `OWED-` id. Both are per-row prose judgements, and the arm's own
header declares a deliberate recall bias — narrowing further trades away the thing the file exists
for. 15 of the surviving 19 are still false; the fix removes noise, it does not make the arm
precise.

**The receipt ACCEPTS a row-grain implementation** — one that silences the whole row when any cue
is denied — because its seed carries a single cue each side. That is a real weakness and it is
covered by the fixture, not by the receipt: `core/fixtures/layer-debt-due-and-discharge` mutant M6
seeds a row that denies one obligation and states another, which no receipt this shape can reach.
Scored: 10 mutants, 10 killed, and the `nothing`-as-negator seed had to be narrowed to its governed
sentence before M7 could fire at all.

verify: sh set -e; d=$(mktemp -d); printf '%s\n' '{"clause":"LC-E4","entry":"x/deny.md","subject_digest":"a","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"Verdict recorded. No owed is carried on this entry."}' '{"clause":"LC-E4","entry":"x/keep.md","subject_digest":"b","verdict":"still-additive","recorded_utc":"2026-01-01T00:00:00Z","reason":"Verdict recorded. New owed is carried on this entry."}' > "$d/r.jsonl"; o="$(bash core/scripts/audit-layer-debt.sh --register "$d/r.jsonl" 2>/dev/null)"; grep -q 'UNDECLARED (1)' <<<"$o" && grep -q 'keep\.md' <<<"$o" && ! grep -q 'deny\.md' <<<"$o"
## BL-144 — the operator-citation parser is greedy, so which quoted segment wins is decided by position

**LANDED (v0.480.0, verified 6a9456cd).**

**Filed and FIXED in this release.** Consumer candidate
`PC-S340-VALIDATE-ESCALATION-RESOLUTION-NONDETERMINISTIC-ON-BYTE-IDENTICAL-INPUT`, filed
2026-08-31 against sprint 307, routing `CO-S307-ESCALATION-VALIDATOR-NONDETERMINISTIC`. **The
filing's stated mechanism is REFUTED and its symptom is real**; both halves are below, because
which one you believe decides what you build.

**THE FILED MECHANISM DOES NOT EXIST.** The candidate reports five consecutive runs over a
`pending.md` whose `shasum` was unchanged producing three different verdicts, and instructs the
adjudicator to read *"whether the parse of a multi-quote citation still depends on unordered
iteration"*. It does not. With the transcript corpus FROZEN — a byte copy of the reference
consumer's 176 `*.jsonl` — ten consecutive runs of the shipping script over one constructed
`pending.md` returned an identical verdict ten times out of ten. What moves is the SECOND input:
the live corpus's listing digest moved four times across ten runs while the peer session writing
it was merely idle. **`pending.md` was byte-identical and the corpus was not, and nothing in the
output said which corpus state a verdict came from.**

**THE DETERMINISTIC DEFECT IS THE PARSE, AND POSITION DECIDES IT.** The cited substring was
captured with `sed -n 's/.*"\(.*\)".*/\1/p'`, whose leading `.*` is GREEDY, so the LAST quoted
segment wins. Measured with the shipping script against one frozen corpus, the same two quotes
with only their ORDER swapped:

    "<genuine operator words>" / "<invented>"   ->  exit 1, "This is the S290 failure"
    "<invented>" / "<genuine operator words>"   ->  exit 0, OK

The first is a false accusation of fabrication against a real citation. **The second is
fail-OPEN: an invented operator disposition notarizes whenever any genuine operator substring
trails it on the same line, which is the exact fabrication the script exists to stop.** The
single-quote controls do not move in either direction — `"<genuine>"` alone passes and
`"<invented>"` alone fails under both builds — so the reading discriminates rather than firing
on every citation.

**ON AN ODD QUOTE COUNT THE CAPTURE IS THE CONNECTIVE BETWEEN TWO QUOTES.** The reference
consumer's own committed citation `** 2026-07-20T13:08:33Z | "1. RETIRE" and "This work was
already done in` captured ` and ` — five characters — and failed as *"too short"* while naming
none of the operator's words.

**AND THE FIELD IS ROUTINELY MULTI-LINE.** The producing `awk` is line-oriented, so a citation
whose closing quote sits on the next line reached the fallback, which kept the opening `"`
inside the needle. No operator message contains that character there.

**THE POPULATION, DERIVED FROM THE CONSUMER'S OWN HISTORY, AND STATED BY NARROWING.** Over the
**713 distinct blobs** of `docs/escalations/pending.md` and `pending-archive.md` — 834 commits
touch the first and 45 the second, and summing those two counts double-counts, which is the
error an earlier revision of this entry made when it called 878 a blob count — **106 citations
are what the READER parses**: the FIRST authorization line of each RESOLVED/OVERRIDDEN entry,
which is all the extractor emits. 98 of the 106 carry exactly two quote characters and are
unaffected; the other 8 are the subject — 6 multi-line, 1 with no quote at all, 1 the
connective case above.

**Every auth line on a terminal entry is 110; every auth line ANYWHERE in those two files is
129, of which 15 are not the clean two-quote shape.** A second hand measured 129 independently
and was right about a different question; the three narrowings were then computed in one
invocation over one blob set, so only the narrowing varies. The reader's population is the one
a differential over the reader must use, and the other two are the exposure ceiling.

**SCORED AS A DIFFERENTIAL, PER ROW, NOT AS A TOTAL.** All 106 replayed as one entry each, in
scope, against one frozen corpus, under the pre-fix and post-fix builds with a `cmp -s` control
asserting the two differ: **33 FAIL before, 31 after; the two that moved are both the
multi-line shape; and NO row moved from pass to fail.** The false-positive set is that
measurement and not an adjudication. What the differential does NOT establish: 31 rows still
fail, and an unknown share of those fail because the July transcripts they cite are no longer in
today's corpus — the differential is immune to that, the absolute count is not.

**THE FIX IS ONE PREDICATE IN THREE FILES.** `cite_segments()` reads the field as SEGMENTS —
`split` on `"` puts the inside-quote fields at the even indices, and an odd count leaves the
final field unterminated at an even index too, so one loop covers both shapes — and
`cite_quote()` takes the first segment long enough to verify. Three programs parse this field
and all three feed the result to the same `--cite` predicate:
`core/scripts/validate-escalation-resolution.sh`,
`core/scripts/validate-adversarial-convergence.sh`, and
`core/hooks/ai-dlc-gate-remediation-guard.sh` — where the permissive direction LIFTS a gate
deny. **I103** holds the three copies byte-identical and refuses a fourth, mirroring I92 over
the same three sites; it was proved able to fire in both directions before shipping (a seeded
one-character drift, and a seeded fourth file), against an unmutated control that is silent.

**WHAT IS NOT CLAIMED.** A second quoted segment beside a verified one is not itself notarized.
The field has always carried free prose after the quote, so that residue is the grammar's rather
than this parser's. **A conjunction over every segment was built and scored**: it produces a
byte-identical fail set over the 106 real citations, and on the constructed case it still
refuses a genuine citation followed by other text — so it leaves half the filed defect unfixed
and is not a second spelling of this one. Stated as a limit, not as deferred work.

**THE POPULATION EXCLUDED THE OTHER TWO READERS' OWN CORPORA, AND THAT IS WHERE THE DEFECT IS
LIVE TODAY.** Found by an independent hand, then re-derived here.
`validate-adversarial-convergence.sh` parses this same field out of `*-resolution-p<N>.md`, and
on the reference consumer that corpus holds 28 citations, 4 of them not two-quote. Scored with
the shipped `cite_quote()` sourced from the shipping file against the pre-fix capture, both
against the real transcript corpus: **the needle moves on 3 of the 4, all 24 clean citations
are unmoved, and one CITATION goes NOMATCH to MATCH.** That one is a genuine
`"Route A (Recommended)"` operator answer whose LAST quoted segment is the file quoting its
own closure line (`"Status: DECIDED_AUTONOMOUSLY-by-operator (...)"`), so the greedy capture
asked the transcript for a sentence the file wrote about itself.

**AND THAT IS A CLAIM ABOUT THE CITATION DECISION, NOT ABOUT THE SHIPPING VERDICT. AN EARLIER
REVISION OF THIS ENTRY CALLED IT A LIVE FALSE ACCUSATION AND THAT IS WITHDRAWN.** Driving the
validator on that record rather than its predicate: both builds exit 1 with byte-identical
output, against a `cmp -s` control asserting the builds differ, because **arm A fails first**
— the provenance block declares no `verdict:` — so F6's citation arm is never reached. The
false accusation is LATENT there. Isolating a predicate and reading a movement its own
control flow never reaches is the mirror of this repo's rule that isolating the subject hides
a defect in its CALLER. A peer hand reached the same conclusion independently and named the
sibling record; the two of us were scoring different files and different objects.

**So both corpora return a null on observable behaviour today, for two different reasons** —
`pending.md` because the defect's shape is absent from that consumer's in-scope entries, and
the convergence corpus because the one record carrying the shape is refused upstream of the
citation arm. The case for delivering this rests on the fail-open half, which is silent by
construction and has no warning shot.

**AND THE CORPUS-ATTRIBUTION HALF IS ADDRESSED WITHOUT BEING CLOSED.** The sibling already
prints `cite: scanned <N> transcript(s) from <corpus>`; the escalation validator discarded it.
It is now rendered into the accusation verbatim rather than restated, so two runs that disagree
are visibly two runs over two corpora. That does not make a live corpus stable and does not
claim to.

verify: sh d=$(mktemp -d); printf '{"type":"user","timestamp":"2026-01-01T00:00:00Z","message":{"content":"Reframe the AC as a class invariant, not a per-site fix."}}\n' > "$d/t.jsonl"; e(){ printf '## S50-%s Lead - 2026-01-01\n**Status:** RESOLVED\n**Operator authorization:** %s\n' "$1" "$2" > "$d/$1.md"; }; e a '2026-01-01T00:00:00Z | "zzz invented disposition zzz" / "reframe the AC as a class invariant"'; e b '2026-01-01T00:00:00Z | "reframe the AC as a class invariant"'; e c '2026-01-01T00:00:00Z | "reframe the AC as a class invariant" / "zzz invented disposition zzz"'; e f '2026-01-01T00:00:00Z, verbatim: "reframe the AC as a class invariant'; v(){ bash core/scripts/validate-escalation-resolution.sh --escalations "$d/$1.md" --sprint 50 --transcript "$d/t.jsonl" >/dev/null 2>&1; echo $?; }; r="$(v a)$(v b)$(v c)$(v f)"; rm -rf "$d"; [ "$r" = "1000" ]
## BL-146 — the snapshot sprint reader spelled the decoration, and the fixture seeded the form it accepted

**LANDED (v0.481.0, verified 6cbad859).**

Discharges `PC-S308-DISPATCH-GUARD-SPRINT-FIELD-INTERMITTENTLY-NULL`, filed by the reference
consumer 2026-09-02 against sprint 308, and `PC-S305-DISPATCH-GUARD-SED-PATTERN-BOLD-MISMATCH`,
the same defect at the same line filed against sprint 305 and recorded RECURRED at sprint 306
where it blocked a live incident fix. Both are cited here so the pair leaves the UNFILED bucket
together; the S305 half was taken on an explicit operator ruling, its recurrence note having been
held for a ruling since batch 20.

Three hooks — `core/hooks/ai-dlc-dispatch-guard.sh`, `ai-dlc-subagent-probe.sh`,
`ai-dlc-context-sensor.sh` — read the sprint out of `_bmad-output/pipeline-snapshot.md` with an
expression requiring the field name wrapped in emphasis markers. The snapshot's writer emits the
plain bullet whenever nothing re-emphasises it, so the read resolved EMPTY and the spawn ledger
recorded `"sprint":null`. Every arm on that read is `2>/dev/null || true`, so nothing said so.

Measured over 2066 real snapshot revisions: **195 recovered, 0 lost, 0 differing values**, with
the residue partitioned (311 non-numeric, 668 fieldless, 0 excluded by the bullet anchor) summing
exactly to the both-empty count.

**The instrument that should have caught it was seeded from the reader's own accept-set.** All
three fixtures wrote the emphasised form, so the battery proved the hook accepts its own grammar
and stayed green for the whole life of the defect. That is the `fixture-mutants.md` rule *"never
seed from what the reader accepts"*, and it is now asserted rather than assumed.

`I104` binds the three copies in both directions. `BL-145` was filed from the same scoping pass
and is NOT closed by this entry.

**The unfiled sibling named here deliberately**: `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR`
is the same class — a bold-markdown grammar against a plain artifact — in a different program
(`validate-scope-confirmation`). It is NOT closed by this change and stays live and unfiled; it is
named so the next sibling join can find it by subsystem rather than by sprint prefix.

verify: sh set -e; r="$PWD"; e='s/^- *[*]*sprint_id:[*]* *\([0-9][0-9]*\).*/\1/p'; n=0; for f in core/hooks/ai-dlc-dispatch-guard.sh core/hooks/ai-dlc-subagent-probe.sh core/hooks/ai-dlc-context-sensor.sh; do [ -r "$r/$f" ] || exit 9; grep -qF -- "$e" "$r/$f" && n=$((n+1)); done; [ "$n" -eq 3 ] || exit 1; s=$(mktemp); printf -- '- sprint_id: 308\n' > "$s"; [ "$(sed -n "$e" "$s")" = "308" ] || exit 1; printf -- '- **sprint_id:** 307\n' > "$s"; [ "$(sed -n "$e" "$s")" = "307" ] || exit 1; printf -- '- sprint_id: TBD\n' > "$s"; [ -z "$(sed -n "$e" "$s")" ] || exit 1; exit 0
## BL-147 — core instructs a status token that core's own gate refuses, and the only passing disposition is the one core forbids

**LANDED (v0.483.0, verified ac2e94eb).**

**Filed by the reference consumer as
`PC-S308-HANDOFF-STOPPED-STATUS-NOT-IN-VALIDATOR-WHITELIST`**, 2026-09-02, and FIXED in this
release. PC-backed, so it ranks above every distribution-internal entry under the
provenance-first rule.

`steps/handoff.md` step 1 tells the lead to set each stopped teammate's **In-Flight Teammates**
row `status` to `stopped` and to *"Rewrite the row; do not delete it"*. `core/hooks/ai-dlc-continue.sh:390`
— the hook that BLOCKS the handoff while a row still reads `in-flight` — emits remedy text saying
the same thing verbatim. `validate-artifact-budget.sh`'s `check_inflight_status()` whitelisted
exactly two leading tokens, `in-flight` and `delivered-reachable`, and FAILED on anything else;
its own remedy text said the opposite of both — *"A teammate that will not be messaged again has
no token: DELETE its row."* Obeying the instruction failed the gate that Rule 25(d) mandates after
every snapshot edit.

**THE BOX WAS CLOSED ON ALL FOUR SIDES, MEASURED ON THE SHIPPING VALIDATOR** with one row varied
against two near-miss rows held constant beside it in the same run:

    stopped (operator-requested handoff)   exit 1   check_inflight_status
    ~~stopped~~                            exit 1   check_inflight_rows
    in-flight                              exit 0   but ai-dlc-continue.sh Check 0 blocks the handoff
    delivered-reachable                    exit 0   and is false: it never delivered

So of the four dispositions available to a lead, three were refused and the only passing one was
DELETION — which `handoff.md` and the continue hook both instruct against, for the stated reason
that a deleted row is indistinguishable from a teammate that never existed.

**THE RECORD LOSS IS NOT HYPOTHETICAL AND THE CONSUMER WROTE IT DOWN.** Its live snapshot's
In-Flight section reads, in prose where a row should be: *"(none -- `adversary-s308-product-brief-p3`'s
row was deleted, not struck or rewritten to `stopped`, on stop: both alternatives are rejected by
`validate-artifact-budget.sh` per `PC-S308-HANDOFF-STOPPED-STATUS-NOT-IN-VALIDATOR-WHITELIST`.)"
The filing records the same conflict resolved the same way earlier in the same sprint.

**`stopped` IS A THIRD STATE, NOT A SPELLING OF THE OTHER TWO.** Neither original token is true of
a stopped teammate: it has not delivered, and it cannot be messaged. The set was closed at two on
the reasoning that a row which will not be reached again is DELETED — and a handoff is the case
that reasoning does not cover, because there the row must survive for the successor.

**CORE ALREADY DISAGREED WITH ITSELF TWO HOMES TO TWO, which is the same shape
`core/fixtures/inflight-row-shape/run.sh` was built for.** `handoff.md` and `route.md:611-617`
already named `stopped` and already carried the handoff exception; `gate-validation.md:840` and
the validator declared the closed set of two. Nothing bound the four, so the contradiction was
invisible to every gate. The fix adds the token at the validator and at both declaring sites.

**Stated limitation.** No invariant binds the token set across its declaring files, so a fifth
site can still disagree silently. That is filed separately rather than built here.

**The receipt DRIVES the validator rather than reading it**, and is presence-shaped on both
halves so a subject that emits nothing cannot satisfy it: an unrecognised token beside a `stopped`
row must still be NAMED, and the `stopped` row must NOT be. Scored six ways against this corpus's
convention, where exit 0 is the fix being present — the shipped fix exits 0, a second spelling
(one regex alternation instead of a third equality line) exits 0, and the pre-fix validator, a
whitelist widened to accept everything, an untouched validator, and a docs-only change all exit 1.

verify: sh d=$(mktemp -d); mkdir -p "$d/_bmad-output"; printf '# S\n\n## In-Flight Teammates\n| a | r | d | t | status |\n|---|---|---|---|---|\n| alpha-stop | x | d.md | t | stopped (handoff) |\n| beta-unk | x | d.md | t | idle-reusable |\n' > "$d/_bmad-output/pipeline-snapshot.md"; AI_DLC_PROJECT_ROOT="$d" bash "$PWD/core/scripts/validate-artifact-budget.sh" --only pipeline-snapshot.md >"$d/o" 2>&1; grep -q beta-unk "$d/o" && ! grep -q alpha-stop "$d/o"
## BL-149 — the handoff guard compared the whole status cell where its sibling compares the leading token, so it fired only on the bare form

**LANDED (v0.483.0, verified 0645904b).**

**Found while fixing `BL-147`**, 2026-09-02, by deriving every core reader of the In-Flight
status column rather than trusting the one the filing named. FIXED in this release.
Distribution-internal, no `PC-` id — it is here because it is the same column, the same release
and the sibling reader of the code `BL-147` changed.

`core/hooks/ai-dlc-continue.sh` Check 0 is the guard that BLOCKS a handoff while a teammate is
still running. It read the status cell with `if (tolower(last) == "in-flight") found = 1` — an
equality against the WHOLE cell. `check_inflight_status()` in `validate-artifact-budget.sh` has
always split the leading token off instead, and its own comment says why: the reference
consumer's live snapshot carries `in-flight, since 2026-07-27T21:12:41Z`, `in-flight, retrying
Write` and `in-flight (VERIFY pass, resolves_divergence: ...)`, and *"an equality check would
have failed every one of them on the day it shipped."*

**MEASURED by driving the arm on the four real forms**, one cell varied:

    in-flight                                        BLOCKS   correct
    in-flight, since 2026-07-27T21:12:41Z            ALLOWS   teammate is running
    in-flight, retrying Write                        ALLOWS   teammate is running
    in-flight (VERIFY pass, resolves_divergence: x)  ALLOWS   teammate is running

**One of four blocked.** The guard fired only on the bare token, and the three forms it let
through are the three the consumer actually writes. The failure is silent and in the open
direction: the handoff proceeds, and the successor inherits a snapshot whose rows name teammates
nobody stopped — the one piece of state `handoff-resume-guard`'s own header says no later step
can reconstruct.

**THE FIXTURE COULD NOT HAVE CAUGHT IT, AND THE REASON IS THE STANDING RULE.**
`core/fixtures/handoff-resume-guard/seed.sh` seeded `| ... | in-flight |` — the bare token, the
form the reader already accepted. That is `fixture-mutants.md`'s *"never seed from what the
reader accepts"*, and the battery proved the guard accepts its own grammar for the defect's whole
life. Seed (b2) now carries the trailing-note form; scored against the pre-fix hook, exactly one
arm fails and it is that one.

**IT COULD NOT SAFELY HAVE BEEN FIXED BEFORE `BL-147`, WHICH IS WHY BOTH ARE IN ONE RELEASE.**
Making this guard fire correctly means a handoff is BLOCKED while any row reads `in-flight`. The
only compliant way to clear such a row is to rewrite it to `stopped` — and until `BL-147` landed,
`validate-artifact-budget.sh` rejected that token, so the lead had no passing move. Fixed alone,
this change converts a guard that fails open into a handoff that WEDGES.

**A NOTE ON HOW THE FIRST CUT BROKE.** The explanatory comment was written with an apostrophe in
it, inside a single-quoted `awk` program, which closed the string and broke the entire hook —
every arm of the fixture went red at once, which reads like a much larger regression than it was.
The comment now carries its own prohibition. `bash -n` on the hook is the one-command control.

**Stated limitation of the receipt below.** It runs the shipping fixture and keys on the arm's
own `ok` line rather than on the hook's source, so it drives the real program — but a rename of
that assertion's text scores STILL-LIVE. Keyed on the behavioural phrase, not on a token nothing
binds; if the arm is reworded, re-anchor rather than reading the non-close.

verify: sh o=$(bash core/fixtures/handoff-resume-guard/run.sh 2>&1); grep -qE '^  ok .*trailing note' <<<"$o"
## BL-150 — legalising `stopped` made three status-blind readers reachable, and they re-arm and re-dispatch a teammate the operator stopped

**LANDED (v0.484.0, verified fd08c6aa).**

**Found by an adversarial hand reporting AFTER `v0.483.0` merged**, 2026-09-02, and FIXED in
`v0.484.0`. Distribution-internal, no `PC-` id. It is here because `v0.483.0` is what made it
reachable.

`v0.483.0` legalised `stopped` in the In-Flight `status` column. Three core sites iterate EVERY
row of that section with **no status filter at all** and route an absent deliverable to re-arm
and eventually re-dispatch:

    core/skills/ai-dlc/SKILL.md:53-56          "Older = ... resume the beat, as for absent"
    core/skills/ai-dlc/steps/route.md:72-76    "Older or absent means the beat resumes"
    core/hooks/ai-dlc-recover.sh:297-313       "Deliverable absent -> ... ARM A FRESH beat"

**A `stopped` row has an absent deliverable BY THE DEFINITION `v0.483.0` ITSELF WROTE** —
"stopped before delivering". So all three classify it as an undelivered teammate, arm a wait-beat
over it, and `ai-dlc-recover.sh` — a `SessionStart` hook on the `compact` matcher — carries that
to re-dispatch once `max_wait_beats` is exhausted. `recover.sh:315` calls re-dispatching a live
or delivered teammate "a lead-conduct retro finding".

**THE DEFECT WAS UNREACHABLE BEFORE THE FIX, AND THE FIX IS WHAT REACHED IT.** Until `v0.483.0`,
deletion was the only disposition that passed both gates, so no `stopped` row survived to be
read by any of the three. **This is the "what does your change make reachable" question, and the
lead's own reader sweep missed it** — that sweep was keyed on `--include="*.sh"` parsers and
dispositioned `recover.sh` as "prose, no token branch", which was true and was the wrong
question. Status-BLIND is worse than branching wrongly: there is no token to find.

**AND `route.md` CONTRADICTED ITSELF 538 LINES APART, WITH `v0.483.0` MAKING THE WRONG HALF
PERMANENTLY FALSE.** `route.md:75` told the resume path *"(A resume that followed `handoff.md`
Step 1 finds the table empty)"*, while `route.md:611-617` had carried the handoff exception —
rows are KEPT — since `v0.408.0`. The premise is now never true, so its consequent is always
reached: the mirror of a check that cannot fire.

**`stopped` ALSO HAD NO REAPER, WHICH THIS ENTRY FIXES.** `_gate-procedures.md` said "do not
delete a `stopped` row" and nothing anywhere deleted one. Measured: every hit for `stopped`
co-occurring with delete/remove/clear/prune across `core/skills`, `core/hooks` and `core/scripts`
is a PROHIBITION on deleting it; control, `DELETE` instructions for the other two tokens exist,
1 in each declaring file. The section would have grown monotonically for the snapshot's life,
bounded only by the byte budget whose 446% overrun IN THIS SAME SECTION is why
`core/fixtures/inflight-row-shape/` exists. The discharge is now named: the successor deletes
`stopped` rows at its first snapshot write after the resume, once it has read them.

**Stated limitation of the receipt below.** Its subject is PROSE read by a model, so there is no
program to drive and the receipt asserts the skip clause is present at all three sites. A
rewording that preserves the instruction scores STILL-LIVE, and a clause present but ignored by
the model scores CLOSE. That is the weaker form and it is chosen because the subject is an
instruction, not a mechanism; it carries a control so a broken grammar exits 9 rather than
reporting a false close.

verify: sh n=0; for f in core/skills/ai-dlc/SKILL.md core/skills/ai-dlc/steps/route.md core/hooks/ai-dlc-recover.sh; do [ -f "$f" ] || exit 9; grep -q 'In-Flight Teammates' "$f" || exit 9; grep -qiE 'stopped' "$f" && grep -qiE 'skip|never re-arm|SKIP THE ROW' "$f" && n=$((n+1)); done; [ "$n" -eq 3 ]
## BL-151 — the `driver-self-update` row prescribed a re-run that the same range's union gate refuses, and the refusal named two causes that were both false

**LANDED (v0.494.0, verified 04a136e0).** Shipped as `v0.493.0` (PR #604, `cb4fff3d`) and corrected by `v0.494.0` (PR #605); receipt exit 0 on `main` at that sha.

**Provenance: `PC-S309-APPLY-SH-DRIVER-SELF-UPDATE-ROW-PRESCRIBES-A-RERUN-ITS-OWN-UNION-GATE-REFUSES`**,
filed by the reference consumer 2026-09-03 on its `0.482.0 -> 0.489.0` pull, by obeying the row.
Consumer-facing and PC-backed. Fixed in `v0.493.0`; this entry is the distribution-side record and
the receipt.

When a range updates `apply.sh` itself, phase 1 replaces the driver by inode swap and emits
`RESOLVED driver-self-update`, which read "Re-run it to see the new one's reading of the same range
— it is idempotent." The same range (`v0.488.0`) installed the union gate at the top of `apply.sh`,
which requires `emit-report.sh --verify` to exit 0 against the approved report at THIS run's
theirs. Post-apply that cannot pass: the apply moved the tree, so the detectors render every applied
path as `ALREADY-AT-THEIRS` and the region no longer byte-matches the report the operator approved.
Obeying the row: rc=1, nothing written, and a refusal whose two stated causes — upstream moved,
region hand-edited — were both false. Two claims, one row apart, both reproduced by driving the
consumer's own copy of the shipping driver in a synthetic pull (self-replacing, report rendered at
theirs pre-apply, stamp advanced): the row prescribed an action the same release makes unexecutable
in the state the row is printed in, and the gate's disjunction omitted the common cause.

**The fix DECIDES the third cause rather than listing it.** The gate's failure branch reads the
stamp's `commit:` and the in-flight marker's `theirs:`, resolves each to a `core/` tree in the
distribution — the tree-keyed comparison the `--finish` identity guard already uses, so a docs-only
commit between releases does not defeat it — and if either equals theirs' tree the refusal says so,
prints the record it matched, and names the procedure that works: re-render the report with
`emit-report.sh <dist> <base> <consumer> <theirs>` from the tree as it now stands, re-approve, and
re-run apply with the same four arguments. Neither record present or resolvable falls through to
the two-cause message, never to a pass. The row no longer prescribes the re-run; it says one will
be refused and that the refusal names the procedure. Both branches still refuse with rc=1 and write
nothing.

**CORRECTED BY `v0.494.0`, on the adversarial hand's post-merge report.** The v0.493.0 diagnosis
also read the in-flight marker's `theirs:`, which `apply.sh` writes from its own argument before
any write, so that arm held by construction: a marker over a tree still at base fired the
post-apply message, and the `--finish` it offered stamped 2.0.0 over a 1.0.0 tree. The four
scenarios below were right; the fifth — marker present, tree unwritten — was not built, and it
is the one that failed. The diagnosis now reads the stamp alone, asserts only what the stamp
asserts, and prescribes nothing that writes. `apply-self-overwrite` assertion 8 holds the fifth
state and M8 restores the marker arm.

**The carve-out was built and REJECTED, and not for the reason the plan predicted.** Letting a
post-apply re-run through when the stamp is at theirs — the shape of the existing `--finish`
exemption — fixes the filed case and re-opens the non-termination `apply.sh`'s own resolution-phase
comment forbids: on a consumer that `--finish`ed a withheld run by hand, the re-run finds the
semantically merged file BOTH-CHANGED again, emits the WORKLIST, withholds the stamp and writes the
marker, so the run the row called idempotent wedges the consumer a second time. Measured on three
candidates across four scenarios (post-apply re-run, stale upstream, re-run after `--finish`,
re-run while withheld): the shipped copy misdiagnoses in every post-apply state, the carve-out
re-wedges after `--finish`, the discriminating refusal is right in all four. The plan's stated
reason for expecting rejection — that the tree being at theirs is not knowable before
classification — was false; the stamp and the marker are readable before phase 1. The acquittal is
the reason.

**Reader set, derived rather than taken from the filing.** The row's only reader is
`core/fixtures/apply-self-overwrite/run.sh`, which greps the row NAME tab-delimited; the gate
message's only reader is `apply-restamp-worklist`'s `m12`, re-anchored so it disarms both refusal
sites. `SKILL.md` never restates the row. Mechanism: `apply-self-overwrite` assertions 5–8 — the row
text, the post-apply refusal naming the record it matched, a stale-upstream report still getting
the two-cause message, and the prescribed procedure completing — with mutants M4–M7, M7 being the
rejected carve-out, each scored on the arm it must move and the neighbour it must not. Green in
both layouts, on a tree built by `install.sh` into an empty directory.

**Receipt limits, stated.** It keys on (a) the refusal line naming `driver-self-update`, the bound
row-name token the diagnosis cross-references, and (b) the row's own two lines lacking the literal
`it is idempotent`, the phrase the consumer's `theirs_has` receipt anchors on, so the two flip
together. A refusal reworded without the cross-reference scores STILL-LIVE though fixed; a row that
keeps the claim in other words scores fixed here and STILL-LIVE upstream. Scored before landing:
HEAD 1, tree 0, a second spelling of the row 0, claim restored 1, cross-reference dropped 1, row
deleted 9, subject missing 9.

verify: sh a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$a" ] || exit 9; s=$(grep -c 'say RESOLVED driver-self-update' "$a"); [ "$s" -eq 1 ] || exit 9; r=$(grep -cE '^[[:space:]]*err "the report at .*driver-self-update' "$a"); i=$(awk '/say RESOLVED driver-self-update/{p=2} p>0{print; p--}' "$a" | grep -c 'it is idempotent'); [ "$r" -ge 1 ] && [ "$i" -eq 0 ] && exit 0; exit 1
## BL-131 — the mechanical union gate is prose, so nothing makes `apply` verify the approved report

**LANDED (v0.488.0, verified 2f7a260b).** NARROWED on an operator ruling at batch 46: this entry
closes against what `v0.488.0` delivered — `apply.sh` drives the union gate itself, so paths 2
and 3 below are gated by a program and the receipt has read exit 0 since. Path 1, step 2's
autonomous self-update, is NOT closed by that release and is filed on its own as `BL-155`, so
that a green receipt no longer stands over an open half. Everything below this line is the
entry as it was when the scope decision was still open.

**Premise moved at `v0.488.0`; re-derived 2026-09-03 while shipping `BL-151`, and NOT closed.**
`apply.sh` now drives the gate itself, so paths 2 and 3 below are closed and the receipt reads
exit 0 — which is exactly the partial-fix state this entry says not to close on. Path 1, step 2's
autonomous self-update, is untouched. Taking the rest means closing step 2 or narrowing this
entry and filing step 2 separately; that is a scope decision and was not made here.

`SKILL.md` step 7 states that `apply` "may write only after BOTH hold", the first being that
`reconcile/emit-report.sh --verify <report> <dist> <base> <consumer> <theirs>` exits 0, "a nonzero
exit means the approval was given without sight of a finding, so STOP and re-emit rather than
write". That is the only thing standing between a stale or hand-edited approval and a write into a
consumer's core.

**Nothing executes it.** Measured across the tracked tree: **zero** invocation sites for
`emit-report.sh` outside its own file and the fixtures, against **76** for `preclassify.sh` under
the identical grammar in the same invocation. `apply.sh` names `emit-report` exactly once, in a
comment. So the gate runs if and only if the narrating agent chooses to run it, and a run that
skips it is indistinguishable from one that ran it and passed — there is no artifact either way.

**THREE PATHS REACH CONSUMER STATE WITHOUT THE GATE, AND THE FIRST IS THE ONE A READER WILL NOT
EXPECT.** They are ranked by what they write, and only the second is the one this entry was first
written about:

1. **Step 2's self-update.** `SKILL.md:396-409` cuts a branch, writes from `theirs` at the
   `map_consumer()` destinations, advances `skill_version`/`skill_commit`, pushes and auto-merges
   — in its own words, **"no operator gate"**. No report is produced at all, so there is no region
   to verify and nothing for a rendered-identity fix to reach. `SKILL.md:160-161` records that this
   runs on EVERY invocation, "step 2's autonomous push→auto-merge writes to `origin` even on a bare
   dry-run". This is distribution `core/` content landing on a consumer with no approval artifact
   anywhere in the path.
2. **Step 7's apply.** `apply.sh` never invokes the gate; the prose sits beside it.
3. **`apply.sh --finish`.** Writes no core but writes the stamp, which is the next pull's merge
   base. `v0.464.0` closed the identity half of this one by reading `.claude/.ai-dlc-applying`;
   it did not make the gate run.

**So a check sited inside `apply.sh` — the obvious repair — closes 2 and 3 and leaves 1 open**,
which is why the siting has to be decided against all three rather than against the one that
prompted the entry.

**This is the `CLAUDE.md` case in its purest form**: a prohibition whose enforcement is an
instruction to a reader. `emit-report.sh:8-13` states the principle in its own header — the region
exists because "an LLM stands between the detector and the operator and can drop the line" — and
the gate guarding that region is itself a line an LLM can drop. The two fixes shipped in `v0.464.0` both sharpen what the gate DETECTS —
the region now carries the `theirs` `core/` tree, so a moved symbolic ref cannot render identically
— and neither of them causes the gate to be RUN. They are strictly downstream of this entry.

**The fix is not simply "call it from `apply.sh`", which is why this is filed rather than taken.**
`apply.sh` receives four paths and no report path; it does not know which report the operator
approved, and inventing a convention for that is a change to the write path with real wedge risk
for a consumer whose report sits under a name the convention does not predict. The candidate shapes
— `apply.sh` taking the report as a required argument, or the ordinary run recording the verified
report's digest into `.claude/.ai-dlc-applying` beside the `theirs:` it already records — differ in
what they do to a consumer mid-pull, and that has to be measured on a scratch install before
either is built.

Discovered while shipping `v0.464.0`. Not filed by the reference consumer and carries no `PC-` id;
it is an ai-dlc-internal discovery and ranks below any PC-backed entry under the provenance-first
rule.

**Tiered DEFECT.** Nothing is corrupted today. What is missing is the guarantee that the gate ran
at all, and the symptom of a gate that did not run is a clean report.

The receipt is STRUCTURAL and carries its own control, because a zero here is the claim being made:
it counts non-comment invocation lines of `emit-report.sh` in tracked `.sh` files outside
`core/fixtures/`, having first asserted that the same grammar finds callers of `preclassify.sh` —
a grammar that finds neither has failed rather than found an absence. It exits 1 today, 0 once any
executable invokes the gate, and 9 if the subject is missing or the control does not fire. Scored
both directions: 1 against the tree, and 0 against a scratch copy with one real call site seeded.

**The receipt is a FLOOR and will go green on a partial fix — that is stated rather than hidden,
because it is the shape this repo closes entries on by mistake.** Any executable call site
satisfies it, so wiring the gate into `apply.sh` flips it to 0 while path 1 above, step 2's
autonomous self-update, is untouched and still writes core with no report in existence. Do not
close this entry on the receipt alone: say what was done about step 2, or narrow the entry to
paths 2 and 3 and file step 2 separately.

verify: sh e=core/skills/ai-dlc-update/reconcile/emit-report.sh; [ -f "$e" ] || exit 9; L=$(git ls-files "*.sh" | grep -vE "^core/fixtures/"); c=$(printf "%s\n" "$L" | grep -v "reconcile/preclassify.sh" | xargs grep -hE "(bash|sh) [^ ]*preclassify\.sh" 2>/dev/null | grep -vcE "^[[:space:]]*#"); [ "${c:-0}" -gt 0 ] || exit 9; n=$(printf "%s\n" "$L" | grep -v "reconcile/emit-report.sh" | xargs grep -hE "(bash|sh) [^ ]*emit-report\.sh" 2>/dev/null | grep -vcE "^[[:space:]]*#"); [ "${n:-0}" -gt 0 ] && exit 0; exit 1

## BL-154 — a rotation flips a sibling's row between `NAMED-UPSTREAM` and `NAMED-UPSTREAM-AMBIGUOUS` when a two-member prefix has one member annotated, and step 8 reads that as a sweep

**LANDED (v0.495.0, verified c7ea323f).** `prefix_entry_count()` now counts the ledger corpus —
every entry line in both files, open or closed — so annotating moves nothing between the files
and rotating moves one entry between them, and the count is invariant under both steps by
construction. Receipt drives the shipping reverify and rotator over a two-member prefix and
exits 0 on the fix, 1 on the reverted counter, 9 on a counter stubbed to a constant of 1 or of
2 — the second stub is the reason the receipt also carries a one-member prefix that must stay
uniquely attributed.

Filed by the reference consumer as
`PC-S337-ROTATE-ACCEPTANCE-TEST-FALSE-FAILS-WHEN-A-PREFIX-CROSSES-THE-ONE-VS-MANY-THRESHOLD`
(2026-08-26), from its own ledger: `NAMED-UPSTREAM PC-S336-STEP-1-AUTOPUSH-…` before a
`ledger-rotate.sh --apply` and `NAMED-UPSTREAM-AMBIGUOUS PC-S336` after it, 89 rows either side,
the entry present once in the live file and never in the archive. Consumer-facing: the
acceptance test in `SKILL.md` step 8 named that exact comparison and said a changed row set
means a live entry was swept. DEFECT.

**Mechanism, driven rather than read.** `prefix_entry_count()` counted OPEN live labels unioned
with ARCHIVED labels. `flush()` in the verdict extraction prints an entry only
`if (has_verify && !closed …)`, so an entry carrying `ADOPTED UPSTREAM` is dropped from the live
side at the moment it is annotated, and it is not on the archive side until `--apply` moves it.
On neither side, the count dips; on a three-member prefix that is a changed number inside an
identical row (`BL-068`'s shape), and on a two-member prefix it is a count of ONE — the value at
which `named_absorbed()`'s prefix fallback fires instead of `named_ambiguous()`. Reproduced by
driving the shipping scripts on a scratch consumer through three states: both members live
(`NAMED-UPSTREAM-AMBIGUOUS PC-S900`), one annotated (`NAMED-UPSTREAM PC-S900-BRAVO-…`), rotated
(`NAMED-UPSTREAM-AMBIGUOUS PC-S900`). Two rows either side, the survivor emitting a verdict in
every state, the moved entry in the archive and nowhere else. A second hand reproduced it
independently and added the discriminating control: on the post-rotate tree, moving the archive
file aside reverts the flip and moving it back restores it.

**`BL-068` rejected this counter change at `v0.377.0` and its measurement was not wrong — it was
taken at rest.** It widened the live side on the reference consumer's ledger as it stood and
counted zero verdict flips; a ledger at rest holds no annotated-but-unrotated entry, so the
transient this defect lives in was not in that population. The consumer's diff was taken ACROSS a
live rotation, which is the only moment the state exists. Re-measured on a copy of the consumer's
ledger at rest with the fix: 116 rows either side, 0 row-set changes, 3 displayed counts moved
(`PC-S297` 18→19, `PC-S303` 11→12, `PC-S308` 7→9 — the annotated-but-unrotated entries now
counted), 7 `NAMED-UPSTREAM-AMBIGUOUS` rows either side. The retained-copy double count that
entry also named is closed by skipping `(original text, retained for the record)` headings in
the corpus parser: a copy is a second heading for an entry already counted.

**The fixture arms that guarded the old behaviour asserted the defect.** `ledger-rotate/run.sh`
required the bytes to DIFFER and the `PC-S900` count to rise `2 -> 3` across the move — true of
the counter as it was, and the same mechanism that one member fewer flips a row. Both are
re-anchored on the stable count (`3 -> 3`, bytes identical), and assertion 4c walks a two-member
`PC-S910` pair through annotate and rotate with a mutant that reverts the counter to its
open-union-archive body and shows the flip. The archive-arm mutant `BL-068` added survives
unchanged: deleting the archive arm still turns a correct ambiguity into a wrong attribution.

**The consumer's own receipt was replaced before the fix landed, for two measured reasons.**
`theirs_has A B` closes when EITHER substring is absent — `all_present()` is an AND over
substrings, so two of them is a disjunction of two close conditions, the opposite of what the
entry's receipt note argued. And both substrings sit at column 6 of wrapped continuation lines
in `SKILL.md`, so of 61 reflows of that bullet at width 90, 12 closed the receipt with the
defect verbatim, while the legitimate fix that widens the carve-out and keeps both clauses read
STILL-LIVE. The receipt below reads no prose.

verify: sh R=core/skills/ai-dlc-update/reconcile; [ -f "$R/ledger-reverify.sh" ] || exit 9; w=$(mktemp -d) || exit 9; g() { git -C "$w/d" -c user.email=r@r -c user.name=r -c commit.gpgsign=false "$@"; }; git -C "$w" init -q d && echo 1 > "$w/d/VERSION" && g add VERSION && g commit -qm base && b=$(g rev-parse HEAD) && g commit -q --allow-empty -m 'absorbed PC-S900 and PC-S901' && t=$(g rev-parse HEAD) || { rm -rf "$w"; exit 9; }; mkdir -p "$w/c/_bmad-output/ai-dlc-update"; L="$w/c/_bmad-output/ai-dlc-update/push-candidate-ledger.md"; printf '# L\n\n## PC-S900-A\n\nverify: theirs_lacks VERSION "ZZA"\n\n## PC-S900-B\n\nverify: theirs_lacks VERSION "ZZB"\n\n## PC-S901-ONLY\n\nverify: theirs_lacks VERSION "ZZC"\n' > "$L"; rs() { bash "$R/ledger-reverify.sh" "$w/d" "$b" "$w/c" "$t" "$L" 2>/dev/null | cut -f1,2 | sort; }; s1=$(rs); grep -qxF "$(printf 'NAMED-UPSTREAM-AMBIGUOUS\tPC-S900')" <<<"$s1" || { rm -rf "$w"; exit 9; }; grep -qxF "$(printf 'NAMED-UPSTREAM\tPC-S901-ONLY')" <<<"$s1" || { rm -rf "$w"; exit 9; }; perl -0pi -e 's/(## PC-S900-A\n)/$1\n**ADOPTED UPSTREAM (v0.1.0, verified 2026-01-01)**\n/' "$L"; s2=$(rs); bash "$R/ledger-rotate.sh" "$L" --apply >/dev/null 2>&1 || { rm -rf "$w"; exit 9; }; s3=$(rs); grep -qxF "$(printf 'NAMED-UPSTREAM-AMBIGUOUS\tPC-S900')" <<<"$s3" || { rm -rf "$w"; exit 9; }; rm -rf "$w"; [ "$s2" = "$s3" ]

## BL-156 — Check 2z of the acknowledge hook denied a dispatched teammate for a router read only the lead could make, so the deny's remedy was unreachable by the actor it was handed to

**LANDED (v0.496.0, verified 5029f2fd).**

Filed by the reference consumer as
`PC-S308-AI-DLC-ACKNOWLEDGE-ROUTE-DENIED-SUBAGENT-CANNOT-CLEAR` on 2026-09-03, by its
`adversary-s308-prd-p2` teammate from inside the deny. Batch 47 of the ledger drain. DEFECT: a
shipped deny whose stated false-positive cost is "one Read" and whose remedy the denied actor
cannot perform, so the cost is unbounded for every Rule 19 dispatch under a lead that has not
routed yet. Nothing was lost on the consumer — the teammate wrote through a Bash redirect, which
the hook's matcher never sees — and that is the second half of the defect: the deny moved the
write onto the one surface the hook does not watch.

**The mechanism.** `core/hooks/ai-dlc-acknowledge.sh` Check 2z greps `$TRANSCRIPT` for the
`"file_path":"…steps/route.md"` a Read emits, and `$TRANSCRIPT` is `.transcript_path` from the
hook's own payload. On a tool call made INSIDE a dispatched teammate that path is the LEAD's
session file, not the teammate's own `<session>/subagents/agent-<id>.jsonl`
(`ai-dlc-subagent-probe.sh:126-151` measured the same fact at `SubagentStop`). So `AIDLC_SESSION`
is set from the lead's `/ai-dlc` marker while the router Read the teammate DID make sits in a
file the scan never opens. The deny FIRING is itself the proof of which file was read: the
consumer's teammate transcript carries 0 `/ai-dlc` markers of either form and its lead's carries
1, so `AIDLC_SESSION=1` could only have come from the lead's file.

**Measured on the consumer's session `c905e5de`, transcript and teammate file read from
`~/.claude/projects/`, never from the consumer tree.** Lead `/ai-dlc` marker 19:36Z; teammate
dispatched 20:03Z; three `ROUTE_DENIED` rows at 20:22:13Z, 20:23:57Z, 20:24:42Z; the teammate's
own Read of `steps/route.md` at 20:22:33Z, BETWEEN the first and second deny; the lead's first
Read of it at 20:53Z, after all three. The consumer's continuation log holds 22 `ROUTE_DENIED`
rows across 12 sessions; which of those were teammate-shaped is NOT derivable from the log,
because the row carries no agent identity — that observability gap is `BL-126`'s subject and is
not closed here. The differential on the consumer's real inputs, copied to `mktemp`: its
installed hook (byte-identical to the pre-fix distribution copy, `cmp -s`) answers `ROUTE` to the
teammate's Write in the 20:23Z state and the fixed hook answers `ALLOW`, while the LEAD's own
Write in that state is `ROUTE` under both.

**The harness fact the fix rests on.** A teammate's PreToolUse payload carries `agent_id`, and
the lead's carries none. `agent_type` is NOT a second spelling of that fact: a lead started with
`claude --agent <name>` carries `agent_type` and no `agent_id` (measured by the adversarial hand
in a headless session with a PreToolUse payload dumper: the flagged lead read `agent_id` ABSENT,
`agent_type` "Explore"), so a check keyed on `agent_type` exempts that lead and cannot fire on
the population it exists for. Readers of `agent_id` at this event already in
the tree: `ai-dlc-gate-remediation-guard.sh:266-277` ("absent == the lead") and the third-party
`context-mode` plugin's `pretooluse.mjs` (`isSubagentContext = input.agent_id != null ||
input.agent_type != null`); `ai-dlc-context-sensor.sh:164` reads it at `Stop`. The Claude Code
hooks documentation (`https://code.claude.com/docs/en/hooks`, common input fields) says the same:
`agent_id` is "present only when the hook fires inside a subagent call", and `transcript_path`
"is the main session's transcript". The receipt below drives a `--agent`-shaped lead as its
own cell, and a fix keyed on `agent_type` scores STILL-LIVE on it.

**The fix, and the shape it rejected.** Check 2z's guard gains one conjunct, `[ -z "$AGENT_ID" ]`:
a dispatched teammate is outside the check, because the check's own justification binds the
session that LOADED `SKILL.md` and a teammate loaded a role file. The consumer's filing offered
two shapes and both were built as copies and scored on one eight-cell probe table. "Also scan the
teammate's own transcript" clears exactly the teammate that has already read the router and still
tells every other one to READ AND FOLLOW a step that rolls the sprint envelope from inside a
dispatched review — a remedy wrong for the actor even where it is reachable. **What the exemption
acquits, stated:** a lead that never routed can dispatch a teammate to write a file and Check 2z
will not stop that write. Before the fix it DID, by the accident of the transcript pair and not
by design (all three teammate probe cells read `ROUTE` on the pre-fix hook, and the consumer's
teammate transcript holds five denials), and the denied teammate wrote via Bash regardless; what
was never stopped is the DISPATCH, `Agent` being on the allowed surface by design. A delegated
write path covered by accident is now uncovered on purpose. The lead's own next write is still
denied (probe cell `lead-bypass`, and the receipt's control `a`). Check 3's Rule 29 pause deny is
deliberately untouched and still denies a teammate on a paused tree (probe cell `sub-paused`;
receipt control `c`).

**Receipt, scored before it was written.** It drives the shipping hook on a seeded tree with a
lead transcript that carries the `/ai-dlc` marker and no router read, a teammate file beside it
with no read either, a second, paused tree, and a `--agent`-shaped lead carrying `agent_type`
alone. Exit 0 on the fix; 1 on the pre-fix hook, on the scan-both-transcripts shape, on a
whole-hook exemption (control `c` flips to allow), and on an `agent_type`-keyed exemption
(control `e`, the flagged lead, flips to allow); 9 when the lead's own Write is not route-denied
(Check 2z gone or unreachable — nothing measured) or when the teammate cell returns a deny that
names neither check. **The first revision of this receipt accepted the `agent_type` spelling and
called that a design property**; the shipped fixture and the battery accepted it too, because
every seed supplied both fields together or neither, and four channels agreeing for that reason
is the shared-seed failure `verification-discipline.md` names. The fixture `route-read-required`
(ships) carries the same five cells and its `.dist-only` battery kills both the conjunct and the
field-name swap. The consumer's own receipt on this candidate names
`core/.claude/hooks/ai-dlc-acknowledge.sh`, a path that resolves to nothing in this tree at either
ref (the file is `core/hooks/ai-dlc-acknowledge.sh`), so it will read `NEEDS-REVIEW` rather than
close; the pull brief says so and offers the guard line as the anchor.

**`BL-126` was one `jq` read from a false close, and its receipt is replaced in this release.**
It keyed on the hook's READ-SET — exit 0 the moment any agent-identity field is read — and this
fix reads one, for a different check. Its subject, the pause deny's blindness to a teammate, is
untouched, so its receipt now drives that deny instead. The measurement `BL-126` said it owed
first — whether a PreToolUse payload carries a usable discriminator at all — is the paragraph
above.

verify: sh h=core/hooks/ai-dlc-acknowledge.sh; [ -f "$h" ] || exit 9; command -v jq >/dev/null || exit 9; w=$(mktemp -d) || exit 9; trap 'rm -rf "$w"' EXIT; for d in t p; do mkdir -p "$w/$d/_bmad-output/planning-artifacts/s7" "$w/$d/scripts/ai-dlc"; printf '#!/bin/sh\necho 7\n' > "$w/$d/scripts/ai-dlc/sprint-status.sh"; chmod +x "$w/$d/scripts/ai-dlc/sprint-status.sh"; : > "$w/$d/_bmad-output/pipeline-snapshot.md"; done; : > "$w/p/_bmad-output/pipeline-paused.flag"; mkdir -p "$w/s/subagents"; printf '{"type":"user","message":{"content":"<command-name>/ai-dlc</command-name>"}}\n' > "$w/s.jsonl"; printf '{"type":"assistant","message":{"content":[{"type":"text","text":"working"}],"isSidechain":true}}\n' > "$w/s/subagents/agent-ax.jsonl"; d(){ jq -nc --arg tr "$w/s.jsonl" --arg ag "$2" '{session_id:"r",transcript_path:$tr,tool_name:"Write",tool_input:{file_path:"/w/_bmad-output/planning-artifacts/x.md"}}+(if $ag=="" then {} elif $ag=="type" then {agent_type:"Explore"} else {agent_id:$ag,agent_type:"general-purpose"} end)' | CLAUDE_PROJECT_DIR="$w/$1" bash "$h" 2>/dev/null; }; a=$(d t ""); b=$(d t ax); c=$(d p ax); e=$(d t type); case "$a" in *"has not read the router"*) ;; *) exit 9;; esac; case "$c" in *"Rule 29"*) ;; *) exit 1;; esac; case "$e" in *"has not read the router"*) ;; *) exit 1;; esac; case "$b" in *"has not read the router"*) exit 1;; *permissionDecision*) exit 9;; esac; exit 0
## BL-157 — `SKILL.md`'s POST-COMPACT RECOVERY PROTOCOL reads as the resume procedure to a fresh `/ai-dlc resume` session, which then skips the router and is denied its first write

**LANDED (v0.497.0, verified fb2fd0ee).**

Filed by the reference consumer as `PC-S308-POST-COMPACT-RECOVERY-PROTOCOL-SKIPS-ROUTE-MD` on
2026-09-04, by a lead from inside the deny. Batch 48 of the ledger drain. DEFECT: a mandatory
step with a documented enforcer, skipped on a documented path, by a lead following the rulebook
as written.

**What happens.** `core/skills/ai-dlc/SKILL.md:26` opens with the recovery protocol — read the
snapshot, emit the verification turn, "proceed immediately to the next pipeline action" — and
the unconditional router Read (`**READ AND FOLLOW** … steps/route.md`) sits under
`## INITIALIZATION` roughly 1,800 lines below it. A session started with `/ai-dlc resume` loads
the whole file, and a resumed lead reads the protocol as its resume procedure: it matches the
trigger's own words (a snapshot referencing turns the lead cannot recall) and it says what to do.
The lead never reads `steps/route.md`, whose Step 0 is the actual resume path and whose Step 0a
runs the six snapshot integrity checks, and `core/hooks/ai-dlc-acknowledge.sh` Check 2z then
denies its first `Write` — correctly, with a remedy the protocol never named.

**Measured on the consumer's own transcripts, both populations.** 41 sessions started with
`/ai-dlc resume` from 2026-09-03 to 2026-09-04: 10 were denied by Check 2z before any
`steps/route.md` Read, and all 10 had read `pipeline-snapshot.md` before the deny — the
protocol's path, exactly as filed. 51 `/ai-dlc` sessions carrying a compaction summary: 0 were
denied after the summary, because the same transcript already carried the router Read. The
population is the fresh resume, not the compaction the protocol is named for; the filing's
title names the section, not the trigger, and the mechanism paragraph is right.

**The fix, one release.** The protocol now opens by stating its scope — a compaction inside a
session that has already routed — and by sending an un-routed transcript to
`{project-root}/.claude/skills/ai-dlc/steps/route.md` before any pipeline action, naming
`ai-dlc-acknowledge.sh` as what denies until it has. The recover hook's injected block is
untouched: it fires only on a compaction, where the Read is already in the transcript, and a
re-read of the router there would cost the tokens the block exists to save.
`core/scripts/validate-reattach-budget.sh` gained an arm requiring the router's installed path
inside the protocol section outside an HTML comment, with comment state carried across lines
because 18 of the 20 comments in that file span them; it fails the pre-fix `SKILL.md` and
passes the fixed one. `core/fixtures/postcompact-rulebook-recovery` carries a mutant that strips
the path, one that parks it in a one-line comment, one that parks it in a multi-line comment,
each failing on that arm alone, and a control asserting a live path bracketed by two comments
on one line still passes.

**Receipt limits, stated.** The receipt drives the shipping validator against the shipping
`SKILL.md` and against a copy with every `steps/route.md` path removed, and reads exit codes
only: it closes when the real file passes and the stripped copy fails. It does not read the
prose, so a protocol that names the path in a sentence telling the lead NOT to read it would
score as fixed; the fixture's comment mutant covers the comment form and nothing covers that one.
A validator that fails every file also reads STILL-LIVE here, which is the correct direction.
The consumer's own receipt keys on the section heading, which any fix keeps, so it reads
STILL-LIVE through this fix and the consumer should re-anchor it on the next pull.

verify: sh v=core/scripts/validate-reattach-budget.sh; s=core/skills/ai-dlc/SKILL.md; [ -f "$v" ] && [ -f "$s" ] || exit 9; bash "$v" --skill "$s" --quiet >/dev/null 2>&1 || exit 1; t=$(mktemp) || exit 9; trap 'rm -f "$t"' EXIT; sed 's|\.claude/skills/ai-dlc/steps/route\.md|the router step|g' "$s" > "$t"; cmp -s "$s" "$t" && exit 1; bash "$v" --skill "$t" --quiet >/dev/null 2>&1 && exit 1; exit 0

## BL-158 — the handoff guard never armed on a resumed session's handoff request, and had no arm for steps 4 and 5 once it did

**LANDED (v0.498.0, verified 2babee86).**

Filed by the reference consumer as `PC-S308-HANDOFF-PROCEDURE-5-STEP-NOT-FOLLOWED` on 2026-09-04,
the third filing of one end state: `BL-120` (`v0.434.0`) fixed the push COMMAND and `BL-125`
(`v0.438.0`) fixed the resume line's router, and each removed one route to an incomplete handoff.
Batch 49 of the ledger drain, scoped by the operator with the context that the miss "happens
often, it's just never been filed before". DEFECT: a mandated five-step procedure whose enforcer
could not arm on the incident and asserted three of the five steps when it did.

**Two defects, one seam.** `core/hooks/ai-dlc-continue.sh` Check 0 is the Stop-hook guard on the
handoff procedure. It arms from the transcript's last user message or from the on-disk predicate
`ai_dlc_handoff_pending` (`core/hooks/ai-dlc-handoff-pending.sh`), whose key 3 reads this
session's operator prompts from the continuation log. (1) Key 3 applied the mention-exclusion
regex to ALL the session's prompts joined, and `/ai-dlc` is in that vocabulary — so the
`/ai-dlc resume` row every resumed session carries first vetoed every later request row for the
rest of the session. Driven on a copy of the consumer's real log for the incident session: rc=1;
the same rows with the resume row removed: rc=0. The transcript channel was blind for the reason
the hook's own header records (a mid-turn `handoff` is a queue-operation, never a user message;
`LAST_USER` at the Stop was `trim` from fifteen minutes earlier). Result: `ALLOWED_BY_PAUSE`, no
guard row. (2) Once armed, the guard asserted steps 1 (teammate sweep), 3 (push) and the resume
line, and nothing for step 4's `touch _bmad-output/.driver/handoff` or step 5's
`rm -f _bmad-output/.handoff-in-progress`.

**Population, from the consumer's transcripts.** 120 handoff commits across all refs; 39 fall
inside the transcript corpus (2026-08-04 → 2026-09-04) and are scorable by Bash tool-call
INPUTS, not text (the body of `handoff.md` contains all three command strings, so a text scan
over-scores). Step 3 skipped 3 of 39; step 4 skipped **20 of 39**, six times the push and the
step the filing ranks third; step 5 skipped 4 of the 17 in scope since `v0.447.0` wrote it. Step-4
skips ran 7 of 7 in the first half of August, 12 of 17 in the second, 1 of 15 in September, and the
turn coincides with the operator's first "did the handoff steps run" prompt on 2026-08-30 — 11
such prompts since, none before, and no mechanism changed. A step counts as run within 25
minutes of the commit, so operator-prompted remediation is credited and the unprompted rate is
worse than every figure here.

**The fix.** Key 3 scores intent and exclusion PER ROW: a row is a request when it matches the
intent pattern and does not itself match the exclusion. Check 0 gains `DRIVER_OK`
(`.driver/handoff` present) and `MARKER_OK` (`.handoff-in-progress` absent), dispatched after the
three existing arms in procedure order with their own remedy text and `H_WHY` clauses.
`handoff.md` step 4 and the auto-handoff twin in `_gate-procedures.md` now spell the touch as
`mkdir -p _bmad-output/.driver && touch …`, since `touch` fails without the directory. Driven on a
copy of the incident state, the fixed hooks BLOCK where the shipped ones write `ALLOWED_BY_PAUSE`.
`core/fixtures/handoff-completion-assertion` carries cases (d1)–(d3) and (g3), mutants m20
(session-wide exclusion restored), m21 and m22 (each new arm removed, with the other arm's
survival as the entanglement control); `handoff-resume-guard` seeds the lead's touch in its
drive().

**Two defects the adversarial hand found in the first cut, both fixed before the merge.** The
driver arm asserted the FILE's presence, and on the reference consumer `.driver/handoff` has sat
on disk since the last handoff that touched it — no driver is attached there to consume it — so
the arm for the most-skipped step would have shipped inert on the tree its skip rate was
measured on. It now requires the signal to be NEWER than the finalized snapshot when one exists
(step 3 precedes step 4 in the procedure), with presence as the stated fallback when there is no
snapshot. And the marker arm asserts the absence of the same file that is key 1, so a lead that
ran step 5's `rm -f` before step 4's touch removed the only thing arming the guard and escaped
both arms. The first armed Stop now records its session id in `.handoff-guard-armed`, and every
later paused Stop of that session is armed by the record until the guard is satisfied, the
backoff releases, or the pause flag comes down. Both have fixture cases ((d4), (d5)) and mutants
(m23, m24).

**Stated limits.** A lead that touched the signal at step 4 and then re-finalized the snapshot
after a teammate-arm block is told to touch again — one extra round in a rare ordering. The
freshness reference is the snapshot, so a handoff that skipped step 3's finalization entirely has
no reference and the driver arm falls back to presence. The four adjacent defects the batch-49
hands found are filed as `BL-159` and not fixed here.

verify: sh h=core/hooks; l=core/schemas/pause-routing.json; [ -f "$h/ai-dlc-continue.sh" ] && [ -f "$h/ai-dlc-handoff-pending.sh" ] && [ -f "$l" ] || exit 9; command -v jq >/dev/null || exit 9; w=$(mktemp -d) || exit 9; trap 'rm -rf "$w"' EXIT; mkdir -p "$w/p/_bmad-output/.driver" "$w/q/_bmad-output/.driver"; : > "$w/p/_bmad-output/pipeline-paused.flag"; : > "$w/q/_bmad-output/pipeline-paused.flag"; printf '## 2026-09-04T06:21:13Z -- USER_PAUSE\n- Session: s1\n- Channel: UserPromptSubmit (typed message)\n- Prompt (first 120 chars): /ai-dlc resume\n\n## 2026-09-04T06:47:11Z -- USER_PAUSE\n- Session: s1\n- Channel: UserPromptSubmit (typed message)\n- Prompt (first 120 chars): handoff\n\n' > "$w/p/_bmad-output/pipeline-continuation-log.md"; printf '{"message":{"role":"user","content":"trim"}}\n{"message":{"role":"assistant","content":"done"}}\n' > "$w/t.jsonl"; d() { o=$(jq -nc --arg t "$w/t.jsonl" --arg s s1 '{transcript_path:$t,session_id:$s}' | CLAUDE_PROJECT_DIR="$w/$1" AI_DLC_PAUSE_ROUTING_SCHEMA="$l" bash "$h/ai-dlc-continue.sh" 2>/dev/null); [ -z "$o" ] && { echo allow; return; }; printf '%s' "$o" | jq -r '.decision // "allow"'; }; a=$(d p); [ "$a" = block ] || exit 1; printf '{"message":{"role":"user","content":"hand off the sprint"}}\n{"message":{"role":"assistant","content":"----\\n/ai-dlc resume\\n----"}}\n' > "$w/t.jsonl"; b=$(d q); : > "$w/q/_bmad-output/.driver/handoff"; rm -f "$w/q/_bmad-output/handoff-guard-state.txt"; c=$(d q); [ "$b" = block ] && [ "$c" = allow ] && exit 0; exit 1

## BL-160 — the ledger's entry-boundary rule opened an entry on a heading-shaped line inside a code fence, so a `derived` block split the entry that carried it

**LANDED (v0.499.0, verified 13502c45).** Merged as PR #619; the release commit names the
`PC-` id verbatim and `named_absorbed()` resolves it to `0.499.0`. The receipt below drove the
shipping engine and read CLOSE-CANDIDATE on the merged tree.

Consumer provenance: `PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS`, filed by
the reference consumer on 2026-09-04 at step 3f of its 0.492.0 → 0.497.0 pull. DEFECT tier: the
instrument this program reads misfiled a receipt under a timestamp label, and the same rule in
`ledger-rotate.sh` then rotated the entry in pieces.

**The claim, re-derived here before building.** `ledger_entry_shape()` in
`core/skills/ai-dlc-update/reconcile/lib.sh` called every `^#{2,6} ` or `^- **` line a boundary
and tracked no fence state. Driven on the distribution engine at `origin/main` with the filing's
own two-line fixture: a fenced `## 2000-01-01T00:00:00Z -- SWALLOW` line labelled the receipt
with the timestamp; the plain-fence control labelled it `PC-CTRL`. On the consumer the damage had
already run past the filing: its 0.497.0 pull rotated
`PC-S308-AI-DLC-ACKNOWLEDGE-ROUTE-DENIED-SUBAGENT-CANNOT-CLEAR` on its three fenced timestamp
lines, leaving two orphan unfenced fragments in the live ledger (lines 3222–3225 at
md5 `ae45394b…`) and a rebuilt fence holding one line in the archive. The reader set is entirely
shared through `lib.sh` — derived by an independent hand, control: the only other `^#{2,6}`
sites in `core/` are the layer-file heading helpers bound by I40.

**Why the obvious fix is wrong, measured.** A plain fence toggle hides 6 live ids on the
consumer (one live line opens with an inline code span, which CommonMark does not read as a
fence) and 59 archived ones (fences left unterminated by earlier splits). The shipped rule uses
the CommonMark opener and closer grammar, bounded by the id rule: a fenced entry-shaped line
whose label is not id-keyed is ignored; one that is id-keyed still opens an entry and resets
the fence, and `ledger-reverify.sh` reports that reset as `ENTRY-SWALLOWED` with the `fence`
signal. Over the consumer's live ledger, its archive and both backlog files: no id-keyed boundary
changes, one non-id line stops being a boundary, two id-keyed headings inside earlier-split
fences are kept and flagged.

**What this does not close.** The consumer's two orphan fragments are bare headings outside any
fence now; a consumer hand has to delete them. The close predicates stay fence-blind by design.
A PROSE-titled entry-shaped line after a fence that never closes, or after a closer carrying
trailing text, is read as fenced and opens nothing, silently: the reported reset fires only on an
id-keyed line, and only a fence still open at end of file is reported on its own. The adversarial
hand measured that set as one line on the consumer's four ledger files, the intended one, and it
is stated in `lib.sh`'s header. A fence quoting TWO id-keyed headings costs one false fence row
on the entry after it, beside the true row; the alternative was measured to cost seven false
resets on the consumer's archive, and the `ledger-reverify` fixture pins the chosen side. `scripts/backlog-rotate.sh`'s own fence guard keeps a separate
naive toggle and is `BL-161`.
The receipt below drives the shipping engine on a three-entry ledger and reads the label column
only: it rejects the pre-fix rule, the fence-blind mutant, the id-reset-removed mutant and the
naive toggle (the last by hiding `PC-AFTER`), and accepts a rule that mis-reads an inline span
as an opener — that clause is held by the `ledger-reverify` fixture's `mutation-naive-opener`
arm, not by this receipt.

verify: sh t=$(mktemp); printf '## PC-CTRL — t\n\n```\n## 2000-01-01T00:00:00Z -- FENCED-TS\n```\n\nverify: theirs_has core/VERSION "."\n\n## PC-UNT — u\n\n```\nnever closed\n\n## PC-AFTER — v\n\nverify: theirs_has core/VERSION "."\n' > "$t"; o=$(bash core/skills/ai-dlc-update/reconcile/ledger-reverify.sh "$PWD" HEAD "$PWD" HEAD "$t" 2>/dev/null); rm -f "$t"; awk -F'\t' '$2=="PC-CTRL"{c=1} $2=="PC-AFTER"{a=1} $2 ~ /FENCED-TS/{s=1} END{exit !(c && a && !s)}' <<<"$o"

## BL-162 — `validate-artifact-derivations.sh` and the capture hook matched a ```derived fence opener at column 0 only, so a block indented inside a list item was never checked and never witnessed, with exit 0 and no error

**LANDED (v0.500.0, verified 2dca4815).** Merged as PR #622; the release commit names the
`PC-` id verbatim and `named_absorbed()` resolves it to `0.500.0`. The receipt below drove both
shipping programs and read CLOSE-CANDIDATE on the merged tree.

Consumer provenance: `PC-S308-VALIDATE-ARTIFACT-DERIVATIONS-INDENTED-FENCE-BLIND-SPOT`, filed by
the reference consumer on 2026-09-03 by `remediator-s308-gate1-p2` while repairing
`carry-over-evaluation.md`, where it had already demoted two indented `derived` fences to `text`
because the check was not firing. DEFECT tier: a fenced claim is the author's promise that the
number is machine-checked, and the tool answered that promise with "0 derivation(s) in 0
block(s)" and exit 0 — the one output it must never produce over a fence.

**The claim, re-derived here before building.** The filing's own two-file reproduction, run on
`core/scripts/validate-artifact-derivations.sh` at `origin/main` (the filing names the
consumer-shaped path `scripts/ai-dlc/…`, which resolves nowhere here): the indented file reports
0 blocks with rc 0, the unindented control reports 1. The fence-open match at `:289` was a `case`
on the line as read. The reader set is TWO programs, not the one the filing names:
`core/hooks/ai-dlc-derivation-capture.sh` reads the same fence at column 0 in its scope grep
(`:120`), its mask (`:154`) and its command grep (`:180`), and its header binds the two to one
population. Control: `'```derived'` across `core/` names exactly those two programs plus
fixtures. On the consumer today: 11 files carry 26 indented openers against 272 files with
unindented ones; the installed and the shipped validator over those 11 files read 87 and 106
STALE, 6 and 14 ALLOWLIST refusals, and three files flip from rc 0 to rc 1 — nineteen stale
derivations and eight refused commands the consumer's own gate has never reported.

**The rule, and the obvious one rejected by measurement.** CommonMark's: the opener's leading
blanks are the block's indent and each content line sheds exactly that prefix, or whatever
leading blanks it has when it carries fewer. Shedding ALL leading blanks turns a right-aligned
`wc -l` count STALE under an unindented fence, and the fixture pins that with a padded twin.
Any indent width opens a fence; CommonMark's three-space cap is deliberately not applied,
because a fence run that CommonMark would have rendered literal is a visible STALE where a
skip is the silent zero this entry records.

**What the indent rule uncovered, fixed in the same release.** Driving the indent-aware
validator over the 11 consumer files, one LOST three derivations: a numbered list item whose
wrapped continuation begins "```derived blocks are machine-checked and plain blocks are not,
…" matched the opener arm `'```derived '*`, opened a phantom block that ran to the next real
opener, read it as a closer, and left the real block's pairs outside any fence. Over the
consumer's 2795 openers: zero carry legitimate text after the word, two are prose (one at
column 0, which the old reader was already swallowing in a different file). Both programs now
require the shed line to be exactly the token plus optional blanks.

**What this does not close.** A `$ ` line indented deeper than its fence is OUTPUT, not a
command, in both programs — the shed form decides — and an author who indents commands past
the fence will read a STALE naming the line. The consumer's demoted `text` fences in
`carry-over-evaluation.md` stay demoted until a consumer hand re-fences them; the fix cannot see
a fence the author removed.

The receipt drives both shipping programs on a throwaway consumer layout: the validator must
count an indented block and a block below a prose line beginning with the token as two blocks,
and the hook must exit 2 on a Write carrying an indented stale pair. It rejects the pre-fix tree,
the indent-only half of the fix, and a tree where only the validator moved.

verify: sh d=$(mktemp -d); mkdir -p "$d/scripts/ai-dlc"; cp core/scripts/validate-artifact-derivations.sh "$d/scripts/ai-dlc/validate-artifact-derivations.sh"; printf '0\n' > "$d/VERSION"; printf -- '- item\n  ```derived\n  $ cat VERSION\n  9\n  ```\n' > "$d/a.md"; printf '```derived would promise nothing\n\n```derived\n$ cat VERSION\n9\n```\n' > "$d/b.md"; o=$(cd "$d" && AI_DLC_PROJECT_ROOT="$d" bash scripts/ai-dlc/validate-artifact-derivations.sh --list a.md b.md 2>&1); h=$(jq -nc --arg f "$d/a.md" --arg c "$(cat "$d/a.md")" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' | CLAUDE_PROJECT_DIR="$d" bash core/hooks/ai-dlc-derivation-capture.sh 2>/dev/null; echo $?); rm -rf "$d"; grep -q '^2 derivation(s) in 2 block(s)' <<<"$o" && [ "$h" = 2 ]
## BL-164 — the handoff-intent declaration could not read a terse request that trails unrelated context, so a typed "I'm solving this issue. handoff." armed nothing and the lead improvised the procedure

**LANDED (v0.502.0, verified 4dc8d791).** Merged as PR #627; the release commit `b2e1da74` names the id verbatim and `named_absorbed()` resolves it to `0.502.0`.

Filed by the reference consumer as `PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING`
on 2026-09-05 (ledger row `2026-09-05T01:54:16Z`, filing commit `a0de44a99` six minutes later),
the fourth filing of the end state `BL-158` records — an unperformed handoff — and the first
against the VOCABULARY rather than a reader of it. Batch 52 of the ledger drain, scoped by the
operator from a marked recommendation over three siblings on consequence: a silent guard failure in
the subsystem batch 49 repaired. DEFECT: `core/schemas/pause-routing.json`'s
`handoff_intent_pattern` spelled a terse request only as the whole field
(`^[[:space:]]*hand[ -]?off[[:space:]]*$`), so the same word as the final sentence of a message
that opens with unrelated context scored NOT-PENDING on every reader, and `ai-dlc-continue.sh`
Check 0 never armed.

**Reader set, derived.** Five sites resolve the declaration through one `jq` line each:
`core/hooks/ai-dlc-handoff-pending.sh:118` (key 3, per row of this session's continuation-log
prose), `core/hooks/ai-dlc-continue.sh:239` (Check 0 on the transcript's last user message),
`core/hooks/ai-dlc-answer-capture.sh:194` (an AskUserQuestion answer),
`core/fixtures/handoff-completion-assertion/run.sh:327`, and invariant I94 in
`scripts/validate-enforcement-map.sh`, which forbids a second copy anywhere under `core/` or
`scripts/`. Control: `handoff_intent_pattern` names exactly those files and no other. The
consumer's installed copies of the schema and of all three hooks were byte-identical to `core/`
at filing, so the filing describes what ships.

**The remedy was BUILT AND SCORED against the consumer's whole history, and the obvious wider
form is refuted.** Population: every `- Prompt (first 120 chars):` and `- Answer (first 120
chars):` row ever added under the consumer's `_bmad-output/` across all refs, plus the working
tree — 3379 unique rows, incident row present as the positive control, 110 rows carrying the word
at all. The shipped pattern matches 6 (all outside the exclusion). The filing's own shape — a
final sentence that is exactly the word, preceded by sentence punctuation:
`(^|[.!?][[:space:]]*)[[:space:]]*hand[ -]?off[[:space:]]*[.!]?[[:space:]]*$` — admits exactly
two more, both requests ("I'll fix the pipeline routing logic in the upstream ai-dlc distribution
project. Handoff." and the incident). An alternative keyed only on the trailing word
(`hand[ -]?off[[:space:]]*[.!]?[[:space:]]*$`) admits fifteen, five of them questions or denials
("I didn't request handoff", "why haven't we done a handoff", "The interesting thing to me is that
the handoff that I issued should have pushed it before completing the handoff."), and is rejected
on that count. Widening the boundary class to commas and semicolons changes nothing on this
corpus, so it was not taken. Driven through the SHIPPING predicate on a copy of the consumer's
real continuation log with the pause flag raised and no other key: the incident session
(`14a97e8b`, 82 rows) reads rc=1 under the shipped declaration and rc=0 `log-request` under the
repaired one; across every session in that log the PENDING count moves 21 → 22 and the one
that moves is the incident's.

**The fix** is that one alternative appended to the declaration, with the schema's own
description recording the shape and the census — and the old whole-field alternative
(`^[[:space:]]*hand[ -]?off[[:space:]]*$`) removed, because the new one's start-of-field branch
subsumes it: deleting it changes zero verdicts on the census (8 matches either way, 0 lost, the
same 2 admitted), and a dead alternative left in place was the thing m25's first control had come
to depend on. `core/fixtures/handoff-completion-assertion` gains the consumer's row verbatim as
`P_TERSE`, three real near-misses and one synthetic (the unpunctuated denial with its curly
apostrophe, the punctuated denial "…if I wanted to handoff.", the definite-article question "did
all of the handoff steps run?", and the copula noun "the handoff was fine yesterday", which no
consumer row carries), seed-premise arms on each, case (g4) through the on-disk reader AND the
transcript reader with near-misses, and mutant m25 — a COPY of the declaration with the
alternative stripped, driven through the unmodified hooks, killed by (g4) on both readers, with
the verb phrase as the control on each reader that the key survived and the bare word asserted
ALLOWED under the copy so a reinstated duplicate is noticed. `core/fixtures/answer-handoff-routing`
gains the same pairs through the answer channel. Against the pre-fix declaration the first fixture
reports FIXTURE BROKEN at its seed premise and the second four assertions FAILED.

**The receipt and the battery were scored against nine implementations, and two rounds of that
scoring each found a hole.** The first receipt's near-miss carried no terminal punctuation, so a
trailing-word regression that REQUIRES a period (`hand[ -]?off[[:space:]]*[.!][[:space:]]*$`,
which admits four denials or questions on the consumer's history) passed it and passed the
fixture's behavioural near-miss too — caught only by m25's byte-lock. The punctuated real denial
is now the receipt's third row and a seed in both fixtures. And two noun-mention widenings
(`|the hand[ -]?off|`, `|handoff (is|was|will)|`) passed the receipt and both fixtures, because
nothing asserted the description's own claim that a noun mention is not a request; the three
noun seeds close them. Final scoring: the receipt closes on the fix and on a second spelling and
stays open on the shipped pattern, both trailing-word regressions, both noun widenings, a
disarm and an empty pattern; the fixtures are green only on the fix, and red on a respelling
solely at m25's byte-lock, whose message now says so and names `ALT_TERSE` as the thing to
re-anchor.

**Two defects the batch-52 hands found in the readers, both fixed before the merge.** The
declared patterns anchor on `^` and `$`, and grep anchors per LINE, so a multi-line message whose
MIDDLE line ended in the terse form — an operator pasting this entry's own incident row into a
question — matched on that line alone and routed the whole message through Check 0's transcript
arm and through the answer channel; a bare `handoff` line inside a longer message already did,
before this release. `ai-dlc-pause.sh` collapses newlines before it writes the row key 3 reads,
so `ai-dlc-continue.sh` and `ai-dlc-answer-capture.sh` now collapse the same way for the match
(the answer record keeps its newlines): case (g5) and mutant m26, and Assertion 6c with a
per-line mutant, each with a last-line sibling that must still route. And I94(c) hand-listed the
three hooks that carry the BRANCH TEXT and omitted `ai-dlc-handoff-pending.sh`, which reads the
PATTERNS through its own `$_schema` argument and decides key 3; each reader now carries the
variable its `jq` line feeds, proved on a worktree in both directions, validator wall clock 25s
against 26s. On a tree built by `install.sh` the three handoff fixtures read 144 / 21 / 13 ok,
the same as here.

**Stated limits, each measured, none fixed here.** (1) `core/hooks/ai-dlc-pause.sh:67` records
the first 120 characters of a prompt, so a terse request trailing more than that is invisible to
key 3 under any pattern; the transcript reader sees the whole message but is blind to a mid-turn
request (the hook's own header). The cut runs the other way too: it manufactures the end anchor
and can delete the exclusion's object in the same stroke, so a long mention whose 120th
character falls after a sentence-initial "Handoff" scores PENDING on the row and not on the
full text. Over the consumer's 872 full request bodies, 249 exceed the cut and exactly one
request-shaped match is lost to it, a mention. (2) `[.!?]` is any period, and the space class
after it admits zero characters: an abbreviation, a decimal, a single-letter list marker or an
abutting token before the word opens the alternative ("Use a terse word, e.g. handoff", "See
section 4.2. handoff", "A. resume B. handoff", "the file is data.handoff" all score REQUEST,
exclusion clean). Zero instances in the 3379-row census; a false PENDING costs one blocked Stop
with its remedy text, a false NOT-PENDING is this entry, and the tightening that excludes them
(`[A-Za-z]{2,}[.!?]`) also excludes a sentence ending in a number or a version. (7) A quoted
request that lands on the LAST line of a message is, after the collapse, byte-identical to a
message ending in that request, and the transcript and answer readers score it PENDING
("Please add a fixture arm for the row this filing quotes:" followed by the incident row). No
regex separates a quotation from a request at the end of a field; a heuristic keyed on a
preceding colon would be a lint with an unmeasured false-positive set, and the cost of the
false PENDING is one blocked Stop with its remedy text. The middle-line position is closed by
the collapse; the last-line position is not, and (g5)'s sibling asserts that a last-line
request BLOCKS. (3)
`core/skills/ai-dlc/steps/route.md:29-31` restates the ENTRY-TOKEN predicate in prose as the
WHOLE input, deliberately narrower than the declaration and measured on its own 67-prompt
corpus; a session whose FIRST input is the terse-trailing form is routed as a new feature there
while key 3 arms at its first Stop. Nothing binds that prose to the declaration and I94 cannot
see a paraphrase. (4) Two consumer rows open with the word and a comma ("handoff, will PVC after
handoff", "Handoff, explicit authorize on resume") and match nothing; both sit in sessions that
already carried a matching row. (5) "Ok, then let's handoff" misses because the row carries a
curly apostrophe and the declaration's `let's` is ASCII. (6) Three June rows are a bare
"Handoff" behind a `<system-reminder>` prefix; `ai-dlc-pause.sh` strips that prefix today.

verify: sh d=$(mktemp -d); s=core/schemas/pause-routing.json; h=core/hooks/ai-dlc-handoff-pending.sh; { [ -f "$s" ] && [ -f "$h" ]; } || exit 9; : > "$d/pipeline-paused.flag"; printf '# log\n\n## 2026-09-05T01:54:16Z -- USER_PAUSE\n- Session: s1\n- Prompt (first 120 chars): I am solving this issue. handoff.\n\n## 2026-09-05T01:55:00Z -- USER_PAUSE\n- Session: s2\n- Prompt (first 120 chars): I did not request handoff\n\n## 2026-09-05T01:56:00Z -- USER_PAUSE\n- Session: s3\n- Prompt (first 120 chars): continue. Note for retro that you were not supposed to pause the pipeline to ask me if I wanted to handoff.\n\n' > "$d/pipeline-continuation-log.md"; . "$h"; ai_dlc_handoff_pending "$d" s1 "$s" || exit 1; ai_dlc_handoff_pending "$d" s2 "$s" && exit 1; ai_dlc_handoff_pending "$d" s3 "$s" && exit 1; exit 0
## BL-152 — `context-sensor`'s freshness control seeds a file 59s old against a `NOW` captured earlier, and the pool eats the one-second margin

**LANDED (v0.502.0, verified b69bfd13).** Incidental close found by batch 53's pre-batch receipt
histogram: `b69bfd13` (`fix(fixture): context-sensor measures a seed age from the moment it is
written`), on the batch-52 branch merged as PR #627, moved the `date +%s` read into the seed call
of the 59s arm (`core/fixtures/context-sensor/run.sh:453`); the receipt below exits 0 against
`origin/main` and the fix commit named no `BL-` id, so nothing rotated it.

**Found 2026-09-03 while landing batch 45's docs commit**, which touched no fixture: the pre-push
gate refused the push on `context-sensor`, green solo (`99 passed, 0 failed`) and red under the
12-way pool (`1 of 185 units red`, `98 passed, 1 failed`). Consumer-facing: the fixture ships,
so a consumer's push can be refused by it for the same reason. DEFECT.

The arm is `CONTROL: 59s old is still fresh and IS taken` (`core/fixtures/context-sensor/run.sh:448`).
It seeds `window.json` with `ts = NOW - 59`, where `NOW` is captured ONCE at `run.sh:392`, some
fifty hook invocations before this arm runs; the hook's freshness bound is
`AI_DLC_WINDOW_MAX_AGE` defaulting to 60 (`core/hooks/ai-dlc-window.sh:89`) and it judges age
against the wall clock at invocation time. The margin is therefore ONE SECOND minus everything
that ran since line 392. Solo that is under a second; under the pool it is not, the file reads
as 60s or older, the hook falls back, and the arm reports `expected '420000', got '300000'`.
The sibling arm at `:443` (`61s old falls back`) is safe by construction — latency only makes it
staler.

**Not a hook defect.** The hook's 60-second bound is the subject under test and is correct; the
fixture's clock is the defect. The measured red run is in `.git/ai-dlc-fixture-failures` under
the `2026-09-03T20:24:46Z` header.

**Remedy shape:** capture the clock at the seed, not at the file's top — either `seedwin` takes
an OFFSET and computes `$(date +%s) - offset` itself, or `NOW` is re-read immediately before the
59s arm. Widening the margin (59 → 30) also works and is worse: it hides latency instead of
removing it, and the 61s sibling then has a 31-second gap between it and the control. Whichever
form, prove it can fail: run the arm with a `sleep 2` injected between seed and fire, before and
after.

**Receipt limits, stated.** The receipt keys on a fresh `date +%s` reaching the seed — inside
`seedwin`'s body or within six lines above the 59s arm. A fix that widens the margin instead
scores STILL-LIVE, deliberately: that form is discouraged above. Exit 9 if the arm is gone.

verify: sh f=core/fixtures/context-sensor/run.sh; [ -f "$f" ] || exit 9; n=$(grep -n '59s old is still fresh' "$f" | head -1 | cut -d: -f1); [ -n "$n" ] || exit 9; awk -v n="$n" '/^seedwin\(\)/{s=1} s && /date \+%s/{c++} s && /^}/{s=0} NR>=n-6 && NR<=n && /date \+%s/{c++} END{exit !(c>0)}' "$f" && exit 0; exit 1

## BL-165 — `validate-adversarial-convergence.sh` counted pass 1 as "scope grew" whenever its first pass found a CRITICAL, so arm D told every mid-cycle series to FREEZE and CUT scope that had never moved

**LANDED (v0.503.0, verified 69010ae9).** Merged as PR #630; the release commit names the id
verbatim and is the only commit on `origin/main` that does, so `named_absorbed()` lists exactly
it at `0.503.0`.

Filed by the reference consumer as `PC-S308-VALIDATE-ADVERSARIAL-CONVERGENCE-SCOPE-GREW-MISFIRES-ON-PASS-1`
on 2026-09-03, found while gate-validating a sprint-308 PRD adversarial series. Batch 53 of the
ledger drain, scoped by this session from its own ranking on consequence (a gate-blocking wrong
diagnosis that trains authors to falsify a fail-closed field), batched with `BL-166`. DEFECT.

The SCOPE_GREW accumulator at `core/scripts/validate-adversarial-convergence.sh:674` incremented
on `crit > prior` for every pass, with no test that a previous pass exists. Pass 1 has no
predecessor, so an honest `findings_critical_prior_scope: 0` beside any CRITICAL satisfied it,
and arm D's terminal branch (`:1617`) then reported "MOVING ARTIFACT … FREEZE the artifact …
CUT the added scope" for every gate run while the series was still mid-cycle. Arm C one screen
above (`:655`) already guards the same comparison with `[ -n "$PREV_CRIT" ]`; the increment did
not.

**Population, measured on the consumer's real artifacts, read-only.** Over every tracked
pass-1 adversarial artifact under its `_bmad-output/` (79 files, repair records excluded, 68
declaring the field): 28 report more CRITICALs than prior scope, 27 of them at an honest
`prior_scope: 0` (every one misdiagnosed), 7 declare `prior == crit` with a CRITICAL present
(authors dodging the misfire by declaring the fail-closed default, which falsifies the field
arm C depends on), 33 found no CRITICAL. Differential on scratch copies of the 28, each as the
gate saw it mid-cycle with only pass 1 on disk, installed validator against the fixed one with a
`cmp -s` control that the two differ in the same run: installed says MOVING ARTIFACT on 28 of
28; fixed, 0 of 28 and the generic "run another pass" remedy on all 28.

**The fix** is the one guard arm C already has, `[ -n "$PREV_CRIT" ]`, on the increment.
Growth at pass 2 or later still counts: the fixture's existing `scope-grew-unconverged` case
(growth at passes 2 and 3) still reports MOVING ARTIFACT, and a new case with growth at pass 2
only proves the guard excludes pass 1 and nothing else. The consumer's dominant shape (pass 1
with a CRITICAL and an honest zero) had no fixture case before this: every seed set pass-1
`prior == crit`. `core/fixtures/check-24-adversarial-convergence` gains `pass1-honest-zero-unconverged`
(exit 1 with the GENERIC remedy, and `MOVING ARTIFACT` / `CUT the added scope` both asserted
silent), `pass1-honest-zero-converges` (the near-miss control, green on both sides by design),
`pass1-honest-zero-then-growth` (growth at pass 2 only, MOVING ARTIFACT required), and two
mutants driven on a copy of the validator: `scope-grew-unguarded` (the guard removed, kills only
the first case) and `scope-grew-wrong-var` (guard on an unrelated variable, kills only the third),
each with an anchor-uniqueness arm and an unmutated control. Against the pre-fix validator the
fixture reports seven reds, all of them the new arms; on an `install.sh` tree, 123 of 123.

**Two pre-existing arms were dead and are repaired in the same commit.** `stall-preempts-d` and
`ceiling-preempts-d` asserted the ABSENCE of "Either run another pass to a clean verdict", a
phrase the validator wraps across two lines and so can never emit (`grep -cF` 0 against a
control of 1 for the single-line token beside it); both had passed on an unproducible absence.
Rekeyed on the single-line token, both still pass, and the new generic-remedy arm is the
positive control that the token appears at all.

**Two wrong fixes the first receipt and the first fixture both accepted, found by the
adversarial hand.** `[ "$prior" -gt 0 ]` in place of the guard passed every behavioural arm (only
the byte-locked mutation anchor failed, which an author re-anchors as `fixture-mutants.md`
prescribes), because every seed and the receipt's control placed pass-2+ growth at `prior > 0`;
growth at `prior == 0` after pass 1 is the purest moving-artifact signal, the consumer carries 11
such passes across 9 series, and that variant loses MOVING ARTIFACT on 13 mid-cycle states in 6
real series. And a guard on the pass NUMBER being 1 counts the first file of a series whose
lowest pass on disk is 2 (the consumer's `s288` architecture and PRD series, passes 2–4 and
2–8, both legacy series carrying no `verdict:` field, so arm D takes its no-verdict branch on
them and neither exercises the guard today), reproducing
the defect on that shape. Both are now seeded in the receipt and in the fixture as
`scope-grew-at-zero-prior` and `series-starts-at-pass2`; against the `prior > 0` variant and the
pass-number variant, each re-anchored as an author shipping it would, the fixture still fails on
four arms, the discriminating ones behavioural.

**Receipt limits, stated.** The receipt seeds four series and drives the shipping validator on
each: pass-1 honest zero then nothing (GENERIC required), growth at pass 2 with `prior == 0`
(MOVING ARTIFACT required), passes 2 and 3 only with the first carrying a CRITICAL at prior 0
(GENERIC required), and a read-control with growth at `prior > 0` that refuses (exit 9) unless it
says MOVING ARTIFACT. Scored: the fix 0; pre-fix, the unguarded, the `prior > 0` and the
pass-number variants 1. A guard on "first file in sorted order" rather than on `PREV_CRIT` also
passes and differs from the fix only when that first file has no parseable CRITICAL count. The
receipt cannot see the seven falsified consumer fields; those are the consumer's to correct once
its gate stops demanding them.

verify: sh V=core/scripts/validate-adversarial-convergence.sh; [ -f "$V" ] || exit 9; d=$(mktemp -d); p() { printf "# pass %s\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\nmode: subagent\nlead_role: r\ninvoked_at: 2026-07-12T%02d:00:00Z\ntool_use_id: t%s\nfindings: %s CRITICAL, 1 MAJOR, 0 MINOR\nfindings_critical: %s\nfindings_critical_prior_scope: %s\nfindings_major: 1\nfindings_minor: 0\nverdict: EXIT_CONDITION_NOT_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n" "$2" "$2" "$2" "$3" "$3" "$4" > "$1"; }; s() { bash "$V" --series "$d/$1/s-adversarial-pass" 2>&1; }; mkdir -p "$d/a" "$d/b" "$d/c" "$d/k"; p "$d/a/s-adversarial-pass1.md" 1 1 0; p "$d/a/s-adversarial-pass2.md" 2 0 0; p "$d/b/s-adversarial-pass1.md" 1 2 2; p "$d/b/s-adversarial-pass2.md" 2 3 0; p "$d/c/s-adversarial-pass2.md" 2 1 0; p "$d/c/s-adversarial-pass3.md" 3 0 0; p "$d/k/s-adversarial-pass1.md" 1 1 0; p "$d/k/s-adversarial-pass2.md" 2 3 1; A=$(s a); B=$(s b); C=$(s c); K=$(s k); rm -rf "$d"; case "$K" in *"MOVING ARTIFACT"*) ;; *) exit 9 ;; esac; case "$A" in *"MOVING ARTIFACT"*) exit 1 ;; esac; case "$C" in *"MOVING ARTIFACT"*) exit 1 ;; esac; case "$B" in *"MOVING ARTIFACT"*) exit 0 ;; esac; exit 1

## BL-166 — Check 5's stale-entry remedy prescribed a `derive-stories` write that "writes the entry from the story file", and the mode never creates an entry, so on a sprint that skipped planning the prescribed repair was a no-op

**LANDED (v0.503.0, verified 69010ae9).** Merged as PR #630; the release commit names the id
verbatim. `named_absorbed()` lists TWO commits for this id — the release commit and batch 51's
docs commit `7b237e02` (`VERSION` 0.500.0), which named the candidate while REPORTING it — so the
consumer's step 8 must establish the version from the release commit and not from the older
mention.

Filed by the reference consumer as `PC-S308-CHECK-5-DERIVE-STORIES-REMEDY-CANNOT-CREATE-AN-ENTRY`
on 2026-09-04, found while running the `story` gate for a `carry-over-single` sprint whose
envelope carried only the `# populated at stories-test-strategy` placeholder in both canonical
copies. Batch 53 of the ledger drain, batched with `BL-165`. DEFECT.

`core/skills/ai-dlc/steps/gate-validation.md:492-497` told the remediator that the repair for a
stale entry is "a `derive-stories` run that writes the entry from the story file in every
canonical copy". `core/scripts/sprint-status.sh derive-stories` walks entries already parsed
from the envelope (`:1049`) and rewrites the value token of a field the entry already carries
(`:1063-1065`); its own header states as policy that core resolves files FROM the entries and
must not infer which files on disk are stories (`:58-61`). With no entry there is nothing to
write: the consumer ran the prescribed command, got `MATCHED NO STORY FILES (exit 3)`, both
canonical files byte-identical before and after, and hand-transcribed the entries. The sentence
had exactly one copy across `core/`, `templates/`, `scripts/` and `docs/`; `implementation.md`
(`:380-388`, the write's home) already said "rewrites each declared field's value" and is
unchanged. The consumer's own `overrides/steps__gate-validation__check-5.md` inherited the claim
and is the consumer's to correct.

**The filing's option (b), a `--create-missing` mode, is rejected**: it contradicts the header
policy, and a core tool that seeds entries from whatever files it finds decides which files on
disk are stories, which is the consumer's membership rule and not core's.

**The fix has two halves, because either alone leaves the other reachable.** The remedy prose
now says the mode rewrites the VALUES of an entry that already exists and never creates one,
and that a missing entry is written BY HAND from the story file's own frontmatter in each
canonical copy — the story id as a key under `stories:` carrying `status:` (an entry without it
is compared on nothing and exits 4) plus `file:` where the path is not derivable from the key —
because `/bmad-sprint-planning` populates that mapping where it runs and a `carry-over-single`
sprint skips it, and no core step owns it (`stories-test-strategy.md` never names
`sprint-status.yaml`; control, `story` on 74 lines). The transcription is confirmed with
`derive-stories --check`, whose `0 drifted key(s)` means agreement, and NOT with the write, which
overwrote a wrong transcription silently (`4 value(s) written`, exit 0) when the adversarial hand
drove it. And the exit-3 message carries a 143-character clause saying the same thing, keyed on
the PER-VIEW state — it prints only when every derived view is `empty` or `no-block` — so a
list-form mapping (`no-entries`, populated in a shape no reader accepts), a canonical holding
another sprint under `--sprint`, and no canonical on disk all keep today's message, whose remedy
is different; exit code unchanged. The first cut keyed on the bare entry count and printed the
clause on all three; the adversarial hand found it.
`core/fixtures/story-fields-derive` gains the entry-less envelope as an arm (exit 3 from the
WRITE mode, the headline, the clause, both canonicals `cmp -s` before and after), the three
false-clause near-misses with the clause withheld, a one-entry near-miss, a resolving twin, and
prose arms on the gate step (the correction present, the old sentence absent, `0 drifted key(s)`
named, `0 value(s) written` not cited); `story-fields-derive-mutants` gains the clause switched
off (one red), the key reverted to the bare count (exactly the three near-misses red), the
rejected create path (the `cmp -s` arm alone red), and the resolving path forced onto the
zero-entry branch (the twin arm red). Against the pre-fix tool the fixture reports one red;
against the pre-fix prose two; against the first cut the three near-misses and two token arms.

**Receipt limits, stated.** The receipt drives the shipping tool on a synthetic entry-less
envelope and refuses (exit 9) unless it exits 3 with the headline, so a tool that stops exiting
3 is a refusal and not a close. It then requires the clause AND the old sentence gone from the
gate step. A rewording of the clause closes the tool half only if it keeps `NEVER CREATES AN
ENTRY`, which the fixture arm also keys on. A prose fix that restates the wrong promise in other
words ("the derive will lay the entry down for you") passes the receipt and both prose arms —
the negative grep is a literal, and wordings are not enumerated. The consumer's own Check 5
override (`overrides/steps__gate-validation__check-5.md`, shadowing `gate-validation.md#5`
verbatim) still carries the wrong sentence at its line 153 and is read INSTEAD of core by its
remediator, so the prose half does not reach that consumer until it edits the override; the tool
half lands on the pull regardless, which is the reason the fix has two halves.

verify: sh T=core/scripts/sprint-status.sh; G=core/skills/ai-dlc/steps/gate-validation.md; S=core/schemas/sprint-status.json; [ -f "$T" ] && [ -f "$G" ] && [ -f "$S" ] || exit 9; grep -q "derive-stories" "$G" || exit 9; d=$(mktemp -d); mkdir -p "$d/.claude/skills/ai-dlc" "$d/_bmad-output/implementation-artifacts" "$d/_bmad-output/planning-artifacts"; printf "contract_version: 13\nconsumer_story_fields_file: .claude/skills/ai-dlc/story-fields.md\n" > "$d/.claude/skills/ai-dlc/layer-contract.yaml"; printf "sprint: 42\nstatus: in_progress\nstories:\n  # populated at stories-test-strategy. A MAPPING keyed by story id\n" | tee "$d/_bmad-output/implementation-artifacts/sprint-status.yaml" > "$d/_bmad-output/planning-artifacts/sprint-status.yaml"; o=$(AI_DLC_SPRINT_STATUS_SCHEMA="$S" bash "$T" derive-stories --root "$d" 2>&1); rc=$?; rm -rf "$d"; [ "$rc" -eq 3 ] || exit 9; case "$o" in *"MATCHED NO STORY FILES"*) ;; *) exit 9 ;; esac; grep -q "writes the entry from the story file" "$G" && exit 1; case "$o" in *"NEVER CREATES AN ENTRY"*) exit 0 ;; esac; exit 1

## BL-167 — Check 26's validator blocked on every per-check FAIL and read nothing else, so an operator's in-force `SUPPRESSED` entry could cover a lead-evaluated check and never an escalated one

**LANDED (v0.504.0, verified 6fc38a46).** Merged as PR #633; the release commit names the id
verbatim and is the only commit on `origin/main` that does, so `named_absorbed()` lists exactly
it at `0.504.0`.

Filed by the reference consumer as `PC-S308-CHECK26-NO-SUPPRESSED-CARVEOUT` on 2026-09-05, from
its story-308-1 gate 3, which was blocked on it when this batch opened (the consumer's HEAD
commit names the block). Batch 54 of the ledger drain, scoped by this session from its own
ranking on consequence — a live consumer gate with no compliant way past it — and batched with
`BL-168`. DEFECT.

`escalations.md` defines `SUPPRESSED` as an authorization to proceed past a failing check, with
a lifetime, and `gate-validation.md` Check 2 says such an entry does not block while in force.
Every `adjudication: llm` check is adopted only through Check 26, and its validator
(`core/scripts/validate-gate-adjudication.sh`) called `block(1, …)` on any entry of its `fails`
list with no read of `docs/escalations/pending.md` anywhere in the file (one `escalations`
token, an unrelated comment about the remediation guard). So the two subsystems never joined:
the lead's inline checks could be suppressed and the escalated ones — which include every
read-and-compare check an implementation gate runs — could not. Measured on the consumer's real
files, read-only, from its own cwd: a well-formed in-force entry naming `[core] 16`,
`validate-suppression-lifetime.sh` PASS, and the installed validator exiting 1 on `['16']` for
the gate-3 verdict `implementation-20260905T172547Z`. The consumer's first attempt at the
disposition was `DECIDED_AUTONOMOUSLY` carrying the suppression fields, which the lifetime arm
correctly refuses; the corrected `SUPPRESSED` entry then covered nothing at Check 26 either.

**The fix puts the predicate in the script that already owns it.**
`validate-suppression-lifetime.sh` gains `--in-force`, which runs the same record extraction,
the same catalog join and the same `gates_since` count the lifetime arm runs and lists every
suppression that is well-formed, names a catalog check and is within its lifetime — one
tab-separated row per entry (catalog, check id, expires-after, gates elapsed, header), exit 0
whenever the file was read, 2 on a refusal, never 1. The parser now carries the bracketed
catalog as its own field instead of stripping it. `validate-gate-adjudication.sh`, in adjudicate
mode only, asks the sibling for those rows before blocking and treats a FAIL as non-blocking
when a row's (catalog, check id) matches the verdict's own `catalog` field and the id. A row
whose entry wrote no bracket counts as `core` and nothing else: `escalations.md` makes the
bracket mandatory, the sibling's shape arm requires only the id, and the sibling resolves ids
against the core catalog alone, so a bare id can only have named a core check. The adversarial
hand found the first cut let a bare `16` cover an extension check `16` in a catalog the entry
never named — an author error buying wider coverage than the correct spelling — and that is now
a fixture case. A covered FAIL is printed as `SUPPRESSED` with the entry that covers it; the remainder block as
before; the all-PASS line is unchanged when nothing was suppressed. Absence fails closed and
says which absence: no escalations file, no sibling beside the script, or a sibling exit other
than 0 all mean no carve-out. The sibling is named in full at its two call sites so that
**I107** in `scripts/validate-enforcement-map.sh` can join the mode spelled there to the mode
the sibling dispatches and to its USAGE lines, on I53's pattern; the arm was probed in both
directions plus a near-miss under `core/fixtures/`, and the validator's wall clock moved from
25.1s to 25.3s over three reps each.

Driven on the consumer's real gate-3 verdict and `pending.md`, read-only, from the consumer's
cwd with a `cmp -s` control that the two validators differ: installed exits 1 on `['16']`; fixed
prints the `SUPPRESSED` row for `[S308-GATE3-STORY-1]` (expires after 1 gate, 0 recorded since
authorization) and exits 0 with `14 PASS, 1 FAIL under an in-force SUPPRESSED entry`; fixed with
the escalations path pointed at a missing file exits 1 and names `no-escalations-file`. The
in-force query over that file lists exactly one of its 17 `SUPPRESSED` entries against 10
recorded gate timestamps.

**Population, measured over the consumer's whole verdict corpus, read-only.** Of 195 verdict
files (all `catalog: core`), 86 carry a FAIL. Reconstructing `pending.md` and the gate metrics at
the commit nearest each verdict's `generated_at` (323 commits; the metrics file is rotated, so a
second reconstruction from the metrics blob at the same commit was run and selects the same set)
and driving the shipped `--in-force` query: 47 had some in-force suppression at their gate and 11
had one naming a check the verdict failed. Driving both validators on those 11 with the
reconstructed inputs: 6 flip from exit 1 to 0; 5 stay at 1 because a second FAIL in the same
verdict is uncovered, and on every one of the 11 the fixed side prints the `SUPPRESSED` row.
Controls in the same run: four uncovered FAIL verdicts read 1 on both sides with no row, four
all-PASS verdicts read 0 on both, and deleting the live `[S308-GATE3-STORY-1]` entry from a scratch
copy returns the live case to 1. The consumer's gate-log archives record four hand adoptions of a
suppressed Check 16 FAIL across sprints 303 and 304, one stating "the script has no suppression
concept and the licence can only be given effect by the lead's own disposition". Every such gate
proceeded by hand; the fix converts that adoption into a mechanical one and unblocks nothing that
stayed blocked. Of the 17 suppressions the consumer ever filed, 15 name `llm` checks (16, 22, 11)
and 2 name script checks (24, 30) the carve-out cannot reach, correctly.

**A stated limit, pre-existing and not widened here.** The lifetime validator joins
`**Suppresses:**` ids against the core `enforcement-map.yaml` only, so a suppression naming an
extension check (`[extension:<id>] XVH` or the `[ext:<id>]` spelling the consumer's gate metrics
also carry, 62 rows against 8) is refused as "not a check in the catalog" and is never listed in
force. No such suppression exists in the consumer's history, every verdict carries `core`, and
the join here inherits that scope rather than inventing an extension resolver.

**The fixture hand found a fail-open inside the carve-out, closed before the merge.** In the
first cut the query treated a missing gate timeline as zero elapsed, so every well-formed entry
was in force regardless of age from any cwd where the metrics file did not auto-locate, and
again with the metrics path naming a missing file — the same entry the lifetime arm declines to
judge ("expiry NOT-APPLICABLE") was adopted as an authorization. Measured three sides on the
fixture's expired entry: explicit timeline 1, no candidate 0, missing file 0. The query now lists
nothing when no metrics file was found, says so per entry and in its summary
(`gates_recorded=NONE`), and a metrics file that exists and records no gate stays the genuine
fresh-consumer case at 0 elapsed. The caller also skips the query on a verdict carrying no FAIL
token, so an all-PASS gate no longer parses the whole escalations file.

**The lifetime's span is now stated where it is declared.** Measured on the consumer by the
adversarial hand: the newest recorded gate timestamp predates the live gate's nonce and the
entry's authorization, so a lead writes gate-metrics rows AFTER Check 26 runs and the gate being
adjudicated is never in the timeline it is measured against. `gates_since` therefore reads 0 at
the authorizing gate and 1 at the next, and `Expires after: 1` covers both. That is arithmetic
the lifetime arm has always done; this carve-out is the first mechanism that turns the second
gate into passage rather than a warning, so `escalations.md` now says beside the default that an
entry covers the authorizing gate and then `<n>` more. `gates_since` itself is unchanged, because
Check 2's arm shares it. Suppressing a `hard_block: true` check, Check 2 itself included, is
within scope by decision: a bounded operator licence past a red check is what `SUPPRESSED` was
created for, and the entry still needs the operator citation Check 2a verifies.

**Reader set derived, not taken from the filing.** The filing named the validator and the step
prose; the enforcement-map posture for Check 26 and `escalations.md`'s own `SUPPRESSED` section
also described the block as unconditional, and both now say a covered FAIL proceeds and where
the predicate lives. The gate-adjudicator role is unchanged — it still records the FAIL, and the
entry carries the licence, not the verdict. `--series` (the stall rung) still counts a
suppressed FAIL as a FAIL, deliberately: a suppression bounds the licence, not the check.

The receipt seeds a scratch escalated set derived with `--expected`, a verdict failing its first
id, and an in-force entry, then scores: entry naming a different id must block (kills a fix that
lets any entry cover every FAIL), the matching entry must pass with a `SUPPRESSED` line, an
entry two recorded gates past a one-gate lifetime must block (kills a fix that ignores expiry),
and a missing escalations file must block (kills a fix that fails open). Unfixed scores 1, the
id-blind wrong fix scores 1, fixed scores 0.

verify: sh V="${GA:-core/scripts/validate-gate-adjudication.sh}"; S="${GASCHEMA:-core/schemas/gate-adjudication-verdict.json}"; M="${GAMAP:-core/skills/ai-dlc/enforcement-map.yaml}"; [ -f "$V" ] && [ -f "$S" ] && [ -f "$M" ] || exit 9; d=$(mktemp -d); N=implementation-20260101T000000Z; ids=$(AI_DLC_VERDICT_SCHEMA="$S" AI_DLC_ENFORCEMENT_MAP="$M" bash "$V" --expected implementation) || { rm -rf "$d"; exit 9; }; x=$(printf '%s\n' "$ids" | head -1); y=$(printf '%s\n' "$ids" | sed -n 2p); [ -n "$x" ] && [ -n "$y" ] || { rm -rf "$d"; exit 9; }; python3 -c 'import json,sys; o,n,f=sys.argv[1],sys.argv[2],sys.argv[3]; ids=sys.argv[4:]; json.dump({"schema_id":"GATE_ADJUDICATION_VERDICT v1","gate_type":"implementation","gate_series_id":n,"gate_nonce":n,"generated_at":"2026-01-01T00:05:00Z","adjudicator_agent_id":"a1","catalog":"core","verdicts":[{"check_id":c,"verdict":"FAIL" if c==f else "PASS","evidence":"e"} for c in ids]},open(o,"w"))' "$d/$N.verdict.json" "$N" "$x" $ids; e() { printf '## [E] [lead] - 2025-12-31T00:00:00Z\n**Status:** SUPPRESSED\n**Suppresses:** [core] %s — t\n**Expires after:** 1 gate\n**Operator authorization:** 2025-12-31T00:00:00Z | "twelve characters long"\n' "$1" > "$d/p.md"; }; g() { printf '{"v":1,"ts":"%s","catalog":"core","check":"%s","verdict":"FAIL"}\n' "$1" "$x"; }; r() { AI_DLC_VERDICT_SCHEMA="$S" AI_DLC_ENFORCEMENT_MAP="$M" AI_DLC_ESCALATIONS="$d/p.md" AI_DLC_GATE_METRICS="$d/m.jsonl" bash "$V" implementation "$d/$N.verdict.json" >"$d/out" 2>&1; echo $?; }; : > "$d/m.jsonl"; e "$y"; B=$(r); e "$x"; A=$(r); C=$(grep -c SUPPRESSED "$d/out"); g 2026-01-02T00:00:00Z > "$d/m.jsonl"; g 2026-01-03T00:00:00Z >> "$d/m.jsonl"; X=$(r); AI_DLC_ESCALATIONS="$d/none.md" AI_DLC_VERDICT_SCHEMA="$S" AI_DLC_ENFORCEMENT_MAP="$M" bash "$V" implementation "$d/$N.verdict.json" >/dev/null 2>&1; Z=$?; rm -rf "$d"; [ "$B" = 1 ] && [ "$X" = 1 ] && [ "$Z" = 1 ] && [ "$A" = 0 ] && [ "$C" -ge 1 ] && exit 0; exit 1

## BL-168 — Step 0a's snapshot-budget check stopped and asked the operator for `trim`, the one remedy it could apply itself, and the reply forced the same whole read the check exists to defer

**LANDED (v0.504.0, verified 6fc38a46).** Merged as PR #633; the release commit names the id
verbatim and is the only commit on `origin/main` that does, so `named_absorbed()` lists exactly
it at `0.504.0`.

Filed by the reference consumer as `PC-S308-RESUME-SNAPSHOT-BUDGET-ASKS-INSTEAD-OF-AUTO-TRIMMING`
on 2026-09-05, found live in-session on a resume whose snapshot measured 155% of its budget.
Batch 54 of the ledger drain. DEFECT, not NOTE: it is not a wording preference but a stall on
every over-budget resume, and it parks an auto-chained session behind a question whose answer was
never in doubt.

`core/skills/ai-dlc/steps/route.md` Step 0a check 1 ran
`verdict.sh validate-artifact-budget --only pipeline-snapshot.md` and, on non-zero exit,
HARD_BLOCKed with a message inviting a reply of `trim`, `archive` or `abort`. Step 1a runs the
same script over the same artifact on the same exit code and directs the agent to apply the
remedy the script names, singling out `consolidate` alone as supervised — `trim` is gated at
neither site, yet only the resume site waited.

Measured over the reference consumer's session transcripts, non-sidechain assistant records only:
the check-1 question reached the operator on **10 distinct occasions** — 8 emissions of the
verbatim sentence beginning "Reply" and naming the trim, plus 3 `AskUserQuestion` calls carrying
the `Snapshot budget` header, one session emitting both. **Every one of the 10 resolved to
`trim`; `archive` and `abort` were chosen zero times.** One operator reply was not a token at all
but the filing's own remedy in words: *"why do you need me to tell you to trim it? shouldn't that
be a natural first step and only if you're unable to bring it under budget you would need to
escalate to me?"* Control in the same scan: `pipeline-snapshot.md` matched 111 assistant-text
records and 4744 tool-use records, so the scan discriminates rather than merely running. The
breaches were 117%, 147%, 155%, 162% and 215% of a 6000-token budget — none large enough that
reading the file in order to trim it is itself the harm.

The check's own sentence, "This check protects the read that follows it", survives the fix and
was never a reason to ask. An autonomous trim must whole-read the snapshot to find what is
superseded, so it spends that read — but so did the `trim` reply, one round-trip later. The only
answers that ever avoided the read were `archive` and `abort`, and the measured population chose
neither. The fix removes no protection that was being exercised, and it keeps the operator gate
for the case that genuinely needs one: a snapshot still over budget after one mechanical pass,
where `archive` and `abort` stop being equivalent to `trim`.

The fix is confined to check 1. It applies the `trim` remedy autonomously by the mechanics Step
1a's `trim` bullet already gives, cites Rule 25(a) and `gate-validation.md` Check 14 as the owners
of move-never-delete and of the seven-section schema rather than restating either, re-runs the
same verdict, and falls through to the existing HARD_BLOCK — pause flag first, per the paragraph
that opens Step 0a — with `archive`, `abort` and a named manual trim as the remaining options.
The ask-first shape had exactly one copy across `core/`, `templates/`, `scripts/` and `docs/`,
and the fix leaves zero (control: `Step 0a` still matches 34 lines in 10 files across those same
trees). `core/fixtures/resume-whole-read` arms A1-A4 still hold, the verdict invocation being
unchanged and still ahead of the whole read. `enforcement-map.yaml`'s `route.md Step 0a (resume)`
call site keeps `posture: HARD_BLOCK`, which stays true of the fall-through, so the map is
unedited.

The receipt is prose-keyed, because the subject is prose and no program reads it: a rewrite that
re-wraps either asserted sentence across a line break scores STILL-LIVE with the behaviour
correct. That is a stated limit rather than a defect in the receipt — the ask-first arm is the
load-bearing half and it fails closed.

verify: sh f="${ROUTE:-core/skills/ai-dlc/steps/route.md}"; [ -f "$f" ] || exit 9; grep -qF 'to have me trim it to its' "$f" && exit 1; grep -qF 'remedy the script names YOURSELF, without asking' "$f" || exit 1; grep -qF 'one trim pass did not clear it' "$f" || exit 1; exit 0

## BL-169 — the gate-remediation guard derives its lock-out set from raw FAIL verdicts, so a FAIL Check 26 now proceeds past under an in-force suppression still keeps the lead locked out of the artifact corpus until a repair record or an authorization file that no step tells it to write

**LANDED (v0.505.0, verified 288d0e53).** Merged as PR #635; the release commit names the id verbatim.

Distribution-internal, no `PC-` id; NOTE tier — found by the batch-54 adversarial hand while
attacking `BL-167`, and deliberately not fixed there. Adjacent, not the same subject: `BL-167`
joins the suppression to the check that ADOPTS the verdict; this is the hook that reads the same
verdict for a different purpose.

`core/hooks/ai-dlc-gate-remediation-guard.sh:301` builds `FAILED_CHECKS` from every
`.verdict == "FAIL"` in the live verdict and denies the lead's edits to the artifact corpus while
that set is non-empty, lifting only on a repair record or on
`<nonce>.authorization.md` carrying a verified operator quote (`:454`). It reads neither
`docs/escalations/pending.md` nor `validate-suppression-lifetime.sh --in-force`. A suppressed
FAIL is still a recorded FAIL — correctly, since a suppression bounds the licence and not the
check — but no repair is coming for a check the operator has dispositioned, so after `0.504.0`
the gate passes while the lead stays in remediation lockdown, and the only exit is an
authorization file that `gate-validation.md` Check 26 and `escalations.md` never mention beside
`SUPPRESSED`. Measured on the consumer: its story-308-1 gate 3 carries exactly this state.

Shape of the fix: either the guard asks the same `--in-force` query and subtracts covered
checks from `FAILED_CHECKS` (keyed on the verdict's `catalog`, as `BL-167` does), or the
`SUPPRESSED` procedure names the authorization file as the paired step. The first is one call
and one subtraction and is probably right; whichever lands, the guard's own fixture needs a
seeded in-force entry beside a FAIL verdict. Also recorded from the same review, not defects:
`--series` deliberately still counts a suppressed FAIL toward the stall rung, so `Expires after: 3`
across three passes of one gate trips it; and the caller's `refused:` branch may be unreachable
because every sibling exit-2 condition keys on inputs the caller resolved itself.

**Taken in batch 55 of the ledger drain**, batched with `BL-170` under the separability
conditions. The guard now asks the sibling `--in-force` after the guarded-root test, joins its
rows on the verdict's `catalog` with a bare bracket counting as `core` only, subtracts the
covered checks, allows and logs `GATE_REMEDIATION_SUPPRESSED` when nothing remains, and denies
naming both sets otherwise; every absence fails closed with its status in the reason, including
a sibling that predates the mode, and an entry whose operator citation the transcript corpus does
not carry. The sibling costs roughly fifteen times its own small-input control over the consumer's
398582-byte escalations file, so the verified answer is cached at
`_bmad-output/.gate-remediation-in-force`, keyed on the live nonce, a DIGEST of the escalations
file, the size and mtime of the metrics file and the sibling, and a marker recording that the
citations were verified; declared transient. Measured on a read-only copy of the consumer: on its live pass
(`implementation-20260905T172547Z`, one FAIL, `16`, covered by `[S308-GATE3-STORY-1]`) the
installed guard denies and the fixed one allows, against a known-positive pass where both deny.
The receipt drives the shipped seed on five shapes because a single allow shape cannot separate
the catalog-blind, bare-wildcard and fail-open wrong fixes. The two side notes above stand.

verify: sh h=${H:-core/hooks/ai-dlc-gate-remediation-guard.sh}; s=core/fixtures/gate-remediation-deny/seed.sh; [ -f "$h" ] && [ -f "$s" ] || exit 9; a=_bmad-output/planning-artifacts/s302/test-strategy.md; d(){ w=$(bash "$s" "$1") || exit 9; o=$(jq -nc --arg f "$w/$a" --arg t "$w/sessions-jsonl/current.jsonl" '{session_id:"r",tool_name:"Edit",transcript_path:$t,tool_input:{file_path:$f}}' | CLAUDE_PROJECT_DIR="$w" AI_DLC_GATE_METRICS="" bash "$h" 2>/dev/null); g=$(grep -c GATE_REMEDIATION_SUPPRESSED "$w/_bmad-output/pipeline-continuation-log.md" 2>/dev/null) || g=0; rm -rf "$w"; }; d suppressed; [ -z "$o" ] && [ "$g" -gt 0 ] || exit 1; for c in suppressed-forged suppressed-superset suppressed-wrongcat suppressed-bare suppressed-partial suppressed-nosibling; do d "$c"; case "$o" in *'"deny"'*) ;; *) exit 1;; esac; done; exit 0


## BL-170 — Rule 11(a) named no presentation mechanism, so an ambiguity question went out as the last line of a recap and the operator read it as narration; the Stop hook's block reason then steered the lead to the pause flag instead of the tool

**LANDED (v0.505.0, verified 288d0e53).** Merged as PR #635; the release commit names the id verbatim.

Filed by the reference consumer as
`PC-S308-RULE-11-AMBIGUITY-QUESTIONS-HAVE-NO-MANDATED-PRESENTATION-TOOL` on 2026-09-04, from a
live session in which the lead asked a real pending decision ("continue through the remaining
gate-3 checks, or pause given the injection pattern") as trailing prose and ended its turn; the
operator's next message was that no question had been asked. Batch 55 of the ledger drain,
opened by a peer handoff and scoped from this session's own ranking: the only PC-backed unfiled
candidate.

**The defect has two halves, and the filing named one.** `SKILL.md` mandated `AskUserQuestion`
once, for pause point (d) only; Rule 11(a) said ask and named no form. The other half is in
`core/hooks/ai-dlc-continue.sh`: the burial turn ended with the pause flag DOWN, so the hook
took its default block path, whose reason told the lead to create the pause flag if it had no
next action. The lead obeyed, touched the flag, and re-asked in prose. Measured over the
consumer's 247 transcripts (3660 turn-ends, control 138 turns carrying the tool): the
predicate "final non-empty line of the turn's last assistant text contains `?` and the turn
holds no `AskUserQuestion` tool_use" fires 97 times, 84 of them genuine pending questions; 65
fire with the flag up (43 real ambiguity decisions, 7 PVC or retro prompts, 8 session-opening
greetings because the flag persists on disk across sessions, 2 handoff prompts, 5 other) and
32 with the flag down, including the incident's burial turn and 9 more real decisions. An arm
sited in the pause-flag branch alone cannot fire on the case that motivated it. Requiring a
TERMINAL `?` drops 22 real questions to remove one false positive (a `?` inside a regex in a
code span) and is rejected.

**The fix.** Rule 11(a) says put the question with `AskUserQuestion`, recommended option
first, and set no pause flag for it; Rule 3 now names (a) and (d) as the no-flag exceptions
and (b) and (c) as the flag-and-end-turn ones; `route.md` Step 6 cites that. The hook computes
the predicate once, fail-open on any transcript problem, and reads it in two branches: with the
flag up it logs `PAUSE_QUESTION_IN_PROSE` and emits a `systemMessage` for the operator, a
neutral pointer that is true at every pause point (the decision is in the final paragraph;
Rule 11(a) questions use the tool, PVC and retro prompts are prose) with no `decision` key, so
the stop stays allowed; with the flag down it prepends one paragraph to the block reason that
carries both readings (a Rule 11(a) question goes through the tool with no flag; a PVC or retro
prompt sets the flag and ends the turn again) and records `- Question in prose: yes` on the
`BLOCKED` row. A block would wedge (b) and (c), which end the turn with a prose question by
design, so the flag-up branch warns and never blocks. `core/fixtures/pause-question-in-prose`
ships; its `.dist-only` battery kills six mutants including the two wrong fixes (a `?`
anywhere in the text; a tool_use anywhere in the transcript).

**Limits, stated.** The consumer's receipt, `theirs_has core/skills/ai-dlc/SKILL.md "is
solicited with"`, keys on a string the fix deliberately keeps, so it reads STILL-LIVE before and
after and cannot see this close; the receipt below drives the hook instead. The 8 greeting fires
remain: a session opening under a persisted flag that ends "What do you need?" gets the pointer.
`templates/QUICKSTART.md.template` still says three pause points and predates this change. A
turn that asked one question with the tool and buried a second decision in prose is acquitted,
because the predicate counts any `AskUserQuestion` in the turn; a question buried at a join-yield
(Check 2b's live-beat allow) gets no pointer on either branch. The adversarial hand found the
first cut's whitespace test regex-substituting every record's full text, sixteen seconds per Stop
on the consumer's largest transcript and paid before Check 1 on every exit; the predicate is now
one regex per record and is computed only inside the two branches that read it.

verify: sh h=${H:-core/hooks/ai-dlc-continue.sh}; [ -f "$h" ] || exit 9; d=$(mktemp -d); u(){ jq -nc --arg t "$1" '{message:{role:"user",content:$t}}'; }; a(){ jq -nc --arg t "$1" '{message:{role:"assistant",content:[{type:"text",text:$t}]}}'; }; tu(){ jq -nc --arg n "$1" '{message:{role:"assistant",content:[{type:"tool_use",id:"t1",name:$n,input:{}}]}}'; }; tr(){ jq -nc '{message:{role:"user",content:[{type:"tool_result",tool_use_id:"t1",content:"ok"}]}}'; }; Q=$'Checks are green.\n\nContinue the remaining checks, or pause given the pattern?'; { u ask; a "$Q"; } >"$d/q.jsonl"; { u ask; a $'Continue the remaining checks, or pause given the pattern?\n\nContinuing now.'; } >"$d/m.jsonl"; { u ask; tu Bash; tr; a "$Q"; } >"$d/b.jsonl"; { u ask; tu AskUserQuestion; tr; a "$Q"; } >"$d/k.jsonl"; printf '## Pipeline Position\ncurrent_step_file: gate-validation.md\n' >"$d/snap.md"; run(){ p="$d/p$1"; mkdir -p "$p/_bmad-output"; [ "$3" = 1 ] && touch "$p/_bmad-output/pipeline-paused.flag"; [ "$4" = 1 ] && cp "$d/snap.md" "$p/_bmad-output/pipeline-snapshot.md"; jq -nc --arg t "$d/$2" '{transcript_path:$t,session_id:"r"}' | CLAUDE_PROJECT_DIR="$p" bash "$h" 2>/dev/null; }; f1=$(run 1 q.jsonl 1 0); a2=$(run 2 m.jsonl 1 0); f2=$(run 3 q.jsonl 0 1); f3=$(run 4 b.jsonl 1 0); a8=$(run 5 k.jsonl 1 0); rm -rf "$d"; jq -e 'has("systemMessage") and (has("decision")|not)' <<<"$f1" >/dev/null 2>&1 || exit 1; jq -e 'has("systemMessage")' <<<"$a2" >/dev/null 2>&1 && exit 1; jq -e 'has("systemMessage")' <<<"$f3" >/dev/null 2>&1 || exit 1; jq -e 'has("systemMessage")' <<<"$a8" >/dev/null 2>&1 && exit 1; jq -e '.decision=="block" and (.reason|test("AskUserQuestion"))' <<<"$f2" >/dev/null 2>&1 || exit 1; exit 0



## BL-172 — `ledger-reverify.sh` searched a `theirs_*` anchor for its backslashes literally, so a receipt whose backticks were markdown-escaped read "vacuous predicate" on an entry upstream had just fixed

**LANDED (v0.506.0, verified 3e59c856).** Merged as PR #637; the release commit names the id verbatim.

Filed by the reference consumer as `PC-S308-LEDGER-REVERIFY-READS-ESCAPED-BACKTICKS-LITERALLY`
on 2026-09-05, from its `0.502.0 → 0.504.0` pull. Batch 56 of the ledger drain, opened by a
peer handoff and scoped from this session's own ranking: the only PC-backed unfiled candidate,
shipping alone because its subject is a bootstrapping file. DEFECT tier: the wrong verdict is
silent in the direction that keeps an absorbed entry open forever, and its stated reason sends
the operator to re-read the entry body rather than the receipt's spelling.

The consumer's `PC-S308-RESUME-SNAPSHOT-BUDGET-ASKS-INSTEAD-OF-AUTO-TRIMMING` carried a
`theirs_has` receipt on `steps/route.md` whose substring wrapped `trim` in backslash-escaped
backticks, as a markdown author writes them inside prose. The reader stripped the outer quotes
and passed the rest to `grep -F`, so the substring was searched for WITH its backslashes, was at
neither ref, and the entry read `NEEDS-REVIEW  vacuous predicate: … absent at BOTH base and
theirs`. The bare substring was present at base and gone at theirs: the `0.504.0` close the
release commit names as `BL-168`, reported as no close at all. Re-driven here on the consumer's
ledger as it stood before it repaired the receipt (a scratch copy at its `37d7d2aa5`, base
`4dc8d791`, theirs `6fc38a46`, installed reader against this one with a `cmp -s` control that
they differ): 123 rows both sides, no status moved, two details moved, that row and the
`RECEIPTS-UNDECIDED` tally, which counts one fewer `theirs_has` receipt because a refused one is
not a measurement.

The filing offered two readings and asked upstream to choose. **Refuse, do not unescape**,
because the consumer's own archive carries the same spelling meaning the opposite:
`PC-S302-EMIT-REPORT-EMITS-LITERAL-BACKSLASHES-INTO-THE-MECHANICAL-REGION` anchored
`theirs_has` on a shell printf whose backslash-backtick pairs WERE the defect text, and that
receipt closed correctly under the literal reading (its annotation quotes the row). The token
cannot say which the author meant, and a reader that unescaped would have reported that entry
still-live after its fix. The distribution's own `scripts/backlog-reverify.sh` made the same
choice for `has` / `lacks` before this was filed. The false-positive population of an
unescaping reader, derived at `origin/main` before this batch and confirmed by the census hand
with three tools: 78 `core/` files carry a literal backslash-backtick pair, against 494 carrying
a backtick; this batch's fixture adds two more.

The fix: the `theirs_has` / `theirs_lacks` parse site refuses any anchor carrying a backslash
with a `NEEDS-REVIEW` row that names the backslash, says the grammar has no escape mechanism,
and gives the remedy (write backticks and quotes bare; anchor text that genuinely contains a
backslash on a backslash-free neighbour, or write the predicate as `sh`). The whole quoted run
is tested, not its first member. **The path field is held to the same rule**, found by the
batch-56 adversarial hand: a markdown-escaped path resolves at neither ref and falls to the
basename fallback, whose `awk -v` strips the backslash and finds the real file, so the escaped
receipt produced a verdict byte-identical to the correct one — a guess in the direction that
closes live entries, one field over from the guess the anchor guard refuses. The refused
receipt no longer counts toward the `theirs_has` tally. The reader's header and the update
skill's step 3f state the rule. **The stated cost**: the `PC-S302` shape loses its mechanical
receipt and is told to re-anchor. The population, from the batch-56 census hand: seven distinct
backslash-bearing receipts across the consumer's history (six `theirs_has`, one `theirs_lacks`);
two survive today, both in its archive (the closed `PC-S302` one and the regex-shaped
`theirs_lacks`, which the rule now refuses instead of reporting still-live forever), and none
in its live ledger. **A rendering limit, not fixed here**: `emit-report.sh` prints every detail
into an unfenced markdown region, so a rendered refusal row shows the anchor with its backslash
consumed; the sentence beside it still names the backslash, and the raw ledger line is the
operator's source. That is a property of the region, shared by every detail carrying markdown.

The receipt below drives the shipping reader over a two-commit repo and a ten-entry ledger:
the escaped anchor refused with the backslash reason and both remedies, the same text bare
closing, the literal shape refused, the regex shape refused, a two-anchor receipt whose second
anchor carries the backslash refused, an escaped double quote refused, an escaped path refused
with its remedy, the same path bare closing, and an escaped anchor on a path that resolves
nowhere refused for the backslash (the guard sits before path resolution), and an `sh` receipt
carrying a backslash still evaluated. It rejects the pre-fix reader (escaped reads vacuous), an
unescaping reader (escaped closes), a backtick-only or backtick-and-dot guard (regex or quote
passes through), a guard that keeps the literal search when it matches at base (literal
closes), a guard that reads only the first anchor (the two-anchor entry closes), a reader
without the path guard (the escaped path closes), a guard sited after path resolution, a row
without its remedy, and a guard that refuses every verb (the `sh` receipt goes silent — found
by the batch-56 scope hand, which measured that shape silencing fifteen of the consumer's
thirty-six live `sh` receipts).

verify: sh A=$PWD; R=core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; [ -f "$R" ] || exit 9; w=$(mktemp -d) || exit 9; trap 'rm -rf "$w"' EXIT; g() { git -C "$w/d" -c user.email=r@r -c user.name=r -c commit.gpgsign=false "$@"; }; mkdir -p "$w/d/core/x" "$w/c" || exit 9; git -c init.templateDir= -C "$w" init -q d >/dev/null 2>&1 || exit 9; printf '%s\n' '# r' 'Reply `trim` to have me trim it' '_base_ \`%s\`' 'version: 9.9.9' > "$w/d/core/x/r.md"; printf '%s\n' 'TOKEN_AT_BASE' > "$w/d/core/x/r_n.md"; echo 1 > "$w/d/VERSION"; g add -A && g commit -qm base || exit 9; b=$(g rev-parse HEAD); printf '%s\n' '# r' 'trimmed' '_base_ %s' 'version: 9.9.9' > "$w/d/core/x/r.md"; printf '%s\n' 'fixed' > "$w/d/core/x/r_n.md"; g add -A && g commit -qm theirs || exit 9; t=$(g rev-parse HEAD); printf '%s\n' '## PC-ESC — escaped' 'verify: theirs_has core/x/r.md "Reply \`trim\` to have me"' '## PC-BARE — bare' 'verify: theirs_has core/x/r.md "Reply `trim` to have me"' '## PC-LIT — literal' 'verify: theirs_has core/x/r.md "_base_ \`%s\`"' '## PC-RX — regex' 'verify: theirs_lacks core/x/r.md "^version: 9\.9\.9$"' '## PC-SECOND — second anchor escaped' 'verify: theirs_has core/x/r.md "version: 9.9.9" "_base_ \`%s\`"' '## PC-QUOTE — escaped quote' 'verify: theirs_has core/x/r.md "to have \"me\" trim"' '## PC-EPATH — escaped path' 'verify: theirs_has core/x/r\_n.md "TOKEN_AT_BASE"' '## PC-CPATH — clean path' 'verify: theirs_has core/x/r_n.md "TOKEN_AT_BASE"' '## PC-MISS — escaped anchor on a missing path' 'verify: theirs_has core/x/none.md "Reply \`trim\` to"' '## PC-SH — sh with a backslash is still evaluated' 'verify: sh case "a\b" in *\\*) exit 0 ;; *) exit 1 ;; esac' > "$w/l.md"; o=$(cd "$w/c" && bash "$A/$R" "$w/d" "$b" "$w/c" "$t" "$w/l.md" 2>/dev/null); printf '%s\n' "$o" | awk -F'\t' 'function ref(p){return $2 ~ p && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0} function cl(p){return $2 ~ p && $1=="CLOSE-CANDIDATE"} ref("^PC-ESC") && index($3,"Write backticks and quotes bare")>0 && index($3,"verify: sh")>0 {e=1} cl("^PC-BARE"){k=1} ref("^PC-LIT"){l=1} ref("^PC-RX"){x=1} ref("^PC-SECOND"){s=1} ref("^PC-QUOTE"){q=1} ref("^PC-EPATH") && index($3,"Write the path bare")>0 {p=1} cl("^PC-CPATH"){c=1} ref("^PC-MISS"){m=1} $2 ~ /^PC-SH/ && $1=="STILL-LIVE" {h=1} END{exit !(e && k && l && x && s && q && p && c && m && h)}'
