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
