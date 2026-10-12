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

## BL-497 — a declared fixture that tolerates a missing input passes its sandbox with fewer assertions, and nothing compares that count against a plain run

**DEFECT, filed at batch 221; re-adjudicated at batch 222 (below the original text, which is kept whole).**

**Original filing (batch 221).** **DEFECT, filed at batch 221** as BL-495's residue, by the 0.771.0 tip adversary, measured at `4a4022e9`. BL-495 says
no mechanical predicate can tell a narrowed declaration from an under-declared one without the trace; the trace
exists for most fixtures, and nothing joins the two. Joining each declared fixture's `inputs.decl` against its own
rows in `.ai-dlc-fixture-readsets.tsv` (tracked paths outside the fixture's own directory) found **110 of 182**
traced declared fixtures reading at least one tracked file their declaration does not cover, **1927** paths in all.
Much of it is root noise (`.gitignore`, `package.json`); `agent-definition-render` alone reads 59 `core/scripts/*`
files it does not declare. An under-declared fixture is skipped when a file it reads changes, and its verdict-store
pass is reused, which is the failure BL-495 warned narrowing could introduce. Control in the same join: removing
`core-paths.sh` from `upstream-routing`'s declaration makes exactly that path appear.

The fix is the join as a validator (standalone, not an arm of `validate-enforcement-map.sh`, which the suite pole
runs), with the root-noise class enumerated and its false-positive set measured before it ships, then each real
gap declared. The map is stale for fixtures changed since its last derivation, so a row naming a file that no
longer exists is the map's, not the declaration's.

**Re-adjudicated at batch 222, measured at `50b5ca40`.** The filing makes two claims; one survives.

**Claim 1, the census: REPRODUCES.** The same join (each declared fixture's `inputs.decl`, `!` stripped, a
trailing-`/` entry covering its subtree, against its committed rows for tracked paths outside its own directory)
reads 238 declared fixtures, 182 traced, **110 with a gap, 1927 paths**. The control holds in the same invocation:
dropping `core/scripts/core-paths.sh` from `upstream-routing`'s declaration reads 111 and 1928, and the diff is that
one line. 1695 of the paths are under `core/`, 102 are `.gitignore`; `shipped-rule-version-floor` carries 956 and
`layer-crosswalk-home` 569, and `agent-definition-render` 59.

**Claim 2, the harm — "an under-declared fixture is skipped when a file it reads changes, and its verdict-store pass
is reused": FALSE as stated.** The skip is real: the hook keys a declared fixture from `.dkeys` alone
(`.githooks/pre-push:1503-1505`, the decision awk at `.githooks/pre-push:1662-1665`), so a change to an undeclared
file does not rerun it. The harm is not, because the fixture never runs against that file. A declared fixture is
run only by `core/scripts/hermetic-run.sh` (`.githooks/pre-push:2003-2006`, dispatch at
`.githooks/pre-push:2011-2020`), in a fresh sandbox holding only its declared inputs
(`core/scripts/hermetic-run.sh:54-57`, invocation at `core/scripts/hermetic-run.sh:510`), so the stored verdict cannot
depend on a file the sandbox does not hold. The map rows that produce the "gap" were traced UNSANDBOXED and predate
the declarations: `agent-definition-render`'s rows were last written at `199721b6` (0.734.0) and `f7eec6f5` (0.674.0),
its `inputs.decl` was added at `cab72a8e` (0.755.0). Measured: the kept sandbox of `agent-definition-render` at this
tip holds **0 of its 59** gap files and holds its declared `core/scripts/render-agent-definitions.sh` (control 1);
sandboxed and plain runs gave identical rc and `ok` counts on six fixtures — `agent-definition-render` 28,
`suppression-lifetime` 97, `escalation-status-vocabulary` 57, `upstream-routing` 54, `shipped-rule-version-floor` 12,
`layer-crosswalk-home` 21 (the last two carry 1525 of the 1927 paths). All six were re-run at this tip, rc 0 on
both sides and no `skip` line on either. The original fix — declare every gap — would
widen keys by files the fixture provably runs without.

**The live residue, which the title now names.**

- **(a) Reduced coverage reads PASS.** A fixture with a skip branch for a missing input passes under the sandbox with
  fewer assertions. `core/scripts/hermetic-run.sh:27-35` records the measured case (48 assertions down to 32, verdict
  PASS, one hook dropped from a declaration) and why only a `!` REQUIRED input's `HERMETIC-CONSUMED` sentinel catches
  it. An input not marked `!` has no such guard, and nothing compares a sandboxed run's assertion count against a plain
  run's.
- **(b) The sandbox is a copy, not a jail.** `env -i` and `AI_DLC_PROJECT_ROOT` set to the sandbox root
  (`core/scripts/hermetic-run.sh:54-56`) redirect a fixture that resolves its root the documented way; one that reaches
  the real tree by absolute path reads outside the sandbox, and there the original harm sentence is true — its verdict
  depends on an unkeyed read. No such fixture was measured. One was available to measure (grep the declared fixtures
  for an absolute repo path, or run each sandboxed with the real tree moved aside) and was not taken this batch.

The fix is an instrument, standalone and not an arm of `validate-enforcement-map.sh`, that runs each declared fixture
sandboxed and plain and compares their assertion and skip counts; (b) shows up in it as a sandboxed run whose result
changes when the real tree is made unreadable for the duration of that run.

**Batch 223: the instrument for (a) is built; the census run has not happened, so this entry stays OPEN.**
`scripts/census-hermetic-coverage.sh` runs each declared fixture through `core/scripts/hermetic-run.sh` (kept
sandbox, a fresh verdict store per pair) and then plainly from the root with the sandbox's own `env -i` invocation
and its tool farm. It compares the fixture rc and the multiset of `ok`/`PASS` lines, normalised for paths only and
never for digits, and it reports each side's skip-line count beside the verdict, which that count does not decide.
Each row gets one verdict: **EQUAL**, **LOW-RES** (equal at 1 or 2 ok lines), **MISMATCH** (direction
PLAIN-MORE, HERMETIC-MORE, DIFFER or RC, confirmed by one re-pair), **FLAKY** (a mismatch the re-pair did not
reproduce), **UNCOUNTABLE** (the plain run printed no ok line, never scored `0 = 0` EQUAL) or **REFUSED** (hermetic-run
exit 2, or a plain run that changed the root's git status, stash list, worktree list or durations record, which also
stops the census). A MISMATCH fixture with no `git.decl` whose own scripts call git is tagged **NO-GIT-DECL**. For that
class, `git.decl: seed` is a valid remedy beside declaring the input or marking it `!`, because the sandbox is not a
repository without one. `core/fixtures/census-hermetic-coverage` (`.dist-only`) binds it. A seeded skip-branch
fixture reads MISMATCH PLAIN-MORE, and a fixture that agrees across a cwd-relative read, a farm-only tool, a stderr ok
line and root and scratch paths reads EQUAL. Eight wrong census implementations are each killed.

The `--jail` half was dropped before it was built, so **(b) remains, unmeasured**. The census measures (a) only:
a fixture that reaches the real tree by absolute path reads it in both runs, and the two runs agree.

**Census, batch 223.** First run over all 240 declared fixtures at `2bdb3a29` (paused by the operator at 232, the
last 8 run on resume): 203 EQUAL, 8 LOW-RES, 26 MISMATCH, 3 REFUSED. Adjudicated, then fixed in 0.774.0:
- **Sandbox escape, 10 fixtures (residue (b), measured).** `inflight-row-shape`, `request-coverage`,
  `scope-confirmation`, `snapshot-conservation`, `snapshot-section-schema`, `snapshot-supersession-marker`,
  `suppression-lifetime`, `budget-summary-verdict`, `mandatory-rules-skip-accounting`,
  `mandatory-rules-snapshot-position`. Each `run.sh` clears `AI_DLC_*`, discarding the sandbox root
  `hermetic-run.sh` hands it; the validator's walk-up left the sandbox (no `.git` there) and in the gate resolved a
  stray `.claude/` above the per-user temp dir (consumer `guarded-merge.sh` logs, 2026-05-31). Without that marker
  all ten fail (seven rc 1, three rc 2). 0.774.0 gives each `git.decl: seed`; seeded, all ten pass with an ok-line
  multiset equal to the plain run's, in the distribution and in a consumer install.
- **Coverage gap, 2 fixtures.** `layer-crosswalk-home`'s installer arms and `handoff-completion-assertion`'s e6-order
  check never ran under the gate (their distribution-only inputs are deliberately undeclared). 0.774.0 folds them
  into `schema-install-fallback`, which declares those inputs; 41 = 41 sandboxed and plain.
- **Instrument artifacts, the rest**: volatile tokens (seeded shas, fork counts), the census's long TMPDIR failing
  memo-key filenames, and two failing runs read as EQUAL. 0.774.0's instrument has a short physical scratch root, a
  marker walk at start and end, BOTH-FAIL, a `fixture-rc-2` split, and EQUIVALENT (a third pair; a differing count
  clears only when the two sides' observed ranges overlap).

**Close run, batch 223** (the fixed instrument on the 0.774.0 tree, the stray marker moved aside, 74 fixtures: every
row above plus the 43 declared fixtures that use a bare `mktemp -d` and clear `AI_DLC_*`): 56 EQUAL, 11 EQUIVALENT,
1 LOW-RES, **6 MISMATCH**, 0 REFUSED. All ten seeded fixtures and all 43 bare-`mktemp` fixtures read EQUAL.
**The entry stays OPEN on the 6, none yet adjudicated:**
- Stable per-side numbers that track the sandbox path length (plain/sandboxed): `procsub-staged-refusal-b` (138/162),
  `fanout-payload-channel` (1230/1422), `preclassify-rename-row` (352/376). Likely the instrument, not coverage: the
  two sides' paths differ in length by a fixed amount (each difference is a multiple of 24).
- `readset-skip-b`: two pairs DIFFER, the third read HERMETIC-MORE at rc 1/0. Timing-sensitive mutants (`noppid`,
  sleep-in-group); likely flaky, unconfirmed.
- `snapshot-archive-rotate`: a sweep summary line whose wording differs, not only its numbers.
- `procsub-staged-refusal-boot-b`: sandboxed rc 1 with 52 ok against plain rc 0 with 51 (one extra `MUTANT KILLED`
  line on the sandboxed side, which then fails).
A run over the other 166 declared fixtures with the fixed instrument has not been taken.

verify: manual -- close when an instrument run over every declared fixture reports, per fixture, the sandboxed run's assertion and skip counts equal to the plain run's, with every mismatch either fixed or covered by a `!` required input; the instrument must be shown to fire on a seeded fixture whose sandboxed count drops (an input left undeclared behind a skip branch) and stay quiet on one whose counts match


