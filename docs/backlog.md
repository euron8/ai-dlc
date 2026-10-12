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
(`core/scripts/hermetic-run.sh:54-57`, invocation at `core/scripts/hermetic-run.sh:536`), so the stored verdict cannot
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

**Instrument limits recorded, not fixed:** the plain and sandboxed sides' temp paths still differ in length by a fixed
amount, which is the most likely source of the first three rows above; and the range-overlap rule for counts acquits
a stable side whose value lies inside the other side's range without ever appearing there (plain 13 x3 against
sandboxed 12, 14, 12 reads EQUIVALENT). The `verify:` line below predates EQUIVALENT and must be reworded when this
entry closes.

**The escape is now refused (0.775.0).** `hermetic-run.sh` exits 2 before building a sandbox when a project marker
(`.git`, a `.claude/` directory, `core/skills/ai-dlc`) sits above its scratch directory or above the system temp dir
a bare `mktemp -d` uses, naming the marker and the fix. The stray marker was deleted on 2026-10-12 after the reference
consumer pulled 0.774.0. The ten seeded fixtures were proven at gate level: 0.774.0's gate re-ran all ten with the
marker moved aside and each read `ok`.

verify: manual -- close when an instrument run over every declared fixture reports, per fixture, the sandboxed run's assertion and skip counts equal to the plain run's, with every mismatch either fixed or covered by a `!` required input; the instrument must be shown to fire on a seeded fixture whose sandboxed count drops (an input left undeclared behind a skip branch) and stay quiet on one whose counts match

## BL-501 — the deploy-gate checkpoint reported no line per locked requirement, so a generic validation reply carried the sprint into retro past an undelivered one

**DEFECT.** Filed by the consumer as `PC-S317-PVC-TEMPLATE-HAS-NO-LINE-FOR-A-LOCKED-PRIORITY-LEFT-UNDELIVERED`.

**What happened.** `core/skills/ai-dlc/steps/deploy-validate.md` §5's Production Validation Checkpoint template
reported deployment, gate log, fix-forward cluster and escalations. Its only disposition line, `Red-gate
dispositions`, covers gate verdicts left FAILED. Nothing asked, per bullet of the sprint's LOCKED_REQUIREMENTS
block, whether it was delivered, deferred or descoped. In the consumer's S317 deploy gate, locked priority 1 was not
delivered. The lead took a generic validation reply as sufficient and entered retro, and the descope disposition was
recorded only after the operator asked. `steps/retro.md` §4a already requires a recorded operator disposition for a
deferred locked requirement, but nothing put that requirement in front of the operator at the checkpoint.

**The fix (batch 224).** §5's template gains a `### Locked-Requirement Coverage` block: one line per bullet of the
sprint's LOCKED_REQUIREMENTS block marked delivered / deferred / descoped, quoting the `HARD_BLOCK` id and disposition
token (approved-deferral / do-now / descope) for each non-delivered bullet and each bullet deferred and then delivered.
§5's prose says retro.md §4a's rule binds at the checkpoint, and that the checkpoint is not presented while any locked
requirement lacks a recorded disposition. §6 says a generic validation reply is not a disposition. §7's route to retro
requires those dispositions first. A bullet a later phase of the same Rule 14 plan delivers reads `phased` and cites
the story or stories delivering it (each carrying the requirement's LR id in any form §2a permits); it owes no
disposition until the plan's final checkpoint (the one after which no story of the plan remains not `done`),
later checkpoints carry forward every bullet an earlier one marked `phased`, and a `phased` line citing no story,
a `done` story, or a story without the LR id counts as deferred; a sprint with no locked-requirements file reports `none recorded`. The channel is the red-gate one: the
lead files the `HARD_BLOCK`, pauses per Rule 3 and stops, and records the operator's token on the entry with its
`Operator authorization:` citation; Rule 3's pause point (b) names that stop;
`escalations.md`'s resolution lifecycle names that exception, since it otherwise resolves a `HARD_BLOCK` at the
checkpoint itself. No new gate: the
`HARD_BLOCK` is the one Rule 13 already owes. `core/fixtures/deploy-validate-smoke-classification` isolates §5 aware
of its fenced template (the fenced `### ` headings end a naive section read after 9 lines) and keys on the block body,
because the Red-gate line already carries the disposition tokens. Each mutant is killed by its own arm.

Three tip adversaries found the first cut's channel circular, its phasing case blocking every multi-sprint boundary,
then `phased` citing a record no file writes, then a final-sprint rule that fired at every phase checkpoint of the
consumer's in-sprint phasing; a fourth, walking the consumer's real checkpoints, found no reader for "final" and
phased bullets dropped across sprint numbers. All are fixed and pinned (23 §5 mutants). The receipt below is scored under
`set -uo pipefail`: 0 on the fixed tree and with the gating sentence's bold markers moved; 1 on the base `625ab4df`
and with the final-checkpoint rule or its definition, the carry-forward sentence or template line, the
uncited-`phased` rule, the lead-records wording, or the gating sentence's
"that needs one" scope cut; 9 when §5 cannot be isolated.

verify: sh F=core/skills/ai-dlc/steps/deploy-validate.md; [ -f "$F" ] || exit 9; S="$(awk '/^### 5\. Production Validation Checkpoint/{on=1;next} on&&/^```/{f=!f;next} on&&!f&&/^### /{exit} on{print (f?"F\t":"P\t") $0}' "$F")"; [ -n "$S" ] || exit 9; B="$(awk -F'\t' '$1=="F"&&$2~/^### Locked-Requirement Coverage/{b=1;next} $1=="F"&&b&&$2~/^### /{b=0} b&&$1=="F"{print $2}' <<<"$S" | tr '\n' ' ' | tr -s ' ')"; [ -n "$B" ] || exit 1; for t in delivered deferred descoped phased approved-deferral do-now descope HARD_BLOCK; do grep -qw -- "$t" <<<"$B" || exit 1; done; grep -qF 'deferred and then delivered' <<<"$B" || exit 1; P="$(awk -F'\t' '$1=="P"{print $2}' <<<"$S" | tr '\n' ' ' | sed 's/\*\*//g' | tr -s ' ')"; grep -qF 'The checkpoint is not presented while any locked requirement that needs one lacks a recorded disposition' <<<"$P" || exit 1; grep -qF 'reply to the checkpoint does not stand in for a recorded disposition' <<<"$P" || exit 1; grep -qF 'owes no disposition until the plan'"'"'s final checkpoint' <<<"$P" || exit 1; grep -qF 'line citing no story counts as deferred at any checkpoint' <<<"$P" || exit 1; grep -qF 'touch _bmad-output/pipeline-paused.flag' <<<"$P" || exit 1; grep -qF 'the lead records the operator'"'"'s disposition' <<<"$P" || exit 1; grep -qF 'the one after which no story of the plan remains not' <<<"$P" || exit 1; grep -qF 'the block also carries every bullet an earlier checkpoint of that plan marked' <<<"$P" || exit 1; grep -qF 'carried from an earlier checkpoint of this plan' <<<"$B" || exit 1; exit 0

## BL-502 — the PM role turned an unrunnable acceptance criterion into a passive-monitoring AC, but not an architecture risk recorded as an unrun probe

**DEFECT.** Filed by the consumer as `PC-S317-PM-ROLE-TAGS-PROBABILISTIC-ACS-BUT-NOT-AN-ADR-RISK-RECORDED-AS-PROBE-NOT-YET-RUN`.

**What happened.** `core/team-roles/pm.md` requires an AC whose only discharge path nobody on the team controls to be
tagged `probabilistic/passive-monitoring` at story creation. It said nothing about a risk an architecture decision
record carries as an unrun probe, and the PM's Context Loading named only the product brief and the PRD, so the PM never
read the architecture document. In the consumer's S317, a risk recorded in its `docs/architecture.md` as "probe not
yet run" sat in no story's AC and surfaced only when a fix-forward made it live.

**The fix (batch 224).** The probabilistic-AC bullet gains one sentence: such a risk becomes a
`probabilistic/passive-monitoring` AC in the story implementing the decision the ADR records, with its discharge
predicate, an AC added to existing scope and never a new capability. Context Loading gains item 3:
`docs/architecture.md` first, then planning-phase architecture artifacts and `docs/adr/`, for the stories in scope.
`core/fixtures/process-rule-pins` pins seven phrases (placement, trigger, tag, discharge predicate, no new capability, the
Context Loading instruction and the primary document) with `contains` rows; 28 generated mutants are each killed.

The receipt below is scored under `set -uo pipefail`: 0 on the fixed tree and with Context Loading renumbered;
1 on the base `625ab4df`, with the Context Loading instruction inverted, and with "never a new capability"
rewritten.

verify: sh F=core/team-roles/pm.md; [ -f "$F" ] || exit 9; A="$(awk '/^## Responsibilities/{on=1;next} on&&/^## /{exit} on{print}' "$F" | tr '\n' ' ' | tr -s ' ')"; C="$(awk '/^## Context Loading/{on=1;next} on&&/^## /{exit} on{print}' "$F" | tr '\n' ' ' | tr -s ' ')"; [ -n "$A" ] && [ -n "$C" ] || exit 9; grep -qF 'carries as an unrun probe' <<<"$A" || exit 1; grep -qF 'in the story implementing the decision the ADR records' <<<"$A" || exit 1; grep -qF 'with its discharge predicate named in the AC text' <<<"$A" || exit 1; grep -qF 'added to existing scope, never a new capability' <<<"$A" || exit 1; grep -qF 'The architecture and ADR sections for the stories in scope' <<<"$C" || exit 1; grep -qF '`docs/architecture.md` (the primary architecture document)' <<<"$C" || exit 1; exit 0
