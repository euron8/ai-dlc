# SPENT — the 0.338.0 -> 0.341.0 pull RAN, in ONE hop, and every done-when passed

**Do not execute this file.** Their #906 (squash `3a9e216c8`) took it, from the half-landed start
state, and the split stamp resolved through the tool's own `ALREADY-AT-THEIRS` subtraction without
ever being hand-edited. All four stamp fields read `0.341.0 / 899411a`.

**What it got right:** the one-hop prediction was not made (it deliberately refused to predict a hop
count), the `ALREADY-AT-THEIRS` mechanism was named correctly and is what carried the half-landed
state, and the LC-O15 blocker survived the wider range exactly as derived.

**What it got wrong, and it is the same class as predicting a hop count:** it named ONE adjudication
to expect. There were **three** — the two extra are LC-E4 rows on `route-domain.md` and
`route-push.md`, which follow from `route.md` moving and which the file listed as entries that
merely *reference* it.

**The run returned three upstream defects.** Two shipped as v0.342.0 and v0.343.0; the third is
item 6 of the live plan's next-action list. Original text follows.

---

# EXECUTE THIS in a graph session — the pull from `0.338.0` to distribution HEAD (`0.341.0`)

You are in `/Users/n8/git/graph`. Everything below is yours to run and yours to commit.

---

## Start here

**Working repo: `/Users/n8/git/graph`. You write here and only here.** The distribution,
`/Users/n8/git/ai-dlc`, is READ-ONLY to you — every figure in this file was derived there and each
one names the command that produced it. Re-run the command rather than trusting the number; this
file's own lineage is that six carried figures were wrong in the previous two runbooks.

**YOUR START STATE IS A HALF-LANDED PULL, AND THAT IS DELIBERATE — THE OPERATOR CHOSE NOT TO FINISH
IT.** Your stamp reads four fields that disagree:

```
version:       0.338.0        <- the rulebook base
commit:        5e49f08
skill_version: 0.340.0        <- the machinery, taken by your #905
skill_commit:  fb20046
```

That is a self-update hop that landed without its reconcile hop. **Do not try to complete the old
run.** Start a fresh `/ai-dlc-update`; the mechanism that makes this safe is in §1.

**THE DIRECTION OF THAT SPLIT IS THE SIGNAL, NOT THE FACT OF IT.** The documented benign divergence
is skill fields *behind* — a run whose machinery slice was empty. Yours are two releases *ahead*.

### Ping the operator

**Ping on any question, on any decision this file does not already make, and on completion —
including an early stop.** From outside this session, "still working" and "stopped, waiting on you"
are indistinguishable, and every stall in this program's history ended with the operator asking
rather than the session reporting. One of those sessions had already finished.

---

## Current status — what is true as of 2026-08-09

**Distribution HEAD is `0.341.0` at `91fde72`.** Confirm with
`git -C /Users/n8/git/ai-dlc rev-parse --short HEAD` and `cat /Users/n8/git/ai-dlc/VERSION`.

**Your working tree is dirty and carries two untracked reports** from the run that stopped:
`_bmad-output/ai-dlc-update/blocker-adjudication-20260809T145920Z.md` and
`self-update-fixtures-20260809T145051Z.md`. **Decide what to do with them before you start**, because
a fresh run writes new ones alongside. The blocker file is still substantively correct — see §2.

**`contract_version` stays 18.** It is not in the range, so no entry changes its conformance
position and **no new layer warnings are expected**. Your validator prints `0 error(s),
2 warning(s)` today (`W6`, `W7`); unchanged is the PASS.

---

## The numbered action list

1. **Take the pull.** §1. Run `/ai-dlc-update`, then `/ai-dlc-update apply` after review.
2. **Answer the one open blocker** when the run raises it. §2. It is the same blocker your stopped
   run drafted, and the draft is still valid.
3. **If, and only if, the apply reports a `HARD-*` row that is NOT the LC-O15 one named in §2**,
   stop and ping the operator. §2 states why any other hard row is unexpected here.
4. **Run the done-whens in §3 and record them in your completion report.**

Nothing else is in scope. §4 names what was deliberately left out.

---

## §1 — Take the pull

### The reason to take it is a live destructive defect

**Your installed `sprint-status.sh sprint-id` returns `1` — greenfield — on the tree state your own
close-out produces.** Measured 2026-08-09 on a replica of your actual artifact layout: the legacy
`sprint-status/` directories preamble-only, the freezes in `s<N>/` slots, the canonical pruned to its
preamble. Your copy and the distribution's, same tree, same invocation:

```
INSTALLED reader (your copy today)        1     <- greenfield
FIXED reader (0.341.0)                  302     <- max frozen (301) + 1
CONTROL: fixed reader, no freezes at all  1     <- so `1` is still a real answer
```

**A `1` there re-stamps a live project as greenfield and destroys the prior sprint's drafts**, in the
words of the comment directly above the fallback that returns it.

**THE CAUSE IS THAT YOU MIGRATED AND THE READER DID NOT.** `max_frozen` globbed
`sprint-status/sprint-*.yaml`. On your tree that directory now holds only `_preamble.yaml`:

```
git ls-files | grep -cE 'sprint-status/sprint-[0-9]+\.yaml'   ->   0
git ls-files | grep -cE '/s[0-9]+/sprint-status\.yaml'        -> 103
```

**It is DORMANT today and armed at s302's close.** Your canonical carries `sprint: 302`, so the
fallback never runs. It runs the first time a canonical goes preamble-only.

**The same release stops `roll` WRITING the pre-migration path.** It froze to
`<area>/sprint-status/sprint-<N>.yaml`, which `validate-artifact-paths.sh` blocks — and your own
pre-push runs that validator. Reproduced end to end on a scratch consumer, real roll then real
validator over its output: pre-fix `VERDICT: FAIL — 1 blocking`, fixed `VERDICT: PASS`.

### The scope, derived, with a control

Run from the distribution, base is your stamp's `commit`:

```
git -C /Users/n8/git/ai-dlc diff --name-only 5e49f08 91fde72 -- core/          ->  13
git -C /Users/n8/git/ai-dlc diff --name-only 5e49f08 91fde72 -- ':(exclude)core/'  ->   5   <- control
```

**9 of those 13 are ALREADY ON YOUR TREE, byte-identical**, carried by your #905. Verified with
`cmp -s` on each mapped pair — 9 SAME, 0 DIFF, against a control that an unrelated pair reports
DIFF. **Four are new to you:**

```
core/scripts/sprint-status.sh              ->  scripts/ai-dlc/sprint-status.sh
core/schemas/sprint-status.json            ->  .claude/schemas/sprint-status.json
core/fixtures/sprint-status-lifecycle/     ->  tests/fixtures/sprint-status-lifecycle/
core/skills/ai-dlc/steps/route.md          ->  .claude/skills/ai-dlc/steps/route.md   <- RULEBOOK
```

### The half-landed machinery is handled by the tool, and this is the mechanism

The slice is `git diff base→theirs` with `base` the stamp's `commit` — `5e49f08`, **not** your
`skill_commit`. So the raw slice re-proposes all nine files you already have.
`core/skills/ai-dlc-update/SKILL.md:291` is the line that resolves it: *"The slice is the sliced
paths MINUS those"*, bucketed by `reconcile/preclassify.sh` as `ALREADY-AT-THEIRS`. **Do not
hand-roll that subtraction and do not edit your stamp to paper over the split.**

### This range puts `core/scripts/` in the machinery slice, which is the case the skill warns about

`core/skills/ai-dlc-update/SKILL.md:296` records `PC-S308`: the machinery slice includes
`core/scripts/*`, your `.githooks/pre-push` invokes several of those, and a cycle can install a check
that fails the very push it is making — stranding a local branch and a `skill_version` on a commit
that never merges. **Run `reconcile/self-update-gate.sh` as step 2 mandates and read its verdict.**

**Measured, so you can tell a real defer from a surprise: your pre-push does NOT invoke
`sprint-status.sh`.** Control, from the same grep of the same file: it does invoke
`validate-artifact-paths.sh`, `validate-layer-entries.sh`, `audit-rule-files.sh` and five more — and
all of those are among the nine already at theirs.

### The covering fixture is named in `seed.sh` and NOT in `run.sh`

`sprint-status-lifecycle` resolves the tooling path in its seed. A `run.sh`-only derivation of the
covering-fixture set misses it and the slice ships the script without its test.
`core/skills/ai-dlc-update/SKILL.md:207` says to grep both; this range is a live instance of why.
The fixture carries no `.dist-only` marker, so it ships to you.

### Adjudications

`route.md` is the only rulebook file in the range. **Three of your entries reference it** —
`extensions/steps-domain/route-domain.md`, `extensions/steps-domain/route-push.md`, and
`overrides/steps__retro__domain-sections.md`. **For the override the reference is prose, not a hook:**
its `shadows:` names `steps/retro.md` alone, and `steps/retro.md` is byte-identical across this range
(`70f05f15…` at both ends). That is what §2 turns on.

---

## §2 — The one open blocker, and your stopped run already answered it

Expect **`HARD-LAYER-ADJUDICATION-MISSING`** on
`.claude/skills/ai-dlc/overrides/steps__retro__domain-sections.md`, clause LC-O15, subject digest
`f7a127f9254a9b4d0d4825c030b5fe9bf2e2d08a`.

**The draft in `blocker-adjudication-20260809T145920Z.md` is still valid across this larger range,
and the reason is derivable rather than assumed.** `adj_digest`
(`core/skills/ai-dlc-update/reconcile/layer-drift.sh:519`) hashes two things: your entry file's blob,
and the target's blob at `THEIRS`. The entry has not changed since your #903, and the target
`steps/retro.md` is byte-identical at `5e49f08` and `91fde72`. **Both inputs are unchanged, so the
digest is unchanged.**

**Re-verify it in the apply run anyway.** That file's own header says a row whose verification does
not resolve against the apply run's refs is stale, and the run's refs are what decide it.

Its recommendation is `still-additive`, re-declaring `OWED-RETRO-4A-NARROW`, and it carries the
fully-resolved register line. **`readopt-override.sh --stamp retire` is the wrong remedy here** — it
deletes the whole file, and core has superseded 1 of the entry's 4 anchors.

**One thing that draft could not verify, so do not treat it as settled:** it reports 119
consumer-only lines in the `#4a` span where the 2026-08-08 debt record says 111. Core is
byte-identical across that window, so the entry side moved and #903 is the only candidate — but that
the repath is what changed the count is an inference, not a measurement.

---

## §3 — Done-when. Every PASS below was RUN against your tree from the distribution side on 2026-08-09

- **`sed -n '1,4p' .claude/.ai-dlc-version` reads `0.341.0` and theirs' sha on ALL FOUR fields.**
  The split you started from is gone. If step 2 deferred its machinery slice, the one run that may
  claim both pairs is `apply.sh --carried-machinery-slice`, and all four still end equal.

- **`bash tests/fixtures/sprint-status-lifecycle/run.sh` prints `sprint-status-lifecycle: PASS`.**
  It passes on your tree TODAY with the old pair, and it must pass after with the new pair — so a red
  here is a partial apply (fixture landed, script did not) or a real regression, never a new fixture.

- **`bash scripts/ai-dlc/sprint-status.sh sprint-id` prints `302`.** It prints `302` today. This is
  the no-regression arm: the reader gained a spelling and must not have lost one.

- **`bash scripts/ai-dlc/validate-artifact-paths.sh` prints
  `VERDICT: PASS — no MIGRATABLE non-conforming path under the scan roots.`** It says that today.
  Unchanged is the PASS.

- **`bash scripts/ai-dlc/validate-layer-entries.sh` prints `0 error(s), 2 warning(s)`** and
  `contract_version=18 entries=43`. The two are `W6` (all 43 below contract 18) and `W7` (the
  dangling `Check 11b` pointer in `deploy-validate-domain.md`). **Both are pre-existing and neither
  is this range's.** `W11=LC-R4:0/43` — measured before the pull; unchanged is the PASS.

- **`layer-drift.sh --list-adjudications` shows the LC-O15 subject keyed and carrying a verdict**,
  and the apply reports **0 `HARD-*`** rows after §2 is recorded.

- **You write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`; `apply.sh` does not**, and it says
  so on a successful run. Write it LAST, after the post-apply re-runs, because it records them.

---

## §4 — Deliberately NOT in this file

- **Finishing the `0.338.0` → `0.340.0` reconcile hop as its own run.** Operator direction
  2026-08-09: the current state is this runbook's start state. §1 folds it in.
- **`docs/qa/sprint-<N>/**` repathing.** 5 `sprint-<N>` directories, 0 slotted. `docs/reviews/` is
  not finished either — 126 slotted against 9 directories and 2 files at the old spelling. Nothing
  blocks; it is yours to take when you choose.
- **`pipeline-continuation-log.md` at 326% of its budget** (32697 tok against 10000), up from 322%.
  Its remedy is `rotate`, which the consolidation step excludes by name-class.
- **The stale line in your own override.** `overrides/steps__retro__domain-sections.md:602` describes
  the freeze going to `<view>/sprint-status/sprint-<N>.yaml`. After this pull that is no longer what
  core does. It is your prose, it blocks nothing, and changing it spends the entry's verdict — so it
  belongs to a later pass, not to this one.
- **The 48 refused artifact-path migrations and `PC-S312`'s re-anchoring.** Unchanged, carried in
  your own ledger.

---

## When you are done

Ping the operator with: the hop count and PR numbers, the four stamp fields, each done-when's actual
output, and anything this file predicted that did not happen. **The last one is the most valuable
thing you can send back** — the previous two runbooks were each wrong about something only your tree
could show, and both times the correction became a distribution release.
