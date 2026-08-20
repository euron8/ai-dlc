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

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:184-186` reads **exit 0 as "the fix
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

## BL-021

**The rare-event ceiling for probabilistic passive-monitor carry-overs has no counterpart
anywhere in core, and it is one of only two blocks left in the row that names it.** Measured
over `core/` at HEAD with a control in the same invocation: files containing `rare_event` = **0**,
files containing `staleness ceiling` = **0**, files containing `validation_intensity` = **12**.
The consumer block is `extensions/checks/gate-validation-push.md:25-37` (`PI-S259-3`), and its
operative clause — a carry-over whose monitored event is rare-and-maybe-never carries
`rare_event: true`, and its ceiling fires a DISPOSITION-REVIEW rather than a health escalation —
is the part core cannot express: `core/skills/ai-dlc/steps/carry-over-evaluation.md` contains
neither `staleness` nor `ceiling` (0 hits, same invocation as the 12-hit control above).

**The row is wrong about three of the six blocks it names, in two directions.** It names
`2s, 3a, 7, 14, 18, 21`. The live file carries five `CHECK_LOADED` ids — `902s, 903a, 914, 918,
921` — and **no block 7**: `non-vacuous` occurs nowhere in `extensions/checks/gate-validation-push.md`,
its two consumer-side hits being `gate-validation-domain.md:552` and
`overrides/steps__gate-validation__check-5.md:9`, neither of which is this file. **Block 21 is
already absorbed and core says so in its own text** — `core/skills/ai-dlc/steps/gate-validation.md:1268-1271`
reads "**Graph→distribution number mapping.** This is graph's Check 21 (validation-intensity)
absorbed as distribution **Check 20**", and core's Check 20 at `:1244-1250` already carries the
extension's whole innovation, that the minimum is READ from Rule 8's table and "this check
deliberately does not restate it". **Block 3a is absorbed away from the gate**: `degenerate-but-type-valid`
lives in `core/skills/ai-dlc/steps/stories-test-strategy.md`, `core/team-roles/qa.md` and
`core/team-roles/code-reviewer.md`, and `Protective-direction` in `qa.md` — but core's Check 3a
at `:347-390` is coverage-only ("identify which acceptance criterion covers it"), so the
discrimination requirement exists in the authoring step and has no gate that enforces it. The
correction is narrowing on 21, 7 and the bulk of 3a, and it leaves 902s plus 3a's SUT-pointer
sub-clause (`_call_real_`, 0 hits in `core/`) as the residue. Block 14's two fields exist in core
(`core/skills/ai-dlc/steps/retro.md`, `core/skills/ai-dlc/enforcement-map.yaml`,
`core/schemas/gate-adjudication-verdict.json`) but not where the block puts them: `hard_block` is
0 hits inside core's Check 14 region, lines 760-931, where `Context Reminders` hits twice at
`:839` and `:855`. Block 18 is consumer-scoped by construction (`server/test_*.py`,
`rebalancer/tests/**`) and is not pushable.

The anchor is `rare_event` because it is the token the absorbed rule cannot be written without —
it is the literal frontmatter key the carry-over must carry — and because the looser candidates
false-close: `staleness` and `ceiling` are ordinary English, and an anchor on the extension's
prose ("disposition review, not health escalation") is a phrasing the filing invented rather than
one core uses. The control is `validation_intensity`, chosen because it is the token of the block
in the SAME row that core DID absorb, so a control hit proves the search reaches the exact file
where an absorption of this class lands.

Discharges the consumer entry `extensions/checks/gate-validation-push.md` at pinned ledger
line 226. That row carries no `PC-` id and no receipt, so nothing re-derives it; the three
corrections above are the reason it survived two drains.


verify: sh grep -qF 'validation_intensity' core/skills/ai-dlc/steps/gate-validation.md || exit 1; grep -rqF 'rare_event' core/
## BL-022

**Fix-Forward Cluster Accounting is absent from core's deploy-validate step entirely, and the
deferral triple the same row names is already core's — only its PVC siting is not.** Measured
over `core/skills/ai-dlc/steps/deploy-validate.md` with a control in the same invocation,
matching lines, case-insensitive: `fix-forward` = **0**, `cascade` = **0**, `EFFORT-BLOCKER` = **0**,
`Post-smoke` = **0**, `smoke` = **27**. Core-wide by file, `cluster count`, `Cluster Accounting`,
`cascade-depth` and `cascade depth` each match **0 files** while `smoke test` matches **15**, same
invocation. The
consumer block is `extensions/steps-domain/deploy-validate-push.md:107-233` — a cascade-depth
threshold on fix-forward PRs, a pre-dispatch fetch mandate, stack-trace-first ordering, and
three named exclusions from the cluster count (pre-merge `PI-S169-4`, pipeline-infrastructure,
operator-directed revert).

**The row misdescribes the second of its three items, narrowing it.** It names
"deferral-justification triple (`PI-S272-1`)" as the push candidate. The triple is already in
core: `core/skills/ai-dlc/steps/retro.md:410` is "**Deferral-justification triple (MANDATORY).**"
and `:419` defines `EFFORT-BLOCKER` as one of its three slots. The extension's own body at
`deploy-validate-push.md:91` cites it as "(retro.md §4a)" — it never claimed to own the triple.
What is unabsorbed is the APPLICATION SITE: that the triple must be attached before the PVC lists
any item as deferred, and that the operator catching a vacuous deferral at the PVC is a Rule-3
lead-conduct violation. Core's `deploy-validate.md` mentions deferrals only as
`DEFERRAL_REQUEST` counts to approve at `:300` and `:318`, with no justification precondition.
**The row is also wrong about its own scope in the widening direction**: it names three items
where the file carries thirteen bold sub-blocks, omitting root-cause-before-disposition (HARD),
verify-tool discharge invocation-fidelity (HARD), the sprint-scope failure cross-check and the
LR-closure traceback. Its parenthetical "sprint-boundary trip" resolves to two incidental prose
uses at `:132` and `:150`, not to a named clause.

The anchor is `fix-forward` scoped to `core/skills/ai-dlc/steps/deploy-validate.md`, because
cluster accounting sited at the PVC cannot be written into that step without the term. A
core-wide anchor was measured and rejected in the same invocation: `grep -rqF 'fix-forward' core/`
exits **0 today**, satisfied by `core/team-roles/code-reviewer.md` and
`core/skills/ai-dlc/steps/gate-validation.md`, so it would report this entry closed the moment
anyone looked. If a future absorption sites the rule in `gate-validation.md` instead, the receipt
must be repointed rather than read as still-live — that is the one failure mode this anchor buys
its tightness with.

Discharges the consumer entry `extensions/steps-domain/deploy-validate-push.md` at pinned ledger
line 252.


verify: sh grep -qF 'smoke' core/skills/ai-dlc/steps/deploy-validate.md || exit 1; grep -qF 'fix-forward' core/skills/ai-dlc/steps/deploy-validate.md
## BL-023

**Core creates the retro branch off the current HEAD, not off `origin/main`, and the
consumer-proved fix for that is the only clean survivor of a row whose named file no longer
exists.** `core/skills/ai-dlc/steps/retro.md:18-22` emits `git checkout -b ai-dlc/retro/sprint-<N>`
with no base argument. The consumer block
`extensions/steps-domain/retro-push-branch-creation.md:11-19` emits
`git fetch origin main` then `git checkout -b ai-dlc/retro/sprint-<N> origin/main`, on the measured
ground that branching from the sprint lineage after a squash-merged sprint PR "guarantees
artificial conflicts on every shared pipeline artifact at retro-PR time". Measured over `core/`
with a control in the same invocation: `Create Retro Branch` = **0 files**, `Validator Contract
Pre-Flight` = **0**, `terminality` = **0**, against `Sprint-Ship Verification` = **3** and
`audit-rule-files` = **4**. The block also carries a fail-fast branch-name self-check and a
`reset --hard` branch-guard (`PI-S271-6`), neither of which core has.

**The row is stale in three separate ways and this is the most decayed entry in the batch.**
(1) **The file it names does not exist.** `extensions/steps-domain/retro-push.md` is absent from
the live consumer tree; it survives only under `.claude/worktrees/agent-a93b52245ff8bbb65/`. It was
split into six `retro-push-*.md` files carrying `extends:` anchors, plus `retro-deferral-expiry.md`,
which is now `push_candidate: false`. Per the brief's own rule a stale path form is a REPOINT, not
a close. (2) **Two of the seven blocks it names are absorbed**, one of them recorded in the
extension's own body: `retro-push-process-improvements.md:11` says "**Absorbed upstream at
`v0.41.0` (dist 6c5830a)** … '## Empirical gate validation'", and core carries it at
`core/skills/ai-dlc/steps/retro.md:335`; "skill-invocation-provenance" is core's Check 17 at
`core/skills/ai-dlc/steps/gate-validation.md:1039`. (3) **Two more are misdescribed.** The
"Sprint-Ship dual-counter" is core's — `retro.md:706` and `:728` carry both counters and the
EITHER-reaches-5/5 rule, and the extension's own header says so; the residue is an `NFR-S176-1`
template prefix. "audit-rule-files finding-classes" is not pushable at all: core owns
`core/scripts/audit-rule-files.sh` and the Rule 18 classes, and the extension body ends **"Do not
re-merge the exercise audit back into core's copy: that would re-fork a file upstream maintains,
which is the exact condition this split resolved."** That clause is a refusal, and the ledger row
proposes exactly what it forbids. **And the row omits a live push candidate it never named** —
`retro-push-party-mode.md`, `push_candidate: true`, carrying the `PI-S194-1` topology mandate and
guarded-merge merge-time enforcement. Four of seven named rows wrong, one live row missing, path
dead: the correction moves in both directions at once.

The anchor is the base ref inside core's own command, and the control is the same string without
it. `ai-dlc/retro/sprint-<N>` matches core today — that is the measured false-close: an anchor on
the branch NAME reports this closed right now, because core already writes the name and only the
base is missing. Appending ` origin/main` makes the anchor a token the fix cannot be written
without, since the fix IS the base argument. Both arms run in one invocation, so a receipt that
cannot see the file fails on the control rather than reporting a green absence.

Discharges the consumer entry `extensions/steps-domain/retro-push.md` at pinned ledger line 255.
The row should additionally be repointed to the six live `retro-push-*.md` files before any
future push-mine reads it.


verify: sh grep -qF 'ai-dlc/retro/sprint-<N>' core/skills/ai-dlc/steps/retro.md || exit 1; grep -qF 'ai-dlc/retro/sprint-<N> origin/main' core/skills/ai-dlc/steps/retro.md
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
## BL-029

**`classify-block.md`'s `domain-local` bucket routes a block to "keep ours" without ever asking
whether core text DEPENDS on the machinery being kept local, so consumer-local machinery that a
core gate presupposes is never flagged for push.** Measured at
`core/skills/ai-dlc-update/reconcile/classify-block.md:36-39`: the bullet's entire action is
`keep ours; note any non-conflicting upstream additions to layer around it` — extracting that
bullet alone (terminating on the next `^- **`, not on a blank line, because the bullets are not
blank-separated) and grepping it case-insensitively for `push` returns **0 hits**. Control in the
same invocation, same extractor: `un-pushed-innovation` returns a hit and `consumer-only-in-block`
returns a hit (its action reads `and judge domain-local vs innovation for the push flag`), while
`conflict` correctly returns none, and a nonexistent bucket name exits 3 rather than passing
silently. So the extractor discriminates in both directions and the zero is a finding.

The consequence is measurable in core today. `core/scripts/validate-artifact-budget.sh:1048` still
emits `rotate -> a rotation was MISSED`, and `core/skills/ai-dlc/steps/retro.md:702,896,965`
carries the `7a-post` rotation step that satisfies it — a step core acquired only at v0.121.0,
having shipped the accusing breach message since v0.45.0. For that whole span the reference
consumer held the rotation as `domain-local` and core held a gate whose passing condition it did
not define. The classifier is the one place that decision is taken, and it has no field in which
the dependency could have been recorded: the return schema at `:93-96` carries exactly `id`,
`bucket`, `action`, `needs_operator_confirmation`, `note`.

The filing is wrong in one direction, narrower than it claims. It asserts the buckets are the only
per-block signal ("a block is not a single claim; the classifier's buckets are assigned per
block"). Since it was written, `needs_operator_confirmation` shipped as an explicitly orthogonal
second axis (`:69-81`, "A block can have an obvious, mechanical bucket … and STILL require a human
decision"), so the general complaint that one bucket carries the whole disposition is now false.
What survives is the specific gap: `needs_operator_confirmation` is a human-attention flag and
carries no push flag, so it cannot re-home an unrelated push axis. The filing also asserts "there
is no detector for 'core references a step it does not define'". That still holds against the
upstream-side class — `core/scripts/validate-ci-gates.sh` is a dormant-gate detector, but its
subject is CI gates declared in a retro with no enforcer match, not core prose depending on
machinery core lacks.

The anchor is the `domain-local` bullet's own body rather than the return schema, because a schema
field-count predicate false-closes on any unrelated sixth field, and because a fix in any shape has
to route this bucket to a push decision and cannot write that routing without naming push — the
same token the two buckets that already route to push both use. A whole-file grep for `push` is
satisfied by `un-pushed-innovation` four lines below, which is why the predicate is scoped to one
bullet; that exact false GREEN was produced and discarded while drafting this receipt.

Discharges the consumer entry `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS` at pinned ledger line 860.


verify: sh bash -c 'c=core/skills/ai-dlc-update/reconcile/classify-block.md; b=$(LC_ALL=C awk "/^- [*][*]domain-local[*][*]/{f=1;print;next} f&&/^- [*][*]/{exit} f&&/^## /{exit} f" "$c"); [ -n "$b" ] || exit 3; grep -qi push <<< "$b"'
## BL-030

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

Discharges the consumer entry `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` at pinned
ledger line 1977.


verify: sh bash -c 'a=core/skills/ai-dlc-update/reconcile/apply.sh; w=$(LC_ALL=C grep -c "say WORKLIST" "$a"); m=$(LC_ALL=C grep -cE "^[^#]*mech_fail=" "$a"); [ "$w" -gt 0 ] && [ "$m" -gt 0 ] || exit 3; n=$(LC_ALL=C grep -n "say DECISION restamp-withheld" "$a" | head -1 | cut -d: -f1); [ -n "$n" ] || exit 3; g=$(sed -n "$((n-1))p" "$a"); LC_ALL=C grep -qE "[&][&]|[|][|]" <<< "$g" && exit 0; LC_ALL=C grep -qiE "^[^#]*worklist[a-z_]*=" "$a" && exit 0; exit 1'
## BL-033

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

Discharges the consumer entry
`PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPSTREAM-ONLY-SO-THE-SELF-UPDATE-CANNOT-TERMINATE`
at pinned ledger line 3018.


verify: sh D=$(mktemp -d); P=core/skills/ai-dlc-update/reconcile/preclassify.sh; export GIT_AUTHOR_NAME=p GIT_AUTHOR_EMAIL=p@p GIT_COMMITTER_NAME=p GIT_COMMITTER_EMAIL=p@p; mkdir -p "$D/d/core/rules" "$D/c/.claude/rules"; git -C "$D/d" init -q; printf "body\n" > "$D/d/core/rules/modeonly.sh"; printf "old\n" > "$D/d/core/rules/content.sh"; chmod 644 "$D/d/core/rules/modeonly.sh" "$D/d/core/rules/content.sh"; git -C "$D/d" add -A >/dev/null; git -C "$D/d" commit -qm base >/dev/null; B=$(git -C "$D/d" rev-parse HEAD); chmod 755 "$D/d/core/rules/modeonly.sh"; printf "new\n" > "$D/d/core/rules/content.sh"; git -C "$D/d" add -A >/dev/null; git -C "$D/d" commit -qm theirs >/dev/null; T=$(git -C "$D/d" rev-parse HEAD); printf "body\n" > "$D/c/.claude/rules/modeonly.sh"; chmod 755 "$D/c/.claude/rules/modeonly.sh"; printf "new\n" > "$D/c/.claude/rules/content.sh"; O=$(bash "$P" "$D/d" "$B" "$T" "$D/c" 2>&1); rm -rf "$D"; CTRL=$(LC_ALL=C awk -F"\t" "\$2 ~ /content/{print \$4}" <<<"$O"); ARM=$(LC_ALL=C awk -F"\t" "\$2 ~ /modeonly/{print \$4}" <<<"$O"); [ "$CTRL" = ALREADY-AT-THEIRS ] || exit 1; [ "$ARM" = ALREADY-AT-THEIRS ]
## BL-034

**The `reconcile-mechanical` region that `SKILL.md` calls "every mechanical finding, complete, from
every detector" omits FOUR mandated detectors, not three.** Measured over
`core/skills/ai-dlc-update/reconcile/emit-report.sh`, counting `SELF/<name>` invocations, with the
sibling control in the same invocation:

```
SELF/retired-layer-contract.sh   0   <- SKILL.md:450  step 3a-iii
SELF/retired-layer-passage.sh    0   <- SKILL.md:463  step 3a-iv
SELF/retired-fixtures.sh         0   <- SKILL.md:480  step 3a-v
--templates                      0   <- SKILL.md:499  step 3b
SELF/retired-tokens.sh           3   <- CONTROL: step 3a-ii, and it IS wired in
```

The control is what makes the zeros mean something: a sibling detector from the same step group is
invoked three times, so detectors living outside the region is an omission and not a convention.
`emit-report.sh` invokes exactly seven — `preclassify.sh:73`, `retired-tokens.sh:158`,
`hard-blockers.sh:222`, `unregistered-drift.sh:226`, `layer-drift.sh:230`,
`relabel-extension-checks.sh:237`, `ledger-reverify.sh:251`.

**The filing said three and it is four — the correction is WIDER.** It named 3a-iii and "3a-iv
`retired-fixtures.sh`". `retired-fixtures.sh` is step 3a-**v** today; step 3a-iv is
`retired-layer-passage.sh`, a detector inserted into the mandated list after the filing and never
wired into the region either. The gap is not stable — it grew by one while the entry sat open, which
is the argument for binding the join rather than re-counting it.

**And the filing's one explicitly unverified sub-claim holds, also wider.** It said "NOT verified:
whether `hard-blockers.sh` picks [a `HARD-` row from `retired-fixtures.sh`] up by some other route."
It does not: `hard-blockers.sh:71-72` collects from exactly two detectors, `unregistered-drift.sh`
and `layer-drift.sh`. So `HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE`, emitted at
`retired-fixtures.sh:57` and `:69`, reaches neither the rendered region nor the blocker wrapper —
a `HARD-`-prefixed status with no reader anywhere, against a step 7 that binds `apply` to "any
status whose name begins `HARD-`", matched "on the PREFIX, not on a list of names you remember".

`SKILL.md:851` still carries the completeness claim verbatim, and gives the reason in the same
breath: "a mechanical finding narrated by you is a finding you can drop, and one already was (a HARD
core-schema drift, twice)." Because `--verify` re-derives and byte-matches only what the region
renders, a dropped `RETIRED-FIXTURE-ORPHAN`, `RETIRED-LAYER-CONTRACT`, `RETIRED-LAYER-PASSAGE` or
`TEMPLATE-PROSE-MERGE` leaves a report that passes the step-7 gate and reports itself complete.

The receipt skips comment lines, and that narrowing is measured rather than assumed. Seeded a copy
of `emit-report.sh` with a two-line comment recording the three detector names and the flag as
"wired in": a naive whole-file `grep -cF` returns **1 for each of the three** and would close the
entry on a file where nothing was wired; this receipt returns exit 1. Both copies were asserted
byte-different from the original before their outputs were read. Verified satisfiable: a copy with
the four invocations actually added exits 0. What it would MISS, carried forward from the consumer
entry's own note: a fix that renders the four from a DIFFERENT driver and leaves `emit-report.sh`
untouched — re-anchor on the new driver rather than declaring it unfixed.

Discharges the consumer entry `PC-S315-EMIT-REPORT-REGION-OMITS-THREE-MANDATED-DETECTORS` at pinned
ledger line 3088. The name undercounts by one; the entry is the wider finding.


verify: sh E=core/skills/ai-dlc-update/reconcile/emit-report.sh; c() { LC_ALL=C awk -v p="$1" '/^[[:space:]]*#/{next} index($0,p){n++} END{exit !(n>0)}' "$E"; }; c "SELF/retired-tokens.sh" || exit 1; N=0; for d in retired-layer-contract.sh retired-layer-passage.sh retired-fixtures.sh; do c "SELF/$d" || N=$((N+1)); done; c "--templates" || N=$((N+1)); [ "$N" -eq 0 ]
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
`SKILL.md:1062-1068` then binds the reader: "Do every step of that subject in the printed order and
commit them together. Do not reorder them, do not land one without the others."

**The correction is narrower than the filing, in one specific way: the co-emission is deliberate,
and the defect is that the reason never reaches the manifest.** `apply.sh:444-448` already
contemplates the both-case in as many words — "an entry can be both … and in that case the readopt
is work whose result is an entry that still freezes its shadowed span." So the filing's "nothing
marking them as ALTERNATIVES" is true of the ROWS and false of the SOURCE: the author knew the
readopt's outcome is futile under a supersession and recorded it in a comment no operator reads.
That moves this from "two detectors are unaware of each other" to "a known interaction is
documented only on the emitting side", which is a smaller claim and a different fix. Everything
else in the filing reproduces unchanged, including the exact three-row shape it quotes.

The filing chose `verify: manual` on the grounds that any anchor would guess at unwritten prose.
That is avoidable: the anchor is behavioural, drives the real `apply.sh`, and keys on a string
`apply.sh:583` emits TODAY rather than one describing a fix. It closes on either remedy the filing
asks for, which is why it is not a guess — measured against two separate mutated copies, each
asserted byte-different from the original before it was read: suppressing the retire sequence while
a readopt is outstanding gave exit **0**, and replacing the "Same commit as the row(s) above."
phrasing gave exit **0**. Against the tree today: exit **1**. The readopt row is the control arm —
a change that emits nothing at all fails the receipt rather than closing it. **Known limit:** a fix
that adds an exclusivity marker while keeping both the retire rows and that phrasing leaves this
receipt reporting still-open; the filing asks for the phrasing to be dropped in that case, so the
receipt is aligned with what was asked, not with every conceivable fix.

Discharges the consumer entry
`PC-S331-APPLY-SH-CO-EMITS-READOPT-AND-RETIRE-FOR-ONE-SUBJECT-AS-IF-BOTH-WERE-OWED` at pinned
ledger line 4258.


verify: sh R=core/skills/ai-dlc-update/reconcile; W=$(mktemp -d); O='.claude/skills/ai-dlc/overrides/steps__w__probe.md'; for r in dist cons; do mkdir -p "$W/$r"; git -C "$W/$r" init -q .; echo seed > "$W/$r/f"; git -C "$W/$r" add -A >/dev/null 2>&1; git -C "$W/$r" -c user.email=f@x -c user.name=f commit -qm seed >/dev/null 2>&1; done; mkdir -p "$W/rec"; cp "$R"/*.sh "$W/rec"/; printf '#!/usr/bin/env bash\nADJ_ROW_TOKEN="adjudicated"\nprintf %s\n' "'HARD-OVERRIDE-DRIFT-SECTION\t$O\tsteps/w.md\tthe shadowed section changed upstream\nOVERRIDE-SUPERSEDED\t$O\tsteps/w.md\treplaces_with=AI_DLC_PROBE_KEY :: core provides what this entry was written to work around.\n'" > "$W/rec/layer-drift.sh"; chmod +x "$W/rec/layer-drift.sh"; M=$(bash "$W/rec/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null); rm -rf "$W"; n() { LC_ALL=C awk -F'\t' -v o="$O" -v k="$1" '$1=="WORKLIST" && $2==k && $3==o' <<<"$M" | LC_ALL=C grep -c . ; }; RE=$(n override-readopt); RT=$(n override-retire); SC=$(LC_ALL=C awk -F'\t' -v o="$O" '$1=="WORKLIST" && $2=="override-retire" && $3==o' <<<"$M" | LC_ALL=C grep -cF 'Same commit as the row(s) above.'); [ "$RE" -ge 1 ] || exit 1; ! { [ "$RT" -ge 1 ] && [ "$SC" -ge 1 ]; }
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
## BL-039

**Two core steps make a red check unsatisfiable by any action available to the lead, and neither
offers the escalation branch core uses for exactly this state twelve hundred lines earlier.**
`core/skills/ai-dlc/steps/retro.md:839` (Step 5c check 3) reads "MUST exit 0. If it fails, fix the
issues before proceeding to Step 6." `core/skills/ai-dlc/steps/deploy-validate.md:165-173` reads
"**Smoke tests MUST pass.** ... 5. Repeat until all smoke tests pass. A deployment with failing
smoke tests is a broken deployment. Do not present it to the human for validation." Measured over
each span: `escalat*` = 0, `Rule 12` = 0, `HARD_BLOCK` = 0, `disposition` = 0, `operator` = 0 —
**ten zeros, all five in both spans.** Controls in the same invocation: `smoke` = 5 in the
deploy-validate span, `check` = 3 in the retro span, so both extractions read real text.

**Core already ships the pattern the filing calls novel, for a different subject.**
`core/skills/ai-dlc/steps/retro.md:448-459` — "**Locked-requirement deferral needs recorded
operator disposition.**" — requires a HARD_BLOCK with an explicit operator disposition on record
(approved-deferral / do-now / descope) per Rule 13 + Rule 12 Tier 1, and surfaces it at the PVC
"so the governance fact that a locked requirement slipped its lock is visible and signed off". It
carries its own Rule 26(c) minimum-mechanism block. Same file, same failure shape, applied to
requirements and never extended to checks.

**The filing's prescribed fix is foreclosed upstream, in writing, and must not be transcribed.**
It proposes "a gate outcome distinct from PASS and FAIL — a BLOCKED-BY-RECORDED-DISPOSITION state".
`core/schemas/gate-adjudication-verdict.json:112-113` closes that vocabulary at two values and
states why in the field's own doc: `"enum": ["PASS", "FAIL"]`, "PASS or FAIL. There is no third
value and no empty value. A check you cannot evaluate is FAIL-with-reason, never omitted and never
PASS-by-default." That schema is the single source the readers load and `sync-taught-schema.sh --check`
byte-matches its rendered example, so a third value is not an omission to fill. The literal token
`BLOCKED-BY-RECORDED-DISPOSITION` occurs **0** times in `core/` (control: `HARD_BLOCK` in 58 files)
— a receipt anchored on it, as the filing's shape invites, would have reported STILL-LIVE forever.
**Narrower** than filed on the remedy: the check stays FAIL and the escalation carries the
disposition, which needs no new outcome. **Wider** than filed on the defect: `retro.md` Step 5c
carries three absolute `MUST exit 0` mandates (`:828`, `:839`, `:845`), not the one the filing
names, and the entry it absorbs (`PC-S295-RETRO-DEPLOY-VALIDATE-S3-DEADLOCK`) is the second site of
the same shape rather than a separate item.

The anchor is `operator disposition` — the phrase core itself uses for this state at `retro.md:448`
— scoped to each of the two spans, never file-wide, because file-wide is satisfied by the
locked-requirement passage that is already there and would false-close on day one. The run control
is `recorded operator disposition` in `retro.md` (2 occurrences today): if that vocabulary is ever
removed the receipt reports STILL-LIVE rather than closing on a broken search. Each span also
closes if its absolute sentence simply disappears, so a fix that replaces the wording with any
vocabulary at all still closes. All four arms — vocabulary added, sentence removed, in both files —
were driven on seeded copies asserted to differ from the source, and all returned 0.

Discharges the consumer entry `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED` (absorbing
`PC-S295-RETRO-DEPLOY-VALIDATE-S3-DEADLOCK`) at pinned ledger line 436. Both source `theirs_has`
predicates are subsumed: each is the `-cF` arm of its half.


verify: sh R=core/skills/ai-dlc/steps/retro.md; D=core/skills/ai-dlc/steps/deploy-validate.md; [ "$(grep -ci "recorded operator disposition" "$R")" -ge 1 ] || exit 1; DS=$(sed -n '/^\*\*Smoke tests MUST pass\.\*\*/,/^### 3b\./p' "$D"); RS=$(sed -n '/^3\. \*\*Mandatory rules validation\.\*\*/,/^4\. \*\*Audit-anchor/p' "$R"); [ -n "$DS" ] && [ -n "$RS" ] || exit 1; DR=$(grep -ci "operator disposition" <<<"$DS"); DL=$(grep -cF "Repeat until all smoke tests pass." <<<"$DS"); RR=$(grep -ci "operator disposition" <<<"$RS"); RL=$(grep -cF "MUST exit 0. If it fails, fix the issues" <<<"$RS"); { [ "$DR" -ge 1 ] || [ "$DL" -eq 0 ]; } && { [ "$RR" -ge 1 ] || [ "$RL" -eq 0 ]; }
## BL-040

**Check 5's whole span consults no record produced by a process other than the one it is
auditing, and the check's own text says the resulting pass is reachable.** Measured over the
66-line `CHECK_LOADED: 5` → `CHECK_LOADED: 6` span of
`core/skills/ai-dlc/steps/gate-validation.md:456-521`: occurrences of `gate-log` **inside the
span = 0**; controls in the same invocation — `sprint-status.yaml` inside the span = **4**, and
`gate-log` elsewhere in the same file = **11** (Checks 12, 16, 18, 22 and 25, the last of which
machine-reads `steering_violations:` out of the previous gate-log entry at `:1668`). The token is
live in the file and absent from this check. The mechanical half agrees:
`core/scripts/sprint-status.sh` names `gate-log` **0** times against a control of **66**
occurrences of `sprint-status` in the same file.

`gate-validation.md:481-483` states the failure in the check's own words — running
`derive-stories` when the story file's own `status:` is wrong "would copy the wrong status into
every canonical copy and this check would then pass." Core documents the vacuous pass and answers
it with a warning to the human, not with a comparand.

**The filing's cause is wrong in the narrowing direction and the headline is too wide.** It filed
"two hand-maintained records compared to each other," and Check 5 is no longer hand-run: `:463`
dispatches `scripts/ai-dlc/sprint-status.sh check-stories` and `:485` adds
`derive-stories --check`, both with exit-code contracts, and `:498-505` adds a non-vacuity
sub-clause that makes exit 4 a FAIL. So "the check cannot fail" is false — it fails on exit 1
whenever the two copies disagree, and it now fails on an empty corpus. What survives, and what is
sharper than filed, is that the two comparands are not independent: the declared repair at
`:473-476` regenerates the `sprint-status.yaml` entry *from* the story file, so the check joins a
record to a derivation of that record. It detects staleness of the copy and cannot detect a status
that is wrong at the source — which is the S295 state the entry reproduces, three stories reading
`review` in the story file and in both canonicals while merged and gate-3 passed.

The anchor is the gate log because that is the only record in this pipeline written by a different
actor at a different time, and four other checks in the same file already machine-read it, so the
fix is reachable rather than architectural. A looser anchor — `gate-log` anywhere in
`gate-validation.md` — false-closes today, on Check 12's rotation prose, which is why the receipt
extracts the span first. The receipt's first arm exits **2** rather than 1 when the span comes
back without `sprint-status.yaml`, which is the renumber-or-removal case: a vanished span would
otherwise make an empty `grep` look like a live defect forever.

Any implementation must scope its own predicate to the `CHECK_LOADED: 5` span for the same reason,
and must add the comparand as check text, carrying no origin note or version tag —
`core/scripts/audit-rule-files.sh` scopes `steps/` (`:374`) and tiers both as blocking.

Discharges the consumer entry `PC-S295-RETRO-CHECK5-SELF-REFERENTIAL` at pinned ledger line 510.


verify: sh S=$(LC_ALL=C awk '/CHECK_LOADED: 5 /,/CHECK_LOADED: 6 /' core/skills/ai-dlc/steps/gate-validation.md); grep -q 'sprint-status\.yaml' <<<"$S" || exit 2; grep -q 'gate-log\.md' <<<"$S"
## BL-041

**The one sprint-ship counter that refuses to grandfather a smoke FAIL is rendered non-binding by
the disjunction that reads both counters.** `core/skills/ai-dlc/steps/retro.md:710-713` defines
`consecutive-deploy-clean` as resetting "on ANY smoke FAIL, regardless of whether the FAIL is new
or pre-existing — strictest counter; reflects ship-quality without grandfathering." `:728-729`
then reads them: "A sprint is ship-quality when **EITHER** counter reaches 5/5." A FAIL carried
across a sprint boundary holds `consecutive-deploy-clean` at 0 permanently while
`consecutive-no-regression` climbs to 5/5, and the sprint is declared ship-quality with the FAIL
live. The strict counter cannot decide anything it does not already share with the loose one.

The renewal loop the entry filed is stated mechanically rather than left as an omission:
`:716-717` resets `consecutive-no-regression` "ONLY on a NEW smoke FAIL not present in the prior
deploy-validate run" — so "new" is defined by comparison against the previous run's record, and
nothing re-derives it against the artifact that set the original threshold. Measured across
`core/skills/`: `pre-existing` occurs 10 times, of which exactly **3** are in the pipeline steps
and all three are `retro.md:712`, `:715`, `:718`; the other 7 are in `ai-dlc-update/reconcile/*`
and are unrelated. Control in the same invocation: `pre-exxisting` = **0**, and `grandfather` = 1
(`retro.md:713`), so the search ran and discriminates.

**The filing named the wrong absence, and the correction moves the fix target.** It filed that
"nothing requires a red check carried across a sprint boundary to be re-justified," which reads as
a missing rule to be added. There is no missing rule — the non-grandfathering requirement already
exists at `:710-713`, fully written. The defect is that `:729` makes it optional. That is a
different and much cheaper fix than the one the entry sketched, and it moves the change from
"add a filing obligation" to "the disjunction at `:729`."

The anchor is `EITHER counter reaches 5/5` because a fix cannot leave that clause standing and
still bind the strict counter — every satisfying change either replaces the disjunction or
qualifies it, and both edit that line. The usual quote-back hazard (a fix that documents what it
removed, leaving the anchor alive in a comment) is suppressed here by a second mechanism rather
than by hope: `retro.md` is in `core/scripts/audit-rule-files.sh`'s `IN_SCOPE` at `:374`, and an
origin note in step prose is a tier-1 blocking finding there, so the removal record has nowhere in
this file to live. The receipt's first arm exits **2** if the Sprint-Ship Verification section
stops naming `consecutive-no-regression` at all, separating a restructure from a live defect.

Discharges the consumer entry `PC-S295-RETRO-RED-SMOKE-CROSSING-SPRINT-BOUNDARY` at pinned ledger
line 577.


verify: sh S=$(LC_ALL=C awk '/^### Sprint-Ship Verification/,/^### 5\. Human Commentary/' core/skills/ai-dlc/steps/retro.md); grep -q 'consecutive-no-regression' <<<"$S" || exit 2; ! grep -q 'EITHER counter reaches 5/5' <<<"$S"
## BL-042

**Check 17's PRD arm reads the provenance block out of an artifact the invocation it pins is
forbidden to write.** `core/skills/ai-dlc/steps/gate-validation.md:1076-1079` runs
`validate-provenance-block.sh _bmad-output/planning-artifacts/prd.md --require-skill bmad-prd`,
and `:1080` states the derivation for that pin: "`research-requirements.md` §3 invokes `/bmad-prd`
with the **validate** intent, so that is the name a correct run stamps." Rule 20 sites the block
at `core/skills/ai-dlc/SKILL.md:767-768` — "Every invocation MUST emit a
`SKILL_INVOCATION_PROVENANCE v1` block into **the artifact it produces**." The artifact §3
produces is not the PRD: `core/skills/ai-dlc/steps/research-requirements.md:110-114` says the
validate intent "always writes both `validation-report.html` and `validation-report.md` into the
run folder," and the same passage forbids the other exit outright — "this call must not re-author
the PRD." A run that obeys Rule 20 puts the block where Check 17 does not look, and a run that
satisfies Check 17 natively has violated `:110`. Hand-carrying the block into `prd.md` is the only
remaining exit, which is the workaround the consumer entry reproduces.

Measured: `validation-report` occurs **0** times in the whole of `gate-validation.md`, and **1**
time in `research-requirements.md` — control `require-skill` = **3** inside the 90-line
`CHECK_LOADED: 17` → `18` span, so the span extraction and the search both ran. The artifact Rule
20 designates as the block's home is named by the step that produces it and by no gate check.

**The filing understated the scope by one project-type axis.** It filed a text-level disagreement
between Check 17's PRD arm and Rule 20's placement clause. The arm is in fact correct for exactly
one branch and unsatisfiable for the rest: `research-requirements.md:80-81` invokes `/bmad-prd` to
author `prd.md` only for greenfield/brownfield-b, where the produced artifact genuinely is the
PRD; `:82-92` routes feature/brownfield-a/c through a hand UPDATE with no `/bmad-prd` invocation
at all, leaving §3's validate call as the only `bmad-prd` run in the sprint. So on every
feature and brownfield-a/c sprint the arm has no legal way to pass. The correction is wider, and
it identifies the missing thing as a branch rather than a wording conflict.

The anchor is `validation-report` inside the span because that is the path the block legally
lands on, so no repoint or added branch can be written without naming it — unlike `prd.md`, which
a correct greenfield branch must keep and which would therefore report the entry live after a real
fix. It also survives the quote-back hazard: a fix documenting the old single-target arm would have
to name `prd.md`, not the report. The receipt exits **2** if the span stops naming `require-skill`,
which is the check-renumbered case. The one satisfying fix this anchor would miss is the mirror
direction — amending §3 to carry the block into `prd.md` — and that branch is closed by `:110`
and by the sub-skill's own headless contract, which writes the report regardless of finding count.

Note for whoever implements it: the fix is a second arm in the check, not a note beside the
existing one. `steps/` is in `core/scripts/audit-rule-files.sh`'s `IN_SCOPE` (`:374`), so the
branch must be written as check text with no version tag and no account of the fork it replaced.

Discharges the consumer entry
`PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLACEMENT` at pinned ledger line 1165.


verify: sh S=$(LC_ALL=C awk '/CHECK_LOADED: 17 /,/CHECK_LOADED: 18 /' core/skills/ai-dlc/steps/gate-validation.md); grep -q 'require-skill' <<<"$S" || exit 2; grep -q 'validation-report' <<<"$S"
## BL-043

**`_gate-procedures.md` owns the bounded-join beat, restates its whole contract, and never says
the beat is backgrounded.** The token `run_in_background` occurs **once** in that file's 41,657
bytes — at `core/skills/ai-dlc/steps/_gate-procedures.md:149`, inside the Gate-adjudication
*dispatch* section, about the `Agent` spawn. The **Bounded-join beat** section at `:91-132` is 41
lines that prescribe the call form (`:101`), both exit codes, why a waiting beat exits 0, the
mtime rule, `--since`, wave batching, and four named prohibitions — and not the one property that
makes a beat a beat. Measured in one invocation over the two slices: Gate-adjudication dispatch =
30 lines, `run_in_background` count **1**; Bounded-join beat = 41 lines, count **0**. Control that
the grep works on that file at all: `wait-for-deliverable` = **5** hits.

That section calls itself "the ONLY sanctioned way to wait for a teammate" (`:94`), and three
sites delegate to it by name — `:158` (gate-adjudicator), `:269` (adversarial review), `:431`
(adversarial repair) — each reading `**Join** with the bounded-join beat (above)`. So the omission
is inherited by every join the gate procedures describe.

A foreground beat is not a slow beat, it is a **dead** one. `core/hooks/ai-dlc-continue.sh:568`
enumerates four ways to believe you have a beat and not have one, and names this as (2): "a
foreground call — its exit trap clears the marker before your turn ends". The same block prescribes
the literal form the beat section omits: `Bash(run_in_background: true)
scripts/ai-dlc/wait-for-deliverable.sh <path> [<path>...]`. `core/scripts/wait-for-deliverable.sh:31`
states the design premise the section drops — "This beat is BACKGROUNDED".

**The filing this discharges named the wrong two sections and prescribed a fix that is now a
restatement.** It asked for one line in "Adversarial review dispatch" and "Adversarial repair
dispatch" mandating backgrounded-plus-bounded-join. The bounded-join half has since landed in both
(`:269`, `:431`), and the backgrounded half of a *dispatch* is now SKILL.md Rule 29's global default
— `SKILL.md:1550`, "`run_in_background: true` is now the DEFAULT for every spawn, not an exception"
— so writing it into two step-file sections would restate a default rather than fix anything. The
correction is **narrower in cause and wider in reach**: the missing property is on the *beat*, not
the dispatch, and it is missing at the one site all three joins share.

The anchor is the beat section's own text because that is where the duty is sited: the three callers
delegate, so a fix at any one of them fixes one join out of three. The control arm is the
Gate-adjudication dispatch slice — a section-slicer or a grep that has stopped working reports
STILL-LIVE rather than closing, which is the safe direction. `run_in_background` is a token the fix
cannot be written without: it is the harness parameter, spelled that way at all 12 core files that
name it, so this cannot be an anchor on a phrasing the filing invented.

**The receipt takes the additive fix** — the mandate written into the beat section. A subtraction fix
that deleted the restated call spec in favour of a bare Rule 29 citation would leave this reporting
STILL-LIVE and needs the receipt re-anchored; that is stated rather than papered over, and the
additive fix is the one the file's own shape invites, since `:149` already spells the token for the
neighbouring dispatch.

Discharges the consumer entry `PC-S297-GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND` at pinned
ledger line 1361. **That entry's own receipt is a live false-close** and must not be reused:
`theirs_has core/skills/ai-dlc/steps/_gate-procedures.md "Execute the sub-skills back-to-back, with
no pause for human input between them:"` — that string is present today at `:190`, in the Validation
cycle section, and has nothing to do with backgrounding. `theirs_has` closes on presence, so the
entry evaluates as a CLOSE-CANDIDATE on a string whose presence is unrelated to the defect.


verify: sh P=core/skills/ai-dlc/steps/_gate-procedures.md; S(){ LC_ALL=C awk -v h="$1" 'index($0,h)==1{f=1;next} f&&/^## /{exit} f' "$P"; }; C=$(S "## Gate-adjudication dispatch"); [ "$(grep -cF run_in_background <<<"$C")" -ge 1 ] || exit 1; B=$(S "## Bounded-join beat"); [ "$(grep -cF run_in_background <<<"$B")" -ge 1 ]
## BL-044

**The code-review verdict set has an owner and a reader and no invariant, and core already ships a
non-member.** `core/team-roles/code-reviewer.md:80` declares `APPROVED | NEEDS_REWORK | BLOCKED` and
repeats `NEEDS_REWORK` at `:317`, `:334`, `:371`, `:398`, `:498`, `:549`.
`core/skills/ai-dlc/steps/gate-validation.md:181-195` is its reader: Check 1 grep-sources the verdict
from the review file's own verdict line, fails on zero matches, and fails on two matches carrying
different values — it validates the SHAPE of the answer and never its MEMBERSHIP. Nothing else reads
the set. Measured with a control in the same invocation over `scripts/ core/scripts/ core/fixtures/`:
files naming `NEEDS_REWORK` = **0**; files naming `CORE-AT-THEIRS` = **3**. Repo-wide,
`NEEDS_REWORK` occurs in exactly **2** files — `CHANGELOG.md` and its own owner. It appears in no row
of `docs/vocabulary-index.md`, whose 7 cross-file rows include one (`validation intensities`) owned by
a resident prose file, so a prose-declared set is squarely in that table's scope.

**The repo has already conceded this in writing and built nothing.** `CHANGELOG.md:16723-16729`
records `code-reviewer.md` carrying THREE verdict sets at once — `APPROVED | CHANGES REQUESTED |
BLOCKED`, `APPROVED | APPROVED-WITH-FIXES | CHANGES-REQUIRED`, and `APPROVED | NEEDS_REWORK` — and
resolves them by hand with the reason stated verbatim: "No script or gate check keys on any of them,
so the set was free to choose." The set was unified; the binding that would keep it unified was not
added, and the drift is documented as having already happened once.

The fourth spelling survived that pass, because it was not in the file the pass edited.
`CHANGES-REQUESTED` occurs exactly **once** in all of `core/` — `gate-validation.md:188` — inside the
cautionary sentence teaching the lead to read verdicts from disk, presented as the value a review file
on disk actually held. A resident step file therefore shows an agent a verdict token the only declared
set does not contain, in the one paragraph about verdict values.

**The filing got its stated mechanism wrong in the collapsing direction.** It claimed core "mandates
`NEEDS_REWORK` in one file and `CHANGES-REQUESTED` in another at the same sha", with the consequence
that "a reviewer following the role file emits a verdict the gate step does not name". Today only one
file mandates anything: `gate-validation.md` names no verdict set at all, its Check 1 reads whatever
value it finds, and its `CHANGES-REQUESTED` is a narrative example rather than a mandate. The
two-mandates cause is dead. What survives is one level down and wider — the set is unbound, which is
precisely why a non-member could sit in its reader unnoticed.

The anchor is `docs/vocabulary-index.md` and not a grep over prose, because that file is GENERATED —
rendered by `scripts/render-vocabulary-index.sh` from `# vocabulary:` arm markers and byte-compared at
pre-push. It cannot be satisfied by a comment, by a mention, or by a hand edit, which is the failure
mode a whole-file `grep -qF` has. The control in the same invocation is `EXIT_CONDITION_MET`, a member
already rendered into that file: a missing or unreadable index reports STILL-LIVE rather than closing.

The receipt reaches 0 when an arm binding the set is added and the index re-rendered. **A fix that only
retires `CHANGES-REQUESTED` from `gate-validation.md:188` still reports STILL-LIVE, deliberately** —
removing today's non-member leaves the set as free to choose as the CHANGELOG found it.

Discharges the consumer entry `PC-S299-UPSTREAM-SHIPS-TWO-REVIEW-VERDICT-VOCABULARIES` at pinned ledger
line 1571.


verify: sh grep -qF "EXIT_CONDITION_MET" docs/vocabulary-index.md || exit 1; grep -qF "NEEDS_REWORK" docs/vocabulary-index.md
## BL-045

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
## BL-047

**A Pipeline Position carrying two `Current step file` values makes `ai-dlc-recover.sh` mandate
one step file while its own excerpt displays the other, in the same emitted block.** Driven
against the shipping hook, not a re-implementation: `CLAUDE_PROJECT_DIR` pointed at a scratch
project whose snapshot carries `stale.md` then `live.md` under `## Pipeline Position`, fed
`{"source":"compact"}` on stdin. The post-compact mandate named **`steps/stale.md`** — the
FIRST value, taken by the whole-file `grep -m1` at `core/hooks/ai-dlc-recover.sh:72` — while the
Pipeline Position excerpt built twenty lines later at `:165`, which awk-scopes to the section
and prints all of it, carried both bullets, so `live.md` appears in the same directive
(occurrences: `stale.md` 1, `live.md` 1). Control in the same invocation: the identical hook
against a single-valued snapshot mandated **`steps/live.md`**. The two sides differ.

Nothing constrains the field. `grep -rl 'current_step_file|Current step file'` over
`core/scripts/`, `scripts/`, `core/fixtures/*/run.sh` and `.githooks/` returns exactly one file,
`core/fixtures/postcompact-rulebook-recovery/run.sh`, and at `:319` that file WRITES the field
into a seeded snapshot — it is a producer, not a guard; the control token `pipeline-snapshot`
over the same corpus returns **31** files. The nearest mechanism,
`validate-artifact-budget.sh:515-524`, is a CLOSED-set check on `## ` section headings and its
own header says so; a duplicated bullet inside a canonical section is invisible to it. The
schema clause the filing points at, `core/skills/ai-dlc/steps/gate-validation.md:773`, says only
"update `current_step_file`" and never says the field is single-valued or where a correction
goes — measured as an absence over all of `core/`: 0 hits for `single-valued`,
`overwrite in place`, `not an append` or `append-ordered`, against a control that returns hits
in the same file.

**The filing has the direction inverted and names the wrong reader, and the consequence is
wider than it claims.** It reports that corrections appended ABOVE the live bullet leave the
Stop hook quoting stale state. Measured against both readers' actual expressions, appending
above is the SAFE direction: `ai-dlc-continue.sh:559` and `ai-dlc-recover.sh:72` both take the
FIRST match, so a correction placed above WINS and the newest value is the one quoted. What goes
stale is the ordinary markdown habit — appending the correction BELOW. And the consequence is
not confined to a Stop hook's advisory text: `ai-dlc-recover.sh` resolves this value into the
post-compact recovery mandate and it is what `ai-dlc-recover-gate.sh` reads to decide whether it
may arm, so a first-match-wins resolution mandates a Read of the wrong step file and gates the
lead's next tool call on it.

The anchor is behavioural and drives the real hook because every substring available here
describes a wanted fix rather than the defect. A seeded reader fix — the same script with the
grep section-scoped and `tail -1` taking the live value — was built as a differential and
asserted to differ before being read: identical line counts (354/354), exactly 4 differing
lines, both inside the `STEP_FILE=` assignment. Against that copy the receipt returns **0**;
against the shipping hook it returns **1**. The receipt also passes if the hook emits no step
mandate at all, so a fix that refuses on a multi-valued field closes it too.

Discharges the consumer entry `PC-S296-PIPELINE-POSITION-MUST-BE-EDITED-IN-PLACE` at pinned
ledger line 701.


verify: sh D=$(mktemp -d); mkdir -p "$D/_bmad-output" "$D/.claude/skills/ai-dlc/steps"; : > "$D/.claude/skills/ai-dlc/steps/stale.md"; : > "$D/.claude/skills/ai-dlc/steps/live.md"; printf '# S\n\n## Pipeline Position\n\n- **Current step file:** `stale.md`\n- **Current step file:** `live.md`\n\n## Recent Activity\n\n- x\n' > "$D/_bmad-output/pipeline-snapshot.md"; M=$(printf '%s' '{"source":"compact"}' | CLAUDE_PROJECT_DIR="$D" bash core/hooks/ai-dlc-recover.sh 2>&1 | grep -oE 'steps/[a-z]+\.md' | head -1); rm -rf "$D"; [ -z "$M" ] || [ "$M" = "steps/live.md" ]
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
## BL-049

**The self-update slice cannot carry a fixture the pull itself fixes, because no derivation
anywhere reads the diff for fixtures.** `core/skills/ai-dlc-update/SKILL.md:215-217` defines the
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

The receipt is a proxy and the positive form was measured and rejected. The obvious positive
predicate — a line joining `diff` to `core/fixtures` — **exits 0 today**, because `SKILL.md:216`
already carries both tokens on one line. So the anchor is the pair of sentences that STATE the
diff-independence, one in each of the two files that own it, and either one changing closes the
entry. A quote-back inside a `~~strikethrough~~ **CORRECTED**` block — the correction form this
very file already uses at `:267-269` — would keep it non-zero, which is the safe direction: it
reports still-open rather than false-closing.

Discharges the consumer entry `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH`
at pinned ledger line 3413.


verify: sh S=core/skills/ai-dlc-update/SKILL.md; F=core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh; grep -qF core/fixtures "$S" && grep -qF core/fixtures "$F" || { echo "CONTROL FAILED"; exit 9; }; grep -qF 'grepped from the fixtures rather than from the diff' "$S" && grep -qF 'passed IN rather than re-derived here' "$F" && exit 1; exit 0
## BL-051

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

The anchor is the condition, in either place a fix can be sited, and it is not the filing's own
anchor. That one was `theirs_has SKILL.md "the consumer never edits them"` — an inverted verb: the
sentence is present at `:207` today, so the receipt reads CLOSE while the defect is live. A gate arm
or a step-2 subtraction must both NAME the bucket. Probed in both directions: `preclassify` already
appearing in step 2, and `BOTH-CHANGED` appearing in `SKILL.md` outside step 2, each leave it
non-zero.

Discharges the consumer entry `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`
at pinned ledger line 3918.


verify: sh S=core/skills/ai-dlc-update/SKILL.md; G=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; s="$(sed -n '/^2\. \*\*Self-update/,/^3\. \*\*Mechanical/p' "$S")"; grep -qF ALREADY-AT-THEIRS <<<"$s" && grep -qF SELF-UPDATE-OK "$G" || { echo "CONTROL FAILED"; exit 9; }; grep -qE 'BOTH-CHANGED|consumer-modified' <<<"$s" && exit 0; grep -qE 'BOTH-CHANGED|consumer-modified' "$G" && exit 0; exit 1
## BL-052

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


verify: sh D=core/skills/ai-dlc-update; grep -rqF 'settings.json.template' "$D" || { echo "CONTROL FAILED"; exit 9; }; n=$(grep -rlE 'show +<(theirs|base|ours)>:' "$D" | wc -l); [ "$n" -eq 0 ] && exit 0; exit 1
## BL-053

**Core's two readers of an escalation's `**Status:**` field disagree on which line in an entry
wins, and the one that adjudicates the closed vocabulary picks the line the resolution replaced.**
`core/scripts/validate-escalation-status-vocabulary.sh:159` carries
`if (status != "") next  # first Status line in an entry wins`;
`core/scripts/validate-escalation-resolution.sh:153-158` has no such guard and therefore takes the
LAST. Measured behaviourally against the shipping validator and the real
`core/skills/ai-dlc/escalations.md` vocabulary, three arms in one invocation, on an entry whose
terminal status is the out-of-vocabulary token `BOGUS_TOKEN`:

- **(a)** filed `HARD_BLOCK`, resolved by an appended `**Status:** BOGUS_TOKEN` — **exit 0**,
  `n=1`, reported "all escalation status tokens are in the derived set".
- **(b)** a prose line mentioning `**Status:** RESOLVED` above a canonical
  `**Status:** BOGUS_TOKEN` field — **exit 0**, `n=1`.
- **(c) CONTROL**, the same token as the entry's only `**Status:**` occurrence — **exit 1**,
  `FAIL: out-of-vocabulary status 'BOGUS_TOKEN'`.

The arm fires. It fires on (c) and not on (a) or (b), and (a) is the shape
`escalations.md:18` prescribes — "**Escalation entry format (append, do not overwrite):**" — while
`escalations.md:65-66` makes the appended line the authoritative one ("status updated to RESOLVED").

**(b) is the sharper half, because the validator's own stated purpose produces it.** Its comment at
`:148-152` widens the match off line-start on the reasoning that "a token in a non-canonical
position is exactly the one a naive line-anchored regex misses". Combined with the first-wins
tie-break at `:159`, matching anywhere makes it strictly WORSE: a `**Status:**` inside prose now
outranks the entry's real field and shields it. The widening was written to catch a case it
instead created.

That same comment cites `validate-escalation-resolution.sh:82-100` as the idiom it mirrors. Lines
82-100 there are the `# EXIT` comment block and the opening of argument parsing; the awk idiom is at
`:137-178`, and on the one axis that decides this it is the OPPOSITE. The citation is stale in
position and wrong in substance.

**What the consumer filing got wrong, and the direction is toward a worse defect.** It named the
consequence as a wrong COUNT — "any status grep overcounts" — a human-legibility problem in a
number nobody gates on. Measured upstream, the consequence is a CHECK THAT CANNOT FIRE on the
token position that matters: the validator whose entire job is to reject an out-of-vocabulary
status reports PASS on one. `gate-validation.md:230-243` orders that script run before Check 2's
branches precisely because "a token the branches cannot reach is not a wrong verdict, it is a
missing one" — and this is that state, reached through the validator meant to prevent it. The
filing's prescribed fix (resolution REPLACES the status line) also does not apply here: core's
prose already says the status is updated, and the defect survives it, because the file that
matters is `pending.md` as it exists today, carrying entries written under the append reading.

**Why these three arms are the anchor.** A receipt asserting only (a) would go green under a fix
that re-anchored the match to line-start — which repairs (a), reintroduces the case `:148-152`
exists to catch, and leaves (b). A receipt asserting only (b) goes green under a first-wins fix
that keeps ignoring appended resolutions. Requiring both, gated on (c), forces a fix that makes the
LAST canonical `**Status:**` authoritative — the one reading consistent with
`validate-escalation-resolution.sh`. Proven satisfiable, not asserted: deleting the single line at
`:159` from a copy takes the receipt to **exit 0** (`c=1 a=1 b=1`), with the two sides asserted to
differ in the same invocation before the comparison was read (`orig=1 fixed=0` occurrences of the
tie-break comment).

Discharges the consumer entry `PC-S296-ESCALATION-STATUS-APPENDS-INSTEAD-OF-REPLACING` at pinned
ledger line 654.


verify: sh D=$(mktemp -d); V=core/scripts/validate-escalation-status-vocabulary.sh; S=core/skills/ai-dlc/escalations.md; printf "## S999 Lead\n**Status:** HARD_BLOCK\n**Resolution:**\n**Status:** BOGUS_TOKEN\n" > "$D/a.md"; printf "## S999 Lead\n**Context:** was **Status:** RESOLVED once\n**Status:** BOGUS_TOKEN\n" > "$D/b.md"; printf "## S999 Lead\n**Status:** BOGUS_TOKEN\n" > "$D/c.md"; bash "$V" "$D/c.md" "$S" >/dev/null 2>&1; c=$?; bash "$V" "$D/a.md" "$S" >/dev/null 2>&1; a=$?; bash "$V" "$D/b.md" "$S" >/dev/null 2>&1; b=$?; rm -rf "$D"; [ "$c" -eq 1 ] || exit 1; [ "$a" -eq 1 ] && [ "$b" -eq 1 ]
## BL-054

**`--verify` anchors the H2 attestation at line start, so any markdown decoration on a line the
script tells a human to transcribe by hand reads as "no attestation ever existed".**
`core/scripts/validate-h2-attestation.sh:158` and `:164` both match
`grep -qE "^H2_ATTESTED v1 sprint=..."`. The line is not written by the script — `:32` says it
prints the line "for the lead to append to the gate log" and `:207-209` emit it as copy text — so a
model retypes it into a markdown file. Measured against the shipping script at the real fixture
digest `a0d56175be56e329`, five gate logs differing only in the decoration around one byte-identical
attestation line:

| gate log | exit | first line of output |
|---|---|---|
| bare (**CONTROL**) | **0** | `PASS  H2 attested for sprint 999 at fixture digest a0d56175be56e329.` |
| `` `…` `` backticks | 1 | `RE-DRIVE: no H2 attestation for sprint 999 — this is the sprint's first gate.` |
| `- ` list item | 1 | (identical) |
| four-space indent | 1 | (identical) |
| `> ` blockquote | 1 | (identical) |

**The filing is right about the defect and understates it twice.** It named backticks; the class is
every leading markdown decoration, four measured, because the anchor tolerates nothing before the
token. And it named the cost as a false RE-DRIVE; the second arm at `:164` is anchored identically,
so a decorated line ALSO cannot reach the digest-mismatch branch. Measured with a control in the
same invocation on a STALE digest: the bare line reports *"sprint 999 has an attestation, but the
fixture set CHANGED"*, and the backticked one reports *"no H2 attestation for sprint 999 — this is
the sprint's first gate."* The operator is not merely told to redo work; they are told the sprint
has never attested when it has, and told the fixtures are unchanged when they moved. That is a
wrong diagnostic, not a redundant one.

**Do not take the filing's prescribed fix.** Transcribed literally — "tolerate optional surrounding
backticks", i.e. a backtick in the pattern — it makes the script unparseable: an unescaped backtick
inside the double-quoted `grep -qE` argument opens command substitution, and `bash -n` on the
patched copy exits **2** with `line 163: syntax error near unexpected token 'fi'` against **exit 0,
no output** on the unpatched original in the same invocation. The fix has to avoid a bare backtick
in that string. `^[^A-Za-z]*H2_ATTESTED` does, and under it all three receipt arms exit 0.

Nothing in-tree catches this. Only two files in `core/` anchor `^H2_ATTESTED` — this script and
`core/fixtures/h2-attest-scripts-dir/run.sh:154` — against four naming `H2_ATTESTED` at all, and the
fixture anchors the SCRIPT'S OWN STDOUT, which is undecorated by construction. The fixture asserts
the emitter and is structurally blind to the reader.

**Why the anchor is the anchor.** A receipt using only the backtick arm goes green under a
backtick-only fix and leaves the bullet, indent and blockquote cases live — and the filing's own
wording invites exactly that narrow fix. Carrying two decorations, gated on the bare control, means
the receipt can only close on a fix that tolerates the class. Proven satisfiable: with the anchor
replaced by `^[^A-Za-z]*H2_ATTESTED` on a copy, `bare=0 tick=0 bullet=0` and the receipt exits 0;
the two sides were asserted to differ first (`orig=3 fixed=0` plain anchors).

Discharges the consumer entry `PC-S296-H2-ATTESTED-ANCHOR-DEFEATED-BY-BACKTICKS` at pinned ledger
line 673.


verify: sh D=$(mktemp -d); V=core/scripts/validate-h2-attestation.sh; G=$(bash "$V" --digest --fixtures core/fixtures); L="H2_ATTESTED v1 sprint=999 digest=$G at=2026-01-01T00:00:00Z items=1,2,3 mechanical=check-17-bypass:PASS"; printf "%s\n" "$L" > "$D/bare.md"; printf "\140%s\140\n" "$L" > "$D/tick.md"; printf "%s\n" "- $L" > "$D/bul.md"; bash "$V" --verify --sprint 999 --fixtures core/fixtures --gate-log "$D/bare.md" >/dev/null 2>&1; b=$?; bash "$V" --verify --sprint 999 --fixtures core/fixtures --gate-log "$D/tick.md" >/dev/null 2>&1; t=$?; bash "$V" --verify --sprint 999 --fixtures core/fixtures --gate-log "$D/bul.md" >/dev/null 2>&1; u=$?; rm -rf "$D"; [ "$b" -eq 0 ] || exit 1; [ "$t" -eq 0 ] && [ "$u" -eq 0 ]
## BL-055

**Check 16's element 2 accepts `OPEN` as a bare substring anywhere on the backlog line, so a
`(CLOSED)` carry-over item launders a stub through the gate.** The status test at
`core/scripts/validate-stub-audit.sh:217` is `[[ $bl =~ ^-\ Item\ [0-9]+.*(OPEN|IN\ SPRINT\ [0-9]+) ]]`
— the `.*` is unbounded and the token is bound to nothing, so any occurrence of the four
characters `OPEN` after the item number satisfies it. Driven through the shipping script on the
fixture's own V7 (`core/fixtures/check-15-bypass`, whose seed writes `- Item 7 — retired ack shim
(CLOSED)` and whose `run.sh:122` expects `element2-item-open`): unmutated the validator returns
**rc=1** with `FINDING src/v7_item_closed.py:5 element2-item-open`; with the single word of the
title changed to `retire the OPENAPI ack shim`, still `(CLOSED)`, it returns **rc=0, 0 finding(s)**.
Two controls in the same invocation — the unmutated tree (rc=1) and a lowercase near-miss,
`reopen the api ack shim (CLOSED)` (rc=1) — so the discriminator is the literal uppercase
substring and not the act of editing the line.

**The filing has the sign backwards.** It reports element 2's regex as *dead against live
content*, i.e. failing closed and producing findings it should not. Measured, the regex matches
live content fine — the fixture's honest positive control `v5_honest.py` passes at rc=0 against
`- Item 12 — connection pooling for the read path (OPEN)` — and the live defect is the opposite
direction: it fails **open**. Consequence moves with the sign, from noisy-but-safe to a stub
whose cited carry-over item is explicitly closed clearing a `gate_types: [universal]` check.
The filing's cited home was also stale twice over: it named `steps/gate-validation.md`, and its
own 2026-08-03 re-anchor note already repointed to this script.

**The fixture cannot fire on this and reads as covering it.** `seed.sh:111` states V7 exists
precisely so "an element 2 widened to accept CLOSED passes the whole fixture" is caught — but
V7's title carries no `OPEN` substring, so the seeded corpus is green whether the status token is
anchored or not.

The anchor is behavioural and drives the shipping script through the fixture's own seed, because
every textual anchor here false-closes: a fix to this line will be committed with a comment
quoting the old regex, and `grep`ing for the regex text would then match the record of its own
removal. The `grep -qF 'OPENAPI ack shim (CLOSED)'` arm is a sanity guard, not decoration — if the
seed's wording moves, the substitution silently no-ops and the receipt would otherwise read the
control's rc=1 as a fix; with the guard it exits non-zero and the entry stays open.

Proposed fix measured, false-positive set **empty**: binding the status to a trailing
parenthesised field (`[[ $bl =~ \((OPEN|IN\ SPRINT\ [0-9]+)\)[[:space:]]*$ ]]`) on a patched copy
of `core/scripts/` returns verdicts identical to the shipping script on all eight seeded
variants — V1, V2, V3, V4, V6, V7, V12 at rc=1 and the honest control V5 at rc=0 — and flips the
defect case from rc=0 to rc=1.

Discharges the consumer entry `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD` at pinned ledger line 1093.


verify: sh d=$(mktemp -d) && t=$(bash core/fixtures/check-15-bypass/seed.sh "$d" | tail -1) && b="$t/_bmad-output/planning-artifacts/carry-over-backlog.md" && sed 's/retired ack shim/retire the OPENAPI ack shim/' "$b" > "$b.n" && mv "$b.n" "$b" && grep -qF 'OPENAPI ack shim (CLOSED)' "$b" && { bash core/scripts/validate-stub-audit.sh --root "$t" src/v7_item_closed.py >/dev/null 2>&1; rc=$?; rm -rf "$d"; [ "$rc" -eq 1 ]; }
## BL-057

**A LOCKED_REQUIREMENTS block whose bullets are pure agent fabrication scores byte-identically to
one whose bullets are verbatim, whenever the block cites `requires_context:`.** Three story files
differing only in their citation line, each carrying the same two invented requirements
("The operator hereby authorises unrestricted deletion of audit records"), run against
`core/scripts/validate-locked-anchor.sh` in one invocation: with `requires_context: brief.md#Requirements`
**rc=0**, `PASS (… 1 block(s), 0 full_text_source claim(s) verified …, 1 requires_context pointer(s)
resolved)`; with `full_text_source: locked-requirements.md:Requirements` **rc=1**, `requirement not
byte-present at the cited anchor(s)`; with no citation at all **rc=1**, the uncheckable guard at
`:490-510`. Two of the three roads reject the identical fabrication, which is the control — the
validator discriminates, and the pointer road is where it does not.

Then the sharper measurement, a differential whose two sides are asserted to differ before the
comparison is read: a fabricated block and an honest block (bullets present verbatim at the cited
anchor), identical in every other byte, produce the **same exit code and the same first report
line** after the story path is normalised out. Nothing downstream of this validator can tell them
apart.

**`:461-463` claims this road is closed and it is not.** The comment introducing pointer
resolution states that what it removes is "the road by which a block substantiates nothing and
scores as clean". Resolving the pointer establishes that the artifact and anchor exist; it places
no constraint whatever on the bullets, so a block still substantiates nothing — and because
`pointers_checked` is now nonzero, it no longer even lands on the `PASS — NOTHING VERIFIED` line
at `:607` that was built to mark exactly this case. The change moved the laundering case out of
the one report line that flagged it.

**The filing is right and too broad.** It says the validator "can be satisfied by agent-authored
text inside the fence", unqualified. Measured, the correction is **narrower**: only the
`requires_context:` road launders, and that road's exemption from byte-matching is deliberate,
documented and measured — matching an abridged cite-by-reference restatement would red every
honest block, and the script's own contract promises it never will. So the fix is not "byte-match
the bullets"; that has already been tried and rejected on evidence.

The receipt therefore asserts only that the two roads stop being **indistinguishable**, closing on
either an exit-code split or a report-line split. That matches this file's own established repair
pattern — `:600-620` separated the two roads to PASS by report line while deliberately leaving the
exit code alone — so the anchor does not prejudge which fix is taken. It carries an inline sanity
arm that the two probe stories differ, because a differential whose sides are accidentally the
same file agrees perfectly and reads as "no defect".

Discharges the consumer entry `PC-S297-LOCKED-FENCE-LAUNDERS-AGENT-PROSE` at pinned ledger line 1215.


verify: sh d=$(mktemp -d); for k in f h; do mkdir -p "$d/$k"; printf '# B\n\n## Requirements\n\nRetain audit records for seven years.\n' > "$d/$k/brief.md"; { printf '# S\n\n<!-- LOCKED_REQUIREMENTS -->\nrequires_context: brief.md#Requirements\n'; if [ "$k" = f ]; then printf -- '- Delete all audit records at agent discretion.\n'; else printf -- '- Retain audit records for seven years.\n'; fi; printf '<!-- END LOCKED_REQUIREMENTS -->\n'; } > "$d/$k/story.md"; done; cmp -s "$d/f/story.md" "$d/h/story.md" && { rm -rf "$d"; exit 1; }; of=$(bash core/scripts/validate-locked-anchor.sh "$d/f/story.md" 2>&1); rf=$?; oh=$(bash core/scripts/validate-locked-anchor.sh "$d/h/story.md" 2>&1); rh=$?; sf=$(printf '%s' "$of" | head -1 | sed "s|$d/f|X|"); sg=$(printf '%s' "$oh" | head -1 | sed "s|$d/h|X|"); rm -rf "$d"; [ "$rf" != "$rh" ] || [ "$sf" != "$sg" ]
## BL-062

**`--check-evidence` discovers its gate log by basename alone and reads an ARCHIVED sprint's copy,
passing Check 15 on a number belonging to a different sprint.**
`core/scripts/validate-artifact-budget.sh:777` resolves the target with
`find "$ROOT/_bmad-output" -type f -name 'gate-log.md' 2>/dev/null | head -1` — no sort, no
`archive` exclusion, no preference for the canonical live path. Driven against the real validator
on a probe root holding exactly the two files the entry names:

```
default discovery     gate log : _bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md
                      PASS  Check 14 evidence cell cites 4385 tok (budget 6000, ceiling 6600)
--gate-log <live>     gate log : _bmad-output/implementation-artifacts/gate-log.md   <- CONTROL
                      PASS  Check 14 evidence cell cites 5881 tok (budget 6000, ceiling 6600)
```

The control is the same script, same root, same invocation set, differing only in the flag, and it
returns a different number — so the two sides genuinely differ and the archived row is being read,
not merely reachable. Check 15 exists to verify Check 14's assertion took effect by re-reading
recorded state; it printed a normal PASS line on a row from an unrelated sprint.

**The filing is corrected WIDER on its central mechanism.** It describes the failure as
nondeterministic — "readdir-order, not sorted and not guaranteed stable call-to-call", observed
flipping between a manual shell and a `bash -x` trace. Measured on 20 independently created probe
roots each holding one live and one archived copy, `find` returned the ARCHIVED path first 20 times
and the live path 0 times; the control, 20 roots holding only the live copy, returned live-first
20 and archive-first 0, so the classifier reports both directions. On this filesystem the wrong
answer is not intermittent, it is the reliable one, which removes the "may not reproduce" defence
the entry's own framing invites. The exposure is wider than the entry's stated population too: the
predicate is basename-only across all of `_bmad-output`, so any second `gate-log.md` anywhere under
that tree qualifies — `archive/cycle-*/` is one source of them, not the condition.

**Why the anchor is the anchor.** The receipt asserts the CITED NUMBER, not the chosen path, and
seeds the two files with different numbers (5881 live, 4385 archived) so that no gate log other
than the live one can satisfy it. An anchor on the path string would false-close on a fix that
merely reordered `find` without preferring the canonical location, and an anchor on the
`find … | head -1` source text would be satisfied by a comment recording its removal — the dominant
failure mode here, since fixes in this tree document what they deleted. It reaches 0 when discovery
prefers `_bmad-output/implementation-artifacts/gate-log.md` or excludes `archive/` segments; that
end state is already demonstrated by the control arm, which prints `cites 5881 tok` today.

Discharges the consumer entry `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG` at
pinned ledger line 4313.


verify: sh R=$(mktemp -d); mkdir -p "$R/_bmad-output/implementation-artifacts" "$R/_bmad-output/planning-artifacts/s300/archive/cycle-1"; printf "| [core] 14 - Update pipeline snapshot | PASS (lead) | 5881 tok |\n" > "$R/_bmad-output/implementation-artifacts/gate-log.md"; printf "| [core] 14 - Update pipeline snapshot | PASS (lead) | 4385 tok |\n" > "$R/_bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md"; out=$(bash core/scripts/validate-artifact-budget.sh --root "$R" --check-evidence 2>&1); rm -rf "$R"; case "$out" in *"cites 5881 tok"*) true;; *) false;; esac

## BL-064

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

## BL-066

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

verify: sh S=core/scripts/audit-layer-debt.sh; [ -f "$S" ] || exit 9; d=$(mktemp -d); g="$d/reg.jsonl"; h="{\"clause\":\"LC-E1\",\"entry\":\"extensions/probe.md\",\"subject_digest\":\"da39a3e\",\"verdict\":\"still-additive\",\"recorded_utc\":\"1970-01-01T00:00:00Z\",\"reason\":\"probe row\",\"owed\":{\"id\":\"OWED-PROBE-1\",\"what\":\"split X out\",\"closes_when\":"; x="$h"'"immediately after scripts/ai-dlc/migrate-artifact-paths.sh --apply completes"}}'; y="$h"'"when the operator says so"}}'; [ "$x" != "$y" ] || { rm -rf "$d"; exit 9; }; printf '%s\n' "$x" > "$g"; a=$(bash "$S" --register "$g" 2>/dev/null); ra=$?; printf '%s\n' "$y" > "$g"; b=$(bash "$S" --register "$g" 2>/dev/null); rb=$?; rm -rf "$d"; [ "$ra" = 0 ] && [ "$rb" = 0 ] || exit 9; case "$a" in *OWED-PROBE-1*) : ;; *) exit 9 ;; esac; case "$b" in *OWED-PROBE-1*) : ;; *) exit 9 ;; esac; [ "$a" != "$b" ] || exit 9; ca=$(printf '%s\n' "$a" | grep -v 'closes when:'); cb=$(printf '%s\n' "$b" | grep -v 'closes when:'); [ "$ca" != "$cb" ]

## BL-069

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

## BL-072

**`validate-no-dead-doc-refs.sh` scans `docs/*.md` and nothing below it, so 74 of 105 tracked
markdown files under `docs/` are outside the corpus it reports clean over.** The loop is
`for doc in docs/*.md` at `scripts/validate-no-dead-doc-refs.sh:42`. Measured in one invocation:
top-level `docs/*.md` = **31**; `find docs -name '*.md'` = **105**; the difference, **74**, is the
population no run has ever read. Control: the same `find` restricted to the glob returns the same
31, so the counts are taken over one tree and one tool.

**This is a scope gap and was deliberately NOT widened when it was found.** The release that found
it fixed four dead citations by hand — three inside the glob that the validator flagged, and four
under `docs/analysis/…` that were the IDENTICAL dead reference sitting outside it and were fixed
without any check having named them. Widening the glob was rejected in that release on one
ground and it is still the live one: the false-positive set over `docs/**` is UNMEASURED, and this
repo does not ship an unmeasured check.

**So the work this entry names is the MEASUREMENT, not the one-character glob change.** Run the
existing predicate over `docs/**/*.md`, enumerate what it flags, and separate genuine dead
references from paths that are legitimately unresolvable in that subtree — plan and review
documents quote paths that no longer exist ON PURPOSE, as the record of a tree that has moved,
and a check that fails the push on a historical citation is one the operator turns off.

The receipt keys on the LOOP, and carries a control so deleting the loop cannot close it: a fix
that widens the corpus changes that line, and a fix that removes the scan entirely fails the
control arm rather than passing it.

verify: sh S=scripts/validate-no-dead-doc-refs.sh; [ -f "$S" ] || exit 9; g="$(grep -oE '^for doc in [^;]+' "$S" | head -1)"; [ -n "$g" ] || exit 9; case "$g" in *'docs/*.md'*) exit 1 ;; *) exit 0 ;; esac

## BL-074

**The ENTRY-LINE half of the ledger close predicate is still a hand-copy, in the one program that
now lifts the BODY half from its owner.** `core/skills/ai-dlc-update/reconcile/`
`warn-shadowed-local-validators.sh` composes its awk from `ledger_entry_awk()` and
`ledger_close_awk()`, so its boundary rule and its BODY close test are both single-homed — and
then writes the entry-line test inline:

```
ledger_entry_shape($0) != "" && ($0 ~ /ADOPTED UPSTREAM|WITHDRAWN/ || $0 ~ /\(original text, retained for the record\)/) { closed=1 }
```

which is the predicate `ledger-reverify.sh`'s `entry_line_closes()` already owns. `lib.sh`
single-homes only the body rule, and its own header's sentence about two close-predicates
differing deliberately is about reverify-vs-rotate — it says nothing about a third copy in a
third program.

**This is the same class the release that filed it just fixed, and it is filed rather than fixed
for a stated reason.** That release replaced four drifted copies of the BODY rule with one lift,
after measuring that the drifted ones produced a false report on the reference consumer and false
retire advice here. A second lift is the correct remedy and it is a second runtime read; landing
one into a release whose fixtures three independent hands had just stabilised is how a green gate
becomes a red one at the last step.

**The two copies AGREE today, so no fixture arm can distinguish them and one would be vacuous.**
That is what makes this a latent defect rather than a live one, and it is also why the remedy is
a lift rather than a guard — `mechanism-design.md` asks for the PARTITION that makes the bad state
unconstructible over the check that looks for it. The receipt below therefore keys on the
restatement itself, with a control so deleting the arm cannot close it.

**A fix must lift, not delete.** The entry-line scope is load-bearing: the legacy id-less form
writes its close inside the title, and the retained-copy parenthetical carries no marker of its
own, so a program without an entry-line test misses both.

Found by the fixture author who repaired `core/fixtures/shadowed-local-validators/` after the body
lift landed, while establishing that its new mutant could distinguish a lifted predicate from an
inline one.

verify: sh W=core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh; [ -f "$W" ] || exit 9; grep -q 'ledger_close_awk' "$W" || exit 9; n="$(grep -c 'original text, retained for the record' "$W")"; [ "$n" -eq 0 ]

## BL-075

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

**The filing's prescribed remedy is a total disarm on this platform, and its own receipt accepts
it.** `\b` is not in Darwin's ERE under bash 3.2 — measured, `[[ "stub = 1" =~ \b(stub)\b ]]`
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

The receipt is four-armed and behavioural because every narrower anchor false-closes here. A
textual anchor on `:108` closes on the `\b` disarm; an anchor on `element1-item-ref` closes on
nothing, since element 1 is merely whichever element fails first when no backlog exists. Arms C
and E are guards in opposite directions — C rejects a disarm, E rejects a comment-only gate — and
without either the receipt certifies a check that has been weakened rather than corrected. Proven
against patched copies under `mktemp`, each asserted byte-different from the shipping file first:
shipping, `\b`, word-boundary and comment-gated all exit non-zero; the split set exits 0.

Discharges the consumer entry `PC-S303-STUB-AUDIT-MARKER-REGEX-MATCHES-LOCAL-VAR-NAMED-STUB` at
LIVE ledger line 2955.


verify: sh V=core/scripts/validate-stub-audit.sh; [ -f "$V" ] || exit 9; d=$(mktemp -d) || exit 9; mkdir -p "$d/src"; printf 'def f():\n    stub = AsyncMock(return_value=None)\n    return stub\n' > "$d/src/a.py"; printf 'def f():\n    client_stub.call()\n    return 0\n' > "$d/src/b.py"; printf 'def f():\n    # stub, wire later\n    return 0\n' > "$d/src/c.py"; printf 'def f():\n    raise NotImplementedError()\n' > "$d/src/e.py"; bash "$V" --root "$d" src/a.py >/dev/null 2>&1; ra=$?; bash "$V" --root "$d" src/b.py >/dev/null 2>&1; rb=$?; bash "$V" --root "$d" src/c.py >/dev/null 2>&1; rc=$?; bash "$V" --root "$d" src/e.py >/dev/null 2>&1; re=$?; rm -rf "$d"; [ "$rc" -eq 1 ] || exit 1; [ "$re" -eq 1 ] || exit 1; [ "$ra" -eq 0 ] || exit 1; [ "$rb" -eq 0 ] || exit 1; exit 0

## BL-076

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


verify: sh T=$(printf '\140'); S(){ P="$1"; Q="$2"; mkdir -p "$P/spec"; H=$(printf hi | shasum -a 256 | cut -d' ' -f1); printf '%s\n' "- user_request_verbatim: x" "- scope_confirmed: confirmed" "- scope_confirmed_cite: $H" > "$P/snap.md"; printf '%s\n' "- SHA256: $H" > "$Q/ans.md"; printf '%s\n' "add CI gate ${T}g1${T} here." > "$P/retro.md"; printf '%s\n' "run: g1" > "$Q/w.yml"; printf '%s\n' "<!-- AC_UNBOUNDED_TERMS v1 -->" "aaa, bbb" "<!-- AC_UNBOUNDED_TERMS_END -->" > "$P/lex.md"; printf '%s\n' "- **AC1 (unit).** counter increments by exactly 1." > "$Q/story.md"; printf '%s\n' "- CAP-1 x" > "$P/spec/SPEC.md"; printf '%s\n' "- (capability) LR-S1-1 -> CAP-1" > "$P/spec/.memlog.md"; printf '%s\n' "- FR-1 (CAP-1) x" > "$Q/prd.md"; printf '%s\n' "# esc" > "$P/esc.md"; }; R(){ P="$1"; Q="$2"; O1=$(bash core/scripts/validate-scope-confirmation.sh --snapshot "$P/snap.md" --answers "$Q/ans.md" 2>&1); C1=$?; O2=$(AI_DLC_RETRO_DIR="$P" AI_DLC_CI_SURFACE="$Q" bash core/scripts/validate-ci-gates.sh 2>&1); C2=$?; O3=$(bash core/scripts/validate-ac-falsifiability.sh --lexicon-from "$P/lex.md" "$Q/story.md" 2>&1); C3=$?; O4=$(bash core/scripts/validate-spec-join.sh --spec "$P/spec" --prd "$Q/prd.md" 2>&1); C4=$?; O5=$(bash core/scripts/validate-suppression-lifetime.sh --escalations "$P/esc.md" 2>&1); C5=$?; }; A1=$(mktemp -d); A2=$(mktemp -d); B1=$(mktemp -d); B2=$(mktemp -d); [ "$A1" != "$B1" ] && [ "$A2" != "$B2" ] || exit 9; S "$A1" "$A2"; S "$B1" "$B2"; R "$A1" "$A2"; a1=$O1; a2=$O2; a3=$O3; a4=$O4; a5=$O5; c1=$C1; c2=$C2; c3=$C3; c4=$C4; c5=$C5; R "$B1" "$B2"; b1=$O1; b2=$O2; b3=$O3; b4=$O4; b5=$O5; rm -rf "$A1" "$A2" "$B1" "$B2"; [ "$c1" = 0 ] && [ "$c2" = 0 ] && [ "$c3" = 0 ] && [ "$c4" = 0 ] && [ "$c5" = 0 ] || exit 9; grep -qF "answers_entries_scanned" <<<"$a1" && grep -qF " retros," <<<"$a2" && grep -qF "term(s) loaded" <<<"$a3" && grep -qF "locked requirement(s)" <<<"$a4" && grep -qF "entries_scanned=" <<<"$a5" || exit 9; [ "$a1" != "$b1" ] && [ "$a2" != "$b2" ] && [ "$a3" != "$b3" ] && [ "$a4" != "$b4" ] && [ "$a5" != "$b5" ] || exit 1; grep -qF "$A1" <<<"$a1" && grep -qF "$A2" <<<"$a1" && grep -qF "$A1" <<<"$a2" && grep -qF "$A2" <<<"$a2" && grep -qF "$A1" <<<"$a3" && grep -qF "$A2" <<<"$a3" && grep -qF "$A1" <<<"$a4" && grep -qF "$A2" <<<"$a4" && grep -qF "$A1" <<<"$a5" || exit 1; grep -qF "$B1" <<<"$b1" && grep -qF "$B1" <<<"$b2" && grep -qF "$B1" <<<"$b3" && grep -qF "$B1" <<<"$b4" && grep -qF "$B1" <<<"$b5"

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

## BL-078

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


verify: sh V=docs/vocabulary-index.md; [ -f "$V" ] || exit 9; grep -q "^| Vocabulary | Members | Owner | Bound by | Readers |$" "$V" || exit 9; row="$(grep -iE "^\|[^|]*(vacuous|empty.subject|examined nothing|nothing to check|not.applicable|nothing verified)[^|]*\|" "$V")"; [ -n "$row" ] || exit 1; n=0; for f in validate-spec-join validate-plan-shape audit-layer-debt validate-bmad-invocations validate-ac-falsifiability validate-escalation-status-vocabulary validate-artifact-paths validate-request-coverage validate-gate-adjudication validate-snapshot-conservation; do case "$row" in *"$f"*) n=$((n+1));; esac; done; case "$row" in *"core/scripts/*"*) n=99;; esac; [ "$n" -ge 3 ] || exit 1; exit 0

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


verify: sh D=$(mktemp -d); mkdir -p "$D/spec" "$D/ctl"; printf '# PRD\n\n- FR-S1-1 the functional requirement, CAP-1\n- LR-S1-1 the locked requirement\n' > "$D/prd.md"; printf '# SPEC\n\nCAP-1 the capability\n' > "$D/spec/SPEC.md"; cp "$D/spec/SPEC.md" "$D/ctl/SPEC.md"; printf -- '- (capability by bmad-spec) LR-S1-1 -> CAP-1\n- (event by bmad-spec) swept with an absent-id control (LR-S999-9) that returned zero\n' > "$D/spec/.memlog.md"; printf -- '- (capability by bmad-spec) LR-S1-1 -> CAP-1\n- (constraint by bmad-spec) LR-S1-2 is locked and cites nothing\n' > "$D/ctl/.memlog.md"; cmp -s "$D/spec/.memlog.md" "$D/ctl/.memlog.md" && { rm -rf "$D"; exit 9; }; V=core/scripts/validate-spec-join.sh; [ -r "$V" ] || { rm -rf "$D"; exit 9; }; bash "$V" --spec "$D/ctl" --prd "$D/prd.md" >/dev/null 2>&1; c=$?; out=$(bash "$V" --spec "$D/spec" --prd "$D/prd.md" 2>&1); s=$?; rm -rf "$D"; [ "$c" -eq 1 ] || exit 9; [ "$s" -eq 0 ] && ! grep -qF "LR-S999-9" <<<"$out"

## BL-080

**`enforcement-map.yaml` states Check 3b's posture as `FAILS the gate (exit 0 required)`, and
exit 0 is exactly what a story that verified NOTHING returns — so the map records a vacuous run as
gate-satisfying.** The row's enforcer is `core/scripts/validate-locked-anchor.sh`, whose vacuous
branch prints `PASS — EXAMINED NOTHING` and exits **0** by deliberate design: a block claiming
nothing has nothing to substantiate, and failing it would red every legacy block in a consumer's
history. Driven through the shipping script on the fixture's own stories, three arms in one
invocation: `nothing-verified-story.md` **rc 0**, `good-story.md` **rc 0**, and the control that
proves the check can still fire, `bad-story.md` **rc 1**. The two roads to 0 are distinguishable in
the REPORT LINE and indistinguishable in the EXIT CODE, and the map's posture is written in terms
of the exit code.

**The scale is already measured and it is recorded in this repo, in the fixture's own prose:** on a
reference consumer **196 of 998 stories took the vacuous road and 0 took the verified one** — the
whole corpus reported PASS and nothing had ever been verified. A posture that reads "exit 0
required" is satisfied by every one of those 196.

**This is `BL-039`'s PASS-by-default hazard written into the map rather than into a schema, and it
is what `BL-058` did NOT fix.** `BL-058` unified the emitted TOKEN across three validators and
registered it as a controlled vocabulary; it deliberately left every exit code untouched, because
the codes are per-validator contracts and one of them is consumer-visible. So the token now
distinguishes the two roads and the posture line still does not. The distinction exists, is
rendered in `docs/vocabulary-index.md`, and the one place a reader goes to ask "what does this
check enforce" cannot see it.

**Narrower than it looks in one direction, and that belongs in the record.** The other two emitters
do not have this shape: `validate-stub-audit.sh` exits **4** on its vacuous branch and its map row
says so explicitly (`exit 4 is the non-vacuity sub-clause`), and `validate-ci-gates.sh` exits
**78** with a row whose posture is `reports; the retro adjudicates`. Only the locked-anchor row
states a bare exit-0 requirement against an emitter whose vacuous road is exit 0. The defect is one
row, not a class — but it is the row on a `hard_block: true` check.

**Why the receipt is the receipt.** It cannot key on the posture's WORDING, because any fix is free
to phrase it differently and this program has already shipped one receipt that rejected a correct
fix for renaming its subject. It keys instead on the JOIN the fix has to create: the Check 3b row
must reach the empty-subject vocabulary — by naming the token, or the vocabulary, or by the gate
step reading the token rather than the code. Its control is behavioural and runs first: the
fixture's failing story must still exit **1** and its vacuous story must still exit **0**, so a fix
that "resolves" this by making the vacuous road fail — reddening 196 of 998 stories on a real
consumer — exits 9 and reports STILL-LIVE rather than closing. That control is the whole reason
this entry is not simply "make it exit non-zero". Proven in both directions with the sides asserted
to differ: **1** against the tree as shipped, **0** against a copy whose Check 3b row names the
token, with the behavioural control passing in both.

Split from `BL-058`, which registered the vocabulary these emitters share; found while auditing
that entry's own owner file. Tier: **DEFECT** — it misstates what a `hard_block` check enforces, on
a corpus where the vacuous road was measured at roughly one story in five.


verify: sh M=core/skills/ai-dlc/enforcement-map.yaml; V=core/scripts/validate-locked-anchor.sh; F=core/fixtures/check-3b-locked-anchor; [ -f "$M" ] && [ -r "$V" ] && [ -d "$F" ] || exit 9; ( cd "$F" && bash "../../../$V" bad-story.md >/dev/null 2>&1 ); b=$?; ( cd "$F" && bash "../../../$V" nothing-verified-story.md >/dev/null 2>&1 ); n=$?; [ "$b" -eq 1 ] || exit 9; [ "$n" -eq 0 ] || exit 9; ROW=$(awk '/- site: gate-validation.md Check 3b$/{on=1} on{print; c++} on && c>=6{exit}' "$M"); [ -n "$ROW" ] || exit 9; printf '%s' "$ROW" | grep -qiE 'EXAMINED NOTHING|empty.subject|empty_subject'
## BL-081

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

