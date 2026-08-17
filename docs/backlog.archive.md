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

