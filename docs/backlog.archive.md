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

