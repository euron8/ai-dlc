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
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

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

Anchored on the glob any fix must name, not on a description of the fix.

verify: has scripts/uninstall.sh "hooks/ai-dlc-"

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

## BL-006 — nothing bounds this ledger's size, and rotation alone does not

`backlog-rotate.sh` moves closed entries to `docs/backlog.archive.md`, but rotation is something
an operator RUNS. Nothing fails a push when this file stops being a queue and becomes a log, so
the bound depends on someone remembering — which is the state that produced the numbers below.

Measured when this ledger was built: `scripts/validate-plan-shape.sh` has **no** size arm at all
(its one `wc -l` resolves a cited line number), and the byte ceiling that does exist — A6 in
`scripts/validate-claude-rules.sh` — covers `CLAUDE.md` and `.claude/rules/` only. With nothing
watching, `docs/plans/retire-graph-consumer-layer.md` reached **384817 bytes** against a
16726-byte median across 23 plans, and no push ever failed over it. The pattern this ledger was
forked from hit the same wall: `core/skills/ai-dlc-update/SKILL.md:1678` records the reference
consumer's push-candidate ledger at 2830 lines / 220 KB / 50 entries, only 39 still classified.

The arm has to name a ceiling AND name this ledger, which is what the receipt joins. Where it
lives is open, with one measured constraint: an arm added to `validate-enforcement-map.sh` is
invoked by the suite pole and costs wall clock there, which is why `validate-plan-shape.sh` and
`validate-claude-rules.sh` are deliberately standalone.

An entry count is likely the better bound than a byte count — the failure being prevented is a
queue nobody can read, not a large file — but a bound that fires is worth more than the right
bound argued about.

verify: sh F=$(git grep -lE "CEILING|MAX_BYTES|MAX_ENTRIES" -- "scripts/*.sh"); test -n "$F" && test -n "$(grep -lF "docs/backlog.md" $F)"

---

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

## BL-005 — `validator-arm-selection` is the pre-push pole, at 166s of a 217s wall

Its shard `b` has a measured floor of ~47.8s solo, set by three serial units: a seeded run at
16s, an attribution sweep at 11s, and a mutant's three parallel full runs at 18s. Going below
it needs either a third directory duplicating the 27s prerequisite, or overlapping the seeded
run with the attribution sweep. Both were measured; neither was taken.

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

## BL-008 — `suite-dispatch-order` asserts an ordering built from wall-clock, and flakes under the pool

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

## BL-009

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

## BL-011

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

## BL-013

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

## BL-014

**The re-adoption dossier renders a multi-line PLAIN scalar `reason:` as its first line only, and
clips a block scalar with no ellipsis.** `fm_block()` at
`core/skills/ai-dlc-update/reconcile/readopt-override.sh:67` enters block mode only on
`/^[|>][0-9]*[-+]?$/`; every other `reason:` value takes `print v; exit` at `:74`. A multi-line PLAIN
scalar therefore reaches the dossier's "WHY THIS OVERRIDE EXISTS" panel as its first line. Separately
the render at `:422` pipes through `head -20` with no ellipsis and no count, so a long reason is
silently truncated.

Measured with the shipping `fm_block()` lifted verbatim, against the reference consumer's override
entries: `steps__retro__ci-gates-enforcement-surface.md` renders **1 line of 35**, and its one
surviving line is a complete sentence that reads as the whole reason — the dangerous direction, since
the operator is looking at a plausible field rather than a blank one.
`team-roles__tea__consumer-drift.md` renders **1 of 18**, cut mid-sentence after a trailing comma.
CONTROLS proving the reader works, same invocation: the three block-scalar reasons read **122**, **93**
and **34** lines. The `head -20` clip then hits all three of those at **20 of 145**, **20 of 169** and
**20 of 37** folded lines, with nothing in the output saying so.

`SKILL.md` step 7's retire / readopt / reaffirm decision turns on exactly this field, which is why the
sibling defect — a bare `|` rendering empty — was already fixed. The plain-scalar case was left
behind by that fix.

**Every figure the filing carried has moved** (it said 1 of 36, 1 of 19, and a clip at 20 of 124 and
20 of 95, over two files rather than three); the numbers above are re-derived and the class is
marginally worse than filed. The mechanism claims are exact at the line level.

Discharges `PC-S299-READOPT-DOSSIER-RENDERS-REASON-EMPTY`. A close of that entry is GATED on this
filing.

Both arms exercise the SHIPPED code — `fm_block()` is lifted verbatim and the render pipeline is
lifted from the line that renders it, so a fix at either site moves the receipt where a restated
pipeline could not. The clip arm deliberately asserts reaching the LAST line or carrying a notice
rather than comparing counts, since a count would be satisfied by raising the limit from 20 to 50
while the silent clip survived at 60. Verified satisfiable: against a copy patched to collect plain
scalars and drop the clip, the identical receipt returns 0.

**Not measured, and stated rather than hidden:** the FULL dossier was not run end to end against a
real override — only the two code paths it composes, which are the entire subject of the claim.

verify: sh S=core/skills/ai-dlc-update/reconcile/readopt-override.sh; eval "$(awk '/^fm_block\(\) \{/,/^\}/' "$S")"; W=$(mktemp -d); printf '%s\n' '---' 'shadows: x' 'reason: first line of a plain scalar,' '  second line,' '  third line.' 'base_sha: dead' '---' > "$W/p.md"; printf '%s\n' '---' 'shadows: x' 'reason: |' '  one' '  two' '  three' 'base_sha: dead' '---' > "$W/b.md"; { printf '%s\n' '---' 'shadows: x' 'reason: |'; i=1; while [ "$i" -le 200 ]; do printf '  L%s\n' "$i"; i=$((i+1)); done; printf '%s\n' 'base_sha: dead' '---'; } > "$W/l.md"; A=$(fm_block "$W/p.md" reason | LC_ALL=C grep -c '' || true); CA=$(fm_block "$W/b.md" reason | LC_ALL=C grep -c '' || true); P=$(LC_ALL=C grep -F 'fm_block "$OVR" reason' "$S" | head -1); P=${P#\$(}; P=${P%)}; OVR="$W/l.md"; R=$(eval "$P"); CB=$(LC_ALL=C grep -c '' <<<"$R" || true); LAST=$(LC_ALL=C grep -c '^  L200$' <<<"$R" || true); NOTE=$(LC_ALL=C grep -vc '^  L[0-9]*$' <<<"$R" || true); rm -rf "$W"; echo "plain=$A block_control=$CA rendered=$CB last=$LAST notice=$NOTE"; [ "$CA" -gt 1 ] && [ "$CB" -gt 0 ] || { echo "HARNESS BROKEN"; exit 2; }; [ "$A" -gt 1 ] && { [ "$LAST" -ge 1 ] || [ "$NOTE" -ge 1 ]; }

## BL-015

**A registered extension entry with zero markdown headings is invisible to the absorption arm, and
the only row it gets says `EXTENSION-OK`.** `layer-drift.sh`'s unnumbered absorption arm harvests its
subject with `ext_titles="$(unnumbered_titles_of_file "$f")"` at
`core/skills/ai-dlc-update/reconcile/layer-drift.sh:1502` and runs only under
`if [ -n "$ext_titles" ]` at `:1503`. `unnumbered_titles_of_file` at `:747` resolves titles from
headings, so an entry whose body carries no markdown heading yields an empty set and the arm never
executes on it. There is no `else`, so nothing is emitted — and the status vocabulary has no member
that could say so: `NOT-CHECKED` appears **0** times in the file, against **21** emit sites carrying
**14** distinct statuses.

Measured on the reference consumer's 38 registered extension entries: **3** carry zero markdown
headings — `roles/pm-domain.md`, `steps-domain/bug-investigation-domain.md`,
`steps-domain/research-requirements-domain.md`. Control: the other **35** carry at least one, and
`checks/gate-validation-push.md` carries **10**.

**The silence is worse than absence**, and this is where the filing understated itself. Running the
shipping `layer-drift.sh` against that consumer, each of the three gets exactly one row and its status
is `EXTENSION-OK` — the sole member of the denylist at
`core/skills/ai-dlc-update/reconcile/emit-report.sh:230`, so it never reaches the report. The operator
sees nothing, and the row behind the nothing reads as checked-and-fine.

**A live instance, found by hand on a file the detector cannot see.** `pm-domain.md`'s own frontmatter
comment records core v0.288.0 adding both of that entry's former bullets to `team-roles/pm.md`
near-verbatim. That is exactly the retirement case the absorption arm exists to find.

Discharges `PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS`, whose headline claim — the
arm being gated behind the `ext_anchors` guard — is already fixed: the arm at `:1502` is a separate
`if` and the weaker status does reach the report. These 3 are the residue. A close of that entry is
GATED on this filing.

**The satisfiability evidence is a DIFFERENTIAL, not a killed mutant, and that is a real gap.** An
attempt to patch `unnumbered_titles_of_file`'s empty case collapsed the classifier from 3 rows to 1
and tripped the receipt's own `HARNESS BROKEN` guard — the guard works, but no green mutant was
obtained. What stands instead: `WITHHEADING` — identical body text, identical `hooks:` target,
identical absorbed section, same invocation — earns `EXTENSION-RETIRE-CANDIDATE`, so the target state
is demonstrably emittable by the shipping code for this exact body and only the harvester's blindness
separates the two entries. **Close this gap with a killed mutant before treating the receipt as
mutation-tested.** The receipt's predicate also had to exclude `EXTENSION-HOOK-DRIFT`: a first version
returned 0 because the synthetic entry picked up that unrelated arm's row, which the three real
entries do not get — found only by running it.

verify: sh D=core/skills/ai-dlc-update/reconcile/layer-drift.sh; R=$(mktemp -d); DI="$R/d"; CO="$R/c"; mkdir -p "$DI/core/skills/ai-dlc/steps" "$DI/core/schemas" "$CO/.claude/skills/ai-dlc/extensions"; cp core/schemas/layer-adjudication-register.json "$DI/core/schemas/" || { echo "HARNESS BROKEN: schema"; exit 2; }; printf '%s\n' '<!-- CORE_MANIFEST v1 -->' 'machinery:' '  - core-manifest.md' 'rulebook:' '  - steps/*.md' > "$DI/core/skills/ai-dlc/core-manifest.md"; printf 'contract_version: 16\n' > "$DI/core/skills/ai-dlc/layer-contract.yaml"; printf '%s\n' '# Widget' '' '### 3. Pre-existing Widget Check.' '' 'Core has carried this for releases.' > "$DI/core/skills/ai-dlc/steps/widget.md"; git -C "$DI" init -q >/dev/null 2>&1; git -C "$DI" add -A >/dev/null 2>&1; git -C "$DI" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1; B=$(git -C "$DI" rev-parse --short HEAD); printf '%s\n' '' '### 9. Absorbed Widget Check.' '' 'Core adopted this on this pull.' >> "$DI/core/skills/ai-dlc/steps/widget.md"; git -C "$DI" add -A >/dev/null 2>&1; git -C "$DI" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1; T=$(git -C "$DI" rev-parse --short HEAD); E="$CO/.claude/skills/ai-dlc/extensions"; for n in HEADINGLESS WITHHEADING; do printf '%s\n' '---' 'kind: step-domain' 'hooks: steps/widget.md' "id: $n" 'push_candidate: false' 'conforms_to: 16' '---' '' > "$E/$n.md"; done; printf '%s\n' '- **Absorbed Widget Check (consumer copy).** The body core has since taken, carried as a bare bullet with no heading.' >> "$E/HEADINGLESS.md"; printf '%s\n' '### 9. Absorbed Widget Check.' '' 'The same body, under a heading.' >> "$E/WITHHEADING.md"; O=$(bash "$D" "$DI" "$B" "$T" "$CO" 2>/dev/null); N=$(LC_ALL=C grep -c '' <<<"$O" || true); SU=$(LC_ALL=C awk -F'\t' '$2 ~ /HEADINGLESS/ && $1 != "EXTENSION-OK" && $1 != "EXTENSION-HOOK-DRIFT"' <<<"$O" | LC_ALL=C grep -c '' || true); CT=$(LC_ALL=C awk -F'\t' '$2 ~ /WITHHEADING/ && $1 == "EXTENSION-RETIRE-CANDIDATE"' <<<"$O" | LC_ALL=C grep -c '' || true); NA=$(LC_ALL=C grep -c HEADINGLESS <<<"$O" || true); rm -rf "$R"; echo "rows=$N headingless_named=$NA headingless_absorption_rows=$SU control_withheading_retire_rows=$CT"; [ "$N" -gt 0 ] && [ "$CT" -ge 1 ] || { echo "HARNESS BROKEN: the absorption arm did not fire on the with-heading control"; exit 2; }; [ "$SU" -ge 1 ]

## BL-016

**Nothing derives a retired PATH from the base→theirs diff, so a layer file citing one is claimed by
no detector.** `retired-layer-contract.sh` does derive its retired set from the base→theirs core
rulebook, but its vocabulary is two shapes and neither is a path: `shapes_of()` at
`core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh:81-87` extracts labelled directives and
`tokens_of()` at `:88-90` extracts `{<token>}` placeholders. A path retired between the two refs
changes neither set, so `RETIRED` at `:131` is empty and the run takes the early exit at `:141`,
reporting that the release "retired NO contract shape ... so NO layer file was opened".

The only other candidate is W11 / LC-R4 at `core/scripts/validate-layer-entries.sh:1560`, which closes
the headline instance and cannot generalise: its arm 2 at `:1731` is hard-coded to the story corpus,
and every W11 candidate path must begin with one of four scan roots declared in
`core/skills/ai-dlc/artifact-path-grammar.md` — `_bmad-output`, `docs/retro`, `docs/reviews`,
`docs/escalations` — alternated into `LC_ALT` at `:1687`. A core path retired outside those four and
cited in a consumer layer file is a candidate for neither mechanism.

Measured behaviourally, both arms in one invocation, on a synthetic dist repo and a consumer extension:
retiring only the PATH produced **0** `RETIRED-LAYER-CONTRACT` rows with the note "retired NO contract
shape (2 at base, 2 at theirs)"; retiring a labelled DIRECTIVE the same layer file also cites produced
**1** row on that same file. Same harness, same layer file — the detector fires, and the vocabulary is
what excludes paths.

The header's "WHAT IT DOES NOT CATCH, STATED PLAINLY" at `:47-51` names an invented shape and a prose
paraphrase, and the run-time limit at `:129` names prose restatements. **Neither tells the operator
that a retired path is outside the vocabulary, so this zero reads as covered** — an additional defect
at the same site, folded in here.

Discharges `PC-S314-NO-DETECTOR-CLAIMS-A-LAYER-FILE-CITING-A-PATH-THE-PULL-JUST-RETIRED`. A close of
that entry is GATED on this filing — W11 arm 2 closes its headline instance and not this sub-claim.

Behavioural rather than a grep: the receipt drives the real detector twice over one seeded tree and the
directive arm is the control in the same invocation, so a harness that stopped exercising the detector
returns 0 rows for BOTH arms and reports STILL-LIVE rather than closing. **A fix landing in W11 instead
of in this detector would also read STILL-LIVE; re-point the receipt if that is the shape chosen.**

verify: sh D=$(mktemp -d); mkdir -p "$D/dist/core/skills/ai-dlc" "$D/cons/.claude/skills/ai-dlc/extensions"; S="$D/dist/core/skills/ai-dlc/SKILL.md"; R="$D/dist"; git -C "$R" init -q; git -C "$R" config user.email a@b; git -C "$R" config user.name a; printf -- "- Model: \140/opus\n- Effort: \140/high\nStories: _bmad-output/planning-artifacts/stories/\n" > "$S"; git -C "$R" add -A; git -C "$R" commit -qm b; C1=$(git -C "$R" rev-parse HEAD); printf -- "- Model: \140/opus\n- Effort: \140/high\nStories: _bmad-output/planning-artifacts/s<N>/stories/\n" > "$S"; git -C "$R" commit -qam p; C2=$(git -C "$R" rev-parse HEAD); git -C "$R" checkout -q -b d "$C1"; printf -- "- Model: \140/opus\nStories: _bmad-output/planning-artifacts/stories/\n" > "$S"; git -C "$R" commit -qam d; C3=$(git -C "$R" rev-parse HEAD); printf -- "- Effort: \140/high\n_bmad-output/planning-artifacts/stories/\n" > "$D/cons/.claude/skills/ai-dlc/extensions/x.md"; V=core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh; P=$(bash "$V" "$R" "$C1" "$C2" "$D/cons" 2>/dev/null | grep -c "^RETIRED-LAYER-CONTRACT"); K=$(bash "$V" "$R" "$C1" "$C3" "$D/cons" 2>/dev/null | grep -c "^RETIRED-LAYER-CONTRACT"); rm -rf "$D"; [ "$K" -ge 1 ] && [ "$P" -ge 1 ]

## BL-017

**The shipped schema still names the blocking row as the only source of `subject_digest`.**
`core/schemas/layer-adjudication-register.json:29` describes `subject_digest` as "Copied verbatim from
the blocking row", and `:5` says `reconcile/layer-drift.sh` "prints the digest in the blocking row, so
the operator copies a value rather than deriving one". Recording a verdict is what stops the row
blocking, so once any verdict exists for the current subject state the message carrying the key is
never emitted again — exactly the case of adding an `owed` object to a verdict already recorded
without one.

`SKILL.md`'s half of that instruction was repaired: `core/skills/ai-dlc-update/SKILL.md:1271` sends the
operator to `layer-drift.sh --list-adjudications`. The schema's half was not. Measured with a control
in the same invocation: `grep -c list-adjudications` on the schema = **0**; `grep -c 'blocking row'` on
the same file = **3**.

The asymmetry is what makes it a defect rather than a duplicate. `scripts/install.sh:601-604` copies
every `core/schemas/*.json` to `.claude/schemas/`, so the artifact a consumer opens while writing a
register record is the unrepaired half, and the repaired half is in a file they are not reading at that
moment.

Discharges `PC-S319-SUBJECT-DIGEST-IS-UNREADABLE-ONCE-ITS-OWN-ROW-STOPS-BLOCKING`. A close of that
entry is GATED on this filing — the entry names two carriers and only one was repaired.

Anchored on the flag name a fix cannot omit. JSON carries no comments, so the token cannot land in a
note recording the change while the description stays wrong: any occurrence is inside a description
string, which IS the text a consumer reads. `subject_digest` is the read control — it survives any
repair, so a receipt that stops finding it has failed to read the file rather than found the fix. Shown
able to fire: the same predicate exits 0 against `SKILL.md`.

verify: sh f=core/schemas/layer-adjudication-register.json; [ "$(grep -c subject_digest "$f")" -ge 1 ] || exit 1; grep -qF -e "--list-adjudications" "$f"

## BL-018

**`hard-blockers.sh` discards `CORE-AT-THEIRS` and prints `0 HARD blockers.`** `collect()` at
`core/skills/ai-dlc-update/reconcile/hard-blockers.sh:96-101` filters both detectors' rows to
`$1 ~ /^HARD-/`. `CORE-AT-THEIRS`, emitted by `unregistered-drift.sh:347`, does not survive that
filter, so a run whose only finding is that row prints the literal `0 HARD blockers.` at `:110` and
nothing else.

That row is the documented tell for a stale base. `SKILL.md:1189` says so in as many words:
"`CORE-AT-THEIRS` rows are the tell that the base was stale." This wrapper is the caller that most
needs it and the only one that discards it.

**The same wrapper already solved this exact class for the other non-`HARD-` status.**
`DRIFT-RANGE-DEGENERATE` is read out separately at `:95`, and the header at `:86-93` states the failure
mode verbatim — "the `^HARD-` filter below is the only reader this wrapper has, so the one caller that
most needs that warning was the one caller that discarded it". Same wrapper, same filter, same class,
one half done.

Measured behaviourally on a copy of the wrapper beside a stub `unregistered-drift.sh` — the wrapper
resolves its detectors from `$0`'s directory at `:70-72`. A stub emitting one `CORE-AT-THEIRS` row
produced `0 HARD blockers.` with no mention of the row; a stub emitting one `HARD-PROBE` row through
the identical harness produced the listed row.

Discharges `PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD`. A close of that entry is GATED on this
filing — `--post-apply` exists and closes the headline; the asymmetry argument does not close with it.

Behavioural, and it stubs the detector deliberately: the subject is the wrapper's filter, not which
base a detector was handed, so the receipt depends on no consumer tree and no ref pair that will move.
The `HARD-PROBE` arm is the control in the same invocation.

verify: sh D=$(mktemp -d); mkdir -p "$D/bin"; cp core/skills/ai-dlc-update/reconcile/hard-blockers.sh "$D/bin/"; printf "#!/bin/bash\nprintf \"%%s\\\\tcore/x.md\\\\tdetail\\\\n\" \"\$ROW\"\n" > "$D/bin/unregistered-drift.sh"; A=$(ROW=CORE-AT-THEIRS bash "$D/bin/hard-blockers.sh" "$D" HEAD "$D" HEAD 2>&1); B=$(ROW=HARD-PROBE bash "$D/bin/hard-blockers.sh" "$D" HEAD "$D" HEAD 2>&1); rm -rf "$D"; [ "$(grep -cF HARD-PROBE <<<"$B")" -ge 1 ] || exit 1; [ "$(grep -cF CORE-AT-THEIRS <<<"$A")" -ge 1 ]

## BL-019

**`effort_bound` records the config rather than the dispatch, and nothing reads it.**
`core/hooks/ai-dlc-dispatch-guard.sh:329` writes `effort_bound` into the spawn ledger from
`--arg effort "${PIN_EFFORT:-}"` at `:318`. `PIN_EFFORT` is the value read out of settings at
`:228-238`; whether the guard actually appends an effort line is decided at `:355-380`, and the guard
returns without appending anything at `:384`. The write sits above the decision it purports to record,
so the field carries the CONFIG on every dispatch the guard leaves untouched — including those exiting
at `:335` for an unreadable role file, recorded before the guard can know whether it will correct
anything.

Nothing reads it. Measured with a control in the same invocation over `core/*`: files naming
`effort_bound` other than the writer = **0**; files naming `model_bound` other than the writer = **6**
(`validate-spawn-ledger.sh`, `check-22-spawn-ledger/run.sh`, `dispatch-model-guard/run.sh`,
`subagent-probe/run.sh`, `enforcement-map.yaml`, `gate-validation.md`). Same search, same corpus, one
field has readers and the other has none.

**`CHANGELOG.md:562-563` concedes the field and discharges nothing.** It reads: "`effort_bound` still
records what the guard appended and is still read by nothing; that is a separate filing and is not
addressed here." Two grounds, both measured. **The separate filing does not exist** — `effort_bound`
occurs at exactly one line across the consumer's ledger and archive, and that line is inside the entry
being deferred; in ai-dlc it appears only in the CHANGELOG, the writer, two plan files and a verdicts
TSV, and nowhere in this backlog until now. **And the concession misdescribes what it concedes**: the
field does not record what the guard appended, it records what was CONFIGURED, which is the sub-claim
itself. This entry is the filing that pointer named.

Discharges `PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND-THAT-RESOLVES-TO-NOTHING`. A close of that
entry is GATED on this filing — its headline is fixed at `:369` and fixture-guarded.

The receipt takes either fix: it exits 0 when the field is gone from the hook, or when the write sits
below the effort decision AND at least one file under `core/` reads it. `model_bound` is the control,
so a search that has stopped working reports STILL-LIVE rather than closing. **A fix that moves the
write and leaves it unread still reports STILL-LIVE, deliberately** — a ledger field nobody reads is
the other half of the claim.

verify: sh H=core/hooks/ai-dlc-dispatch-guard.sh; C=$(git grep -l "model_bound" -- "core/*" | grep -vxF "$H" | wc -l | tr -d " "); [ "$C" -ge 1 ] || exit 1; LW=$(grep -n "effort_bound:" "$H" | head -1 | cut -d: -f1); [ -z "$LW" ] && exit 0; LD=$(grep -n "^NEEDS_EFFORT=false" "$H" | head -1 | cut -d: -f1); W=$(git grep -l "effort_bound" -- "core/*" | grep -vxF "$H" | wc -l | tr -d " "); [ "$LW" -gt "$LD" ] && [ "$W" -ge 1 ]

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
