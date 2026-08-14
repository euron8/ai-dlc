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
